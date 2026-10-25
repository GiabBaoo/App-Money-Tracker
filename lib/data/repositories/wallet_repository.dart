import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';
import 'transaction_repository.dart';
import '../../utils/category_utils.dart';
import '../../utils/finance_precision.dart';

/// Repository quản lý Ví tiền (Nơi chứa tiền) — Offline-first với SQLite
class WalletRepository with OwnedTableOps {
  static final WalletRepository _instance = WalletRepository._internal();
  factory WalletRepository() => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _changeStream = StreamController<void>.broadcast();
  final _walletsController = StreamController<List<WalletModel>>.broadcast();

  List<WalletModel> _cachedWallets = [];
  List<WalletModel> get latestWallets => List.unmodifiable(_cachedWallets);

  String? get currentUid => session.uidOrNull;

  WalletRepository._internal() {
    session.changes.listen((_) {
      _cachedWallets = [];
      _notifyChanged();
      if (session.uidOrNull != null) {
        getWallets();
      }
    });
    _loadAndEmitWallets();
  }

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  Future<List<WalletModel>> _loadAndEmitWallets() async {
    try {
      final list = await getWallets();
      if (!_walletsController.isClosed) {
        _walletsController.add(list);
      }
      return list;
    } catch (e) {
      debugPrint('WalletRepository _loadAndEmitWallets error: $e');
      return [];
    }
  }

  // ════════ CRUD VÍ TIỀN ════════

  /// Thêm ví mới vào SQLite + enqueue sync
  Future<String> addWallet(WalletModel wallet) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = wallet.id.isEmpty ? _uuid.v4() : wallet.id;
    final now = DateTime.now();

    final newWallet = wallet.copyWith(
      id: id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    final row = stampOwner(newWallet.toSqlite(), uid);

    await db.transaction((txn) async {
      // Nếu ví này được đánh dấu mặc định, bỏ cờ mặc định của các ví khác cùng uid
      if (wallet.isDefault) {
        await txn.update(
          'wallets',
          {'isDefault': 0},
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }
      await txn.insert('wallets', row);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    _notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    return id;
  }

  /// Cập nhật thông tin ví
  Future<void> updateWallet(WalletModel wallet) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    final updatedWallet = wallet.copyWith(
      updatedAt: now,
      syncStatus: 'pending',
    );
    final row = stampOwner(updatedWallet.toSqlite(), uid);

    await db.transaction((txn) async {
      if (wallet.isDefault) {
        await txn.update(
          'wallets',
          {'isDefault': 0},
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }
      await updateOwned(txn, 'wallets', wallet.id, row, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: wallet.id,
        action: 'UPDATE',
        data: row,
      );
    });

    _notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Xóa ví (áp dụng Soft Delete / Tombstone)
  Future<void> deleteWallet(String walletId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'wallets', walletId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: walletId,
        action: 'SOFT_DELETE',
      );
    });

    _notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Điều chỉnh số dư của ví khi có giao dịch
  Future<void> adjustWalletBalance(String walletId, double amountDelta) async {
    if (walletId.isEmpty) return;
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final row = await findOwned(txn, 'wallets', walletId, uid);
      if (row == null) {
        throw BusinessException(
          BusinessErrorCode.notFound,
          'wallets/$walletId không tồn tại',
        );
      }
      final currentWallet = WalletModel.fromSqlite(row);
      final newBalance = currentWallet.balance + amountDelta;
      final now = DateTime.now();
      final updatedWallet = currentWallet.copyWith(
        balance: newBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final rowMap = updatedWallet.toSqlite();
      await updateOwned(txn, 'wallets', walletId, rowMap, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: walletId,
        action: 'UPDATE',
        data: rowMap,
      );
    });

    _notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
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
    final uid = session.requireUid();

    if (fromWalletId == toWalletId) {
      throw const BusinessException(
        BusinessErrorCode.sameWalletTransfer,
        'Ví nguồn và ví đích không được trùng nhau',
      );
    }

    if (amount <= 0 || fee < 0) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền chuyển phải lớn hơn 0 và phí không được âm',
      );
    }

    final db = await _dbHelper.database;
    final transferId = 'xfer_${_uuid.v4()}';
    final now = DateTime.now();

