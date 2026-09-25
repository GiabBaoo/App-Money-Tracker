import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/transaction_item.dart';
import '../transaction/add_transaction_screen.dart';

class CalendarTrackingScreen extends StatefulWidget {
  const CalendarTrackingScreen({super.key});

  @override
  State<CalendarTrackingScreen> createState() => _CalendarTrackingScreenState();
}

class _CalendarTrackingScreenState extends State<CalendarTrackingScreen> {
  final TransactionRepository _txRepo = TransactionRepository();
  final WalletRepository _walletRepo = WalletRepository();

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      _txRepo.setUid(uid);
    }
    _walletRepo.getWallets();
  }

  void _onPrevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _onNextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Lịch Theo Dõi Thu Chi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF0F2625) : primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _txRepo.getTransactionsStream(),
        initialData: _txRepo.latestTransactions.isNotEmpty ? _txRepo.latestTransactions : null,
        builder: (context, snapshot) {
          final allTx = snapshot.data ?? [];

          // Giao dịch trong tháng đang xem
          final monthTx = allTx.where((tx) =>
            tx.date.year == _focusedMonth.year &&
            tx.date.month == _focusedMonth.month
          ).toList();

          double monthIncome = 0;
          double monthExpense = 0;
          for (var tx in monthTx) {
            if (tx.isTransfer) continue;
            if (tx.type == 'income') {
              monthIncome += tx.amount;
            } else {
              monthExpense += tx.amount;
            }
          }

          // Giao dịch trong ngày được chọn
          final dayTx = monthTx.where((tx) =>
            tx.date.year == _selectedDate.year &&
            tx.date.month == _selectedDate.month &&
            tx.date.day == _selectedDate.day
          ).toList();

          double dayIncome = 0;
          double dayExpense = 0;
          for (var tx in dayTx) {
            if (tx.isTransfer) continue;
            if (tx.type == 'income') {
              dayIncome += tx.amount;
            } else {
              dayExpense += tx.amount;
            }
          }

          return Column(
            children: [
              // Thanh điều hướng tháng & Ribbon tổng quan
              _buildMonthHeader(isDark, primaryColor, monthIncome, monthExpense),

              // Bảng lịch
              _buildCalendarGrid(monthTx, isDark, primaryColor),

              const Divider(height: 1),

              // Thẻ tóm tắt ngày đang chọn
              _buildSelectedDayHeader(isDark, primaryColor, dayIncome, dayExpense),

              // Danh sách giao dịch của ngày đang chọn
              Builder(
                builder: (context) {
                  final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                    allTransactions: allTx,
                    wallets: _walletRepo.latestWallets,
                  );
                  return Expanded(
                    child: dayTx.isEmpty
                        ? _buildEmptyDay(isDark, primaryColor)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: dayTx.length,
                            itemBuilder: (context, index) {
                              final tx = dayTx[index];
                              WalletModel? txWallet;
                              try {
                                txWallet = _walletRepo.latestWallets.firstWhere((w) => w.id == tx.walletId);
                              } catch (_) {}
                              return TransactionItem(
                                transaction: tx,
                                showDate: false,
                                runningTotal: reverseBalances[tx.id],
                                wallet: txWallet,
                              );
                            },
                          ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader(bool isDark, Color primaryColor, double income, double expense) {
    final monthStr = 'Tháng ${_focusedMonth.month}/${_focusedMonth.year}';
    final net = income - expense;

    return Container(
      color: isDark ? const Color(0xFF1B2E2B) : const Color(0xFFE8F3F1),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: primaryColor, size: 28),
                onPressed: _onPrevMonth,
              ),
              Text(
                monthStr,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : primaryColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: primaryColor, size: 28),
                onPressed: _onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ribbon tổng quan tháng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryPill('Thu nhập', income, const Color(0xFF10B981), isDark),
              _buildSummaryPill('Chi tiêu', expense, const Color(0xFFEF4444), isDark),
              _buildSummaryPill('Chênh lệch', net, net >= 0 ? const Color(0xFF0EA5E9) : Colors.orange, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String label, double amount, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(List<TransactionModel> monthTx, bool isDark, Color primaryColor) {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 (Mon) to 7 (Sun)
    final offset = firstWeekday - 1; // 0 for Monday

    final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    // Map ngày -> các giao dịch trong ngày
    final Map<int, List<TransactionModel>> dayTxMap = {};
    for (var tx in monthTx) {
      dayTxMap.putIfAbsent(tx.date.day, () => []).add(tx);
    }

    final now = DateTime.now();
    final isCurrentMonth = now.year == _focusedMonth.year && now.month == _focusedMonth.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Hàng tiêu đề thứ
          Row(
            children: weekDays.map((d) {
              final isWeekend = d == 'T7' || d == 'CN';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isWeekend ? Colors.orange : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // Lưới các ngày
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 tuần x 7 ngày
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final dayNum = index - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }

              final isSelected = _selectedDate.year == _focusedMonth.year &&
                  _selectedDate.month == _focusedMonth.month &&
                  _selectedDate.day == dayNum;
              final isToday = isCurrentMonth && now.day == dayNum;

              final txList = dayTxMap[dayNum] ?? [];
              final hasIncome = txList.any((t) => t.type == 'income' && !t.isTransfer);
              final hasExpense = txList.any((t) => t.type == 'expense' && !t.isTransfer);
              final hasTransfer = txList.any((t) => t.isTransfer);

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : (isToday
                            ? primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(color: primaryColor, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Dấu chấm xanh (thu), đỏ (chi), lam (chuyển ví)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasIncome)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasExpense)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.8) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasTransfer)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF0284C7),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDayHeader(DateTime date) {
    try {
      final dayFormat = DateFormat('EEEE, dd/MM/yyyy', 'vi');
      final formatted = dayFormat.format(date);
      return formatted[0].toUpperCase() + formatted.substring(1);
    } catch (_) {
      const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
      final dayName = weekdays[date.weekday - 1];
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      return '$dayName, $d/$m/${date.year}';
    }
  }

  Widget _buildSelectedDayHeader(bool isDark, Color primaryColor, double dayIncome, double dayExpense) {
    final formattedDate = _formatDayHeader(_selectedDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (dayIncome > 0) ...[
                      Text(
                        '+${CurrencyUtils.formatCurrency(dayIncome)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (dayExpense > 0) ...[
                      Text(
                        '-${CurrencyUtils.formatCurrency(dayExpense)}',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Nút thêm giao dịch cho ngày được chọn
          AnimatedScaleButton(
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.slideUp(
                  AddTransactionScreen(initialDate: _selectedDate),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Thêm giao dịch',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay(bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Không có giao dịch ngày ${_selectedDate.day}/${_selectedDate.month}',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                PageTransitions.slideUp(
                  AddTransactionScreen(initialDate: _selectedDate),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Ghi chép giao dịch ngay'),
          ),
        ],
      ),
    );
  }
}
