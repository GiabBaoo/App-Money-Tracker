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

  const PersonalSpendingQueryResult({
    required this.queryText,
    required this.totalAmount,
    required this.transactionCount,
    required this.periodDescription,
    this.categoryFilter,
    required this.relevantTransactions,
    required this.answerText,
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

    if (lower.contains('hôm nay') || lower.contains('hom nay')) {
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
    } else if (lower.contains('tháng trước') || lower.contains('thang truoc')) {
      startDate = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0);
      endDate = DateTime(lastDayPrevMonth.year, lastDayPrevMonth.month, lastDayPrevMonth.day, 23, 59, 59);
      periodText = 'tháng trước';
    } else {
      // Mặc định tháng này
      startDate = DateTime(now.year, now.month, 1);
      periodText = 'tháng này';
    }

    final allTx = await _txRepo.getAllTransactions();

    // Lọc theo khoảng thời gian
    var filtered = allTx.where((tx) {
      return tx.date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          tx.date.isBefore(endDate.add(const Duration(seconds: 1)));
    }).toList();

    // Lọc theo danh mục nếu người dùng có hỏi danh mục cụ thể (Ăn uống, Grab, Mua sắm...)
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

    // Nếu hỏi khoản chi lớn nhất
    if (lower.contains('lớn nhất') || lower.contains('nhất') || lower.contains('cao nhất')) {
      final expenseOnly = filtered.where((tx) => tx.type == 'expense').toList();
      expenseOnly.sort((a, b) => b.amount.compareTo(a.amount));
      if (expenseOnly.isNotEmpty) {
        final top = expenseOnly.first;
        final answer = '🔍 Khoản chi lớn nhất của bạn $periodText là **${CurrencyUtils.formatCurrency(top.amount)}** cho "${top.description}" ([${top.category}]) vào ngày ${top.date.day}/${top.date.month}.';
        return PersonalSpendingQueryResult(
          queryText: query,
          totalAmount: top.amount,
          transactionCount: 1,
          periodDescription: periodText,
          categoryFilter: categoryFilter,
          relevantTransactions: [top],
          answerText: answer,
        );
      }
    }

    final totalAmount = filtered.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);
    final count = filtered.length;

    final catText = categoryFilter != null ? 'cho danh mục **$categoryFilter** ' : '';
    final answerText = '📊 $periodText, bạn đã chi tổng cộng **${CurrencyUtils.formatCurrency(totalAmount)}** $catText(gồm **$count giao dịch**).';

    return PersonalSpendingQueryResult(
      queryText: query,
      totalAmount: totalAmount,
      transactionCount: count,
      periodDescription: periodText,
      categoryFilter: categoryFilter,
      relevantTransactions: filtered.take(5).toList(),
      answerText: answerText,
    );
  }
}
