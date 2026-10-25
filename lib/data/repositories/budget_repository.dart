import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../models/budget_model.dart';
import 'transaction_repository.dart';

class BudgetRepository with OwnedTableOps {
  static final BudgetRepository _instance = BudgetRepository._internal();
  factory BudgetRepository() => _instance;

  BudgetRepository._internal() {
    session.changes.listen((_) {
      _notifyChanged();
    });
    // Tự động lắng nghe thay đổi từ transaction repository để cập nhật spentAmount
    TransactionRepository().getTransactionsStream().listen((_) {
      _notifyChanged();
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  final _budgetStreamController =
      StreamController<List<BudgetModel>>.broadcast();

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  Stream<List<BudgetModel>> getBudgetsStream({int? month, int? year}) {
    _notifyChanged(month: month, year: year);
    return _budgetStreamController.stream;
  }

  Future<void> _notifyChanged({int? month, int? year}) async {
    try {
      final budgets = await getBudgetsWithSpent(month: month, year: year);
      if (!_budgetStreamController.isClosed) {
        _budgetStreamController.add(budgets);
      }
    } catch (_) {}
  }

  Future<List<BudgetModel>> getBudgetsWithSpent({int? month, int? year}) async {
    final uid = session.uidOrNull;
    if (uid == null) return [];

    final targetMonth = month ?? DateTime.now().month;
    final targetYear = year ?? DateTime.now().year;

    List<BudgetModel> rawBudgets = [];
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'budgets',
        where:
            'uid = ? AND month = ? AND year = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid, targetMonth, targetYear],
        orderBy: 'createdAt DESC',
      );
      rawBudgets = maps.map((m) => BudgetModel.fromSqlite(m)).toList();
    } catch (e) {
      debugPrint('BudgetRepository.getBudgetsWithSpent error: $e');
      return [];
    }
    if (rawBudgets.isEmpty) return [];

    // Lấy tất cả giao dịch trong tháng để tính currentSpent cho từng budget
    final allTx = await TransactionRepository().getAllTransactions();
    final monthExpenseTx = allTx
        .where(
          (tx) =>
              tx.type == 'expense' &&
              !tx.isTransfer &&
              tx.date.month == targetMonth &&
              tx.date.year == targetYear,
        )
        .toList();

    return rawBudgets.map((b) {
      double spent = 0;
      if (b.category == 'Tất cả' || b.category.isEmpty) {
        spent = monthExpenseTx.fold(0.0, (sum, tx) => sum + tx.amount);
      } else {
        spent = monthExpenseTx
            .where(
              (tx) =>
                  tx.category.toLowerCase().trim() ==
                  b.category.toLowerCase().trim(),
            )
            .fold(0.0, (sum, tx) => sum + tx.amount);
      }
      return b.copyWith(currentSpent: spent);
    }).toList();
  }

  Future<String> addBudget(BudgetModel budget) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = budget.id.isEmpty ? _uuid.v4() : budget.id;

    final newBudget = budget.copyWith(id: id, syncStatus: 'pending');
    final row = stampOwner(newBudget.toSqlite(), uid);

    await db.transaction((txn) async {
      await txn.insert(
        'budgets',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'budgets',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    await _notifyChanged(month: budget.month, year: budget.year);
    return id;
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final updated = budget.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );
    final row = stampOwner(updated.toSqlite(), uid);

    await db.transaction((txn) async {
      await updateOwned(txn, 'budgets', budget.id, row, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'budgets',
        recordId: budget.id,
        action: 'UPDATE',
        data: row,
      );
    });

    await _notifyChanged(month: budget.month, year: budget.year);
  }

  /// Xóa ngân sách (áp dụng Soft Delete / Tombstone)
  Future<void> deleteBudget(String id, {int? month, int? year}) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'budgets', id, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'budgets',
        recordId: id,
        action: 'SOFT_DELETE',
      );
    });

    await _notifyChanged(month: month, year: year);
  }

  /// Đổi tên danh mục trong mọi ngân sách (khi user đổi tên danh mục tự tạo).
  Future<int> renameCategory({
    required String oldName,
    required String newName,
    int? iconCode,
  }) async {
    final uid = session.requireUid();
    if (oldName == newName) return 0;
    final db = await _dbHelper.database;
    final target = oldName.toLowerCase().trim();

    // SQLite LOWER() chỉ xử lý ASCII → lọc bằng Dart để đúng với tiếng Việt có dấu
    final rows = (await db.query('budgets', where: 'uid = ?', whereArgs: [uid]))
        .where(
          (r) =>
              ((r['category'] as String?) ?? '').toLowerCase().trim() == target,
        )
        .toList();
    if (rows.isEmpty) return 0;

    final now = DateTime.now();
    await db.transaction((txn) async {
      for (final row in rows) {
        final updated = BudgetModel.fromSqlite(row).copyWith(
          category: newName,
          categoryIconCode: iconCode,
          updatedAt: now,
          syncStatus: 'pending',
        );
        final values = updated.toSqlite();
        await updateOwned(txn, 'budgets', updated.id, values, uid);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'budgets',
          recordId: updated.id,
          action: 'UPDATE',
          data: values,
        );
      }
    });

    await _notifyChanged();
    return rows.length;
  }

  /// Upsert danh sách ngân sách từ Firestore vào SQLite (áp dụng Local Dirty Shield và Soft Delete)
  Future<void> upsertFromFirestore(List<BudgetModel> firestoreBudgets) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || firestoreBudgets.isEmpty) return;
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final fb in firestoreBudgets) {
        if (fb.uid != currentUid) continue;

        // 1. Dirty Shield: kiểm tra sync_queue
        final queuePending = await txn.query(
          'sync_queue',
          columns: ['id'],
          where:
              'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
          whereArgs: [
            'budgets',
            fb.id,
            currentUid,
            currentUid,
            'pending',
            'processing',
          ],
          limit: 1,
        );
        if (queuePending.isNotEmpty) continue;

        final existing = await txn.query(
          'budgets',
          where: 'id = ? AND uid = ?',
          whereArgs: [fb.id, currentUid],
          limit: 1,
        );

        if (existing.isEmpty) {
          if (!fb.isDeleted) {
            await txn.insert(
              'budgets',
              fb.copyWith(syncStatus: 'synced').toSqlite(),
            );
          }
        } else {
          final local = BudgetModel.fromSqlite(existing.first);
          if (local.syncStatus == 'pending') continue; // Dirty Shield

          final isRemoteNewer = fb.updatedAt.isAfter(local.updatedAt);
          final isSameTime = fb.updatedAt.isAtSameMomentAs(local.updatedAt);
          final winsTieBreak =
              isSameTime && _resolveTieBreaker(local.toSqlite(), fb.toSqlite());

          if (isRemoteNewer || winsTieBreak) {
            if (fb.isDeleted) {
              await txn.update(
                'budgets',
                {
                  'isDeleted': 1,
                  'deletedAt':
                      fb.deletedAt?.millisecondsSinceEpoch ??
                      DateTime.now().millisecondsSinceEpoch,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [fb.id, currentUid],
              );
            } else {
              await txn.update(
                'budgets',
                fb.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [fb.id, currentUid],
              );
            }
          }
        }
      }
    });

    await _notifyChanged();
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

  /// Upsert an toàn tuân thủ ISyncableRepository
  Future<void> upsertFromFirestoreSafe(List<BudgetModel> firestoreBudgets) =>
      upsertFromFirestore(firestoreBudgets);
}
