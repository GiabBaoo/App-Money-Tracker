import 'dart:async';
import 'package:flutter/material.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../models/transaction_model.dart';
import '../models/goal_model.dart';
import '../utils/currency_format_utils.dart';

/// Kết quả phân tích hạn mức an toàn tiêu mỗi ngày
class SafeDailySpendResult {
  final double safeDailyAmount;
  final int daysRemaining;
  final double totalMonthlyBudget;
  final double totalSpentThisMonth;
  final double remainingBudget;
  final double todaySpent;
  final String status; // 'healthy' | 'warning' | 'danger'
  final String advice;

  const SafeDailySpendResult({
    required this.safeDailyAmount,
    required this.daysRemaining,
    required this.totalMonthlyBudget,
    required this.totalSpentThisMonth,
    required this.remainingBudget,
    required this.todaySpent,
    required this.status,
    required this.advice,
  });
}

/// Kết quả dự báo số dư và chi tiêu cuối tháng
class MonthEndForecastResult {
  final double currentExpense;
  final double dailyBurnRate;
  final double projectedTotalExpense;
  final double expectedIncome;
  final double projectedBalance;
  final bool isDeficit;
  final String burnRateStatus; // 'low' | 'normal' | 'high' | 'critical'
  final String summary;

  const MonthEndForecastResult({
    required this.currentExpense,
    required this.dailyBurnRate,
    required this.projectedTotalExpense,
    required this.expectedIncome,
    required this.projectedBalance,
    required this.isDeficit,
    required this.burnRateStatus,
    required this.summary,
  });
}

/// Kết quả phân tích các khoản tiêu vặt gây thủng ví (Latte Factor)
class LatteFactorResult {
  final double totalSmallExpenses;
  final int transactionCount;
  final List<TransactionModel> smallTransactions;
  final double projectedYearlySavings;
  final String comparisonItem;
  final String advice;

  const LatteFactorResult({
    required this.totalSmallExpenses,
    required this.transactionCount,
    required this.smallTransactions,
    required this.projectedYearlySavings,
    required this.comparisonItem,
    required this.advice,
  });
}

/// Kết quả kiểm tra giao dịch trùng lặp / bất thường
class AnomalyCheckResult {
  final bool isDuplicate;
  final TransactionModel? duplicateTx;
  final bool isAnomaly;
  final String? anomalyReason;

  const AnomalyCheckResult({
    this.isDuplicate = false,
    this.duplicateTx,
    this.isAnomaly = false,
    this.anomalyReason,
  });
}

/// Kết quả lộ trình tiết kiệm mục tiêu cụ thể
class SavingsRoadmapResult {
  final GoalModel goal;
  final double monthlyTarget;
  final double dailyTarget;
  final int monthsNeeded;
  final List<String> cutbackSuggestions;
  final String planExplanation;

  const SavingsRoadmapResult({
    required this.goal,
    required this.monthlyTarget,
    required this.dailyTarget,
    required this.monthsNeeded,
    required this.cutbackSuggestions,
    required this.planExplanation,
  });
}

/// Kết quả tra cứu chi tiêu cá nhân từ SQLite
class PersonalSpendingQueryResult {
  final String queryText;
  final double totalAmount;
  final int transactionCount;
  final String periodDescription;
  final String? categoryFilter;
  final List<TransactionModel> relevantTransactions;
  final String answerText;
  final String? topCategory;
  final double? topCategoryAmount;
  final double? topCategoryPercentage;
  final int? topCategoryTxCount;
  final TransactionModel? topTransaction;
  final Map<String, double>? categoryBreakdown;
  final int? daysCount;

  const PersonalSpendingQueryResult({
    required this.queryText,
    required this.totalAmount,
    required this.transactionCount,
    required this.periodDescription,
    this.categoryFilter,
    required this.relevantTransactions,
    required this.answerText,
    this.topCategory,
    this.topCategoryAmount,
    this.topCategoryPercentage,
    this.topCategoryTxCount,
    this.topTransaction,
    this.categoryBreakdown,
    this.daysCount,
  });
}

/// Kết quả phân tích xu hướng chi tiêu & phát hiện biến động bất thường
class SpendingTrendResult {
  final String periodName;
  final double currentExpense;
  final double previousExpense;
  final double percentChange;
  final String trendStatus; // 'increased' | 'decreased' | 'stable'
  final List<String> anomalies;
  final Map<String, double> currentCategoryBreakdown;
  final String advice;

  const SpendingTrendResult({
    required this.periodName,
    required this.currentExpense,
    required this.previousExpense,
    required this.percentChange,
    required this.trendStatus,
    required this.anomalies,
    required this.currentCategoryBreakdown,
    required this.advice,
  });
}

/// Chi tiết một tiêu chí đánh giá sức khỏe tài chính
class HealthScoreMetric {
  final String name;
  final int score;
  final int maxScore;
  final String status; // 'excellent' | 'good' | 'warning' | 'poor'
  final String detail;

  const HealthScoreMetric({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.detail,
  });
}

/// Kết quả tính toán điểm sức khỏe tài chính toàn diện (0-100)
class FinancialHealthScoreResult {
  final int overallScore;
  final String rating; // 'Xuất sắc' | 'Tốt' | 'Cần cải thiện' | 'Báo động'
  final Color statusColor;
  final List<HealthScoreMetric> metrics;
  final List<String> recommendations;
  final String summaryAdvice;

  const FinancialHealthScoreResult({
    required this.overallScore,
    required this.rating,
    required this.statusColor,
    required this.metrics,
    required this.recommendations,
    required this.summaryAdvice,
  });
}

/// Chi tiết một khoản giao dịch định kỳ
class RecurringTransactionItem {
  final String title;
  final String category;
  final double amount;
  final String frequency; // 'Hàng tháng' | 'Hàng tuần'
  final int occurrences;
  final DateTime nextEstimatedDate;

  const RecurringTransactionItem({
    required this.title,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.occurrences,
    required this.nextEstimatedDate,
  });
}

/// Kết quả quét phát hiện chi phí định kỳ
class RecurringDetectionResult {
  final List<RecurringTransactionItem> items;
  final double totalMonthlyFixedCost;
  final String summary;

