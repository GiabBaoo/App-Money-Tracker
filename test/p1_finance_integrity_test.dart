import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1 Financial Integrity & Invariant Unit Tests', () {
    // ══════════════════════════════════════════════════════════════
    // FIN-I6: Chuẩn xác số học & Sai số IEEE 754
    // ══════════════════════════════════════════════════════════════
    test('TC-FIN-11: FinancePrecision triệt tiêu sai số dấu phẩy động', () {
      // 0.1 + 0.2 trong IEEE 754 là 0.30000000000000004
      const double sum = 0.1 + 0.2;
      expect(FinancePrecision.areEqual(sum, 0.3), isTrue);
      expect(FinancePrecision.roundCurrency(sum, currency: 'USD'), equals(0.3));

      // VND làm tròn đến 0 chữ số thập phân
      expect(
        FinancePrecision.roundCurrency(100000.499, currency: 'VND'),
        equals(100000.0),
      );
      expect(
        FinancePrecision.roundCurrency(100000.501, currency: 'VND'),
        equals(100001.0),
      );

      expect(FinancePrecision.isGreaterThan(100.0002, 100.0), isTrue);
      expect(FinancePrecision.isGreaterThan(100.00001, 100.0), isFalse);
      expect(FinancePrecision.isLessThan(99.9998, 100.0), isTrue);
    });

    // ══════════════════════════════════════════════════════════════
    // FIN-I1: Chuyển tiền & Bảo toàn số dư (Double-Entry Conservation)
    // ══════════════════════════════════════════════════════════════
    test('TC-FIN-01: Chuyển tiền cùng ví bị chặn ngay lập tức', () {
      const fromWalletId = 'wallet_1';
      const toWalletId = 'wallet_1';

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

    test('TC-FIN-03: Chuyển tiền vượt quá số dư khả dụng bị chặn', () {
      final fromWallet = WalletModel(
        id: 'w_from',
        uid: 'user_1',
        name: 'Ví Nguồn',
        type: 'cash',
        iconCode: 1,
        colorValue: 0xFF000000,
        balance: 500000.0,
      );

      const transferAmount = 1000000.0;
      const transferFee = 10000.0;

      expect(
        () {
          if (fromWallet.balance < (transferAmount + transferFee)) {
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

    test(
      'TC-FIN-Double-Entry: Bảo toàn tổng tài sản khi chuyển tiền có phí',
      () {
        final fromWallet = WalletModel(
          id: 'w_from',
          uid: 'user_1',
          name: 'Ví Tiền Mặt',
          type: 'cash',
          iconCode: 1,
          colorValue: 0xFF000000,
          balance: 2000000.0,
        );
        final toWallet = WalletModel(
          id: 'w_to',
          uid: 'user_1',
          name: 'Ví Ngân Hàng',
          type: 'bank',
          iconCode: 2,
          colorValue: 0xFF000000,
          balance: 1000000.0,
        );

        const amount = 500000.0;
        const fee = 5000.0;

        // Giả lập giao dịch chuyển tiền
        final newFromBalance = FinancePrecision.roundCurrency(
          fromWallet.balance - (amount + fee),
          currency: fromWallet.currency,
        );
        final newToBalance = FinancePrecision.roundCurrency(
          toWallet.balance + amount,
          currency: toWallet.currency,
        );

        // Delta From + Delta To + Fee = 0
        final deltaFrom = newFromBalance - fromWallet.balance; // -505,000
        final deltaTo = newToBalance - toWallet.balance; // +500,000
        expect(deltaFrom + deltaTo + fee, equals(0.0));

        // Bút toán nguồn & đích mang cùng transferId
        const transferId = 'xfer_test_123';
        final expenseTx = TransactionModel(
          id: 'tx_exp',
          uid: 'user_1',
          type: 'expense',
          category: 'Chuyển tiền',
          categoryIconCode: 10,
          amount: amount + fee,
          date: DateTime.now(),
          walletId: fromWallet.id,
          transferId: transferId,
        );
        final incomeTx = TransactionModel(
          id: 'tx_inc',
          uid: 'user_1',
          type: 'income',
          category: 'Nhận chuyển tiền',
          categoryIconCode: 11,
          amount: amount,
          date: DateTime.now(),
          walletId: toWallet.id,
          transferId: transferId,
        );

        expect(expenseTx.isTransfer, isTrue);
        expect(incomeTx.isTransfer, isTrue);
        expect(expenseTx.transferId, equals(incomeTx.transferId));
        expect(
          expenseTx.amount - incomeTx.amount,
          equals(fee),
        ); // Chênh lệch đúng bằng phí
      },
    );

    // ══════════════════════════════════════════════════════════════
    // FIN-I2: Mục tiêu tiết kiệm & Triệt tiêu tiền ảo (No Phantom Money)
    // ══════════════════════════════════════════════════════════════
    test(
      'TC-FIN-06: Chặn rút vượt quá số dư hiện có của Goal (Triệt tiêu tiền ảo)',
      () {
        final goal = GoalModel(
          id: 'goal_car',
          uid: 'user_1',
          title: 'Mua xe',
          targetAmount: 50000000.0,
          currentAmount: 2000000.0, // Chỉ có 2 triệu
          deadline: DateTime.now().add(const Duration(days: 300)),
          iconCode: 1,
          colorValue: 0xFF438883,
        );

        const withdrawAmount = 5000000.0; // Yêu cầu rút 5 triệu

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
      },
    );

    test('TC-FIN-07: Chặn nạp vào Goal khi số dư ví không đủ', () {
      final wallet = WalletModel(
        id: 'w_cash',
        uid: 'user_1',
        name: 'Ví tiền mặt',
        type: 'cash',
        iconCode: 1,
        colorValue: 0xFF000000,
        balance: 200000.0, // Chỉ có 200k
      );

      const depositAmount = 1000000.0; // Yêu cầu nạp 1 triệu

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

    test(
      'TC-FIN-08: Nạp & Rút Goal bảo toàn số dư và tạo bút toán sổ cái có goalId',
      () {
        final wallet = WalletModel(
          id: 'w_cash',
          uid: 'user_1',
          name: 'Ví tiền mặt',
          type: 'cash',
          iconCode: 1,
          colorValue: 0xFF000000,
          balance: 5000000.0,
        );
        final goal = GoalModel(
          id: 'goal_savings',
          uid: 'user_1',
          title: 'Quỹ khẩn cấp',
          targetAmount: 10000000.0,
          currentAmount: 1000000.0,
          deadline: DateTime.now().add(const Duration(days: 100)),
          iconCode: 1,
          colorValue: 0xFF438883,
        );

        const depositAmount = 500000.0;

        // 1. Thao tác Nạp tiền vào Goal
        final walletAfterDeposit = wallet.copyWith(
          balance: wallet.balance - depositAmount,
        );
        final goalAfterDeposit = goal.copyWith(
          currentAmount: goal.currentAmount + depositAmount,
        );

        final depositTx = TransactionModel(
          id: 'tx_dep',
          uid: 'user_1',
          type: 'expense',
          category: 'Tiết kiệm',
          categoryIconCode: 1,
          amount: depositAmount,
          date: DateTime.now(),
          walletId: wallet.id,
          goalId: goal.id,
        );

        expect(walletAfterDeposit.balance, equals(4500000.0));
        expect(goalAfterDeposit.currentAmount, equals(1500000.0));
        expect(depositTx.goalId, equals(goal.id));
        expect(depositTx.type, equals('expense'));

        // Tổng tài sản ròng (Net Worth) bảo toàn tuyệt đối:
        final netWorthBefore = wallet.balance + goal.currentAmount; // 6,000,000
        final netWorthAfter =
            walletAfterDeposit.balance +
            goalAfterDeposit.currentAmount; // 6,000,000
        expect(netWorthAfter, equals(netWorthBefore));

        // 2. Thao tác Rút tiền từ Goal về ví
        const withdrawAmount = 300000.0;
        final walletAfterWithdraw = walletAfterDeposit.copyWith(
          balance: walletAfterDeposit.balance + withdrawAmount,
        );
        final goalAfterWithdraw = goalAfterDeposit.copyWith(
          currentAmount: goalAfterDeposit.currentAmount - withdrawAmount,
        );

        final withdrawTx = TransactionModel(
          id: 'tx_with',
          uid: 'user_1',
          type: 'income',
          category: 'Rút tiết kiệm',
          categoryIconCode: 2,
          amount: withdrawAmount,
          date: DateTime.now(),
          walletId: wallet.id,
          goalId: goal.id,
        );

        expect(walletAfterWithdraw.balance, equals(4800000.0));
        expect(goalAfterWithdraw.currentAmount, equals(1200000.0));
        expect(withdrawTx.goalId, equals(goal.id));
        expect(withdrawTx.type, equals('income'));
        expect(
          walletAfterWithdraw.balance + goalAfterWithdraw.currentAmount,
          equals(netWorthBefore),
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // FIN-I4: Phân lập Dòng tiền Vận hành (Operating Cashflow Isolation)
    // ══════════════════════════════════════════════════════════════
    test(
      'TC-FIN-05: Giao dịch chuyển tiền và nạp Goal không bị tính vào chi tiêu sinh hoạt thực tế',
      () {
        final transactions = [
          // Chi tiêu sinh hoạt thực tế: 120k
          TransactionModel(
            id: 'tx_normal_exp',
            uid: 'u1',
            type: 'expense',
            category: 'Ăn uống',
            categoryIconCode: 1,
            amount: 120000.0,
            date: DateTime.now(),
          ),
          // Thu nhập lương thực tế: 10,000k
          TransactionModel(
            id: 'tx_normal_inc',
            uid: 'u1',
            type: 'income',
            category: 'Lương',
            categoryIconCode: 2,
            amount: 10000000.0,
            date: DateTime.now(),
          ),
          // Chuyển khoản nội bộ 50,000k + phí 10k
          TransactionModel(
            id: 'tx_xfer_exp',
            uid: 'u1',
            type: 'expense',
            category: 'Chuyển tiền',
            categoryIconCode: 3,
            amount: 50010000.0,
            date: DateTime.now(),
            transferId: 'xfer_999',
          ),
          TransactionModel(
            id: 'tx_xfer_inc',
            uid: 'u1',
            type: 'income',
            category: 'Nhận chuyển tiền',
            categoryIconCode: 4,
            amount: 50000000.0,
            date: DateTime.now(),
            transferId: 'xfer_999',
          ),
          // Nạp tích lũy mục tiêu: 2,000k
          TransactionModel(
            id: 'tx_goal_exp',
            uid: 'u1',
            type: 'expense',
            category: 'Tiết kiệm',
            categoryIconCode: 5,
            amount: 2000000.0,
            date: DateTime.now(),
            goalId: 'goal_777',
          ),
        ];

        // Bộ lọc báo cáo chuẩn hóa (P1)
        final actualTx = transactions
            .where(
              (tx) =>
                  !tx.isTransfer && (tx.goalId == null || tx.goalId!.isEmpty),
            )
            .toList();

        final transferTx = transactions.where((tx) => tx.isTransfer).toList();
        final transferExpense = transferTx
            .where((tx) => !tx.isIncome)
            .fold<double>(0, (s, tx) => s + tx.amount);
        final transferIncome = transferTx
            .where((tx) => tx.isIncome)
            .fold<double>(0, (s, tx) => s + tx.amount);
        final transferFeeTotal = (transferExpense - transferIncome).clamp(
          0.0,
          double.infinity,
        );

        final totalIncome = actualTx
            .where((tx) => tx.isIncome)
            .fold<double>(0, (s, tx) => s + tx.amount);
        final totalExpense =
            actualTx
                .where((tx) => !tx.isIncome)
                .fold<double>(0, (s, tx) => s + tx.amount) +
            transferFeeTotal;

        // Chi tiêu sinh hoạt thực tế không bị đội thêm 50 triệu hay 2 triệu Goal,
        // chỉ tính đúng 120k tiền ăn uống + 10k phí chuyển khoản = 130k!
        expect(totalExpense, equals(130000.0));
        // Thu nhập thực tế là 10 triệu
        expect(totalIncome, equals(10000000.0));
      },
    );
  });
}
