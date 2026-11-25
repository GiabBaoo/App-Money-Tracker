import 'dart:async';
import 'package:flutter/material.dart';
import '../core/logging/app_logger.dart';
import '../data/local/database_helper.dart';
import '../data/local/sync_queue_writer.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../models/wallet_model.dart';
import '../models/goal_model.dart';
import '../utils/finance_precision.dart';
import 'sync_service.dart';

/// Dịch vụ đối soát số dư sổ cái (Ledger-Derived Balance Reconciliation)
/// Đảm bảo số dư Ví (wallets.balance) và Mục tiêu (goals.currentAmount)
/// luôn hội tụ chính xác tuyệt đối sau các chu kỳ đồng bộ đa thiết bị (Strong Eventual Consistency),
/// đồng thời tái tạo ví bị thiếu từ lịch sử giao dịch khi thiết bị mới chưa nhận được bảng wallets.
class LedgerReconciliationService {
  static final LedgerReconciliationService _instance =
      LedgerReconciliationService._internal();
  factory LedgerReconciliationService() => _instance;
  LedgerReconciliationService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const List<int> _fallbackColors = [
    0xFF438883,
    0xFFD82D8B,
    0xFF0068FF,
    0xFF006E33,
    0xFF1429A0,
    0xFFE31B23,
  ];

