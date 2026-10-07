import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../utils/currency_format_utils.dart';

class WidgetSnapshotData {
  final String snapshotDate;
  final bool isLoggedIn;
  final String totalBalance;
  final double totalBalanceRaw;
  final String todayExpense;
  final double todayExpenseRaw;
  final String monthExpense;
  final double monthExpenseRaw;
  final String monthIncome;
  final double monthIncomeRaw;
  final String monthDifference;
  final String weekExpense;
  final String weekIncome;
  final String weekDifference;
  final String safeDailySpend;
  final String monthVsLastMonthPercent;
  final String monthVsLastMonthStatus; // 'positive' (chi giảm), 'negative' (chi tăng), 'neutral'
  final String sevenDaysChartJson;
  final String topCategoriesJson;
  final String walletsJson;
  final String budgetsJson;
  final String goalsJson;
  final String recentTransactionsJson;

  const WidgetSnapshotData({
    required this.snapshotDate,
    required this.isLoggedIn,
    required this.totalBalance,
    required this.totalBalanceRaw,
    required this.todayExpense,
    required this.todayExpenseRaw,
    required this.monthExpense,
    required this.monthExpenseRaw,
    required this.monthIncome,
    required this.monthIncomeRaw,
    required this.monthDifference,
    required this.weekExpense,
    required this.weekIncome,
    required this.weekDifference,
    required this.safeDailySpend,
    required this.monthVsLastMonthPercent,
    required this.monthVsLastMonthStatus,
    required this.sevenDaysChartJson,
    required this.topCategoriesJson,
    required this.walletsJson,
    required this.budgetsJson,
    required this.goalsJson,
    required this.recentTransactionsJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'widget_snapshot_date': snapshotDate,
      'widget_is_logged_in': isLoggedIn,
      'widget_total_balance': totalBalance,
      'widget_total_balance_raw': totalBalanceRaw,
      'widget_today_expense': todayExpense,
      'widget_today_expense_raw': todayExpenseRaw,
      'widget_month_expense': monthExpense,
      'widget_month_expense_raw': monthExpenseRaw,
      'widget_month_income': monthIncome,
      'widget_month_income_raw': monthIncomeRaw,
      'widget_month_difference': monthDifference,
      'widget_week_expense': weekExpense,
      'widget_week_income': weekIncome,
      'widget_week_difference': weekDifference,
      'widget_safe_daily_spend': safeDailySpend,
      'widget_month_vs_last_month_percent': monthVsLastMonthPercent,
      'widget_month_vs_last_month_status': monthVsLastMonthStatus,
      'widget_seven_days_chart_json': sevenDaysChartJson,
      'widget_top_categories_json': topCategoriesJson,
      'widget_wallets_json': walletsJson,
      'widget_budgets_json': budgetsJson,
      'widget_goals_json': goalsJson,
      'widget_recent_transactions_json': recentTransactionsJson,
    };
  }
}

