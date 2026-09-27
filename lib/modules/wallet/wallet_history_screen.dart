import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/transaction_item.dart';
import '../../services/auth_service.dart';

/// Trang chuyên sâu dành riêng cho lịch sử giao dịch và dòng tiền của các ví.
/// Hỗ trợ lọc theo từng ví cụ thể, theo loại (thu/chi/chuyển tiền),
/// theo danh mục, theo thời gian (tháng, hôm nay, tuần này, khoảng ngày tùy chọn, tất cả thời gian)
/// và tìm kiếm từ khóa theo thời gian thực.
class WalletHistoryScreen extends StatefulWidget {
  final String? initialWalletId;

  const WalletHistoryScreen({
    super.key,
    this.initialWalletId,
  });

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  late String? _selectedWalletId;
  String _selectedTxType = 'all'; // 'all', 'expense', 'income', 'transfer'
  String _timeFilterMode = 'month'; // 'month', 'today', 'week', 'custom', 'all_time'
  DateTimeRange? _customDateRange;
  String? _selectedCategoryFilter;
  late DateTime _selectedMonth;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<WalletModel> _cachedWallets = [];

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.initialWalletId;
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      _txRepo.setUid(uid);
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedWalletId = widget.initialWalletId;
      _selectedTxType = 'all';
      _timeFilterMode = 'month';
      _customDateRange = null;
      _selectedCategoryFilter = null;
      _searchController.clear();
      _searchQuery = '';
      final now = DateTime.now();
      _selectedMonth = DateTime(now.year, now.month);
    });
  }

  bool get _hasActiveFilters {
    return _selectedWalletId != widget.initialWalletId ||
        _selectedTxType != 'all' ||
        _timeFilterMode != 'month' ||
        _selectedCategoryFilter != null ||
        _searchQuery.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === 1. TOP APP BAR ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getHeaderTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _getHeaderSubtitle(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    AnimatedScaleButton(
                      onTap: _resetFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Đặt lại',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // === 2. THANH TÌM KIẾM GIAO DỊCH ===
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF163230) : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên món, ghi chú, danh mục...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),

            // === 3. NỘI DUNG CHÍNH (CONTAINER BO TRÒN TRẮNG/TỐI) ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: StreamBuilder<List<WalletModel>>(
                  stream: _walletRepo.getWalletsStream(),
                  builder: (context, walletSnapshot) {
                    final wallets = walletSnapshot.data ?? _cachedWallets;
                    if (wallets.isNotEmpty) {
                      _cachedWallets = wallets;
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        // 3.1. Smart Ergonomic Filter Bar (1 hàng điều khiển thông minh tối ưu Thumb Zone)
                        _buildSmartErgonomicFilterBar(wallets, isDark),
                        const SizedBox(height: 4),

                        // 3.2. Dòng hiển thị Chips bộ lọc đang áp dụng (nếu có)
                        _buildActiveFilterChips(isDark),

                        // 3.5. Danh sách giao dịch Realtime
                        Expanded(
                          child: StreamBuilder<List<TransactionModel>>(
                            stream: _txRepo.getTransactionsStream(),
                            builder: (context, txSnapshot) {
                              if (txSnapshot.connectionState == ConnectionState.waiting && !txSnapshot.hasData) {
                                return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                              }

                              final allTx = txSnapshot.data ?? [];
                              final filteredTx = _applyFilters(allTx);
                              filteredTx.sort(CurrencyUtils.compareTransactionsChronological);

                              // Tính toán tổng kết dòng tiền & phân loại danh mục
                              final summary = _calculateSummary(filteredTx);
                              final breakdown = _getCategoryBreakdown(filteredTx);

                              final effectiveWallets = _cachedWallets.isNotEmpty
                                  ? _cachedWallets
                                  : _walletRepo.latestWallets;

                              final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                                allTransactions: allTx,
                                wallets: effectiveWallets,
                              );

                              final grouped = _groupByDate(filteredTx);

                              return CustomScrollView(
                                key: const PageStorageKey('wallet_history_scroll'),
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  // Tóm tắt dòng tiền Thu/Chi/Ròng
                                  SliverToBoxAdapter(
                                    child: _buildCashflowSummaryBar(summary.income, summary.expense, summary.net, isDark),
                                  ),

                                  // Phân loại danh mục theo ví
                                  if (breakdown.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: _buildCategoryBreakdownSection(breakdown, isDark),
                                    ),

                                  // Danh sách giao dịch hoặc Empty state
                                  if (filteredTx.isEmpty)
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: _buildEmptyState(isDark),
                                    )
                                  else
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final date = grouped.keys.elementAt(index);
                                            final txs = grouped[date]!;
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildDateHeader(date, txs, isDark),
                                                ...txs.asMap().entries.map((e) {
                                                  final tx = e.value;
                                                  WalletModel? txWallet;
                                                  try {
                                                    txWallet = effectiveWallets.firstWhere((w) => w.id == tx.walletId);
                                                  } catch (_) {}
                                                  return StaggeredListItem(
                                                    index: e.key,
                                                    child: TransactionItem(
                                                      transaction: tx,
                                                      showDate: false,
                                                      runningTotal: reverseBalances[tx.id],
                                                      wallet: txWallet,
                                                    ),
                                                  );
                                                }),
                                              ],
                                            );
                                          },
                                          childCount: grouped.keys.length,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
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

  // === CÁC TIÊU ĐỀ HEADER ===
  String _getHeaderTitle() {
    if (_selectedWalletId == null) {
      return 'Lịch sử thu / chi tất cả ví';
    }
    final wallet = _cachedWallets.cast<WalletModel?>().firstWhere(
          (w) => w?.id == _selectedWalletId,
          orElse: () => null,
        );
    if (wallet != null) {
      return 'Lịch sử: ${wallet.name}';
    }
    return 'Lịch sử thu / chi';
  }

  String _getHeaderSubtitle() {
    if (_selectedWalletId == null) {
      final count = _cachedWallets.length;
      return '$count ví đang hoạt động';
    }
    final wallet = _cachedWallets.cast<WalletModel?>().firstWhere(
          (w) => w?.id == _selectedWalletId,
          orElse: () => null,
        );
    if (wallet != null) {
      return 'Số dư hiện tại: ${CurrencyUtils.formatCurrency(wallet.balance)}';
    }
    return 'Theo dõi dòng tiền thu chi';
  }

  // === SMART ERGONOMIC FILTER BAR (1 HÀNG DUY NHẤT TỐI ƯU THUMB ZONE) ===
  Widget _buildSmartErgonomicFilterBar(List<WalletModel> wallets, bool isDark) {
    WalletModel? curWallet;
    if (_selectedWalletId != null) {
      try {
        curWallet = wallets.firstWhere((w) => w.id == _selectedWalletId);
      } catch (_) {}
    }
    final walletLabel = curWallet?.name ?? 'Tất cả ví';

    final types = [
      {'key': 'all', 'label': 'Tất cả'},
      {'key': 'expense', 'label': 'Chi tiêu'},
      {'key': 'income', 'label': 'Thu nhập'},
      {'key': 'transfer', 'label': 'Chuyển ví'},
    ];

    String timeLabel;
    if (_timeFilterMode == 'month_to_date') {
      timeLabel = 'Đầu tháng đến nay';
    } else if (_timeFilterMode == 'today') {
      timeLabel = 'Hôm nay';
    } else if (_timeFilterMode == 'last_7_days') {
      timeLabel = '7 ngày qua';
    } else if (_timeFilterMode == 'last_30_days') {
      timeLabel = '30 ngày qua';
    } else if (_timeFilterMode == 'last_month') {
      timeLabel = 'Tháng trước';
    } else if (_timeFilterMode == 'month') {
      timeLabel = 'Tháng ${DateFormat('MM/yy').format(_selectedMonth)}';
    } else if (_timeFilterMode == 'week') {
      timeLabel = 'Tuần này';
    } else if (_timeFilterMode == 'custom' && _customDateRange != null) {
      timeLabel = '${DateFormat('dd/MM').format(_customDateRange!.start)}-${DateFormat('dd/MM').format(_customDateRange!.end)}';
    } else {
      timeLabel = 'Tất cả time';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. Pill Ví (Chạm vào mở Thumb-Zone Sheet chọn ví)
                  AnimatedScaleButton(
                    scaleDown: 0.94,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showWalletPickerSheet(context, wallets, isDark);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedWalletId != null
                            ? const Color(0xFF438883)
                            : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFE8F5F1)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedWalletId != null
                              ? Colors.transparent
                              : (isDark ? Colors.white12 : const Color(0xFFD0E6E1)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            curWallet?.icon ?? Icons.account_balance_wallet_rounded,
                            size: 14,
                            color: _selectedWalletId != null
                                ? Colors.white
                                : (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            walletLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedWalletId != null
                                  ? Colors.white
                                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: _selectedWalletId != null
                                ? Colors.white70
                                : (isDark ? Colors.white60 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Các Pill Loại Giao dịch (Tất cả, Chi tiêu, Thu nhập, Chuyển ví)
                  ...types.map((t) {
                    final isSel = _selectedTxType == t['key'];
                    return AnimatedScaleButton(
                      scaleDown: 0.94,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTxType = t['key']!;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
                              : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          t['label']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel
                                ? (isDark ? const Color(0xFF0F2625) : Colors.white)
                                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Pill Thời gian / Tháng
                  AnimatedScaleButton(
                    scaleDown: 0.94,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (_timeFilterMode == 'month') {
                        _showMonthPickerSheet(context);
                      } else {
                        _showAdvancedTimeFilterSheet(context, isDark);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFE8F5F1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFD0E6E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Action Pill "Bộ lọc" (Ghim cố định bên phải tầm với ngón tay cái)
          AnimatedScaleButton(
            scaleDown: 0.94,
            onTap: () {
              HapticFeedback.selectionClick();
              _showErgonomicFilterSheet(context, isDark);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _hasActiveFilters
                    ? const Color(0xFF438883)
                    : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFE8F5F1)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasActiveFilters
                      ? Colors.transparent
                      : (isDark ? Colors.white12 : const Color(0xFFD0E6E1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: _hasActiveFilters
                        ? Colors.white
                        : (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bộ lọc',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _hasActiveFilters
                          ? Colors.white
                          : (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === BOTTOM SHEET CHỌN VÍ TIỀN (THUMB ZONE) ===
  void _showWalletPickerSheet(BuildContext context, List<WalletModel> wallets, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162523) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
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
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chọn ví xem lịch sử',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Tất cả ví
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF438883), size: 20),
                        ),
                        title: Text(
                          'Tất cả ví',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          '${wallets.length} ví hoạt động',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: _selectedWalletId == null
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF438883), size: 20)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedWalletId = null;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      const Divider(height: 8),
                      // Từng ví cụ thể
                      ...wallets.map((w) {
                        final isSelected = _selectedWalletId == w.id;
                        final wColor = Color(w.colorValue);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: wColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(w.icon, color: wColor, size: 20),
                          ),
                          title: Text(
                            w.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            CurrencyUtils.formatCurrency(w.balance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: wColor, size: 20)
                              : null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedWalletId = w.id;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // === BOTTOM SHEET BỘ LỌC CÔNG THÁI HỌC (THUMB-ZONE FILTER SHEET) ===
  void _showErgonomicFilterSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF162523) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 18, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                              const SizedBox(width: 8),
                              Text(
                                'Bộ lọc nâng cao',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          if (_hasActiveFilters)
                            GestureDetector(
                              onTap: () {
                                _resetFilters();
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                'Đặt lại tất cả',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 1. Khoảng thời gian
                      Text(
                        'Khoảng thời gian',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterSheetTimeChip('Tháng này', 'month', isDark, setSheetState, () {
                            final now = DateTime.now();
                            setState(() {
                              _timeFilterMode = 'month';
                              _selectedMonth = DateTime(now.year, now.month);
                              _customDateRange = null;
                            });
                          }),
                          _buildFilterSheetTimeChip('Hôm nay', 'today', isDark, setSheetState, () {
                            setState(() {
                              _timeFilterMode = 'today';
                              _customDateRange = null;
                            });
                          }),
                          _buildFilterSheetTimeChip('Tuần này', 'week', isDark, setSheetState, () {
                            setState(() {
                              _timeFilterMode = 'week';
                              _customDateRange = null;
                            });
                          }),
                          _buildFilterSheetTimeChip('Tất cả thời gian', 'all_time', isDark, setSheetState, () {
                            setState(() {
                              _timeFilterMode = 'all_time';
                              _customDateRange = null;
                            });
                          }),
                          _buildFilterSheetTimeChip(
                            _customDateRange != null
                                ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                : 'Tùy chọn ngày...',
                            'custom',
                            isDark,
                            setSheetState,
                            () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange: _customDateRange ??
                                    DateTimeRange(
                                      start: DateTime.now().subtract(const Duration(days: 7)),
                                      end: DateTime.now(),
                                    ),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF438883),
                                        onPrimary: Colors.white,
                                        onSurface: Color(0xFF1E293B),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _timeFilterMode = 'custom';
                                  _customDateRange = picked;
                                });
                                setSheetState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 2. Loại giao dịch
                      Text(
                        'Loại giao dịch',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          {'key': 'all', 'label': 'Tất cả'},
                          {'key': 'expense', 'label': 'Chi tiêu'},
                          {'key': 'income', 'label': 'Thu nhập'},
                          {'key': 'transfer', 'label': 'Chuyển ví'},
                        ].map((t) {
                          final isSel = _selectedTxType == t['key'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedTxType = t['key']!;
                                });
                                setSheetState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
                                      : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t['label']!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel
                                        ? (isDark ? const Color(0xFF0F2625) : Colors.white)
                                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 26),

                      // Nút Đóng / Áp dụng
                      AnimatedScaleButton(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF438883), Color(0xFF2DD4BF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
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
                          child: const Text(
                            'Áp dụng bộ lọc',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSheetTimeChip(
    String label,
    String modeKey,
    bool isDark,
    StateSetter setSheetState,
    VoidCallback onSelect,
  ) {
    final isSelected = _timeFilterMode == modeKey;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
        setSheetState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883))
              : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // === ACTIVE FILTER CHIPS ===
  Widget _buildActiveFilterChips(bool isDark) {
    if (_timeFilterMode == 'month' && _selectedCategoryFilter == null && _searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
      child: Row(
        children: [
          if (_timeFilterMode != 'month')
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range_rounded, size: 12, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                  const SizedBox(width: 4),
                  Text(
                    _timeFilterMode == 'month_to_date'
                        ? 'Đầu tháng đến nay'
                        : _timeFilterMode == 'today'
                            ? 'Hôm nay'
                            : _timeFilterMode == 'last_7_days'
                                ? '7 ngày qua'
                                : _timeFilterMode == 'last_30_days'
                                    ? '30 ngày qua'
                                    : _timeFilterMode == 'last_month'
                                        ? 'Tháng trước'
                                        : _timeFilterMode == 'week'
                                            ? 'Tuần này'
                                            : _timeFilterMode == 'custom' && _customDateRange != null
                                                ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                                : 'Tất cả thời gian',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                  ),
                  const SizedBox(width: 3),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _timeFilterMode = 'month';
                        _customDateRange = null;
                      });
                    },
                    child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF438883)),
                  ),
                ],
              ),
            ),
          if (_selectedCategoryFilter != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CategoryUtils.getCategoryIcon(_selectedCategoryFilter!), size: 12, color: const Color(0xFF3A86FF)),
                  const SizedBox(width: 4),
                  Text(
                    _selectedCategoryFilter!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3A86FF)),
                  ),
                  const SizedBox(width: 3),
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategoryFilter = null),
                    child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFF3A86FF)),
                  ),
                ],
              ),
            ),
          if (_searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE07A5F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, size: 12, color: Color(0xFFE07A5F)),
                  const SizedBox(width: 4),
                  Text(
                    '"$_searchQuery"',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE07A5F)),
                  ),
                  const SizedBox(width: 3),
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFFE07A5F)),
                  ),
                ],
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _resetFilters,
            child: Text(
              'Đặt lại',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === TÓM TẮT THU - CHI - RÒNG (MINI CASHFLOW GLANCE BAR) ===
  Widget _buildCashflowSummaryBar(double income, double expense, double net, bool isDark) {
    final totalFlow = income + expense;
    final incomePercent = totalFlow > 0 ? (income / totalFlow) : 0.5;
    final expensePercent = totalFlow > 0 ? (expense / totalFlow) : 0.5;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162523) : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryColumn('Thu nhập', income, const Color(0xFF2E7D32), isDark),
              Container(height: 22, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
              _buildSummaryColumn('Chi tiêu', expense, const Color(0xFFD32F2F), isDark),
              Container(height: 22, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
              _buildSummaryColumn(
                'Dòng tiền ròng',
                net,
                net >= 0
                    ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32))
                    : (isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F)),
                isDark,
              ),
            ],
          ),
          if (totalFlow > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                child: Row(
                  children: [
                    Flexible(
                      flex: (incomePercent * 100).round().clamp(1, 99),
                      child: Container(color: const Color(0xFF2E7D32)),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      flex: (expensePercent * 100).round().clamp(1, 99),
                      child: Container(color: const Color(0xFFD32F2F)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String title, double amount, Color valueColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // === PHÂN LOẠI DANH MỤC THEO VÍ ===
  Widget _buildCategoryBreakdownSection(List<MapEntry<String, double>> breakdown, bool isDark) {
    final total = breakdown.fold<double>(0, (sum, item) => sum + item.value);

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162523) : const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5EBE9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedTxType == 'income'
                    ? 'Phân loại nguồn thu'
                    : 'Phân loại chi tiêu',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF333333),
                ),
              ),
              if (_selectedCategoryFilter != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryFilter = null),
                  child: Text(
                    'Xem tất cả',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: breakdown.map((entry) {
                final cat = entry.key;
                final amount = entry.value;
                final percent = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0';
                final isCatSelected = _selectedCategoryFilter == cat;
                final catColor = CategoryUtils.getVibrantColor(cat);

                return AnimatedScaleButton(
                  scaleDown: 0.94,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedCategoryFilter == cat) {
                        _selectedCategoryFilter = null;
                      } else {
                        _selectedCategoryFilter = cat;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isCatSelected
                          ? catColor
                          : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCatSelected ? Colors.transparent : catColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryUtils.getCategoryIcon(cat),
                          size: 13,
                          color: isCatSelected ? Colors.white : catColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$cat $percent%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                            color: isCatSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // === EMPTY STATE ===
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 52,
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không tìm thấy giao dịch nào khớp với "$_searchQuery"'
                  : 'Không có giao dịch nào phù hợp bộ lọc',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedScaleButton(
              onTap: _resetFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF438883).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF438883)),
                    SizedBox(width: 6),
                    Text(
                      'Xem tất cả giao dịch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF438883),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === BỘ LỌC GIAO DỊCH ===
  List<TransactionModel> _applyFilters(List<TransactionModel> txs) {
    return txs.where((tx) {
      // 1. Lọc theo Ví được chọn
      if (_selectedWalletId != null) {
        if (tx.walletId != _selectedWalletId) {
          return false;
        }
      }

      // 2. Lọc theo Loại giao dịch (Tất cả, Chi tiêu, Thu nhập, Chuyển ví)
      if (_selectedTxType != 'all') {
        if (_selectedTxType == 'transfer') {
          if (!tx.isTransfer) return false;
        } else if (_selectedTxType == 'expense') {
          if (tx.type != 'expense' || tx.isTransfer) return false;
        } else if (_selectedTxType == 'income') {
          if (tx.type != 'income' || tx.isTransfer) return false;
        }
      }

      // 3. Lọc theo Phân loại danh mục
      if (_selectedCategoryFilter != null) {
        if (tx.category != _selectedCategoryFilter) {
          return false;
        }
      }

      // 4. Lọc theo Tìm kiếm từ khóa
      if (_searchQuery.isNotEmpty) {
        final desc = tx.description.toLowerCase();
        final cat = tx.category.toLowerCase();
        final amountStr = tx.amount.toString();
        if (!desc.contains(_searchQuery) &&
            !cat.contains(_searchQuery) &&
            !amountStr.contains(_searchQuery)) {
          return false;
        }
      }

      // 5. Lọc theo Thời gian
      final date = tx.date;
      switch (_timeFilterMode) {
        case 'month_to_date':
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, 1);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          if (date.isBefore(start) || date.isAfter(end)) return false;
          break;
        case 'today':
          final now = DateTime.now();
          if (date.year != now.year || date.month != now.month || date.day != now.day) {
            return false;
          }
          break;
        case 'last_7_days':
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          if (date.isBefore(start) || date.isAfter(end)) return false;
          break;
        case 'last_30_days':
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          if (date.isBefore(start) || date.isAfter(end)) return false;
          break;
        case 'last_month':
          final now = DateTime.now();
          final start = DateTime(now.year, now.month - 1, 1);
          final end = DateTime(now.year, now.month, 0, 23, 59, 59);
          if (date.isBefore(start) || date.isAfter(end)) return false;
          break;
        case 'week':
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          final endDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 7, 23, 59, 59);
          if (date.isBefore(startDay) || date.isAfter(endDay)) {
            return false;
          }
          break;
        case 'custom':
          if (_customDateRange != null) {
            final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
            final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
            if (date.isBefore(start) || date.isAfter(end)) {
              return false;
            }
          }
          break;
        case 'all_time':
          break;
        case 'month':
        default:
          if (date.year != _selectedMonth.year || date.month != _selectedMonth.month) {
            return false;
          }
          break;
      }

      return true;
    }).toList();
  }

  ({double income, double expense, double net}) _calculateSummary(List<TransactionModel> txs) {
    double inc = 0.0;
    double exp = 0.0;

    for (final tx in txs) {
      if (tx.type == 'income') {
        inc += tx.amount;
      } else if (tx.type == 'expense') {
        exp += tx.amount;
      }
    }

    return (income: inc, expense: exp, net: inc - exp);
  }

  List<MapEntry<String, double>> _getCategoryBreakdown(List<TransactionModel> txs) {
    final Map<String, double> map = {};
    for (final tx in txs) {
      if (tx.isTransfer) continue;

      if (_selectedTxType == 'income') {
        if (tx.type == 'income') {
          map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
        }
      } else {
        if (tx.type == 'expense') {
          map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
        }
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  Map<DateTime, List<TransactionModel>> _groupByDate(List<TransactionModel> txs) {
    final Map<DateTime, List<TransactionModel>> groups = {};
    for (final tx in txs) {
      final dateKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!groups.containsKey(dateKey)) {
        groups[dateKey] = [];
      }
      groups[dateKey]!.add(tx);
    }
    return groups;
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) {
      return 'Hôm nay - ${DateFormat('dd/MM/yyyy').format(date)}';
    } else if (diff == 1) {
      return 'Hôm qua - ${DateFormat('dd/MM/yyyy').format(date)}';
    } else {
      final weekdayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
      final weekday = weekdayNames[date.weekday - 1];
      return '$weekday - ${DateFormat('dd/MM/yyyy').format(date)}';
    }
  }

  Widget _buildDateHeader(DateTime date, List<TransactionModel> txs, bool isDark) {
    double dayNet = 0.0;
    for (final tx in txs) {
      if (tx.type == 'income') {
        dayNet += tx.amount;
      } else if (tx.type == 'expense') {
        dayNet -= tx.amount;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatFriendlyDate(date),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
              letterSpacing: 0.2,
            ),
          ),
          Text(
            (dayNet > 0 ? '+' : '') + CurrencyUtils.formatCurrency(dayNet),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: dayNet > 0
                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32))
                  : dayNet < 0
                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F))
                      : (isDark ? Colors.white38 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }



  // === BOTTOM SHEET CHỌN THÁNG ===
  void _showMonthPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int tempYear = _selectedMonth.year;
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF162523) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chọn tháng',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF243332) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: isDark ? Colors.white70 : const Color(0xFF333333),
                                  size: 22,
                                ),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setSheetState(() => tempYear--);
                                },
                              ),
                              Text(
                                '$tempYear',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: tempYear >= now.year
                                      ? Colors.grey.withValues(alpha: 0.3)
                                      : (isDark ? Colors.white70 : const Color(0xFF333333)),
                                  size: 22,
                                ),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                padding: EdgeInsets.zero,
                                onPressed: tempYear >= now.year
                                    ? null
                                    : () {
                                        setSheetState(() => tempYear++);
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.2,
                      ),
                      itemBuilder: (context, i) {
                        final month = i + 1;
                        final isSel = _selectedMonth.year == tempYear && _selectedMonth.month == month;
                        final isFuture = (tempYear > now.year) || (tempYear == now.year && month > now.month);
                        final isCurrentMonth = (tempYear == now.year && month == now.month);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isFuture
                                ? null
                                : () {
                                    setState(() {
                                      _selectedMonth = DateTime(tempYear, month);
                                      _timeFilterMode = 'month';
                                      _customDateRange = null;
                                    });
                                    Navigator.pop(ctx);
                                  },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: isSel
                                    ? const LinearGradient(
                                        colors: [Color(0xFF438883), Color(0xFF2DD4BF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSel
                                    ? null
                                    : isFuture
                                        ? (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB))
                                        : (isDark ? const Color(0xFF243332) : const Color(0xFFF3F4F6)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSel
                                      ? Colors.transparent
                                      : isCurrentMonth
                                          ? const Color(0xFF438883).withValues(alpha: 0.5)
                                          : isFuture
                                              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200)
                                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                                  width: isCurrentMonth && !isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                'Tháng $month',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSel || isCurrentMonth ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel
                                      ? Colors.white
                                      : isFuture
                                          ? (isDark ? Colors.white24 : Colors.grey.shade400)
                                          : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  // === BOTTOM SHEET BỘ LỌC THỜI GIAN NÂNG CAO ===
  void _showAdvancedTimeFilterSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162523) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn phạm vi thời gian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTimeFilterOption('Từ đầu tháng đến nay', 'month_to_date', Icons.trending_up_rounded, isDark, ctx),
                _buildTimeFilterOption('Hôm nay', 'today', Icons.today_rounded, isDark, ctx),
                _buildTimeFilterOption('7 ngày qua', 'last_7_days', Icons.date_range_rounded, isDark, ctx),
                _buildTimeFilterOption('30 ngày qua', 'last_30_days', Icons.calendar_view_day_rounded, isDark, ctx),
                _buildTimeFilterOption('Tháng này (${DateFormat('MM/yyyy').format(DateTime.now())})', 'month', Icons.calendar_month_rounded, isDark, ctx, onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _timeFilterMode = 'month';
                    _selectedMonth = DateTime(now.year, now.month);
                    _customDateRange = null;
                  });
                  Navigator.pop(ctx);
                }),
                _buildTimeFilterOption('Tháng trước', 'last_month', Icons.history_rounded, isDark, ctx),
                _buildTimeFilterOption('Khoảng ngày tùy chọn...', 'custom', Icons.edit_calendar_rounded, isDark, ctx, onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _customDateRange ??
                        DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 7)),
                          end: DateTime.now(),
                        ),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF438883),
                            onPrimary: Colors.white,
                            onSurface: Color(0xFF1E293B),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _timeFilterMode = 'custom';
                      _customDateRange = picked;
                    });
                  }
                }),
                _buildTimeFilterOption('Tất cả thời gian', 'all_time', Icons.all_inclusive_rounded, isDark, ctx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeFilterOption(
    String label,
    String modeKey,
    IconData icon,
    bool isDark,
    BuildContext sheetCtx, {
    VoidCallback? onTap,
  }) {
    final isSelected = _timeFilterMode == modeKey;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
            : (isDark ? Colors.white60 : Colors.grey.shade600),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
              : (isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
              size: 20,
            )
          : null,
      onTap: onTap ??
          () {
            setState(() {
              _timeFilterMode = modeKey;
              _customDateRange = null;
            });
            Navigator.pop(sheetCtx);
          },
    );
  }
}
