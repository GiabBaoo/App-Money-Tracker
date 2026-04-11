import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
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
    final balanceAsync = ref.watch(groupBalanceProvider(widget.groupId));
    final groupAsync = ref.watch(groupStreamProvider(widget.groupId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with high header design
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Thống kê - ${widget.groupName}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.insights_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),

          // Content Panel
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  
                  // Toggle Control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildToggleItem('Chi phí', 0, isDark),
                          _buildToggleItem('Thu nhập', 1, isDark),
                        ],
                      ),
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
                      error: (error, _) => Center(child: Text('Lỗi: $error')),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Lỗi: $error')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ số dư giống trang Detail để đồng bộ
  Widget _buildSyncBalanceCard(BuildContext context, String groupName, double income, double expense, bool isDark) {
    final balance = income - expense;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF438883),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Số dư quỹ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${_formatMoney(balance)}đ', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thu nhập', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${_formatMoney(income)}đ', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chi phí', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${_formatMoney(expense)}đ', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, int tabIndex, bool isDark) {
    bool isSelected = selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF438883) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
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
      final key = "Rút quỹ - ${tx.userName}";
      categorySums[key] = (categorySums[key] ?? 0) + tx.amount;
      totalSum += tx.amount;
    }

    if (totalSum == 0) {
      return _buildEmptyState(isDark, 'chi phí');
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
      return _buildEmptyState(isDark, 'thu nhập/góp quỹ');
    }

    final Map<String, double> groupedData = {};
    double totalSum = 0;
    
    for (var tx in contributions) {
      final key = "Góp quỹ - ${tx.userName}";
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
                  swapAnimationDuration: const Duration(milliseconds: 600),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tổng ${selectedTab == 0 ? 'chi' : 'thu'}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyUtils.formatCurrency(total).replaceAll(' ₫', '').replaceAll('đ', '')}đ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'VNĐ',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1),
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
              'CHI TIẾT HOẠT ĐỘNG',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...filteredTransactions.map((tx) {
            final color = tx.type == TransactionType.contribute ? Colors.greenAccent : Colors.redAccent;
            final icon = tx.type == TransactionType.contribute ? Icons.person_add_rounded : Icons.person_remove_rounded;
            final timeStr = '${tx.createdAt.day}/${tx.createdAt.month} • ${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark) BoxShadow(
                    color: Colors.black.withOpacity(0.03),
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
                      color: color.withOpacity(0.1),
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
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx.type == TransactionType.contribute ? 'Đã góp quỹ' : 'Đã rút quỹ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
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
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildItemCard(String title, double amount, double percentage, Color color, IconData icon, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E2F2E).withOpacity(0.5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      Text('${(percentage * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState(bool isDark, String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Không có $type nào', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
        ],
      ),
    );
  }
}