    await db.transaction((txn) async {
      final fromRow = await findOwned(txn, 'wallets', fromWalletId, uid);
      final toRow = await findOwned(txn, 'wallets', toWalletId, uid);

      if (fromRow == null || toRow == null) {
        throw const BusinessException(
          BusinessErrorCode.notFound,
          'Không tìm thấy ví nguồn hoặc ví đích thuộc tài khoản',
        );
      }

      final fromWallet = WalletModel.fromSqlite(fromRow);
      final toWallet = WalletModel.fromSqlite(toRow);

      if (fromWallet.balance < (amount + fee)) {
        throw const BusinessException(
          BusinessErrorCode.insufficientBalance,
          'Số dư ví nguồn không đủ để thực hiện giao dịch',
        );
      }

      // 1. Trừ ví nguồn: amount + fee (chuẩn hóa làm tròn tiền tệ)
      final newFromBalance = FinancePrecision.roundCurrency(
        fromWallet.balance - (amount + fee),
        currency: fromWallet.currency,
      );
      final updatedFrom = fromWallet.copyWith(
        balance: newFromBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final fromMap = updatedFrom.toSqlite();
      await updateOwned(txn, 'wallets', fromWalletId, fromMap, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: fromWalletId,
        action: 'UPDATE',
        data: fromMap,
      );

      // 2. Cộng ví đích: amount (chuẩn hóa làm tròn tiền tệ)
      final newToBalance = FinancePrecision.roundCurrency(
        toWallet.balance + amount,
        currency: toWallet.currency,
      );
      final updatedTo = toWallet.copyWith(
        balance: newToBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final toMap = updatedTo.toSqlite();
      await updateOwned(txn, 'wallets', toWalletId, toMap, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: toWalletId,
        action: 'UPDATE',
        data: toMap,
      );

      // 3. Ghi nhận 2 giao dịch liên kết chuyên dụng với transferId (không mượn groupId)
      final expenseTx = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'expense',
        category: 'Chuyển tiền',
        categoryIconCode: CategoryUtils.getCategoryIcon(
          'Chuyển tiền',
        ).codePoint,
        amount: amount + fee,
        date: now,
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description:
            'Chuyển sang [${toWallet.name}]${note.isNotEmpty ? ': $note' : ''}',
        walletId: fromWalletId,
        transferId: transferId,
        groupId: null,
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

      final incomeTx = TransactionModel(
        id: _uuid.v4(),
        uid: uid,
        type: 'income',
        category: 'Nhận chuyển tiền',
        categoryIconCode: CategoryUtils.getCategoryIcon(
          'Nhận chuyển tiền',
        ).codePoint,
        amount: amount,
        date: now,
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        description:
            'Nhận từ [${fromWallet.name}]${note.isNotEmpty ? ': $note' : ''}',
        walletId: toWalletId,
        transferId: transferId,
        groupId: null,
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
    });

    _notifyChanged();
    TransactionRepository().notifyTransactionsChanged();
    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
    return true;
  }

  /// Đảm bảo luôn có ít nhất 1 ví mặc định (Ví tiền mặt) cho người dùng
  Future<void> ensureDefaultWalletExists(
    String uid, {
    double initialBalance = 0.0,
  }) async {
    if (!SessionManager.isValidUid(uid)) return;
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
            final wallets = snapshot.docs
                .map((d) => WalletModel.fromFirestore(d))
                .toList();
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
      final row = stampOwner(defaultWallet.toSqlite(), uid);
      await db.transaction((txn) async {
        await txn.insert('wallets', row);
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'wallets',
          recordId: defaultWallet.id,
          action: 'INSERT',
          data: row,
        );
      });
      _notifyChanged();
    }
  }

