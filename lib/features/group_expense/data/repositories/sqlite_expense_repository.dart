import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/local/owned_table_ops.dart';
import '../../../../data/local/sync_queue_writer.dart';
import '../../../../models/wallet_model.dart';
import '../../../../utils/finance_precision.dart';
import '../../../../data/repositories/wallet_repository.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../services/connectivity_service.dart';
import '../../../../services/sync_service.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../dtos/create_expense_dto.dart';
import '../models/expense_model.dart';
import '../models/expense_split_model.dart';
import '../../domain/services/vnd_split_calculator.dart';

class SqliteExpenseRepository implements IExpenseRepository {
  final DatabaseHelper _dbHelper;
  final _changeController = StreamController<void>.broadcast();

  SqliteExpenseRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper() {
    SessionManager.instance.changes.listen((_) {
      _changeController.add(null);
    });
  }

  @override
  Future<ExpenseModel> create(CreateExpenseDto dto, String createdBy) async {
    final db = await _dbHelper.database;
    final expenseId = const Uuid().v4();
    final now = DateTime.now();
    final totalAmountVnd = dto.amount.round();

    // 1. Tính toán chia tiền qua VndSplitCalculator cho mọi kiểu chia
    final Map<String, int> intSplits;
    switch (dto.splitMethod) {
      case SplitMethod.equal:
        intSplits = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: totalAmountVnd,
          participantIds: dto.participantIds,
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.percentage:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu tỷ lệ phần trăm chia tiền');
        }
        intSplits = VndSplitCalculator.calculatePercentageSplit(
          totalAmountVnd: totalAmountVnd,
          percentages: dto.customShares!,
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.shares:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu số phần chia tiền');
        }
        intSplits = VndSplitCalculator.calculateSharesSplit(
          totalAmountVnd: totalAmountVnd,
          shares: dto.customShares!.map((k, v) => MapEntry(k, v.round())),
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.exact:
      case SplitMethod.custom:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu số tiền chia lẻ');
        }
        intSplits = VndSplitCalculator.calculateExactSplit(
          totalAmountVnd: totalAmountVnd,
          exactAmounts: dto.customShares!.map((k, v) => MapEntry(k, v.round())),
        );
        break;
      case SplitMethod.singlePayer:
        intSplits = {dto.payerId: totalAmountVnd};
        break;
    }

    final doubleShares = intSplits.map((k, v) => MapEntry(k, v.toDouble()));
    final currentUid = SessionManager.instance.uidOrNull ?? createdBy;
    String? linkedTxId;

