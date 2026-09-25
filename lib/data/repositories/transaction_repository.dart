import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../local/database_helper.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';

/// Repository quản lý giao dịch — đọc/ghi từ SQLite (offline-first).
/// Mọi thay đổi đều được ghi vào sync_queue để đồng bộ lên Firestore sau.
/// SINGLETON: Đảm bảo chỉ có 1 instance duy nhất để tất cả StreamBuilder
/// trên UI đều lắng nghe cùng một stream, tránh lỗi "Bad State".
class TransactionRepository {
  static final TransactionRepository _instance = TransactionRepository._internal();
  factory TransactionRepository() => _instance;
  TransactionRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _changeStream = StreamController<void>.broadcast();
  final _transactionsController = StreamController<List<TransactionModel>>.broadcast();
  final _balanceController = StreamController<({double balance, double totalIncome, double totalExpense})>.broadcast();

  List<TransactionModel> _cachedTransactions = [];
  List<TransactionModel> get latestTransactions => List.unmodifiable(_cachedTransactions);

  String? _explicitUid;
  String? get _currentUid => _explicitUid ?? AuthService().currentUid;
  String? get currentUid => _currentUid;

  void setUid(String uid) {
    _explicitUid = uid;
    _notifyTransactionsChanged();
  }

  // ════════ TRANSACTIONS CRUD ════════

  /// Thêm giao dịch mới vào SQLite + enqueue sync
  Future<String> addTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final uid = transaction.uid.isNotEmpty ? transaction.uid : (_currentUid ?? '');
    final now = DateTime.now();

    final tx = TransactionModel(
      id: id,
      uid: uid,
      type: transaction.type,
      category: transaction.category,
      categoryIconCode: transaction.categoryIconCode,
      amount: transaction.amount,
      date: transaction.date,
      time: transaction.time,
      description: transaction.description,
      hasPhoto: transaction.hasPhoto,
      photoUrl: transaction.photoUrl,
      photoStoragePath: transaction.photoStoragePath,
      photoLocalPath: transaction.photoLocalPath,
      createdAt: transaction.createdAt,
      updatedAt: now,
      groupId: transaction.groupId,
      groupIconCode: transaction.groupIconCode,
      source: transaction.source,
      walletId: transaction.walletId,
      syncStatus: 'pending',
    );

    await db.insert('transactions', tx.toSqlite());

    // Thêm vào sync queue
    await _enqueueSyncAction('transactions', id, 'INSERT', tx.toSqlite());

    // Phát sự kiện thay đổi
    _notifyTransactionsChanged();

