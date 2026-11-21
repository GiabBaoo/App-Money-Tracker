import 'dart:async';
import '../core/logging/app_logger.dart';
import '../data/local/database_helper.dart';
import '../data/local/sync_queue_writer.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../models/wallet_model.dart';
import '../models/goal_model.dart';
import '../utils/finance_precision.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

/// Dịch vụ đối soát số dư sổ cái (Ledger-Derived Balance Reconciliation)
/// Đảm bảo số dư Ví (wallets.balance) và Mục tiêu (goals.currentAmount)
/// luôn hội tụ chính xác tuyệt đối sau các chu kỳ đồng bộ đa thiết bị (Strong Eventual Consistency),
/// triệt tiêu hoàn toàn bài toán Lost Update khi nhiều thiết bị cùng chi tiêu offline.
class LedgerReconciliationService {
  static final LedgerReconciliationService _instance =
      LedgerReconciliationService._internal();
  factory LedgerReconciliationService() => _instance;
  LedgerReconciliationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Đối soát và tái tính toán số dư cho toàn bộ Ví và Mục tiêu của một người dùng
  Future<void> reconcileAll(String uid) async {
    if (uid.isEmpty) return;
    try {
      final walletsUpdated = await reconcileWallets(uid);
      final goalsUpdated = await reconcileGoals(uid);

      if (walletsUpdated > 0) {
        WalletRepository().notifyChanged();
      }
      if (goalsUpdated > 0) {
        GoalRepository().notifyChanged();
      }
      if ((walletsUpdated > 0 || goalsUpdated > 0) && ConnectivityService().isOnline) {
        unawaited(SyncService().syncAll());
      }
    } catch (e, st) {
      AppLogger.error('LedgerReconciliationService.reconcileAll thất bại', tag: 'LedgerReconciliation', error: e, stackTrace: st);
    }
  }

  /// Đối soát số dư toàn bộ các ví của user dựa trên các giao dịch thực tế
  Future<int> reconcileWallets(String uid) async {
    final db = await _dbHelper.database;
    final walletRows = await db.query(
      'wallets',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
    );

    int updatedCount = 0;
    for (final wRow in walletRows) {
      final wallet = WalletModel.fromSqlite(wRow);

      // Chỉ đối soát các ví đang ở trạng thái 'synced' để không ghi đè thay đổi local đang chờ đẩy
      if (wallet.syncStatus != 'synced') continue;

      // Tính tổng thu và tổng chi của ví từ bảng transactions
      final incomeRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transactions "
        "WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0) AND type = 'income'",
        [uid, wallet.id],
      );
      final expenseRes = await db.rawQuery(
        "SELECT COALESCE(SUM(amount), 0) as total FROM transactions "
        "WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0) AND type = 'expense'",
        [uid, wallet.id],
      );

      final totalIncome = (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final totalExpense = (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final expectedBalance = FinancePrecision.roundCurrency(
        wallet.initialBalance + totalIncome - totalExpense,
        currency: wallet.currency,
      );

      // Nếu có sự sai lệch số dư do Lost Update từ thiết bị khác
      if ((wallet.balance - expectedBalance).abs() > 0.001) {
        AppLogger.info(
          'LedgerReconciliation: Lệch số dư ví [${wallet.name}] (Hiện tại: ${wallet.balance}, Sổ cái: $expectedBalance). Tự động cân bằng...',
          tag: 'LedgerReconciliation',
        );
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final updateData = {
          'balance': expectedBalance.round(),
          'updatedAt': nowMs,
          'syncStatus': 'pending',
        };
        await db.transaction((txn) async {
          await txn.update(
            'wallets',
            updateData,
            where: 'id = ? AND uid = ?',
            whereArgs: [wallet.id, uid],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'wallets',
            recordId: wallet.id,
            action: 'UPDATE',
            data: updateData,
          );
        });
        updatedCount++;
      }
    }

    return updatedCount;
  }

  /// Đối soát số dư mục tiêu tài chính nếu có giao dịch liên kết
  Future<int> reconcileGoals(String uid) async {
    final db = await _dbHelper.database;
    final goalRows = await db.query(
      'goals',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
    );

    int updatedCount = 0;
    for (final gRow in goalRows) {
      final goal = GoalModel.fromSqlite(gRow);
      if (goal.syncStatus != 'synced') continue;

      // Tính các giao dịch tích lũy liên kết với goal này
      final txRows = await db.query(
        'transactions',
        where: 'uid = ? AND goalId = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid, goal.id],
      );

      if (txRows.isEmpty) continue;

      double netSaved = 0.0;
      for (final txRow in txRows) {
        final amount = (txRow['amount'] as num?)?.toDouble() ?? 0.0;
        final type = txRow['type'] as String? ?? 'expense';
        // Chi tiêu 'Tiết kiệm' nạp vào mục tiêu (+)
        // Thu nhập 'Rút tiết kiệm' rút khỏi mục tiêu (-)
        if (type == 'expense') {
          netSaved += amount;
        } else if (type == 'income') {
          netSaved -= amount;
        }
      }

      final expectedCurrent = FinancePrecision.roundCurrency(netSaved);
      if (expectedCurrent >= 0 && (goal.currentAmount - expectedCurrent).abs() > 0.001) {
        AppLogger.info(
          'LedgerReconciliation: Lệch số dư mục tiêu [${goal.title}] (Hiện tại: ${goal.currentAmount}, Sổ cái: $expectedCurrent). Tự động cân bằng...',
          tag: 'LedgerReconciliation',
        );
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final updateData = {
          'currentAmount': expectedCurrent.round(),
          'updatedAt': nowMs,
          'syncStatus': 'pending',
        };
        await db.transaction((txn) async {
          await txn.update(
            'goals',
            updateData,
            where: 'id = ? AND uid = ?',
            whereArgs: [goal.id, uid],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'goals',
            recordId: goal.id,
            action: 'UPDATE',
            data: updateData,
          );
        });
        updatedCount++;
      }
    }

    return updatedCount;
  }
}