  /// Cập nhật hoặc chèn danh sách ví từ Firestore vào SQLite (áp dụng Local Dirty Shield và Soft Delete)
  Future<void> upsertFromFirestore(List<WalletModel> firestoreWallets) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || firestoreWallets.isEmpty) return;
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final fw in firestoreWallets) {
        // Phòng thủ nhiều lớp: bỏ qua doc có uid khác phiên hiện tại
        if (fw.uid != currentUid) continue;

        // 1. Kiểm tra Local Dirty Shield: nếu bản ghi đang chờ upload thì bỏ qua
        final queuePending = await txn.query(
          'sync_queue',
          columns: ['id'],
          where:
              'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
          whereArgs: [
            'wallets',
            fw.id,
            currentUid,
            currentUid,
            'pending',
            'processing',
          ],
          limit: 1,
        );
        if (queuePending.isNotEmpty) continue;

        final existing = await txn.query(
          'wallets',
          where: 'id = ? AND uid = ?',
          whereArgs: [fw.id, currentUid],
          limit: 1,
        );

        if (existing.isEmpty) {
          if (!fw.isDeleted) {
            await txn.insert(
              'wallets',
              fw.copyWith(syncStatus: 'synced').toSqlite(),
            );
          }
        } else {
          final local = WalletModel.fromSqlite(existing.first);
          if (local.syncStatus == 'pending') continue; // Dirty Shield

          final isRemoteNewer = fw.updatedAt.isAfter(local.updatedAt);
          final isSameTime = fw.updatedAt.isAtSameMomentAs(local.updatedAt);
          final winsTieBreak =
              isSameTime && _resolveTieBreaker(local.toSqlite(), fw.toSqlite());

          if (isRemoteNewer || winsTieBreak) {
            if (fw.isDeleted) {
              await txn.update(
                'wallets',
                {
                  'isDeleted': 1,
                  'deletedAt':
                      fw.deletedAt?.millisecondsSinceEpoch ??
                      DateTime.now().millisecondsSinceEpoch,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [fw.id, currentUid],
              );
            } else {
              await txn.update(
                'wallets',
                fw.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [fw.id, currentUid],
              );
            }
          }
        }
      }
    });

    _notifyChanged();
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
  Future<void> upsertFromFirestoreSafe(List<WalletModel> firestoreWallets) =>
      upsertFromFirestore(firestoreWallets);

  // ════════ QUERIES ════════

  /// Stream danh sách ví của người dùng (phát dữ liệu tức thì cho StreamBuilder)
  Stream<List<WalletModel>> getWalletsStream() async* {
    if (_cachedWallets.isNotEmpty) {
      yield latestWallets;
    }
    yield await getWallets();
    await for (final _ in _changeStream.stream) {
      yield await getWallets();
    }
  }

  /// Lấy danh sách ví một lần
  Future<List<WalletModel>> getWallets() async {
    final uid = session.uidOrNull;
    if (uid == null) return const []; // fail-closed READ
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'wallets',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid],
        orderBy: 'isDefault DESC, createdAt ASC',
      );

      final list = rows.map((r) => WalletModel.fromSqlite(r)).toList();
      _cachedWallets = list;
      return list;
    } catch (e) {
      debugPrint('WalletRepository.getWallets error: $e');
      return _cachedWallets;
    }
  }

  /// Lấy ví mặc định
  Future<WalletModel?> getDefaultWallet() async {
    final wallets = await getWallets();
    if (wallets.isEmpty) return null;
    return wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
  }

  /// Lấy ví theo ID
  Future<WalletModel?> getWalletById(String id) async {
    final uid = session.uidOrNull;
    if (id.isEmpty || uid == null) return null;
    final db = await _dbHelper.database;
    final row = await findOwned(db, 'wallets', id, uid);
    if (row == null) return null;
    final w = WalletModel.fromSqlite(row);
    if (w.isDeleted) return null;
    return w;
  }

  /// Lấy tổng tài sản (tổng số dư tất cả các ví - phát tức thì không bị delay)
  Stream<double> getTotalBalanceStream() async* {
    if (_cachedWallets.isNotEmpty) {
      yield _cachedWallets.fold(0.0, (prev, w) => prev + w.balance);
    }
    yield await getTotalBalance();
    await for (final _ in _changeStream.stream) {
      yield await getTotalBalance();
    }
  }

  /// Lấy tổng số dư hiện tại một lần
  Future<double> getTotalBalance() async {
    final uid = session.uidOrNull;
    if (uid == null) return 0.0;
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
    _loadAndEmitWallets();
    if (!_changeStream.isClosed) {
      _changeStream.add(null);
    }
  }

  void dispose() {
    _changeStream.close();
    _walletsController.close();
  }
}
