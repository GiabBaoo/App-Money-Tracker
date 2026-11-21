import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/vnd_split_calculator.dart';
import 'package:money_tracker_app/services/financial_calculation_service.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  group('Phase 2 Regression Tests: Financial Precision & Double-Entry Ledger', () {
    test('FIN-01: VND amounts rounded to integer without floating point decimals', () {
      expect(FinancePrecision.roundCurrency(12345.67, currency: 'VND'), 12346.0);
      expect(FinancePrecision.roundCurrency(12345.49, currency: 'VND'), 12345.0);
      expect(FinancePrecision.roundCurrency(0.1 + 0.2, currency: 'VND'), 0.0);
      expect(FinancePrecision.roundCurrency(100000.00001, currency: 'VND'), 100000.0);
    });

    test('FIN-02: Non-VND (USD, EUR) precision handled to 2 decimals', () {
      expect(FinancePrecision.roundCurrency(12.3456, currency: 'USD'), 12.35);
      expect(FinancePrecision.roundCurrency(12.3444, currency: 'EUR'), 12.34);
      expect(FinancePrecision.roundCurrency(0.1 + 0.2, currency: 'USD'), 0.30);
    });

    test('FIN-03: FinancePrecision comparison with epsilon', () {
      expect(FinancePrecision.areEqual(100.0, 100.00005), isTrue);
      expect(FinancePrecision.areEqual(100.0, 100.001), isFalse);
      expect(FinancePrecision.isGreaterThan(100.001, 100.0), isTrue);
      expect(FinancePrecision.isLessThan(99.999, 100.0), isTrue);
      expect(FinancePrecision.isZero(0.00001), isTrue);
      expect(FinancePrecision.isPositive(0.0002), isTrue);
    });

    test('FIN-04: VndSplitCalculator equal split sum matches exact original total (zero remainder leakage)', () {
      const totalVnd = 100000;
      final participants = ['user_A', 'user_B', 'user_C'];
      final splits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: totalVnd,
        participantIds: participants,
        payerId: 'user_A',
      );

      expect(splits.length, 3);
      // 100000 ~/ 3 = 33333, remainder = 1
      // user_A (payer) gets 33334, others get 33333
      expect(splits['user_A'], 33334);
      expect(splits['user_B'], 33333);
      expect(splits['user_C'], 33333);

      final totalSum = splits.values.fold<int>(0, (a, b) => a + b);
      expect(totalSum, totalVnd);
    });

    test('FIN-05: VndSplitCalculator 7-way split with odd pennies', () {
      const totalVnd = 1000000; // 1,000,000 VND chia 7 người
      final participants = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7'];
      final splits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: totalVnd,
        participantIds: participants,
        payerId: 'u4',
      );

      // 1000000 ~/ 7 = 142857, remainder = 1
      // u4 là payer nên được xếp đầu tiên nhận 142858
      expect(splits['u4'], 142858);
      for (final u in ['u1', 'u2', 'u3', 'u5', 'u6', 'u7']) {
        expect(splits[u], 142857);
      }

      final sum = splits.values.fold<int>(0, (a, b) => a + b);
      expect(sum, totalVnd);
    });

    test('FIN-06: VndSplitCalculator percentage split handles largest remainder method', () {
      const totalVnd = 250000;
      final percentages = {
        'user_1': 33.33,
        'user_2': 33.33,
        'user_3': 33.34,
      };

      final splits = VndSplitCalculator.calculatePercentageSplit(
        totalAmountVnd: totalVnd,
        percentages: percentages,
        payerId: 'user_1',
      );

      final sum = splits.values.fold<int>(0, (a, b) => a + b);
      expect(sum, totalVnd);
    });

    test('FIN-07: FinancialCalculationService isAssetReallocation filters out wallet transfers and goal fundings', () {
      final now = DateTime.now();

      final normalExpense = TransactionModel(
        id: 'tx_1',
        uid: 'u1',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 0,
        amount: 50000,
        date: now,
        time: '12:00',
        walletId: 'w1',
      );

      final transferTx = TransactionModel(
        id: 'tx_2',
        uid: 'u1',
        type: 'expense',
        category: 'Chuyển tiền',
        categoryIconCode: 0,
        amount: 200000,
        date: now,
        time: '12:05',
        walletId: 'w1',
        transferId: 'tr_1',
      );

      final goalTx = TransactionModel(
        id: 'tx_3',
        uid: 'u1',
        type: 'expense',
        category: 'Tiết kiệm',
        categoryIconCode: 0,
        amount: 500000,
        date: now,
        time: '12:10',
        walletId: 'w1',
        goalId: 'g1',
      );

      expect(FinancialCalculationService.isAssetReallocation(normalExpense), isFalse);
      expect(FinancialCalculationService.isAssetReallocation(transferTx), isTrue);
      expect(FinancialCalculationService.isAssetReallocation(goalTx), isTrue);

      final metrics = FinancialCalculationService.calculatePeriodMetrics([
        normalExpense,
        transferTx,
        goalTx,
      ]);

      // Chi tiêu hoạt động chỉ tính normalExpense = 50,000đ, không tính 200,000đ transfer và 500,000đ goal
      expect(metrics.totalExpense, 50000.0);
      expect(metrics.transactionCount, 1);
    });

    test('FIN-08: FinancialCalculationService calculateWalletTrueBalance reconstructs balance from ledger', () {
      final now = DateTime.now();
      final txs = [
        TransactionModel(
          id: '1',
          uid: 'u1',
          type: 'income',
          category: 'Lương',
          categoryIconCode: 0,
          amount: 15000000,
          date: now,
          time: '08:00',
          walletId: 'w1',
        ),
        TransactionModel(
          id: '2',
          uid: 'u1',
          type: 'expense',
          category: 'Tiền nhà',
          categoryIconCode: 0,
          amount: 5000000,
          date: now,
          time: '09:00',
          walletId: 'w1',
        ),
        TransactionModel(
          id: '3',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 0,
          amount: 200000,
          date: now,
          time: '12:00',
          walletId: 'w1',
        ),
      ];

      // Initial 1,000,000 + 15,000,000 - 5,000,000 - 200,000 = 10,800,000
      final balance = FinancialCalculationService.calculateWalletTrueBalance(
        initialBalance: 1000000,
        walletTransactions: txs,
      );

      expect(balance, 10800000.0);
    });
  });
}