  /// Đối soát và tái tính toán số dư cho toàn bộ Ví và Mục tiêu của một người dùng
  Future<void> reconcileAll(String uid) async {
    if (uid.isEmpty) return;
    try {
      final reconstructed = await reconstructMissingWalletsFromTransactions(
        uid,
      );
      final walletsUpdated = await reconcileWallets(
        uid,
        forceLedgerOverwrite: false,
      );
      final goalsUpdated = await reconcileGoals(uid);

      if (reconstructed > 0 || walletsUpdated > 0) {
        WalletRepository().notifyChanged();
      }
      if (goalsUpdated > 0) {
        GoalRepository().notifyChanged();
      }
      if (reconstructed > 0 || walletsUpdated > 0 || goalsUpdated > 0) {
        unawaited(SyncService().syncAll());
      }
    } catch (e, st) {
      AppLogger.error(
        'LedgerReconciliationService.reconcileAll thất bại',
        tag: 'LedgerReconciliation',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Tái tạo các ví bị thiếu trên thiết bị mới dựa trên lịch sử giao dịch (transactions)
  /// khi máy cũ chưa kịp đẩy bảng wallets hoặc bảng wallets trên Firestore bị rỗng.
  Future<int> reconstructMissingWalletsFromTransactions(String uid) async {
    if (uid.isEmpty) return 0;
    final db = await _dbHelper.database;

    final txRows = await db.query(
      'transactions',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
    );
    if (txRows.isEmpty) return 0;

    final existingWalletRows = await db.query(
      'wallets',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    final activeWalletIds = <String>{};
    final deletedWalletById = <String, Map<String, dynamic>>{};
    bool hasDefaultWallet = false;

    for (final row in existingWalletRows) {
      final id = row['id'] as String? ?? '';
      final isDel = (row['isDeleted'] as int? ?? 0) == 1;
      if (!isDel) {
        activeWalletIds.add(id);
        if ((row['isDefault'] as int? ?? 0) == 1) {
          hasDefaultWallet = true;
        }
      } else if (id.isNotEmpty) {
        deletedWalletById[id] = row;
      }
    }

    // Thu thập tên ví gợi ý từ mô tả giao dịch chuyển tiền ("Chuyển sang [Tên]" / "Nhận từ [Tên]")
    final inferredNames = <String, String>{};
    final txByTransferId = <String, List<Map<String, dynamic>>>{};
    for (final tx in txRows) {
      final trId = tx['transferId'] as String?;
      if (trId != null && trId.isNotEmpty) {
        txByTransferId.putIfAbsent(trId, () => []).add(tx);
      }
    }
    final bracketRegex = RegExp(r'\[([^\]]+)\]');
    for (final pair in txByTransferId.values) {
      for (final tx in pair) {
        final desc = tx['description'] as String? ?? '';
        final match = bracketRegex.firstMatch(desc);
        if (match == null) continue;
        final mentionedName = match.group(1)?.trim() ?? '';
        if (mentionedName.isEmpty) continue;
        // Nếu tx hiện tại là "Chuyển sang [X]", thì X là tên của ví đối ứng trong cùng transferId
        for (final other in pair) {
          final otherWid = other['walletId'] as String? ?? '';
          final curWid = tx['walletId'] as String? ?? '';
          if (otherWid.isNotEmpty && otherWid != curWid) {
            inferredNames.putIfAbsent(otherWid, () => mentionedName);
          }
        }
      }
    }

    // Gom nhóm thu/chi theo walletId (giao dịch không có walletId gom về wlt_default_$uid)
    final defaultWalletId = 'wlt_default_$uid';
    final incomeByWallet = <String, double>{};
    final expenseByWallet = <String, double>{};
    final earliestTxByWallet = <String, int>{};
    final hasEmptyWalletTx = txRows.any(
      (r) => (r['walletId'] as String? ?? '').trim().isEmpty,
    );

    for (final tx in txRows) {
      final rawWid = (tx['walletId'] as String? ?? '').trim();
      final wid = rawWid.isEmpty ? defaultWalletId : rawWid;
      final type = tx['type'] as String? ?? 'expense';
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final createdAt =
          (tx['createdAt'] as int?) ??
          (tx['date'] as int?) ??
          DateTime.now().millisecondsSinceEpoch;

      if (type == 'income') {
        incomeByWallet[wid] = (incomeByWallet[wid] ?? 0.0) + amount;
      } else {
        expenseByWallet[wid] = (expenseByWallet[wid] ?? 0.0) + amount;
      }
      final prevEarliest = earliestTxByWallet[wid];
      if (prevEarliest == null || createdAt < prevEarliest) {
        earliestTxByWallet[wid] = createdAt;
      }
    }

    final referencedWalletIds = <String>{
      ...incomeByWallet.keys,
      ...expenseByWallet.keys,
    };

    int reconstructedCount = 0;
    int colorIdx = activeWalletIds.length;

    await db.transaction((txn) async {
      // Gán các giao dịch có walletId rỗng về ví tiền mặt mặc định (wlt_default_$uid)
      if (hasEmptyWalletTx) {
        await txn.rawUpdate(
          "UPDATE transactions SET walletId = ? WHERE uid = ? AND (walletId IS NULL OR walletId = '')",
          [defaultWalletId, uid],
        );
      }

      for (final wid in referencedWalletIds) {
        if (wid.isEmpty || activeWalletIds.contains(wid)) continue;

        final inc = incomeByWallet[wid] ?? 0.0;
        final exp = expenseByWallet[wid] ?? 0.0;
        final net = FinancePrecision.roundCurrency(inc - exp);

        String name = inferredNames[wid] ?? '';
        if (name.isEmpty) {
          final deletedRow = deletedWalletById[wid];
          final deletedName = (deletedRow?['name'] as String? ?? '').trim();
          if (deletedName.isNotEmpty) {
            name = deletedName;
          } else if (wid == defaultWalletId ||
              (activeWalletIds.isEmpty && reconstructedCount == 0)) {
            name = 'Ví tiền mặt';
          } else {
            name = 'Ví tiền ${activeWalletIds.length + reconstructedCount + 1}';
          }
        }

        final nameLower = name.toLowerCase();
        String type = WalletType.cash;
        int iconCode = Icons.payments_rounded.codePoint;
        int colorValue = _fallbackColors[colorIdx % _fallbackColors.length];
        colorIdx++;

        if (nameLower.contains('momo') || nameLower.contains('zalo')) {
          type = WalletType.eWallet;
          iconCode = Icons.phone_android_rounded.codePoint;
          colorValue = 0xFFD82D8B;
        } else if (nameLower.contains('bank') ||
            nameLower.contains('ngân hàng') ||
            nameLower.contains('vcb') ||
            nameLower.contains('mb')) {
          type = WalletType.bank;
          iconCode = Icons.account_balance_rounded.codePoint;
          colorValue = 0xFF1429A0;
        }

        final double initialBalance = net < 0 ? net.abs() : 0.0;
        final double balance = net > 0 ? net : 0.0;
        const String syncStatus = 'local_only';
        const int updatedAtMs = 0;

        final assignDefault = !hasDefaultWallet;
        if (assignDefault) {
          hasDefaultWallet = true;
        }

        final createdMs =
            earliestTxByWallet[wid] ?? DateTime.now().millisecondsSinceEpoch;
        final wallet = WalletModel(
          id: wid,
          uid: uid,
          name: name,
          type: type,
          balance: balance,
          initialBalance: initialBalance,
          iconCode: iconCode,
          colorValue: colorValue,
          isDefault: assignDefault,
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
          syncStatus: syncStatus,
          isDeleted: false,
        );

        final row = wallet.toSqlite();
        if (deletedWalletById.containsKey(wid)) {
          await txn.update(
            'wallets',
            row,
            where: 'id = ? AND uid = ?',
            whereArgs: [wid, uid],
          );
        } else {
          await txn.insert('wallets', row);
        }
        if (syncStatus == 'pending') {
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'wallets',
            recordId: wid,
            action: 'INSERT',
            data: row,
          );
        }
        activeWalletIds.add(wid);
        reconstructedCount++;
      }
    });

    if (reconstructedCount > 0) {
      AppLogger.info(
        'LedgerReconciliation: Đã tái tạo $reconstructedCount ví bị thiếu từ lịch sử giao dịch',
        tag: 'LedgerReconciliation',
      );
    }
    return reconstructedCount;
  }

  /// Đối soát số dư toàn bộ các ví của user dựa trên công thức Sổ cái SSOT:
  /// `expectedBalance = initialBalance + totalIncome - totalExpense`.
  /// Tuyệt đối không sửa ngầm `initialBalance` cục bộ khi phát hiện lệch.
  Future<int> reconcileWallets(
    String uid, {
    bool forceLedgerOverwrite = true,
  }) async {
    final db = await _dbHelper.database;
    final walletRows = await db.query(
      'wallets',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
    );

    // Kiểm tra xem transactions đã từng hoàn tất ít nhất 1 lần tải từ server chưa
    bool hasTxSyncMetadata = false;
    if (!forceLedgerOverwrite) {
      final metaRows = await db.query(
        'sync_metadata',
        columns: ['lastSyncTimestamp'],
        where: 'uid = ? AND tableName = ?',
        whereArgs: [uid, 'transactions'],
        limit: 1,
      );
      hasTxSyncMetadata = metaRows.isNotEmpty;
    }

    int updatedCount = 0;
    for (final wRow in walletRows) {
      final wallet = WalletModel.fromSqlite(wRow);

      // Chỉ đối soát các ví đang ở trạng thái 'synced' hoặc 'local_only' để không ghi đè thay đổi local đang chờ đẩy
      if (wallet.syncStatus != 'synced' && wallet.syncStatus != 'local_only') {
        continue;
      }

      // Không đối soát nếu ví hoặc bảng transactions đang có item pending/processing trong sync_queue
      final pendingQueue = await db.rawQuery(
        'SELECT 1 FROM sync_queue '
        'WHERE (ownerUid = ? OR uid = ?) '
        'AND status IN (?, ?) '
        'AND ((tableName = ? AND recordId = ?) OR tableName = ?) '
        'LIMIT 1',
        [
          uid,
          uid,
          'pending',
          'processing',
          'wallets',
          wallet.id,
          'transactions',
        ],
      );
      if (pendingQueue.isNotEmpty) {
        continue;
      }

      // Tính tổng thu, tổng chi và số lượng giao dịch của ví từ bảng transactions
      final countRes = await db.rawQuery(
        "SELECT COUNT(*) as txCount FROM transactions "
        "WHERE uid = ? AND walletId = ? AND (isDeleted IS NULL OR isDeleted = 0)",
        [uid, wallet.id],
      );
      final txCount = (countRes.first['txCount'] as int?) ?? 0;

      // Bảo vệ: nếu ví có balance != initialBalance nhưng chưa có giao dịch local nào
      // và chưa từng hoàn tất tải transactions từ server, bỏ qua để tránh ghi đè sớm.
      if (!forceLedgerOverwrite &&
          txCount == 0 &&
          !hasTxSyncMetadata &&
          (wallet.balance - wallet.initialBalance).abs() > 0.001) {
        AppLogger.warn(
          'LedgerReconciliation: Bỏ qua ví [${wallet.name}] vì chưa hoàn tất tải transactions (balance=${wallet.balance}, initial=${wallet.initialBalance})',
          tag: 'LedgerReconciliation',
        );
        continue;
      }

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
      final totalExpense =
          (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final netLedger = FinancePrecision.roundCurrency(
        totalIncome - totalExpense,
        currency: wallet.currency,
      );

      final expectedBalance = FinancePrecision.roundCurrency(
        wallet.initialBalance + netLedger,
        currency: wallet.currency,
      );

      if ((wallet.balance - expectedBalance).abs() > 0.001) {
        AppLogger.info(
          'LedgerReconciliation: Lệch số dư ví [${wallet.name}] (Hiện tại: ${wallet.balance}, Sổ cái: $expectedBalance). Tự động cân bằng...',
          tag: 'LedgerReconciliation',
        );
        final updatedWallet = wallet.copyWith(
          balance: expectedBalance,
          updatedAt: DateTime.now().toUtc(),
          syncStatus: 'pending',
        );
        final fullRow = updatedWallet.toSqlite();
        await db.transaction((txn) async {
          await txn.update(
            'wallets',
            fullRow,
            where: 'id = ? AND uid = ?',
            whereArgs: [wallet.id, uid],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'wallets',
            recordId: wallet.id,
            action: 'UPDATE',
            data: fullRow,
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

      final txRows = await db.query(
        'transactions',
        where:
            'uid = ? AND goalId = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid, goal.id],
      );

      if (txRows.isEmpty) continue;

      double netSaved = 0.0;
      for (final txRow in txRows) {
        final amount = (txRow['amount'] as num?)?.toDouble() ?? 0.0;
        final type = txRow['type'] as String? ?? 'expense';
        if (type == 'expense') {
          netSaved += amount;
        } else if (type == 'income') {
          netSaved -= amount;
        }
      }

      final expectedCurrent = FinancePrecision.roundCurrency(netSaved);
      if (expectedCurrent >= 0 &&
          (goal.currentAmount - expectedCurrent).abs() > 0.001) {
        AppLogger.info(
          'LedgerReconciliation: Lệch số dư mục tiêu [${goal.title}] (Hiện tại: ${goal.currentAmount}, Sổ cái: $expectedCurrent). Tự động cân bằng...',
          tag: 'LedgerReconciliation',
        );
        final updatedGoal = goal.copyWith(
          currentAmount: expectedCurrent,
          updatedAt: DateTime.now().toUtc(),
          syncStatus: 'pending',
        );
        final fullRow = updatedGoal.toSqlite();
        await db.transaction((txn) async {
          await txn.update(
            'goals',
            fullRow,
            where: 'id = ? AND uid = ?',
            whereArgs: [goal.id, uid],
          );
          await SyncQueueWriter.enqueue(
            txn,
            ownerUid: uid,
            table: 'goals',
            recordId: goal.id,
            action: 'INSERT',
            data: fullRow,
          );
        });
        updatedCount++;
      }
    }

    return updatedCount;
  }
}
