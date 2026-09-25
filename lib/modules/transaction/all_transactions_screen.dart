import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/colored_amount_text.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/animated_scale_button.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../utils/page_transitions.dart';
import '../calendar/calendar_tracking_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final TransactionRepository _txRepo = TransactionRepository();
  final WalletRepository _walletRepo = WalletRepository();
  String _selectedType = 'Tất cả';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _txRepo.setUid(uid);
      _walletRepo.setUid(uid);
    }
    _walletRepo.getWallets();
    // Mặc định lọc tháng hiện tại theo yêu cầu
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'Tất cả';
      _selectedDateRange = null; // Khi reset hoàn toàn thì cho xem tất cả hoặc tùy ý
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // HEADER & FILTER ICON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20),
                      ),
                    ),
                    const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(context, PageTransitions.slideRight(const CalendarTrackingScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, size: 22, color: Color(0xFF438883)),
                          ),
                        ),
                        AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showFilterBottomSheet(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_selectedType != 'Tất cả' || _selectedDateRange != null)
                                  ? const Color(0xFF438883).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              size: 24,
                              color: (_selectedType != 'Tất cả' || _selectedDateRange != null)
                                  ? const Color(0xFF438883)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // CHIP HIỂN THỊ BỘ LỌC ĐANG CHỌN (NẾU CÓ)
            if (_selectedType != 'Tất cả' || _selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedType != 'Tất cả')
                        _buildFilterChip(_selectedType, () => setState(() => _selectedType = 'Tất cả')),
                      if (_selectedDateRange != null)
                        _buildFilterChip(
                          '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}',
                          () => setState(() => _selectedDateRange = null),
                        ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Xóa tất cả', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // DANH SÁCH GIAO DỊCH REALTIME VỚI BỘ LỌC
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: _txRepo.getTransactionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                  }

                  // 1. ÁP DỤNG BỘ LỌC
                  List<TransactionModel> transactions = snapshot.data ?? [];
                  
                  // LỌC THỨ TỰ (Tie-breaker cho các giao dịch cùng ngày bằng time và createdAt)
                  transactions.sort((a, b) {
                    DateTime dateA = DateTime(a.date.year, a.date.month, a.date.day);
                    DateTime dateB = DateTime(b.date.year, b.date.month, b.date.day);
                    int dateComp = dateB.compareTo(dateA);
                    if (dateComp != 0) return dateComp;
                    int timeComp = b.time.compareTo(a.time);
                    if (timeComp != 0) return timeComp;
                    return b.createdAt.compareTo(a.createdAt);
                  });
                  
                  // Lọc theo loại hình
                  if (_selectedType == 'Thu nhập') {
                    transactions = transactions.where((tx) => tx.isIncome && !tx.isTransfer).toList();
                  } else if (_selectedType == 'Chi tiêu') {
                    transactions = transactions.where((tx) => !tx.isIncome && !tx.isTransfer).toList();
                  } else if (_selectedType == 'Chuyển ví') {
                    transactions = transactions.where((tx) => tx.isTransfer).toList();
                  }
                  
                  // Lọc theo thời gian
                  if (_selectedDateRange != null) {
                    transactions = transactions.where((tx) {
                      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
                      return !txDate.isBefore(_selectedDateRange!.start) && 
                             !txDate.isAfter(_selectedDateRange!.end);
                    }).toList();
                  }

                  if (transactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 60, color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('Không tìm thấy giao dịch nào', style: TextStyle(color: Colors.grey.withValues(alpha: 0.6), fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  // 2. NHÓM GIAO DỊCH THEO NGÀY
                  final allTx = snapshot.data ?? [];
                  final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                    allTransactions: allTx,
                    wallets: _walletRepo.latestWallets,
                  );
                  final grouped = _groupByDate(transactions);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...grouped.entries.expand((entry) => [
                          _buildDateHeader(entry.key, entry.value),
                          ...entry.value.asMap().entries.map((txEntry) {
                                WalletModel? txWallet;
                                try {
                                  txWallet = _walletRepo.latestWallets.firstWhere((w) => w.id == txEntry.value.walletId);
                                } catch (_) {}
                                return StaggeredListItem(
                                  index: txEntry.key,
                                  child: TransactionItem(
                                    transaction: txEntry.value,
                                    showDate: false, // Vì đã có Header ngày rồi
                                    runningTotal: reverseBalances[txEntry.value.id],
                                    wallet: txWallet,
                                  ),
                                );
                              }),
                          const SizedBox(height: 16),
                        ]),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        onDeleted: onDeleted,
        deleteIcon: const Icon(Icons.close, size: 14),
        backgroundColor: const Color(0xFF438883).withValues(alpha: 0.1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // BỘ LỌC BOTTOM SHEET
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bộ lọc giao dịch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // LỌC THEO LOẠI HÌNH
                  const Text('Loại giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Tất cả', 'Thu nhập', 'Chi tiêu', 'Chuyển ví'].map((tp) {
                      final isSelected = _selectedType == tp;
                      return Expanded(
                        child: AnimatedScaleButton(
                          scaleDown: 0.95,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => _selectedType = tp);
                            setState(() {}); // Cập nhật màn hình chính
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF438883) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF438883) : Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                tp,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // LỌC THEO THỜI GIAN
                  const Text('Thời gian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                        initialDateRange: _selectedDateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(
                                      primary: Color(0xFF438883),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E2827),
                                      onSurface: Colors.white,
                                    )
                                  : const ColorScheme.light(
                                      primary: Color(0xFF438883),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (range != null) {
                        setModalState(() => _selectedDateRange = range);
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF438883)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDateRange == null
                                  ? 'Chọn khoảng thời gian'
                                  : '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}',
                              style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  
                  // NÚT HOÀN TẤT
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF438883),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF438883).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text('Xem kết quả', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Nhóm giao dịch theo ngày
  Map<DateTime, List<TransactionModel>> _groupByDate(List<TransactionModel> transactions) {
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (var tx in transactions) {
      final key = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    if (diffDays == 0) {
      return 'Hôm nay, $dateStr';
    } else if (diffDays == 1) {
      return 'Hôm qua, $dateStr';
    } else {
      const weekdays = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
      final weekdayStr = weekdays[date.weekday - 1];
      return '$weekdayStr, $dateStr';
    }
  }

  Widget _buildDateHeader(DateTime date, List<TransactionModel> transactions) {
    double dailyIncome = 0;
    double dailyExpense = 0;
    for (final tx in transactions) {
      if (tx.isTransfer) continue;
      if (tx.isIncome) {
        dailyIncome += tx.amount;
      } else {
        dailyExpense += tx.amount;
      }
    }

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatFriendlyDate(date),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (dailyIncome > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColoredAmountText.incomeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${CurrencyUtils.formatCurrency(dailyIncome)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColoredAmountText.incomeColor,
                    ),
                  ),
                ),
              if (dailyExpense > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ColoredAmountText.expenseColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${CurrencyUtils.formatCurrency(dailyExpense)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ColoredAmountText.expenseColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
