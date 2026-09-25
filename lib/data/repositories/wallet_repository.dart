import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/database_helper.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';
import 'transaction_repository.dart';

/// Repository quản lý Ví tiền (Nơi chứa tiền) — Offline-first với SQLite
class WalletRepository {
  static final WalletRepository _instance = WalletRepository._internal();
  factory WalletRepository() => _instance;
  WalletRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _changeStream = StreamController<void>.broadcast();

  List<WalletModel> _cachedWallets = [];
  List<WalletModel> get latestWallets => List.unmodifiable(_cachedWallets);

  String? _explicitUid;
  String? get _currentUid => _explicitUid ?? AuthService().currentUid;

  void setUid(String uid) {
    _explicitUid = uid;
    _notifyChanged();
  }

  // ════════ CRUD VÍ TIỀN ════════

  /// Thêm ví mới vào SQLite + enqueue sync
  Future<String> addWallet(WalletModel wallet) async {
    final db = await _dbHelper.database;
    final id = wallet.id.isEmpty ? _uuid.v4() : wallet.id;
    final now = DateTime.now();

    // Nếu ví này được đánh dấu mặc định, bỏ cờ mặc định của các ví khác
    if (wallet.isDefault) {
      await db.update(
        'wallets',
        {'isDefault': 0},
        where: 'uid = ?',
        whereArgs: [_currentUid ?? wallet.uid],
      );
    }

    final newWallet = wallet.copyWith(
      id: id,
      uid: _currentUid ?? wallet.uid,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    await db.insert('wallets', newWallet.toSqlite());
    await _enqueueSyncAction('wallets', id, 'INSERT', newWallet.toSqlite());

    _notifyChanged();
    return id;
  }

  /// Cập nhật thông tin ví
  Future<void> updateWallet(WalletModel wallet) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    if (wallet.isDefault) {
      await db.update(
        'wallets',
        {'isDefault': 0},
        where: 'uid = ?',
        whereArgs: [_currentUid ?? wallet.uid],
      );
    }

    final updatedWallet = wallet.copyWith(
      updatedAt: now,
      syncStatus: 'pending',
    );

    await db.update(
      'wallets',
      updatedWallet.toSqlite(),
      where: 'id = ?',
      whereArgs: [wallet.id],
    );

    await _enqueueSyncAction('wallets', wallet.id, 'UPDATE', updatedWallet.toSqlite());
    _notifyChanged();
  }

  /// Xóa ví
  Future<void> deleteWallet(String walletId) async {
    final db = await _dbHelper.database;

    await db.delete(
      'wallets',
      where: 'id = ?',
      whereArgs: [walletId],
    );

    await _enqueueSyncAction('wallets', walletId, 'DELETE', {'id': walletId});
    _notifyChanged();
  }

