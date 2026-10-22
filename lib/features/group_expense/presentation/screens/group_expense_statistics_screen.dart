import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../providers/group_expense_providers.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/fund_transaction_model.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/currency_format_utils.dart';

// Helper function để format tiền
String _formatMoney(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
}

class GroupExpenseStatisticsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final int initialTab; // 0 = Chi phí, 1 = Thu nhập

  const GroupExpenseStatisticsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialTab = 0,
  });

  @override
  ConsumerState<GroupExpenseStatisticsScreen> createState() => _GroupExpenseStatisticsScreenState();
}

class _GroupExpenseStatisticsScreenState extends ConsumerState<GroupExpenseStatisticsScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  int touchedIndex = -1;
  late int selectedTab; // Sẽ khởi tạo từ initialTab

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId));
    final fundTransactionsAsync = ref.watch(groupFundTransactionsProvider(widget.groupId));

    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;
    final expenses = expensesAsync.asData?.value ?? [];
    final transactions = fundTransactionsAsync.asData?.value ?? [];
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (var tx in transactions) {
      if (tx.type == TransactionType.contribute) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    for (var e in expenses) {
      totalExpense += e.amount;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar - Premium Glassmorphism Redesign
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: Center(
              child: AnimatedScaleButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final isCollapsed = constraints.maxHeight <= kToolbarHeight + (MediaQuery.of(context).padding.top);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isCollapsed ? 1.0 : 0.0,
                    child: Text(
                      isVi ? 'Thống kê - ${widget.groupName}' : 'Statistics - ${widget.groupName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      const Color(0xFF2C5E5A),
                      const Color(0xFF142B28),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + 20),
                    // TOP: Premium Summary Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildHeaderSummaryItem(
                              isVi ? 'Tổng thu' : 'Total Income',
                              totalIncome,
                              Icons.arrow_circle_down_rounded,
                              context.income,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildHeaderSummaryItem(
                              isVi ? 'Tổng chi' : 'Total Expense',
                              totalExpense,
                              Icons.arrow_circle_up_rounded,
                              context.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // BOTTOM: Page Title & Group Name
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVi ? 'Thống kê chi tiết' : 'Detailed Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                          ),
                          child: Text(
                            widget.groupName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),

          // Content Panel
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  
                  // Toggle Control - Re-engineered for Pixel-Perfect Alignment
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final innerPadding = 6.0;
                        final indicatorWidth = (width - (innerPadding * 2)) / 2;
                        
                        return Container(
                          height: 58,
                          padding: EdgeInsets.all(innerPadding),
                          decoration: BoxDecoration(
                            color: context.inputBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.borderColor,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Background Indicator with smarter positioning
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.fastOutSlowIn,
                                left: selectedTab == 0 ? 0 : indicatorWidth,
                                top: 0,
                                bottom: 0,
                                width: indicatorWidth,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        primaryColor,
                                        primaryColor.withValues(alpha: 0.85),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Foreground Items
                              Row(
                                children: [
                                  _buildToggleItem(context, isVi ? 'Chi phí' : 'Expense', 0, Icons.arrow_circle_up_rounded, isDark),
                                  _buildToggleItem(context, isVi ? 'Thu nhập' : 'Income', 1, Icons.arrow_circle_down_rounded, isDark),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Statistics Charts & Lists
                  expensesAsync.when(
                    data: (expenses) => fundTransactionsAsync.when(
                      data: (transactions) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: selectedTab == 0
                              ? _buildExpensesTab(expenses, transactions, isDark)
                              : _buildIncomeTab(transactions, isDark),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('${isVi ? 'Lỗi' : 'Error'}: $error')),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('${isVi ? 'Lỗi' : 'Error'}: $error')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummaryItem(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatMoney(amount)}đ',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(BuildContext context, String label, int tabIndex, IconData icon, bool isDark) {
    final isSelected = selectedTab == tabIndex;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selectedTab = tabIndex);
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesTab(List<ExpenseModel> expenses, List<FundTransactionModel> transactions, bool isDark) {
    // Collect all expenses from ExpenseModel
    final Map<String, double> categorySums = {};
    double totalSum = 0;
    
    for (var expense in expenses) {
      categorySums[expense.category] = (categorySums[expense.category] ?? 0) + expense.amount;
      totalSum += expense.amount;
    }

    // ADD withdrawals to expenses
    // Group withdrawals BY USER to match Income tab consistency
    final withdrawals = transactions.where((tx) => tx.type == TransactionType.withdraw).toList();
    for (var tx in withdrawals) {
      final key = isVi ? "Rút quỹ - ${tx.userName}" : "Withdrawal - ${tx.userName}";
      categorySums[key] = (categorySums[key] ?? 0) + tx.amount;
      totalSum += tx.amount;
    }

    if (totalSum == 0) {
      return _buildEmptyState(isDark, isVi ? 'chi phí' : 'expenses');
    }

    final List<PieChartSectionData> sections = [];
    final categories = categorySums.keys.toList();
    
    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final amount = categorySums[category]!;
      final percentage = (amount / totalSum) * 100;
      final isTouched = i == touchedIndex;
      
      // Use dynamic color based on index or category
      final color = category.startsWith('Rút quỹ') || category.startsWith('Góp quỹ')
          ? Colors.primaries[i % Colors.primaries.length]
          : CategoryUtils.getVibrantColor(category);

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: percentage > 8 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: isTouched ? 65.0 : 55.0,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          borderSide: BorderSide(color: isDark ? const Color(0xFF000000) : Colors.white, width: 2),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildChartSection(sections, totalSum, 'chi', isDark),
          _buildCategoryList(transactions, isDark, false),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildIncomeTab(List<FundTransactionModel> transactions, bool isDark) {
    // ONLY contributions for income
    final contributions = transactions.where((tx) => tx.type == TransactionType.contribute).toList();
    
    if (contributions.isEmpty) {
      return _buildEmptyState(isDark, isVi ? 'thu nhập/góp quỹ' : 'income/contributions');
    }

    final Map<String, double> groupedData = {};
    double totalSum = 0;
    
    for (var tx in contributions) {
      final key = isVi ? "Góp quỹ - ${tx.userName}" : "Contribution - ${tx.userName}";
      groupedData[key] = (groupedData[key] ?? 0) + tx.amount;
      totalSum += tx.amount;
    }

    final List<PieChartSectionData> sections = [];
    final keys = groupedData.keys.toList();

    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final amount = groupedData[key]!;
      final percentage = (amount / totalSum) * 100;
      final isTouched = i == touchedIndex;
      
      final color = Colors.primaries[i % Colors.primaries.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: percentage > 8 ? '${percentage.toStringAsFixed(1)}%' : '',
          radius: isTouched ? 65.0 : 55.0,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          borderSide: BorderSide(color: isDark ? const Color(0xFF000000) : Colors.white, width: 2),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildChartSection(sections, totalSum, 'thu', isDark),
          _buildCategoryList(transactions, isDark, true),
          const SizedBox(height: 30),
        ],
      ),
    );
  }


  Widget _buildChartSection(List<PieChartSectionData> sections, double total, String label, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 30),
        SizedBox(
          height: 250,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 0,
                    centerSpaceRadius: 75,
                    sections: sections,
                    startDegreeOffset: -90,
                  ),
                  duration: const Duration(milliseconds: 600),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isVi ? "Tổng" : "Total"} ${selectedTab == 0 ? (isVi ? "chi" : "expense") : (isVi ? "thu" : "income")}',
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyUtils.formatCurrency(total).replaceAll(' ₫', '').replaceAll('đ', '')}đ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: context.colors.onSurface,
                      ),
                    ),
                    Text(
                      isVi ? 'VNĐ' : 'VND',
                      style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 11, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildCategoryList(List<FundTransactionModel> transactions, bool isDark, bool isIncome) {
    // Filter transactions based on current tab (Income or Expense)
    final filteredTransactions = transactions.where((tx) => 
      isIncome ? tx.type == TransactionType.contribute : tx.type == TransactionType.withdraw
    ).toList();
    
    // Sort by date (newest first)
    filteredTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              isVi ? 'CHI TIẾT HOẠT ĐỘNG' : 'ACTIVITY DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...filteredTransactions.map((tx) {
            final color = tx.type == TransactionType.contribute ? context.income : context.expense;
            final icon = tx.type == TransactionType.contribute ? Icons.person_add_rounded : Icons.person_remove_rounded;
            final timeStr = '${tx.createdAt.day}/${tx.createdAt.month} • ${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor, width: 1),
                boxShadow: [
                  if (!isDark) BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx.type == TransactionType.contribute ? (isVi ? 'Đã góp quỹ' : 'Contributed') : (isVi ? 'Đã rút quỹ' : 'Withdrawn'),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${tx.type == TransactionType.contribute ? '+' : '-'}${_formatMoney(tx.amount)}đ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(isVi ? 'Không có $type nào' : 'No $type recorded', style: TextStyle(color: context.colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
