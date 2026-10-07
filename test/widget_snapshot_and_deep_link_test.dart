import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/budget_model.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/services/widget_snapshot_builder.dart';
import 'package:money_tracker_app/services/widget_deep_link_parser.dart';

void main() {
  group('WidgetDeepLinkParser Tests', () {
    test('parse legacy add_transaction deep link', () {
      final uri = Uri.parse('moneytracker://add_transaction');
      final action = WidgetDeepLinkParser.parse(uri);
      expect(action.type, WidgetActionType.addExpense);
    });

    test('parse add transaction with income parameter', () {
      final uri = Uri.parse('moneytracker://add?type=income');
      final action = WidgetDeepLinkParser.parse(uri);
      expect(action.type, WidgetActionType.addIncome);
    });

    test('parse voice and scan deep links', () {
      final voiceUri = Uri.parse('moneytracker://voice');
      expect(WidgetDeepLinkParser.parse(voiceUri).type, WidgetActionType.voiceAssistant);

      final scanUri = Uri.parse('moneytracker://scan');
      expect(WidgetDeepLinkParser.parse(scanUri).type, WidgetActionType.scanReceipt);

      final scanReceiptUri = Uri.parse('moneytracker://scan_receipt');
      expect(WidgetDeepLinkParser.parse(scanReceiptUri).type, WidgetActionType.scanReceipt);

      final reportUri = Uri.parse('moneytracker://report');
      expect(WidgetDeepLinkParser.parse(reportUri).type, WidgetActionType.openReport);

      final statUri = Uri.parse('moneytracker://statistics');
      expect(WidgetDeepLinkParser.parse(statUri).type, WidgetActionType.openReport);
    });

    test('parse budget, goal, wallet and transactions deep links', () {
      final budgetUri = Uri.parse('moneytracker://budget');
      expect(WidgetDeepLinkParser.parse(budgetUri).type, WidgetActionType.openBudget);

      final goalUri = Uri.parse('moneytracker://goal?id=g123');
      final goalAction = WidgetDeepLinkParser.parse(goalUri);
      expect(goalAction.type, WidgetActionType.openGoal);
      expect(goalAction.targetId, 'g123');

      final walletUri = Uri.parse('moneytracker://wallet?id=w456');
      final walletAction = WidgetDeepLinkParser.parse(walletUri);
      expect(walletAction.type, WidgetActionType.openWallet);
      expect(walletAction.targetId, 'w456');

      final txsUri = Uri.parse('moneytracker://transactions');
      expect(WidgetDeepLinkParser.parse(txsUri).type, WidgetActionType.openTransactions);
    });

    test('fallback to openApp for unknown or invalid schemes', () {
      final invalidScheme = Uri.parse('https://example.com');
      expect(WidgetDeepLinkParser.parse(invalidScheme).type, WidgetActionType.openApp);

      final unknownHost = Uri.parse('moneytracker://unknown_route');
      expect(WidgetDeepLinkParser.parse(unknownHost).type, WidgetActionType.openApp);
    });
  });

  group('WidgetSnapshotBuilder Tests', () {
    test('buildEmpty returns zeros and empty arrays', () {
      final empty = WidgetSnapshotBuilder.buildEmpty(isLoggedIn: false);
      expect(empty.isLoggedIn, false);
      expect(empty.totalBalanceRaw, 0.0);
      expect(empty.walletsJson, '[]');
      expect(empty.budgetsJson, '[]');
      expect(empty.goalsJson, '[]');
      expect(empty.recentTransactionsJson, '[]');
    });

    test('build calculates wallets, expenses and budgets properly', () {
      final refDate = DateTime(2026, 10, 5, 14, 0);

      final List<WalletModel> wallets = [
        WalletModel(id: 'w1', uid: 'u1', name: 'Tiền mặt', type: 'cash', balance: 500000, iconCode: 0xe532, colorValue: 0xFF438883),
        WalletModel(id: 'w2', uid: 'u1', name: 'MoMo', type: 'e_wallet', balance: 1500000, iconCode: 0xe532, colorValue: 0xFF438883),
      ];

      final List<TransactionModel> transactions = [
        // Today expense
        TransactionModel(
          id: 't1',
          uid: 'u1',
          type: 'expense',
          amount: 50000,
          category: 'Ăn uống',
          categoryIconCode: 0xe148,
          walletId: 'w1',
          date: DateTime(2026, 10, 5, 12, 0),
        ),
        // Past day same month expense
        TransactionModel(
          id: 't2',
          uid: 'u1',
          type: 'expense',
          amount: 200000,
          category: 'Mua sắm',
          categoryIconCode: 0xe148,
          walletId: 'w2',
          date: DateTime(2026, 10, 2, 9, 0),
        ),
        // This month income
        TransactionModel(
          id: 't3',
          uid: 'u1',
          type: 'income',
          amount: 10000000,
          category: 'Lương',
          categoryIconCode: 0xe148,
          walletId: 'w2',
          date: DateTime(2026, 10, 1, 8, 0),
        ),
      ];

      final List<BudgetModel> budgets = [
        BudgetModel(id: 'b1', uid: 'u1', category: 'Ăn uống', limitAmount: 1000000, currentSpent: 850000, month: 10, year: 2026),
        BudgetModel(id: 'b2', uid: 'u1', category: 'Đi lại', limitAmount: 500000, currentSpent: 600000, month: 10, year: 2026),
        BudgetModel(id: 'b3', uid: 'u1', category: 'Giải trí', limitAmount: 2000000, currentSpent: 400000, month: 10, year: 2026),
        BudgetModel(id: 'b4', uid: 'u1', category: 'Học tập', limitAmount: 1000000, currentSpent: 100000, month: 10, year: 2026),
      ];

      final List<GoalModel> goals = [
        GoalModel(id: 'g1', uid: 'u1', title: 'Mua Laptop', targetAmount: 20000000, currentAmount: 10000000, deadline: DateTime(2026, 12, 31)),
      ];

      final snapshot = WidgetSnapshotBuilder.build(
        wallets: wallets,
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        referenceDate: refDate,
        isLoggedIn: true,
      );

      expect(snapshot.totalBalanceRaw, 2000000.0);
      expect(snapshot.todayExpenseRaw, 50000.0);
      expect(snapshot.monthExpenseRaw, 250000.0);
      expect(snapshot.monthIncomeRaw, 10000000.0);

      // Budgets: top 3 by % spent
      final topBudgets = jsonDecode(snapshot.budgetsJson) as List;
      expect(topBudgets.length, 3);
      expect(topBudgets[0]['name'], 'Đi lại');
      expect(topBudgets[0]['percent'], 120);
      expect(topBudgets[0]['status'], 'red');

      expect(topBudgets[1]['name'], 'Ăn uống');
      expect(topBudgets[1]['percent'], 85);
      expect(topBudgets[1]['status'], 'orange');

      // Recent transactions (up to 3)
      final recentTxs = jsonDecode(snapshot.recentTransactionsJson) as List;
      expect(recentTxs.length, 3);
      expect(recentTxs[0]['title'], 'Ăn uống');
      expect(recentTxs[0]['amount'], contains('50.000'));

      // 7-day chart verification
      final sevenDays = jsonDecode(snapshot.sevenDaysChartJson) as List;
      expect(sevenDays.length, 7);
      expect(sevenDays.last['is_today'], true);
      expect(sevenDays.last['day'], isNotEmpty);

      // Safe daily spend
      expect(snapshot.safeDailySpend, isNotEmpty);

      // Top categories breakdown
      final topCats = jsonDecode(snapshot.topCategoriesJson) as List;
      expect(topCats, isNotEmpty);
      expect(topCats[0]['name'], 'Mua sắm'); // 200k vs 50k
    });
  });
}
