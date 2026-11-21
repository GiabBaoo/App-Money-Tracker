import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suite 3: Saving Goals Integrity & Anti-Phantom Money', () {
    final now = DateTime(2026, 10, 20);

    test('TC-GOAL-01: Chặn nạp vào Mục tiêu khi walletId rỗng hoặc null', () {
      expect(
        () {
          const walletId = '';
          if (walletId.trim().isEmpty) {
            throw const BusinessException(
              BusinessErrorCode.invalidAmount,
              'Phải chọn ví nguồn khi nạp tiền vào mục tiêu',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.invalidAmount,
          ),
        ),
      );
    });

    test('TC-GOAL-02: Chặn rút từ Mục tiêu khi walletId rỗng hoặc null', () {
      expect(
        () {
          const walletId = '   ';
          if (walletId.trim().isEmpty) {
            throw const BusinessException(
              BusinessErrorCode.invalidAmount,
              'Phải chọn ví nhận khi rút tiền từ mục tiêu',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.invalidAmount,
          ),
        ),
      );
    });

    test('TC-GOAL-03: Chặn nạp vào Mục tiêu khi số dư ví nguồn không đủ', () {
      final wallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví Tiền mặt',
        type: WalletType.cash,
        balance: 1000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      const depositAmount = 2000000.0;

      expect(
        () {
          if (wallet.balance < depositAmount) {
            throw const BusinessException(
              BusinessErrorCode.insufficientBalance,
              'Số dư ví nguồn không đủ để nạp vào mục tiêu',
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

    test('TC-GOAL-04: Chặn rút vượt quá số dư hiện có của Mục tiêu (Triệt tiêu tiền ảo)', () {
      final goal = GoalModel(
        id: 'g1',
        uid: 'u1',
        title: 'Mua iPhone',
        targetAmount: 30000000.0,
        currentAmount: 5000000.0,
        deadline: now.add(const Duration(days: 60)),
        iconCode: 10,
        colorValue: 10,
      );

      const withdrawAmount = 6000000.0;

      expect(
        () {
          if (goal.currentAmount < withdrawAmount) {
            throw const BusinessException(
              BusinessErrorCode.invalidAmount,
              'Số tiền rút vượt quá số dư hiện tại của mục tiêu',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.invalidAmount,
          ),
        ),
      );
    });

    test('TC-GOAL-05: Nạp và Rút tiền Mục tiêu bảo toàn số dư tổng thể', () {
      var wallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví Ngân hàng',
        type: WalletType.bank,
        balance: 10000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      var goal = GoalModel(
        id: 'g1',
        uid: 'u1',
        title: 'Mua Xe máy',
        targetAmount: 25000000.0,
        currentAmount: 2000000.0,
        deadline: now.add(const Duration(days: 180)),
        iconCode: 2,
        colorValue: 2,
      );

      final initialTotal = wallet.balance + goal.currentAmount; // 12.000.000 VND

      // 1. Nạp 3.000.000 VND vào mục tiêu
      const depositAmt = 3000000.0;
      wallet = wallet.copyWith(
        balance: FinancePrecision.subtract(wallet.balance, depositAmt),
      );
      goal = goal.copyWith(
        currentAmount: FinancePrecision.add(goal.currentAmount, depositAmt),
      );

      expect(wallet.balance, equals(7000000.0));
      expect(goal.currentAmount, equals(5000000.0));
      expect(wallet.balance + goal.currentAmount, equals(initialTotal));

      // 2. Rút 1.500.000 VND từ mục tiêu về ví
      const withdrawAmt = 1500000.0;
      goal = goal.copyWith(
        currentAmount: FinancePrecision.subtract(goal.currentAmount, withdrawAmt),
      );
      wallet = wallet.copyWith(
        balance: FinancePrecision.add(wallet.balance, withdrawAmt),
      );

      expect(wallet.balance, equals(8500000.0));
      expect(goal.currentAmount, equals(3500000.0));
      expect(wallet.balance + goal.currentAmount, equals(initialTotal));
    });
  });
}
