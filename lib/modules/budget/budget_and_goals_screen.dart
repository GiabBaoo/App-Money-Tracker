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
import 'add_budget_dialog.dart';
import 'add_goal_dialog.dart';

class BudgetAndGoalsScreen extends StatefulWidget {
  final int initialTabIndex;

  const BudgetAndGoalsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<BudgetAndGoalsScreen> createState() => _BudgetAndGoalsScreenState();
}

class _BudgetAndGoalsScreenState extends State<BudgetAndGoalsScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? const Color(0xFF0F2625) : const Color(0xFF438883);

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
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  const Text(
                    'Ngân Sách & Mục Tiêu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
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
                        border: Border.all(color: Colors.white24, width: 0.8),
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
                  color: Colors.black.withValues(alpha: 0.15),
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
                            color: _tabController.index == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _tabController.index == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
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
                                color: _tabController.index == 0 ? const Color(0xFF438883) : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ngân Sách Chi',
                                style: TextStyle(
                                  color: _tabController.index == 0 ? const Color(0xFF438883) : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
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
                            color: _tabController.index == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _tabController.index == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
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
                                color: _tabController.index == 1 ? const Color(0xFF438883) : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mục Tiêu Tích Lũy',
                                style: TextStyle(
                                  color: _tabController.index == 1 ? const Color(0xFF438883) : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
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
                    colors: [Color(0xFF438883), Color(0xFF2E635F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF438883).withValues(alpha: 0.35),
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
                      _tabController.index == 0 ? 'Thêm Ngân Sách Mới' : 'Tạo Mục Tiêu Mới',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
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
                          const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Tháng $_selectedMonth, $_selectedYear',
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(overallProgress * 100).toStringAsFixed(0)}% đã dùng',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyUtils.formatCurrency(totalLimit),
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 9,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallProgress >= 1.0
                            ? const Color(0xFFEF4444)
                            : (overallProgress >= 0.8 ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đã chi: ${CurrencyUtils.formatCurrency(totalSpent)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Còn lại: ${CurrencyUtils.formatCurrency(overallRemaining >= 0 ? overallRemaining : 0)}',
                        style: TextStyle(
                          color: overallRemaining < 0 ? const Color(0xFFFCA5A5) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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
                const Text(
                  'Hạn mức theo danh mục',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${budgets.length} danh mục',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
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

    Color statusColor = const Color(0xFF10B981);
    if (isOver) {
      statusColor = const Color(0xFFEF4444);
    } else if (isNear) {
      statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver
            ? (isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF1E2827) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: isOver ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOver
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: statusColor.withValues(alpha: 0.15),
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
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                            isOver ? 'VƯỢT ${(progress * 100).toStringAsFixed(0)}%' : '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
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
                      'Hạn mức: ${CurrencyUtils.formatCurrency(budget.limitAmount)}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
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
                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
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
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã tiêu: ${CurrencyUtils.formatCurrency(budget.currentSpent)}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              Text(
                isOver
                    ? 'Vượt ${CurrencyUtils.formatCurrency(budget.currentSpent - budget.limitAmount)}'
                    : 'Còn ${CurrencyUtils.formatCurrency(budget.remainingAmount)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isOver ? const Color(0xFFEF4444) : statusColor,
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
        color: isDark ? const Color(0xFF1E2827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('Chưa có ngân sách nào trong tháng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Hãy đặt hạn mức cho các khoản ăn uống, mua sắm để chi tiêu kỷ luật và tối ưu dòng tiền hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
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
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('Chưa có mục tiêu tài chính nào', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(
                    'Đặt mục tiêu như mua xe máy, đi du lịch hoặc quỹ khẩn cấp để có thêm động lực tiết kiệm mỗi ngày!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
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
    final goalColor = goal.color;
    final daysLeft = goal.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCompleted ? Colors.green.withValues(alpha: 0.5) : goalColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  color: goalColor.withValues(alpha: 0.15),
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
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isCompleted ? Colors.green : goalColor).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCompleted ? 'HOÀN THÀNH 🎉' : '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isCompleted ? Colors.green : goalColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hạn chót: ${DateFormat('dd/MM/yyyy').format(goal.deadline)} • ${daysLeft > 0 ? "$daysLeft ngày nữa" : "Đã đến hạn"}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
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
                  const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                  const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: goalColor),
              ),
              Text(
                'Mục tiêu: ${CurrencyUtils.formatCurrency(goal.targetAmount)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : goalColor),
            ),
          ),

          const SizedBox(height: 12),

          // Gợi ý tiết kiệm
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.tips_and_updates_outlined,
                  size: 16,
                  color: isCompleted ? Colors.green : Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCompleted
                        ? '🎉 Chúc mừng bạn đã hoàn thành mục tiêu này!'
                        : 'Cần tích lũy ~${CurrencyUtils.formatCurrency(goal.recommendedDailySavings)}/ngày để kịp hạn',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
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
