import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../models/goal_model.dart';
import '../../core/logging/app_logger.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';
import '../../services/sync_trigger.dart';
import '../../utils/finance_precision.dart';
import 'wallet_repository.dart';
import 'transaction_repository.dart';

class GoalRepository with OwnedTableOps {
  static final GoalRepository _instance = GoalRepository._internal();
  factory GoalRepository() => _instance;

  GoalRepository._internal() {
    session.changes.listen((_) {
      _notifyChanged();
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  final _goalStreamController = StreamController<List<GoalModel>>.broadcast();

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  Stream<List<GoalModel>> getGoalsStream() {
    _notifyChanged();
    return _goalStreamController.stream;
  }

  /// Phát thông báo thay đổi mục tiêu ra bên ngoài
  void notifyChanged() => _notifyChanged();

  Future<void> _notifyChanged() async {
    try {
      final goals = await getAllGoals();
      if (!_goalStreamController.isClosed) {
        _goalStreamController.add(goals);
      }
    } catch (e, st) {
      AppLogger.warn('Lỗi emit stream goal', tag: 'GoalRepository', error: e, stackTrace: st);
    }
  }

  Future<List<GoalModel>> getAllGoals() async {
    final uid = session.uidOrNull;
    if (uid == null) return []; // fail-closed READ

    final db = await _dbHelper.database;
    final maps = await db.query(
      'goals',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
      orderBy: 'deadline ASC',
    );

    return maps.map((m) => GoalModel.fromSqlite(m)).toList();
  }

  Future<String> addGoal(GoalModel goal) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;

    final newGoal = goal.copyWith(id: id, syncStatus: 'pending');
    final row = stampOwner(newGoal.toSqlite(), uid);

    await db.transaction((txn) async {
      await txn.insert(
        'goals',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'goals',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    await _notifyChanged();
    SyncTrigger.requestSync();
    return id;
  }

  Future<void> updateGoal(GoalModel goal) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final updated = goal.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );
    final row = stampOwner(updated.toSqlite(), uid);

    await db.transaction((txn) async {
      await updateOwned(txn, 'goals', goal.id, row, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'goals',
        recordId: goal.id,
        action: 'UPDATE',
        data: row,
      );
    });

    await _notifyChanged();
    SyncTrigger.requestSync();
  }

  /// Xóa mục tiêu (áp dụng Soft Delete / Tombstone)
  Future<void> deleteGoal(String id) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'goals', id, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'goals',
        recordId: id,
        action: 'SOFT_DELETE',
      );
    });

