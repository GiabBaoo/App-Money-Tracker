import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/session/session_manager.dart';
import '../data/local/database_helper.dart';
import '../data/local/sync_queue_writer.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../utils/finance_precision.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'app_widget_service.dart';
import 'smart_notification_service.dart';

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
    final uid = SessionManager.instance.requireUid();
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

    final effectiveTx = targetWalletId.isNotEmpty
        ? transaction.copyWith(walletId: targetWalletId, uid: uid)
        : transaction.copyWith(uid: uid);

    final id = await db.transaction<String>((txn) async {
      // 1. Thêm giao dịch & sync_queue của transaction
      final txId = await _txRepo.addTransactionInTxn(txn, effectiveTx);

      // 2. Điều chỉnh số dư ví & sync_queue của wallet
      if (effectiveTx.walletId.isNotEmpty) {
        final delta = effectiveTx.type == 'income'
            ? effectiveTx.amount
            : -effectiveTx.amount;
        await _adjustWalletInTxn(txn, effectiveTx.walletId, delta, uid);
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

    // Tự động cập nhật số dư Android App Widget
    unawaited(AppWidgetService.instance.updateWidgetBalance());

    // Kiểm tra và cảnh báo ngưỡng ngân sách (80% / 100%) khi phát sinh chi tiêu
    if (effectiveTx.type == 'expense' && !effectiveTx.isTransfer) {
      unawaited(
        SmartNotificationService.instance.checkCategoryBudgetThresholds(
          category: effectiveTx.category,
          expenseAmount: effectiveTx.amount,
        ),
      );
    }

    return id;
  }

  /// ═══════════════════════════════════════════════
  /// 2. SỬA GIAO DỊCH + CÂN ĐỐI SỐ DƯ VÍ (ATOMIC)
  /// ═══════════════════════════════════════════════
  Future<void> editTransactionAtomic({
    required TransactionModel oldTx,
    required TransactionModel newTx,
  }) async {
    final uid = SessionManager.instance.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final oldWalletId = oldTx.walletId;
      final newWalletId = newTx.walletId;
      final oldType = oldTx.type;
      final newType = newTx.type;
      final oldAmount = oldTx.amount;
      final newAmount = newTx.amount;

      // Bước 1: Revert tác động cũ lên oldWalletId
      if (oldWalletId.isNotEmpty) {
        final revertDelta = (oldType == 'income') ? -oldAmount : oldAmount;
        await _adjustWalletInTxn(txn, oldWalletId, revertDelta, uid);
      }

      // Bước 2: Apply tác động mới lên newWalletId
      if (newWalletId.isNotEmpty) {
        final applyDelta = (newType == 'income') ? newAmount : -newAmount;
        await _adjustWalletInTxn(txn, newWalletId, applyDelta, uid);
      }

      // Bước 3: Cập nhật giao dịch trong bảng transactions
      final now = DateTime.now();
      final updatedTx = newTx.copyWith(
        uid: uid,
        updatedAt: now,
        syncStatus: 'pending',
      );

      final row = updatedTx.toSqlite();
      await txn.update(
        'transactions',
        row,
        where: 'id = ? AND uid = ?',
        whereArgs: [newTx.id, uid],
      );

      // Bước 4: Thêm bản ghi sync_queue cho transactions
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: newTx.id,
        action: 'UPDATE',
        data: row,
      );
    });

    _txRepo.notifyTransactionsChanged();
    _walletRepo.notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    // Tự động cập nhật số dư Android App Widget
    unawaited(AppWidgetService.instance.updateWidgetBalance());

    // Kiểm tra và cảnh báo ngưỡng ngân sách khi cập nhật chi tiêu
    if (newTx.type == 'expense' && !newTx.isTransfer) {
      unawaited(
        SmartNotificationService.instance.checkCategoryBudgetThresholds(
          category: newTx.category,
          expenseAmount: newTx.amount,
        ),
      );
    }
  }

  /// ═══════════════════════════════════════════════
  /// 3. XÓA GIAO DỊCH + HOÀN LẠI SỐ DƯ VÍ (ATOMIC)
  /// ═══════════════════════════════════════════════
  Future<void> deleteTransactionAtomic(TransactionModel tx) async {
    final uid = SessionManager.instance.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Hoàn lại số dư ví nếu giao dịch có liên kết ví
      if (tx.walletId.isNotEmpty) {
        final revertDelta = (tx.type == 'income') ? -tx.amount : tx.amount;
        await _adjustWalletInTxn(txn, tx.walletId, revertDelta, uid);
      }

      // 2. Xóa khỏi bảng transactions
      await txn.delete(
        'transactions',
        where: 'id = ? AND uid = ?',
        whereArgs: [tx.id, uid],
      );

      // 3. Thêm bản ghi sync_queue DELETE
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'transactions',
        recordId: tx.id,
        action: 'DELETE',
      );

      // 4. Nếu là giao dịch chuyển tiền hai chiều, tìm và hoàn lại giao dịch đối ứng cùng lúc
      if (tx.isTransfer) {
        List<Map<String, dynamic>> pairedRows = [];
        if (tx.groupId != null && tx.groupId!.startsWith('transfer_')) {
          pairedRows = await txn.query(
            'transactions',
            where: 'uid = ? AND groupId = ? AND id != ?',
            whereArgs: [uid, tx.groupId, tx.id],
          );
        } else {
          // Fallback cho giao dịch chuyển tiền cũ chưa có groupId transfer_
          final oppositeCategory = (tx.category == 'Chuyển tiền')
              ? 'Nhận chuyển tiền'
              : 'Chuyển tiền';
          final oppositeType = (tx.type == 'expense') ? 'income' : 'expense';
          pairedRows = await txn.query(
            'transactions',
            where:
                'uid = ? AND category = ? AND type = ? AND date = ? AND time = ? AND id != ?',
            whereArgs: [
              uid,
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
            final pairedRevertDelta = (pairedTx.type == 'income')
                ? -pairedTx.amount
                : pairedTx.amount;
            await _adjustWalletInTxn(
              txn,
              pairedTx.walletId,
              pairedRevertDelta,
              uid,
            );
          }
          await txn.delete(
            'transactions',
            where: 'id = ? AND uid = ?',
            whereArgs: [pairedTx.id, uid],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'transactions',
            recordId: pairedTx.id,
            action: 'DELETE',
          );
        }
      }
    });

    _txRepo.notifyTransactionsChanged();
    _walletRepo.notifyChanged();

    if (ConnectivityService().isOnline) {
      unawaited(SyncService().syncAll());
    }

    // Tự động cập nhật số dư Android App Widget
    unawaited(AppWidgetService.instance.updateWidgetBalance());
  }

  /// ═══════════════════════════════════════════════
  /// HELPER: Điều chỉnh số dư ví bên trong Transaction
  /// ═══════════════════════════════════════════════
  Future<void> _adjustWalletInTxn(
    Transaction txn,
    String walletId,
    double amountDelta, [
    String? ownerUid,
  ]) async {
    if (walletId.isEmpty) return;
    final uid = ownerUid ?? SessionManager.instance.requireUid();

    final rows = await txn.query(
      'wallets',
      where: 'id = ? AND uid = ?',
      whereArgs: [walletId, uid],
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
      final row = updatedWallet.toSqlite();

      await txn.update(
        'wallets',
        row,
        where: 'id = ? AND uid = ?',
        whereArgs: [walletId, uid],
      );

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'wallets',
        recordId: walletId,
        action: 'UPDATE',
        data: row,
      );
    }
  }

  /// ══════════════════════════════════════════════════════════════════
  /// 5. ĐỘNG CƠ ĐỐI SOÁT SỔ CÁI & TỰ CÂN BẰNG (RECONCILIATION ENGINE)
  /// ══════════════════════════════════════════════════════════════════
  Future<ReconciliationReport> reconcileWalletBalances({
    String? targetUid,
    ReconciliationMode mode = ReconciliationMode.auditOnly,
  }) async {
    final uid = targetUid ?? SessionManager.instance.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now();

    const sql = '''
      SELECT 
        w.id AS walletId,
        w.name AS walletName,
        w.balance AS cachedBalance,
        w.initialBalance AS initialBalance,
        w.currency AS currency,
        COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0.0 END), 0.0) AS totalIncome,
        COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0.0 END), 0.0) AS totalExpense
      FROM wallets w
      LEFT JOIN transactions t 
        ON t.walletId = w.id 
        AND t.uid = w.uid 
        AND (t.isDeleted IS NULL OR t.isDeleted = 0)
      WHERE w.uid = ? 
        AND (w.isDeleted IS NULL OR w.isDeleted = 0)
      GROUP BY w.id;
    ''';

    final rows = await db.rawQuery(sql, [uid]);
    final List<WalletDiscrepancy> discrepancies = [];
    bool hasModified = false;

    for (final row in rows) {
      final walletId = row['walletId'] as String;
      final walletName = row['walletName'] as String;
      final currency = (row['currency'] as String?) ?? 'VND';
      final cachedBalance = (row['cachedBalance'] as num).toDouble();
      final initialBalance = (row['initialBalance'] as num).toDouble();
      final totalIncome = (row['totalIncome'] as num).toDouble();
      final totalExpense = (row['totalExpense'] as num).toDouble();

      final calculatedBalance = FinancePrecision.roundCurrency(
        initialBalance + totalIncome - totalExpense,
        currency: currency,
      );
      final delta = FinancePrecision.roundCurrency(
        calculatedBalance - cachedBalance,
        currency: currency,
      );
      final isBalanced = FinancePrecision.areEqual(
        cachedBalance,
        calculatedBalance,
      );

      ReconciliationStatus itemStatus = isBalanced
          ? ReconciliationStatus.balanced
          : ReconciliationStatus.discrepant;

      if (!isBalanced && mode != ReconciliationMode.auditOnly) {
        await db.transaction((txn) async {
          if (mode == ReconciliationMode.healByLedgerRebalance) {
            final updateData = {
              'balance': calculatedBalance,
              'updatedAt': now.millisecondsSinceEpoch,
              'syncStatus': 'pending',
            };
            await txn.update(
              'wallets',
              updateData,
              where: 'id = ? AND uid = ?',
              whereArgs: [walletId, uid],
            );
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: uid,
              table: 'wallets',
              recordId: walletId,
              action: 'UPDATE',
              data: updateData,
            );
            itemStatus = ReconciliationStatus.healed;
            hasModified = true;
          } else if (mode == ReconciliationMode.healByAdjustmentTransaction) {
            final adjAmount = delta.abs();
            final isAdjIncome = delta < 0;
            final adjTx = TransactionModel(
              id: const Uuid().v4(),
              uid: uid,
              type: isAdjIncome ? 'income' : 'expense',
              category: 'Điều chỉnh số dư',
              categoryIconCode: isAdjIncome
                  ? Icons.account_balance_wallet_outlined.codePoint
                  : Icons.price_change_outlined.codePoint,
              amount: adjAmount,
              date: now,
              time:
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              description: 'Bút toán đối soát cân bằng sổ cái',
              walletId: walletId,
              source: 'personal',
              syncStatus: 'pending',
            );
            final adjMap = adjTx.toSqlite();
            adjMap['uid'] = uid;
            await txn.insert('transactions', adjMap);
            await SyncQueueWriter.enqueue(
              txn,
              ownerUid: uid,
              table: 'transactions',
              recordId: adjTx.id,
              action: 'INSERT',
              data: adjMap,
            );
            itemStatus = ReconciliationStatus.healed;
            hasModified = true;
          }
        });
      }

      discrepancies.add(
        WalletDiscrepancy(
          walletId: walletId,
          walletName: walletName,
          cachedBalance: cachedBalance,
          initialBalance: initialBalance,
          totalIncomeLedger: totalIncome,
          totalExpenseLedger: totalExpense,
          calculatedBalance: calculatedBalance,
          delta: delta,
          status: itemStatus,
        ),
      );
    }

    if (hasModified) {
      _walletRepo.notifyChanged();
      _txRepo.notifyTransactionsChanged();
      if (ConnectivityService().isOnline) {
        unawaited(SyncService().syncAll());
      }
    }

    final hasDiscrepancy = discrepancies.any(
      (d) => d.status == ReconciliationStatus.discrepant,
    );

    return ReconciliationReport(
      uid: uid,
      auditedAt: now,
      items: discrepancies,
      hasDiscrepancy: hasDiscrepancy,
    );
  }

  /// ══════════════════════════════════════════════════════════════════
  /// 6. KHÔI PHỤC SỐ DƯ GỐC (VÔ HIỆU HÓA Ở P0 ĐỂ TRÁNH GHI ĐÈ SỐ DƯ CỨNG)
  /// ══════════════════════════════════════════════════════════════════
  Future<void> restoreCorrectUserBaselineOnce({String? targetUid}) async {
    // Vô hiệu hóa ở P0 (no-op) theo PLAN_P0_SECURITY.md §4
    return;
  }

  /// Alias hỗ trợ tương thích ngược nếu còn lời gọi cũ
  Future<void> reconcileUserBaseline({
    String? targetUid,
    String? targetEmail,
  }) async {
    await restoreCorrectUserBaselineOnce(targetUid: targetUid);
  }
}