    return id;
  }

  /// Insert giao dịch bên trong một Transaction đã có (để dùng với atomic service)
  Future<String> addTransactionInTxn(DatabaseExecutor txn, TransactionModel transaction) async {
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final uid = transaction.uid.isNotEmpty ? transaction.uid : (_currentUid ?? '');
    final now = DateTime.now();

    final tx = TransactionModel(
      id: id,
      uid: uid,
      type: transaction.type,
      category: transaction.category,
      categoryIconCode: transaction.categoryIconCode,
      amount: transaction.amount,
      date: transaction.date,
      time: transaction.time,
      description: transaction.description,
      hasPhoto: transaction.hasPhoto,
      photoUrl: transaction.photoUrl,
      photoStoragePath: transaction.photoStoragePath,
      photoLocalPath: transaction.photoLocalPath,
      createdAt: transaction.createdAt,
      updatedAt: now,
      groupId: transaction.groupId,
      groupIconCode: transaction.groupIconCode,
      source: transaction.source,
      walletId: transaction.walletId,
      syncStatus: 'pending',
    );

    await txn.insert('transactions', tx.toSqlite());

    await txn.insert('sync_queue', {
      'tableName': 'transactions',
      'recordId': id,
      'action': 'INSERT',
      'data': json.encode(tx.toSqlite()),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });

    return id;
  }

  /// Cập nhật giao dịch
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final updated = transaction.copyWith(
      updatedAt: now,
      syncStatus: 'pending',
    );

    await db.update(
      'transactions',
      updated.toSqlite(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    await _enqueueSyncAction('transactions', transaction.id, 'UPDATE', updated.toSqlite());

    _notifyTransactionsChanged();
  }

  /// Xóa giao dịch
  Future<void> deleteTransaction(String transactionId) async {
    final db = await _dbHelper.database;

    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);

    await _enqueueSyncAction('transactions', transactionId, 'DELETE', null);

    _notifyTransactionsChanged();
  }

  static bool _hasPurgedBeforeSeptember2026 = false;

  /// Tự động kiểm tra và dọn dẹp các giao dịch cũ từ tháng 8/2026 trở về trước
  Future<void> checkAndPurgeOldTransactions() async {
    if (_hasPurgedBeforeSeptember2026) return;
    _hasPurgedBeforeSeptember2026 = true;
    try {
      final count = await purgeHistoryBeforeSeptember2026();
      if (count > 0) {
        debugPrint('TransactionRepository: Đã tự động dọn dẹp $count giao dịch từ tháng 8/2026 trở về trước.');
      }
    } catch (e) {
      debugPrint('TransactionRepository: Lỗi khi dọn dẹp giao dịch cũ: $e');
    }
  }

  /// Xóa sạch toàn bộ lịch sử thu/chi trước 01/09/2026 trên cả SQLite và Cloud Firestore
  Future<int> purgeHistoryBeforeSeptember2026({String? targetUid}) async {
    final cutoff = DateTime(2026, 9, 1);
    return deleteTransactionsBefore(cutoff, targetUid: targetUid);
  }

  /// Xóa toàn bộ giao dịch trước một mốc thời gian (bao gồm cả SQLite, sync_queue và Firestore)
  Future<int> deleteTransactionsBefore(DateTime cutoffDate, {String? targetUid}) async {
    final db = await _dbHelper.database;
    final cutoffMs = cutoffDate.millisecondsSinceEpoch;
    final uid = targetUid ?? _currentUid;

    final whereClause = uid != null ? 'uid = ? AND date < ?' : 'date < ?';
    final whereArgs = uid != null ? [uid, cutoffMs] : [cutoffMs];

    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where: whereClause,
      whereArgs: whereArgs,
    );

    final txIds = rows.map((r) => r['id'] as String).toSet();
    debugPrint('TransactionRepository: Bắt đầu xóa ${txIds.length} giao dịch SQLite trước ngày $cutoffDate (uid=$uid)');

    // 1. Xóa trực tiếp trên Cloud Firestore nếu có mạng và có UID
    final isOnline = ConnectivityService().isOnline;
    final firestore = FirebaseFirestore.instance;
    int firestoreDeleteCount = 0;

    if (isOnline && uid != null) {
      try {
        final snap = await firestore
            .collection('transactions')
            .where('uid', isEqualTo: uid)
            .get();

        final batch = firestore.batch();
        for (final doc in snap.docs) {
          final data = doc.data();
          DateTime? docDate;
          if (data['date'] is Timestamp) {
            docDate = (data['date'] as Timestamp).toDate();
          } else if (data['date'] is int) {
            docDate = DateTime.fromMillisecondsSinceEpoch(data['date'] as int);
          }

          if (docDate != null && docDate.isBefore(cutoffDate)) {
            batch.delete(doc.reference);
            txIds.add(doc.id);
            firestoreDeleteCount++;
          }
        }

        if (firestoreDeleteCount > 0) {
          await batch.commit();
          debugPrint('TransactionRepository: Đã xóa batch $firestoreDeleteCount docs trên Firestore thành công');
        }
      } catch (e) {
        debugPrint('TransactionRepository: Lỗi batch delete Firestore: $e');
      }
    }

    // 2. Dọn dẹp các bản ghi pending cũ trong sync_queue
    for (final id in txIds) {
      await db.delete(
        'sync_queue',
        where: 'tableName = ? AND recordId = ?',
        whereArgs: ['transactions', id],
      );
    }

    // 3. Xóa các giao dịch trong SQLite
    final count = await db.delete(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
    );

    // 4. Nếu có txIds nào chưa xóa trên Firestore (ví dụ offline), enqueue DELETE
    for (final id in txIds) {
      await db.insert('sync_queue', {
        'tableName': 'transactions',
        'recordId': id,
        'action': 'DELETE',
        'data': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'retryCount': 0,
      });

      if (isOnline) {
        try {
          unawaited(firestore.collection('transactions').doc(id).delete());
        } catch (_) {}
      }
    }

    // 5. Phát sự kiện cập nhật số dư & danh sách giao dịch
    _notifyTransactionsChanged();

    debugPrint('TransactionRepository: Đã hoàn tất xóa $count SQLite + $firestoreDeleteCount Firestore trước ngày $cutoffDate');
    return count;
  }

  /// Cập nhật ảnh cho giao dịch
  Future<void> updateTransactionPhoto({
    required String transactionId,
    String? photoUrl,
    String? photoStoragePath,
    String? photoLocalPath,
  }) async {
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{
      'hasPhoto': 1,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'syncStatus': 'pending',
    };
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (photoStoragePath != null) updates['photoStoragePath'] = photoStoragePath;
    if (photoLocalPath != null) updates['photoLocalPath'] = photoLocalPath;

    await db.update('transactions', updates, where: 'id = ?', whereArgs: [transactionId]);

    await _enqueueSyncAction('transactions', transactionId, 'UPDATE', updates);

    _notifyTransactionsChanged();
  }

  // ════════ QUERIES ════════

  /// Stream danh sách giao dịch — dùng broadcast StreamController
  /// để nhiều StreamBuilder có thể lắng nghe đồng thời mà không crash.
  Stream<List<TransactionModel>> getTransactionsStream({int? limit}) {
    _loadAndEmitTransactions(limit: limit);
    return _transactionsController.stream;
  }

  /// Stream tổng số dư, tổng thu, tổng chi
  Stream<({double balance, double totalIncome, double totalExpense})> getBalanceStream() {
    _loadAndEmitBalance();
    return _balanceController.stream;
  }

  /// Stream các giao dịch có ảnh (dùng cho Gallery)
  Stream<List<TransactionModel>> getTransactionsWithPhotosStream() {
    return getTransactionsStream().map(
      (list) => list.where((tx) => tx.hasPhoto).toList(),
    );
  }

  /// Tải danh sách giao dịch một lần (không stream)
  Future<List<TransactionModel>> getAllTransactions({int? limit}) async {
    final uid = _currentUid;
    if (uid == null) return [];
    final db = await _dbHelper.database;
    final results = await db.query(
      'transactions',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'date DESC',
      limit: limit,
    );
    return results.map((row) => TransactionModel.fromSqlite(row)).toList();
  }

  /// Lấy 1 giao dịch theo ID
  Future<TransactionModel?> getTransactionById(String id) async {
    if (id.isEmpty) return null;
    final db = await _dbHelper.database;
    final results = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return TransactionModel.fromSqlite(results.first);
  }

  /// Lấy giao dịch theo khoảng thời gian (dùng cho export báo cáo)
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_currentUid == null) return [];
    final db = await _dbHelper.database;

    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final results = await db.query(
      'transactions',
      where: 'uid = ? AND date >= ? AND date <= ? AND type = ?',
      whereArgs: [
        _currentUid,
        rangeStart.millisecondsSinceEpoch,
        rangeEnd.millisecondsSinceEpoch,
        'expense',
      ],
      orderBy: 'date ASC, createdAt ASC',
    );
    return results.map((row) => TransactionModel.fromSqlite(row)).toList();
  }

  // ════════ BULK OPERATIONS (dùng cho Sync) ════════

  /// Upsert nhiều giao dịch từ Firestore (dùng khi sync download)
  Future<void> upsertFromFirestore(List<TransactionModel> transactions) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final tx in transactions) {
      batch.insert(
        'transactions',
        tx.copyWith(syncStatus: 'synced').toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    _notifyTransactionsChanged();
  }

  /// Đánh dấu đã sync thành công
  Future<void> markAsSynced(String transactionId) async {
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      {'syncStatus': 'synced'},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Lấy danh sách giao dịch chưa sync (pending)
  Future<List<TransactionModel>> getPendingTransactions() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'transactions',
      where: 'syncStatus = ?',
      whereArgs: ['pending'],
    );
    return results.map((row) => TransactionModel.fromSqlite(row)).toList();
  }

  // ════════ INTERNAL HELPERS ════════

  Future<void> _loadAndEmitTransactions({int? limit}) async {
    await checkAndPurgeOldTransactions();
    final list = await getAllTransactions(limit: limit);
    _cachedTransactions = list;
    if (!_transactionsController.isClosed) {
      _transactionsController.add(list);
    }
  }

  Future<void> _loadAndEmitBalance() async {
    final balance = await _calculateBalance();
    if (!_balanceController.isClosed) {
      _balanceController.add(balance);
    }
  }

  Future<({double balance, double totalIncome, double totalExpense})> _calculateBalance() async {
    final uid = _currentUid;
    if (uid == null) {
      return (balance: 0.0, totalIncome: 0.0, totalExpense: 0.0);
    }
    final db = await _dbHelper.database;

    final incomeResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE uid = ? AND type = ? AND category NOT IN ('Chuyển tiền', 'Nhận chuyển tiền', 'Chuyển ví') AND (groupId IS NULL OR groupId NOT LIKE 'transfer_%')",
      [uid, 'income'],
    );
    final expenseResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE uid = ? AND type = ? AND category NOT IN ('Chuyển tiền', 'Nhận chuyển tiền', 'Chuyển ví') AND (groupId IS NULL OR groupId NOT LIKE 'transfer_%')",
      [uid, 'expense'],
    );

    final totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpense = (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return (
      balance: totalIncome - totalExpense,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }

  void notifyTransactionsChanged() => _notifyTransactionsChanged();

  void _notifyTransactionsChanged() {
    _loadAndEmitTransactions();
    _loadAndEmitBalance();
  }

  Future<void> _enqueueSyncAction(String table, String recordId, String action, Map<String, dynamic>? data) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'tableName': table,
      'recordId': recordId,
      'action': action,
      'data': data != null ? json.encode(data) : null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });

    // Tự động đẩy lên Firebase nếu thiết bị đang có mạng
    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  void dispose() {
    _changeStream.close();
    _transactionsController.close();
    _balanceController.close();
  }
}