  /// Điều chỉnh số dư của ví khi có giao dịch
  Future<void> adjustWalletBalance(String walletId, double amountDelta) async {
    if (walletId.isEmpty) return;
    final db = await _dbHelper.database;
    final rows = await db.query('wallets', where: 'id = ?', whereArgs: [walletId], limit: 1);
    if (rows.isNotEmpty) {
      final currentWallet = WalletModel.fromSqlite(rows.first);
      final newBalance = currentWallet.balance + amountDelta;
      final now = DateTime.now();
      final updatedWallet = currentWallet.copyWith(
        balance: newBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await db.update(
        'wallets',
        updatedWallet.toSqlite(),
        where: 'id = ?',
        whereArgs: [walletId],
      );
      await _enqueueSyncAction('wallets', walletId, 'UPDATE', updatedWallet.toSqlite());
      _notifyChanged();
    }
  }

  /// Chuyển tiền giữa các ví (Transfer money between wallets)
  Future<bool> transferMoney({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    double fee = 0.0,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId || amount <= 0) return false;
    final db = await _dbHelper.database;

    final transferGroupId = 'transfer_${_uuid.v4()}';
    final now = DateTime.now();

    final success = await db.transaction<bool>((txn) async {
      final fromRows = await txn.query('wallets', where: 'id = ?', whereArgs: [fromWalletId], limit: 1);
      final toRows = await txn.query('wallets', where: 'id = ?', whereArgs: [toWalletId], limit: 1);

      if (fromRows.isEmpty || toRows.isEmpty) return false;

      final fromWallet = WalletModel.fromSqlite(fromRows.first);
      final toWallet = WalletModel.fromSqlite(toRows.first);
      final uid = _currentUid ?? fromWallet.uid;

      // 1. Trừ ví nguồn: amount + fee
      final newFromBalance = fromWallet.balance - (amount + fee);
      final updatedFrom = fromWallet.copyWith(
        balance: newFromBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await txn.update(
        'wallets',
        updatedFrom.toSqlite(),
        where: 'id = ?',
        whereArgs: [fromWalletId],
      );
      await txn.insert('sync_queue', {
        'tableName': 'wallets',
        'recordId': fromWalletId,
        'action': 'UPDATE',
        'data': jsonEncode(updatedFrom.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });

      // 2. Cộng ví đích: amount
      final newToBalance = toWallet.balance + amount;
      final updatedTo = toWallet.copyWith(
        balance: newToBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await txn.update(
        'wallets',
        updatedTo.toSqlite(),
        where: 'id = ?',
        whereArgs: [toWalletId],
      );
      await txn.insert('sync_queue', {
        'tableName': 'wallets',
        'recordId': toWalletId,
        'action': 'UPDATE',
        'data': jsonEncode(updatedTo.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });

      // 3. Ghi nhận 2 giao dịch liên kết cùng transferGroupId
      final expenseTx = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'expense',
        category: 'Chuyển tiền',
        categoryIconCode: Icons.swap_horiz_rounded.codePoint,
        amount: amount + fee,
        date: now,
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description: 'Chuyển sang [${toWallet.name}]${note.isNotEmpty ? ': $note' : ''}',
        walletId: fromWalletId,
        groupId: transferGroupId,
        source: 'personal',
        syncStatus: 'pending',
      );
      await txn.insert('transactions', expenseTx.toSqlite());
      await txn.insert('sync_queue', {
        'tableName': 'transactions',
        'recordId': expenseTx.id,
        'action': 'INSERT',
        'data': jsonEncode(expenseTx.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });

      final incomeTx = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'income',
        category: 'Nhận chuyển tiền',
        categoryIconCode: Icons.call_received_rounded.codePoint,
        amount: amount,
        date: now,
        time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description: 'Nhận từ [${fromWallet.name}]${note.isNotEmpty ? ': $note' : ''}',
        walletId: toWalletId,
        groupId: transferGroupId,
        source: 'personal',
        syncStatus: 'pending',
      );
      await txn.insert('transactions', incomeTx.toSqlite());
      await txn.insert('sync_queue', {
        'tableName': 'transactions',
        'recordId': incomeTx.id,
        'action': 'INSERT',
        'data': jsonEncode(incomeTx.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });

      return true;
    });

    if (success) {
      _notifyChanged();
      TransactionRepository().notifyTransactionsChanged();
      if (ConnectivityService().isOnline) {
        unawaited(SyncService().syncAll());
      }
    }
    return success;
  }

  /// Đảm bảo luôn có ít nhất 1 ví mặc định (Ví tiền mặt) cho người dùng
  Future<void> ensureDefaultWalletExists(String uid, {double initialBalance = 0.0}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('wallets', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) {
      // Nếu có mạng, kiểm tra xem trên Firestore có sẵn ví của tài khoản này không
      if (ConnectivityService().isOnline) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('wallets')
              .where('uid', isEqualTo: uid)
              .get();
          if (snapshot.docs.isNotEmpty) {
            final wallets = snapshot.docs.map((d) => WalletModel.fromFirestore(d)).toList();
            await upsertFromFirestore(wallets);
            return;
          }
        } catch (_) {}
      }

      final defaultWallet = WalletModel(
        id: _uuid.v4(),
        uid: uid,
        name: 'Ví tiền mặt',
        type: WalletType.cash,
        balance: initialBalance,
        initialBalance: initialBalance,
        iconCode: Icons.payments_rounded.codePoint,
        colorValue: const Color(0xFF438883).toARGB32(),
        isDefault: true,
        note: 'Ví chi tiêu tiền mặt hằng ngày',
        syncStatus: 'pending',
      );
      await db.insert('wallets', defaultWallet.toSqlite());
      await _enqueueSyncAction('wallets', defaultWallet.id, 'INSERT', defaultWallet.toSqlite());
      _notifyChanged();
    }
  }

  /// Cập nhật hoặc chèn danh sách ví từ Firestore vào SQLite (áp dụng Last Write Wins)
  Future<void> upsertFromFirestore(List<WalletModel> firestoreWallets) async {
    if (firestoreWallets.isEmpty) return;
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final fw in firestoreWallets) {
        final existing = await txn.query(
          'wallets',
          where: 'id = ?',
          whereArgs: [fw.id],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert('wallets', fw.copyWith(syncStatus: 'synced').toSqlite());
        } else {
          final local = WalletModel.fromSqlite(existing.first);
          if (fw.updatedAt.isAfter(local.updatedAt) || local.syncStatus == 'synced') {
            await txn.update(
              'wallets',
              fw.copyWith(syncStatus: 'synced').toSqlite(),
              where: 'id = ?',
              whereArgs: [fw.id],
            );
          }
        }
      }
    });

    _notifyChanged();
  }

