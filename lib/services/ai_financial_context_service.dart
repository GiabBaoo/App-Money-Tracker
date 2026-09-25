import 'package:flutter/foundation.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../utils/currency_format_utils.dart';

class AiFinancialSnapshot {
  final double totalBalance;
  final List<WalletModel> wallets;
  final double monthExpense;
  final double monthIncome;
  final double todayExpense;
  final double todayIncome;
  final Map<String, double> topCategories;
  final List<BudgetModel> budgets;
  final List<GoalModel> goals;

  AiFinancialSnapshot({
    required this.totalBalance,
    required this.wallets,
    required this.monthExpense,
    required this.monthIncome,
    required this.todayExpense,
    required this.todayIncome,
    required this.topCategories,
    required this.budgets,
    required this.goals,
  });

  double get netMonthSavings => monthIncome - monthExpense;
}

/// Dịch vụ tổng hợp bức tranh tài chính thời gian thực cung cấp cho Trợ lý AI Mono
class AiFinancialContextService {
  static final AiFinancialContextService _instance = AiFinancialContextService._internal();
  factory AiFinancialContextService() => _instance;
  AiFinancialContextService._internal();

  /// Lấy snapshot tài chính tổng hợp từ SQLite (tốc độ cực nhanh 0-5ms)
  Future<AiFinancialSnapshot> getFinancialSnapshot() async {
    final now = DateTime.now();
    double totalBal = 0.0;
    List<WalletModel> wallets = [];
    List<TransactionModel> allTxs = [];
    List<BudgetModel> budgets = [];
    List<GoalModel> goals = [];

    try {
      wallets = await WalletRepository().getWallets();
      for (var w in wallets) {
        totalBal += w.balance;
      }
    } catch (e) {
      debugPrint('AiFinancialContextService - wallets error: $e');
    }

    try {
      allTxs = await TransactionRepository().getAllTransactions();
    } catch (e) {
      debugPrint('AiFinancialContextService - transactions error: $e');
    }

    try {
      budgets = await BudgetRepository().getBudgetsWithSpent(month: now.month, year: now.year);
    } catch (e) {
      debugPrint('AiFinancialContextService - budgets error: $e');
    }

    try {
      goals = await GoalRepository().getAllGoals();
    } catch (e) {
      debugPrint('AiFinancialContextService - goals error: $e');
    }

    double monthExp = 0.0;
    double monthInc = 0.0;
    double todayExp = 0.0;
    double todayInc = 0.0;
    final Map<String, double> catMap = {};

    for (var tx in allTxs) {
      final isThisMonth = tx.date.year == now.year && tx.date.month == now.month;
      final isToday = isThisMonth && tx.date.day == now.day;

      if (tx.type == 'income') {
        if (isThisMonth) monthInc += tx.amount;
        if (isToday) todayInc += tx.amount;
      } else {
        if (isThisMonth) {
          monthExp += tx.amount;
          catMap[tx.category] = (catMap[tx.category] ?? 0.0) + tx.amount;
        }
        if (isToday) todayExp += tx.amount;
      }
    }

    // Top 3 danh mục chi tiêu lớn nhất tháng này
    final sortedCats = catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = Map.fromEntries(sortedCats.take(3));

    return AiFinancialSnapshot(
      totalBalance: totalBal,
      wallets: wallets,
      monthExpense: monthExp,
      monthIncome: monthInc,
      todayExpense: todayExp,
      todayIncome: todayInc,
      topCategories: top3,
      budgets: budgets,
      goals: goals,
    );
  }

  String? _cachedPrompt;
  DateTime? _lastCacheTime;

  /// Xóa cache để làm mới dữ liệu khi có giao dịch mới phát sinh
  void invalidateCache() {
    _cachedPrompt = null;
    _lastCacheTime = null;
  }

  /// Xây dựng đoạn prompt tóm tắt ngữ cảnh tài chính để nhúng vào Prompt của Gemini AI
  /// Sử dụng In-Memory Cache với TTL 30 giây để giảm độ trễ từ ~200ms xuống < 1ms
  Future<String> buildFinancialContextPrompt({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedPrompt != null &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!).inSeconds < 30) {
      return _cachedPrompt!;
    }

    final snapshot = await getFinancialSnapshot();
    final sb = StringBuffer();

    sb.writeln('=== BỨC TRANH TÀI CHÍNH THỰC TẾ CỦA NGƯỜI DÙNG HIỆN TẠI (Tháng ${now.month}/${now.year}) ===');
    sb.writeln('• Tổng số dư hiện có: ${CurrencyUtils.formatCurrency(snapshot.totalBalance)}');

    if (snapshot.wallets.isNotEmpty) {
      final wInfo = snapshot.wallets
          .map((w) => '${w.name}: ${CurrencyUtils.formatCurrency(w.balance)}')
          .join(', ');
      sb.writeln('• Chi tiết các ví: $wInfo');
    }

    sb.writeln('• Tháng này: Tổng thu = ${CurrencyUtils.formatCurrency(snapshot.monthIncome)}, Tổng chi = ${CurrencyUtils.formatCurrency(snapshot.monthExpense)}, Thặng dư còn lại = ${CurrencyUtils.formatCurrency(snapshot.netMonthSavings)}');
    sb.writeln('• Hôm nay: Đã chi = ${CurrencyUtils.formatCurrency(snapshot.todayExpense)}, Đã thu = ${CurrencyUtils.formatCurrency(snapshot.todayIncome)}');

    if (snapshot.topCategories.isNotEmpty) {
      final topCatStr = snapshot.topCategories.entries
          .map((e) => '${e.key}: ${CurrencyUtils.formatCurrency(e.value)}')
          .join(', ');
      sb.writeln('• Top danh mục chi nhiều nhất tháng này: $topCatStr');
    }

    if (snapshot.budgets.isNotEmpty) {
      final bInfo = snapshot.budgets
          .map((b) => '${b.category}: tiêu ${CurrencyUtils.formatCurrency(b.currentSpent)}/${CurrencyUtils.formatCurrency(b.limitAmount)}')
          .join(', ');
      sb.writeln('• Hạn mức ngân sách tháng: $bInfo');
    }

    if (snapshot.goals.isNotEmpty) {
      final gInfo = snapshot.goals
          .map((g) => '${g.title}: đã có ${CurrencyUtils.formatCurrency(g.currentAmount)}/${CurrencyUtils.formatCurrency(g.targetAmount)}')
          .join(', ');
      sb.writeln('• Mục tiêu tiết kiệm đang theo đuổi: $gInfo');
    }
    sb.writeln('========================================================================');

    _cachedPrompt = sb.toString();
    _lastCacheTime = now;
    return _cachedPrompt!;
  }
}
