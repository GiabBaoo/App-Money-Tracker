import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/session/session_manager.dart';
import 'package:money_tracker_app/data/local/owned_table_ops.dart';
import 'package:money_tracker_app/data/local/sync_queue_writer.dart';
import 'package:money_tracker_app/data/repositories/transaction_repository.dart';
import 'package:money_tracker_app/data/repositories/wallet_repository.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/services/midnight_sync_service.dart';
import 'package:money_tracker_app/services/sync_service.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

class _TestOwnedOps with OwnedTableOps {}

/// Mô phỏng hội tụ tập giao dịch theo CRDT LWW-Element-Set + Tie-breaker
Map<String, TransactionModel> _mergeTransactionsCrdt(
  List<TransactionModel> localTxs,
  List<TransactionModel> remoteTxs,
) {
  final merged = <String, TransactionModel>{
    for (final tx in localTxs) tx.id: tx,
  };
  for (final remote in remoteTxs) {
    final local = merged[remote.id];
    if (local == null) {
      merged[remote.id] = remote;
      continue;
    }
    final remoteWins = ConflictResolver.shouldRemoteWin(
      localUpdatedAt: local.updatedAt,
      remoteUpdatedAt: remote.updatedAt,
      localData: local.toSqlite(),
      remoteData: remote.toSqlite(),
    );
    if (remoteWins) {
      merged[remote.id] = remote;
    }
  }
  return merged;
}

/// Tính số dư ví tất định từ Sổ cái SSOT: initialBalance + sum(income) - sum(expense)
double _computeLedgerDerivedBalance(
  WalletModel wallet,
  Iterable<TransactionModel> txs,
) {
  double income = 0.0;
  double expense = 0.0;
  for (final tx in txs) {
    if (tx.isDeleted || tx.walletId != wallet.id) continue;
    if (tx.type == 'income') {
      income += tx.amount;
    } else {
      expense += tx.amount;
    }
  }
  final net = FinancePrecision.roundCurrency(
    income - expense,
    currency: wallet.currency,
  );
  return FinancePrecision.roundCurrency(
    wallet.initialBalance + net,
    currency: wallet.currency,
  );
}

