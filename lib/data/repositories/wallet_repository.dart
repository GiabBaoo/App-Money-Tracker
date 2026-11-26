import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/firestore_parse.dart';
import '../../models/wallet_model.dart';
import '../../core/logging/app_logger.dart';
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

  bool _isHealingDefault = false;

  /// Bỏ cờ mặc định của các ví khác trong cùng transaction và enqueue sync_queue
  /// để Firestore cũng được cập nhật đồng bộ (tránh 2 ví cùng mặc định).
  Future<void> _clearOtherDefaultsInTxn(
    dynamic txn,
    String uid, {
    String? exceptWalletId,
    required DateTime now,
  }) async {
    final whereClause = exceptWalletId != null
        ? 'uid = ? AND isDefault = 1 AND id != ? AND (isDeleted IS NULL OR isDeleted = 0)'
        : 'uid = ? AND isDefault = 1 AND (isDeleted IS NULL OR isDeleted = 0)';
    final whereArgs = exceptWalletId != null ? [uid, exceptWalletId] : [uid];

    final otherDefaults = await txn.query(
      'wallets',
      where: whereClause,
      whereArgs: whereArgs,
    );

    for (final r in otherDefaults) {
      final w = WalletModel.fromSqlite(r).copyWith(
        isDefault: false,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final updatedRow = stampOwner(w.toSqlite(), uid);
      await updateOwned(txn, 'wallets', w.id, updatedRow, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: w.id,
        action: 'UPDATE',
        data: updatedRow,
      );
    }
  }

  /// Đảm bảo bất biến: với các ví đang hoạt động của [uid], luôn có ĐÚNG 1 ví mặc định.
  /// Nếu >1 ví mặc định -> giữ ví có updatedAt mới nhất (hoặc [preferredWalletId]), tắt các ví còn lại + sync.
  /// Nếu 0 ví mặc định -> chọn ví tạo sớm nhất làm mặc định + sync.
  Future<bool> _ensureSingleDefaultInTxn(
    dynamic txn,
    String uid, {
    required DateTime now,
    String? preferredWalletId,
  }) async {
    final rows = await txn.query(
      'wallets',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
      orderBy: 'createdAt ASC',
    );
    if (rows.isEmpty) return false;

    final wallets = rows.map((r) => WalletModel.fromSqlite(r)).toList();
    final defaults = wallets.where((w) => w.isDefault).toList();

    if (defaults.length == 1) return false;

    bool changed = false;
    if (defaults.length > 1) {
      WalletModel keep;
      if (preferredWalletId != null &&
          defaults.any((w) => w.id == preferredWalletId)) {
        keep = defaults.firstWhere((w) => w.id == preferredWalletId);
      } else {
        defaults.sort((a, b) {
          final cmp = b.updatedAt.compareTo(a.updatedAt);
          if (cmp != 0) return cmp;
          return a.createdAt.compareTo(b.createdAt);
        });
        keep = defaults.first;
      }

      for (final w in defaults) {
        if (w.id == keep.id) continue;
        final isLocalOnly = w.syncStatus == 'local_only';
        final updated = w.copyWith(
          isDefault: false,
          updatedAt: isLocalOnly ? w.updatedAt : now,
          syncStatus: isLocalOnly ? 'local_only' : 'pending',
        );
        final rowMap = stampOwner(updated.toSqlite(), uid);
        await updateOwned(txn, 'wallets', w.id, rowMap, uid);
        if (!isLocalOnly) {
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'wallets',
            recordId: w.id,
            action: 'UPDATE',
            data: rowMap,
          );
        }
        changed = true;
      }
    } else if (defaults.isEmpty) {
      final chosen =
          (preferredWalletId != null &&
              wallets.any((w) => w.id == preferredWalletId))
          ? wallets.firstWhere((w) => w.id == preferredWalletId)
          : wallets.first;
      final isLocalOnly = chosen.syncStatus == 'local_only';
      final updated = chosen.copyWith(
        isDefault: true,
        updatedAt: isLocalOnly ? chosen.updatedAt : now,
        syncStatus: isLocalOnly ? 'local_only' : 'pending',
      );
      final rowMap = stampOwner(updated.toSqlite(), uid);
      await updateOwned(txn, 'wallets', chosen.id, rowMap, uid);
      if (!isLocalOnly) {
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'wallets',
          recordId: chosen.id,
          action: 'UPDATE',
          data: rowMap,
        );
      }
      changed = true;
    }

    return changed;
  }

  /// Đặt một ví cụ thể làm ví mặc định duy nhất
  Future<void> setDefaultWallet(String walletId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final existing = await findOwned(txn, 'wallets', walletId, uid);
      if (existing == null) {
        throw BusinessException(
          BusinessErrorCode.notFound,
          'wallets/$walletId không tồn tại',
        );
      }
      final wallet = WalletModel.fromSqlite(existing);
      if (wallet.isDeleted) {
        throw BusinessException(
          BusinessErrorCode.notFound,
          'wallets/$walletId đã bị xóa',
        );
      }

      await _clearOtherDefaultsInTxn(
        txn,
        uid,
        exceptWalletId: walletId,
        now: now,
      );

      final updated = wallet.copyWith(
        isDefault: true,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final rowMap = stampOwner(updated.toSqlite(), uid);
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

    unawaited(SyncService().syncAll());
  }

  /// Thêm ví mới vào SQLite + enqueue sync
  Future<String> addWallet(WalletModel wallet) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = wallet.id.isEmpty ? _uuid.v4() : wallet.id;
    final now = DateTime.now();

    await db.transaction((txn) async {
      bool effectiveIsDefault = wallet.isDefault;

      if (effectiveIsDefault) {
        await _clearOtherDefaultsInTxn(
          txn,
          uid,
          exceptWalletId: id,
          now: now,
        );
      } else {
        // Nếu chưa có ví mặc định nào đang hoạt động thì tự động bật mặc định cho ví mới
        final existingDefaults = await txn.query(
          'wallets',
          columns: ['id'],
          where:
              'uid = ? AND isDefault = 1 AND (isDeleted IS NULL OR isDeleted = 0)',
          whereArgs: [uid],
          limit: 1,
        );
        if (existingDefaults.isEmpty) {
          effectiveIsDefault = true;
        }
      }

      final newWallet = wallet.copyWith(
        id: id,
        isDefault: effectiveIsDefault,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final row = stampOwner(newWallet.toSqlite(), uid);

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

    unawaited(SyncService().syncAll());

    return id;
  }

  /// Cập nhật thông tin ví
  Future<void> updateWallet(WalletModel wallet) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final existingRow = await findOwned(txn, 'wallets', wallet.id, uid);
      final prevUpdatedMs = existingRow != null
          ? (existingRow['updatedAt'] as int?)
          : null;
      final nowMs = nextMonotonicTimestamp(prevUpdatedMs);
      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);

      bool effectiveIsDefault = wallet.isDefault;

      if (effectiveIsDefault) {
        await _clearOtherDefaultsInTxn(
          txn,
          uid,
          exceptWalletId: wallet.id,
          now: now,
        );
      } else {
        // Kiểm tra các ví đang hoạt động khác
        final otherActiveRows = await txn.query(
          'wallets',
          where:
              'uid = ? AND id != ? AND (isDeleted IS NULL OR isDeleted = 0)',
          whereArgs: [uid, wallet.id],
          orderBy: 'createdAt ASC',
        );
        if (otherActiveRows.isEmpty) {
          // Nếu chỉ có duy nhất 1 ví này thì bắt buộc giữ làm mặc định
          effectiveIsDefault = true;
        } else {
          // Nếu người dùng tắt mặc định trên ví này và chưa có ví khác làm mặc định,
          // tự động chuyển cờ mặc định sang ví hoạt động đầu tiên còn lại
          final hasAnotherDefault = otherActiveRows.any(
            (r) => (r['isDefault'] as int? ?? 0) == 1,
          );
          if (!hasAnotherDefault) {
            final fallbackDefault = WalletModel.fromSqlite(
              otherActiveRows.first,
            ).copyWith(
              isDefault: true,
              updatedAt: now,
              syncStatus: 'pending',
            );
            final fallbackRow = stampOwner(fallbackDefault.toSqlite(), uid);
            await updateOwned(
              txn,
              'wallets',
              fallbackDefault.id,
              fallbackRow,
              uid,
            );
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: uid,
              table: 'wallets',
              recordId: fallbackDefault.id,
              action: 'UPDATE',
              data: fallbackRow,
            );
          }
        }
      }

      final existingBalance = existingRow != null
          ? (existingRow['balance'] as num?)?.toDouble()
          : null;
      final balanceChanged =
          existingBalance == null ||
          (existingBalance - wallet.balance).abs() > 0.001;

      final countRes = await txn.rawQuery(
        'SELECT COUNT(*) as txCount FROM transactions '
        'WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        [uid, wallet.id],
      );
      final txCount = (countRes.first['txCount'] as int?) ?? 0;

      double effectiveInitialBalance = wallet.initialBalance;
      if (balanceChanged || txCount > 0) {
        final incomeRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM transactions "
          "WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0) AND type = 'income'",
          [uid, wallet.id],
        );
        final expenseRes = await txn.rawQuery(
          "SELECT COALESCE(SUM(amount), 0) as total FROM transactions "
          "WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0) AND type = 'expense'",
          [uid, wallet.id],
        );
        final totalIncome =
            (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final totalExpense =
            (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final netLedger = FinancePrecision.roundCurrency(
          totalIncome - totalExpense,
          currency: wallet.currency,
        );
        effectiveInitialBalance = FinancePrecision.roundCurrency(
          wallet.balance - netLedger,
          currency: wallet.currency,
        );
      }

      final updatedWallet = wallet.copyWith(
        initialBalance: effectiveInitialBalance,
        isDefault: effectiveIsDefault,
        updatedAt: now,
        syncStatus: 'pending',
      );
      final row = stampOwner(updatedWallet.toSqlite(), uid);

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

    unawaited(SyncService().syncAll());
  }

  /// Xóa ví (áp dụng Soft Delete / Tombstone và Cascade Soft Delete giao dịch liên kết)
  Future<void> deleteWallet(String walletId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'wallets', walletId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: walletId,
        action: 'SOFT_DELETE',
      );

      // Cascade soft delete các giao dịch đang hoạt động thuộc về ví bị xóa
      final txRows = await txn.query(
        'transactions',
        columns: ['id'],
        where:
            'walletId = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [walletId, uid],
      );
      for (final r in txRows) {
        final txId = r['id'] as String;
        await txn.update(
          'transactions',
          {
            'isDeleted': 1,
            'deletedAt': nowMs,
            'updatedAt': nowMs,
            'syncStatus': 'pending',
          },
          where: 'id = ? AND uid = ?',
          whereArgs: [txId, uid],
        );
        await SyncQueueWriter.enqueue(
          txn,
          ownerUid: uid,
          table: 'transactions',
          recordId: txId,
          action: 'SOFT_DELETE',
        );
      }

      // Nếu ví vừa xóa là ví mặc định, chọn ví còn lại sớm nhất làm mặc định
      await _ensureSingleDefaultInTxn(
        txn,
        uid,
        now: DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
    });

    _notifyChanged();
    TransactionRepository().notifyTransactionsChanged();

    unawaited(SyncService().syncAll());
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
      final newBalance = FinancePrecision.roundCurrency(
        currentWallet.balance + amountDelta,
        currency: currentWallet.currency,
      );
      final nextMs = nextMonotonicTimestamp(
        currentWallet.updatedAt.millisecondsSinceEpoch,
      );
      final now = DateTime.fromMillisecondsSinceEpoch(nextMs);
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

    unawaited(SyncService().syncAll());
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

      // 1. Trừ ví nguồn: amount + fee (chuẩn hóa làm tròn tiền tệ + timestamp tịnh tiến)
      final newFromBalance = FinancePrecision.roundCurrency(
        fromWallet.balance - (amount + fee),
        currency: fromWallet.currency,
      );
      final fromNextMs = nextMonotonicTimestamp(
        fromWallet.updatedAt.millisecondsSinceEpoch,
      );
      final updatedFrom = fromWallet.copyWith(
        balance: newFromBalance,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(fromNextMs),
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

      // 2. Cộng ví đích: amount (chuẩn hóa làm tròn tiền tệ + timestamp tịnh tiến)
      final newToBalance = FinancePrecision.roundCurrency(
        toWallet.balance + amount,
        currency: toWallet.currency,
      );
      final toNextMs = nextMonotonicTimestamp(
        toWallet.updatedAt.millisecondsSinceEpoch,
      );
      final updatedTo = toWallet.copyWith(
        balance: newToBalance,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(toNextMs),
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
        id: '${transferId}_out',
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
        id: '${transferId}_in',
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
    unawaited(SyncService().syncAll());
    return true;
  }

  /// Đảm bảo luôn có ít nhất 1 ví mặc định (Ví tiền mặt) cho người dùng.
  /// Chỉ tạo ví khi đã xác nhận Firestore không có ví nào (tránh tạo ví 0đ ghi đè ví thật).
  Future<void> ensureDefaultWalletExists(
    String uid, {
    double initialBalance = 0.0,
    bool firestoreConfirmed = false,
  }) async {
    if (!SessionManager.isValidUid(uid)) return;
    final db = await _dbHelper.database;
    final rows = await db.query('wallets', where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) {
      bool confirmedEmpty = firestoreConfirmed;
      if (!confirmedEmpty) {
        final isOnline =
            ConnectivityService().isOnline ||
            await ConnectivityService().checkRealInternet();
        if (!isOnline) {
          // Offline và chưa xác nhận được Firestore → không tạo ví 0đ
          return;
        }
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('wallets')
              .where('uid', isEqualTo: uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
          if (snapshot.metadata.isFromCache) {
            return;
          }
          if (snapshot.docs.isNotEmpty) {
            final wallets = FirestoreParse.parseList(
              snapshot.docs,
              WalletModel.fromFirestore,
              tag: 'WalletRepository',
            );
            await upsertFromFirestore(wallets);
            return;
          }
          confirmedEmpty = true;
        } catch (e, st) {
          AppLogger.warn(
            'Không thể xác nhận ví từ Firestore lúc khởi tạo — bỏ qua tạo ví mặc định',
            tag: 'WalletRepository',
            error: e,
            stackTrace: st,
          );
          return;
        }
      }

      final defaultWalletId = 'wlt_default_$uid';
      final defaultWallet = WalletModel(
        id: defaultWalletId,
        uid: uid,
        name: 'Ví tiền mặt',
        type: WalletType.cash,
        balance: initialBalance,
        initialBalance: initialBalance,
        iconCode: Icons.payments_rounded.codePoint,
        colorValue: const Color(0xFF438883).toARGB32(),
        isDefault: true,
        note: 'Ví chi tiêu tiền mặt hằng ngày',
        syncStatus: confirmedEmpty ? 'pending' : 'local_only',
      );
      final row = stampOwner(defaultWallet.toSqlite(), uid);
      await db.transaction((txn) async {
        await txn.insert('wallets', row);
        if (confirmedEmpty) {
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'wallets',
            recordId: defaultWallet.id,
            action: 'INSERT',
            data: row,
          );
        }
      });
      _notifyChanged();
      if (confirmedEmpty) {
        unawaited(SyncService().syncAll());
      }
    }
  }

  /// Upsert nhiều ví từ Firestore theo batch (áp dụng Local Dirty Shield, Soft Delete & Self-Healing)
  Future<void> upsertFromFirestore(List<WalletModel> firestoreWallets) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || firestoreWallets.isEmpty) return;

    final ownedWallets = firestoreWallets
        .where((fw) => fw.uid == currentUid && fw.id.isNotEmpty)
        .toList();
    if (ownedWallets.isEmpty) return;

    final db = await _dbHelper.database;
    bool needsUploadHealing = false;
    bool hasChanges = false;

    await db.transaction((txn) async {
      // Preload pending/processing sync_queue IDs cho bảng wallets
      final queueRows = await txn.query(
        'sync_queue',
        columns: ['recordId'],
        where:
            'tableName = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
        whereArgs: ['wallets', currentUid, currentUid, 'pending', 'processing'],
      );
      final pendingIds = <String>{
        for (final r in queueRows)
          if (r['recordId'] is String) r['recordId'] as String,
      };

      // Preload local wallets hiện có (chunk 450)
      final existingById = <String, Map<String, Object?>>{};
      final ids = ownedWallets.map((w) => w.id).toSet().toList();
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          i + chunkSize > ids.length ? ids.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          'wallets',
          where: 'uid = ? AND id IN ($placeholders)',
          whereArgs: [currentUid, ...chunk],
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id != null) existingById[id] = row;
        }
      }

      final batch = txn.batch();
      var batchOps = 0;
      for (var fw in ownedWallets) {
        final existingRow = existingById[fw.id];

        // Nếu doc trên Firestore bị thiếu tên (do bản ghi UPDATE bán phần cũ),
        // ưu tiên giữ tên local hoặc đặt tên mặc định hợp lệ
        if (fw.name.trim().isEmpty && !fw.isDeleted) {
          if (existingRow != null) {
            final local = WalletModel.fromSqlite(existingRow);
            if (local.name.trim().isNotEmpty) {
              final healed = local.copyWith(syncStatus: 'pending');
              final rowMap = stampOwner(healed.toSqlite(), currentUid);
              await updateOwned(txn, 'wallets', local.id, rowMap, currentUid);
              await SyncQueueWriter.enqueue(
                txn,
                ownerUid: currentUid,
                table: 'wallets',
                recordId: local.id,
                action: 'INSERT',
                data: rowMap,
              );
              needsUploadHealing = true;
              continue;
            }
          }
          fw = fw.copyWith(
            name: fw.id == 'wlt_default_$currentUid'
                ? 'Ví tiền mặt'
                : 'Ví tiền',
          );
        }

        // Kiểm tra trường hợp ví local là bản tạm (local_only) hoặc ví mặc định 0đ rỗng mới khởi tạo
        // trong khi Firestore đã có ví thật từ máy gốc: cho phép Firestore ghi đè (bỏ qua Dirty Shield)
        bool bypassDirtyShield = false;
        if (existingRow != null && !fw.isDeleted) {
          final local = WalletModel.fromSqlite(existingRow);

          if (local.syncStatus == 'local_only') {
            bypassDirtyShield = true;
            batch.delete(
              'sync_queue',
              where:
                  'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?)',
              whereArgs: ['wallets', fw.id, currentUid, currentUid],
            );
            batchOps++;
          } else if (fw.id == 'wlt_default_$currentUid' &&
              local.balance == 0 &&
              local.initialBalance == 0 &&
              (fw.balance != 0 || fw.initialBalance != 0)) {
            bypassDirtyShield = true;
            batch.delete(
              'sync_queue',
              where:
                  'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?)',
              whereArgs: ['wallets', fw.id, currentUid, currentUid],
            );
            batchOps++;
          } else if (local.balance == 0 && local.initialBalance == 0) {
            final txCountRes = await txn.rawQuery(
              'SELECT COUNT(*) as c FROM transactions '
              'WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0)',
              [currentUid, fw.id],
            );
            final txCount = (txCountRes.first['c'] as int?) ?? 0;
            if (txCount == 0 && (fw.balance != 0 || fw.initialBalance != 0)) {
              bypassDirtyShield = true;
              batch.delete(
                'sync_queue',
                where:
                    'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?)',
                whereArgs: ['wallets', fw.id, currentUid, currentUid],
              );
              batchOps++;
            }
          }
        }

        // 1. Kiểm tra Local Dirty Shield: nếu bản ghi đang chờ upload thì bỏ qua
        if (!bypassDirtyShield && pendingIds.contains(fw.id)) {
          continue;
        }

        if (existingRow == null) {
          if (!fw.isDeleted) {
            batch.insert(
              'wallets',
              fw.copyWith(syncStatus: 'synced').toSqlite(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            batchOps++;
            hasChanges = true;
          }
        } else {
          final local = WalletModel.fromSqlite(existingRow);
          if (!bypassDirtyShield && local.syncStatus == 'pending') {
            // Nếu local đang pending nhưng không có trong sync_queue (mồ côi), tự động đưa lại vào sync_queue
            final healedRow = stampOwner(local.toSqlite(), currentUid);
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: currentUid,
              table: 'wallets',
              recordId: local.id,
              action: 'INSERT',
              data: healedRow,
            );
            needsUploadHealing = true;
            continue; // Dirty Shield
          }

          if (bypassDirtyShield) {
            batch.update(
              'wallets',
              fw.copyWith(syncStatus: 'synced').toSqlite(),
              where: 'id = ? AND uid = ?',
              whereArgs: [fw.id, currentUid],
            );
            batchOps++;
            hasChanges = true;
            continue;
          }

          // Monotonic Delete Rule: Nếu local đã xóa mềm, chỉ chấp nhận khôi phục nếu remote mới hơn thời điểm xóa
          if (local.isDeleted && !fw.isDeleted) {
            final localDeletedMs = local.deletedAt?.millisecondsSinceEpoch ??
                local.updatedAt.millisecondsSinceEpoch;
            if (!fw.updatedAt.isAfter(
              DateTime.fromMillisecondsSinceEpoch(localDeletedMs),
            )) {
              continue; // Local Tombstone wins
            }
          }

          final shouldWin = ConflictResolver.shouldRemoteWin(
            localUpdatedAt: local.updatedAt,
            remoteUpdatedAt: fw.updatedAt,
            localData: local.toSqlite(),
            remoteData: fw.toSqlite(),
          );

          if (shouldWin) {
            if (fw.isDeleted) {
              final remoteDeletedMs = fw.deletedAt?.millisecondsSinceEpoch ??
                  fw.updatedAt.millisecondsSinceEpoch;
              final effectiveUpdatedMs =
                  fw.updatedAt.millisecondsSinceEpoch > remoteDeletedMs
                      ? fw.updatedAt.millisecondsSinceEpoch
                      : remoteDeletedMs;

              batch.update(
                'wallets',
                {
                  'isDeleted': 1,
                  'deletedAt': remoteDeletedMs,
                  'updatedAt': effectiveUpdatedMs,
                  'syncStatus': 'synced',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [fw.id, currentUid],
              );
            } else {
              batch.update(
                'wallets',
                fw.copyWith(syncStatus: 'synced').toSqlite(),
                where: 'id = ? AND uid = ?',
                whereArgs: [fw.id, currentUid],
              );
            }
            batchOps++;
            hasChanges = true;
          } else {
            // Local thắng xung đột (Local mới hơn Remote): Nếu dữ liệu lệch nhau, đẩy bản Local chuẩn lên Firestore
            final isDifferent =
                (local.balance - fw.balance).abs() > 0.001 ||
                (local.initialBalance - fw.initialBalance).abs() > 0.001 ||
                local.name != fw.name ||
                local.isDeleted != fw.isDeleted;
            if (isDifferent && !local.isDeleted) {
              final healed = local.copyWith(syncStatus: 'pending');
              final rowMap = stampOwner(healed.toSqlite(), currentUid);
              await updateOwned(txn, 'wallets', local.id, rowMap, currentUid);
              await SyncQueueWriter.enqueue(
                txn,
                ownerUid: currentUid,
                table: 'wallets',
                recordId: local.id,
                action: 'INSERT',
                data: rowMap,
              );
              needsUploadHealing = true;
            }
          }
        }
      }

      if (batchOps > 0) {
        await batch.commit(noResult: true);
      }

      // Nếu từ Firestore đã tải về ít nhất 1 ví thật đang hoạt động, dọn dẹp các ví tạm local_only
      // và ví mặc định 0đ rỗng tự sinh (wlt_default_*) không có giao dịch
      final activeRemoteWallets = ownedWallets
          .where((w) => !w.isDeleted)
          .toList();
      final activeRemoteIds = activeRemoteWallets.map((w) => w.id).toSet();
      if (activeRemoteIds.isNotEmpty) {
        final localOnlyRows = await txn.query(
          'wallets',
          columns: ['id'],
          where: "uid = ? AND syncStatus = 'local_only'",
          whereArgs: [currentUid],
        );
        for (final r in localOnlyRows) {
          final lid = r['id'] as String? ?? '';
          if (lid.isNotEmpty && !activeRemoteIds.contains(lid)) {
            await txn.delete(
              'wallets',
              where: 'id = ? AND uid = ?',
              whereArgs: [lid, currentUid],
            );
            hasChanges = true;
          }
        }

        // Nếu có ít nhất 1 ví thật khác ngoài wlt_default_$currentUid, và wlt_default_$currentUid đang 0đ + không có giao dịch -> xóa mềm
        final defaultWid = 'wlt_default_$currentUid';
        final hasOtherActiveWallet = activeRemoteWallets.any(
          (w) => w.id != defaultWid,
        );
        if (hasOtherActiveWallet) {
          final defRows = await txn.query(
            'wallets',
            where:
                'id = ? AND uid = ? AND balance = 0 AND initialBalance = 0 AND (isDeleted IS NULL OR isDeleted = 0)',
            whereArgs: [defaultWid, currentUid],
            limit: 1,
          );
          if (defRows.isNotEmpty) {
            final txCountRes = await txn.rawQuery(
              'SELECT COUNT(*) as c FROM transactions '
              'WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0)',
              [currentUid, defaultWid],
            );
            final txCount = (txCountRes.first['c'] as int?) ?? 0;
            if (txCount == 0) {
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              await txn.update(
                'wallets',
                {
                  'isDeleted': 1,
                  'deletedAt': nowMs,
                  'updatedAt': nowMs,
                  'isDefault': 0,
                  'syncStatus': 'pending',
                },
                where: 'id = ? AND uid = ?',
                whereArgs: [defaultWid, currentUid],
              );
              await SyncQueueWriter.enqueue(
                txn,
                ownerUid: currentUid,
                table: 'wallets',
                recordId: defaultWid,
                action: 'SOFT_DELETE',
              );
              needsUploadHealing = true;
              hasChanges = true;
            }
          }
        }
      }

      // Tự chữa bất biến: nếu dữ liệu cloud có >1 hoặc 0 ví mặc định -> giữ đúng 1 ví & enqueue sync
      final healedDefault = await _ensureSingleDefaultInTxn(
        txn,
        currentUid,
        now: DateTime.now(),
      );
      if (healedDefault) {
        needsUploadHealing = true;
        hasChanges = true;
      }
    });

    if (hasChanges || needsUploadHealing) {
      await _refreshAndNotify();
    }
    if (needsUploadHealing) {
      unawaited(SyncService().syncAll());
    }
  }

  /// Upsert an toàn tuân thủ ISyncableRepository
  Future<void> upsertFromFirestoreSafe(List<WalletModel> firestoreWallets) =>
      upsertFromFirestore(firestoreWallets);

  // ════════ QUERIES ════════

  /// Stream danh sách ví của người dùng (phát dữ liệu tức thì cho StreamBuilder)
  Stream<List<WalletModel>> getWalletsStream() {
    return (() async* {
      if (_cachedWallets.isNotEmpty) {
        yield latestWallets;
      }
      yield await getWallets();
      await for (final _ in _changeStream.stream) {
        yield await getWallets();
      }
    })().asBroadcastStream(onCancel: (sub) => sub.cancel());
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

      // Tự chữa dữ liệu cũ nếu phát hiện != 1 ví mặc định
      if (list.isNotEmpty && !_isHealingDefault) {
        final defaultCount = list.where((w) => w.isDefault).length;
        if (defaultCount != 1) {
          _isHealingDefault = true;
          try {
            bool healed = false;
            await db.transaction((txn) async {
              healed = await _ensureSingleDefaultInTxn(
                txn,
                uid,
                now: DateTime.now(),
              );
            });
            if (healed) {
              final healedRows = await db.query(
                'wallets',
                where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
                whereArgs: [uid],
                orderBy: 'isDefault DESC, createdAt ASC',
              );
              final healedList = healedRows
                  .map((r) => WalletModel.fromSqlite(r))
                  .toList();
              _cachedWallets = healedList;
              unawaited(SyncService().syncAll());
              return healedList;
            }
          } finally {
            _isHealingDefault = false;
          }
        }
      }

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
  Stream<double> getTotalBalanceStream() {
    return (() async* {
      if (_cachedWallets.isNotEmpty) {
        yield _cachedWallets.fold(0.0, (prev, w) => prev + w.balance);
      }
      yield await getTotalBalance();
      await for (final _ in _changeStream.stream) {
        yield await getTotalBalance();
      }
    })().asBroadcastStream(onCancel: (sub) => sub.cancel());
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

  Future<void> _refreshAndNotify() async {
    await _loadAndEmitWallets();
    if (!_changeStream.isClosed) {
      _changeStream.add(null);
    }
  }

  void _notifyChanged() {
    unawaited(_refreshAndNotify());
  }

  void dispose() {
    _changeStream.close();
    _walletsController.close();
  }
}
