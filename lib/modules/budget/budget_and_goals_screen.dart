import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/budget_model.dart';
import '../../models/goal_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/top_toast.dart';
import '../../services/category_style_service.dart';
import 'add_budget_dialog.dart';
import 'add_goal_dialog.dart';
import '../../services/language_service.dart';
import '../../core/theme/app_theme.dart';

class BudgetAndGoalsScreen extends StatefulWidget {
  final int initialTabIndex;

  const BudgetAndGoalsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<BudgetAndGoalsScreen> createState() => _BudgetAndGoalsScreenState();
}

class _BudgetAndGoalsScreenState extends State<BudgetAndGoalsScreen> with SingleTickerProviderStateMixin {
  bool get isVi => LanguageService.instance.isVietnamese;
  late TabController _tabController;
  final BudgetRepository _budgetRepo = BudgetRepository();
  final GoalRepository _goalRepo = GoalRepository();

  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    CategoryStyleService.instance.addListener(_onCategoryStyleChanged);
  }

  void _onCategoryStyleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CategoryStyleService.instance.removeListener(_onCategoryStyleChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddBudgetDialog(),
    );
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (_) => const AddGoalDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isVi = LanguageScope.of(context).isVietnamese;
    final headerColor = isDark ? AppColors.primaryTealDark : AppColors.primaryTeal;

    return Scaffold(
      backgroundColor: headerColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── 1. TOP APP BAR FINTECH GLASSMORPHISM ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  Text(
                    isVi ? 'Ngân Sách & Mục Tiêu' : 'Budgets & Goals',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: isDark ? const Color(0xFFF8FAFC) : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      shadows: isDark
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_tabController.index == 0) {
                        _showAddBudgetDialog();
                      } else {
                        _showAddGoalDialog();
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 0.8),
                      ),
                      child: const Icon(Icons.add_rounded, size: 24, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ─── 2. LIQUID SEGMENTED TAB SWITCHER ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _tabController.animateTo(0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tabController.index == 0
                                ? (isDark ? context.colors.surface : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: _tabController.index == 0 && isDark
                                ? Border.all(color: context.colors.outline.withValues(alpha: 0.25), width: 1)
                                : null,
                            boxShadow: _tabController.index == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pie_chart_rounded,
                                size: 17,
                                color: _tabController.index == 0
                                    ? (isDark ? AppColors.primaryTealVibrant : context.colors.primary)
                                    : Colors.white.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi ? 'Ngân Sách Chi' : 'Expense Budgets',
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: _tabController.index == 0
                                      ? (isDark ? AppColors.primaryTealVibrant : context.colors.primary)
                                      : Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _tabController.animateTo(1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _tabController.index == 1
                                ? (isDark ? context.colors.surface : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: _tabController.index == 1 && isDark
                                ? Border.all(color: context.colors.outline.withValues(alpha: 0.25), width: 1)
                                : null,
                            boxShadow: _tabController.index == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.savings_rounded,
                                size: 17,
                                color: _tabController.index == 1
                                    ? (isDark ? AppColors.primaryTealVibrant : context.colors.primary)
                                    : Colors.white.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi ? 'Mục Tiêu Tích Lũy' : 'Savings Goals',
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: _tabController.index == 1
                                      ? (isDark ? AppColors.primaryTealVibrant : context.colors.primary)
                                      : Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── 3. BODY SHEET VỚI SQUIRCLE BORDER ───
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBudgetTab(isDark),
                    _buildGoalsTab(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating Bottom Action Button (Thumb Zone)
      bottomNavigationBar: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: AnimatedScaleButton(
              onTap: () {
                HapticFeedback.lightImpact();
                if (_tabController.index == 0) {
                  _showAddBudgetDialog();
                } else {
                  _showAddGoalDialog();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabController.index == 0 ? Icons.add_chart_rounded : Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _tabController.index == 0 
                          ? (isVi ? 'Thêm Ngân Sách Mới' : 'Add New Budget') 
                          : (isVi ? 'Tạo Mục Tiêu Mới' : 'Create New Goal'),
                      style: context.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════ TAB 1: NGÂN SÁCH CHI TIÊU ════════
  Widget _buildBudgetTab(bool isDark) {
    return StreamBuilder<List<BudgetModel>>(
      stream: _budgetRepo.getBudgetsStream(month: _selectedMonth, year: _selectedYear),
      builder: (context, snapshot) {
        final budgets = snapshot.data ?? [];

        double totalLimit = 0;
        double totalSpent = 0;
        for (var b in budgets) {
          totalLimit += b.limitAmount;
          totalSpent += b.currentSpent;
        }
        final overallProgress = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
        final overallRemaining = totalLimit - totalSpent;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            // Thẻ tổng quan ngân sách tháng
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B3835), const Color(0xFF102523)]
                      : [const Color(0xFF438883), const Color(0xFF2E6561)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: isDark
                    ? Border.all(color: context.colors.outline.withValues(alpha: 0.3), width: 1.2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF438883).withValues(alpha: isDark ? 0.3 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Colors.white.withValues(alpha: 0.75), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            isVi ? 'Tháng $_selectedMonth, $_selectedYear' : 'Month $_selectedMonth, $_selectedYear',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isVi ? '${(overallProgress * 100).toStringAsFixed(0)}% đã dùng' : '${(overallProgress * 100).toStringAsFixed(0)}% used',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyUtils.formatCurrency(totalLimit),
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 9,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallProgress >= 1.0
                            ? AppColors.expenseCoral
                            : (overallProgress >= 0.8 ? AppColors.warningAmber : (isDark ? AppColors.primaryTealVibrant : AppColors.incomeGreen)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVi ? 'Đã chi: ${CurrencyUtils.formatCurrency(totalSpent)}' : 'Spent: ${CurrencyUtils.formatCurrency(totalSpent)}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isVi 
                            ? 'Còn lại: ${CurrencyUtils.formatCurrency(overallRemaining >= 0 ? overallRemaining : 0)}'
                            : 'Remaining: ${CurrencyUtils.formatCurrency(overallRemaining >= 0 ? overallRemaining : 0)}',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: overallRemaining < 0 ? AppColors.expenseRoseLight : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi ? 'Hạn mức theo danh mục' : 'Category Limits',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.onSurface,
                  ),
                ),
                Text(
                  isVi ? '${budgets.length} danh mục' : '${budgets.length} categories',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (budgets.isEmpty)
              _buildEmptyBudgets(isDark)
            else
              ...budgets.map((b) => _buildBudgetItem(b, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildBudgetItem(BudgetModel budget, bool isDark) {
    final progress = budget.progressPercentage;
    final isOver = budget.isOverBudget;
    final isNear = budget.isNearLimit;

    Color statusColor = isDark ? AppColors.incomeEmeraldLight : context.income;
    if (isOver) {
      statusColor = isDark ? AppColors.expenseRoseLight : context.expense;
    } else if (isNear) {
      statusColor = isDark ? AppColors.warningAmberLight : context.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver
            ? (isDark ? AppColors.expenseBgDark.withValues(alpha: 0.35) : context.expenseBg)
            : (isDark ? context.colors.surface : context.cardBg),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver
              ? (isDark ? AppColors.expenseRoseLight.withValues(alpha: 0.6) : context.expense.withValues(alpha: 0.6))
              : (isDark ? context.colors.outline.withValues(alpha: 0.25) : context.borderColor),
          width: isOver ? 1.5 : 1.2,
        ),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(budget.icon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            budget.category,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOver 
                                ? (LanguageScope.of(context).isVietnamese ? 'VƯỢT ${(progress * 100).toStringAsFixed(0)}%' : 'OVER ${(progress * 100).toStringAsFixed(0)}%')
                                : '${(progress * 100).toStringAsFixed(0)}%',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LanguageScope.of(context).isVietnamese ? 'Hạn mức: ${CurrencyUtils.formatCurrency(budget.limitAmount)}' : 'Limit: ${CurrencyUtils.formatCurrency(budget.limitAmount)}',
                      style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: context.colors.onSurfaceVariant),
                onSelected: (val) {
                  if (val == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => AddBudgetDialog(existingBudget: budget),
                    );
                  } else if (val == 'delete') {
                    _budgetRepo.deleteBudget(budget.id, month: budget.month, year: budget.year);
                    TopToast.show(context, 'Đã xóa ngân sách');
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(LanguageScope.of(context).isVietnamese ? 'Chỉnh sửa' : 'Edit', style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurface))),
                  PopupMenuItem(value: 'delete', child: Text(LanguageScope.of(context).isVietnamese ? 'Xóa' : 'Delete', style: context.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.expenseRoseLight : context.expense))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? AppColors.borderDark : context.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LanguageScope.of(context).isVietnamese ? 'Đã tiêu: ${CurrencyUtils.formatCurrency(budget.currentSpent)}' : 'Spent: ${CurrencyUtils.formatCurrency(budget.currentSpent)}',
                style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              Text(
                isOver
                    ? (LanguageScope.of(context).isVietnamese ? 'Vượt ${CurrencyUtils.formatCurrency(budget.currentSpent - budget.limitAmount)}' : 'Over ${CurrencyUtils.formatCurrency(budget.currentSpent - budget.limitAmount)}')
                    : (LanguageScope.of(context).isVietnamese ? 'Còn ${CurrencyUtils.formatCurrency(budget.remainingAmount)}' : 'Remaining ${CurrencyUtils.formatCurrency(budget.remainingAmount)}'),
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isOver ? (isDark ? AppColors.expenseRoseLight : context.expense) : statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudgets(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? context.colors.outline.withValues(alpha: 0.25) : context.borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 56, color: context.colors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            LanguageScope.of(context).isVietnamese ? 'Chưa có ngân sách nào trong tháng' : 'No budgets set for this month',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LanguageScope.of(context).isVietnamese
                ? 'Hãy đặt hạn mức cho các khoản ăn uống, mua sắm để chi tiêu kỷ luật và tối ưu dòng tiền hơn.'
                : 'Set spending limits for dining, shopping, etc., to stay disciplined and optimize cash flow.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ════════ TAB 2: MỤC TIÊU TÀI CHÍNH TÍCH LŨY ════════
  Widget _buildGoalsTab(bool isDark) {
    return StreamBuilder<List<GoalModel>>(
      stream: _goalRepo.getGoalsStream(),
      builder: (context, snapshot) {
        final goals = snapshot.data ?? [];

        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: context.colors.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    LanguageScope.of(context).isVietnamese ? 'Chưa có mục tiêu tài chính nào' : 'No financial goals yet',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LanguageScope.of(context).isVietnamese
                        ? 'Đặt mục tiêu như mua xe máy, đi du lịch hoặc quỹ khẩn cấp để có thêm động lực tiết kiệm mỗi ngày!'
                        : 'Set goals like buying a bike, travel, or an emergency fund to motivate daily savings!',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            return _buildGoalCard(goals[index], isDark);
          },
        );
      },
    );
  }

  Widget _buildGoalCard(GoalModel goal, bool isDark) {
    final progress = goal.progress;
    final isCompleted = goal.isCompleted;
    final baseGoalColor = goal.color;
    final goalColor = isDark && baseGoalColor == AppColors.primaryTeal 
        ? AppColors.primaryTealVibrant 
        : baseGoalColor;
    final daysLeft = goal.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted
              ? (isDark ? AppColors.incomeEmeraldLight.withValues(alpha: 0.5) : context.income.withValues(alpha: 0.5))
              : (isDark ? context.colors.outline.withValues(alpha: 0.25) : goalColor.withValues(alpha: 0.35)),
          width: 1.2,
        ),
        boxShadow: AppShadows.card(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: goalColor.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(goal.icon, color: goalColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            goal.title,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isCompleted ? context.income : goalColor).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompleted 
                                ? (LanguageScope.of(context).isVietnamese ? 'HOÀN THÀNH 🎉' : 'COMPLETED 🎉')
                                : '${(progress * 100).toStringAsFixed(0)}%',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? (isDark ? AppColors.incomeEmeraldLight : context.income) : goalColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LanguageScope.of(context).isVietnamese
                          ? 'Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.deadline)} • ${daysLeft > 0 ? "$daysLeft ngày nữa" : "Đã đến hạn"}'
                          : 'Deadline: ${DateFormat('dd/MM/yyyy').format(goal.deadline)} • ${daysLeft > 0 ? "$daysLeft days left" : "Due today"}',
                      style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: context.colors.onSurfaceVariant),
                onSelected: (val) {
                  if (val == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => AddGoalDialog(existingGoal: goal),
                    );
                  } else if (val == 'delete') {
                    _goalRepo.deleteGoal(goal.id);
                    TopToast.show(context, 'Đã xóa mục tiêu');
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(LanguageScope.of(context).isVietnamese ? 'Chỉnh sửa' : 'Edit', style: context.textTheme.bodyMedium?.copyWith(color: context.colors.onSurface))),
                  PopupMenuItem(value: 'delete', child: Text(LanguageScope.of(context).isVietnamese ? 'Xóa' : 'Delete', style: context.textTheme.bodyMedium?.copyWith(color: isDark ? AppColors.expenseRoseLight : context.expense))),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Số tiền & tiến độ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyUtils.formatCurrency(goal.currentAmount),
                style: context.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: goalColor),
              ),
              Text(
                LanguageScope.of(context).isVietnamese ? 'Mục tiêu: ${CurrencyUtils.formatCurrency(goal.targetAmount)}' : 'Target: ${CurrencyUtils.formatCurrency(goal.targetAmount)}',
                style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: isDark ? AppColors.borderDark : context.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? (isDark ? AppColors.incomeEmeraldLight : context.income) : goalColor),
            ),
          ),

          const SizedBox(height: 12),

          // Gợi ý tiết kiệm
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : context.inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: context.colors.outline.withValues(alpha: 0.2)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.tips_and_updates_outlined,
                  size: 16,
                  color: isCompleted ? (isDark ? AppColors.incomeEmeraldLight : context.income) : (isDark ? AppColors.warningAmberLight : context.warning),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCompleted
                        ? (LanguageScope.of(context).isVietnamese ? '🎉 Chúc mừng bạn đã hoàn thành mục tiêu này!' : '🎉 Congratulations on achieving this goal!')
                        : (LanguageScope.of(context).isVietnamese
                            ? 'Cần tích lũy ~${CurrencyUtils.formatCurrency(goal.recommendedDailySavings)}/ngày để kịp hạn'
                            : 'Save ~${CurrencyUtils.formatCurrency(goal.recommendedDailySavings)}/day to meet your goal'),
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
