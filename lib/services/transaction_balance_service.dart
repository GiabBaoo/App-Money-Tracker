import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

/// Service đảm bảo mọi thao tác tạo, sửa, xóa giao dịch cùng với việc
/// cộng/trừ số dư ví liên quan và ghi sync_queue ĐỀU NẰM TRONG 1 SQLite Transaction
/// duy nhất (Atomic / Nguyên tử). Tránh triệt để tình trạng số dư lệch khỏi giao dịch.
class TransactionBalanceService {
  static final TransactionBalanceService _instance =
      TransactionBalanceService._internal();
  factory TransactionBalanceService() => _instance;
  TransactionBalanceService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TransactionRepository _txRepo = TransactionRepository();
  final WalletRepository _walletRepo = WalletRepository();

  /// ═══════════════════════════════════════════════
  /// 1. THÊM GIAO DỊCH + CẬP NHẬT SỐ DƯ VÍ (ATOMIC)
  /// ═══════════════════════════════════════════════
  Future<String> addTransactionAtomic(TransactionModel transaction) async {
    final db = await _dbHelper.database;

    // Tự động gán ví mặc định nếu giao dịch chưa được chỉ định walletId
    String targetWalletId = transaction.walletId;
    if (targetWalletId.isEmpty) {
      final wallets = _walletRepo.latestWallets;
      if (wallets.isNotEmpty) {
        try {
          targetWalletId = wallets.firstWhere((w) => w.isDefault).id;
        } catch (_) {
          targetWalletId = wallets.first.id;
        }
      }
    }

    final effectiveTx = targetWalletId.isNotEmpty && targetWalletId != transaction.walletId
        ? transaction.copyWith(walletId: targetWalletId)
        : transaction;

    final id = await db.transaction<String>((txn) async {
      // 1. Thêm giao dịch & sync_queue của transaction
      final txId = await _txRepo.addTransactionInTxn(txn, effectiveTx);

      // 2. Điều chỉnh số dư ví & sync_queue của wallet
      if (effectiveTx.walletId.isNotEmpty) {
        final delta = effectiveTx.type == 'income'
            ? effectiveTx.amount
            : -effectiveTx.amount;
        await _adjustWalletInTxn(txn, effectiveTx.walletId, delta);
      }

      return txId;
    });

    // Thông báo cập nhật ra ngoài transaction để tránh deadlock UI stream
    _txRepo.notifyTransactionsChanged();
    _walletRepo.notifyChanged();

    // Tự động đẩy sync nếu đang online
    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    return id;
  }

