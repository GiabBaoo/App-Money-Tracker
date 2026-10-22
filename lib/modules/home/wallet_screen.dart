import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/mono_dialog.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_balance_service.dart';
import '../../utils/page_transitions.dart';
import '../wallet/wallet_history_screen.dart';
import '../wallet/add_wallet_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool get isVi => LanguageService.instance.isVietnamese;
  final WalletRepository _walletRepo = WalletRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  late final ScrollController _scrollController;
  late final ScrollController _cardScrollController;
  late final ScrollController _pillsScrollController;
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  String? _selectedWalletId; // Ví được chọn (null = tất cả)
  List<WalletModel> _latestWallets = [];
  bool _isBalanceVisible = true; // Bật / tắt ẩn số dư tổng tài sản

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _cardScrollController = ScrollController();
    _pillsScrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      _txRepo.setUid(uid);
      _walletRepo.ensureDefaultWalletExists(uid);
      // Khôi phục số dư gốc ban đầu chuẩn xác (chỉ chạy 1 lần duy nhất nếu chưa khôi phục)
      TransactionBalanceService().restoreCorrectUserBaselineOnce(targetUid: uid);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrolled = _scrollController.offset > 120;
    // TỐI ƯU CỰC HẠN: Chỉ phát thông báo qua ValueNotifier cho riêng Sticky Header.
    // Hoàn toàn KHÔNG gọi setState() -> Triệt tiêu 100% hiện tượng khựng lag khi lướt lên lướt xuống.
    if (scrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = scrolled;
    }
  }

  void _scrollCardTo(int index) {
    if (_cardScrollController.hasClients) {
      const cardStep = 294.0;
      final maxOffset = _cardScrollController.position.maxScrollExtent;
      final target = (index * cardStep).clamp(0.0, maxOffset);
      _cardScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cardScrollController.dispose();
    _pillsScrollController.dispose();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = math.max(MediaQuery.paddingOf(context).top, MediaQuery.viewPaddingOf(context).top);
    final bottomInset = math.max(MediaQuery.paddingOf(context).bottom, MediaQuery.viewPaddingOf(context).bottom);
    final headerHeight = topPadding + 58.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. NỀN GRADIENT PHÍA TRÊN (CHUYỂN SẮC MỀM MẠI, HOÀN TOÀN KHÔNG CẮT NGANG)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF0F2625),
                            const Color(0xFF0F2625),
                            Theme.of(context).scaffoldBackgroundColor,
                          ]
                        : [
                            const Color(0xFF438883),
                            const Color(0xFF438883),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                    stops: const [0.0, 0.60, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. NỘI DUNG CUỘN THỐNG NHẤT
          SingleChildScrollView(
            controller: _scrollController,
            key: const PageStorageKey('wallet_unified_scroll'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              top: headerHeight + 6,
              bottom: (bottomInset > 0 ? bottomInset : 12) + 74, // Căn chuẩn sát mép trên Floating Navigation Bar (cao 74px), triệt tiêu khoảng trống thừa
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === 2.1. CỤM TỔNG TÀI SẢN & THAO TÁC CÔNG THÁI HỌC (THUMB ZONE) ===
                StreamBuilder<List<WalletModel>>(
                  stream: _walletRepo.getWalletsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF438883))),
                      );
                    }

                    final allWallets = snapshot.data ?? [];
                    _latestWallets = allWallets;
                    final totalBalance = allWallets.fold<double>(0.0, (sum, w) => sum + w.balance);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thẻ Hero Net Worth Card tích hợp Thanh phân bổ tài sản trực quan
                        _buildHeroNetWorthCard(context, totalBalance, allWallets, isDark),

                        // Thanh Chọn Ví một chạm (One-Thumb Selector Pills)
                        if (allWallets.isNotEmpty)
                          _buildWalletSelectorPills(allWallets, isDark),

                        const SizedBox(height: 6),

                        // Tiêu đề Carousel
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('account_cards'),
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  context.tr('accounts_count').replaceAll('{count}', allWallets.length.toString()),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Carousel thẻ ví nằm ngang mượt 120Hz (Bọc RepaintBoundary, loại bỏ Staggered thừa)
                        RepaintBoundary(
                          child: SizedBox(
                            height: 185,
                            child: ListView.builder(
                              controller: _cardScrollController,
                              key: const PageStorageKey('wallet_cards_list'),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              cacheExtent: 600,
                              itemCount: allWallets.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildAllWalletsCard(
                                    context,
                                    allWallets,
                                    totalBalance,
                                    _selectedWalletId == null,
                                    isDark,
                                  );
                                }
                                final wallet = allWallets[index - 1];
                                final isCurrentSelected = _selectedWalletId == wallet.id;
                                return _buildWalletCard(context, wallet, isCurrentSelected, isDark);
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 14),

                // 2.3. Thẻ tổng quan dòng tiền tháng này (gọn gàng, tinh tế)
                _buildMonthlyCashflowCard(isDark),

                const SizedBox(height: 16),

                // 2.4. Section Giao dịch gần đây (3-5 giao dịch)
                _buildRecentTransactionsSection(isDark),
              ],
            ),
          ),

          // 3. STICKY TOP APP BAR (FROSTED GLASSMORPHISM VỚI MINI BALANCE KHI CUỘN)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildStickyHeader(context, isDark, topPadding),
          ),

          // 4. ĐÃ BỎ FLOATING ACTION CAPSULE ĐÁY THEO YÊU CẦU TINH GIẢN (ĐÃ CÓ QUICK ACTION HUB 4 NÚT Ở TRÊN)
        ],
      ),
    );
  }

  // === STICKY TOP APP BAR (FROSTED GLASSMORPHISM & MINI BALANCE) ===
  Widget _buildStickyHeader(BuildContext context, bool isDark, double topPadding) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isScrolledNotifier,
      builder: (context, isScrolled, _) {
        return RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              top: topPadding + 6,
              bottom: 10,
              left: 18,
              right: 18,
            ),
            decoration: BoxDecoration(
              color: isScrolled
                  ? (isDark
                      ? const Color(0xF50F2625)
                      : const Color(0xF5438883))
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isScrolled
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              boxShadow: isScrolled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Trái: Khi ở trên cùng -> "Ví của bạn", Khi cuộn -> Mini Balance Pill
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: isScrolled
                      ? Align(
                          alignment: Alignment.centerLeft,
                          key: const ValueKey('sticky_mini_balance'),
                          child: StreamBuilder<double>(
                            stream: _walletRepo.getTotalBalanceStream(),
                            builder: (context, snapshot) {
                              final totalBalance = snapshot.data ?? 0.0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 1.1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      _isBalanceVisible
                                          ? CurrencyUtils.formatCurrency(totalBalance)
                                          : '•••••••• ₫',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _isBalanceVisible = !_isBalanceVisible;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isBalanceVisible
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          key: const ValueKey('normal_title'),
                          child: Text(
                            context.tr('wallets_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Phải: Chuyển tiền & Thêm ví thu gọn
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showTransferDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showWalletForm(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

  // === THẺ TỔNG TÀI SẢN ĐẲNG CẤP (HERO NET WORTH CARD) ===
  Widget _buildHeroNetWorthCard(
    BuildContext context,
    double totalBalance,
    List<WalletModel> allWallets,
    bool isDark,
  ) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF132F2C),
                  const Color(0xFF0F2624),
                  const Color(0xFF0A1B19),
                ]
              : [
                  const Color(0xFF2A6C67),
                  const Color(0xFF438883),
                  const Color(0xFF35706B),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
                .withValues(alpha: isDark ? 0.22 : 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            // Hoa văn watermark chìm góc phải
            Positioned(
              right: -20,
              top: -20,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.shield_rounded,
                  size: 140,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng tiêu đề & nút con mắt bảo mật
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.diamond_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            context.tr('total_net_worth'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isBalanceVisible = !_isBalanceVisible;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isBalanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isBalanceVisible
                                    ? (context.tr('cancel') == 'Cancel' ? 'Hide' : 'Ẩn')
                                    : (context.tr('cancel') == 'Cancel' ? 'Show' : 'Hiện'),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Số dư lớn nổi bật
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isBalanceVisible
                          ? CurrencyUtils.formatCurrency(totalBalance)
                          : '•••••••• ₫',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Huy hiệu trạng thái & số lượng ví
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: (totalBalance >= 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171))
                              .withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (totalBalance >= 0
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFF87171))
                                .withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              totalBalance >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: totalBalance >= 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFF87171),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              totalBalance >= 0
                                  ? (context.tr('cancel') == 'Cancel' ? 'Positive Flow' : 'Tài chính dương')
                                  : (context.tr('cancel') == 'Cancel' ? 'Needs Attention' : 'Cần cân đối'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: totalBalance >= 0
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFF87171),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.tr('cancel') == 'Cancel'
                              ? '•  ${allWallets.length} linked sources'
                              : '•  ${allWallets.length} nguồn tiền liên kết',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Thanh phân bổ danh mục tài sản dạng phân đoạn (Segmented Allocation Bar)
                  if (allWallets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: _buildSegmentedAssetBar(allWallets, isDark),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // === THANH PHÂN BỔ TÀI SẢN PHÂN ĐOẠN (SEGMENTED ALLOCATION BAR) ===
  Widget _buildSegmentedAssetBar(List<WalletModel> wallets, bool isDark) {
    final Map<String, double> categorySums = {};
    for (final w in wallets) {
      if (w.balance > 0) {
        final key = w.type;
        categorySums[key] = (categorySums[key] ?? 0.0) + w.balance;
      }
    }

    final positiveTotal = categorySums.values.fold<double>(0.0, (sum, val) => sum + val);

    final categoryColors = {
      WalletType.bank: const Color(0xFF38BDF8), // Xanh Sky
      WalletType.eWallet: const Color(0xFFF472B6), // Hồng Neon
      WalletType.cash: const Color(0xFF4ADE80), // Xanh lá Mint
      WalletType.savings: const Color(0xFFFBBF24), // Vàng Amber
      WalletType.credit: const Color(0xFFA78BFA), // Tím Violet
      WalletType.other: const Color(0xFF94A3B8), // Xám Bạc
    };

    if (positiveTotal <= 0) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      );
    }

    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('asset_allocation'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        // Thanh phân đoạn tỷ lệ
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: Row(
              children: sortedCategories.map((entry) {
                final ratio = (entry.value / positiveTotal);
                final flex = (ratio * 1000).round().clamp(1, 1000);
                final color = categoryColors[entry.key] ?? const Color(0xFF38BDF8);
                return Flexible(
                  flex: flex,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.6),
                    color: color,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Chú thích danh mục kèm phần trăm
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: sortedCategories.map((entry) {
            final ratio = (entry.value / positiveTotal);
            final percentStr = (ratio * 100).toStringAsFixed(ratio < 0.1 ? 1 : 0);
            final color = categoryColors[entry.key] ?? const Color(0xFF38BDF8);
            final name = WalletType.getDisplayName(entry.key);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$name $percentStr%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }


  // === THANH CHỌN VÍ MỘT CHẠM (ONE-THUMB WALLET SELECTOR PILLS) ===
  Widget _buildWalletSelectorPills(List<WalletModel> wallets, bool isDark) {
    return RepaintBoundary(
      child: Container(
        height: 38,
        margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        controller: _pillsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        cacheExtent: 300,
        itemCount: wallets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedWalletId == null;
            return _buildPillChip(
              label: '${context.tr('filter_all')} (${wallets.length})',
              icon: Icons.account_balance_wallet_rounded,
              isSelected: isSelected,
              accentColor: const Color(0xFF438883),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedWalletId = null);
                _scrollCardTo(0);
              },
            );
          }

          final wallet = wallets[index - 1];
          final isSelected = _selectedWalletId == wallet.id;
          final walletColor = Color(wallet.colorValue);

          return _buildPillChip(
            label: wallet.name,
            icon: wallet.icon,
            isSelected: isSelected,
            accentColor: walletColor,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedWalletId = isSelected ? null : wallet.id;
              });
              _scrollCardTo(isSelected ? 0 : index);
            },
          );
        },
      ),
    ));
  }

  Widget _buildPillChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return AnimatedScaleButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // === THẺ TỔNG QUAN DÒNG TIỀN THÁNG NÀY ===
  Widget _buildMonthlyCashflowCard(bool isDark) {
    final now = DateTime.now();
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<TransactionModel>>(
        stream: _txRepo.getTransactionsStream(),
        builder: (context, snapshot) {
          final allTx = snapshot.data ?? [];
          final thisMonthTx = allTx.where((tx) =>
              tx.date.year == now.year &&
              tx.date.month == now.month &&
              (_selectedWalletId == null || tx.walletId == _selectedWalletId)).toList();

          double income = 0;
          double expense = 0;
          for (final tx in thisMonthTx) {
            if (tx.type == 'income') {
              income += tx.amount;
            } else if (tx.type == 'expense') {
              expense += tx.amount;
            }
          }
          final net = income - expense;
          final totalFlow = income + expense;
          final incomePercent = totalFlow > 0 ? (income / totalFlow) : 0.5;
          final expensePercent = totalFlow > 0 ? (expense / totalFlow) : 0.5;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182234) : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.insights_rounded,
                            size: 15,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.tr('cancel') == 'Cancel'
                                  ? 'Cash Flow ${DateFormat('MM/yyyy').format(now)}'
                                  : 'Dòng tiền tháng ${DateFormat('MM/yyyy').format(now)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedWalletId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF438883).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.tr('cancel') == 'Cancel' ? 'Filtered' : 'Lọc theo ví',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF438883)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryColumn(context.tr('income'), income, const Color(0xFF2E7D32), isDark),
                    Container(height: 22, width: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    _buildSummaryColumn(context.tr('expense'), expense, const Color(0xFFD32F2F), isDark),
                    Container(height: 22, width: 1, color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                    _buildSummaryColumn(
                      context.tr('net_flow'),
                      net,
                      net >= 0
                          ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32))
                          : (isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F)),
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Thanh tiến trình tỷ lệ Thu / Chi
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 5,
                    child: totalFlow == 0
                        ? Container(color: isDark ? Colors.white12 : Colors.grey.shade300)
                        : Row(
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      totalFlow > 0 ? 'Thu: ${(incomePercent * 100).toStringAsFixed(0)}%' : 'Thu: 0%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF2E7D32),
                      ),
                    ),
                    Text(
                      totalFlow > 0 ? 'Chi: ${(expensePercent * 100).toStringAsFixed(0)}%' : 'Chi: 0%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ));
  }

  Widget _buildSummaryColumn(String title, double amount, Color valueColor, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // === SECTION: GIAO DỊCH GẦN ĐÂY (3-5 GIAO DỊCH) ===
  Widget _buildRecentTransactionsSection(bool isDark) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<TransactionModel>>(
        stream: _txRepo.getTransactionsStream(),
        builder: (context, snapshot) {
          final allTx = snapshot.data ?? [];
          final filteredTx = _selectedWalletId == null
              ? List<TransactionModel>.from(allTx)
              : allTx.where((t) => t.walletId == _selectedWalletId).toList();

          filteredTx.sort(CurrencyUtils.compareTransactionsChronological);

          // Lấy 5 giao dịch mới nhất làm bản xem nhanh
          final recentTx = filteredTx.take(5).toList();

          final effectiveWallets = _latestWallets.isNotEmpty
              ? _latestWallets
              : _walletRepo.latestWallets;
          final walletMap = {for (final w in effectiveWallets) w.id: w};

          final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
            allTransactions: allTx,
            wallets: effectiveWallets,
          );

          String sectionTitle = context.tr('tx_history');
          if (_selectedWalletId != null) {
            try {
              final w = effectiveWallets.firstWhere((w) => w.id == _selectedWalletId);
              sectionTitle = '${context.tr('tx_history')}: ${w.name}';
            } catch (_) {}
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            sectionTitle,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${filteredTx.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF438883),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        PageTransitions.slideRight(
                          WalletHistoryScreen(initialWalletId: _selectedWalletId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          context.tr('see_all'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recentTx.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162523) : const Color(0xFFFAFCFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE5EBE9),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 36, color: isDark ? Colors.white24 : Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        isVi ? 'Chưa có giao dịch nào' : 'No transactions yet',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                ...recentTx.map((tx) {
                  return TransactionItem(
                    transaction: tx,
                    showDate: true,
                    runningTotal: reverseBalances[tx.id],
                    wallet: walletMap[tx.walletId],
                  );
                }),
            ],
          );
        },
      ),
    ));
  }



  // === EMV CHIP KIM LOẠI CHO THẺ FINTECH ===
  Widget _buildEmvChip({bool isGold = true}) {
    final baseColor = isGold ? const Color(0xFFE5B842) : const Color(0xFFCBD5E1);
    final innerColor = isGold ? const Color(0xFFC49A28) : const Color(0xFF94A3B8);
    return Container(
      width: 32,
      height: 23,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: baseColor.withValues(alpha: 0.8), width: 1.1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14,
            height: 11,
            decoration: BoxDecoration(
              border: Border.all(color: innerColor.withValues(alpha: 0.7), width: 0.8),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Container(width: 1, height: 23, color: innerColor.withValues(alpha: 0.5)),
          Container(width: 32, height: 1, color: innerColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  // === THẺ TẤT CẢ VÍ FINTECH CAO CẤP (ALL WALLETS CARD) ===
  Widget _buildAllWalletsCard(
    BuildContext context,
    List<WalletModel> wallets,
    double totalBalance,
    bool isSelected,
    bool isDark,
  ) {
    return AnimatedScaleButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedWalletId = null;
        });
      },
      child: Container(
        width: 280,
        height: 175,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF2C3E50), const Color(0xFF1A252F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2DD4BF)
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF2DD4BF).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Vân watermark sóng chìm
              Positioned(
                right: -15,
                top: -15,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 125,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Nội dung thẻ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hàng trên: Chip EMV + Sóng contactless + Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildEmvChip(isGold: true),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.contactless_rounded,
                              size: 19,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2DD4BF).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2DD4BF)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 12,
                                color: isSelected ? const Color(0xFF2DD4BF) : Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('all_wallets').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: isSelected ? const Color(0xFF2DD4BF) : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Phần giữa: Số tài khoản phong cách ATM & Số dư dập nổi
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•••• •••• •••• ALL',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible
                                ? CurrencyUtils.formatCurrency(totalBalance)
                                : '•••••••• ₫',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Hàng dưới: Số lượng ví & Nút Lịch sử kính mờ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${wallets.length} ${context.tr('wallets_title').toLowerCase()}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                const WalletHistoryScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('cancel') == 'Cancel' ? 'History' : 'Lịch sử',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === THẺ VÍ FINTECH CAO CẤP (WALLET CARD) ===
  Widget _buildWalletCard(BuildContext context, WalletModel wallet, bool isSelected, bool isDark) {
    final walletColor = Color(wallet.colorValue);
    final darkShade = HSLColor.fromColor(walletColor)
        .withLightness((HSLColor.fromColor(walletColor).lightness - 0.22).clamp(0.0, 1.0))
        .toColor();

    return AnimatedScaleButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedWalletId = (_selectedWalletId == wallet.id) ? null : wallet.id;
        });
      },
      child: Container(
        width: 280,
        height: 175,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              walletColor,
              darkShade,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
            width: isSelected ? 2.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? walletColor.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Vân watermark biểu tượng ví
              Positioned(
                right: -12,
                top: -12,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    wallet.icon,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // Nội dung thẻ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Hàng trên: Chip EMV + Sóng contactless + Thao tác
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildEmvChip(isGold: wallet.type == WalletType.credit || wallet.type == WalletType.savings),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.contactless_rounded,
                              size: 19,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (wallet.isDefault)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.tr('is_default'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white),
                              ),
                              onSelected: (value) {
                                if (value == 'history') {
                                  Navigator.push(
                                    context,
                                    PageTransitions.slideRight(
                                      WalletHistoryScreen(initialWalletId: wallet.id),
                                    ),
                                  );
                                } else if (value == 'edit') {
                                  _showWalletForm(context, wallet: wallet);
                                } else if (value == 'delete') {
                                  _confirmDeleteWallet(context, wallet);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'history',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history_rounded, size: 18, color: Color(0xFF438883)),
                                      SizedBox(width: 8),
                                      Text(context.tr('wallet_history')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(value: 'edit', child: Text(context.tr('edit_wallet'))),
                                if (!wallet.isDefault)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.tr('delete_wallet'), style: const TextStyle(color: Colors.red)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Giữa: STK dập số và Số dư nổi bật
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.accountNumber.isNotEmpty
                              ? '•••• •••• •••• ${wallet.accountNumber.length > 4 ? wallet.accountNumber.substring(wallet.accountNumber.length - 4) : wallet.accountNumber}'
                              : wallet.typeDisplayName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible
                                ? CurrencyUtils.formatCurrency(wallet.balance)
                                : '•••••••• ₫',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Dưới: Tên ví & Nút Lịch sử kính mờ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            wallet.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                WalletHistoryScreen(initialWalletId: wallet.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  isVi ? 'Lịch sử' : 'History',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === FORM THÊM / SỬA VÍ TIỀN CHUẨN FINTECH HIỆN ĐẠI ===
  void _showWalletForm(BuildContext context, {WalletModel? wallet}) {
    AddWalletSheet.show(context, wallet: wallet);
  }

  // === DIALOG CHUYỂN TIỀN GIỮA CÁC VÍ ===
  void _showTransferDialog(BuildContext context) async {
    final wallets = await _walletRepo.getWalletsStream().first;
    if (wallets.length < 2) {
      if (!context.mounted) return;
      TopToast.show(
        context,
        context.tr('transfer_min_wallets_error'),
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String fromWalletId = _selectedWalletId ?? wallets.first.id;
    String toWalletId = wallets.firstWhere((w) => w.id != fromWalletId).id;

    final amountController = TextEditingController();
    final feeController = TextEditingController(text: '0');
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        final topPunchHolePadding = math.max(
          MediaQuery.viewPaddingOf(ctx).top,
          math.max(
            MediaQuery.paddingOf(context).top,
            MediaQuery.viewPaddingOf(context).top,
          ),
        );

        return SafeArea(
          top: true,
          bottom: false,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final fromW = wallets.firstWhere((w) => w.id == fromWalletId, orElse: () => wallets.first);
              final toW = wallets.firstWhere((w) => w.id == toWalletId, orElse: () => wallets.last);

              final extraTopPadding = (MediaQuery.paddingOf(ctx).top == 0 && topPunchHolePadding > 0)
                  ? topPunchHolePadding + 8
                  : 20.0;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                  left: 20,
                  right: 20,
                  top: extraTopPadding,
                ),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('transfer_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('transfer_from'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                key: ValueKey('from_$fromWalletId'),
                                initialValue: fromWalletId,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 13),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: wallets.map((w) {
                                  return DropdownMenuItem(
                                    value: w.id,
                                    child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      fromWalletId = val;
                                      if (fromWalletId == toWalletId) {
                                        toWalletId = wallets.firstWhere((w) => w.id != fromWalletId).id;
                                      }
                                    });
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 2),
                                child: Text(
                                  '${context.tr('balance_prefix')}: ${CurrencyUtils.formatCurrency(fromW.balance)}',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: IconButton(
                            icon: Icon(Icons.swap_horiz, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                            onPressed: () {
                              setModalState(() {
                                final temp = fromWalletId;
                                fromWalletId = toWalletId;
                                toWalletId = temp;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('transfer_to'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                key: ValueKey('to_$toWalletId'),
                                initialValue: toWalletId,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontSize: 13),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: wallets.map((w) {
                                  return DropdownMenuItem(
                                    value: w.id,
                                    child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() {
                                      toWalletId = val;
                                      if (toWalletId == fromWalletId) {
                                        fromWalletId = wallets.firstWhere((w) => w.id != toWalletId).id;
                                      }
                                    });
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 2),
                                child: Text(
                                  '${context.tr('balance_prefix')}: ${CurrencyUtils.formatCurrency(toW.balance)}',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: context.tr('transfer_amount_label'),
                        hintText: isVi ? '0 đ' : '0',
                        prefixIcon: Icon(Icons.attach_money, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        final parsed = CurrencyUtils.parseCurrency(val);
                        if (parsed > 0) {
                          final formatted = CurrencyUtils.formatCurrency(parsed);
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: context.tr('transfer_fee_label'),
                        hintText: isVi ? '0 đ' : '0',
                        prefixIcon: Icon(Icons.receipt_outlined, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        final parsed = CurrencyUtils.parseCurrency(val);
                        final formatted = CurrencyUtils.formatCurrency(parsed);
                        feeController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: context.tr('note_optional_label'),
                        prefixIcon: const Icon(Icons.notes),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(context.tr('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final amount = CurrencyUtils.parseCurrency(amountController.text);
                              final fee = CurrencyUtils.parseCurrency(feeController.text);
                              if (amount <= 0) {
                                TopToast.show(
                                  context,
                                  context.tr('transfer_amount_error'),
                                  isError: true,
                                );
                                return;
                              }
                              if (fromW.balance < (amount + fee)) {
                                TopToast.show(
                                  context,
                                  context.tr('insufficient_balance_error'),
                                  isError: true,
                                );
                                return;
                              }

                              final note = noteController.text.trim();
                              await _walletRepo.transferMoney(
                                fromWalletId: fromWalletId,
                                toWalletId: toWalletId,
                                amount: amount,
                                fee: fee,
                                note: note,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                TopToast.show(context, context.tr('transfer_success'));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                              foregroundColor: isDark ? const Color(0xFF0F2625) : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(context.tr('confirm_transfer')),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  // === XÁC NHẬN XÓA VÍ ===
  void _confirmDeleteWallet(BuildContext context, WalletModel wallet) async {
    final confirm = await MonoDialog.confirm(
      context,
      title: context.tr('delete_wallet_title'),
      message: context.tr('delete_wallet_confirm').replaceAll('{name}', wallet.name),
      cancelText: context.tr('cancel'),
      confirmText: context.tr('delete'),
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirm == true) {
      await _walletRepo.deleteWallet(wallet.id);
    }
  }
}
