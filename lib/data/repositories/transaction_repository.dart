import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../core/safety/destructive_ops_guard.dart';
import '../../models/transaction_model.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/ai_financial_context_service.dart';

/// Repository quản lý giao dịch — đọc/ghi từ SQLite (offline-first).
/// Mọi thay đổi đều được ghi vào sync_queue để đồng bộ lên Firestore sau.
/// SINGLETON: Đảm bảo chỉ có 1 instance duy nhất để tất cả StreamBuilder
/// trên UI đều lắng nghe cùng một stream, tránh lỗi "Bad State".
class TransactionRepository with OwnedTableOps {
  static final TransactionRepository _instance =
      TransactionRepository._internal();
  factory TransactionRepository() => _instance;

  TransactionRepository._internal() {
    session.changes.listen((_) {
      _cachedTransactions = [];
      _notifyTransactionsChanged();
      if (session.uidOrNull != null) {
        getAllTransactions();
      }
    });
    _loadAndEmitTransactions();
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _changeStream = StreamController<void>.broadcast();
  final _transactionsController =
      StreamController<List<TransactionModel>>.broadcast();
  final _balanceController =
      StreamController<
        ({double balance, double totalIncome, double totalExpense})
      >.broadcast();

  List<TransactionModel> _cachedTransactions = [];
  List<TransactionModel> get latestTransactions =>
      List.unmodifiable(_cachedTransactions);

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  // ════════ TRANSACTIONS CRUD ════════

  /// Thêm giao dịch mới vào SQLite + enqueue sync
  Future<String> addTransaction(TransactionModel transaction) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final now = DateTime.now();

    final tx = transaction.copyWith(
      id: id,
      updatedAt: now,
      syncStatus: 'pending',
    );
    final row = stampOwner(tx.toSqlite(), uid);

    await db.transaction((txn) async {
      await txn.insert('transactions', row);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    _notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    return id;
  }

  /// Insert giao dịch bên trong một Transaction đã có (để dùng với atomic service)
  Future<String> addTransactionInTxn(
    DatabaseExecutor txn,
    TransactionModel transaction,
  ) async {
    final uid = session.requireUid();
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final now = DateTime.now();

    final tx = transaction.copyWith(
      id: id,
      updatedAt: now,
      syncStatus: 'pending',
    );
    final row = stampOwner(tx.toSqlite(), uid);

    await txn.insert('transactions', row);
    await SyncQueueWriter.enqueue(
      txn,
      ownerUid: uid,
      table: 'transactions',
      recordId: id,
      action: 'INSERT',
      data: row,
    );

    return id;
  }

  /// Cập nhật giao dịch
  Future<void> updateTransaction(TransactionModel transaction) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final updated = transaction.copyWith(updatedAt: now, syncStatus: 'pending');
    final row = stampOwner(updated.toSqlite(), uid);

    await db.transaction((txn) async {
      await updateOwned(txn, 'transactions', transaction.id, row, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: transaction.id,
        action: 'UPDATE',
        data: row,
      );
    });

    _notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Xóa giao dịch (áp dụng Soft Delete / Tombstone)
  Future<void> deleteTransaction(String transactionId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'transactions', transactionId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: transactionId,
        action: 'SOFT_DELETE',
      );
    });

    _notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Tự động kiểm tra và dọn dẹp các giao dịch cũ - ĐÃ VÔ HIỆU HÓA để bảo toàn hóa đơn và số dư người dùng
  @Deprecated('Đã vô hiệu hóa để bảo toàn hóa đơn và số dư')
  Future<void> checkAndPurgeOldTransactions() async {
    return;
  }

  /// Xóa sạch toàn bộ lịch sử thu/chi trước 01/09/2026 trên cả SQLite và Cloud Firestore - ĐÃ KHÓA Ở P0
  @Deprecated('Đã bị khóa ở P0 — xem PLAN_P0_SECURITY.md §4')
  Future<int> purgeHistoryBeforeSeptember2026({String? targetUid}) async {
    DestructiveOpsGuard.ensureEnabled('purgeHistoryBeforeSeptember2026');
    final cutoff = DateTime(2026, 9, 1);
    return deleteTransactionsBefore(cutoff, targetUid: targetUid);
  }

  /// Xóa toàn bộ giao dịch trước một mốc thời gian - ĐÃ KHÓA Ở P0
  @Deprecated('Bị khóa ở P0 — xem PLAN_P0_SECURITY.md §4')
  Future<int> deleteTransactionsBefore(
    DateTime cutoffDate, {
    String? targetUid,
    String? ownerUid,
  }) async {
    DestructiveOpsGuard.ensureEnabled('deleteTransactionsBefore');
    final uid = session.requireUid();
    final effectiveOwner = ownerUid ?? targetUid ?? uid;
    if (effectiveOwner != uid) {
      throw const BusinessException(
        BusinessErrorCode.ownershipViolation,
        'ownerUid ≠ phiên',
      );
    }
    throw UnimplementedError('Triển khai lại ở P1 cùng cơ chế tính lại số dư');
  }

