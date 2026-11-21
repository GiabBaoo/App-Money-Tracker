import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/services/financial_calculation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suite 2: Financial Metrics & Net Worth Calculation', () {
    final now = DateTime(2026, 10, 15);

    test('TC-METR-01: Thu nhập hoạt động loại trừ giao dịch chuyển tiền và rút tiết kiệm', () {
      final transactions = [
        // Thu nhập thực tế: Lương 20.000.000 VND
        TransactionModel(
          id: 'tx_salary',
          uid: 'user_1',
          type: 'income',
          category: 'Lương',
          categoryIconCode: 1,
          amount: 20000000.0,
          date: now,
          walletId: 'w_bank',
        ),
        // Thu nhập thực tế: Thưởng 5.000.000 VND
        TransactionModel(
          id: 'tx_bonus',
          uid: 'user_1',
          type: 'income',
          category: 'Thưởng',
          categoryIconCode: 2,
          amount: 5000000.0,
          date: now,
          walletId: 'w_bank',
        ),
        // Nhận chuyển khoản nội bộ: 3.000.000 VND (KHÔNG được tính vào thu nhập)
        TransactionModel(
          id: 'tx_xfer_in',
          uid: 'user_1',
          type: 'income',
          category: 'Nhận chuyển tiền',
          categoryIconCode: 3,
          amount: 3000000.0,
          date: now,
          walletId: 'w_cash',
          transferId: 'xfer_001',
        ),
        // Rút tiền từ mục tiêu tiết kiệm: 2.000.000 VND (KHÔNG được tính vào thu nhập)
        TransactionModel(
          id: 'tx_goal_withdraw',
          uid: 'user_1',
          type: 'income',
          category: 'Rút tiết kiệm',
          categoryIconCode: 4,
          amount: 2000000.0,
          date: now,
          walletId: 'w_cash',
          goalId: 'goal_001',
        ),
      ];

      final metrics = FinancialCalculationService.calculatePeriodMetrics(
        transactions,
        filterMonth: now.month,
        filterYear: now.year,
      );

      // Tổng thu nhập chỉ là Lương + Thưởng = 25.000.000 VND
      expect(metrics.totalIncome, equals(25000000.0));
    });

    test('TC-METR-02: Chi tiêu hoạt động loại trừ chuyển tiền nội bộ và nạp tiết kiệm, cộng đủ phí', () {
      final transactions = [
        // Chi tiêu sinh hoạt: Ăn uống 3.000.000 VND
        TransactionModel(
          id: 'tx_food',
          uid: 'user_1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 10,
          amount: 3000000.0,
          date: now,
          walletId: 'w_cash',
        ),
        // Chi tiêu sinh hoạt: Mua sắm 2.000.000 VND
        TransactionModel(
          id: 'tx_shopping',
          uid: 'user_1',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 11,
          amount: 2000000.0,
          date: now,
          walletId: 'w_bank',
        ),
        // Chuyển tiền sang ví khác: 5.000.000 VND + Phí 11.000 VND
        TransactionModel(
          id: 'tx_xfer_out',
          uid: 'user_1',
          type: 'expense',
          category: 'Chuyển tiền',
          categoryIconCode: 12,
          amount: 5011000.0,
          date: now,
          walletId: 'w_bank',
          transferId: 'xfer_002',
        ),
        TransactionModel(
          id: 'tx_xfer_in',
          uid: 'user_1',
          type: 'income',
          category: 'Nhận chuyển tiền',
          categoryIconCode: 13,
          amount: 5000000.0,
          date: now,
          walletId: 'w_cash',
          transferId: 'xfer_002',
        ),
        // Nạp tiền tiết kiệm: 4.000.000 VND (Asset Reallocation - KHÔNG được tính chi tiêu)
        TransactionModel(
          id: 'tx_goal_deposit',
          uid: 'user_1',
          type: 'expense',
          category: 'Tiết kiệm',
          categoryIconCode: 14,
          amount: 4000000.0,
          date: now,
          walletId: 'w_bank',
          goalId: 'goal_002',
        ),
      ];

      final metrics = FinancialCalculationService.calculatePeriodMetrics(
        transactions,
        filterMonth: now.month,
        filterYear: now.year,
      );

      // Phí chuyển tiền = 5.011.000 - 5.000.000 = 11.000 VND
      expect(metrics.transferFeeTotal, equals(11000.0));
      // Chi tiêu sinh hoạt = 3.000.000 + 2.000.000 + 11.000 (phí) = 5.011.000 VND
      expect(metrics.totalExpense, equals(5011000.0));
    });

    test('TC-METR-03: Dòng tiền thuần và Tỷ lệ tiết kiệm (Savings Rate)', () {
      final transactions = [
        TransactionModel(
          id: 'tx1',
          uid: 'user_1',
          type: 'income',
          category: 'Lương',
          categoryIconCode: 1,
          amount: 20000000.0,
          date: now,
          walletId: 'w1',
        ),
        TransactionModel(
          id: 'tx2',
          uid: 'user_1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 2,
          amount: 5000000.0,
          date: now,
          walletId: 'w1',
        ),
      ];

      final metrics = FinancialCalculationService.calculatePeriodMetrics(transactions);
      expect(metrics.totalIncome, equals(20000000.0));
      expect(metrics.totalExpense, equals(5000000.0));
      expect(metrics.netCashFlow, equals(15000000.0));
      // Savings rate = (20M - 5M) / 20M = 75%
      expect(metrics.savingsRate, equals(75.0));
    });

    test('TC-METR-04: Tính toán Net Worth và phân loại cơ cấu tài sản', () {
      final wallets = [
        WalletModel(
          id: 'w_cash',
          uid: 'u1',
          name: 'Tiền mặt',
          type: WalletType.cash,
          balance: 5000000.0,
          iconCode: 1,
          colorValue: 1,
        ),
        WalletModel(
          id: 'w_bank',
          uid: 'u1',
          name: 'Vietcombank',
          type: WalletType.bank,
          balance: 20000000.0,
          iconCode: 2,
          colorValue: 2,
        ),
        WalletModel(
          id: 'w_savings',
          uid: 'u1',
          name: 'Sổ tiết kiệm SCB',
          type: WalletType.savings,
          balance: 50000000.0,
          iconCode: 3,
          colorValue: 3,
        ),
        WalletModel(
          id: 'w_credit',
          uid: 'u1',
          name: 'Thẻ tín dụng',
          type: WalletType.credit,
          balance: -3000000.0, // Nợ 3.000.000 VND
          iconCode: 4,
          colorValue: 4,
        ),
        WalletModel(
          id: 'w_deleted',
          uid: 'u1',
          name: 'Ví cũ đã xóa',
          type: WalletType.cash,
          balance: 10000000.0,
          iconCode: 5,
          colorValue: 5,
          isDeleted: true, // Đã xóa mềm -> không tính
        ),
      ];

      final goals = [
        GoalModel(
          id: 'g1',
          uid: 'u1',
          title: 'Mua MacBook',
          targetAmount: 30000000.0,
          currentAmount: 15000000.0,
          deadline: now.add(const Duration(days: 90)),
          iconCode: 10,
          colorValue: 10,
        ),
        GoalModel(
          id: 'g2',
          uid: 'u1',
          title: 'Mục tiêu đã hủy',
          targetAmount: 50000000.0,
          currentAmount: 5000000.0,
          deadline: now,
          iconCode: 11,
          colorValue: 11,
          isDeleted: true, // Đã xóa mềm -> không tính
        ),
      ];

      final netWorthMetrics = FinancialCalculationService.calculateNetWorth(
        wallets: wallets,
        goals: goals,
      );

      // Liquid: Cash (5M) + Bank (20M) = 25M
      expect(netWorthMetrics.liquidAssets, equals(25000000.0));
      // Savings: Sổ tiết kiệm (50M) + Goal g1 (15M) = 65M
      expect(netWorthMetrics.savingsAssets, equals(65000000.0));
      // Liabilities: Thẻ tín dụng = 3M
      expect(netWorthMetrics.liabilities, equals(3000000.0));
      // Net Worth = (25M + 65M) - 3M = 87M
      expect(netWorthMetrics.netWorth, equals(87000000.0));
    });

    test('TC-METR-05: Tính toán True Balance của ví từ lịch sử giao dịch (SSOT Ledger Re-calculation)', () {
      final walletTx = [
        TransactionModel(
          id: 'tx_in_1',
          uid: 'u1',
          type: 'income',
          category: 'Nạp tiền',
          categoryIconCode: 1,
          amount: 10000000.0,
          date: now,
          walletId: 'w_test',
        ),
        TransactionModel(
          id: 'tx_out_1',
          uid: 'u1',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 2,
          amount: 3500000.0,
          date: now,
          walletId: 'w_test',
        ),
        TransactionModel(
          id: 'tx_deleted',
          uid: 'u1',
          type: 'expense',
          category: 'Nhầm lẫn',
          categoryIconCode: 3,
          amount: 5000000.0,
          date: now,
          walletId: 'w_test',
          isDeleted: true, // Không được tính
        ),
      ];

      final trueBalance = FinancialCalculationService.calculateWalletTrueBalance(
        initialBalance: 2000000.0,
        walletTransactions: walletTx,
      );

      // initial (2M) + 10M - 3.5M = 8.5M
      expect(trueBalance, equals(8500000.0));
    });
  });
}