    await _notifyChanged();
    SyncTrigger.requestSync();
  }

  /// Nạp tiền tiết kiệm vào mục tiêu (Bảo đảm đối ứng 1:1 với ví nguồn)
  Future<void> depositToGoal(
    String goalId,
    double amount, {
    required String walletId,
  }) async {
    if (amount <= 0) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền nạp mục tiêu phải lớn hơn 0',
      );
    }
    if (walletId.trim().isEmpty) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Phải chọn ví nguồn khi nạp tiền vào mục tiêu',
      );
    }
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final goalRow = await findOwned(txn, 'goals', goalId, uid);
      if (goalRow == null) {
        throw const BusinessException(
          BusinessErrorCode.notFound,
          'Không tìm thấy mục tiêu tài chính',
        );
      }
      final goal = GoalModel.fromSqlite(goalRow);

      // Trừ số dư ví nếu chọn ví cụ thể và tạo bút toán sổ cái tương ứng
      if (walletId.isNotEmpty) {
        final walletRow = await findOwned(txn, 'wallets', walletId, uid);
        if (walletRow == null) {
          throw const BusinessException(
            BusinessErrorCode.notFound,
            'Không tìm thấy ví nguồn',
          );
        }
        final wallet = WalletModel.fromSqlite(walletRow);
        if (wallet.balance < amount) {
          throw const BusinessException(
            BusinessErrorCode.insufficientBalance,
            'Số dư ví nguồn không đủ để nạp vào mục tiêu',
          );
        }

        final newWalletBalance = FinancePrecision.roundCurrency(
          wallet.balance - amount,
          currency: wallet.currency,
        );
        final updatedWallet = wallet.copyWith(
          balance: newWalletBalance,
          updatedAt: now,
          syncStatus: 'pending',
        );
        final walletMap = updatedWallet.toSqlite();
        await updateOwned(txn, 'wallets', walletId, walletMap, uid);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'wallets',
          recordId: walletId,
          action: 'UPDATE',
          data: walletMap,
        );

        // Bút toán sổ cái: Expense - Tiết kiệm (gắn liền với goalId)
        final expenseTx = TransactionModel(
          id: _uuid.v4(),
          uid: uid,
          type: 'expense',
          category: 'Tiết kiệm',
          categoryIconCode: Icons.savings_outlined.codePoint,
          amount: amount,
          date: now,
          time:
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          description: 'Tích lũy mục tiêu: ${goal.title}',
          walletId: walletId,
          goalId: goalId,
          source: 'personal',
          syncStatus: 'pending',
        );
        final expenseRow = stampOwner(expenseTx.toSqlite(), uid);
        await txn.insert('transactions', expenseRow);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'transactions',
          recordId: expenseTx.id,
          action: 'INSERT',
          data: expenseRow,
        );
      }

      // Cập nhật số tiền hiện tại của mục tiêu
      final newCurrentAmount = FinancePrecision.roundCurrency(
        goal.currentAmount + amount,
      );
      final updatedGoal = goal.copyWith(
        currentAmount: newCurrentAmount,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final goalMap = updatedGoal.toSqlite();
      await updateOwned(txn, 'goals', goalId, goalMap, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'goals',
        recordId: goalId,
        action: 'UPDATE',
        data: goalMap,
      );
    });

    await _notifyChanged();
    if (walletId.isNotEmpty) {
      WalletRepository().notifyChanged();
      TransactionRepository().notifyTransactionsChanged();
    }
    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Rút tiền từ mục tiêu về ví (Ngăn chặn tiền ảo - No Phantom Money)
  Future<void> withdrawFromGoal(
    String goalId,
    double amount, {
    required String walletId,
  }) async {
    if (amount <= 0) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền rút mục tiêu phải lớn hơn 0',
      );
    }
    if (walletId.trim().isEmpty) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Phải chọn ví nhận khi rút tiền từ mục tiêu',
      );
    }
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final goalRow = await findOwned(txn, 'goals', goalId, uid);
      if (goalRow == null) {
        throw const BusinessException(
          BusinessErrorCode.notFound,
          'Không tìm thấy mục tiêu tài chính',
        );
      }
      final goal = GoalModel.fromSqlite(goalRow);

      // Chặn rút vượt quá số dư hiện có của mục tiêu (Triệt tiêu tiền ảo)
      if (goal.currentAmount < amount) {
        throw const BusinessException(
          BusinessErrorCode.invalidAmount,
          'Số tiền rút vượt quá số dư hiện tại của mục tiêu',
        );
      }

      // Cập nhật số dư mục tiêu (Không dùng .clamp())
      final newCurrentAmount = FinancePrecision.roundCurrency(
        goal.currentAmount - amount,
      );
      final updatedGoal = goal.copyWith(
        currentAmount: newCurrentAmount,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final goalMap = updatedGoal.toSqlite();
      await updateOwned(txn, 'goals', goalId, goalMap, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'goals',
        recordId: goalId,
        action: 'UPDATE',
        data: goalMap,
      );

      // Cộng số dư ví nếu chọn ví cụ thể và tạo bút toán sổ cái tương ứng
      if (walletId.isNotEmpty) {
        final walletRow = await findOwned(txn, 'wallets', walletId, uid);
        if (walletRow == null) {
          throw const BusinessException(
            BusinessErrorCode.notFound,
            'Không tìm thấy ví nhận tiền',
          );
        }
        final wallet = WalletModel.fromSqlite(walletRow);
        final newWalletBalance = FinancePrecision.roundCurrency(
          wallet.balance + amount,
          currency: wallet.currency,
        );
        final updatedWallet = wallet.copyWith(
          balance: newWalletBalance,
          updatedAt: now,
          syncStatus: 'pending',
        );
        final walletMap = updatedWallet.toSqlite();
        await updateOwned(txn, 'wallets', walletId, walletMap, uid);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'wallets',
          recordId: walletId,
          action: 'UPDATE',
          data: walletMap,
        );

        // Bút toán sổ cái: Income - Rút tiết kiệm (gắn liền với goalId)
        final incomeTx = TransactionModel(
          id: _uuid.v4(),
          uid: uid,
          type: 'income',
          category: 'Rút tiết kiệm',
          categoryIconCode: Icons.savings_rounded.codePoint,
          amount: amount,
          date: now,
          time:
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          description: 'Rút tiền từ mục tiêu: ${goal.title}',
          walletId: walletId,
          goalId: goalId,
          source: 'personal',
          syncStatus: 'pending',
        );
        final incomeRow = stampOwner(incomeTx.toSqlite(), uid);
        await txn.insert('transactions', incomeRow);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'transactions',
          recordId: incomeTx.id,
          action: 'INSERT',
          data: incomeRow,
        );
      }
    });

    await _notifyChanged();
    if (walletId.isNotEmpty) {
      WalletRepository().notifyChanged();
      TransactionRepository().notifyTransactionsChanged();
    }
    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Upsert danh sách mục tiêu từ Firestore vào SQLite theo batch (áp dụng Local Dirty Shield và Soft Delete)
  Future<void> upsertFromFirestore(List<GoalModel> firestoreGoals) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || firestoreGoals.isEmpty) return;

    final ownedGoals = firestoreGoals
        .where((fg) => fg.uid == currentUid && fg.id.isNotEmpty)
        .toList();
    if (ownedGoals.isEmpty) return;

    final db = await _dbHelper.database;
    var hasChanges = false;

    await db.transaction((txn) async {
      final queueRows = await txn.query(
        'sync_queue',
        columns: ['recordId'],
        where:
            'tableName = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
        whereArgs: ['goals', currentUid, currentUid, 'pending', 'processing'],
      );
      final pendingIds = <String>{
        for (final r in queueRows)
          if (r['recordId'] is String) r['recordId'] as String,
      };

      final existingById = <String, Map<String, Object?>>{};
      final ids = ownedGoals.map((g) => g.id).toSet().toList();
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          i + chunkSize > ids.length ? ids.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          'goals',
          where: 'uid = ? AND id IN ($placeholders)',
          whereArgs: [currentUid, ...chunk],
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id != null) existingById[id] = row;
        }
      }

      final batch = txn.batch();
      for (final fg in ownedGoals) {
        if (pendingIds.contains(fg.id)) continue;

        final existingRow = existingById[fg.id];
        if (existingRow == null) {
          if (!fg.isDeleted) {
            batch.insert(
              'goals',
              fg.copyWith(syncStatus: 'synced').toSqlite(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            hasChanges = true;
          }
        } else {
          final local = GoalModel.fromSqlite(existingRow);
          if (local.syncStatus == 'pending') continue; // Dirty Shield

          // Monotonic Delete Rule
          if (local.isDeleted && !fg.isDeleted) {
            final localDeletedMs = local.deletedAt?.millisecondsSinceEpoch ??
                local.updatedAt.millisecondsSinceEpoch;
            if (!fg.updatedAt.isAfter(
              DateTime.fromMillisecondsSinceEpoch(localDeletedMs),
            )) {
              continue; // Local Tombstone wins
            }
          }

          final shouldWin = ConflictResolver.shouldRemoteWin(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: fg.updatedAt,
            localData: local.toSqlite(),
            remoteData: fg.toSqlite(),
          );

          if (shouldWin) {
            if (fg.isDeleted) {
              final remoteDeletedMs = fg.deletedAt?.millisecondsSinceEpoch ??
                  fg.updatedAt.millisecondsSinceEpoch;
              final effectiveUpdatedMs =
                  fg.updatedAt.millisecondsSinceEpoch > remoteDeletedMs
                      ? fg.updatedAt.millisecondsSinceEpoch
                      : remoteDeletedMs;

              batch.update(
                'goals',
                {
                  'isDeleted': 1,
                  'deletedAt': remoteDeletedMs,
                  'updatedAt': effectiveUpdatedMs,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [fg.id, currentUid],
              );
            } else {
              batch.update(
                'goals',
                fg.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [fg.id, currentUid],
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
      await _notifyChanged();
    }
  }

  /// Upsert an toàn tuân thủ ISyncableRepository
  Future<void> upsertFromFirestoreSafe(List<GoalModel> firestoreGoals) =>
      upsertFromFirestore(firestoreGoals);
}
