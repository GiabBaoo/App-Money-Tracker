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
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_balance_service.dart';
import '../../utils/page_transitions.dart';
import '../wallet/wallet_history_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final WalletRepository _walletRepo = WalletRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  late final ScrollController _scrollController;
  late final ScrollController _cardScrollController;
  late final ScrollController _pillsScrollController;
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  String? _selectedWalletId; // Ví được chọn (null = tất cả)
  List<WalletModel> _latestWallets = [];
  bool _isBalanceVisible = true; // Bật / tắt ẩn số dư tổng tài sản

  // Bảng màu 28 sắc độ hiện đại dành cho tùy biến ví (bao gồm màu thương hiệu MoMo, ZaloPay, Vietcombank, Techcombank, MB Bank,...)
  static const List<int> _paletteColors = [
    0xFF438883, // Emerald (Màu chủ đạo của app)
    0xFF10B981, // Mint Emerald
    0xFF006E33, // Vietcombank Deep Green
    0xFF06D6A0, // Neon Mint
    0xFF14B8A6, // Teal
    0xFF06B6D4, // Cyan
    0xFF0EA5E9, // Sky Blue
    0xFF0077B6, // Ocean Blue
    0xFF0068FF, // ZaloPay Blue
    0xFF3A86FF, // Electric Blue
    0xFF1429A0, // MB Bank Navy
    0xFF6366F1, // Indigo
    0xFF8338EC, // Violet
    0xFF7209B7, // Royal Purple
    0xFFD82D8B, // MoMo Pink
    0xFFEC4899, // Hot Pink
    0xFFF43F5E, // Rose
    0xFFD62828, // Crimson Red
    0xFFE31B23, // Techcombank Red
    0xFFF97316, // Orange
    0xFFF77F00, // Sunset Orange
    0xFFE07A5F, // Terracotta
    0xFFFFB703, // Amber Gold
    0xFFF59E0B, // Deep Amber
    0xFF84CC16, // Lime
    0xFF2B2D42, // Midnight Dark
    0xFF1E293B, // Dark Slate
    0xFF6F4E37, // Coffee Brown
  ];

  // Danh sách 16 icon tài chính thông dụng
  static const List<IconData> _walletIcons = [
    Icons.payments_rounded,
    Icons.account_balance_rounded,
    Icons.phone_android_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.wallet_rounded,
    Icons.local_atm_rounded,
    Icons.shopping_bag_rounded,
    Icons.flight_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.work_rounded,
    Icons.attach_money_rounded,
    Icons.card_giftcard_rounded,
    Icons.coffee_rounded,
    Icons.stars_rounded,
  ];

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
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
                                'Thẻ tài khoản',
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
                                  '${allWallets.length} tài khoản',
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
                            'Tổng tài sản',
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
                                _isBalanceVisible ? 'Ẩn' : 'Hiện',
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
                              totalBalance >= 0 ? 'Tài chính dương' : 'Cần cân đối',
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
                          '•  ${allWallets.length} nguồn tiền liên kết',
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
              'Phân bổ tài sản',
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
              label: 'Tất cả (${wallets.length})',
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
              : (isDark ? const Color(0xFF1E2827) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
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
              color: isDark ? const Color(0xFF162523) : const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
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
                              'Dòng tiền tháng ${DateFormat('MM/yyyy').format(now)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                        child: const Text(
                          'Lọc theo ví',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF438883)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryColumn('Thu nhập', income, const Color(0xFF2E7D32), isDark),
                    Container(height: 22, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                    _buildSummaryColumn('Chi tiêu', expense, const Color(0xFFD32F2F), isDark),
                    Container(height: 22, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                    _buildSummaryColumn(
                      'Ròng',
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

          String sectionTitle = 'Giao dịch gần đây';
          if (_selectedWalletId != null) {
            try {
              final w = effectiveWallets.firstWhere((w) => w.id == _selectedWalletId);
              sectionTitle = 'Giao dịch: ${w.name}';
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
                          'Xem tất cả',
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
                        'Chưa có giao dịch nào',
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Lịch sử',
                                  style: TextStyle(
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
                                child: const Text(
                                  'Mặc định',
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
                                const PopupMenuItem(
                                  value: 'history',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history_rounded, size: 18, color: Color(0xFF438883)),
                                      SizedBox(width: 8),
                                      Text('Xem lịch sử'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa ví')),
                                if (!wallet.isDefault)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Xóa ví', style: TextStyle(color: Colors.red)),
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Lịch sử',
                                  style: TextStyle(
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

  // === BỘ CHỌN MÀU NÂNG CAO CHO VÍ TIỀN (PHỔ QUANG CẦU VỒNG + BẢNG MÀU PHỐI SẴN) ===
  Future<int?> _showCustomColorPickerDialog(BuildContext context, int initialColor) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int pickedColor = initialColor;
    Color currentColor = Color(initialColor);
    HSVColor hsv = HSVColor.fromColor(currentColor);
    double currentHue = hsv.hue;
    double currentSaturation = hsv.saturation.clamp(0.15, 1.0);
    double currentValue = hsv.value.clamp(0.25, 1.0);

    final hexController = TextEditingController(
      text: initialColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );

    // Bảng 36 sắc độ phong cách tuyển chọn
    final categorizedColors = <String, List<int>>{
      'Đỏ & Hồng': [
        0xFFE53935, 0xFFD82D8B, 0xFFE91E63, 0xFFF43F5E, 0xFFC2185B, 0xFF880E4F,
      ],
      'Cam & Vàng': [
        0xFFFF9800, 0xFFF77F00, 0xFFE07A5F, 0xFFFFB703, 0xFFF59E0B, 0xFFFF6F00,
      ],
      'Xanh lá & Bạc hà': [
        0xFF438883, 0xFF10B981, 0xFF006E33, 0xFF06D6A0, 0xFF2A9D8F, 0xFF558B2F,
      ],
      'Xanh dương & Biển': [
        0xFF0077B6, 0xFF0068FF, 0xFF3A86FF, 0xFF1429A0, 0xFF0284C7, 0xFF0369A1,
      ],
      'Tím & Chàm': [
        0xFF8338EC, 0xFF7209B7, 0xFF6366F1, 0xFF5B21B6, 0xFF9333EA, 0xFF4C1D95,
      ],
      'Trung tính & Sang trọng': [
        0xFF2B2D42, 0xFF1E293B, 0xFF334155, 0xFF6F4E37, 0xFF475569, 0xFF0F172A,
      ],
    };

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141F1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final activeColor = Color(pickedColor);
            final hexString = '#${pickedColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

            void updateFromHsv() {
              final newColor = HSVColor.fromAHSV(1.0, currentHue, currentSaturation, currentValue).toColor();
              pickedColor = newColor.toARGB32();
              hexController.text = pickedColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt modal
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Tiêu đề & nút đóng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.palette_rounded, color: activeColor, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tùy chọn màu sắc ví',
                                  style: TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Chọn từ bảng màu hoặc tùy biến phổ quang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Thẻ xem trước màu đã chọn + mã Hex
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor,
                            Color.lerp(activeColor, const Color(0xFF0F172A), 0.3) ?? activeColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: isDark ? 0.4 : 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 1.5),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Màu sắc hiển thị của ví',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hexString,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Đang chọn', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 1. Phổ quang cầu vồng tùy chỉnh (Hue Rainbow Spectrum Slider)
                    Text(
                      'Tùy chỉnh dải màu phổ quang (Hue):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: activeColor,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      ),
                      child: Slider(
                        value: currentHue,
                        min: 0,
                        max: 360,
                        onChanged: (val) {
                          setPickerState(() {
                            currentHue = val;
                            updateFromHsv();
                          });
                        },
                      ),
                    ),

                    // Độ bão hòa & Độ sáng (Saturation / Brightness)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Độ rực màu (${(currentSaturation * 100).toInt()}%):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                                ),
                              ),
                              Slider(
                                value: currentSaturation,
                                min: 0.15,
                                max: 1.0,
                                activeColor: activeColor,
                                onChanged: (val) {
                                  setPickerState(() {
                                    currentSaturation = val;
                                    updateFromHsv();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Độ sáng (${(currentValue * 100).toInt()}%):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                                ),
                              ),
                              Slider(
                                value: currentValue,
                                min: 0.25,
                                max: 1.0,
                                activeColor: activeColor,
                                onChanged: (val) {
                                  setPickerState(() {
                                    currentValue = val;
                                    updateFromHsv();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Bảng màu phối sẵn theo nhóm phong cách
                    Text(
                      'Bảng màu phong cách tuyển chọn:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...categorizedColors.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: entry.value.map((colVal) {
                                final isSel = colVal == pickedColor;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setPickerState(() {
                                      pickedColor = colVal;
                                      final c = Color(colVal);
                                      final newHsv = HSVColor.fromColor(c);
                                      currentHue = newHsv.hue;
                                      currentSaturation = newHsv.saturation.clamp(0.15, 1.0);
                                      currentValue = newHsv.value.clamp(0.25, 1.0);
                                      hexController.text = colVal.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Color(colVal),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel ? Colors.white : Colors.transparent,
                                        width: isSel ? 2.5 : 0,
                                      ),
                                      boxShadow: isSel
                                          ? [
                                              BoxShadow(
                                                color: Color(colVal).withValues(alpha: 0.65),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                    ),
                                    child: isSel
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 14),

                    // Nhập mã HEX thủ công (Tùy chọn nâng cao)
                    Row(
                      children: [
                        Text(
                          'Mã màu HEX:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: TextField(
                                    controller: hexController,
                                    maxLength: 6,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) {
                                      if (val.length == 6) {
                                        final parsed = int.tryParse('FF$val', radix: 16);
                                        if (parsed != null) {
                                          setPickerState(() {
                                            pickedColor = parsed;
                                            final newHsv = HSVColor.fromColor(Color(parsed));
                                            currentHue = newHsv.hue;
                                            currentSaturation = newHsv.saturation.clamp(0.15, 1.0);
                                            currentValue = newHsv.value.clamp(0.25, 1.0);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Nút áp dụng & Hủy
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            child: Text(
                              'Đóng',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AnimatedScaleButton(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(dialogCtx, pickedColor);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    activeColor,
                                    Color.lerp(activeColor, const Color(0xFF0F172A), 0.2) ?? activeColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: isDark ? 0.45 : 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_rounded, color: Colors.white, size: 19),
                                    SizedBox(width: 6),
                                    Text(
                                      'Áp dụng màu này',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
        );
      },
    );
  }

  // === FORM THÊM / SỬA VÍ TIỀN CHUẨN FINTECH HIỆN ĐẠI ===
  void _showWalletForm(BuildContext context, {WalletModel? wallet}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = wallet != null;

    final nameController = TextEditingController(text: wallet?.name ?? '');
    final balanceController = TextEditingController(
      text: wallet != null ? CurrencyUtils.formatCurrency(wallet.balance) : '',
    );
    final noteController = TextEditingController(text: wallet?.note ?? '');

    String selectedType = wallet?.type ?? WalletType.cash;
    int selectedColor = wallet?.colorValue ?? _paletteColors[0];
    int selectedIconCode = wallet?.iconCode ?? Icons.payments_rounded.codePoint;
    bool isDefault = wallet?.isDefault ?? false;

    // Danh sách các mẫu ví & ngân hàng thông dụng tại Việt Nam (1 chạm tự điền thông tin)
    final presets = [
      {
        'name': 'Tiền mặt',
        'type': WalletType.cash,
        'color': 0xFF438883,
        'icon': Icons.payments_rounded.codePoint,
        'label': '💵 Tiền mặt',
      },
      {
        'name': 'Ví MoMo',
        'type': WalletType.eWallet,
        'color': 0xFFD82D8B,
        'icon': Icons.phone_android_rounded.codePoint,
        'label': '👛 MoMo',
      },
      {
        'name': 'Ví ZaloPay',
        'type': WalletType.eWallet,
        'color': 0xFF0068FF,
        'icon': Icons.qr_code_rounded.codePoint,
        'label': '🔵 ZaloPay',
      },
      {
        'name': 'Vietcombank',
        'type': WalletType.bank,
        'color': 0xFF006E33,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 Vietcombank',
      },
      {
        'name': 'MB Bank',
        'type': WalletType.bank,
        'color': 0xFF1429A0,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 MB Bank',
      },
      {
        'name': 'Techcombank',
        'type': WalletType.bank,
        'color': 0xFFE31B23,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 Techcombank',
      },
      {
        'name': 'Thẻ tín dụng',
        'type': WalletType.credit,
        'color': 0xFF8338EC,
        'icon': Icons.credit_card_rounded.codePoint,
        'label': '💳 Tín dụng',
      },
      {
        'name': 'Heo đất tiết kiệm',
        'type': WalletType.savings,
        'color': 0xFFFFB703,
        'icon': Icons.savings_rounded.codePoint,
        'label': '🐷 Tiết kiệm',
      },
    ];

    // Các mốc tiền cộng nhanh số dư
    final quickAmounts = [
      {'label': '0 đ', 'add': false, 'val': 0.0},
      {'label': '+500k', 'add': true, 'val': 500000.0},
      {'label': '+1tr', 'add': true, 'val': 1000000.0},
      {'label': '+5tr', 'add': true, 'val': 5000000.0},
      {'label': '+10tr', 'add': true, 'val': 10000000.0},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141F1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentParsedBalance = CurrencyUtils.parseCurrency(balanceController.text);
            final activeColor = Color(selectedColor);

            String typeDisplay = 'Tiền mặt';
            if (selectedType == WalletType.bank) {
              typeDisplay = 'Tài khoản Ngân hàng';
            } else if (selectedType == WalletType.eWallet) {
              typeDisplay = 'Ví điện tử';
            } else if (selectedType == WalletType.credit) {
              typeDisplay = 'Thẻ tín dụng';
            } else if (selectedType == WalletType.savings) {
              typeDisplay = 'Sổ tiết kiệm';
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 12,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh gạt modal
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Tiêu đề & Nút đóng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                                color: activeColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isEditing ? context.tr('edit_wallet') : context.tr('add_wallet'),
                              style: TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ════════════ 1. LIVE WALLET CARD PREVIEW (THẺ XEM TRƯỚC THỜI GIAN THỰC) ════════════
                    Container(
                      width: double.infinity,
                      height: 155,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor,
                            activeColor.withValues(alpha: 0.78),
                            Color.lerp(activeColor, const Color(0xFF0F172A), 0.25) ?? activeColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: isDark ? 0.45 : 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Họa tiết trang trí vòng tròn mờ cao cấp
                          Positioned(
                            right: -25,
                            top: -25,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 40,
                            bottom: -35,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),

                          // Nội dung thẻ
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Hàng trên: Icon ví + Badge loại ví + Badge mặc định
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                                    ),
                                    child: Icon(
                                      IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (isDefault) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded, size: 12, color: Colors.black87),
                                              SizedBox(width: 3),
                                              Text(
                                                'Mặc định',
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          typeDisplay.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Hàng dưới: Tên ví & Số dư thời gian thực
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameController.text.trim().isNotEmpty
                                        ? nameController.text.trim()
                                        : 'Tên chiếc ví của bạn',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: nameController.text.trim().isNotEmpty ? 1.0 : 0.7,
                                      ),
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      shadows: const [
                                        Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 4),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyUtils.formatCurrency(currentParsedBalance),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                          shadows: [
                                            Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 5),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.contactless_rounded, color: Colors.white60, size: 24),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 2. GỢI Ý VÍ & NGÂN HÀNG PHỔ BIẾN (1 CHẠM TỰ ĐIỀN) ════════════
                    if (!isEditing) ...[
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 15, color: activeColor),
                          const SizedBox(width: 6),
                          Text(
                            'Gợi ý ví & ngân hàng phổ biến (1 chạm):',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: presets.length,
                          separatorBuilder: (_, index) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final p = presets[idx];
                            final isCur = nameController.text == p['name'];
                            final pColor = Color(p['color'] as int);

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  nameController.text = p['name'] as String;
                                  selectedType = p['type'] as String;
                                  selectedColor = p['color'] as int;
                                  selectedIconCode = p['icon'] as int;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? pColor.withValues(alpha: isDark ? 0.35 : 0.18)
                                      : (isDark ? const Color(0xFF22302E) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isCur ? pColor : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    width: isCur ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  p['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.w500,
                                    color: isCur
                                        ? (isDark ? Colors.white : pColor)
                                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ════════════ 3. SỐ DƯ BAN ĐẦU (HERO BALANCE INPUT) ════════════
                    Text(
                      isEditing ? context.tr('current_balance_label') : context.tr('initial_balance_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '₫',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: balanceController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: activeColor,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0 ₫',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final parsed = CurrencyUtils.parseCurrency(val);
                                setModalState(() {});
                                if (parsed > 0) {
                                  final formatted = CurrencyUtils.formatCurrency(parsed);
                                  balanceController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }
                              },
                            ),
                          ),
                          if (balanceController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                              onPressed: () {
                                setModalState(() {
                                  balanceController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ),

                    // Hàng chip nạp số dư nhanh
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: quickAmounts.map((q) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final isAdd = q['add'] as bool;
                            final val = q['val'] as double;
                            double newBal = 0.0;
                            if (isAdd) {
                              newBal = currentParsedBalance + val;
                            } else {
                              newBal = val;
                            }
                            setModalState(() {
                              balanceController.text = CurrencyUtils.formatCurrency(newBal);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF233532) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF38524E) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              q['label'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 4. TÊN VÍ TIỀN ════════════
                    Text(
                      context.tr('wallet_name_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: context.tr('wallet_name_hint'),
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: activeColor),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: activeColor, width: 2),
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 5. LOẠI VÍ TIỀN ════════════
                    Text(
                      context.tr('wallet_type_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: isDark ? const Color(0xFF1E2B29) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(value: WalletType.cash, child: Text('💵 ${context.tr('wallet_cash')}')),
                        DropdownMenuItem(value: WalletType.bank, child: Text('🏦 ${context.tr('wallet_bank')}')),
                        DropdownMenuItem(value: WalletType.eWallet, child: Text('👛 ${context.tr('wallet_e_wallet')}')),
                        DropdownMenuItem(value: WalletType.credit, child: const Text('💳 Thẻ tín dụng')),
                        DropdownMenuItem(value: WalletType.savings, child: Text('🐷 ${context.tr('wallet_savings')}')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 6. BỘ CHỌN MÀU SẮC PHỐI SẴN & TÙY CHỌN ════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('color_label'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            final customColor = await _showCustomColorPickerDialog(context, selectedColor);
                            if (customColor != null) {
                              setModalState(() => selectedColor = customColor);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Colors.red, Colors.amber, Colors.green, Colors.blue, Colors.purple],
                                  ).createShader(bounds),
                                  child: const Icon(Icons.palette_rounded, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tùy chọn màu sắc...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: activeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // Nút mở Bảng màu tùy chọn với biểu tượng cầu vồng
                          GestureDetector(
                            onTap: () async {
                              final customColor = await _showCustomColorPickerDialog(context, selectedColor);
                              if (customColor != null) {
                                setModalState(() => selectedColor = customColor);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    Colors.red,
                                    Colors.amber,
                                    Colors.green,
                                    Colors.cyan,
                                    Colors.blue,
                                    Colors.purple,
                                    Colors.red,
                                  ],
                                ),
                                border: Border.all(
                                  color: !_paletteColors.contains(selectedColor) ? Colors.white : Colors.transparent,
                                  width: !_paletteColors.contains(selectedColor) ? 2.5 : 0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E2B29) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.colorize_rounded,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Nếu màu được chọn là màu tùy biến không có trong bảng _paletteColors thì hiển thị riêng ở đây
                          if (!_paletteColors.contains(selectedColor))
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Color(selectedColor),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(selectedColor).withValues(alpha: 0.65),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              ),
                            ),

                          // Danh sách các màu trong _paletteColors
                          ..._paletteColors.map((color) {
                            final isSel = color == selectedColor;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => selectedColor = color);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Color(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.white : Colors.transparent,
                                    width: isSel ? 2.5 : 0,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: Color(color).withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 7. BỘ CHỌN ICON BIỂU TƯỢNG VÍ ════════════
                    Text(
                      context.tr('icon_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _walletIcons.length,
                        itemBuilder: (context, i) {
                          final icon = _walletIcons[i];
                          final isSel = icon.codePoint == selectedIconCode;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() => selectedIconCode = icon.codePoint);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSel ? activeColor.withValues(alpha: 0.22) : (isDark ? const Color(0xFF1E2B29) : const Color(0xFFF1F5F9)),
                                border: Border.all(
                                  color: isSel ? activeColor : (isDark ? Colors.white12 : Colors.grey.shade300),
                                  width: isSel ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                icon,
                                color: isSel ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade700),
                                size: 23,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ════════════ 8. ĐẶT LÀM VÍ MẶC ĐỊNH & GHI CHÚ ════════════
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.tr('default_wallet_label'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          'Tự động chọn ví này khi ghi nhận thu chi mới',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        value: isDefault,
                        activeThumbColor: activeColor,
                        onChanged: (val) => setModalState(() => isDefault = val),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: context.tr('note_optional_label'),
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2B29) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF324844) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ════════════ 9. NÚT HÀNH ĐỘNG (LƯU / HỦY) ════════════
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            child: Text(
                              context.tr('cancel'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: AnimatedScaleButton(
                            onTap: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                TopToast.show(context, context.tr('enter_wallet_name_error'), isError: true);
                                return;
                              }
                              final balance = CurrencyUtils.parseCurrency(balanceController.text);
                              final uid = AuthService().currentUid;
                              if (uid == null) return;

                              HapticFeedback.mediumImpact();

                              if (isEditing) {
                                final allTxs = await _txRepo.getAllTransactions();
                                final txs = allTxs.where((t) => t.walletId == wallet.id);
                                double inc = 0.0;
                                double exp = 0.0;
                                for (final t in txs) {
                                  if (t.type == 'income') {
                                    inc += t.amount;
                                  } else {
                                    exp += t.amount;
                                  }
                                }
                                final calcInitial = balance - (inc - exp);
                                final updated = wallet.copyWith(
                                  name: name,
                                  balance: balance,
                                  initialBalance: calcInitial,
                                  type: selectedType,
                                  colorValue: selectedColor,
                                  iconCode: selectedIconCode,
                                  isDefault: isDefault,
                                  note: noteController.text.trim(),
                                );
                                await _walletRepo.updateWallet(updated);
                              } else {
                                final newWallet = WalletModel(
                                  id: '',
                                  uid: uid,
                                  name: name,
                                  balance: balance,
                                  initialBalance: balance,
                                  type: selectedType,
                                  colorValue: selectedColor,
                                  iconCode: selectedIconCode,
                                  isDefault: isDefault,
                                  createdAt: DateTime.now(),
                                  note: noteController.text.trim(),
                                );
                                await _walletRepo.addWallet(newWallet);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                TopToast.show(
                                  context,
                                  isEditing ? context.tr('update_wallet_success') : context.tr('create_wallet_success'),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    activeColor,
                                    Color.lerp(activeColor, const Color(0xFF0F172A), 0.2) ?? activeColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: isDark ? 0.45 : 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isEditing ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEditing ? context.tr('save_changes') : context.tr('create_wallet_btn'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fromW = wallets.firstWhere((w) => w.id == fromWalletId, orElse: () => wallets.first);
            final toW = wallets.firstWhere((w) => w.id == toWalletId, orElse: () => wallets.last);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
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
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF438883), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('transfer_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                key: ValueKey('from_$fromWalletId'),
                                initialValue: fromWalletId,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF222C2A) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
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
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Color(0xFF438883)),
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
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                key: ValueKey('to_$toWalletId'),
                                initialValue: toWalletId,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF222C2A) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
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
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: context.tr('transfer_amount_label'),
                        hintText: '0 đ',
                        prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF438883)),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: context.tr('transfer_fee_label'),
                        hintText: '0 đ',
                        prefixIcon: const Icon(Icons.receipt_outlined, color: Colors.grey),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
                              backgroundColor: const Color(0xFF438883),
                              foregroundColor: Colors.white,
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
        );
      },
    );
  }

  // === XÁC NHẬN XÓA VÍ ===
  void _confirmDeleteWallet(BuildContext context, WalletModel wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_wallet_title')),
        content: Text(
          context.tr('delete_wallet_confirm').replaceAll('{name}', wallet.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await _walletRepo.deleteWallet(wallet.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.tr('delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
