import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/data/local/owned_table_ops.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

class _TestOwnedOps with OwnedTableOps {}

void main() {
  group('Wallet balance deduction & cloud backup conflict invariants', () {
    test('monotonic timestamp advances past future remote updatedAt so local deduction wins LWW', () {
      final ops = _TestOwnedOps();
      // Giả lập ví có updatedAt bị lệch tương lai +60 giây do clock skew từ thiết bị khác
      final futureRemoteMs =
          DateTime.now().toUtc().millisecondsSinceEpoch + 60000;
      final remoteWallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví tiền mặt',
        type: WalletType.cash,
        balance: 1000000,
        initialBalance: 1000000,
        iconCode: 1,
        colorValue: 0xFF438883,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(futureRemoteMs),
      );

      // Khi ghi khoản chi 50.000đ, timestamp mới phải tịnh tiến > futureRemoteMs
      final nextMs = ops.nextMonotonicTimestamp(
        remoteWallet.updatedAt.millisecondsSinceEpoch,
      );
      expect(nextMs, greaterThan(futureRemoteMs));

      final localDeducted = remoteWallet.copyWith(
        balance: FinancePrecision.roundCurrency(
          remoteWallet.balance - 50000,
          currency: remoteWallet.currency,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(nextMs),
        syncStatus: 'pending',
      );
      expect(localDeducted.balance, equals(950000.0));

      // Khi sync/realtime nhận lại bản remote cũ (1.000.000đ), remote KHÔNG được thắng
      final remoteWins = ConflictResolver.shouldRemoteWin(
        localUpdatedAt: localDeducted.updatedAt,
        remoteUpdatedAt: remoteWallet.updatedAt,
        localData: localDeducted.toSqlite(),
        remoteData: remoteWallet.toSqlite(),
      );
      expect(remoteWins, isFalse);
    });

    test('live Firestore wallet newer than stale backups/latest wins merge', () {
      final tBackup = DateTime.utc(2026, 11, 20, 10, 0, 0);
      final tLiveTx = DateTime.utc(2026, 11, 23, 12, 0, 0);

      final backupWallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví chính',
        type: WalletType.cash,
        balance: 1000000,
        initialBalance: 1000000,
        iconCode: 1,
        colorValue: 0xFF438883,
        updatedAt: tBackup,
      );

      final liveWallet = backupWallet.copyWith(
        balance: 850000,
        updatedAt: tLiveTx,
      );

      // Mô phỏng logic hợp nhất trong restoreLatestCloudBackup
      final merged = <String, WalletModel>{backupWallet.id: backupWallet};
      final existing = merged[liveWallet.id];
      if (existing == null || !existing.updatedAt.isAfter(liveWallet.updatedAt)) {
        merged[liveWallet.id] = liveWallet;
      }

      expect(merged['w1']!.balance, equals(850000.0));
      expect(merged['w1']!.updatedAt, equals(tLiveTx));
    });
  });
}
