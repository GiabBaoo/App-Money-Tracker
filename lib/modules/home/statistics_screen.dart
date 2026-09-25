import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/page_transitions.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../calendar/calendar_tracking_screen.dart';
import '../../utils/category_utils.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/language_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/transaction_item.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  StatisticsScreenState createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void setExpenseFilter(bool isExpense) {
    if (mounted && _isExpense != isExpense) {
      setState(() {
        _isExpense = isExpense;
      });
    }
  }
  late Stream<List<TransactionModel>> _transactionStream;

  int _selectedMainTab = 0; // Mặc định là Tuần (0)
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int _selectedWeekOffset = 0; // 0 = Tuần hiện tại, 1 = Tuần trước...

  DateTime? _userJoinDate;
  bool _isExpense = true;
  bool _isDescending = true;
  int _selectedChartType = 0; // 0: Đường xu hướng, 1: Tròn phân bổ, 2: Cột đôi Thu vs Chi
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _transactionStream = TransactionRepository().getTransactionsStream();
    _loadUserJoinDate();
  }

  Future<void> _loadUserJoinDate() async {
    try {
      final user = await UserRepository().getUser();
      final firebaseCreation = FirebaseAuth.instance.currentUser?.metadata.creationTime;
      DateTime join = user?.joinDate ?? firebaseCreation ?? DateTime.now();

      final now = DateTime.now();
      if (join.isAfter(now)) {
        join = now;
      }

      if (mounted) {
        setState(() {
          _userJoinDate = DateTime(join.year, join.month, 1);
        });
      }
    } catch (e) {
      debugPrint('Error loading user join date: $e');
    }
  }

  DateTime get _effectiveJoinDate {
    final now = DateTime.now();
    if (_userJoinDate == null) {
      return DateTime(now.year, now.month, 1);
    }
    if (_userJoinDate!.isAfter(now)) {
      return DateTime(now.year, now.month, 1);
    }
    return DateTime(_userJoinDate!.year, _userJoinDate!.month, 1);
  }

  // ════════ ĐIỀU HƯỚNG THỜI GIAN THEO BỘ LỌC ════════

  bool _canGoPrevMonth() {
    final prev = DateTime(_selectedYear, _selectedMonth - 1, 1);
    final minDate = DateTime(_effectiveJoinDate.year, _effectiveJoinDate.month, 1);
    return !prev.isBefore(minDate);
  }

  bool _canGoNextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedYear, _selectedMonth + 1, 1);
    final maxDate = DateTime(now.year, now.month, 1);
    return !next.isAfter(maxDate);
  }

  void _onPrevMonth() {
    if (!_canGoPrevMonth()) return;
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear -= 1;
      } else {
        _selectedMonth -= 1;
      }
    });
  }

  void _onNextMonth() {
    if (!_canGoNextMonth()) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear += 1;
      } else {
        _selectedMonth += 1;
      }
    });
  }

  bool _canGoPrevYear() {
    return (_selectedYear - 1) >= _effectiveJoinDate.year;
  }

  bool _canGoNextYear() {
    return (_selectedYear + 1) <= DateTime.now().year;
  }

  void _onPrevYear() {
    if (!_canGoPrevYear()) return;
    setState(() {
      _selectedYear -= 1;
    });
  }

  void _onNextYear() {
    if (!_canGoNextYear()) return;
    setState(() {
      _selectedYear += 1;
    });
  }

  bool _canGoPrevWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfTargetWeek = today.subtract(Duration(days: today.weekday - 1 + (_selectedWeekOffset + 1) * 7));
    return !startOfTargetWeek.isBefore(_effectiveJoinDate);
  }

  bool _canGoNextWeek() {
    return _selectedWeekOffset > 0;
  }

  void _onPrevWeek() {
    if (!_canGoPrevWeek()) return;
    setState(() {
      _selectedWeekOffset += 1;
    });
  }

  void _onNextWeek() {
    if (!_canGoNextWeek()) return;
    setState(() {
      _selectedWeekOffset -= 1;
    });
  }

  bool get _canGoPrev {
    if (_selectedMainTab == 0) return _canGoPrevWeek();
    if (_selectedMainTab == 1) return _canGoPrevMonth();
    return _canGoPrevYear();
  }

  bool get _canGoNext {
    if (_selectedMainTab == 0) return _canGoNextWeek();
    if (_selectedMainTab == 1) return _canGoNextMonth();
    return _canGoNextYear();
  }

  void _onPrev() {
    if (_selectedMainTab == 0) {
      _onPrevWeek();
    } else if (_selectedMainTab == 1) {
      _onPrevMonth();
    } else {
      _onPrevYear();
    }
  }

  void _onNext() {
    if (_selectedMainTab == 0) {
      _onNextWeek();
    } else if (_selectedMainTab == 1) {
      _onNextMonth();
    } else {
      _onNextYear();
    }
  }

  String _getFilterLabel() {
    if (_selectedMainTab == 0) {
      final range = _getRangeFromFilter();
      final rangeStr = '${range.start.day.toString().padLeft(2, '0')}/${range.start.month.toString().padLeft(2, '0')} - ${range.end.day.toString().padLeft(2, '0')}/${range.end.month.toString().padLeft(2, '0')}';
      if (_selectedWeekOffset == 0) return 'Tuần ($rangeStr)';
      if (_selectedWeekOffset == 1) return 'Tuần trước ($rangeStr)';
      return rangeStr;
    } else if (_selectedMainTab == 1) {
      return 'Tháng $_selectedMonth/$_selectedYear';
    } else {
      return 'Năm $_selectedYear';
    }
  }

  ({DateTime start, DateTime end}) _getRangeFromFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedMainTab == 0) {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1 + _selectedWeekOffset * 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start: startOfWeek, end: endOfWeek);
    } else if (_selectedMainTab == 1) {
      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
      return (start: start, end: end);
    } else {
      final start = DateTime(_selectedYear, 1, 1);
      final end = DateTime(_selectedYear, 12, 31, 23, 59, 59);
      return (start: start, end: end);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // === HEADER CURVE ===
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(400, 30)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Text(
                        context.tr('stats_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(context, PageTransitions.slideRight(const CalendarTrackingScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, size: 22, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // === MAIN TABS (TUẦN/THÁNG/NĂM) ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildMainTab(0, context.tr('stats_filter_week')),
                  _buildMainTab(1, context.tr('stats_filter_month')),
                  _buildMainTab(2, context.tr('stats_filter_year')),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // === CAPSULE FILTER (NAVIGATOR + MODAL TRIGGER) & TYPE SWITCH ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // BỘ ĐIỀU HƯỚNG THỜI GIAN (< Tháng MM/YYYY >)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // NÚT LÙI THỜI GIAN (<)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: _canGoPrev
                                ? (isDark ? Colors.white70 : const Color(0xFF438883))
                                : (isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          onPressed: _canGoPrev
                              ? () {
                                  HapticFeedback.selectionClick();
                                  _onPrev();
                                }
                              : null,
                        ),

                        // NHÃN TRUNG TÂM (CHẠM ĐỂ MỞ MODAL CHỌN NHANH)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _showFilterPickerModal(context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: isDark ? Colors.white70 : const Color(0xFF438883),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _getFilterLabel(),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF333333),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),

                        // NÚT TIẾN THỜI GIAN (>)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: _canGoNext
                                ? (isDark ? Colors.white70 : const Color(0xFF438883))
                                : (isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          onPressed: _canGoNext
                              ? () {
                                  HapticFeedback.selectionClick();
                                  _onNext();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // NÚT CHUYỂN ĐỔI LOẠI GIAO DỊCH (CHI TIẾU / THU NHẬP)
                AnimatedScaleButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isExpense = !_isExpense;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: _isExpense
                          ? (isDark ? const Color(0xFF3D1B1B) : const Color(0xFFFEF2F2))
                          : (isDark ? const Color(0xFF1B3D2F) : const Color(0xFFE8F5EE)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpense ? context.tr('expense') : context.tr('income'),
                          style: TextStyle(
                            color: _isExpense
                                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFE63946))
                                : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF24A869)),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_horiz,
                          color: _isExpense
                              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFE63946))
                              : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF24A869)),
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // === CONTENT ===
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: _transactionStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                }

                final allTx = snapshot.data ?? [];
                final range = _getRangeFromFilter();

                final filteredAll = allTx.where((tx) {
                  return !tx.date.isBefore(range.start) && !tx.date.isAfter(range.end);
                }).toList();

                // Lọc bỏ các giao dịch chuyển tiền nội bộ giữa các ví để không làm lệch số liệu
                final actualTx = filteredAll.where((tx) => !tx.isTransfer).toList();

                final filtered = actualTx.where((tx) => _isExpense ? !tx.isIncome : tx.isIncome).toList();
                final chartPoints = _buildChartData(filtered, range);
                final total = filtered.fold<double>(0, (sum, tx) => sum + tx.amount);
                final categoryGroups = _getCategoryGroups(filtered);

                // Tính toán các chỉ số tài chính thông minh dựa trên thu/chi thực tế
                final totalIncome = actualTx.where((tx) => tx.isIncome).fold<double>(0, (s, tx) => s + tx.amount);
                final totalExpense = actualTx.where((tx) => !tx.isIncome).fold<double>(0, (s, tx) => s + tx.amount);
                final savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(-100.0, 100.0) : 0.0;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    key: ValueKey('stats-$_selectedMainTab-$_selectedMonth-$_selectedYear-$_selectedWeekOffset-$_isExpense-$_selectedChartType'),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      children: [
                        // Bộ chuyển đổi loại biểu đồ trực quan
                        _buildChartTypeSelector(isDark),
                        const SizedBox(height: 16),

                        // Biểu đồ được chọn
                        if (_selectedChartType == 0)
                          _buildWaveChart(chartPoints, total)
                        else if (_selectedChartType == 1)
                          _buildPieChart(categoryGroups, total)
                        else
                          _buildDoubleBarChart(actualTx, range),

                        const SizedBox(height: 12),

                        // Khối đánh giá Sức khỏe tài chính & Tỷ lệ tiết kiệm
                        _buildFinancialHealthCard(totalIncome, totalExpense, savingsRate, isDark),

                        _buildEnhancedTopSection(categoryGroups, total, actualTx),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ════════ DANH SÁCH THỐNG KÊ THEO HẠNG MỤC (NHẤN VÀO ĐỂ XEM CHI TIẾT) ════════

  Widget _buildEnhancedTopSection(List<_CategoryGroup> groups, double total, List<TransactionModel> allTx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isExpense ? context.tr('spending_breakdown') : context.tr('income_breakdown'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isDescending = !_isDescending);
              },
              child: Row(
                children: [
                  Text(
                    _isDescending ? (context.tr('see_all') != 'Xem tất cả' ? 'Highest' : 'Cao nhất') : (context.tr('see_all') != 'Xem tất cả' ? 'Lowest' : 'Thấp nhất'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(_isDescending ? Icons.expand_more : Icons.expand_less, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (groups.isEmpty)
          _buildEmptyState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final double percent = total > 0 ? (group.totalAmount / total) : 0;
              final color = CategoryUtils.getVibrantColor(group.category);
              final bgColor = CategoryUtils.getLightBgColor(group.category, isDark);

              return StaggeredListItem(
                index: index,
                child: AnimatedScaleButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showCategoryDetailSheet(context, group, total, isDark, allTransactions: allTx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                      ],
                      border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Icon Badge
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
                              child: Icon(group.icon, color: color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.trCat(group.category),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${group.transactionCount} ${context.tr('tx_history').toLowerCase()}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Amount & Chevron
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyUtils.formatCurrency(group.totalAmount),
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF333333),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${(percent * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress Bar
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percent.clamp(0.0, 1.0),
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ════════ BOTTOM SHEET CHI TIẾT CÁC GIAO DỊCH THEO MỤC ════════

  void _showCategoryDetailSheet(
    BuildContext context,
    _CategoryGroup initialGroup,
    double initialTotalAll,
    bool isDark, {
    List<TransactionModel>? allTransactions,
  }) {
    final initialAll = (allTransactions != null && allTransactions.isNotEmpty)
        ? allTransactions
        : TransactionRepository().latestTransactions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StreamBuilder<List<TransactionModel>>(
          stream: _transactionStream,
          initialData: initialAll.isNotEmpty ? initialAll : null,
          builder: (context, snapshot) {
            final allTx = (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : initialAll;
            final range = _getRangeFromFilter();

            final filteredAll = allTx.where((tx) {
              return !tx.date.isBefore(range.start) && !tx.date.isAfter(range.end);
            }).toList();

            final actualTx = filteredAll.where((tx) => !tx.isTransfer).toList();
            final filteredByType = actualTx.where((tx) => _isExpense ? !tx.isIncome : tx.isIncome).toList();
            final currentTotalAll = filteredByType.fold<double>(0, (sum, tx) => sum + tx.amount);

            var currentCategoryTx = filteredByType.where((tx) => tx.category == initialGroup.category).toList();
            // Nếu stream lọc chưa có kết quả (hoặc rỗng do lọc) thì lấy danh sách ban đầu đã lọc của group
            if (currentCategoryTx.isEmpty && initialGroup.transactions.isNotEmpty) {
              currentCategoryTx = initialGroup.transactions;
            }
            final currentCategoryTotal = currentCategoryTx.fold<double>(0, (sum, tx) => sum + tx.amount);

            final effectiveTotalAll = currentTotalAll > 0 ? currentTotalAll : initialTotalAll;
            final percent = effectiveTotalAll > 0 ? (currentCategoryTotal / effectiveTotalAll) * 100 : 0.0;
            final color = CategoryUtils.getVibrantColor(initialGroup.category);
            final bgColor = CategoryUtils.getLightBgColor(initialGroup.category, isDark);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(initialGroup.icon, color: color, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.trCat(initialGroup.category),
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${percent.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${currentCategoryTx.length} ${context.tr('tx_history').toLowerCase()}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 135),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  CurrencyUtils.formatAmountWithSign(currentCategoryTotal, !_isExpense),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _isExpense ? const Color(0xFFE63946) : const Color(0xFF24A869),
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),

                  // Subheader
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('tx_history'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Danh sách giao dịch
                  if (currentCategoryTx.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          context.tr('no_tx_category'),
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        // Sắp xếp theo thời gian tăng dần để tính lũy kế theo dòng thời gian
                        final sortedAsc = List<TransactionModel>.from(currentCategoryTx)
                          ..sort((a, b) => a.date.compareTo(b.date));
                        final Map<String, double> runningTotals = {};
                        double cumulative = 0;
                        for (int i = 0; i < sortedAsc.length; i++) {
                          final t = sortedAsc[i];
                          cumulative += t.amount;
                          final key = t.id.isNotEmpty ? t.id : '${t.date.millisecondsSinceEpoch}_$i';
                          runningTotals[key] = cumulative;
                        }

                        // Hiển thị danh sách mới nhất lên đầu
                        final displayList = List<TransactionModel>.from(currentCategoryTx)
                          ..sort((a, b) => b.date.compareTo(a.date));

                        return Flexible(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            shrinkWrap: true,
                            itemCount: displayList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final tx = displayList[idx];
                              final key = tx.id.isNotEmpty ? tx.id : '${tx.date.millisecondsSinceEpoch}_$idx';
                              return TransactionItem(
                                transaction: tx,
                                showDate: true,
                                runningTotal: runningTotals[key],
                                runningTotalLabel: 'Tổng',
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('Chưa có dữ liệu thống kê trong kỳ này', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ════════ BỘ LỌC MODAL PICKER (KHÓA TƯƠNG LAI & TRƯỚC KHI TẠO TÀI KHOẢN) ════════

  void _showFilterPickerModal(BuildContext context) {
    if (_selectedMainTab == 0) {
      _showWeekPickerSheet(context);
    } else if (_selectedMainTab == 1) {
      _showMonthPickerSheet(context);
    } else {
      _showYearPickerSheet(context);
    }
  }

  // MODAL CHỌN THÁNG & NĂM
  void _showMonthPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    int tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final canPrevYear = (tempYear - 1) >= _effectiveJoinDate.year;
          final canNextYear = (tempYear + 1) <= now.year;

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),

                // Tiêu đề & Chọn năm
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chọn tháng thống kê',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    // Bộ chọn năm: [<] Năm YYYY [>]
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: canPrevYear
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400,
                            ),
                            onPressed: canPrevYear
                                ? () => setModalState(() => tempYear -= 1)
                                : null,
                          ),
                          Text(
                            '$tempYear',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: canNextYear
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey.shade400,
                            ),
                            onPressed: canNextYear
                                ? () => setModalState(() => tempYear += 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Lưới 12 tháng (3 hàng x 4 cột)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, idx) {
                    final month = idx + 1;
                    final isBeforeAccount = tempYear == _effectiveJoinDate.year &&
                        month < _effectiveJoinDate.month;
                    final isFutureMonth = tempYear == now.year && month > now.month;
                    final isDisabled = isBeforeAccount || isFutureMonth;
                    final isSelected =
                        (month == _selectedMonth && tempYear == _selectedYear);

                    return InkWell(
                      onTap: isDisabled
                          ? null
                          : () {
                              setState(() {
                                _selectedMonth = month;
                                _selectedYear = tempYear;
                              });
                              Navigator.pop(context);
                            },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : isDisabled
                                  ? (isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : const Color(0xFFF9FAFB))
                                  : (isDark
                                      ? const Color(0xFF2E2E2E)
                                      : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(14),
                          border: isDisabled
                              ? Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade200)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tháng $month',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : isDisabled
                                        ? (isDark
                                            ? Colors.white24
                                            : Colors.grey.shade400)
                                        : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            if (isDisabled) ...[
                              const SizedBox(height: 2),
                              Text(
                                isBeforeAccount ? 'Chưa tạo' : 'Chưa tới',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // MODAL CHỌN NĂM (CHỈ CHO CHỌN TỪ NĂM TẠO TÀI KHOẢN ĐẾN HIỆN TẠI)
  void _showYearPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();

    final minYear = _effectiveJoinDate.year;
    final maxYear = now.year;
    final years = <int>[];
    for (int y = maxYear; y >= minYear; y--) {
      years.add(y);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chọn năm thống kê',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                final isSelected = year == _selectedYear;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedYear = year;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Năm $year',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // MODAL CHỌN TUẦN
  void _showWeekPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final weeks = <({int offset, String label})>[];
    for (int offset = 0; offset < 12; offset++) {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1 + offset * 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      if (endOfWeek.isBefore(_effectiveJoinDate) && offset > 0) {
        break;
      }

      String label;
      if (offset == 0) {
        label = 'Tuần (${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.day}/${endOfWeek.month})';
      } else if (offset == 1) {
        label = 'Tuần trước (${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.day}/${endOfWeek.month})';
      } else {
        label = '${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.day}/${endOfWeek.month}/${startOfWeek.year}';
      }
      weeks.add((offset: offset, label: label));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chọn tuần thống kê',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: weeks.length,
                itemBuilder: (context, index) {
                  final item = weeks[index];
                  final isSelected = item.offset == _selectedWeekOffset;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWeekOffset = item.offset;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        ],
                      ),
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

  Widget _buildMainTab(int index, String label) {
    bool isSelected = _selectedMainTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: AnimatedScaleButton(
        scaleDown: 0.95,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedMainTab = index;
            if (index == 0) {
              _selectedWeekOffset = 0;
            } else if (index == 1) {
              _selectedMonth = DateTime.now().month;
              _selectedYear = DateTime.now().year;
            } else if (index == 2) {
              _selectedYear = DateTime.now().year;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF438883) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF438883).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════ BIỂU ĐỒ LƯỢN SÓNG (CHART) ════════

  Widget _buildChartTypeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242424) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildChartTypeTab(0, Icons.show_chart_rounded, 'Xu hướng', isDark),
          _buildChartTypeTab(1, Icons.pie_chart_rounded, 'Phân bổ', isDark),
          _buildChartTypeTab(2, Icons.bar_chart_rounded, 'So sánh Thu/Chi', isDark),
        ],
      ),
    );
  }

  Widget _buildChartTypeTab(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedChartType == index;
    final primaryColor = Theme.of(context).primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedChartType = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF333333) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : primaryColor) : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(List<_CategoryGroup> groups, double total) {
    if (groups.isEmpty || total <= 0) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu phân bổ trong kỳ này', style: TextStyle(color: Color(0xFF999999))),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sections = groups.asMap().entries.map((entry) {
      final idx = entry.key;
      final group = entry.value;
      final isTouched = idx == _touchedPieIndex;
      final radius = isTouched ? 62.0 : 52.0;
      final percent = (group.totalAmount / total * 100);
      final color = CategoryUtils.getVibrantColor(group.category);

      return PieChartSectionData(
        color: color,
        value: group.totalAmount,
        title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedPieIndex = -1;
                      return;
                    }
                    _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: groups.take(4).map((g) {
            final color = CategoryUtils.getVibrantColor(g.category);
            final percent = (g.totalAmount / total * 100).toStringAsFixed(1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${g.category} ($percent%)', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDoubleBarChart(List<TransactionModel> allFilteredTx, ({DateTime start, DateTime end}) range) {
    if (allFilteredTx.isEmpty) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu so sánh Thu - Chi', style: TextStyle(color: Color(0xFF999999))),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<({String label, double income, double expense})> barData = [];

    if (_selectedMainTab == 0) {
      final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      for (int i = 0; i < 7; i++) {
        final d = range.start.add(Duration(days: i));
        final dayTx = allFilteredTx.where((tx) =>
          tx.date.year == d.year && tx.date.month == d.month && tx.date.day == d.day);
        final inc = dayTx.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        final exp = dayTx.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        barData.add((label: dayNames[d.weekday % 7], income: inc, expense: exp));
      }
    } else if (_selectedMainTab == 1) {
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final intervals = [
        (start: 1, end: 7, label: 'W1'),
        (start: 8, end: 14, label: 'W2'),
        (start: 15, end: 21, label: 'W3'),
        (start: 22, end: daysInMonth, label: 'W4'),
      ];
      for (final itv in intervals) {
        final itvTx = allFilteredTx.where((tx) =>
          tx.date.year == _selectedYear &&
          tx.date.month == _selectedMonth &&
          tx.date.day >= itv.start &&
          tx.date.day <= itv.end);
        final inc = itvTx.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        final exp = itvTx.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        barData.add((label: itv.label, income: inc, expense: exp));
      }
    } else {
      for (int i = 1; i <= 12; i++) {
        final monthTx = allFilteredTx.where((tx) => tx.date.year == _selectedYear && tx.date.month == i);
        final inc = monthTx.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        final exp = monthTx.where((t) => !t.isIncome).fold<double>(0, (s, t) => s + t.amount);
        barData.add((label: 'T$i', income: inc, expense: exp));
      }
    }

    double maxY = 1.0;
    for (var b in barData) {
      if (b.income > maxY) maxY = b.income;
      if (b.expense > maxY) maxY = b.expense;
    }
    maxY *= 1.25;

    final barGroups = barData.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: item.income,
            color: const Color(0xFF10B981),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: item.expense,
            color: const Color(0xFFEF4444),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Thu nhập', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            const SizedBox(width: 16),
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Chi tiêu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => isDark ? const Color(0xFF2E2E2E) : Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isInc = rodIndex == 0;
                    return BarTooltipItem(
                      '${isInc ? "Thu" : "Chi"}: ${CurrencyUtils.formatCurrency(rod.toY)}',
                      TextStyle(
                        color: isInc ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final i = val.toInt();
                      if (i < 0 || i >= barData.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(barData[i].label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialHealthCard(double income, double expense, double savingsRate, bool isDark) {
    String healthStatus = 'Cân đối';
    Color healthColor = const Color(0xFF10B981);
    IconData healthIcon = Icons.sentiment_satisfied_alt;

    if (savingsRate >= 30) {
      healthStatus = 'Rất tốt';
      healthColor = const Color(0xFF10B981);
      healthIcon = Icons.sentiment_very_satisfied;
    } else if (savingsRate > 0) {
      healthStatus = 'Tốt';
      healthColor = const Color(0xFF0EA5E9);
      healthIcon = Icons.sentiment_satisfied;
    } else if (savingsRate == 0) {
      healthStatus = 'Vừa đủ';
      healthColor = Colors.orange;
      healthIcon = Icons.sentiment_neutral;
    } else {
      healthStatus = 'Báo động';
      healthColor = const Color(0xFFEF4444);
      healthIcon = Icons.sentiment_dissatisfied;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: healthColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  Icon(healthIcon, color: healthColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Sức khỏe tài chính', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  healthStatus,
                  style: TextStyle(color: healthColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tỷ lệ tiết kiệm', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      '${savingsRate >= 0 ? "+" : ""}${savingsRate.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: healthColor),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: isDark ? Colors.white12 : Colors.grey.shade200),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chênh lệch thu chi', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyUtils.formatCurrency(income - expense),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: (income - expense) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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

  Widget _buildWaveChart(List<_ChartPoint> data, double total) {
    final chartColor = _isExpense ? const Color(0xFFE63946) : const Color(0xFF438883);
    if (data.isEmpty || total == 0) {
      return Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu giao dịch trong kỳ này', style: TextStyle(color: Color(0xFF999999))),
        ),
      );
    }
    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY <= 0 ? 1.0 : maxY * 1.3;
    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: safeMaxY,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(data[idx].label, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E2E2E) : Colors.white,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        CurrencyUtils.formatCurrency(s.y),
                        TextStyle(color: chartColor, fontWeight: FontWeight.bold),
                      ))
                  .toList(),
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              color: chartColor,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [chartColor.withValues(alpha: 0.25), chartColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ChartPoint> _buildChartData(List<TransactionModel> transactions, ({DateTime start, DateTime end}) range) {
    List<_ChartPoint> result = [];
    if (_selectedMainTab == 0) {
      final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
      for (int i = 0; i < 7; i++) {
        final d = range.start.add(Duration(days: i));
        final val = transactions
            .where((tx) => tx.date.year == d.year && tx.date.month == d.month && tx.date.day == d.day)
            .fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: dayNames[d.weekday % 7], value: val));
      }
    } else if (_selectedMainTab == 1) {
      final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      final intervals = [
        (start: 1, end: 7, label: 'W1'),
        (start: 8, end: 14, label: 'W2'),
        (start: 15, end: 21, label: 'W3'),
        (start: 22, end: daysInMonth, label: 'W4'),
      ];
      for (final interval in intervals) {
        final val = transactions
            .where((tx) =>
                tx.date.year == _selectedYear &&
                tx.date.month == _selectedMonth &&
                tx.date.day >= interval.start &&
                tx.date.day <= interval.end)
            .fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: interval.label, value: val));
      }
    } else {
      for (int i = 1; i <= 12; i++) {
        final val = transactions
            .where((tx) => tx.date.year == _selectedYear && tx.date.month == i)
            .fold<double>(0, (s, tx) => s + tx.amount);
        result.add(_ChartPoint(label: 'T$i', value: val));
      }
    }
    return result;
  }

  // ════════ NHÓM GIAO DỊCH THEO HẠNG MỤC ════════

  List<_CategoryGroup> _getCategoryGroups(List<TransactionModel> txs) {
    final Map<String, List<TransactionModel>> map = {};
    for (final tx in txs) {
      map.putIfAbsent(tx.category, () => []).add(tx);
    }

    final list = map.entries.map((e) {
      final sortedTxs = List<TransactionModel>.from(e.value)..sort((a, b) => b.date.compareTo(a.date));
      final sum = sortedTxs.fold<double>(0, (prev, element) => prev + element.amount);
      return _CategoryGroup(
        category: e.key,
        totalAmount: sum,
        transactionCount: sortedTxs.length,
        icon: CategoryUtils.getCategoryIcon(e.key),
        transactions: sortedTxs,
      );
    }).toList();

    list.sort((a, b) =>
        _isDescending ? b.totalAmount.compareTo(a.totalAmount) : a.totalAmount.compareTo(b.totalAmount));
    return list;
  }
}

class _CategoryGroup {
  final String category;
  final double totalAmount;
  final int transactionCount;
  final IconData icon;
  final List<TransactionModel> transactions;

  _CategoryGroup({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.icon,
    required this.transactions,
  });
}

class _ChartPoint {
  final String label;
  final double value;
  _ChartPoint({required this.label, required this.value});
}
