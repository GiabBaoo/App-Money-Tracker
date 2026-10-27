import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/local/sync_queue_writer.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../dtos/create_expense_dto.dart';
import '../models/expense_model.dart';
import '../models/expense_split_model.dart';
import '../../domain/services/vnd_split_calculator.dart';

class SqliteExpenseRepository implements IExpenseRepository {
  final DatabaseHelper _dbHelper;
  final _changeController = StreamController<void>.broadcast();

  SqliteExpenseRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<ExpenseModel> create(CreateExpenseDto dto, String createdBy) async {
    final db = await _dbHelper.database;
    final expenseId = const Uuid().v4();
    final now = DateTime.now();
    final totalAmountVnd = dto.amount.round();

    // 1. Tính toán chia tiền
    Map<String, int> intSplits;
    if (dto.splitMethod == SplitMethod.equal) {
      intSplits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: totalAmountVnd,
        participantIds: dto.participantIds,
        payerId: dto.payerId,
      );
    } else if (dto.splitMethod == SplitMethod.custom &&
        dto.customShares != null) {
      intSplits = dto.customShares!.map((k, v) => MapEntry(k, v.round()));
    } else if (dto.splitMethod == SplitMethod.singlePayer) {
      intSplits = {dto.payerId: totalAmountVnd};
    } else {
      intSplits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: totalAmountVnd,
        participantIds: dto.participantIds,
        payerId: dto.payerId,
      );
    }

    final doubleShares = intSplits.map((k, v) => MapEntry(k, v.toDouble()));
    String? linkedTxId;

    await db.transaction((txn) async {
      // 2. Dual-Ledger: Nếu thanh toán từ ví cá nhân của Payer, tạo bản ghi transactions và trừ số dư ví
      if (dto.paidFromWalletId != null && dto.paidFromWalletId!.isNotEmpty) {
        linkedTxId = const Uuid().v4();
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
          'syncStatus': 'synced',
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

        await txn.insert('transactions', txRow);

        // Trừ số dư ví cá nhân
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance - ?, updatedAt = ? WHERE id = ?',
          [
            totalAmountVnd,
            now.toUtc().millisecondsSinceEpoch,
            dto.paidFromWalletId,
          ],
        );

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

      // 4. Ghi các bản ghi expense_splits
      for (final entry in intSplits.entries) {
        final splitModel = ExpenseSplitModel(
          id: const Uuid().v4(),
          expenseId: expenseId,
          userId: entry.key,
          shareAmount: entry.value,
          allocatedRemainder: 0,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert('expense_splits', splitModel.toSqflite());
      }

      // 5. Enqueue sync
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
          final walletId = txRows.first['walletId'] as String;
          await txn.update(
            'transactions',
            {
              'isDeleted': 1,
              'deletedAt': now.toUtc().millisecondsSinceEpoch,
              'updatedAt': now.toUtc().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [linkedTxId],
          );

          if (walletId.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE wallets SET balance = balance + ?, updatedAt = ? WHERE id = ?',
              [amount, now.toUtc().millisecondsSinceEpoch, walletId],
            );
          }
        }
      }

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: activeUid,
        table: 'group_expenses',
        recordId: id,
        action: 'DELETE',
        data: {'id': id, 'isDeleted': 1},
      );
    });

    _changeController.add(null);
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
}