/// Bộ tổng hợp dữ liệu Snapshot cho Android App Widgets (Dart thuần, testable)
class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder();

  static WidgetSnapshotData buildEmpty({bool isLoggedIn = false}) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    return WidgetSnapshotData(
      snapshotDate: dateStr,
      isLoggedIn: isLoggedIn,
      totalBalance: CurrencyUtils.formatCurrency(0),
      totalBalanceRaw: 0,
      todayExpense: CurrencyUtils.formatCurrency(0),
      todayExpenseRaw: 0,
      monthExpense: CurrencyUtils.formatCurrency(0),
      monthExpenseRaw: 0,
      monthIncome: CurrencyUtils.formatCurrency(0),
      monthIncomeRaw: 0,
      monthDifference: CurrencyUtils.formatCurrency(0),
      weekExpense: CurrencyUtils.formatCurrency(0),
      weekIncome: CurrencyUtils.formatCurrency(0),
      weekDifference: CurrencyUtils.formatCurrency(0),
      safeDailySpend: CurrencyUtils.formatCurrency(0),
      monthVsLastMonthPercent: '0%',
      monthVsLastMonthStatus: 'neutral',
      sevenDaysChartJson: '[]',
      topCategoriesJson: '[]',
      walletsJson: '[]',
      budgetsJson: '[]',
      goalsJson: '[]',
      recentTransactionsJson: '[]',
    );
  }

  static WidgetSnapshotData build({
    required List<WalletModel> wallets,
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<GoalModel> goals,
    DateTime? referenceDate,
    bool isLoggedIn = true,
  }) {
    final now = referenceDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    // 1. Số dư các ví
    double totalBalanceRaw = 0;
    final walletsList = <Map<String, dynamic>>[];
    for (final w in wallets) {
      totalBalanceRaw += w.balance;
      walletsList.add({
        'id': w.id,
        'name': w.name,
        'balance': CurrencyUtils.formatCurrency(w.balance),
        'balance_raw': w.balance,
      });
    }

    // 2. Chi tiêu hôm nay, tuần này & tháng này
    double todayExpenseRaw = 0;
    double monthExpenseRaw = 0;
    double monthIncomeRaw = 0;
    double weekExpenseRaw = 0;
    double weekIncomeRaw = 0;

    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    // Thống kê theo danh mục trong tháng
    final categoryExpenseMap = <String, double>{};

    // Chi tiêu cùng kỳ tháng trước (từ ngày 1 đến ngày now.day của tháng trước)
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    double lastMonthExpenseSamePeriod = 0;

    for (final tx in transactions) {
      final isSameMonth = tx.date.year == now.year && tx.date.month == now.month;
      final isSameDay = isSameMonth && tx.date.day == now.day;
      final isThisWeek = !tx.date.isBefore(startOfWeek) && tx.date.year == now.year;

      if (tx.isIncome) {
        if (isSameMonth) monthIncomeRaw += tx.amount;
        if (isThisWeek) weekIncomeRaw += tx.amount;
      } else {
        if (isSameMonth) {
          monthExpenseRaw += tx.amount;
          final cat = tx.category.isNotEmpty ? tx.category : 'Khác';
          categoryExpenseMap[cat] = (categoryExpenseMap[cat] ?? 0) + tx.amount;
        }
        if (isSameDay) todayExpenseRaw += tx.amount;
        if (isThisWeek) weekExpenseRaw += tx.amount;

        // So sánh cùng kỳ tháng trước
        if (tx.date.year == lastMonthYear && tx.date.month == lastMonth && tx.date.day <= now.day) {
          lastMonthExpenseSamePeriod += tx.amount;
        }
      }
    }

    final monthDiffRaw = monthIncomeRaw - monthExpenseRaw;
    final diffPrefix = monthDiffRaw > 0 ? '+' : '';
    final monthDifference = '$diffPrefix${CurrencyUtils.formatCurrency(monthDiffRaw)}';

    final weekDiffRaw = weekIncomeRaw - weekExpenseRaw;
    final weekDiffPrefix = weekDiffRaw > 0 ? '+' : '';
    final weekDifference = '$weekDiffPrefix${CurrencyUtils.formatCurrency(weekDiffRaw)}';

    // 3. Tính toán "Hôm nay còn được tiêu" (Safe Daily Spend)
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (lastDayOfMonth - now.day + 1).clamp(1, 31);

    final totalBudget = budgets.fold<double>(
      0.0,
      (sum, b) => (b.month == now.month && b.year == now.year) ? sum + b.limitAmount : sum,
    );

    double dailySafe = 0;
    if (totalBudget > 0) {
      final remainingBudget = (totalBudget - monthExpenseRaw).clamp(0.0, double.infinity);
      dailySafe = remainingBudget / daysRemaining;
    } else {
      dailySafe = (totalBalanceRaw / daysRemaining).clamp(0.0, double.infinity);
    }
    final safeDailySpend = CurrencyUtils.formatCurrency(dailySafe);

    // 4. Biểu đồ 7 ngày gần nhất (Mini Bar Chart)
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final sevenDaysList = <Map<String, dynamic>>[];
    double maxDayExpense = 0;

    for (int i = 6; i >= 0; i--) {
      final dayDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      double dayExpense = 0;
      for (final tx in transactions) {
        if (!tx.isIncome &&
            tx.date.year == dayDate.year &&
            tx.date.month == dayDate.month &&
            tx.date.day == dayDate.day) {
          dayExpense += tx.amount;
        }
      }
      if (dayExpense > maxDayExpense) maxDayExpense = dayExpense;
      final dayName = dayNames[dayDate.weekday - 1];

      sevenDaysList.add({
        'day': dayName,
        'amount': CurrencyUtils.formatCurrency(dayExpense),
        'amount_raw': dayExpense,
        'is_today': (i == 0),
      });
    }

    // Tính tỷ lệ chiều cao (từ 10 đến 100%)
    for (final dayItem in sevenDaysList) {
      final amount = dayItem['amount_raw'] as double;
      final ratio = maxDayExpense > 0 ? ((amount / maxDayExpense) * 100).round().clamp(10, 100) : 10;
      dayItem['ratio'] = ratio;
    }

    // 5. So sánh chi tiêu với cùng kỳ tháng trước
    String monthVsLastMonthPercent = '0%';
    String monthVsLastMonthStatus = 'neutral';

    if (lastMonthExpenseSamePeriod > 0) {
      final diffPercent = (((monthExpenseRaw - lastMonthExpenseSamePeriod) / lastMonthExpenseSamePeriod) * 100).round();
      if (diffPercent < 0) {
        monthVsLastMonthPercent = '$diffPercent%';
        monthVsLastMonthStatus = 'positive'; // Chi ít hơn tháng trước (xanh)
      } else if (diffPercent > 0) {
        monthVsLastMonthPercent = '+$diffPercent%';
        monthVsLastMonthStatus = 'negative'; // Chi nhiều hơn tháng trước (đỏ)
      } else {
        monthVsLastMonthPercent = '0%';
        monthVsLastMonthStatus = 'neutral';
      }
    }

    // 6. Cơ cấu chi tiêu top 3 danh mục tháng này
    final sortedCategories = categoryExpenseMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topColors = ['#F59E0B', '#10B981', '#06B6D4']; // Cam, Xanh lá, Xanh ngọc
    final topCategories = <Map<String, dynamic>>[];
    for (int i = 0; i < sortedCategories.length && i < 3; i++) {
      final entry = sortedCategories[i];
      final percent = monthExpenseRaw > 0 ? ((entry.value / monthExpenseRaw) * 100).round() : 0;
      topCategories.add({
        'name': entry.key,
        'percent': percent,
        'amount': CurrencyUtils.formatCurrency(entry.value),
        'color': topColors[i],
      });
    }

    // 7. Top 3 ngân sách theo phần trăm sử dụng cao nhất
    final sortedBudgets = List<BudgetModel>.from(budgets);
    sortedBudgets.sort((a, b) {
      final percentA = a.limitAmount > 0 ? (a.currentSpent / a.limitAmount) : 0.0;
      final percentB = b.limitAmount > 0 ? (b.currentSpent / b.limitAmount) : 0.0;
      return percentB.compareTo(percentA);
    });

    final topBudgets = sortedBudgets.take(3).map((b) {
      final percent = b.limitAmount > 0 ? ((b.currentSpent / b.limitAmount) * 100).round() : 0;
      String status = 'green';
      if (percent >= 100) {
        status = 'red';
      } else if (percent >= 80) {
        status = 'orange';
      }

      return {
        'id': b.id,
        'name': b.category,
        'spent': CurrencyUtils.formatCurrency(b.currentSpent),
        'limit': CurrencyUtils.formatCurrency(b.limitAmount),
        'percent': percent,
        'status': status,
      };
    }).toList();

    // 8. Danh sách mục tiêu tiết kiệm
    final goalsList = goals.map((g) {
      final percent = g.targetAmount > 0 ? ((g.currentAmount / g.targetAmount) * 100).round() : 0;
      final remaining = (g.targetAmount - g.currentAmount).clamp(0.0, double.infinity);
      return {
        'id': g.id,
        'name': g.title,
        'current': CurrencyUtils.formatCurrency(g.currentAmount),
        'target': CurrencyUtils.formatCurrency(g.targetAmount),
        'remaining': CurrencyUtils.formatCurrency(remaining),
        'percent': percent,
      };
    }).toList();

    // 9. Hai hoặc ba giao dịch gần nhất
    final sortedTxs = List<TransactionModel>.from(transactions);
    sortedTxs.sort((a, b) => b.date.compareTo(a.date));

    final recentTxs = sortedTxs.take(3).map((tx) {
      final isToday = tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day;
      final timeStr = DateFormat('HH:mm').format(tx.date);
      final dateStrFormatted = isToday ? 'Hôm nay, $timeStr' : DateFormat('dd/MM, HH:mm').format(tx.date);

      final prefix = tx.isIncome ? '+' : '-';
      final formattedAmount = '$prefix${CurrencyUtils.formatCurrency(tx.amount)}';

      final title = tx.category.isNotEmpty ? tx.category : (tx.description.isNotEmpty ? tx.description : 'Giao dịch');

      return {
        'id': tx.id,
        'title': title,
        'amount': formattedAmount,
        'is_income': tx.isIncome,
        'date': dateStrFormatted,
      };
    }).toList();

    return WidgetSnapshotData(
      snapshotDate: dateStr,
      isLoggedIn: isLoggedIn,
      totalBalance: CurrencyUtils.formatCurrency(totalBalanceRaw),
      totalBalanceRaw: totalBalanceRaw,
      todayExpense: CurrencyUtils.formatCurrency(todayExpenseRaw),
      todayExpenseRaw: todayExpenseRaw,
      monthExpense: CurrencyUtils.formatCurrency(monthExpenseRaw),
      monthExpenseRaw: monthExpenseRaw,
      monthIncome: CurrencyUtils.formatCurrency(monthIncomeRaw),
      monthIncomeRaw: monthIncomeRaw,
      monthDifference: monthDifference,
      weekExpense: CurrencyUtils.formatCurrency(weekExpenseRaw),
      weekIncome: CurrencyUtils.formatCurrency(weekIncomeRaw),
      weekDifference: weekDifference,
      safeDailySpend: safeDailySpend,
      monthVsLastMonthPercent: monthVsLastMonthPercent,
      monthVsLastMonthStatus: monthVsLastMonthStatus,
      sevenDaysChartJson: jsonEncode(sevenDaysList),
      topCategoriesJson: jsonEncode(topCategories),
      walletsJson: jsonEncode(walletsList),
      budgetsJson: jsonEncode(topBudgets),
      goalsJson: jsonEncode(goalsList),
      recentTransactionsJson: jsonEncode(recentTxs),
    );
  }
}