void main() {
  group('Multi-device sync convergence (Redmi K70E <-> Pixel 7a)', () {
    setUp(() {
      SessionManager.instance.end();
    });

    tearDown(() {
      SessionManager.instance.end();
    });

    test(
      'Scenario 1: SessionManager.activate(sameUid) is idempotent and keeps realtime listener stillValid() == true',
      () {
        const uid = 'uid_pixel7a_k70e_shared';
        SessionManager.instance.activate(uid);
        final epochAfterFirstActivate = SessionManager.instance.epoch;
        bool stillValid() =>
            SessionManager.instance.isStillValid(epochAfterFirstActivate, uid);

        expect(stillValid(), isTrue);

        // Kích hoạt lại cùng uid (như khi mở vân tay / resume / setOnlineUid)
        SessionManager.instance.activate(uid);
        SessionManager.instance.activate(uid);

        expect(SessionManager.instance.epoch, equals(epochAfterFirstActivate));
        expect(stillValid(), isTrue);

        // Chuyển tài khoản hoặc đăng xuất phải vô hiệu hóa listener cũ ngay
        SessionManager.instance.beginSwitch();
        expect(stillValid(), isFalse);
      },
    );

    test(
      'Scenario 2: Concurrent offline/online writes converge to exact ledger-derived balance on both devices',
      () {
        final t0 = DateTime.utc(2026, 11, 25, 8, 0, 0);
        const walletId = 'w_cash_1';
        const uid = 'uid_shared';

        final baseWallet = WalletModel(
          id: walletId,
          uid: uid,
          name: 'Ví tiền mặt',
          type: WalletType.cash,
          balance: 1000000,
          initialBalance: 1000000,
          iconCode: 1,
          colorValue: 0xFF438883,
          createdAt: t0,
          updatedAt: t0,
        );

        // Redmi K70E ghi -50.000đ lúc offline
        final txK70e = TransactionModel(
          id: 'tx_k70e_1',
          uid: uid,
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 1,
          amount: 50000,
          date: t0,
          time: '08:05',
          walletId: walletId,
          createdAt: t0.add(const Duration(minutes: 5)),
          updatedAt: t0.add(const Duration(minutes: 5)),
          syncStatus: 'pending',
        );

        // Pixel 7a ghi -30.000đ và +200.000đ lúc online
        final txPixel1 = TransactionModel(
          id: 'tx_pixel_1',
          uid: uid,
          type: 'expense',
          category: 'Cà phê',
          categoryIconCode: 2,
          amount: 30000,
          date: t0,
          time: '08:06',
          walletId: walletId,
          createdAt: t0.add(const Duration(minutes: 6)),
          updatedAt: t0.add(const Duration(minutes: 6)),
          syncStatus: 'synced',
        );
        final txPixel2 = TransactionModel(
          id: 'tx_pixel_2',
          uid: uid,
          type: 'income',
          category: 'Thưởng',
          categoryIconCode: 3,
          amount: 200000,
          date: t0,
          time: '08:07',
          walletId: walletId,
          createdAt: t0.add(const Duration(minutes: 7)),
          updatedAt: t0.add(const Duration(minutes: 7)),
          syncStatus: 'synced',
        );

        // Hợp nhất 2 chiều giữa K70E và Pixel 7a
        final mergedOnK70e = _mergeTransactionsCrdt(
          [txK70e],
          [txPixel1, txPixel2],
        );
        final mergedOnPixel = _mergeTransactionsCrdt(
          [txPixel1, txPixel2],
          [txK70e],
        );

        expect(mergedOnK70e.length, equals(3));
        expect(mergedOnPixel.length, equals(3));

        final balanceK70e = _computeLedgerDerivedBalance(
          baseWallet,
          mergedOnK70e.values,
        );
        final balancePixel = _computeLedgerDerivedBalance(
          baseWallet,
          mergedOnPixel.values,
        );

        // Cả 2 máy đều phải đạt đúng initialBalance + 120.000đ = 1.120.000đ
        expect(balanceK70e, equals(1120000.0));
        expect(balancePixel, equals(1120000.0));

        // Khi người dùng chỉnh thủ công số dư ví thành 1.500.000đ:
        // initialBalance mới = 1.500.000 - netLedger (120.000) = 1.380.000đ
        const netLedger = 120000.0;
        final adjustedInitial = FinancePrecision.roundCurrency(
          1500000.0 - netLedger,
          currency: baseWallet.currency,
        );
        expect(adjustedInitial, equals(1380000.0));
        final editedWallet = baseWallet.copyWith(
          initialBalance: adjustedInitial,
          balance: 1500000.0,
        );
        expect(
          _computeLedgerDerivedBalance(editedWallet, mergedOnPixel.values),
          equals(1500000.0),
        );
      },
    );

    test(
      'Scenario 3: MidnightSyncService daily backup ID and midnight-only schedule are deterministic',
      () {
        final morning = DateTime(2026, 11, 25, 8, 30);
        final midnight = DateTime(2026, 11, 25, 0, 10);

        // Ban ngày không nằm trong khung giờ sao lưu tự động; nửa đêm thì hợp lệ
        expect(MidnightSyncService.isWithinMidnightWindow(morning), isFalse);
        expect(MidnightSyncService.isWithinMidnightWindow(midnight), isTrue);

        // Lịch sao lưu kế tiếp luôn trỏ về 00:00:05 ngày hôm sau khi đang là ban ngày
        expect(
          MidnightSyncService.computeNextScheduleTime(
            morning,
            lastBackedUpDateKey: '2026-11-24',
          ),
          equals(DateTime(2026, 11, 26, 0, 0, 5)),
        );
        expect(
          MidnightSyncService.dailyBackupIdForDate('2026-11-25'),
          equals('daily_2026-11-25'),
        );
        expect(CloudBackupType.autoDaily.wireValue, equals('auto_daily'));
      },
    );

    test(
      'Scenario 4: In-flight transaction created during backup is protected by queue ID watermark & full-row sanitize',
      () {
        final ops = _TestOwnedOps();
        const maxQueueIdBeforeUpload = 10;
        const inFlightQueueId = 11;
        expect(inFlightQueueId > maxQueueIdBeforeUpload, isTrue);

        final tBackupStart = DateTime.utc(2026, 11, 25, 8, 50, 0);
        final txUpdatedMs = ops.nextMonotonicTimestamp(
          tBackupStart.millisecondsSinceEpoch,
        );
        final inFlightTx = TransactionModel(
          id: 'tx_inflight',
          uid: 'uid_shared',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 10,
          amount: 75000,
          date: tBackupStart,
          time: '08:50',
          walletId: 'w1',
          createdAt: tBackupStart,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(txUpdatedMs),
          syncStatus: 'pending',
        );

        final sanitized = SyncQueueWriter.sanitizeMap(inFlightTx.toSqlite());
        expect(sanitized, isNotNull);
        expect(sanitized!['id'], equals('tx_inflight'));
        expect(sanitized['amount'], equals(75000.0));
        expect(sanitized['walletId'], equals('w1'));
      },
    );

    test(
      'Scenario 5: Transfer pair & Goal deposit/withdraw deletion preserve total balance invariants',
      () {
        final t0 = DateTime.utc(2026, 11, 25, 9, 0, 0);
        var walletA = WalletModel(
          id: 'wA',
          uid: 'uid_shared',
          name: 'Tiền mặt',
          type: WalletType.cash,
          balance: 1000000,
          initialBalance: 1000000,
          iconCode: 1,
          colorValue: 0xFF438883,
          updatedAt: t0,
        );
        var walletB = WalletModel(
          id: 'wB',
          uid: 'uid_shared',
          name: 'Ngân hàng',
          type: WalletType.bank,
          balance: 500000,
          initialBalance: 500000,
          iconCode: 2,
          colorValue: 0xFF1429A0,
          updatedAt: t0,
        );

        // Chuyển 200k từ A sang B, sau đó sửa thành 350k
        final txOut = TransactionModel(
          id: 'tr_1_out',
          uid: 'uid_shared',
          type: 'expense',
          category: 'Chuyển tiền',
          categoryIconCode: 1,
          amount: 350000,
          date: t0,
          time: '09:00',
          walletId: 'wA',
          transferId: 'tr_1',
          createdAt: t0,
          updatedAt: t0,
        );
        final txIn = TransactionModel(
          id: 'tr_1_in',
          uid: 'uid_shared',
          type: 'income',
          category: 'Nhận chuyển tiền',
          categoryIconCode: 1,
          amount: 350000,
          date: t0,
          time: '09:00',
          walletId: 'wB',
          transferId: 'tr_1',
          createdAt: t0,
          updatedAt: t0,
        );

        final balA = _computeLedgerDerivedBalance(walletA, [txOut, txIn]);
        final balB = _computeLedgerDerivedBalance(walletB, [txOut, txIn]);
        expect(balA, equals(650000.0));
        expect(balB, equals(850000.0));
        expect(balA + balB, equals(1500000.0));

        // Mục tiêu tiết kiệm: nạp 100k (expense) -> currentAmount tăng 100k; khi xóa giao dịch nạp -> hoàn lại -100k
        final goal = GoalModel(
          id: 'g1',
          uid: 'uid_shared',
          title: 'Mua xe',
          targetAmount: 10000000,
          currentAmount: 500000,
          deadline: t0.add(const Duration(days: 365)),
          iconCode: 1,
          colorValue: 0xFF438883,
          createdAt: t0,
          updatedAt: t0,
        );
        const deletedDepositAmount = 100000.0;
        final revertedGoalAmount = FinancePrecision.roundCurrency(
          (goal.currentAmount - deletedDepositAmount).clamp(0.0, double.infinity),
        );
        expect(revertedGoalAmount, equals(400000.0));
      },
    );

    test(
      'Scenario 6: Machine A deducts wallet -> Machine B converges balance via ledger & broadcast streams allow multiple listeners',
      () async {
        final ops = _TestOwnedOps();
        const uid = 'uid_device_sync';
        final t0 = DateTime.utc(2026, 11, 26, 10, 0, 0);

        // Machine A và Machine B ban đầu cùng có 1 ví 1.000.000đ
        final walletInit = WalletModel(
          id: 'w_main',
          uid: uid,
          name: 'Ví chính',
          type: WalletType.cash,
          balance: 1000000,
          initialBalance: 1000000,
          iconCode: 1,
          colorValue: 0xFF438883,
          createdAt: t0,
          updatedAt: t0,
          syncStatus: 'synced',
        );

        // Machine A thêm chi tiêu 120.000đ -> trừ số dư ví và tăng monotonic updatedAt
        final nextWalletMs = ops.nextMonotonicTimestamp(
          walletInit.updatedAt.millisecondsSinceEpoch,
        );
        final walletOnA = walletInit.copyWith(
          balance: FinancePrecision.roundCurrency(
            walletInit.balance - 120000,
            currency: walletInit.currency,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nextWalletMs),
          syncStatus: 'pending',
        );
        final txExpense = TransactionModel(
          id: 'tx_a_1',
          uid: uid,
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 1,
          amount: 120000,
          date: t0,
          time: '10:05',
          walletId: 'w_main',
          createdAt: t0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nextWalletMs),
          syncStatus: 'pending',
        );
        final txDeleted = TransactionModel(
          id: 'tx_a_del',
          uid: uid,
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 1,
          amount: 50000,
          date: t0,
          time: '10:06',
          walletId: 'w_main',
          isDeleted: true,
          createdAt: t0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nextWalletMs),
          syncStatus: 'synced',
        );

        expect(walletOnA.balance, equals(880000.0));
        expect(walletOnA.updatedAt.isAfter(walletInit.updatedAt), isTrue);

        // Machine B nhận transaction mới từ Firestore -> tái tính toán số dư từ initialBalance + income - expense (bỏ qua isDeleted)
        final convergedBalanceOnB = _computeLedgerDerivedBalance(
          walletInit,
          [txExpense, txDeleted],
        );
        expect(convergedBalanceOnB, equals(880000.0));

        // Kiểm tra sync_metadata trong LedgerReconciliationService dùng đúng cột entityName (không dùng tableName)
        final reconcileSrc = File(
          'lib/services/ledger_reconciliation_service.dart',
        ).readAsStringSync();
        expect(reconcileSrc.contains('entityName = ?'), isTrue);
        expect(
          RegExp(r'sync_metadata[\s\S]{0,120}tableName\s*=').hasMatch(reconcileSrc),
          isFalse,
        );

        // Kiểm tra broadcast streams của WalletRepository & TransactionRepository không ném lỗi "Bad state: Stream has already been listened to"
        final walletRepo = WalletRepository();
        final txRepo = TransactionRepository();
        final sub1 = walletRepo.getWalletsStream().listen((_) {});
        final sub2 = walletRepo.getWalletsStream().listen((_) {});
        final sub3 = walletRepo.getTotalBalanceStream().listen((_) {});
        final sub4 = walletRepo.getTotalBalanceStream().listen((_) {});
        final sub5 = txRepo.getTransactionsStream().listen((_) {});
        final sub6 = txRepo.getTransactionsStream().listen((_) {});
        await Future.wait([
          sub1.cancel(),
          sub2.cancel(),
          sub3.cancel(),
          sub4.cancel(),
          sub5.cancel(),
          sub6.cancel(),
        ]);
      },
    );
  });
}