  /// ═══════════════════════════════════════════════
  /// 2. SỬA GIAO DỊCH + CÂN ĐỐI SỐ DƯ VÍ (ATOMIC)
  /// ═══════════════════════════════════════════════
  /// Xử lý đầy đủ 4 kịch bản:
  /// - Chỉ đổi số tiền
  /// - Đổi loại giao dịch (thu ↔ chi)
  /// - Đổi nguồn tiền / ví
  /// - Đổi đồng thời cả 3 thuộc tính
  Future<void> editTransactionAtomic({
    required TransactionModel oldTx,
    required TransactionModel newTx,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final oldWalletId = oldTx.walletId;
      final newWalletId = newTx.walletId;
      final oldType = oldTx.type;
      final newType = newTx.type;
      final oldAmount = oldTx.amount;
      final newAmount = newTx.amount;

      // Bước 1: Revert (hoàn lại) tác động cũ lên oldWalletId
      if (oldWalletId.isNotEmpty) {
        final revertDelta = (oldType == 'income') ? -oldAmount : oldAmount;
        await _adjustWalletInTxn(txn, oldWalletId, revertDelta);
      }

      // Bước 2: Apply (áp dụng) tác động mới lên newWalletId
      if (newWalletId.isNotEmpty) {
        final applyDelta = (newType == 'income') ? newAmount : -newAmount;
        await _adjustWalletInTxn(txn, newWalletId, applyDelta);
      }

      // Bước 3: Cập nhật giao dịch trong bảng transactions
      final now = DateTime.now();
      final updatedTx = newTx.copyWith(
        updatedAt: now,
        syncStatus: 'pending',
      );

      await txn.update(
        'transactions',
        updatedTx.toSqlite(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );

      // Bước 4: Thêm bản ghi sync_queue cho transactions
      await txn.insert('sync_queue', {
        'tableName': 'transactions',
        'recordId': newTx.id,
        'action': 'UPDATE',
        'data': jsonEncode(updatedTx.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });
    });

    _txRepo.notifyTransactionsChanged();
    _walletRepo.notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// ═══════════════════════════════════════════════
  /// 3. XÓA GIAO DỊCH + HOÀN LẠI SỐ DƯ VÍ (ATOMIC)
  /// ═══════════════════════════════════════════════
  Future<void> deleteTransactionAtomic(TransactionModel tx) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Hoàn lại số dư ví nếu giao dịch có liên kết ví
      if (tx.walletId.isNotEmpty) {
        final revertDelta = (tx.type == 'income') ? -tx.amount : tx.amount;
        await _adjustWalletInTxn(txn, tx.walletId, revertDelta);
      }

      // 2. Xóa khỏi bảng transactions
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );

      // 3. Thêm bản ghi sync_queue DELETE
      await txn.insert('sync_queue', {
        'tableName': 'transactions',
        'recordId': tx.id,
        'action': 'DELETE',
        'data': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'retryCount': 0,
      });

      // 4. Nếu là giao dịch chuyển tiền hai chiều, tìm và hoàn lại giao dịch đối ứng cùng lúc
      if (tx.isTransfer) {
        List<Map<String, dynamic>> pairedRows = [];
        if (tx.groupId != null && tx.groupId!.startsWith('transfer_')) {
          pairedRows = await txn.query(
            'transactions',
            where: 'groupId = ? AND id != ?',
            whereArgs: [tx.groupId, tx.id],
          );
        } else {
          // Fallback cho giao dịch chuyển tiền cũ chưa có groupId transfer_
          final oppositeCategory = (tx.category == 'Chuyển tiền') ? 'Nhận chuyển tiền' : 'Chuyển tiền';
          final oppositeType = (tx.type == 'expense') ? 'income' : 'expense';
          pairedRows = await txn.query(
            'transactions',
            where: 'uid = ? AND category = ? AND type = ? AND date = ? AND time = ? AND id != ?',
            whereArgs: [
              tx.uid,
              oppositeCategory,
              oppositeType,
              tx.date.millisecondsSinceEpoch,
              tx.time,
              tx.id,
            ],
            limit: 1,
          );
        }

        for (final row in pairedRows) {
          final pairedTx = TransactionModel.fromSqlite(row);
          if (pairedTx.walletId.isNotEmpty) {
            final pairedRevertDelta = (pairedTx.type == 'income') ? -pairedTx.amount : pairedTx.amount;
            await _adjustWalletInTxn(txn, pairedTx.walletId, pairedRevertDelta);
          }
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [pairedTx.id],
          );
          await txn.insert('sync_queue', {
            'tableName': 'transactions',
            'recordId': pairedTx.id,
            'action': 'DELETE',
            'data': null,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'retryCount': 0,
          });
        }
      }
    });

    _txRepo.notifyTransactionsChanged();
    _walletRepo.notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }
  }

  /// ═══════════════════════════════════════════════
  /// HELPER: Điều chỉnh số dư ví bên trong Transaction
  /// ═══════════════════════════════════════════════
  Future<void> _adjustWalletInTxn(
    Transaction txn,
    String walletId,
    double amountDelta,
  ) async {
    if (walletId.isEmpty) return;

    final rows = await txn.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [walletId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final currentWallet = WalletModel.fromSqlite(rows.first);
      final newBalance = currentWallet.balance + amountDelta;
      final now = DateTime.now();

      final updatedWallet = currentWallet.copyWith(
        balance: newBalance,
        updatedAt: now,
        syncStatus: 'pending',
      );

      await txn.update(
        'wallets',
        updatedWallet.toSqlite(),
        where: 'id = ?',
        whereArgs: [walletId],
      );

      await txn.insert('sync_queue', {
        'tableName': 'wallets',
        'recordId': walletId,
        'action': 'UPDATE',
        'data': jsonEncode(updatedWallet.toSqlite()),
        'createdAt': now.millisecondsSinceEpoch,
        'retryCount': 0,
      });
    }
  }
}