  const RecurringDetectionResult({
    required this.items,
    required this.totalMonthlyFixedCost,
    required this.summary,
  });
}

/// Dịch vụ Cố vấn Tài chính Cá nhân Thông minh của Trợ lý Mono
class FinancialAdvisorService {
  static final FinancialAdvisorService _instance = FinancialAdvisorService._internal();
  factory FinancialAdvisorService() => _instance;
  FinancialAdvisorService._internal();

  final TransactionRepository _txRepo = TransactionRepository();
  final BudgetRepository _budgetRepo = BudgetRepository();
  final WalletRepository _walletRepo = WalletRepository();

  // ════════════════════════════════════════════════════════════════════════════
  // 1. CẢNH BÁO NGÂN SÁCH: HẠN MỨC AN TOÀN ĐƯỢC TIÊU MỖI NGÀY
  // ════════════════════════════════════════════════════════════════════════════

  Future<SafeDailySpendResult> calculateSafeDailyBudget() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (daysInMonth - now.day + 1).clamp(1, 31);

    // Lấy tất cả giao dịch trong tháng hiện tại
    final startOfMonth = DateTime(now.year, now.month, 1);
    final allTx = await _txRepo.getAllTransactions();
    final thisMonthTx = allTx.where((tx) => tx.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))).toList();

    final monthExpenses = thisMonthTx.where((tx) => tx.type == 'expense');
    final totalSpentThisMonth = monthExpenses.fold(0.0, (sum, tx) => sum + tx.amount);

    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySpent = monthExpenses
        .where((tx) => tx.date.isAfter(todayStart.subtract(const Duration(seconds: 1))))
        .fold(0.0, (sum, tx) => sum + tx.amount);

    // Lấy ngân sách đã thiết lập cho tháng này
    final budgets = await _budgetRepo.getBudgetsWithSpent(month: now.month, year: now.year);
    double totalBudget = budgets.fold(0.0, (sum, b) => sum + b.limitAmount);

    // Nếu người dùng chưa tạo Budget, tham chiếu theo tổng thu nhập tháng hoặc số dư hiện có
    if (totalBudget <= 0) {
      final monthIncome = thisMonthTx.where((tx) => tx.type == 'income').fold(0.0, (sum, tx) => sum + tx.amount);
      if (monthIncome > 0) {
        totalBudget = monthIncome * 0.8; // Khuyến nghị chi tối đa 80% thu nhập
      } else {
        // Dùng số dư các ví
        final wallets = await _walletRepo.getWallets();
        final totalWalletBalance = wallets.fold(0.0, (sum, w) => sum + w.balance);
        totalBudget = totalWalletBalance > 0 ? totalWalletBalance : 10000000;
      }
    }

    final remainingBudget = (totalBudget - totalSpentThisMonth).clamp(0.0, double.infinity);
    final rawSafePerDay = remainingBudget / remainingDays;
    final safeDaily = (rawSafePerDay / 1000).floor() * 1000.0;

    String status = 'healthy';
    String advice = '';

    if (totalSpentThisMonth > totalBudget) {
      status = 'danger';
      advice = '⚠️ Bạn đã chi vượt ngân sách tháng **${CurrencyUtils.formatCurrency(totalSpentThisMonth - totalBudget)}**. Hãy thắt chặt các khoản không thiết yếu!';
    } else if (todaySpent > safeDaily && safeDaily > 0) {
      status = 'warning';
      advice = '⚡ Hôm nay bạn đã tiêu **${CurrencyUtils.formatCurrency(todaySpent)}**, vượt định mức an toàn ngày (${CurrencyUtils.formatCurrency(safeDaily)}). Cân nhắc giảm chi vào ngày mai nhé!';
    } else {
      status = 'healthy';
      advice = '✅ Bạn đang kiểm soát chi tiêu rất tốt! Định mức an toàn hôm nay là **${CurrencyUtils.formatCurrency(safeDaily)}**.';
    }

    return SafeDailySpendResult(
      safeDailyAmount: safeDaily,
      daysRemaining: remainingDays,
      totalMonthlyBudget: totalBudget,
      totalSpentThisMonth: totalSpentThisMonth,
      remainingBudget: remainingBudget,
      todaySpent: todaySpent,
      status: status,
      advice: advice,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. DỰ BÁO CUỐI THÁNG: DỰ ĐOÁN SỐ DƯ & NGUY CƠ THÂM HỤT
  // ════════════════════════════════════════════════════════════════════════════

  Future<MonthEndForecastResult> forecastMonthEndBalance() async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day.clamp(1, 31);
    final daysRemaining = daysInMonth - daysPassed;

    final startOfMonth = DateTime(now.year, now.month, 1);
    final allTx = await _txRepo.getAllTransactions();
    final thisMonthTx = allTx.where((tx) => tx.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))).toList();

    final currentExpense = thisMonthTx.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);
    final currentIncome = thisMonthTx.where((tx) => tx.type == 'income').fold(0.0, (sum, tx) => sum + tx.amount);

    // Tốc độ đốt tiền (Burn rate) trung bình/ngày từ đầu tháng tới giờ
    final dailyBurnRate = currentExpense / daysPassed;
    final projectedAdditionalExpense = dailyBurnRate * daysRemaining;
    final projectedTotalExpense = currentExpense + projectedAdditionalExpense;

    // Dự kiến thu nhập cuối tháng
    final expectedIncome = currentIncome > 0 ? currentIncome : (projectedTotalExpense * 1.2);
    final projectedBalance = expectedIncome - projectedTotalExpense;
    final isDeficit = projectedBalance < 0;

    String burnRateStatus = 'normal';
    final summaryBuffer = StringBuffer();

    if (isDeficit) {
      burnRateStatus = 'critical';
      summaryBuffer.writeln('🚨 **CẢNH BÁO NGUY CƠ THÂM HỤT CUỐI THÁNG!**');
      summaryBuffer.writeln('Với tốc độ tiêu trung bình **${CurrencyUtils.formatCurrency(dailyBurnRate)}/ngày**, bạn dự kiến sẽ chi hết **${CurrencyUtils.formatCurrency(projectedTotalExpense)}** trong tháng này.');
      summaryBuffer.writeln('Dự kiến thiếu hụt khoảng **${CurrencyUtils.formatCurrency(projectedBalance.abs())}** so với thu nhập. Hãy xem xét cắt giảm các khoản mua sắm và giải trí ngay hôm nay.');
    } else if (dailyBurnRate > (expectedIncome / daysInMonth * 0.9)) {
      burnRateStatus = 'high';
      summaryBuffer.writeln('⚠️ **Tốc độ chi tiêu đang ở mức cao!**');
      summaryBuffer.writeln('Bạn đang tiêu trung bình **${CurrencyUtils.formatCurrency(dailyBurnRate)}/ngày**. Dự kiến cuối tháng bạn chỉ còn giữ lại được khoảng **${CurrencyUtils.formatCurrency(projectedBalance)}**.');
    } else {
      burnRateStatus = 'low';
      summaryBuffer.writeln('🎉 **Tình hình tài chính cuối tháng rất khả quan!**');
      summaryBuffer.writeln('Với mức chi trung bình **${CurrencyUtils.formatCurrency(dailyBurnRate)}/ngày**, bạn dự kiến giữ lại được số dư an toàn **${CurrencyUtils.formatCurrency(projectedBalance)}** khi hết tháng.');
    }

    return MonthEndForecastResult(
      currentExpense: currentExpense,
      dailyBurnRate: dailyBurnRate,
      projectedTotalExpense: projectedTotalExpense,
      expectedIncome: expectedIncome,
      projectedBalance: projectedBalance,
      isDeficit: isDeficit,
      burnRateStatus: burnRateStatus,
      summary: summaryBuffer.toString(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. TIÊU VẶT THỦNG VÍ: PHÂN TÍCH LATTE FACTOR
  // ════════════════════════════════════════════════════════════════════════════

  Future<LatteFactorResult> analyzeLatteFactor() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final allTx = await _txRepo.getAllTransactions();

    // Các khoản tiêu vặt: <= 70.000đ thuộc các danh mục dễ phát sinh tiêu vặt
    final snackCategories = {'Ăn uống', 'Giải trí', 'Mua sắm', 'Chi khác'};
    final smallExpenses = allTx.where((tx) {
      final isSmall = tx.type == 'expense' && tx.amount > 0 && tx.amount <= 70000;
      final inMonth = tx.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
      final isSnackCategory = snackCategories.contains(tx.category) ||
          tx.description.toLowerCase().contains('cafe') ||
          tx.description.toLowerCase().contains('trà sữa') ||
          tx.description.toLowerCase().contains('quà vặt') ||
          tx.description.toLowerCase().contains('ship');
      return isSmall && inMonth && isSnackCategory;
    }).toList();

    final totalSmallExpenses = smallExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final count = smallExpenses.length;

    // Dự tính 1 năm (nhân 12 tháng)
    final yearlySavings = totalSmallExpenses * 12;

    String comparison = '1 kỳ nghỉ dưỡng cuối tuần trọn vẹn';
    if (yearlySavings >= 25000000) {
      comparison = '1 chiếc iPhone mới nhất hoặc xe tay ga';
    } else if (yearlySavings >= 15000000) {
      comparison = '1 chiếc Laptop cao cấp hoặc chuyến du lịch Thái Lan';
    } else if (yearlySavings >= 8000000) {
      comparison = '1 chiếc Apple Watch hoặc khóa học nâng cao kỹ năng';
    } else if (yearlySavings >= 3000000) {
      comparison = '1 đôi giày thể thao hàng hiệu và tai nghe xịn';
    }

    String advice = '';
    if (count > 0) {
      advice = '💡 Trong tháng này bạn đã có **$count lần** chi tiêu lặt vặt (dưới 70.000đ), tích tụ thành **${CurrencyUtils.formatCurrency(totalSmallExpenses)}**. '
          'Nếu giảm bớt 1 ly trà sữa hoặc cà phê mỗi ngày, bạn sẽ tiết kiệm được khoảng **${CurrencyUtils.formatCurrency(yearlySavings)}/năm** ($comparison)!';
    } else {
      advice = '👏 Tuyệt vời! Bạn không có nhiều khoản chi tiêu vặt gây rò rỉ ví tiền trong tháng này. Hãy tiếp tục duy trì thói quen kiểm soát này!';
    }

    return LatteFactorResult(
      totalSmallExpenses: totalSmallExpenses,
      transactionCount: count,
      smallTransactions: smallExpenses,
      projectedYearlySavings: yearlySavings,
      comparisonItem: comparison,
      advice: advice,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. PHÁT HIỆN TRÙNG LẶP & GIAO DỊCH BẤT THƯỜNG
  // ════════════════════════════════════════════════════════════════════════════

  Future<AnomalyCheckResult> detectDuplicateOrAnomaly(TransactionModel newTx) async {
    final recentTxList = await _txRepo.getAllTransactions(limit: 30);

    // 1. Kiểm tra trùng lặp trong vòng 30 phút
    for (final tx in recentTxList) {
      if (tx.id == newTx.id) continue;
      final timeDiff = newTx.date.difference(tx.date).abs();
      if (timeDiff.inMinutes <= 30 &&
          (tx.amount - newTx.amount).abs() < 1 &&
          tx.type == newTx.type &&
          (tx.category == newTx.category || tx.description.toLowerCase() == newTx.description.toLowerCase())) {
        return AnomalyCheckResult(
          isDuplicate: true,
          duplicateTx: tx,
          isAnomaly: false,
          anomalyReason: 'Bạn vừa lưu một giao dịch tương tự "${tx.description}" (${CurrencyUtils.formatCurrency(tx.amount)}) cách đây ${timeDiff.inMinutes} phút.',
        );
      }
    }

    // 2. Kiểm tra bất thường (Anomaly): Giao dịch chi tiêu đột biến > 3x trung bình danh mục
    if (newTx.type == 'expense' && newTx.amount >= 500000) {
      final categoryTxs = recentTxList.where((tx) => tx.category == newTx.category && tx.type == 'expense');
      if (categoryTxs.length >= 3) {
        final avg = categoryTxs.fold(0.0, (sum, tx) => sum + tx.amount) / categoryTxs.length;
        if (newTx.amount >= avg * 3.0 && newTx.amount >= 1000000) {
          return AnomalyCheckResult(
            isDuplicate: false,
            isAnomaly: true,
            anomalyReason: 'Khoản chi ${CurrencyUtils.formatCurrency(newTx.amount)} cho [${newTx.category}] cao gấp ${(newTx.amount / avg).toStringAsFixed(1)} lần mức chi tiêu trung bình (${CurrencyUtils.formatCurrency(avg)})!',
          );
        }
      }
    }

    return const AnomalyCheckResult();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. TRÒ CHUYỆN & CỐ VẤN: LÊN LỘ TRÌNH TIẾT KIỆM THEO MỤC TIÊU CỤ THỂ
  // ════════════════════════════════════════════════════════════════════════════

  Future<SavingsRoadmapResult> generateSavingsRoadmap({
    required String goalTitle,
    required double targetAmount,
    int? targetMonths,
  }) async {
    final months = targetMonths ?? 6;
    final monthlyTarget = (targetAmount / months / 1000).ceil() * 1000.0;
    final dailyTarget = (monthlyTarget / 30 / 1000).ceil() * 1000.0;

    final deadline = DateTime.now().add(Duration(days: months * 30));

    // Phân tích chi tiêu thực tế để gợi ý cắt giảm
    final allTx = await _txRepo.getAllTransactions(limit: 100);
    final expenseTx = allTx.where((tx) => tx.type == 'expense');

    final Map<String, double> categoryTotals = {};
    for (final tx in expenseTx) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final suggestions = <String>[];
    if ((categoryTotals['Ăn uống'] ?? 0) > monthlyTarget * 0.5) {
      suggestions.add('Cắt giảm bớt 20% tiền ăn ngoài/cafe (tiết kiệm ~${CurrencyUtils.formatCurrency((categoryTotals['Ăn uống'] ?? 0) * 0.2)}/tháng)');
    }
    if ((categoryTotals['Mua sắm'] ?? 0) > 500000) {
      suggestions.add('Áp dụng quy tắc chờ 48 giờ trước khi mua sắm online');
    }
    if ((categoryTotals['Giải trí'] ?? 0) > 300000) {
      suggestions.add('Hạn chế 1 buổi xem phim/nhậu cuối tuần để bù vào quỹ');
    }
    if (suggestions.isEmpty) {
      suggestions.add('Tự động trích ${CurrencyUtils.formatCurrency(monthlyTarget)} vào tài khoản tiết kiệm ngay khi nhận lương.');
      suggestions.add('Tích lũy các khoản tiền lẻ hàng ngày.');
    }

    final explanationBuffer = StringBuffer();
    explanationBuffer.writeln('🎯 **LỘ TRÌNH TIẾT KIỆM CHO: ${goalTitle.toUpperCase()}**');
    explanationBuffer.writeln('• Mục tiêu cần đạt: **${CurrencyUtils.formatCurrency(targetAmount)}**');
    explanationBuffer.writeln('• Thời hạn dự kiến: **$months tháng** (hoàn thành trước ${deadline.day}/${deadline.month}/${deadline.year})');
    explanationBuffer.writeln('• Số tiền cần để dành mỗi tháng: **${CurrencyUtils.formatCurrency(monthlyTarget)}**');
    explanationBuffer.writeln('• Tương đương mỗi ngày: **${CurrencyUtils.formatCurrency(dailyTarget)}/ngày** (bằng khoảng 1 ly cafe).');
    explanationBuffer.writeln('\n💡 **Gợi ý hành động từ Mono:**');
    for (final s in suggestions) {
      explanationBuffer.writeln('• $s');
    }

    final goalModel = GoalModel(
      id: '',
      uid: '',
      title: goalTitle,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      deadline: deadline,
      iconCode: Icons.savings_rounded.codePoint,
      colorValue: 0xFF438883,
      note: 'Lộ trình do Trợ lý Mono tạo: Cần tiết kiệm ${CurrencyUtils.formatCurrency(monthlyTarget)}/tháng',
    );

    return SavingsRoadmapResult(
      goal: goalModel,
      monthlyTarget: monthlyTarget,
      dailyTarget: dailyTarget,
      monthsNeeded: months,
      cutbackSuggestions: suggestions,
      planExplanation: explanationBuffer.toString(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. TRA CỨU CHI TIÊU CÁ NHÂN TRỰC TIẾP TỪ SQLITE (Offline 0ms)
  // ════════════════════════════════════════════════════════════════════════════

  Future<PersonalSpendingQueryResult> queryPersonalSpending(String query) async {
    final lower = query.toLowerCase();
    final now = DateTime.now();

    DateTime startDate;
    DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    String periodText = 'trong tháng này';
    int? customDays;

    // 1. Nhận diện các khoảng thời gian tùy biến: "3 ngày qua", "5 ngày gần đây", "7 ngày trước"...
    final daysMatch = RegExp(r'(\d+)\s+ngày\s+(?:qua|gần\s+đây|trước)', caseSensitive: false).firstMatch(lower);
    if (daysMatch != null) {
      customDays = int.tryParse(daysMatch.group(1)!);
    } else if (lower.contains('vài ngày qua') || lower.contains('mấy ngày qua') || lower.contains('mấy ngày nay')) {
      customDays = 3;
    }

    if (customDays != null && customDays > 0) {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: customDays - 1));
      periodText = '$customDays ngày qua';
    } else if (lower.contains('hôm nay') || lower.contains('hom nay')) {
      startDate = DateTime(now.year, now.month, now.day);
      periodText = 'hôm nay';
    } else if (lower.contains('hôm qua') || lower.contains('hom qua')) {
      final yesterday = now.subtract(const Duration(days: 1));
      startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      periodText = 'hôm qua';
    } else if (lower.contains('tuần này') || lower.contains('tuan nay')) {
      startDate = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      periodText = 'tuần này';
    } else if (lower.contains('tuần trước') || lower.contains('tuan truoc')) {
      final lastWeek = now.subtract(Duration(days: now.weekday + 6));
      startDate = DateTime(lastWeek.year, lastWeek.month, lastWeek.day);
      final endLastWeek = startDate.add(const Duration(days: 6));
      endDate = DateTime(endLastWeek.year, endLastWeek.month, endLastWeek.day, 23, 59, 59);
      periodText = 'tuần trước';
    } else if (lower.contains('tháng trước') || lower.contains('thang truoc')) {
      startDate = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0);
      endDate = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, lastDayPrevMonth.day, 23, 59, 59);
      periodText = 'tháng trước';
    } else if (lower.contains('năm nay') || lower.contains('nam nay')) {
      startDate = DateTime(now.year, 1, 1);
      periodText = 'năm nay';
    } else {
      // Mặc định tháng này
      startDate = DateTime(now.year, now.month, 1);
      periodText = 'tháng này';
    }

    final allTx = await _txRepo.getAllTransactions();

    // 2. Lọc theo khoảng thời gian chuẩn xác
    var filtered = allTx.where((tx) {
      return tx.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          tx.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    // 3. Lọc theo danh mục nếu người dùng có hỏi danh mục cụ thể
    String? categoryFilter;
    if (lower.contains('ăn uống') || lower.contains('an uong') || lower.contains('cơm') || lower.contains('cafe')) {
      categoryFilter = 'Ăn uống';
    } else if (lower.contains('di chuyển') || lower.contains('grab') || lower.contains('xăng') || lower.contains('taxi')) {
      categoryFilter = 'Di chuyển';
    } else if (lower.contains('mua sắm') || lower.contains('shopping') || lower.contains('shopee')) {
      categoryFilter = 'Mua sắm';
    } else if (lower.contains('tiền nhà') || lower.contains('tiền phòng') || lower.contains('tiền trọ')) {
      categoryFilter = 'Tiền nhà';
    } else if (lower.contains('tiền điện') || lower.contains('điện nước')) {
      categoryFilter = 'Tiền điện';
    }

    if (categoryFilter != null) {
      final filter = categoryFilter.toLowerCase();
      filtered = filtered.where((tx) => tx.category == categoryFilter || tx.description.toLowerCase().contains(filter)).toList();
    }

    // 4. Phân tích bóc tách các khoản chi tiêu (Expense)
    final expenseTxs = filtered.where((tx) => tx.type == 'expense').toList();
    final double totalAmount = expenseTxs.fold(0.0, (sum, tx) => sum + tx.amount);
    final count = expenseTxs.length;

    // Tổng hợp chi tiêu theo từng danh mục
    final Map<String, double> catMap = {};
    final Map<String, int> catCount = {};
    for (var tx in expenseTxs) {
      catMap[tx.category] = (catMap[tx.category] ?? 0.0) + tx.amount;
      catCount[tx.category] = (catCount[tx.category] ?? 0) + 1;
    }

    // Sắp xếp danh mục chi nhiều nhất giảm dần
    final sortedCats = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    String? topCat;
    double topCatAmount = 0.0;
    double topCatPct = 0.0;
    int topCatCount = 0;
    if (sortedCats.isNotEmpty) {
      topCat = sortedCats.first.key;
      topCatAmount = sortedCats.first.value;
      topCatPct = totalAmount > 0 ? (topCatAmount / totalAmount) * 100 : 0.0;
      topCatCount = catCount[topCat] ?? 1;
    }

    // Khoản chi đơn lẻ lớn nhất
    expenseTxs.sort((a, b) => b.amount.compareTo(a.amount));
    final topTx = expenseTxs.isNotEmpty ? expenseTxs.first : null;

    // 5. Nếu chưa có giao dịch nào trong khoảng thời gian này
    if (expenseTxs.isEmpty) {
      final emptyAnswer = '🔍 Trong **$periodText**, bạn chưa có ghi chép chi tiêu nào trong sổ. Hãy ghi chép đều đặn để Mono giúp bạn kiểm soát và phân tích tài chính chính xác nhé! ✨';
      return PersonalSpendingQueryResult(
        queryText: query,
        totalAmount: 0.0,
        transactionCount: 0,
        periodDescription: periodText,
        categoryFilter: categoryFilter,
        relevantTransactions: [],
        answerText: emptyAnswer,
        daysCount: customDays,
      );
    }

    // 6. Xây dựng câu trả lời tự nhiên, sâu sắc và thông minh
    final sb = StringBuffer();
    final totalFormatted = CurrencyUtils.formatCurrency(totalAmount);

    final bool isAskingTopCategory = lower.contains('nhiều nhất') ||
        lower.contains('lớn nhất') ||
        lower.contains('việc nào') ||
        lower.contains('cái gì') ||
        lower.contains('khoản nào') ||
        lower.contains('mức chi tiêu');

    if (isAskingTopCategory && topCat != null) {
      final topCatFormatted = CurrencyUtils.formatCurrency(topCatAmount);
      final pctStr = topCatPct.toStringAsFixed(1);
      sb.writeln('📊 Trong **$periodText**, bạn chi tiêu nhiều nhất cho việc **$topCat** với tổng cộng **$topCatFormatted** (chiếm **$pctStr%** trên tổng chi **$totalFormatted**, gồm **$topCatCount giao dịch**).');
      
      if (topTx != null) {
        sb.writeln('\n• 📌 Khoản chi lớn nhất: **${CurrencyUtils.formatCurrency(topTx.amount)}** cho "${topTx.description}" ngày ${topTx.date.day}/${topTx.date.month}.');
      }

      if (sortedCats.length > 1) {
        sb.writeln('• 📋 Các danh mục chi tiêu tiếp theo:');
        for (var i = 1; i < sortedCats.length && i < 4; i++) {
          final entry = sortedCats[i];
          final p = totalAmount > 0 ? (entry.value / totalAmount * 100).toStringAsFixed(0) : '0';
          sb.writeln('   - ${entry.key}: **${CurrencyUtils.formatCurrency(entry.value)}** ($p%)');
        }
      }
    } else {
      final catText = categoryFilter != null ? 'cho danh mục **$categoryFilter** ' : '';
      sb.writeln('📊 Trong **$periodText**, tổng chi tiêu của bạn là **$totalFormatted** $catText(gồm **$count giao dịch**).');
      if (topCat != null) {
        sb.writeln('• Danh mục chi nhiều nhất: **$topCat** (${CurrencyUtils.formatCurrency(topCatAmount)}, chiếm ${topCatPct.toStringAsFixed(0)}%).');
      }
    }

    return PersonalSpendingQueryResult(
      queryText: query,
      totalAmount: totalAmount,
      transactionCount: count,
      periodDescription: periodText,
      categoryFilter: categoryFilter,
      relevantTransactions: expenseTxs.take(5).toList(),
      answerText: sb.toString().trim(),
      topCategory: topCat,
      topCategoryAmount: topCatAmount,
      topCategoryPercentage: topCatPct,
      topCategoryTxCount: topCatCount,
      topTransaction: topTx,
      categoryBreakdown: catMap,
      daysCount: customDays,
    );
  }

  /// ════════════════════════════════════════════════════════════════════════════
  /// 6. PHÂN TÍCH XU HƯỚNG CHI TIÊU & CẢNH BÁO BẤT THƯỜNG (Spending Trends)
  /// ════════════════════════════════════════════════════════════════════════════
  Future<SpendingTrendResult> analyzeSpendingTrends({String period = 'week'}) async {
    final allTx = await _txRepo.getAllTransactions();
    final now = DateTime.now();

    final isMonth = period.toLowerCase().contains('tháng') || period.toLowerCase().contains('month');
    final periodName = isMonth ? 'tháng này' : 'tuần này';

    DateTime curStart;
    DateTime prevStart;
    DateTime prevEnd;

    if (isMonth) {
      curStart = DateTime(now.year, now.month, 1);
      final prevMonthDate = DateTime(now.year, now.month - 1, 1);
      prevStart = DateTime(prevMonthDate.year, prevMonthDate.month, 1);
      prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else {
      curStart = now.subtract(const Duration(days: 7));
      prevStart = now.subtract(const Duration(days: 14));
      prevEnd = curStart;
    }

    final curTx = allTx.where((tx) => tx.type == 'expense' && tx.date.isAfter(curStart.subtract(const Duration(seconds: 1))));
    final prevTx = allTx.where((tx) => tx.type == 'expense' && tx.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) && tx.date.isBefore(prevEnd));

    final curExpense = curTx.fold(0.0, (sum, tx) => sum + tx.amount);
    final prevExpense = prevTx.fold(0.0, (sum, tx) => sum + tx.amount);

    double percentChange = 0.0;
    if (prevExpense > 0) {
      percentChange = ((curExpense - prevExpense) / prevExpense) * 100;
    } else if (curExpense > 0) {
      percentChange = 100.0;
    }

    final Map<String, double> curCatMap = {};
    for (final tx in curTx) {
      curCatMap[tx.category] = (curCatMap[tx.category] ?? 0.0) + tx.amount;
    }

    final Map<String, double> prevCatMap = {};
    for (final tx in prevTx) {
      prevCatMap[tx.category] = (prevCatMap[tx.category] ?? 0.0) + tx.amount;
    }

    final List<String> anomalies = [];
    curCatMap.forEach((cat, amount) {
      final prevAmount = prevCatMap[cat] ?? 0.0;
      if (prevAmount > 0 && amount >= prevAmount * 1.35 && (amount - prevAmount) >= 100000) {
        final diff = amount - prevAmount;
        final growth = ((amount - prevAmount) / prevAmount) * 100;
        anomalies.add('$cat (+${CurrencyUtils.formatCurrency(diff)}, tăng ${growth.toStringAsFixed(0)}%)');
      } else if (prevAmount == 0 && amount >= 200000) {
        anomalies.add('$cat (mới phát sinh ${CurrencyUtils.formatCurrency(amount)})');
      }
    });

    String trendStatus = 'stable';
    String advice = '';
    if (percentChange > 15) {
      trendStatus = 'increased';
      advice = '⚠️ Chi tiêu $periodName tăng **${percentChange.toStringAsFixed(1)}%** (+${CurrencyUtils.formatCurrency(curExpense - prevExpense)}) so với kỳ trước. Bạn nên cân nhắc thắt chặt các khoản chi không thiết yếu!';
    } else if (percentChange < -10) {
      trendStatus = 'decreased';
      advice = '🎉 Rất tốt! Bạn đã tiết kiệm và giảm chi tiêu **${percentChange.abs().toStringAsFixed(1)}%** (-${CurrencyUtils.formatCurrency(prevExpense - curExpense)}) so với kỳ trước. Tiếp tục phát huy nhé!';
    } else {
      trendStatus = 'stable';
      advice = '⚖️ Mức chi tiêu của bạn duy trì ổn định (${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}% so với kỳ trước).';
    }

    return SpendingTrendResult(
      periodName: isMonth ? 'Tháng này' : 'Tuần này',
      currentExpense: curExpense,
      previousExpense: prevExpense,
      percentChange: percentChange,
      trendStatus: trendStatus,
      anomalies: anomalies,
      currentCategoryBreakdown: curCatMap,
      advice: advice,
    );
  }

  /// ════════════════════════════════════════════════════════════════════════════
  /// 7. ĐIỂM SỨC KHỎE TÀI CHÍNH TOÀN DIỆN (Financial Health Score 0-100)
  /// ════════════════════════════════════════════════════════════════════════════
  Future<FinancialHealthScoreResult> calculateFinancialHealthScore() async {
    final allTx = await _txRepo.getAllTransactions();
    final budgets = await _budgetRepo.getBudgetsWithSpent();
    final wallets = await _walletRepo.getWallets();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentTx = allTx.where((tx) => tx.date.isAfter(thirtyDaysAgo)).toList();

    final totalIncome = recentTx.where((tx) => tx.type == 'income').fold(0.0, (s, tx) => s + tx.amount);
    final totalExpense = recentTx.where((tx) => tx.type == 'expense').fold(0.0, (s, tx) => s + tx.amount);
    final totalBalance = wallets.fold(0.0, (s, w) => s + w.balance);

    final List<HealthScoreMetric> metrics = [];
    final List<String> recommendations = [];

    // Tiêu chí 1: Tỷ lệ tiết kiệm (Max 25đ)
    int savingsScore = 15;
    String savingsDetail = 'Thu chi tương đương';
    if (totalIncome > 0) {
      final rate = ((totalIncome - totalExpense) / totalIncome) * 100;
      if (rate >= 20) {
        savingsScore = 25;
        savingsDetail = 'Tiết kiệm ${rate.toStringAsFixed(0)}% thu nhập (Rất tốt)';
      } else if (rate >= 10) {
        savingsScore = 18;
        savingsDetail = 'Tiết kiệm ${rate.toStringAsFixed(0)}% thu nhập (Khá)';
        recommendations.add('Nâng tỷ lệ tiết kiệm lên mức chuẩn 20% thu nhập hàng tháng.');
      } else if (rate > 0) {
        savingsScore = 12;
        savingsDetail = 'Tiết kiệm ${rate.toStringAsFixed(0)}% thu nhập (Thấp)';
        recommendations.add('Cắt giảm bớt các chi phí không cần thiết để tạo khoản tích lũy.');
      } else {
        savingsScore = 5;
        savingsDetail = 'Bội chi (Chi vượt thu)';
        recommendations.add('Báo động: Đang chi tiêu vượt thu nhập! Cần rà soát ngay các khoản chi lớn.');
      }
    }
    metrics.add(HealthScoreMetric(
      name: 'Tỷ lệ tiết kiệm',
      score: savingsScore,
      maxScore: 25,
      status: savingsScore >= 20 ? 'excellent' : (savingsScore >= 15 ? 'good' : 'warning'),
      detail: savingsDetail,
    ));

    // Tiêu chí 2: Tuân thủ ngân sách (Max 25đ)
    int budgetScore = 25;
    String budgetDetail = 'Đang duy trì ngân sách an toàn';
    if (budgets.isNotEmpty) {
      int exceededCount = 0;
      for (final b in budgets) {
        if (b.isOverBudget) exceededCount++;
      }
      if (exceededCount == 0) {
        budgetScore = 25;
        budgetDetail = 'Tuân thủ tốt 100% ngân sách đã đặt';
      } else if (exceededCount == 1) {
        budgetScore = 15;
        budgetDetail = 'Có 1 ngân sách bị bội chi';
        recommendations.add('Điều chỉnh lại định mức chi tiêu cho danh mục đang vượt hạn mức.');
      } else {
        budgetScore = 8;
        budgetDetail = 'Có $exceededCount ngân sách bị vượt';
        recommendations.add('Cần thiết lập lại ngân sách chi tiêu thực tế hơn để tránh bội chi.');
      }
    } else {
      budgetScore = 18;
      budgetDetail = 'Chưa thiết lập ngân sách chi tiêu';
      recommendations.add('Hãy tạo hạn mức ngân sách tháng để kiểm soát chi tiêu chủ động hơn.');
    }
    metrics.add(HealthScoreMetric(
      name: 'Kỷ luật ngân sách',
      score: budgetScore,
      maxScore: 25,
      status: budgetScore >= 20 ? 'excellent' : (budgetScore >= 15 ? 'good' : 'warning'),
      detail: budgetDetail,
    ));

    // Tiêu chí 3: Tần suất ghi chép đều đặn (Max 20đ)
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    final distinctDays = allTx
        .where((tx) => tx.date.isAfter(fourteenDaysAgo))
        .map((tx) => '${tx.date.year}-${tx.date.month}-${tx.date.day}')
        .toSet()
        .length;
    int consistencyScore = 10;
    String consistencyDetail = 'Ghi chép chưa đều ($distinctDays/14 ngày)';
    if (distinctDays >= 10) {
      consistencyScore = 20;
      consistencyDetail = 'Ghi chép đều đặn ($distinctDays/14 ngày)';
    } else if (distinctDays >= 6) {
      consistencyScore = 15;
      consistencyDetail = 'Ghi chép khá tốt ($distinctDays/14 ngày)';
    } else {
      consistencyScore = 8;
      consistencyDetail = 'Ghi chép gián đoạn ($distinctDays/14 ngày)';
      recommendations.add('Tập thói quen mở Mono ghi lại ngay mỗi khi phát sinh chi tiêu.');
    }
    metrics.add(HealthScoreMetric(
      name: 'Thói quen ghi chép',
      score: consistencyScore,
      maxScore: 20,
      status: consistencyScore >= 18 ? 'excellent' : (consistencyScore >= 14 ? 'good' : 'warning'),
      detail: consistencyDetail,
    ));

    // Tiêu chí 4: Quỹ dự phòng khẩn cấp (Max 15đ)
    int emergencyScore = 10;
    String emergencyDetail = 'Đang tích lũy quỹ dự phòng';
    final monthlyExpense = totalExpense > 0 ? totalExpense : 3000000.0;
    final monthsCoverage = totalBalance / monthlyExpense;
    if (monthsCoverage >= 3) {
      emergencyScore = 15;
      emergencyDetail = 'Đủ chi trả ${monthsCoverage.toStringAsFixed(1)} tháng (An toàn)';
    } else if (monthsCoverage >= 1) {
      emergencyScore = 11;
      emergencyDetail = 'Đủ chi trả ${monthsCoverage.toStringAsFixed(1)} tháng (Khá)';
      recommendations.add('Tích lũy thêm quỹ khẩn cấp để đạt mục tiêu bảo đảm 3-6 tháng sinh hoạt.');
    } else {
      emergencyScore = 5;
      emergencyDetail = 'Dưới 1 tháng sinh hoạt (Thấp)';
      recommendations.add('Ưu tiên xây dựng quỹ khẩn cấp tối thiểu 1 tháng chi tiêu phòng rủi ro.');
    }
    metrics.add(HealthScoreMetric(
      name: 'Dự phòng rủi ro',
      score: emergencyScore,
      maxScore: 15,
      status: emergencyScore >= 14 ? 'excellent' : (emergencyScore >= 10 ? 'good' : 'poor'),
      detail: emergencyDetail,
    ));

    // Tiêu chí 5: Cân đối cấu trúc chi tiêu (Max 15đ)
    int balanceScore = 15;
    String balanceDetail = 'Phân bổ danh mục đồng đều';
    final Map<String, double> catMap = {};
    for (final tx in recentTx.where((tx) => tx.type == 'expense')) {
      catMap[tx.category] = (catMap[tx.category] ?? 0.0) + tx.amount;
    }
    if (totalExpense > 0 && catMap.isNotEmpty) {
      final maxCatAmount = catMap.values.reduce((a, b) => a > b ? a : b);
      final maxCatRatio = maxCatAmount / totalExpense;
      if (maxCatRatio > 0.65) {
        balanceScore = 8;
        balanceDetail = 'Chi quá tập trung vào một nhóm (>65%)';
        recommendations.add('Đa dạng hóa và cân nhắc các khoản chi cho danh mục chiếm tỷ trọng lớn.');
      } else {
        balanceScore = 15;
        balanceDetail = 'Phân bổ danh mục chi tiêu hợp lý';
      }
    }
    metrics.add(HealthScoreMetric(
      name: 'Cân đối cơ cấu chi',
      score: balanceScore,
      maxScore: 15,
      status: balanceScore >= 12 ? 'excellent' : 'warning',
      detail: balanceDetail,
    ));

    final totalScore = metrics.fold(0, (s, m) => s + m.score);

    String rating = 'Tốt';
    Color statusColor = Colors.green;
    String summaryAdvice = '';

    if (totalScore >= 85) {
      rating = 'Xuất sắc';
      statusColor = const Color(0xFF10B981);
      summaryAdvice = '🌟 Chúc mừng! Bạn đang quản lý tài chính rất khoa học và có kỷ luật xuất sắc. Hãy tiếp tục duy trì đà này!';
    } else if (totalScore >= 70) {
      rating = 'Tốt';
      statusColor = const Color(0xFF3B82F6);
      summaryAdvice = '👍 Sức khỏe tài chính của bạn ở mức tốt! Cải thiện thêm vài điểm khuyến nghị để đạt mức xuất sắc nhé.';
    } else if (totalScore >= 50) {
      rating = 'Cần cải thiện';
      statusColor = const Color(0xFFF59E0B);
      summaryAdvice = '⚠️ Tài chính của bạn đang ở mức trung bình. Hãy chú ý kiểm soát ngân sách và xây dựng quỹ dự phòng.';
    } else {
      rating = 'Báo động';
      statusColor = const Color(0xFFEF4444);
      summaryAdvice = '🚨 Báo động: Bạn đang gặp rủi ro tài chính cao (bội chi hoặc cạn quỹ dự phòng). Cần rà soát và cắt giảm ngay!';
    }

    return FinancialHealthScoreResult(
      overallScore: totalScore,
      rating: rating,
      statusColor: statusColor,
      metrics: metrics,
      recommendations: recommendations,
      summaryAdvice: summaryAdvice,
    );
  }

  /// ════════════════════════════════════════════════════════════════════════════
  /// 8. PHÁT HIỆN GIAO DỊCH ĐỊNH KỲ (Recurring Transaction Detection)
  /// ════════════════════════════════════════════════════════════════════════════
  Future<RecurringDetectionResult> detectRecurringTransactions() async {
    final allTx = await _txRepo.getAllTransactions();
    final now = DateTime.now();
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final expenseTx = allTx
        .where((tx) => tx.type == 'expense' && tx.date.isAfter(ninetyDaysAgo))
        .toList();

    final Map<String, List<TransactionModel>> grouped = {};
    for (final tx in expenseTx) {
      final desc = tx.description.toLowerCase().trim();
      final key = '${tx.category}_$desc';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final List<RecurringTransactionItem> items = [];

    grouped.forEach((key, txList) {
      if (txList.length >= 2) {
        txList.sort((a, b) => a.date.compareTo(b.date));
        final intervals = <int>[];
        for (int i = 1; i < txList.length; i++) {
          intervals.add(txList[i].date.difference(txList[i - 1].date).inDays);
        }
        final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
        final avgAmount = txList.fold(0.0, (s, tx) => s + tx.amount) / txList.length;

        String frequency = '';
        if (avgInterval >= 20 && avgInterval <= 40) {
          frequency = 'Hàng tháng';
        } else if (avgInterval >= 5 && avgInterval <= 10) {
          frequency = 'Hàng tuần';
        }

        final lastTx = txList.last;
        final isFixedExpenseKeyword = lastTx.category == 'Tiền nhà' ||
            lastTx.category == 'Tiền điện' ||
            lastTx.category == 'Điện thoại' ||
            lastTx.description.toLowerCase().contains('tiền phòng') ||
            lastTx.description.toLowerCase().contains('tiền trọ') ||
            lastTx.description.toLowerCase().contains('internet') ||
            lastTx.description.toLowerCase().contains('netflix') ||
            lastTx.description.toLowerCase().contains('spotify') ||
            lastTx.description.toLowerCase().contains('gym');

        if (frequency.isNotEmpty || isFixedExpenseKeyword) {
          final freq = frequency.isNotEmpty ? frequency : 'Hàng tháng';
          final daysToAdd = freq == 'Hàng tháng' ? 30 : 7;
          final nextEst = lastTx.date.add(Duration(days: daysToAdd));

          items.add(RecurringTransactionItem(
            title: lastTx.description.isNotEmpty ? lastTx.description : lastTx.category,
            category: lastTx.category,
            amount: avgAmount,
            frequency: freq,
            occurrences: txList.length,
            nextEstimatedDate: nextEst,
          ));
        }
      }
    });

    double totalMonthlyFixed = 0.0;
    for (final item in items) {
      if (item.frequency == 'Hàng tháng') {
        totalMonthlyFixed += item.amount;
      } else {
        totalMonthlyFixed += item.amount * 4.33;
      }
    }

    final summary = items.isNotEmpty
        ? 'Mono đã phát hiện **${items.length} khoản chi định kỳ** với tổng ước tính **${CurrencyUtils.formatCurrency(totalMonthlyFixed)}/tháng**.'
        : 'Chưa phát hiện khoản chi lặp lại định kỳ rõ ràng trong 90 ngày qua.';

    return RecurringDetectionResult(
      items: items,
      totalMonthlyFixedCost: totalMonthlyFixed,
      summary: summary,
    );
  }
}