  // ════════ QUERIES ════════

  /// Stream danh sách ví của người dùng (phát dữ liệu tức thì cho StreamBuilder)
  Stream<List<WalletModel>> getWalletsStream() async* {
    yield await getWallets();
    await for (final _ in _changeStream.stream) {
      yield await getWallets();
    }
  }

  /// Lấy danh sách ví một lần
  Future<List<WalletModel>> getWallets() async {
    final db = await _dbHelper.database;
    final uid = _currentUid;
    final rows = uid != null
        ? await db.query('wallets', where: 'uid = ?', whereArgs: [uid], orderBy: 'isDefault DESC, createdAt ASC')
        : await db.query('wallets', orderBy: 'isDefault DESC, createdAt ASC');

    final list = rows.map((r) => WalletModel.fromSqlite(r)).toList();
    _cachedWallets = list;
    return list;
  }

  /// Lấy ví mặc định
  Future<WalletModel?> getDefaultWallet() async {
    final wallets = await getWallets();
    if (wallets.isEmpty) return null;
    return wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
  }

  /// Lấy ví theo ID
  Future<WalletModel?> getWalletById(String id) async {
    if (id.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.query('wallets', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return WalletModel.fromSqlite(rows.first);
  }

  /// Lấy tổng tài sản (tổng số dư tất cả các ví - phát tức thì không bị delay)
  Stream<double> getTotalBalanceStream() async* {
    yield await getTotalBalance();
    await for (final _ in _changeStream.stream) {
      yield await getTotalBalance();
    }
  }

  /// Lấy tổng số dư hiện tại một lần
  Future<double> getTotalBalance() async {
    final wallets = await getWallets();
    double total = 0.0;
    for (final w in wallets) {
      total += w.balance;
    }
    return total;
  }

  /// Phát thông báo thay đổi ví ra bên ngoài
  void notifyChanged() => _notifyChanged();

  void _notifyChanged() {
    if (!_changeStream.isClosed) {
      _changeStream.add(null);
    }
  }

  Future<void> _enqueueSyncAction(
    String tableName,
    String recordId,
    String action,
    Map<String, dynamic> data,
  ) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'tableName': tableName,
      'recordId': recordId,
      'action': action,
      'data': jsonEncode(data),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  void dispose() {
    _changeStream.close();
  }
}
