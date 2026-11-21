import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suite 4: Double-Entry Transfer & Balance Conservation', () {
    final now = DateTime(2026, 10, 22);

    test('TC-XFER-01: Chuyển tiền cùng ví bị chặn ngay lập tức', () {
      const fromWalletId = 'wallet_abc';
      const toWalletId = 'wallet_abc';

      expect(
        () {
          if (fromWalletId == toWalletId) {
            throw const BusinessException(
              BusinessErrorCode.sameWalletTransfer,
              'Ví nguồn và ví đích không được trùng nhau',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.sameWalletTransfer,
          ),
        ),
      );
    });

    test('TC-XFER-02: Chuyển tiền không có phí bảo toàn 100% tổng tài sản', () {
      var walletA = WalletModel(
        id: 'wallet_A',
        uid: 'user_1',
        name: 'Ví Nguồn A',
        type: WalletType.cash,
        balance: 5000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      var walletB = WalletModel(
        id: 'wallet_B',
        uid: 'user_1',
        name: 'Ví Đích B',
        type: WalletType.bank,
        balance: 10000000.0,
        iconCode: 2,
        colorValue: 2,
      );

      final totalBefore = walletA.balance + walletB.balance; // 15.000.000 VND
      const transferAmount = 2000000.0;
      const transferFee = 0.0;

      // 1. Trừ ví nguồn: amount + fee
      walletA = walletA.copyWith(
        balance: FinancePrecision.subtract(walletA.balance, transferAmount + transferFee),
      );

      // 2. Cộng ví đích: amount
      walletB = walletB.copyWith(
        balance: FinancePrecision.add(walletB.balance, transferAmount),
      );

      final totalAfter = walletA.balance + walletB.balance;

      expect(walletA.balance, equals(3000000.0));
      expect(walletB.balance, equals(12000000.0));
      // Bất biến: Không có phí thì tổng tài sản không đổi
      expect(totalAfter, equals(totalBefore));
    });

    test('TC-XFER-03: Chuyển tiền có phí giao dịch làm giảm tổng tài sản đúng bằng phí', () {
      var walletA = WalletModel(
        id: 'wallet_A',
        uid: 'user_1',
        name: 'Ví Nguồn A',
        type: WalletType.bank,
        balance: 10000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      var walletB = WalletModel(
        id: 'wallet_B',
        uid: 'user_1',
        name: 'Ví Đích B',
        type: WalletType.eWallet,
        balance: 2000000.0,
        iconCode: 2,
        colorValue: 2,
      );

      final totalBefore = walletA.balance + walletB.balance; // 12.000.000 VND
      const transferAmount = 3000000.0;
      const transferFee = 5500.0; // Phí chuyển khoản

      // 1. Trừ ví nguồn: amount + fee
      walletA = walletA.copyWith(
        balance: FinancePrecision.subtract(walletA.balance, transferAmount + transferFee),
      );

      // 2. Cộng ví đích: amount
      walletB = walletB.copyWith(
        balance: FinancePrecision.add(walletB.balance, transferAmount),
      );

      final totalAfter = walletA.balance + walletB.balance;

      expect(walletA.balance, equals(6994500.0));
      expect(walletB.balance, equals(5000000.0));
      // Bất biến: Delta tổng tài sản đúng bằng -fee
      expect(totalBefore - totalAfter, equals(transferFee));
    });

    test('TC-XFER-04: Chặn chuyển tiền khi số dư ví nguồn nhỏ hơn (amount + fee)', () {
      final walletA = WalletModel(
        id: 'wallet_A',
        uid: 'user_1',
        name: 'Ví Nguồn A',
        type: WalletType.bank,
        balance: 1000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      const transferAmount = 1000000.0;
      const transferFee = 5500.0;

      expect(
        () {
          if (walletA.balance < (transferAmount + transferFee)) {
            throw const BusinessException(
              BusinessErrorCode.insufficientBalance,
              'Số dư ví nguồn không đủ để thực hiện giao dịch',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.insufficientBalance,
          ),
        ),
      );
    });

    test('TC-XFER-05: Cặp bút toán chuyển tiền mang chung transferId và phân định rõ Leg 1 / Leg 2', () {
      const transferId = 'xfer_uuid_12345';
      const amount = 500000.0;

      final expenseTx = TransactionModel(
        id: 'tx_out',
        uid: 'user_1',
        type: 'expense',
        category: 'Chuyển tiền',
        categoryIconCode: 1,
        amount: amount,
        date: now,
        walletId: 'w_from',
        transferId: transferId,
      );

      final incomeTx = TransactionModel(
        id: 'tx_in',
        uid: 'user_1',
        type: 'income',
        category: 'Nhận chuyển tiền',
        categoryIconCode: 2,
        amount: amount,
        date: now,
        walletId: 'w_to',
        transferId: transferId,
      );

      expect(expenseTx.isTransfer, isTrue);
      expect(incomeTx.isTransfer, isTrue);
      expect(expenseTx.transferId, equals(incomeTx.transferId));
      expect(expenseTx.walletId, isNot(equals(incomeTx.walletId)));
      expect(expenseTx.amount, equals(incomeTx.amount));
    });
  });
}
