import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/goal_model.dart';
import '../../services/auth_service.dart';
import 'wallet_repository.dart';

class GoalRepository {
  static final GoalRepository _instance = GoalRepository._internal();
  factory GoalRepository() => _instance;
  GoalRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();
  final _goalStreamController = StreamController<List<GoalModel>>.broadcast();

  String? _explicitUid;
  String? get _currentUid => _explicitUid ?? AuthService().currentUid;

  void setUid(String uid) {
    _explicitUid = uid;
    _notifyChanged();
  }

  Stream<List<GoalModel>> getGoalsStream() {
    _notifyChanged();
    return _goalStreamController.stream;
  }

  Future<void> _notifyChanged() async {
    try {
      final goals = await getAllGoals();
      if (!_goalStreamController.isClosed) {
        _goalStreamController.add(goals);
      }
    } catch (_) {}
  }

  Future<List<GoalModel>> getAllGoals() async {
    final uid = _currentUid;
    if (uid == null) return [];

    final db = await _dbHelper.database;
    final maps = await db.query(
      'goals',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'deadline ASC',
    );

    return maps.map((m) => GoalModel.fromSqlite(m)).toList();
  }

  Future<String> addGoal(GoalModel goal) async {
    final db = await _dbHelper.database;
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
    final uid = goal.uid.isEmpty ? (_currentUid ?? '') : goal.uid;

    final newGoal = goal.copyWith(
      id: id,
      uid: uid,
      syncStatus: 'pending',
    );

    await db.insert('goals', newGoal.toSqlite(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _enqueueSyncAction('goals', id, 'INSERT', newGoal.toSqlite());
    await _notifyChanged();
    return id;
  }

  Future<void> updateGoal(GoalModel goal) async {
    final db = await _dbHelper.database;
    final updated = goal.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    await db.update(
      'goals',
      updated.toSqlite(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );

    await _enqueueSyncAction('goals', goal.id, 'UPDATE', updated.toSqlite());
    await _notifyChanged();
  }

  Future<void> deleteGoal(String id) async {
    final db = await _dbHelper.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    await _enqueueSyncAction('goals', id, 'DELETE', {'id': id});
    await _notifyChanged();
  }

  /// Nạp tiền tiết kiệm vào mục tiêu
  Future<void> depositToGoal(String goalId, double amount, {String? walletId}) async {
    if (amount <= 0) return;
    final db = await _dbHelper.database;
    final maps = await db.query('goals', where: 'id = ?', whereArgs: [goalId]);
    if (maps.isEmpty) return;

    final goal = GoalModel.fromSqlite(maps.first);
    final newCurrentAmount = goal.currentAmount + amount;

    await updateGoal(goal.copyWith(currentAmount: newCurrentAmount));

    // Trừ số dư ví nếu chọn ví cụ thể
    if (walletId != null && walletId.isNotEmpty) {
      await WalletRepository().adjustWalletBalance(walletId, -amount);
    }
  }

  /// Rút tiền từ mục tiêu về ví
  Future<void> withdrawFromGoal(String goalId, double amount, {String? walletId}) async {
    if (amount <= 0) return;
    final db = await _dbHelper.database;
    final maps = await db.query('goals', where: 'id = ?', whereArgs: [goalId]);
    if (maps.isEmpty) return;

    final goal = GoalModel.fromSqlite(maps.first);
    final newCurrentAmount = (goal.currentAmount - amount).clamp(0.0, double.infinity);

    await updateGoal(goal.copyWith(currentAmount: newCurrentAmount));

    // Cộng số dư ví nếu chọn ví cụ thể
    if (walletId != null && walletId.isNotEmpty) {
      await WalletRepository().adjustWalletBalance(walletId, amount);
    }
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
