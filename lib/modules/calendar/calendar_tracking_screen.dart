import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/transaction_model.dart';
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

  // Cờ chuyển trang mượt mà (tránh drop frame trong 400ms transition)
  bool _isTransitionReady = false;

  // Cache memoization để không tính toán lại lặp đi lặp lại
  List<TransactionModel>? _cachedAllTx;
  DateTime? _cachedMonthKey;
  Map<int, List<TransactionModel>> _cachedDayTxMap = {};
  double _cachedMonthIncome = 0;
  double _cachedMonthExpense = 0;

  Map<String, double> _cachedReverseBalances = {};
  int _lastTxCountForBalance = -1;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      _txRepo.setUid(uid);
    }
    _walletRepo.getWallets();

    // Lắng nghe hoàn tất animation chuyển trang để giải phóng frame rate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route == null || route.animation == null) {
        if (mounted) setState(() => _isTransitionReady = true);
      } else if (route.animation!.isCompleted) {
        if (mounted) setState(() => _isTransitionReady = true);
      } else {
        void statusListener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route.animation?.removeStatusListener(statusListener);
            if (mounted) setState(() => _isTransitionReady = true);
          }
        }
        route.animation!.addStatusListener(statusListener);
      }
    });
  }

  void _onPrevMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _onNextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  /// Cập nhật cache cho tháng đang chọn nếu dữ liệu hoặc tháng thay đổi
  void _ensureMonthCalculations(List<TransactionModel> allTx) {
    if (identical(_cachedAllTx, allTx) &&
        _cachedMonthKey != null &&
        _cachedMonthKey!.year == _focusedMonth.year &&
        _cachedMonthKey!.month == _focusedMonth.month) {
      return;
    }

    _cachedAllTx = allTx;
    _cachedMonthKey = _focusedMonth;

    final monthTx = allTx.where((tx) =>
      tx.date.year == _focusedMonth.year &&
      tx.date.month == _focusedMonth.month
    ).toList();

    double income = 0;
    double expense = 0;
    final Map<int, List<TransactionModel>> map = {};

    for (final tx in monthTx) {
      if (!tx.isTransfer) {
        if (tx.type == 'income') {
          income += tx.amount;
        } else {
          expense += tx.amount;
        }
      }
      map.putIfAbsent(tx.date.day, () => []).add(tx);
    }

    _cachedMonthIncome = income;
    _cachedMonthExpense = expense;
    _cachedDayTxMap = map;
  }

  /// Memoize số dư chạy ngược chỉ khi allTx thay đổi
  Map<String, double> _ensureReverseBalances(List<TransactionModel> allTx) {
    if (allTx.length == _lastTxCountForBalance && _cachedReverseBalances.isNotEmpty) {
      return _cachedReverseBalances;
    }

    _lastTxCountForBalance = allTx.length;
    _cachedReverseBalances = CurrencyUtils.calculateReverseWalletBalances(
      allTransactions: allTx,
      wallets: _walletRepo.latestWallets,
    );
    return _cachedReverseBalances;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF0F2625) : const Color(0xFF438883);

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOP APP BAR FINTECH GLASSMORPHISM
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
                    'Lịch Theo Dõi Thu Chi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  AnimatedScaleButton(
                    onTap: _jumpToToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.today_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Hôm nay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. MAIN SHEET
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
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _txRepo.getTransactionsStream(),
                  initialData: _txRepo.latestTransactions.isNotEmpty ? _txRepo.latestTransactions : null,
                  builder: (context, snapshot) {
                    final allTx = snapshot.data ?? [];

                    // Tính toán và lưu cache tháng
                    _ensureMonthCalculations(allTx);

                    final dayTx = (_cachedDayTxMap[_selectedDate.day] ?? [])
                        .where((tx) =>
                            tx.date.year == _selectedDate.year &&
                            tx.date.month == _selectedDate.month)
                        .toList()
                      ..sort(CurrencyUtils.compareTransactionsChronological);

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
                        // RepaintBoundary cách ly bảng lịch và header khỏi sự kiện cuộn danh sách bên dưới
                        RepaintBoundary(
                          child: Column(
                            children: [
                              // Thanh điều hướng tháng & Ribbon tổng quan
                              _buildMonthHeader(isDark, _cachedMonthIncome, _cachedMonthExpense),

                              // Bảng lịch
                              _buildCalendarGrid(_cachedDayTxMap, isDark),
                            ],
                          ),
                        ),

                        const Divider(height: 1, thickness: 1),

                        // Thẻ tóm tắt ngày đang chọn
                        _buildSelectedDayHeader(isDark, dayIncome, dayExpense),

                        // Danh sách giao dịch của ngày đang chọn
                        Expanded(
                          child: !_isTransitionReady && dayTx.length > 5
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF438883)),
                                    ),
                                  ),
                                )
                              : (dayTx.isEmpty
                                  ? _buildEmptyDay(isDark)
                                  : Builder(
                                      builder: (context) {
                                        final reverseBalances = _ensureReverseBalances(allTx);
                                        final walletMap = {for (final w in _walletRepo.latestWallets) w.id: w};
                                        return ListView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          cacheExtent: 500,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          itemCount: dayTx.length,
                                          itemBuilder: (context, index) {
                                            final tx = dayTx[index];
                                            return TransactionItem(
                                              transaction: tx,
                                              showDate: false,
                                              runningTotal: reverseBalances[tx.id],
                                              wallet: walletMap[tx.walletId],
                                            );
                                          },
                                        );
                                      },
                                    )),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(bool isDark, double income, double expense) {
    final monthStr = 'Tháng ${_focusedMonth.month}, ${_focusedMonth.year}';
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162524) : const Color(0xFFF1F8F6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedScaleButton(
                onTap: _onPrevMonth,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 24, color: Color(0xFF438883)),
                ),
              ),
              Text(
                monthStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              AnimatedScaleButton(
                onTap: _onNextMonth,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 24, color: Color(0xFF438883)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ribbon tổng quan tháng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryPill('Tổng thu', income, const Color(0xFF10B981), isDark),
              _buildSummaryPill('Tổng chi', expense, const Color(0xFFEF4444), isDark),
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
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Map<int, List<TransactionModel>> dayTxMap, bool isDark) {
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final offset = firstWeekday - 1;

    const weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    final now = DateTime.now();
    final isCurrentMonth = now.year == _focusedMonth.year && now.month == _focusedMonth.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Tiêu đề các thứ
          Row(
            children: weekDays.map((d) {
              final isWeekend = d == 'T7' || d == 'CN';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isWeekend ? Colors.orange : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // Lưới các ngày (42 ô cố định)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 38,
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

              final txList = dayTxMap[dayNum] ?? const [];
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF438883)
                        : (isToday
                            ? (isDark ? const Color(0xFF1E3A37) : const Color(0xFFE8F5F1))
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFF438883), width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? const Color(0xFF438883)
                                  : (isDark ? Colors.white70 : const Color(0xFF1E293B))),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasIncome)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasExpense)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasTransfer)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : const Color(0xFF0EA5E9),
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

  Widget _buildSelectedDayHeader(bool isDark, double dayIncome, double dayExpense) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final dayStr = isToday
        ? 'Hôm nay, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
        : 'Ngày ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: isDark ? const Color(0xFF162524).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF438883).withValues(alpha: 0.16)
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                  size: 13,
                  color: isToday ? const Color(0xFF438883) : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              Text(
                dayStr,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (dayIncome > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded, size: 10, color: Color(0xFF2ECC71)),
                      const SizedBox(width: 2),
                      Text(
                        '+${CurrencyUtils.formatCurrency(dayIncome)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                    ],
                  ),
                ),
              if (dayExpense > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63946).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFFE63946).withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded, size: 10, color: Color(0xFFE63946)),
                      const SizedBox(width: 2),
                      Text(
                        '-${CurrencyUtils.formatCurrency(dayExpense)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE63946),
                        ),
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

  Widget _buildEmptyDay(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 38, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text(
                'Không có giao dịch trong ngày này',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              AnimatedScaleButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    PageTransitions.slideUp(const AddTransactionScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF438883).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: Color(0xFF438883)),
                      SizedBox(width: 4),
                      Text(
                        'Thêm giao dịch',
                        style: TextStyle(
                          color: Color(0xFF438883),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
