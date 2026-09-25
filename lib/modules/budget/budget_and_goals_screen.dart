import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../models/goal_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../utils/currency_format_utils.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ngân Sách & Mục Tiêu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Ngân Sách Chi Tiêu'),
            Tab(text: 'Mục Tiêu Tích Lũy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBudgetTab(isDark, primaryColor),
          _buildGoalsTab(isDark, primaryColor),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Thêm Ngân Sách' : 'Tạo Mục Tiêu',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddBudgetDialog();
          } else {
            _showAddGoalDialog();
          }
        },
      ),
    );
  }

  // ════════ TAB 1: NGÂN SÁCH CHI TIÊU ════════

  Widget _buildBudgetTab(bool isDark, Color primaryColor) {
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Thẻ tổng quan ngân sách tháng
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1B3330), const Color(0xFF122422)]
                      : [const Color(0xFF438883), const Color(0xFF2E6561)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng ngân sách tháng $_selectedMonth/$_selectedYear',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(overallProgress * 100).toStringAsFixed(0)}% đã dùng',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyUtils.formatCurrency(totalLimit),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overallProgress >= 1.0 ? Colors.redAccent : (overallProgress >= 0.8 ? Colors.amberAccent : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đã chi: ${CurrencyUtils.formatCurrency(totalSpent)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Còn lại: ${CurrencyUtils.formatCurrency(overallRemaining >= 0 ? overallRemaining : 0)}',
                        style: TextStyle(
                          color: overallRemaining < 0 ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hạn mức theo danh mục',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showAddBudgetDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (budgets.isEmpty)
              _buildEmptyBudgets(isDark)
            else
              ...budgets.map((b) => _buildBudgetItem(b, isDark, primaryColor)),
          ],
        );
      },
    );
  }

  Widget _buildBudgetItem(BudgetModel budget, bool isDark, Color primaryColor) {
    final progress = budget.progressPercentage;
    final isOver = budget.isOverBudget;
    final isNear = budget.isNearLimit;

    Color statusColor = const Color(0xFF10B981); // Green
    if (isOver) {
      statusColor = const Color(0xFFEF4444); // Red
    } else if (isNear) {
      statusColor = const Color(0xFFF59E0B); // Amber
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver
            ? (isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
        borderRadius: BorderRadius.circular(16),
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
                : Colors.black.withValues(alpha: 0.03),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(budget.icon, color: statusColor, size: 20),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(6),
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
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
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

          const SizedBox(height: 12),

          // Progress bar hiện đại
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('Chưa có ngân sách nào trong tháng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Hãy đặt hạn mức cho các khoản ăn uống, mua sắm để chi tiêu kỷ luật hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddBudgetDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thiết lập ngân sách ngay'),
          ),
        ],
      ),
    );
  }

  // ════════ TAB 2: MỤC TIÊU TÀI CHÍNH TÍCH LŨY ════════

  Widget _buildGoalsTab(bool isDark, Color primaryColor) {
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
                  const Text('Chưa có mục tiêu tài chính nào', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Đặt mục tiêu như mua xe máy, đi du lịch hoặc quỹ khẩn cấp để có thêm động lực tiết kiệm mỗi ngày!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddGoalDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tạo mục tiêu đầu tiên'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? Colors.green.withValues(alpha: 0.5) : goalColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: goalColor.withValues(alpha: 0.15),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isCompleted ? Colors.green : goalColor).withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(6),
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
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: goalColor),
              ),
              Text(
                'Mục tiêu: ${CurrencyUtils.formatCurrency(goal.targetAmount)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
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
              borderRadius: BorderRadius.circular(10),
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
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Nút Nạp tiền / Rút tiền
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDepositDialog(goal, isDeposit: true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nạp tiền'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goalColor,
                    side: BorderSide(color: goalColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDepositDialog(goal, isDeposit: false),
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('Rút tiền'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  void _showDepositDialog(GoalModel goal, {required bool isDeposit}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Nạp tiền vào mục tiêu' : 'Rút tiền từ mục tiêu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mục tiêu: ${goal.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập số tiền...',
                suffixText: 'đ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final clean = controller.text.replaceAll(RegExp(r'[^\d]'), '');
              final amount = double.tryParse(clean) ?? 0.0;
              if (amount <= 0) return;

              if (isDeposit) {
                await _goalRepo.depositToGoal(goal.id, amount);
                if (mounted) TopToast.show(context, 'Đã nạp ${CurrencyUtils.formatCurrency(amount)} vào mục tiêu!');
              } else {
                await _goalRepo.withdrawFromGoal(goal.id, amount);
                if (mounted) TopToast.show(context, 'Đã rút ${CurrencyUtils.formatCurrency(amount)}!');
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isDeposit ? 'Nạp tiền' : 'Rút tiền'),
          ),
        ],
      ),
    );
  }
}
