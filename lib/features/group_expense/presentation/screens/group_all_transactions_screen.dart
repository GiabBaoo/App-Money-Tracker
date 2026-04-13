import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Cho phép bottom sheet mở rộng theo nội dung
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch sử hoạt động',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.groupName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Month Picker Header
            GestureDetector(
              onTap: _showMonthPicker,
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Tháng ${_selectedDate.month.toString().padLeft(2, '0')} / ${_selectedDate.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: fundTransactionsAsync.when(
                  data: (transactions) {
                    // Filter transactions by selected month and year
                    final filteredTransactions = transactions.where((tx) => 
                      tx.createdAt.month == _selectedDate.month && 
                      tx.createdAt.year == _selectedDate.year
                    ).toList();

                    if (filteredTransactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 60,
                              color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có hoạt động nào trong tháng ${_selectedDate.month}/${_selectedDate.year}',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
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

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final date = sortedDates[dateIndex];
                        final dayTransactions = groupedTransactions[date]!;
                        
                        // Format date header
                        final now = DateTime.now();
                        final todayKey = DateTime(now.year, now.month, now.day);
                        final yesterdayKey = todayKey.subtract(const Duration(days: 1));
                        
                        String dateHeader = '${date.day}/${date.month}/${date.year}';
                        if (date == todayKey) {
                          dateHeader = 'Hôm nay - $dateHeader';
                        } else if (date == yesterdayKey) {
                          dateHeader = 'Hôm qua - $dateHeader';
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                dateHeader,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                            
                            // Transactions for this date
                            ...dayTransactions.map((transaction) {
                              final isContribute = transaction.type == TransactionType.contribute;
                              final color = isContribute ? Colors.green : Colors.red;
                              
                              return GestureDetector(
                                onTap: () {
                                  _showTransactionDetail(context, transaction, isDark);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.1),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isContribute ? Icons.add_rounded : Icons.arrow_downward_rounded,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isContribute ? 'Góp quỹ' : 'Rút quỹ',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              transaction.userName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white60 : Colors.black54,
                                              ),
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
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${transaction.createdAt.hour}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Text('Lỗi: $error'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showTransactionDetail(BuildContext context, FundTransactionModel transaction, bool isDark) {
    final isContribute = transaction.type == TransactionType.contribute;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isContribute ? 'Chi tiết góp quỹ' : 'Chi tiết rút quỹ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Người thực hiện:', transaction.userName, isDark),
            const SizedBox(height: 12),
            _buildDetailRow('Số tiền:', '${_formatMoney(transaction.amount)}đ', isDark),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Thời gian:', 
              '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} ${transaction.createdAt.hour}:${transaction.createdAt.minute.toString().padLeft(2, '0')}',
              isDark,
            ),
            if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow('Ghi chú:', transaction.notes!, isDark),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
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
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lọc theo thời gian',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedYear--),
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Year $_selectedYear',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF438883),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedYear++),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = month == _selectedMonth;
                
                return GestureDetector(
                  onTap: () {
                    widget.onDateSelected(DateTime(_selectedYear, month));
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF438883) 
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F5F5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Tháng $month',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? Colors.white 
                            : (widget.isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                final now = DateTime.now();
                widget.onDateSelected(DateTime(now.year, now.month));
                Navigator.pop(context);
              },
              child: const Text(
                'Trở về hôm nay',
                style: TextStyle(
                  color: Color(0xFF438883),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