    await db.transaction((txn) async {
      // 2. Dual-Ledger: CHỈ tạo transactions & trừ ví cá nhân khi payerId == currentUid
      if (dto.paidFromWalletId != null &&
          dto.paidFromWalletId!.isNotEmpty &&
          dto.payerId == currentUid) {
        linkedTxId = 'gtx_$expenseId';
        final txRow = {
          'id': linkedTxId,
          'uid': dto.payerId,
          'type': 'expense',
          'category': dto.category,
          'categoryIconCode': dto.categoryIconCode,
          'amount': totalAmountVnd,
          'date': dto.date.toUtc().millisecondsSinceEpoch,
          'time': '',
          'description': 'Chi tiền nhóm: ${dto.name}',
          'createdAt': now.toUtc().millisecondsSinceEpoch,
          'updatedAt': now.toUtc().millisecondsSinceEpoch,
          'hasPhoto': dto.photoUrls.isNotEmpty ? 1 : 0,
          'photoUrl': dto.photoUrls.isNotEmpty ? dto.photoUrls.first : '',
          'photoStoragePath': '',
          'photoLocalPath': '',
          'groupId': dto.groupId,
          'groupIconCode': null,
          'source': 'group',
          'syncStatus': 'pending',
          'walletId': dto.paidFromWalletId,
          'location': '',
          'latitude': null,
          'longitude': null,
          'transferId': null,
          'goalId': null,
          'groupExpenseId': expenseId,
          'isDeleted': 0,
          'deletedAt': null,
        };

        await txn.insert(
          'transactions',
          txRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Trừ số dư ví cá nhân (chuẩn Dual-Ledger với sync_queue)
        final wRows = await txn.query(
          'wallets',
          where: 'id = ? AND uid = ?',
          whereArgs: [dto.paidFromWalletId, dto.payerId],
          limit: 1,
        );
        if (wRows.isNotEmpty) {
          final w = WalletModel.fromSqlite(wRows.first);
          final newBal = FinancePrecision.roundCurrency(
            w.balance - totalAmountVnd,
            currency: w.currency,
          );
          final updatedW = w.copyWith(
            balance: newBal,
            updatedAt: now,
            syncStatus: 'pending',
          );
          final wRow = updatedW.toSqlite();
          await txn.update(
            'wallets',
            wRow,
            where: 'id = ? AND uid = ?',
            whereArgs: [dto.paidFromWalletId, dto.payerId],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: dto.payerId,
            table: 'wallets',
            recordId: dto.paidFromWalletId!,
            action: 'UPDATE',
            data: wRow,
          );
        }

        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: dto.payerId,
          table: 'transactions',
          recordId: linkedTxId!,
          action: 'INSERT',
          data: txRow,
        );
      }

      // 3. Ghi bản ghi group_expenses
      final expense = ExpenseModel(
        id: expenseId,
        groupId: dto.groupId,
        name: dto.name,
        amount: totalAmountVnd.toDouble(),
        payerId: dto.payerId,
        participantIds: dto.participantIds,
        splitMethod: dto.splitMethod,
        shares: doubleShares,
        category: dto.category,
        categoryIconCode: dto.categoryIconCode,
        date: dto.date,
        notes: dto.notes,
        photoUrls: dto.photoUrls,
        createdBy: createdBy,
        linkedTransactionId: linkedTxId,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('group_expenses', expense.toSqflite());

      // 4. Ghi các bản ghi expense_splits với Deterministic ID
      for (final entry in intSplits.entries) {
        final splitModel = ExpenseSplitModel(
          id: '${expenseId}_${entry.key}',
          expenseId: expenseId,
          userId: entry.key,
          shareAmount: entry.value,
          allocatedRemainder: 0,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert(
          'expense_splits',
          splitModel.toSqflite(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 5. Enqueue sync cho group_expenses
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: createdBy,
        table: 'group_expenses',
        recordId: expenseId,
        action: 'INSERT',
        data: expense.toJson(),
      );
    });

    _changeController.add(null);
    WalletRepository().notifyChanged();
    TransactionRepository().notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    return ExpenseModel(
      id: expenseId,
      groupId: dto.groupId,
      name: dto.name,
      amount: totalAmountVnd.toDouble(),
      payerId: dto.payerId,
      participantIds: dto.participantIds,
      splitMethod: dto.splitMethod,
      shares: doubleShares,
      category: dto.category,
      categoryIconCode: dto.categoryIconCode,
      date: dto.date,
      notes: dto.notes,
      photoUrls: dto.photoUrls,
      createdBy: createdBy,
      linkedTransactionId: linkedTxId,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ExpenseModel> getById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'group_expenses',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Expense not found');

    final splitRows = await db.query(
      'expense_splits',
      where: 'expenseId = ?',
      whereArgs: [id],
    );

    final shares = <String, double>{};
    for (final s in splitRows) {
      shares[s['userId'] as String] = (s['shareAmount'] as num).toDouble();
    }

    return ExpenseModel.fromSqflite(
      rows.first,
      participants: shares.keys.toList(),
      shares: shares,
    );
  }

  @override
  Future<List<ExpenseModel>> getByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'group_expenses',
      where: 'groupId = ? AND isDeleted = 0',
      whereArgs: [groupId],
      orderBy: 'date DESC',
    );

    final expenses = <ExpenseModel>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final splitRows = await db.query(
        'expense_splits',
        where: 'expenseId = ?',
        whereArgs: [id],
      );
      final shares = <String, double>{};
      for (final s in splitRows) {
        shares[s['userId'] as String] = (s['shareAmount'] as num).toDouble();
      }

      expenses.add(
        ExpenseModel.fromSqflite(
          row,
          participants: shares.keys.toList(),
          shares: shares,
        ),
      );
    }

    return expenses;
  }

  @override
  Stream<List<ExpenseModel>> watchByGroupId(String groupId) {
    late StreamController<List<ExpenseModel>> controller;

    void updateList() async {
      try {
        final list = await getByGroupId(groupId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    StreamSubscription? sub;
    controller = StreamController<List<ExpenseModel>>.broadcast(
      onListen: () {
        updateList();
        sub = _changeController.stream.listen((_) => updateList());
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> update(ExpenseModel expense) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final activeUid = SessionManager.instance.uidOrNull ?? expense.createdBy;

    await db.transaction((txn) async {
      final updated = expense.copyWith(updatedAt: now);
      await txn.update(
        'group_expenses',
        updated.toSqflite(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );

      // Cập nhật lại expense_splits khớp với expense.shares mới
      await txn.delete(
        'expense_splits',
        where: 'expenseId = ?',
        whereArgs: [expense.id],
      );
      for (final entry in updated.shares.entries) {
        final splitModel = ExpenseSplitModel(
          id: '${expense.id}_${entry.key}',
          expenseId: expense.id,
          userId: entry.key,
          shareAmount: entry.value.round(),
          allocatedRemainder: 0,
          createdAt: updated.createdAt,
          updatedAt: now,
        );
        await txn.insert(
          'expense_splits',
          splitModel.toSqflite(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: activeUid,
        table: 'group_expenses',
        recordId: expense.id,
        action: 'UPDATE',
        data: updated.toJson(),
      );
    });

    _changeController.add(null);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'group_expenses',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;

      final expenseRow = rows.first;
      final linkedTxId = expenseRow['linkedTransactionId'] as String?;
      final amount = expenseRow['amount'] as int;
      final createdBy = expenseRow['createdBy'] as String;
      final activeUid = SessionManager.instance.uidOrNull ?? createdBy;

      // Soft delete group expense
      await txn.update(
        'group_expenses',
        {
          'isDeleted': 1,
          'deletedAt': now.toUtc().millisecondsSinceEpoch,
          'updatedAt': now.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Nếu có liên kết giao dịch cá nhân: hoàn lại số dư ví cá nhân
      if (linkedTxId != null && linkedTxId.isNotEmpty) {
        final txRows = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [linkedTxId],
        );
        if (txRows.isNotEmpty) {
          final txUid = (txRows.first['uid'] as String?) ?? activeUid;
          final walletId = txRows.first['walletId'] as String;
          await txn.update(
            'transactions',
            {
              'isDeleted': 1,
              'deletedAt': now.toUtc().millisecondsSinceEpoch,
              'updatedAt': now.toUtc().millisecondsSinceEpoch,
              'syncStatus': 'pending',
            },
            where: 'id = ?',
            whereArgs: [linkedTxId],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: txUid,
            table: 'transactions',
            recordId: linkedTxId,
            action: 'SOFT_DELETE',
          );

          if (walletId.isNotEmpty) {
            final wRows = await txn.query(
              'wallets',
              where: 'id = ?',
              whereArgs: [walletId],
              limit: 1,
            );
            if (wRows.isNotEmpty) {
              final w = WalletModel.fromSqlite(wRows.first);
              final newBal = FinancePrecision.roundCurrency(
                w.balance + amount,
                currency: w.currency,
              );
              final updatedW = w.copyWith(
                balance: newBal,
                updatedAt: now,
                syncStatus: 'pending',
              );
              final wRow = updatedW.toSqlite();
              await txn.update(
                'wallets',
                wRow,
                where: 'id = ?',
                whereArgs: [walletId],
              );
              await SyncQueueWriter.enqueue(
                txn,
                ownerUid: w.uid.isNotEmpty ? w.uid : activeUid,
                table: 'wallets',
                recordId: walletId,
                action: 'UPDATE',
                data: wRow,
              );
            }
          }
        }
      }

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: activeUid,
        table: 'group_expenses',
        recordId: id,
        action: 'SOFT_DELETE',
        data: {'id': id, 'isDeleted': 1},
      );
    });

    _changeController.add(null);
    WalletRepository().notifyChanged();
    TransactionRepository().notifyTransactionsChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  Future<List<ExpenseSplitModel>> getSplits(String expenseId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'expense_splits',
      where: 'expenseId = ?',
      whereArgs: [expenseId],
    );
    return rows.map((r) => ExpenseSplitModel.fromSqflite(r)).toList();
  }

  /// Upsert danh sách chi tiêu nhóm và các phần chia (splits) từ Firestore về SQLite
  Future<void> upsertFromFirestore(List<ExpenseModel> expenses) async {
    if (expenses.isEmpty) return;
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final exp in expenses) {
        // Dirty shield
        final pendingQueue = await txn.query(
          'sync_queue',
          columns: ['id'],
          where: "tableName = 'group_expenses' AND recordId = ? AND status IN ('pending', 'processing')",
          whereArgs: [exp.id],
          limit: 1,
        );
        if (pendingQueue.isNotEmpty) continue;

        final existing = await txn.query(
          'group_expenses',
          where: 'id = ?',
          whereArgs: [exp.id],
          limit: 1,
        );

        if (existing.isEmpty) {
          if (!exp.isDeleted) {
            await txn.insert('group_expenses', exp.toSqflite());
          }
        } else {
          final local = ExpenseModel.fromSqflite(existing.first);
          if (local.syncStatus == 'pending') continue;

          final shouldWin = ConflictResolver.shouldRemoteWin(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: exp.updatedAt,
            localData: local.toSqflite(),
            remoteData: exp.toSqflite(),
          );

          if (shouldWin) {
            if (exp.isDeleted) {
              await txn.update(
                'group_expenses',
                {
                  'isDeleted': 1,
                  'deletedAt': (exp.deletedAt ?? exp.updatedAt).toUtc().millisecondsSinceEpoch,
                  'updatedAt': exp.updatedAt.toUtc().millisecondsSinceEpoch,
                  'syncStatus': 'synced',
                },
                where: 'id = ?',
                whereArgs: [exp.id],
              );
            } else {
              await txn.update(
                'group_expenses',
                exp.toSqflite(),
                where: 'id = ?',
                whereArgs: [exp.id],
              );
            }
          }
        }

        // Đồng bộ expense_splits (upsert mới & xóa splits không còn trên cloud)
        if (!exp.isDeleted && exp.shares.isNotEmpty) {
          for (final entry in exp.shares.entries) {
            final splitId = '${exp.id}_${entry.key}';
            await txn.rawInsert(
              '''
              INSERT INTO expense_splits (id, expenseId, userId, shareAmount, allocatedRemainder, createdAt, updatedAt)
              VALUES (?, ?, ?, ?, 0, ?, ?)
              ON CONFLICT(expenseId, userId) DO UPDATE SET
                shareAmount = ?,
                updatedAt = ?
              ''',
              [
                splitId,
                exp.id,
                entry.key,
                entry.value.round(),
                exp.createdAt.toUtc().millisecondsSinceEpoch,
                exp.updatedAt.toUtc().millisecondsSinceEpoch,
                entry.value.round(),
                exp.updatedAt.toUtc().millisecondsSinceEpoch,
              ],
            );
          }

          final splitUsers = exp.shares.keys.toList();
          final placeholders = List.filled(splitUsers.length, '?').join(',');
          await txn.delete(
            'expense_splits',
            where: 'expenseId = ? AND userId NOT IN ($placeholders)',
            whereArgs: [exp.id, ...splitUsers],
          );
        }
      }
    });

    _changeController.add(null);
  }
}
