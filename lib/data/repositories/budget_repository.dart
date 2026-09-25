import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/budget_model.dart';
import '../../services/auth_service.dart';
import 'transaction_repository.dart';

class BudgetRepository {
  static final BudgetRepository _instance = BudgetRepository._internal();
  factory BudgetRepository() => _instance;
  BudgetRepository._internal() {
    // Tự động lắng nghe thay đổi từ transaction repository để cập nhật spentAmount
    TransactionRepository().getTransactionsStream().listen((_) {
      _notifyChanged();
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  final _budgetStreamController = StreamController<List<BudgetModel>>.broadcast();

  String? _explicitUid;
  String? get _currentUid => _explicitUid ?? AuthService().currentUid;

  void setUid(String uid) {
    _explicitUid = uid;
    _notifyChanged();
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
    final uid = _currentUid;
    if (uid == null) return [];

    final targetMonth = month ?? DateTime.now().month;
    final targetYear = year ?? DateTime.now().year;

    final db = await _dbHelper.database;
    final maps = await db.query(
      'budgets',
      where: 'uid = ? AND month = ? AND year = ?',
      whereArgs: [uid, targetMonth, targetYear],
      orderBy: 'createdAt DESC',
    );

    final rawBudgets = maps.map((m) => BudgetModel.fromSqlite(m)).toList();
    if (rawBudgets.isEmpty) return [];

    // Lấy tất cả giao dịch trong tháng để tính currentSpent cho từng budget
    final allTx = await TransactionRepository().getAllTransactions();
    final monthExpenseTx = allTx.where((tx) =>
      tx.type == 'expense' &&
      !tx.isTransfer &&
      tx.date.month == targetMonth &&
      tx.date.year == targetYear
    ).toList();

    return rawBudgets.map((b) {
      double spent = 0;
      if (b.category == 'Tất cả' || b.category.isEmpty) {
        spent = monthExpenseTx.fold(0.0, (sum, tx) => sum + tx.amount);
      } else {
        spent = monthExpenseTx
            .where((tx) => tx.category.toLowerCase().trim() == b.category.toLowerCase().trim())
            .fold(0.0, (sum, tx) => sum + tx.amount);
      }
      return b.copyWith(currentSpent: spent);
    }).toList();
  }

  Future<String> addBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    final id = budget.id.isEmpty ? _uuid.v4() : budget.id;
    final uid = budget.uid.isEmpty ? (_currentUid ?? '') : budget.uid;

    final newBudget = budget.copyWith(
      id: id,
      uid: uid,
      syncStatus: 'pending',
    );

    await db.insert('budgets', newBudget.toSqlite(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Queue Firestore sync
    await _enqueueSyncAction('budgets', id, 'INSERT', newBudget.toSqlite());

    await _notifyChanged(month: budget.month, year: budget.year);
    return id;
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final db = await _dbHelper.database;
    final updated = budget.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    await db.update(
      'budgets',
      updated.toSqlite(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );

    await _enqueueSyncAction('budgets', budget.id, 'UPDATE', updated.toSqlite());
    await _notifyChanged(month: budget.month, year: budget.year);
  }

  Future<void> deleteBudget(String id, {int? month, int? year}) async {
    final db = await _dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    await _enqueueSyncAction('budgets', id, 'DELETE', {'id': id});
    await _notifyChanged(month: month, year: year);
  }

  Future<void> _enqueueSyncAction(String tableName, String recordId, String action, Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('sync_queue', {
        'tableName': tableName,
        'recordId': recordId,
        'action': action,
        'data': jsonEncode(data),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'retryCount': 0,
      });
    } catch (_) {}
  }
}