  /// Cập nhật ảnh cho giao dịch
  Future<void> updateTransactionPhoto({
    required String transactionId,
    String? photoUrl,
    String? photoStoragePath,
    String? photoLocalPath,
  }) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final updates = <String, dynamic>{
      'hasPhoto': 1,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'syncStatus': 'pending',
    };
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (photoStoragePath != null) {
      updates['photoStoragePath'] = photoStoragePath;
    }
    if (photoLocalPath != null) updates['photoLocalPath'] = photoLocalPath;

    await db.transaction((txn) async {
      await updateOwned(txn, 'transactions', transactionId, updates, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: transactionId,
        action: 'UPDATE',
        data: updates,
      );
    });

    _notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Đổi tên danh mục cho toàn bộ giao dịch cũ (dùng khi user đổi tên danh mục tự tạo).
  /// Trả về số giao dịch đã cập nhật.
  Future<int> renameCategory({
    required String oldName,
    required String newName,
    required String type, // 'income' | 'expense'
  }) async {
    final uid = session.requireUid();
    if (oldName == newName) return 0;
    final db = await _dbHelper.database;

    final rows = await db.query(
      'transactions',
      where: 'uid = ? AND category = ? AND type = ?',
      whereArgs: [uid, oldName, type],
    );
    if (rows.isEmpty) return 0;

    final now = DateTime.now();
    await db.transaction((txn) async {
      for (final row in rows) {
        final updated = TransactionModel.fromSqlite(
          row,
        ).copyWith(category: newName, updatedAt: now, syncStatus: 'pending');
        final values = updated.toSqlite();
        await updateOwned(txn, 'transactions', updated.id, values, uid);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'transactions',
          recordId: updated.id,
          action: 'UPDATE',
          data: values,
        );
      }
    });

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
    _notifyTransactionsChanged();
    return rows.length;
  }

  // ════════ QUERIES ════════

  /// Stream danh sách giao dịch — phát dữ liệu từ cache và lắng nghe broadcast sự kiện thay đổi
  Stream<List<TransactionModel>> getTransactionsStream({int? limit}) async* {
    if (_cachedTransactions.isNotEmpty) {
      yield latestTransactions;
    }
    yield await getAllTransactions(limit: limit);
    await for (final _ in _changeStream.stream) {
      yield await getAllTransactions(limit: limit);
    }
  }

  /// Stream tổng số dư, tổng thu, tổng chi
  Stream<({double balance, double totalIncome, double totalExpense})>
  getBalanceStream() async* {
    yield await _calculateBalance();
    await for (final _ in _changeStream.stream) {
      yield await _calculateBalance();
    }
  }

  /// Stream các giao dịch có ảnh (dùng cho Gallery)
  Stream<List<TransactionModel>> getTransactionsWithPhotosStream() {
    return getTransactionsStream().map(
      (list) => list.where((tx) => tx.hasPhoto).toList(),
    );
  }

  /// Tải danh sách giao dịch một lần (không stream)
  Future<List<TransactionModel>> getAllTransactions({int? limit}) async {
    final uid = session.uidOrNull;
    if (uid == null) return const []; // fail-closed READ
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'transactions',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid],
        orderBy: 'date DESC',
        limit: limit,
      );
      final list = results
          .map((row) => TransactionModel.fromSqlite(row))
          .toList();
      _cachedTransactions = list;
      return list;
    } catch (e) {
      debugPrint('TransactionRepository.getAllTransactions error: $e');
      return _cachedTransactions;
    }
  }

  /// Lấy 1 giao dịch theo ID
  Future<TransactionModel?> getTransactionById(String id) async {
    final uid = session.uidOrNull;
    if (id.isEmpty || uid == null) return null;
    final db = await _dbHelper.database;
    final row = await findOwned(db, 'transactions', id, uid);
    if (row == null) return null;
    final tx = TransactionModel.fromSqlite(row);
    if (tx.isDeleted) return null;
    return tx;
  }

  /// Lấy giao dịch theo khoảng thời gian (dùng cho export báo cáo)
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? type,
  }) async {
    final uid = session.uidOrNull;
    if (uid == null) return const [];
    final db = await _dbHelper.database;

    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final whereClause = type != null
        ? 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND date >= ? AND date <= ? AND type = ?'
        : 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND date >= ? AND date <= ?';
    final whereArgs = type != null
        ? [
            uid,
            rangeStart.millisecondsSinceEpoch,
            rangeEnd.millisecondsSinceEpoch,
            type,
          ]
        : [
            uid,
            rangeStart.millisecondsSinceEpoch,
            rangeEnd.millisecondsSinceEpoch,
          ];

    final results = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date ASC, createdAt ASC',
    );
    return results.map((row) => TransactionModel.fromSqlite(row)).toList();
  }

  // ════════ BULK OPERATIONS (dùng cho Sync) ════════

  /// Upsert nhiều giao dịch từ Firestore (áp dụng Local Dirty Shield và Soft Delete)
  Future<void> upsertFromFirestore(List<TransactionModel> transactions) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || transactions.isEmpty) return;
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final tx in transactions) {
        if (tx.uid != currentUid) continue;

        // 1. Kiểm tra Local Dirty Shield: nếu bản ghi đang chờ upload thì bỏ qua
        final queuePending = await txn.query(
          'sync_queue',
          columns: ['id'],
          where:
              'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
          whereArgs: [
            'transactions',
            tx.id,
            currentUid,
            currentUid,
            'pending',
            'processing',
          ],
          limit: 1,
        );
        if (queuePending.isNotEmpty) continue;

        final existing = await txn.query(
          'transactions',
          where: 'id = ? AND uid = ?',
          whereArgs: [tx.id, currentUid],
          limit: 1,
        );

        if (existing.isEmpty) {
          if (!tx.isDeleted) {
            await txn.insert(
              'transactions',
              tx.copyWith(syncStatus: 'synced').toSqlite(),
            );
          }
        } else {
          final local = TransactionModel.fromSqlite(existing.first);
          if (local.syncStatus == 'pending') continue; // Dirty Shield

          final isRemoteNewer = tx.updatedAt.isAfter(local.updatedAt);
          final isSameTime = tx.updatedAt.isAtSameMomentAs(local.updatedAt);
          final winsTieBreak =
              isSameTime && _resolveTieBreaker(local.toSqlite(), tx.toSqlite());

          if (isRemoteNewer || winsTieBreak) {
            if (tx.isDeleted) {
              await txn.update(
                'transactions',
                {
                  'isDeleted': 1,
                  'deletedAt':
                      tx.deletedAt?.millisecondsSinceEpoch ??
                      DateTime.now().millisecondsSinceEpoch,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [tx.id, currentUid],
              );
            } else {
              await txn.update(
                'transactions',
                tx.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [tx.id, currentUid],
              );
            }
          }
        }
      }
    });

    _notifyTransactionsChanged();
  }

  /// Deterministic Tie-Breaker theo SHA256 khi hai thiết bị có updatedAt giống hệt nhau
  static bool _resolveTieBreaker(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final localStr = json.encode(local);
    final remoteStr = json.encode(remote);
    final localHash = sha256.convert(utf8.encode(localStr)).toString();
    final remoteHash = sha256.convert(utf8.encode(remoteStr)).toString();
    return remoteHash.compareTo(localHash) >= 0;
  }

  /// Upsert an toàn tuân thủ interface ISyncableRepository
  Future<void> upsertFromFirestoreSafe(List<TransactionModel> transactions) =>
      upsertFromFirestore(transactions);

  /// Đánh dấu đã sync thành công
  Future<void> markAsSynced(String transactionId) async {
    final uid = session.uidOrNull;
    if (uid == null) return;
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      {'syncStatus': 'synced'},
      where: 'id = ? AND uid = ?',
      whereArgs: [transactionId, uid],
    );
  }

  /// Lấy danh sách giao dịch chưa sync (pending)
  Future<List<TransactionModel>> getPendingTransactions() async {
    final uid = session.uidOrNull;
    if (uid == null) return const [];
    final db = await _dbHelper.database;
    final results = await db.query(
      'transactions',
      where: 'uid = ? AND syncStatus = ?',
      whereArgs: [uid, 'pending'],
    );
    return results.map((row) => TransactionModel.fromSqlite(row)).toList();
  }

  // ════════ INTERNAL HELPERS ════════

  Future<void> _loadAndEmitTransactions({int? limit}) async {
    try {
      final list = await getAllTransactions(limit: limit);
      _cachedTransactions = list;
      if (!_transactionsController.isClosed) {
        _transactionsController.add(list);
      }
    } catch (e) {
      debugPrint('TransactionRepository._loadAndEmitTransactions error: $e');
    }
  }

  Future<void> _loadAndEmitBalance() async {
    try {
      final balance = await _calculateBalance();
      if (!_balanceController.isClosed) {
        _balanceController.add(balance);
      }
    } catch (e) {
      debugPrint('TransactionRepository._loadAndEmitBalance error: $e');
    }
  }

  Future<({double balance, double totalIncome, double totalExpense})>
  _calculateBalance() async {
    final uid = session.uidOrNull;
    if (uid == null) {
      return (balance: 0.0, totalIncome: 0.0, totalExpense: 0.0);
    }
    final db = await _dbHelper.database;

    const whereClause =
        "uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND type = ? AND (transferId IS NULL OR transferId = '') AND (groupId IS NULL OR groupId NOT LIKE 'transfer_%') AND category NOT IN ('Chuyển tiền', 'Nhận chuyển tiền', 'Chuyển ví') AND (goalId IS NULL OR goalId = '')";
    final incomeArgs = [uid, 'income'];
    final expenseArgs = [uid, 'expense'];

    final incomeResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE $whereClause",
      incomeArgs,
    );
    final expenseResult = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE $whereClause",
      expenseArgs,
    );

    final totalIncome =
        (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpense =
        (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

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
    if (!_changeStream.isClosed) {
      _changeStream.add(null);
    }
    AiFinancialContextService().invalidateCache();
  }

  void dispose() {
    _changeStream.close();
    _transactionsController.close();
    _balanceController.close();
  }
}
