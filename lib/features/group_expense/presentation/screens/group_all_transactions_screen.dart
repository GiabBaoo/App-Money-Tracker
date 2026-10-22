import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_dialog.dart';
import '../../../../widgets/mono_bottom_sheet.dart';
import '../providers/group_expense_providers.dart';
import '../../data/models/fund_transaction_model.dart';

// Helper function để format tiền
String _formatMoney(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
}

class GroupAllTransactionsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupAllTransactionsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupAllTransactionsScreen> createState() => _GroupAllTransactionsScreenState();
}

class _GroupAllTransactionsScreenState extends ConsumerState<GroupAllTransactionsScreen> {
  DateTime _selectedDate = DateTime.now();

  void _showMonthPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    MonoBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MonthPickerSheet(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
          });
        },
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fundTransactionsAsync = ref.watch(groupFundTransactionsProvider(widget.groupId));
    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;

    // Design Tokens
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBgColor = context.cardBg;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── ERGONOMIC TOP APP BAR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
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
                        shape: BoxShape.circle,
                        color: cardBgColor,
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Lịch Sử Hoạt Động' : 'Transaction History',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          widget.groupName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Month filter trigger button
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showMonthPicker();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'T${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── MAIN CONTENT ───
            Expanded(
              child: fundTransactionsAsync.when(
                data: (transactions) {
                  // Filter by month & year
                  final filteredTransactions = transactions.where((tx) =>
                    tx.createdAt.month == _selectedDate.month &&
                    tx.createdAt.year == _selectedDate.year
                  ).toList();

                  // Compute monthly totals
                  double monthInflow = 0;
                  double monthOutflow = 0;
                  for (var tx in filteredTransactions) {
                    if (tx.type == TransactionType.contribute) {
                      monthInflow += tx.amount;
                    } else {
                      monthOutflow += tx.amount;
                    }
                  }

                  // Group transactions by date
                  final Map<DateTime, List<FundTransactionModel>> groupedTransactions = {};
                  for (final transaction in filteredTransactions) {
                    final dateKey = DateTime(
                      transaction.createdAt.year,
                      transaction.createdAt.month,
                      transaction.createdAt.day,
                    );
                    if (!groupedTransactions.containsKey(dateKey)) {
                      groupedTransactions[dateKey] = [];
                    }
                    groupedTransactions[dateKey]!.add(transaction);
                  }

                  // Sort dates in descending order
                  final sortedDates = groupedTransactions.keys.toList()
                    ..sort((a, b) => b.compareTo(a));

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Monthly Summary Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      const Color(0xFF1E293B),
                                      const Color(0xFF16202E),
                                    ]
                                  : [
                                      primaryColor,
                                      Color.lerp(primaryColor, Colors.black, 0.12) ?? primaryColor,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.black : primaryColor).withValues(alpha: 0.22),
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
                                  Text(
                                    isVi
                                        ? 'TỔNG KẾT THÁNG ${_selectedDate.month}/${_selectedDate.year}'
                                        : 'MONTHLY SUMMARY ${_selectedDate.month}/${_selectedDate.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    '${filteredTransactions.length} ${isVi ? 'hoạt động' : 'records'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  // Inflow
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi ? 'Tổng góp quỹ' : 'Total Contributed',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '+${_formatMoney(monthInflow)}đ',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: context.income,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 32,
                                    width: 1,
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(width: 16),
                                  // Outflow
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi ? 'Tổng chi/rút quỹ' : 'Total Withdrawn',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '-${_formatMoney(monthOutflow)}đ',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: context.expense,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 2. Transactions or Empty State
                        if (filteredTransactions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: textSecondary.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isVi
                                      ? 'Không có hoạt động nào trong tháng ${_selectedDate.month}/${_selectedDate.year}'
                                      : 'No activity in ${_selectedDate.month}/${_selectedDate.year}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...sortedDates.map((date) {
                            final dayTransactions = groupedTransactions[date]!;
                            final now = DateTime.now();
                            final todayKey = DateTime(now.year, now.month, now.day);
                            final yesterdayKey = todayKey.subtract(const Duration(days: 1));

                            String dateHeader = '${date.day}/${date.month}/${date.year}';
                            if (date == todayKey) {
                              dateHeader = '${isVi ? 'Hôm nay' : 'Today'} • $dateHeader';
                            } else if (date == yesterdayKey) {
                              dateHeader = '${isVi ? 'Hôm qua' : 'Yesterday'} • $dateHeader';
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: context.inputBgColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          dateHeader,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...dayTransactions.map((transaction) {
                                  final isContribute = transaction.type == TransactionType.contribute;
                                  final color = isContribute ? context.income : context.expense;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: borderColor, width: 1),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showTransactionDetail(context, transaction, isDark),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isContribute ? Icons.add_rounded : Icons.arrow_outward_rounded,
                                                  color: color,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      isContribute ? (isVi ? 'Góp quỹ' : 'Contribution') : (isVi ? 'Rút quỹ' : 'Withdrawal'),
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      transaction.userName,
                                                      style: TextStyle(fontSize: 12, color: textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${isContribute ? '+' : '-'}${_formatMoney(transaction.amount)}đ',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: color,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${transaction.createdAt.hour}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                error: (error, _) => Center(child: Text('${isVi ? 'Lỗi' : 'Error'}: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, FundTransactionModel transaction, bool isDark) {
    final isContribute = transaction.type == TransactionType.contribute;
    final color = isContribute ? context.income : context.expense;

    MonoDialog.show(
      context,
      title: isContribute ? (isVi ? 'Chi tiết góp quỹ' : 'Contribution Details') : (isVi ? 'Chi tiết rút quỹ' : 'Withdrawal Details'),
      icon: isContribute ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
      iconColor: color,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(context, isVi ? 'Người thực hiện:' : 'By:', transaction.userName),
          const SizedBox(height: 12),
          _buildDetailRow(context, isVi ? 'Số tiền:' : 'Amount:', '${_formatMoney(transaction.amount)}đ'),
          const SizedBox(height: 12),
          _buildDetailRow(
            context,
            isVi ? 'Thời gian:' : 'Time:',
            '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} ${transaction.createdAt.hour}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(context, isVi ? 'Ghi chú:' : 'Notes:', transaction.notes!),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.inputBgColor,
            foregroundColor: context.colors.onSurface,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(isVi ? 'Đóng' : 'Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;
  final bool isDark;

  const _MonthPickerSheet({
    required this.initialDate,
    required this.onDateSelected,
    required this.isDark,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = context.cardBg;
    final textP = context.colors.onSurface;
    final textS = context.colors.onSurfaceVariant;
    final primaryColor = context.colors.primary;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textS.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isVi ? 'Lọc Theo Thời Gian' : 'Filter by Month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textP,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _selectedYear--),
                    icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: textP),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isVi ? 'Năm $_selectedYear' : 'Year $_selectedYear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _selectedYear++),
                    icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: textP),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == _selectedMonth;
                  final now = DateTime.now();
                  final isFuture = (_selectedYear > now.year) || (_selectedYear == now.year && month > now.month);

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            widget.onDateSelected(DateTime(_selectedYear, month));
                            Navigator.pop(context);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : isFuture
                                ? (widget.isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100)
                                : context.inputBgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isVi ? 'Tháng $month' : 'Month $month',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : isFuture
                                  ? textS.withValues(alpha: 0.4)
                                  : textP,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  final now = DateTime.now();
                  widget.onDateSelected(DateTime(now.year, now.month));
                  Navigator.pop(context);
                },
                child: Text(
                  isVi ? 'Trở về tháng hiện tại' : 'Back to current month',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
