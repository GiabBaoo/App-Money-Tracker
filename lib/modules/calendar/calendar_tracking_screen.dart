import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
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
    final isDark = context.isDark;
    final primaryColor = isDark ? AppColors.primaryTealDark : AppColors.primaryTeal;

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
                  Expanded(
                    child: Text(
                      LanguageScope.of(context).isVietnamese ? 'Lịch Theo Dõi Thu Chi' : 'Income & Expense Calendar',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
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
                      child: Row(
                        children: [
                          const Icon(Icons.today_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            LanguageScope.of(context).isVietnamese ? 'Hôm nay' : 'Today',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
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
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
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
                              ? Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
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
    final isVi = LanguageScope.of(context).isVietnamese;
    final monthStr = isVi
        ? 'Tháng ${_focusedMonth.month}, ${_focusedMonth.year}'
        : 'Month ${_focusedMonth.month}, ${_focusedMonth.year}';
    final net = income - expense;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? context.cardBg : context.inputBgColor,
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
                  child: Icon(Icons.chevron_left_rounded, size: 24, color: context.colors.primary),
                ),
              ),
              Text(
                monthStr,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colors.onSurface,
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
                  child: Icon(Icons.chevron_right_rounded, size: 24, color: context.colors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ribbon tổng quan tháng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildSummaryPill(isVi ? 'Tổng thu' : 'Total Income', income, context.income, isDark)),
              const SizedBox(width: 4),
              Expanded(child: _buildSummaryPill(isVi ? 'Tổng chi' : 'Total Expense', expense, context.expense, isDark)),
              const SizedBox(width: 4),
              Expanded(child: _buildSummaryPill(isVi ? 'Chênh lệch' : 'Net Cashflow', net, net >= 0 ? context.info : context.warning, isDark)),
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
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyUtils.formatCurrency(amount),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(Map<int, List<TransactionModel>> dayTxMap, bool isDark) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday;
    final offset = firstWeekday - 1;

    final weekDays = isVi
        ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final now = DateTime.now();
    final isCurrentMonth = now.year == _focusedMonth.year && now.month == _focusedMonth.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Tiêu đề các thứ
          Row(
            children: weekDays.map((d) {
              final isWeekend = isVi ? (d == 'T7' || d == 'CN') : (d == 'Sat' || d == 'Sun');
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: context.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isWeekend ? context.warning : context.colors.onSurfaceVariant,
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
                        ? context.colors.primary
                        : (isToday
                            ? (isDark ? context.colors.primary.withValues(alpha: 0.25) : context.colors.primary.withValues(alpha: 0.12))
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: context.colors.primary, width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                  ? context.colors.primary
                                  : context.colors.onSurface),
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
                                color: isSelected ? Colors.white : context.income,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasExpense)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : context.expense,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasTransfer)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : context.info,
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
    final isVi = LanguageScope.of(context).isVietnamese;
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final dayStr = isToday
        ? (isVi ? 'Hôm nay, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}' : 'Today, ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}')
        : (isVi ? 'Ngày ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}' : 'Date ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: isDark ? context.cardBg.withValues(alpha: 0.6) : context.inputBgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: isToday
                        ? context.colors.primary.withValues(alpha: 0.16)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                    size: 13,
                    color: isToday ? context.colors.primary : context.colors.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    dayStr,
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dayIncome > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: context.income.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: context.income.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_downward_rounded, size: 10, color: context.income),
                          const SizedBox(width: 2),
                          Text(
                            '+${CurrencyUtils.formatCurrency(dayIncome)}',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.income,
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
                        color: context.expense.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: context.expense.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 10, color: context.expense),
                          const SizedBox(width: 2),
                          Text(
                            '-${CurrencyUtils.formatCurrency(dayExpense)}',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay(bool isDark) {
    final isVi = LanguageScope.of(context).isVietnamese;
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 38, color: context.colors.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text(
                isVi ? 'Không có giao dịch trong ngày này' : 'No transactions on this day',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
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
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        isVi ? 'Thêm giao dịch' : 'Add transaction',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colors.primary,
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
