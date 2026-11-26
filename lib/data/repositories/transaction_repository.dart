import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../core/safety/destructive_ops_guard.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../models/goal_model.dart';
import '../../utils/finance_precision.dart';
import 'wallet_repository.dart';
import 'goal_repository.dart';
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

  /// Helper điều chỉnh số dư ví nguyên tử bên trong SQLite transaction (dùng timestamp tịnh tiến)
  Future<void> _adjustWalletBalanceInTxn(
    DatabaseExecutor txn,
    String walletId,
    double amountDelta,
    String uid,
  ) async {
    if (walletId.isEmpty) return;
    final walletRows = await txn.query(
      'wallets',
      where: 'id = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [walletId, uid],
      limit: 1,
    );
    if (walletRows.isEmpty) return;

    final w = WalletModel.fromSqlite(walletRows.first);
    final newBal = FinancePrecision.roundCurrency(
      w.balance + amountDelta,
      currency: w.currency,
    );
    final nextMs = nextMonotonicTimestamp(w.updatedAt.millisecondsSinceEpoch);
    final updatedW = w.copyWith(
      balance: newBal,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(nextMs),
      syncStatus: 'pending',
    );
    final wRow = stampOwner(updatedW.toSqlite(), uid);
    await txn.update(
      'wallets',
      wRow,
      where: 'id = ? AND uid = ?',
      whereArgs: [walletId, uid],
    );
    await SyncQueueWriter.enqueue(
      txn,
      ownerUid: uid,
      table: 'wallets',
      recordId: walletId,
      action: 'UPDATE',
      data: wRow,
    );
  }

  /// Thêm giao dịch mới vào SQLite + cập nhật số dư ví nguyên tử + enqueue sync
  Future<String> addTransaction(TransactionModel transaction) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final nowMs = nextMonotonicTimestamp(null);
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

    await db.transaction((txn) async {
      String resolvedWalletId = transaction.walletId;
      if (resolvedWalletId.isNotEmpty) {
        final exists = await txn.query(
          'wallets',
          columns: ['id'],
          where: 'id = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
          whereArgs: [resolvedWalletId, uid],
          limit: 1,
        );
        if (exists.isEmpty) resolvedWalletId = '';
      }
      if (resolvedWalletId.isEmpty) {
        final fallback = await txn.query(
          'wallets',
          columns: ['id'],
          where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
          whereArgs: [uid],
          orderBy: 'isDefault DESC, createdAt ASC',
          limit: 1,
        );
        if (fallback.isNotEmpty) {
          resolvedWalletId = fallback.first['id'] as String;
        }
      }

      final tx = transaction.copyWith(
        id: id,
        uid: uid,
        walletId: resolvedWalletId,
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

      if (resolvedWalletId.isNotEmpty) {
        final delta = tx.type == 'income' ? tx.amount : -tx.amount;
        await _adjustWalletBalanceInTxn(txn, resolvedWalletId, delta, uid);
      }
    });

    await WalletRepository().getWallets();
    await getAllTransactions();
    _notifyTransactionsChanged();
    WalletRepository().notifyChanged();

    unawaited(SyncService().syncAll());

    return id;
  }

  /// Insert giao dịch bên trong một Transaction đã có (để dùng với atomic service)
  Future<String> addTransactionInTxn(
    DatabaseExecutor txn,
    TransactionModel transaction,
  ) async {
    final uid = session.requireUid();
    final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
    final nowMs = nextMonotonicTimestamp(null);
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

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

  /// Cập nhật giao dịch + cân đối số dư ví nguyên tử
  Future<void> updateTransaction(TransactionModel transaction) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'transactions',
        where: 'id = ? AND uid = ?',
        whereArgs: [transaction.id, uid],
        limit: 1,
      );
      int? prevUpdatedMs;
      if (oldRows.isNotEmpty) {
        final oldTx = TransactionModel.fromSqlite(oldRows.first);
        prevUpdatedMs = oldTx.updatedAt.millisecondsSinceEpoch;
        if (oldTx.walletId.isNotEmpty) {
          final revertDelta = oldTx.type == 'income'
              ? -oldTx.amount
              : oldTx.amount;
          await _adjustWalletBalanceInTxn(txn, oldTx.walletId, revertDelta, uid);
        }
      }

      if (transaction.walletId.isNotEmpty) {
        final applyDelta = transaction.type == 'income'
            ? transaction.amount
            : -transaction.amount;
        await _adjustWalletBalanceInTxn(
          txn,
          transaction.walletId,
          applyDelta,
          uid,
        );
      }

      final nextMs = nextMonotonicTimestamp(prevUpdatedMs);
      final updated = transaction.copyWith(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(nextMs),
        syncStatus: 'pending',
      );
      final row = stampOwner(updated.toSqlite(), uid);

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

    await WalletRepository().getWallets();
    await getAllTransactions();
    _notifyTransactionsChanged();
    WalletRepository().notifyChanged();

    unawaited(SyncService().syncAll());
  }

  /// Xóa giao dịch (áp dụng Soft Delete / Tombstone và hoàn lại số dư ví nguyên tử)
  Future<void> deleteTransaction(String transactionId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    bool goalUpdated = false;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ? AND uid = ?',
        whereArgs: [transactionId, uid],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final tx = TransactionModel.fromSqlite(rows.first);

        // 1. Hoàn lại số dư ví nếu giao dịch có gắn walletId (dùng timestamp tịnh tiến)
        if (tx.walletId.isNotEmpty) {
          final revertDelta = (tx.type == 'income') ? -tx.amount : tx.amount;
          await _adjustWalletBalanceInTxn(txn, tx.walletId, revertDelta, uid);
        }

        // 1b. Nếu giao dịch liên kết mục tiêu tiết kiệm (goalId), hoàn lại goals.currentAmount
        if (tx.goalId != null && tx.goalId!.isNotEmpty) {
          final goalRows = await txn.query(
            'goals',
            where: 'id = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
            whereArgs: [tx.goalId, uid],
            limit: 1,
          );
          if (goalRows.isNotEmpty) {
            final goal = GoalModel.fromSqlite(goalRows.first);
            final revertGoalDelta = (tx.type == 'expense')
                ? -tx.amount
                : tx.amount;
            final nextAmount = FinancePrecision.roundCurrency(
              (goal.currentAmount + revertGoalDelta).clamp(0.0, double.infinity),
            );
            final goalNowMs = nextMonotonicTimestamp(
              goal.updatedAt.millisecondsSinceEpoch,
            );
            final updatedGoal = goal.copyWith(
              currentAmount: nextAmount,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(goalNowMs),
              syncStatus: 'pending',
            );
            final goalMap = stampOwner(updatedGoal.toSqlite(), uid);
            await updateOwned(txn, 'goals', goal.id, goalMap, uid);
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: uid,
              table: 'goals',
              recordId: goal.id,
              action: 'UPDATE',
              data: goalMap,
            );
            goalUpdated = true;
          }
        }

        // 2. Nếu là giao dịch chuyển tiền hai chiều, tìm và hoàn lại đầu đối ứng
        if (tx.isTransfer) {
          List<Map<String, dynamic>> pairedRows = [];
          if (tx.transferId != null && tx.transferId!.isNotEmpty) {
            pairedRows = await txn.query(
              'transactions',
              where:
                  'uid = ? AND transferId = ? AND id != ? AND (isDeleted IS NULL OR isDeleted = 0)',
              whereArgs: [uid, tx.transferId, tx.id],
            );
          }

          for (final row in pairedRows) {
            final pairedTx = TransactionModel.fromSqlite(row);
            if (pairedTx.walletId.isNotEmpty) {
              final pairedRevertDelta = (pairedTx.type == 'income')
                  ? -pairedTx.amount
                  : pairedTx.amount;
              await _adjustWalletBalanceInTxn(
                txn,
                pairedTx.walletId,
                pairedRevertDelta,
                uid,
              );
            }
            final pairedNowMs = nextMonotonicTimestamp(
              pairedTx.updatedAt.millisecondsSinceEpoch,
            );
            final pairedTombstone = <String, Object?>{
              'id': pairedTx.id,
              'uid': uid,
              'isDeleted': 1,
              'deletedAt': pairedNowMs,
              'updatedAt': pairedNowMs,
              'syncStatus': 'pending',
            };
            await txn.update(
              'transactions',
              {
                'isDeleted': 1,
                'deletedAt': pairedNowMs,
                'updatedAt': pairedNowMs,
                'syncStatus': 'pending',
              },
              where: 'id = ? AND uid = ?',
              whereArgs: [pairedTx.id, uid],
            );
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: uid,
              table: 'transactions',
              recordId: pairedTx.id,
              action: 'SOFT_DELETE',
              data: pairedTombstone,
            );
          }
        }
      }

      await softDeleteOwned(txn, 'transactions', transactionId, uid);
      final deletedRow = await findOwned(txn, 'transactions', transactionId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: transactionId,
        action: 'SOFT_DELETE',
        data: deletedRow != null ? Map<String, Object?>.from(deletedRow) : null,
      );
    });

    await WalletRepository().getWallets();
    await getAllTransactions();
    _notifyTransactionsChanged();
    WalletRepository().notifyChanged();
    if (goalUpdated) {
      GoalRepository().notifyChanged();
    }

    unawaited(SyncService().syncAll());
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

  /// Cập nhật ảnh cho giao dịch (enqueue full-row payload)
  Future<void> updateTransactionPhoto({
    required String transactionId,
    String? photoUrl,
    String? photoStoragePath,
    String? photoLocalPath,
  }) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final existing = await findOwned(txn, 'transactions', transactionId, uid);
      if (existing == null) return;

      final prevUpdatedMs = existing['updatedAt'] as int?;
      final nowMs = nextMonotonicTimestamp(prevUpdatedMs);

      final fullRow = Map<String, dynamic>.from(existing);
      fullRow['hasPhoto'] = 1;
      fullRow['updatedAt'] = nowMs;
      fullRow['syncStatus'] = 'pending';
      if (photoUrl != null) fullRow['photoUrl'] = photoUrl;
      if (photoStoragePath != null) {
        fullRow['photoStoragePath'] = photoStoragePath;
      }
      if (photoLocalPath != null) fullRow['photoLocalPath'] = photoLocalPath;

      final stamped = stampOwner(fullRow, uid);
      await updateOwned(txn, 'transactions', transactionId, stamped, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: transactionId,
        action: 'UPDATE',
        data: stamped,
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

    await db.transaction((txn) async {
      for (final row in rows) {
        final existingTx = TransactionModel.fromSqlite(row);
        final nextMs = nextMonotonicTimestamp(
          existingTx.updatedAt.millisecondsSinceEpoch,
        );
        final updated = existingTx.copyWith(
          category: newName,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nextMs),
          syncStatus: 'pending',
        );
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
  Stream<List<TransactionModel>> getTransactionsStream({int? limit}) {
    return (() async* {
      if (_cachedTransactions.isNotEmpty) {
        yield limit != null
            ? _cachedTransactions.take(limit).toList()
            : latestTransactions;
      }
      yield await getAllTransactions(limit: limit);
      await for (final list in _transactionsController.stream) {
        yield limit != null ? list.take(limit).toList() : list;
      }
    })().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  /// Stream tổng số dư, tổng thu, tổng chi
  Stream<({double balance, double totalIncome, double totalExpense})>
  getBalanceStream() {
    return (() async* {
      yield await _calculateBalance();
      await for (final _ in _changeStream.stream) {
        yield await _calculateBalance();
      }
    })().asBroadcastStream(onCancel: (sub) => sub.cancel());
  }

  /// Stream các giao dịch có ảnh (dùng cho Gallery)
  Stream<List<TransactionModel>> getTransactionsWithPhotosStream() {
    return getTransactionsStream()
        .map((list) => list.where((tx) => tx.hasPhoto).toList())
        .asBroadcastStream(onCancel: (sub) => sub.cancel());
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

  /// Upsert nhiều giao dịch từ Firestore theo batch (áp dụng Local Dirty Shield và Soft Delete)
  Future<void> upsertFromFirestore(List<TransactionModel> transactions) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || transactions.isEmpty) return;

    final ownedTxs = transactions
        .where((tx) => tx.uid == currentUid && tx.id.isNotEmpty)
        .toList();
    if (ownedTxs.isEmpty) return;

    final db = await _dbHelper.database;
    var hasChanges = false;

    await db.transaction((txn) async {
      // 1. Preload toàn bộ recordId đang pending/processing trong sync_queue (1 query thay vì N queries)
      final queueRows = await txn.query(
        'sync_queue',
        columns: ['recordId'],
        where:
            'tableName = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
        whereArgs: ['transactions', currentUid, currentUid, 'pending', 'processing'],
      );
      final pendingIds = <String>{
        for (final r in queueRows)
          if (r['recordId'] is String) r['recordId'] as String,
      };

      // 2. Preload bản ghi local hiện có theo từng chunk 450 ID (tránh giới hạn 999 bind params)
      final existingById = <String, Map<String, Object?>>{};
      final ids = ownedTxs.map((t) => t.id).toSet().toList();
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          'transactions',
          where: 'uid = ? AND id IN ($placeholders)',
          whereArgs: [currentUid, ...chunk],
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id != null) existingById[id] = row;
        }
      }

      final batch = txn.batch();
      for (final tx in ownedTxs) {
        // Local Dirty Shield
        if (pendingIds.contains(tx.id)) continue;

        final existingRow = existingById[tx.id];
        if (existingRow == null) {
          if (!tx.isDeleted) {
            batch.insert(
              'transactions',
              tx.copyWith(syncStatus: 'synced').toSqlite(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            hasChanges = true;
          }
        } else {
          final local = TransactionModel.fromSqlite(existingRow);
          if (local.syncStatus == 'pending') continue; // Dirty Shield

          // Quy tắc Monotonic Delete: Nếu local đã xóa mềm, chỉ chấp nhận khôi phục nếu remote mới hơn thời điểm xóa
          if (local.isDeleted && !tx.isDeleted) {
            final localDeletedMs = local.deletedAt?.millisecondsSinceEpoch ??
                local.updatedAt.millisecondsSinceEpoch;
            if (!tx.updatedAt.isAfter(
              DateTime.fromMillisecondsSinceEpoch(localDeletedMs),
            )) {
              continue; // Local Tombstone wins
            }
          }

          final shouldWin = ConflictResolver.shouldRemoteWin(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: tx.updatedAt,
            localData: local.toSqlite(),
            remoteData: tx.toSqlite(),
          );

          if (shouldWin) {
            if (tx.isDeleted) {
              final remoteDeletedMs = tx.deletedAt?.millisecondsSinceEpoch ??
                  tx.updatedAt.millisecondsSinceEpoch;
              final effectiveUpdatedMs =
                  tx.updatedAt.millisecondsSinceEpoch > remoteDeletedMs
                      ? tx.updatedAt.millisecondsSinceEpoch
                      : remoteDeletedMs;

              batch.update(
                'transactions',
                {
                  'isDeleted': 1,
                  'deletedAt': remoteDeletedMs,
                  'updatedAt': effectiveUpdatedMs,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [tx.id, currentUid],
              );
            } else {
              batch.update(
                'transactions',
                tx.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [tx.id, currentUid],
              );
            }
            hasChanges = true;
          }
        }
      }

      if (hasChanges) {
        await batch.commit(noResult: true);
      }
    });

    if (hasChanges) {
      await WalletRepository().recalculateWalletBalances(
        uid: currentUid,
        enqueueSync: false,
        notify: true,
      );
      await _refreshAndNotifyTransactions();
      WalletRepository().notifyChanged();
    }
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

  Future<void> _refreshAndNotifyTransactions() async {
    AiFinancialContextService().invalidateCache();
    await _loadAndEmitTransactions();
    await _loadAndEmitBalance();
    if (!_changeStream.isClosed) {
      _changeStream.add(null);
    }
  }

  void _notifyTransactionsChanged() {
    unawaited(_refreshAndNotifyTransactions());
  }

  void dispose() {
    _changeStream.close();
    _transactionsController.close();
    _balanceController.close();
  }
}
