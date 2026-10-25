import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/animated_scale_button.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../utils/page_transitions.dart';
import '../calendar/calendar_tracking_screen.dart';
import '../../services/language_service.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  final TransactionRepository _txRepo = TransactionRepository();
  final WalletRepository _walletRepo = WalletRepository();
  String _selectedType = 'Tất cả';
  String _datePreset = 'month_to_date';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _txRepo.setUid(uid);
      _walletRepo.setUid(uid);
    }
    _walletRepo.getWallets();
    _applyDatePreset('month_to_date');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    _datePreset = preset;
    switch (preset) {
      case 'month_to_date':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'today':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'last_7_days':
        _selectedDateRange = DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'last_30_days':
        _selectedDateRange = DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'this_month':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
        break;
      case 'last_month':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0, 23, 59, 59),
        );
        break;
      case 'this_year':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
        break;
      case 'year_2020':
        _selectedDateRange = DateTimeRange(
          start: DateTime(2020, 1, 1),
          end: DateTime(2020, 12, 31, 23, 59, 59),
        );
        break;
      case 'all_time':
        _selectedDateRange = null;
        break;
      case 'custom':
        // Giữ nguyên _selectedDateRange hiện có
        break;
    }
  }

  String _getDateFilterLabel() {
    switch (_datePreset) {
      case 'month_to_date':
        return context.tr('preset_month_to_date');
      case 'today':
        return context.tr('preset_today');
      case 'last_7_days':
        return context.tr('preset_last_7_days');
      case 'last_30_days':
        return context.tr('preset_last_30_days');
      case 'this_month':
        return context.tr('preset_this_month');
      case 'last_month':
        return context.tr('preset_last_month');
      case 'this_year':
        return '${context.tr('year')} ${DateTime.now().year}';
      case 'year_2020':
        return '${context.tr('year')} 2020';
      case 'all_time':
        return context.tr('filter_all');
      case 'custom':
      default:
        if (_selectedDateRange == null) return context.tr('filter_all');
        return '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}';
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'Tất cả';
      _datePreset = 'all_time';
      _selectedDateRange = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ════════ TOP APP BAR (FINTECH GLASSMORPHISM) ════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.45),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.tr('transaction_history'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            PageTransitions.slideRight(
                              const CalendarTrackingScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.45),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showFilterBottomSheet(context);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                (_selectedType != 'Tất cả' ||
                                    _selectedDateRange != null)
                                ? Colors.white
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.22)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  (_selectedType != 'Tất cả' ||
                                      _selectedDateRange != null)
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.45)),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color:
                                (_selectedType != 'Tất cả' ||
                                    _selectedDateRange != null)
                                ? const Color(0xFF235F5B)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ════════ SEARCH BOX CAO CẤP TƯƠNG PHẢN CAO ════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.08,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase().trim()),
                  cursorColor: isDark ? Colors.white : context.colors.onSurface,
                  style: (context.textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(
                        color: isDark ? Colors.white : context.colors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Tìm theo nội dung, danh mục, số tiền...'
                        : 'Search by note, category, amount...',
                    hintStyle:
                        (context.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                              color: isDark
                                  ? Colors.white60
                                  : context.colors.onSurfaceVariant,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? Colors.white70
                          : context.colors.onSurfaceVariant,
                      size: 21,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark
                                  ? Colors.white70
                                  : context.colors.onSurfaceVariant,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ════════ QUICK FILTER CHIPS ════════
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Row(
                children: [
                  _buildQuickTypeChip('Tất cả', isDark),
                  _buildQuickTypeChip('Chi tiêu', isDark),
                  _buildQuickTypeChip('Thu nhập', isDark),
                  _buildQuickTypeChip('Chuyển ví', isDark),
                  // Quick Date Filter Pill
                  _buildQuickDateFilterPill(isDark),
                  if (_selectedType != 'Tất cả' ||
                      _datePreset != 'all_time' ||
                      _searchQuery.isNotEmpty)
                    AnimatedScaleButton(
                      onTap: _resetFilters,
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('clear_filter'),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11.5,
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

            const SizedBox(height: 8),

            // ════════ DANH SÁCH GIAO DỊCH REALTIME ════════
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: StreamBuilder<List<TransactionModel>>(
                    stream: _txRepo.getTransactionsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: context.brandColor,
                          ),
                        );
                      }

                      // 1. ÁP DỤNG BỘ LỌC
                      List<TransactionModel> transactions =
                          List<TransactionModel>.from(snapshot.data ?? []);
                      transactions.sort(
                        CurrencyUtils.compareTransactionsChronological,
                      );

                      // Lọc theo loại hình
                      if (_selectedType == 'Thu nhập') {
                        transactions = transactions
                            .where((tx) => tx.isIncome && !tx.isTransfer)
                            .toList();
                      } else if (_selectedType == 'Chi tiêu') {
                        transactions = transactions
                            .where((tx) => !tx.isIncome && !tx.isTransfer)
                            .toList();
                      } else if (_selectedType == 'Chuyển ví') {
                        transactions = transactions
                            .where((tx) => tx.isTransfer)
                            .toList();
                      }

                      // Lọc theo thời gian (Tự động bỏ qua khi người dùng đang tìm kiếm từ khóa để tìm trong toàn bộ lịch sử)
                      if (_selectedDateRange != null && _searchQuery.isEmpty) {
                        transactions = transactions.where((tx) {
                          final txDate = DateTime(
                            tx.date.year,
                            tx.date.month,
                            tx.date.day,
                          );
                          return !txDate.isBefore(_selectedDateRange!.start) &&
                              !txDate.isAfter(_selectedDateRange!.end);
                        }).toList();
                      }

                      // Lọc theo Search Query (Tìm kiếm toàn thời gian)
                      if (_searchQuery.isNotEmpty) {
                        transactions = transactions.where((tx) {
                          final desc = tx.description.toLowerCase();
                          final cat = tx.category.toLowerCase();
                          final amt = tx.amount.toString();
                          final formattedAmt = CurrencyUtils.formatCurrency(
                            tx.amount,
                          ).toLowerCase();
                          final dateFormatted = CurrencyUtils.formatDate(
                            tx.date,
                          ).toLowerCase();
                          final yearStr = tx.date.year.toString();
                          final walletMatches = _walletRepo.latestWallets.where(
                            (w) => w.id == tx.walletId,
                          );
                          final walletName = walletMatches.isNotEmpty
                              ? walletMatches.first.name.toLowerCase()
                              : '';

                          return desc.contains(_searchQuery) ||
                              cat.contains(_searchQuery) ||
                              amt.contains(_searchQuery) ||
                              formattedAmt.contains(_searchQuery) ||
                              dateFormatted.contains(_searchQuery) ||
                              yearStr.contains(_searchQuery) ||
                              (walletName.isNotEmpty &&
                                  walletName.contains(_searchQuery));
                        }).toList();
                      }

                      // Tính tổng dòng tiền cho phạm vi đang lọc
                      double totalIncome = 0;
                      double totalExpense = 0;
                      for (final tx in transactions) {
                        if (tx.isTransfer) continue;
                        if (tx.isIncome) {
                          totalIncome += tx.amount;
                        } else {
                          totalExpense += tx.amount;
                        }
                      }

                      if (transactions.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 56,
                                color: context.textMutedColor,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? (isVi
                                          ? 'Không tìm thấy giao dịch "$_searchQuery" trong toàn bộ lịch sử'
                                          : 'No transactions found matching "$_searchQuery"')
                                    : (isVi
                                          ? 'Không tìm thấy giao dịch nào'
                                          : 'No transactions found'),
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // 2. NHÓM GIAO DỊCH THEO NGÀY & VIRTUALIZATION TỐI ƯU 120FPS
                      final allTx = List<TransactionModel>.from(
                        snapshot.data ?? [],
                      );
                      final effectiveWallets = _walletRepo.latestWallets;
                      final walletMap = {
                        for (final w in effectiveWallets) w.id: w,
                      };
                      final reverseBalances =
                          CurrencyUtils.calculateReverseWalletBalances(
                            allTransactions: allTx,
                            wallets: effectiveWallets,
                          );
                      final grouped = _groupByDate(transactions);

                      // Làm phẳng danh sách (Flattened list) để SliverList ảo hóa toàn bộ 100% item và date header
                      final List<_TxHistoryRow> flatRows = [];
                      int globalTxCounter = 0;

                      for (final entry in grouped.entries) {
                        flatRows.add(
                          _TxHistoryRow.header(
                            date: entry.key,
                            dailyTxs: entry.value,
                          ),
                        );
                        for (final tx in entry.value) {
                          flatRows.add(
                            _TxHistoryRow.transaction(
                              tx: tx,
                              wallet: walletMap[tx.walletId],
                              runningTotal: reverseBalances[tx.id],
                              globalIndex: globalTxCounter++,
                            ),
                          );
                        }
                      }

                      return CustomScrollView(
                        key: const PageStorageKey('all_transactions_scroll'),
                        physics: const BouncingScrollPhysics(),
                        cacheExtent: 600,
                        slivers: [
                          // ════════ ALL-TIME SEARCH INDICATOR BADGE ════════
                          if (_searchQuery.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  0,
                                ),
                                child: _buildSearchIndicatorBadge(
                                  transactions.length,
                                  isDark,
                                ),
                              ),
                            ),

                          // ════════ CASHFLOW MINI SUMMARY CARD ════════
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: _buildCashflowSummaryCard(
                                totalIncome,
                                totalExpense,
                                isDark,
                              ),
                            ),
                          ),

                          // ════════ DANH SÁCH GIAO DỊCH ẢO HÓA (ZERO-LAG 120FPS) ════════
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final row = flatRows[index];
                                if (row.isHeader) {
                                  return _buildDateHeader(
                                    row.date,
                                    row.dailyTxs!,
                                  );
                                }
                                final txWidget = TransactionItem(
                                  transaction: row.tx!,
                                  showDate: false,
                                  runningTotal: row.runningTotal,
                                  wallet: row.wallet,
                                );
                                // Chỉ chạy hiệu ứng staggered xuất hiện cho tối đa 5 giao dịch đầu tiên trên màn hình
                                // Khi người dùng cuộn/lướt lên xuống, các mục tiếp theo render tức thì để không bao giờ bị khựng khung hình!
                                if (row.globalIndex < 5) {
                                  return StaggeredListItem(
                                    index: row.globalIndex,
                                    child: txWidget,
                                  );
                                }
                                return txWidget;
                              }, childCount: flatRows.length),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDisplayLabel(String type, bool isVi) {
    switch (type) {
      case 'Chi tiêu':
        return isVi ? 'Chi tiêu' : 'Expense';
      case 'Thu nhập':
        return isVi ? 'Thu nhập' : 'Income';
      case 'Chuyển ví':
        return isVi ? 'Chuyển ví' : 'Transfer';
      case 'Tất cả':
      default:
        return isVi ? 'Tất cả' : 'All';
    }
  }

  Widget _buildQuickTypeChip(String label, bool isDark) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isSelected = _selectedType == label;
    final displayLabel = _getTypeDisplayLabel(label, isVi);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedType = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.24)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.45)),
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              displayLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFF235F5B) : Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDateFilterPill(bool isDark) {
    final hasFilter = _datePreset != 'all_time';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.lightImpact();
          _showDatePresetPickerSheet(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasFilter
                ? Colors.white
                : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.24)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasFilter
                  ? Colors.white
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.45)),
              width: 1.0,
            ),
            boxShadow: hasFilter
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: hasFilter ? const Color(0xFF235F5B) : Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                _getDateFilterLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasFilter ? FontWeight.w800 : FontWeight.w700,
                  color: hasFilter ? const Color(0xFF235F5B) : Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: hasFilter ? const Color(0xFF235F5B) : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // BOTTOM SHEET CHỌN NHANH KHOẢNG THỜI GIAN FINTECH
  void _showDatePresetPickerSheet(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;

    final presets = [
      {
        'key': 'month_to_date',
        'title': isVi ? 'Từ đầu tháng đến nay' : 'Month to date',
        'desc': isVi
            ? 'Ngày 01 đến hôm nay (Khuyên dùng)'
            : 'From day 1 to today (Recommended)',
        'icon': Icons.trending_up_rounded,
      },
      {
        'key': 'today',
        'title': isVi ? 'Hôm nay' : 'Today',
        'desc': isVi ? 'Giao dịch phát sinh trong ngày' : 'Transactions today',
        'icon': Icons.today_rounded,
      },
      {
        'key': 'last_7_days',
        'title': isVi ? '7 ngày qua' : 'Last 7 days',
        'desc': isVi ? '7 ngày gần nhất tính đến nay' : 'Past 7 days up to now',
        'icon': Icons.date_range_rounded,
      },
      {
        'key': 'last_30_days',
        'title': isVi ? '30 ngày qua' : 'Last 30 days',
        'desc': isVi
            ? '30 ngày gần nhất tính đến nay'
            : 'Past 30 days up to now',
        'icon': Icons.calendar_view_day_rounded,
      },
      {
        'key': 'this_month',
        'title': isVi ? 'Tháng này' : 'This month',
        'desc': isVi
            ? 'Toàn bộ các ngày trong tháng hiện tại'
            : 'All days in current month',
        'icon': Icons.calendar_month_rounded,
      },
      {
        'key': 'last_month',
        'title': isVi ? 'Tháng trước' : 'Last month',
        'desc': isVi
            ? 'Toàn bộ các ngày của tháng vừa qua'
            : 'All days of previous month',
        'icon': Icons.history_rounded,
      },
      {
        'key': 'this_year',
        'title': isVi
            ? 'Năm nay (${DateTime.now().year})'
            : 'This year (${DateTime.now().year})',
        'desc': isVi
            ? 'Toàn bộ giao dịch trong năm hiện tại'
            : 'All transactions in current year',
        'icon': Icons.calendar_today_rounded,
      },
      {
        'key': 'year_2020',
        'title': isVi ? 'Năm 2020 (Lịch sử cũ)' : 'Year 2020 (Old history)',
        'desc': isVi
            ? 'Xem tất cả giao dịch thuộc năm 2020'
            : 'View all transactions from 2020',
        'icon': Icons.history_toggle_off_rounded,
      },
      {
        'key': 'custom',
        'title': isVi ? 'Khoảng ngày tùy chọn...' : 'Custom date range...',
        'desc': isVi
            ? 'Tự chọn ngày bắt đầu & kết thúc'
            : 'Select custom start & end date',
        'icon': Icons.edit_calendar_rounded,
      },
      {
        'key': 'all_time',
        'title': isVi ? 'Tất cả thời gian' : 'All time',
        'desc': isVi
            ? 'Không giới hạn ngày giao dịch'
            : 'No date limit for transactions',
        'icon': Icons.all_inclusive_rounded,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: context.cardBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: context.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('transaction_time_range'),
                      style:
                          (context.textTheme.titleMedium ?? const TextStyle())
                              .copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimaryColor,
                                letterSpacing: -0.3,
                              ),
                    ),
                    if (_datePreset != 'all_time')
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _applyDatePreset('all_time'));
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          context.tr('clear_date_filter'),
                          style: TextStyle(
                            color: context.brandColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: presets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = presets[index];
                      final key = p['key'] as String;
                      final isSelected = _datePreset == key;

                      return AnimatedScaleButton(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          if (key == 'custom') {
                            Navigator.pop(ctx);
                            final now = DateTime.now();
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(
                                now.year,
                                now.month,
                                now.day,
                                23,
                                59,
                                59,
                              ),
                              initialDateRange:
                                  _selectedDateRange ??
                                  DateTimeRange(
                                    start: DateTime(now.year, now.month, 1),
                                    end: DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      23,
                                      59,
                                      59,
                                    ),
                                  ),
                            );
                            if (range != null) {
                              setState(() {
                                _datePreset = 'custom';
                                _selectedDateRange = range;
                              });
                            }
                          } else {
                            setState(() => _applyDatePreset(key));
                            Navigator.pop(ctx);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.brandColor.withValues(alpha: 0.12)
                                : context.inputBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? context.brandColor
                                  : context.borderColor,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? context.brandColor
                                      : context.cardBgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p['icon'] as IconData,
                                  size: 19,
                                  color: isSelected
                                      ? Colors.white
                                      : context.brandColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title'] as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? context.textPrimaryColor
                                            : context.textSecondaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textMutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: context.brandColor,
                                  size: 22,
                                ),
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
      },
    );
  }

  // BỘ LỌC BOTTOM SHEET TỔNG HỢP
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              decoration: BoxDecoration(
                color: context.cardBgColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: context.dividerColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('filter_transactions'),
                          style:
                              (context.textTheme.titleMedium ??
                                      const TextStyle())
                                  .copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimaryColor,
                                  ),
                        ),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setModalState(() {
                              _selectedType = 'Tất cả';
                              _applyDatePreset('all_time');
                            });
                            setState(() {});
                          },
                          child: Text(
                            context.tr('reset_filter'),
                            style: TextStyle(
                              color: context.brandColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. LỌC THEO LOẠI HÌNH
                    Text(
                      context.tr('transaction_type'),
                      style: (context.textTheme.titleSmall ?? const TextStyle())
                          .copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimaryColor,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Tất cả', 'Thu nhập', 'Chi tiêu', 'Chuyển ví']
                          .map((tp) {
                            final isSelected = _selectedType == tp;
                            return Expanded(
                              child: AnimatedScaleButton(
                                scaleDown: 0.95,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => _selectedType = tp);
                                  setState(() {});
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.brandColor
                                        : context.inputBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.brandColor
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      tp == 'Tất cả'
                                          ? context.tr('filter_all')
                                          : (tp == 'Thu nhập'
                                                ? context.tr('filter_income')
                                                : (tp == 'Chi tiêu'
                                                      ? context.tr(
                                                          'filter_expense',
                                                        )
                                                      : context.tr(
                                                          'filter_transfers',
                                                        ))),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isSelected
                                            ? Colors.white
                                            : context.textSecondaryColor,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),

                    const SizedBox(height: 22),

                    // 2. LỌC THEO THỜI GIAN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('time_range'),
                          style:
                              (context.textTheme.titleSmall ??
                                      const TextStyle())
                                  .copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimaryColor,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _getDateFilterLabel(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.brandColor,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            {
                              'k': 'month_to_date',
                              'label': context.tr('preset_month_to_date'),
                            },
                            {'k': 'today', 'label': context.tr('preset_today')},
                            {
                              'k': 'last_7_days',
                              'label': context.tr('preset_last_7_days'),
                            },
                            {
                              'k': 'last_30_days',
                              'label': context.tr('preset_last_30_days'),
                            },
                            {
                              'k': 'this_month',
                              'label': context.tr('preset_this_month'),
                            },
                            {
                              'k': 'last_month',
                              'label': context.tr('preset_last_month'),
                            },
                            {
                              'k': 'all_time',
                              'label': context.tr('filter_all'),
                            },
                          ].map((item) {
                            final key = item['k']!;
                            final isSel = _datePreset == key;
                            return AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => _applyDatePreset(key));
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? context.brandColor
                                      : context.inputBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel
                                        ? context.brandColor
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  item['label']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? Colors.white
                                        : context.textSecondaryColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(
                            now.year,
                            now.month,
                            now.day,
                            23,
                            59,
                            59,
                          ),
                          initialDateRange:
                              _selectedDateRange ??
                              DateTimeRange(
                                start: DateTime(now.year, now.month, 1),
                                end: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  23,
                                  59,
                                  59,
                                ),
                              ),
                        );
                        if (range != null) {
                          setModalState(() {
                            _datePreset = 'custom';
                            _selectedDateRange = range;
                          });
                          setState(() {});
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 18,
                              color: context.brandColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _datePreset == 'custom' &&
                                        _selectedDateRange != null
                                    ? '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}'
                                    : context.tr('specific_date_range'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimaryColor,
                                  fontWeight: _datePreset == 'custom'
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: context.textMutedColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // NÚT HOÀN TẤT
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.brandColor,
                              context.brandColor.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: context.brandColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          context.tr('apply_filter'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Nhóm giao dịch theo ngày
  Map<DateTime, List<TransactionModel>> _groupByDate(
    List<TransactionModel> transactions,
  ) {
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (var tx in transactions) {
      final key = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  String _formatFriendlyDate(DateTime date, bool isVi) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    if (diffDays == 0) {
      return isVi ? 'Hôm nay, $dateStr' : 'Today, $dateStr';
    } else if (diffDays == 1) {
      return isVi ? 'Hôm qua, $dateStr' : 'Yesterday, $dateStr';
    } else {
      final weekdaysVi = [
        'Thứ 2',
        'Thứ 3',
        'Thứ 4',
        'Thứ 5',
        'Thứ 6',
        'Thứ 7',
        'Chủ nhật',
      ];
      final weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weekdayStr = isVi
          ? weekdaysVi[date.weekday - 1]
          : weekdaysEn[date.weekday - 1];
      return '$weekdayStr, $dateStr';
    }
  }

  Widget _buildSearchIndicatorBadge(int count, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.brandColor.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 16, color: context.brandColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVi
                  ? 'Tìm thấy $count giao dịch trong toàn bộ lịch sử'
                  : 'Found $count transactions in all history',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.brandColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowSummaryCard(
    double totalIncome,
    double totalExpense,
    bool isDark,
  ) {
    final double net = totalIncome - totalExpense;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Thu nhập
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 13,
                      color: context.income,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr('total_income'),
                        style:
                            (context.textTheme.bodySmall ?? const TextStyle())
                                .copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondaryColor,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+${CurrencyUtils.formatCurrency(totalIncome)}',
                    style: (context.textTheme.titleMedium ?? const TextStyle())
                        .copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.income,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: context.dividerColor,
          ),
          // Chi tiêu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 13,
                      color: context.expense,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr('total_expense'),
                        style:
                            (context.textTheme.bodySmall ?? const TextStyle())
                                .copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondaryColor,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '-${CurrencyUtils.formatCurrency(totalExpense)}',
                    style: (context.textTheme.titleMedium ?? const TextStyle())
                        .copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.expense,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: context.dividerColor,
          ),
          // Dòng tiền ròng (Net)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      net >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: net >= 0 ? context.income : context.expense,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        context.tr('net_cashflow'),
                        style:
                            (context.textTheme.bodySmall ?? const TextStyle())
                                .copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondaryColor,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${net >= 0 ? '+' : ''}${CurrencyUtils.formatCurrency(net)}',
                    style: (context.textTheme.titleMedium ?? const TextStyle())
                        .copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: net >= 0 ? context.income : context.expense,
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
        final isVi = LanguageScope.of(context).isVietnamese;
        final now = DateTime.now();
        final isToday =
            (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day);
        final dateLabel = _formatFriendlyDate(date, isVi);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isToday
                      ? context.brandColor.withValues(alpha: 0.16)
                      : context.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
                  size: 13,
                  color: isToday
                      ? context.brandColor
                      : context.textSecondaryColor,
                ),
              ),
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dailyIncome > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
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
                      Icon(
                        Icons.arrow_downward_rounded,
                        size: 10,
                        color: context.income,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '+${CurrencyUtils.formatCurrency(dailyIncome)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.income,
                        ),
                      ),
                    ],
                  ),
                ),
              if (dailyExpense > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: context.expense.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: context.expense.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 10,
                        color: context.expense,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '-${CurrencyUtils.formatCurrency(dailyExpense)}',
                        style: TextStyle(
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
        );
      },
    );
  }
}

/// Helper model ảo hóa phẳng (Flattened Virtual List Row) cho danh sách lịch sử giao dịch
class _TxHistoryRow {
  final bool isHeader;
  final DateTime date;
  final List<TransactionModel>? dailyTxs;
  final TransactionModel? tx;
  final WalletModel? wallet;
  final double? runningTotal;
  final int globalIndex;

  _TxHistoryRow.header({required this.date, required this.dailyTxs})
    : isHeader = true,
      tx = null,
      wallet = null,
      runningTotal = null,
      globalIndex = 0;

  _TxHistoryRow.transaction({
    required this.tx,
    required this.wallet,
    required this.runningTotal,
    required this.globalIndex,
  }) : isHeader = false,
       date = DateTime.fromMillisecondsSinceEpoch(0),
       dailyTxs = null;
}
