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
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case 'last_30_days':
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
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
        return 'Đầu tháng đến nay';
      case 'today':
        return 'Hôm nay';
      case 'last_7_days':
        return '7 ngày qua';
      case 'last_30_days':
        return '30 ngày qua';
      case 'this_month':
        return 'Tháng này';
      case 'last_month':
        return 'Tháng trước';
      case 'all_time':
        return 'Tất cả thời gian';
      case 'custom':
      default:
        if (_selectedDateRange == null) return 'Tất cả thời gian';
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1817) : const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F2625), const Color(0xFF0A1817)]
                : [const Color(0xFF438883), const Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.28],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ════════ TOP APP BAR (FINTECH GLASSMORPHISM) ════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
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
                    const Text(
                      'Lịch Sử Giao Dịch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Row(
                      children: [
                        AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(context, PageTransitions.slideRight(const CalendarTrackingScreen()));
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 1.0,
                              ),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (_selectedType != 'Tất cả' || _selectedDateRange != null)
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 1.0,
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: (_selectedType != 'Tất cả' || _selectedDateRange != null)
                                  ? const Color(0xFF438883)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ════════ SEARCH BOX KÍNH MỜ ════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo nội dung, danh mục, số tiền...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
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
                    if (_selectedType != 'Tất cả' || _datePreset != 'all_time' || _searchQuery.isNotEmpty)
                      AnimatedScaleButton(
                        onTap: _resetFilters,
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, size: 14, color: Colors.redAccent),
                              SizedBox(width: 4),
                              Text('Xóa lọc', style: TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    child: StreamBuilder<List<TransactionModel>>(
                      stream: _txRepo.getTransactionsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                        }

                        // 1. ÁP DỤNG BỘ LỌC
                        List<TransactionModel> transactions = snapshot.data ?? [];
                        transactions.sort(CurrencyUtils.compareTransactionsChronological);

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

                        // Lọc theo Search Query
                        if (_searchQuery.isNotEmpty) {
                          transactions = transactions.where((tx) {
                            final desc = tx.description.toLowerCase();
                            final cat = tx.category.toLowerCase();
                            final amt = tx.amount.toString();
                            return desc.contains(_searchQuery) || cat.contains(_searchQuery) || amt.contains(_searchQuery);
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
                                Icon(Icons.search_off_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'Không tìm thấy giao dịch "$_searchQuery"'
                                      : 'Không tìm thấy giao dịch nào',
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ════════ CASHFLOW MINI SUMMARY CARD ════════
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF152423) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                                  ),
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: const [
                                            Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF2ECC71)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tổng Thu',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+${CurrencyUtils.formatCurrency(totalIncome)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2ECC71),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: 1,
                                      height: 32,
                                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: const [
                                            Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFE63946)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Tổng Chi',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '-${CurrencyUtils.formatCurrency(totalExpense)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFE63946),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // DANH SÁCH THEO NGÀY
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
                                      showDate: false,
                                      runningTotal: reverseBalances[txEntry.value.id],
                                      wallet: txWallet,
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                              ]),
                              const SizedBox(height: 36),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTypeChip(String label, bool isDark) {
    final isSelected = _selectedType == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedType = label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? const Color(0xFF438883) : Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: hasFilter ? Colors.white : Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasFilter ? Colors.white : Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 14,
                color: hasFilter ? const Color(0xFF438883) : Colors.white,
              ),
              const SizedBox(width: 5),
              Text(
                _getDateFilterLabel(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w600,
                  color: hasFilter ? const Color(0xFF438883) : Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: hasFilter ? const Color(0xFF438883) : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // BOTTOM SHEET CHỌN NHANH KHOẢNG THỜI GIAN FINTECH
  void _showDatePresetPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presets = [
      {'key': 'month_to_date', 'title': 'Từ đầu tháng đến nay', 'desc': 'Ngày 01 đến hôm nay (Khuyên dùng)', 'icon': Icons.trending_up_rounded},
      {'key': 'today', 'title': 'Hôm nay', 'desc': 'Giao dịch phát sinh trong ngày', 'icon': Icons.today_rounded},
      {'key': 'last_7_days', 'title': '7 ngày qua', 'desc': '7 ngày gần nhất tính đến nay', 'icon': Icons.date_range_rounded},
      {'key': 'last_30_days', 'title': '30 ngày qua', 'desc': '30 ngày gần nhất tính đến nay', 'icon': Icons.calendar_view_day_rounded},
      {'key': 'this_month', 'title': 'Tháng này', 'desc': 'Toàn bộ các ngày trong tháng hiện tại', 'icon': Icons.calendar_month_rounded},
      {'key': 'last_month', 'title': 'Tháng trước', 'desc': 'Toàn bộ các ngày của tháng vừa qua', 'icon': Icons.history_rounded},
      {'key': 'custom', 'title': 'Khoảng ngày tùy chọn...', 'desc': 'Tự chọn ngày bắt đầu & kết thúc', 'icon': Icons.edit_calendar_rounded},
      {'key': 'all_time', 'title': 'Tất cả thời gian', 'desc': 'Không giới hạn ngày giao dịch', 'icon': Icons.all_inclusive_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF142423) : Colors.white,
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Khoảng thời gian giao dịch',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                        child: const Text('Bỏ lọc ngày', style: TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
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
                              lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                              initialDateRange: _selectedDateRange ??
                                  DateTimeRange(
                                    start: DateTime(now.year, now.month, 1),
                                    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A37) : const Color(0xFFE8F5F1))
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF438883)
                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                                      ? const Color(0xFF438883)
                                      : (isDark ? Colors.white10 : Colors.white),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p['icon'] as IconData,
                                  size: 19,
                                  color: isSelected ? Colors.white : const Color(0xFF438883),
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
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF438883),
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF142423) : Colors.white,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bộ lọc giao dịch',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                          child: const Text('Đặt lại', style: TextStyle(color: Color(0xFF438883), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 1. LỌC THEO LOẠI HÌNH
                    const Text('Loại giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Tất cả', 'Thu nhập', 'Chi tiêu', 'Chuyển ví'].map((tp) {
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
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF438883)
                                    : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF438883) : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  tp,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 22),
                    
                    // 2. LỌC THEO THỜI GIAN
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Khoảng thời gian', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(
                          _getDateFilterLabel(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF438883), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'k': 'month_to_date', 'label': 'Đầu tháng đến nay'},
                        {'k': 'today', 'label': 'Hôm nay'},
                        {'k': 'last_7_days', 'label': '7 ngày qua'},
                        {'k': 'last_30_days', 'label': '30 ngày qua'},
                        {'k': 'this_month', 'label': 'Tháng này'},
                        {'k': 'last_month', 'label': 'Tháng trước'},
                        {'k': 'all_time', 'label': 'Tất cả'},
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF438883)
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF438883) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              item['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
                          lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
                          initialDateRange: _selectedDateRange ??
                              DateTimeRange(
                                start: DateTime(now.year, now.month, 1),
                                end: DateTime(now.year, now.month, now.day, 23, 59, 59),
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
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF438883)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _datePreset == 'custom' && _selectedDateRange != null
                                    ? '${CurrencyUtils.formatDate(_selectedDateRange!.start)} - ${CurrencyUtils.formatDate(_selectedDateRange!.end)}'
                                    : 'Tùy chọn khoảng ngày cụ thể...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  fontWeight: _datePreset == 'custom' ? FontWeight.w700 : FontWeight.normal,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF438883), Color(0xFF2DD4BF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF438883).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text('Xem kết quả', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