/// Trạng thái đối soát của từng ví
enum ReconciliationStatus {
  balanced, // Số dư khớp hoàn toàn (sai số < epsilon)
  discrepant, // Phát hiện lệch giữa cache và sổ cái
  healed, // Đã tự động cân đối/điều chỉnh thành công
}

/// Chế độ đối soát
enum ReconciliationMode {
  auditOnly, // Chỉ đối soát, không ghi đè database
  healByLedgerRebalance, // Đồng bộ wallets.balance theo sổ cái
  healByAdjustmentTransaction, // Tạo bút toán điều chỉnh minh bạch
}

/// Báo cáo chi tiết sai lệch của từng ví
class WalletDiscrepancy {
  final String walletId;
  final String walletName;
  final double cachedBalance; // Số dư đang hiển thị ở wallets.balance
  final double initialBalance; // Số dư khởi tạo ban đầu
  final double totalIncomeLedger; // Tổng thu từ sổ transactions
  final double totalExpenseLedger; // Tổng chi từ sổ transactions
  final double calculatedBalance; // initialBalance + Income - Expense
  final double delta; // calculatedBalance - cachedBalance
  final ReconciliationStatus status;

  const WalletDiscrepancy({
    required this.walletId,
    required this.walletName,
    required this.cachedBalance,
    required this.initialBalance,
    required this.totalIncomeLedger,
    required this.totalExpenseLedger,
    required this.calculatedBalance,
    required this.delta,
    required this.status,
  });
}

/// Báo cáo tổng hợp đối soát của toàn bộ tài khoản
class ReconciliationReport {
  final String uid;
  final DateTime auditedAt;
  final List<WalletDiscrepancy> items;
  final bool hasDiscrepancy;

  const ReconciliationReport({
    required this.uid,
    required this.auditedAt,
    required this.items,
    required this.hasDiscrepancy,
  });

  /// Map tương thích ngược: walletId -> delta
  Map<String, double> toMap() => {
    for (final item in items) item.walletId: item.delta,
  };
}
