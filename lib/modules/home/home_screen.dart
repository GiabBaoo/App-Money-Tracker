import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/fade_indexed_stack.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/connectivity_service.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../models/notification_model.dart';
import 'statistics_screen.dart';
import '../settings/profile_screen.dart';
import 'wallet_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_gallery_screen.dart';
import 'notification_screen.dart';
import '../../widgets/top_toast.dart';
import '../budget/budget_and_goals_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';

import '../transaction/all_transactions_screen.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/user_avatar.dart';
import '../../features/group_expense/presentation/screens/group_list_screen.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../services/smart_notification_service.dart';
import '../../services/local_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<StatisticsScreenState> _statsKey = GlobalKey<StatisticsScreenState>();
  DateTime? _lastBackPressTime;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeBody(onNavigateTab: _switchTab),
      StatisticsScreen(key: _statsKey),
      const WalletScreen(),
      const ProfileScreen(),
    ];
  }

  void _switchTab(int index, {bool? isExpense}) {
    setState(() => _selectedIndex = index);
    if (index == 1 && isExpense != null) {
      _statsKey.currentState?.setExpenseFilter(isExpense);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // MÀU SẮC FLOATING DOCK CHUẨN FINTECH
    final Color activeColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883);
    final Color inactiveColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          // Quay về tab Trang chủ nếu đang ở tab khác
          _switchTab(0);
        } else {
          // Nếu đang ở tab Trang chủ: bấm lần 2 để thoát
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            TopToast.show(context, 'Nhấn lần nữa để thoát ứng dụng');
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: FadeIndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xF5182221)
                      : const Color(0xF8FFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFloatingNavItem(0, Icons.home_rounded, 'nav_home', activeColor, inactiveColor),
                    _buildFloatingNavItem(1, Icons.bar_chart_rounded, 'nav_stats', activeColor, inactiveColor),
                    _buildCenterFabButton(context, isDark),
                    _buildFloatingNavItem(2, Icons.account_balance_wallet_rounded, 'nav_wallets', activeColor, inactiveColor),
                    _buildFloatingNavItem(3, Icons.person_rounded, 'nav_profile', activeColor, inactiveColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem(int index, IconData icon, String labelKey, Color activeColor, Color inactiveColor) {
    final bool isSelected = _selectedIndex == index;
    return Tooltip(
      message: context.tr(labelKey),
      child: AnimatedScaleButton(
        scaleDown: 0.88,
        onTap: () {
          HapticFeedback.selectionClick();
          _switchTab(index);
        },
        child: SizedBox(
          width: 52,
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 25,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 12 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFabButton(BuildContext context, bool isDark) {
    return Tooltip(
      message: 'Thêm giao dịch',
      child: AnimatedScaleButton(
        scaleDown: 0.88,
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, PageTransitions.slideUp(const AddTransactionScreen()));
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF438883), Color(0xFF2DD4BF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF438883).withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class HomeBody extends StatefulWidget {
  final void Function(int index, {bool? isExpense})? onNavigateTab;

  const HomeBody({super.key, this.onNavigateTab});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final WalletRepository _walletRepo = WalletRepository();
  final NotificationRepository _notiRepo = NotificationRepository();

  bool _showOfflineBanner = false;
  bool _isBalanceVisible = true;
  Timer? _offlineBannerTimer;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      TransactionRepository().setUid(uid);
      UserRepository().setUid(uid);
      _notiRepo.setUid(uid);
    }
    _walletRepo.getWallets().then((_) {
      if (mounted) setState(() {});
    });
    // Yêu cầu quyền thông báo hệ thống (bắt buộc cho Android 13+)
    LocalNotificationService.instance.requestPermission();
    // Tự động phân tích chi tiêu và tạo thông báo thông minh trong background
    SmartNotificationService.instance.generateSmartFinancialNotifications();
    // Lập lịch toàn bộ thông báo ngoài màn hình (nhắc nhở 20h, gợi ý 11h30, báo cáo tuần)
    SmartNotificationService.instance.scheduleAllBackgroundNotifications();

    // CHỈ hiển thị banner offline khi thiết bị THỰC SỰ KHÔNG CÓ MẠNG
    if (!ConnectivityService().isOnline) {
      _showOfflineBanner = true;
      _offlineBannerTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showOfflineBanner = false);
      });
    }
  }

  @override
  void dispose() {
    _offlineBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // THÔNG BÁO CHẾ ĐỘ NGOẠI TUYẾN (TỰ ĐỘNG BIẾN MẤT SAU 4 GIÂY)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _showOfflineBanner
              ? Container(
                  key: const ValueKey('offline_banner'),
                  width: double.infinity,
                  height: 22,
                  color: const Color(0xFFEA580C),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('offline_mode'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // PHẦN CỐ ĐỊNH: HEADER VÀ CARD SỐ DƯ
        Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: StreamBuilder<UserModel?>(
                          initialData: UserRepository().currentUser,
                          stream: UserRepository().getUserStream(),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data;
                            final fallbackName = context.tr('profile_title') == 'Profile' ? 'User' : 'Người dùng';
                            String? fbName;
                            String? fbPhoto;
                            try {
                              fbName = FirebaseAuth.instance.currentUser?.displayName;
                              fbPhoto = FirebaseAuth.instance.currentUser?.photoURL;
                            } catch (_) {}
                            final displayName = (user?.name != null && user!.name.isNotEmpty)
                                ? user.name
                                : (fbName ?? fallbackName);
                            final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                                ? user.avatarUrl
                                : fbPhoto;
                            final nowHour = DateTime.now().hour;
                            final greeting = nowHour < 12
                                ? '${context.tr('greeting_morning')},'
                                : (nowHour < 18 ? '${context.tr('greeting_afternoon')},' : '${context.tr('greeting_evening')},');

                            return Row(
                              children: [
                                AnimatedScaleButton(
                                  scaleDown: 0.93,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    widget.onNavigateTab?.call(3);
                                  },
                                  child: UserAvatar(
                                    radius: 22,
                                    name: displayName,
                                    avatarUrl: avatarUrl,
                                    avatarLocalPath: user?.avatarLocalPath,
                                    showBorder: true,
                                    borderColor: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        greeting,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          AnimatedScaleButton(
                            scaleDown: 0.9,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context, 
                                PageTransitions.slideRight(const GroupListScreen()),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.group, color: Colors.white, size: 20),
                            ),
                          ),
                          AnimatedScaleButton(
                            scaleDown: 0.9,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await Navigator.push(
                                context,
                                PageTransitions.slideRight(const NotificationScreen()),
                              );
                              if (context.mounted) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                                  // Badge hiển thị số thông báo chưa đọc
                                  StreamBuilder<List<NotificationModel>>(
                                    stream: _notiRepo.getNotificationsStream(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const SizedBox.shrink();
                                      
                                      final unreadCount = snapshot.data!.where((n) => !n.isRead).length;
                                      
                                      if (unreadCount == 0) return const SizedBox.shrink();
                                      
                                      return Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // TỔNG SỐ DƯ CARD - ĐỒNG BỘ CHÍNH XÁC VỚI VÍ TIỀN
                  StreamBuilder<double>(
                    initialData: _walletRepo.latestWallets.fold<double>(0.0, (double prev, w) => prev + w.balance),
                    stream: _walletRepo.getTotalBalanceStream(),
                    builder: (context, walletSnapshot) {
                      final double totalBalance = walletSnapshot.data ?? _walletRepo.latestWallets.fold<double>(0.0, (double prev, w) => prev + w.balance);
                      return StreamBuilder<List<TransactionModel>>(
                        initialData: TransactionRepository().latestTransactions,
                        stream: TransactionRepository().getTransactionsStream(),
                        builder: (context, snapshot) {
                          double totalIncome = 0;
                          double totalExpense = 0;
                          final txList = (snapshot.data != null && snapshot.data!.isNotEmpty)
                              ? snapshot.data!
                              : TransactionRepository().latestTransactions;
                          final now = DateTime.now();
                          for (var tx in txList) {
                            // Chỉ tính cho tháng và năm hiện tại & loại trừ chuyển tiền nội bộ
                            if (tx.date.month == now.month && tx.date.year == now.year) {
                              if (tx.isTransfer) continue;
                              if (tx.type == 'income') {
                                totalIncome += tx.amount;
                              } else {
                                totalExpense += tx.amount;
                              }
                            }
                          }
                          return _buildBalanceCard(totalBalance, totalIncome, totalExpense);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        // BỘ 4 NÚT THAO TÁC NHANH (QUICK ACTIONS GRID) - CÔNG THÁI HỌC VÙNG NGÓN TAY CÁI
        _buildQuickActionsGrid(context, isDark),

        // TIÊU ĐỀ LỊCH SỬ GIAO DỊCH (TINH GỌN, ĐÃ BỎ NÚT LỊCH THU CHI)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('tx_history'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  PageTransitions.slideRight(const AllTransactionsScreen()),
                ),
                child: Text(
                  context.tr('see_all'),
                  style: const TextStyle(
                    color: Color(0xFF438883),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // PHẦN CUỘN ĐỘC LẬP: DANH SÁCH GIAO DỊCH
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            initialData: TransactionRepository().latestTransactions,
            stream: TransactionRepository().getTransactionsStream(),
            builder: (context, snapshot) {
              final allTx = List<TransactionModel>.from(
                (snapshot.data != null && snapshot.data!.isNotEmpty)
                    ? snapshot.data!
                    : TransactionRepository().latestTransactions,
              );

              if (snapshot.connectionState == ConnectionState.waiting && allTx.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
              }
              
              allTx.sort(CurrencyUtils.compareTransactionsChronological);
              
              // Hiển thị danh sách các giao dịch gần đây nhất (tối đa 10 giao dịch)
              // Giúp giao diện luôn hiển thị đầy đủ dòng tiền mới nhất, không bị giới hạn chỉ 1 giao dịch khi vừa sang tháng
              final displayTransactions = allTx.take(10).toList();
              
              if (displayTransactions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      context.tr('no_tx_month'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              final effectiveWallets = _walletRepo.latestWallets;
              final walletMap = {for (final w in effectiveWallets) w.id: w};
              final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                allTransactions: allTx,
                wallets: effectiveWallets,
              );

              return ListView.builder(
                key: const PageStorageKey('home_tx_list'),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 400,
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
                itemCount: displayTransactions.length,
                itemBuilder: (context, index) {
                  final tx = displayTransactions[index];
                  return StaggeredListItem(
                    index: index,
                    child: TransactionItem(
                      transaction: tx,
                      showDate: true,
                      runningTotal: reverseBalances[tx.id],
                      wallet: walletMap[tx.walletId],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // === THẺ SỐ DƯ TỔNG QUAN FINTECH GLASSMORPHISM ===
  Widget _buildBalanceCard(double totalBalance, double income, double expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double totalFlow = income + expense;
    final int incomePercent = totalFlow > 0 ? ((income / totalFlow) * 100).round() : 50;
    final int expensePercent = totalFlow > 0 ? (100 - incomePercent) : 50;

    return AnimatedScaleButton(
      scaleDown: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNavigateTab?.call(1);
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1B3835), const Color(0xFF102423)]
                : [const Color(0xFF2F7E79), const Color(0xFF235F5B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0xFF438883).withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // HỌA TIẾT HÌNH TRÒN TRANG TRÍ MỜ NGHỆ THUẬT
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -35,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HÀNG TIÊU ĐỀ SỐ DƯ & NÚT CON MẮT BẢO MẬT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('total_balance'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    AnimatedScaleButton(
                      scaleDown: 0.88,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isBalanceVisible = !_isBalanceVisible;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isBalanceVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isBalanceVisible ? 'Hiện' : 'Ẩn',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // CON SỐ SỐ DƯ CHÍNH
                Text(
                  _isBalanceVisible ? CurrencyUtils.formatCurrency(totalBalance) : '•••••••• ₫',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 20),

                // 2 PILL THU NHẬP & CHI PHÍ
                Row(
                  children: [
                    Expanded(
                      child: _buildBalancePill(
                        icon: Icons.arrow_downward_rounded,
                        label: context.tr('income'),
                        amount: income,
                        type: 'income',
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalancePill(
                        icon: Icons.arrow_upward_rounded,
                        label: context.tr('expense'),
                        amount: expense,
                        type: 'expense',
                        color: const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // DẢI TỶ LỆ DÒNG TIỀN MINI TRỰC QUAN (DUAL-TONE RATIO BAR)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        color: Colors.white.withValues(alpha: 0.15),
                        child: Row(
                          children: [
                            Expanded(
                              flex: totalFlow > 0 ? incomePercent.clamp(1, 99) : 50,
                              child: Container(
                                color: totalFlow > 0 ? const Color(0xFF2DD4BF) : Colors.white24,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: totalFlow > 0 ? expensePercent.clamp(1, 99) : 50,
                              child: Container(
                                color: totalFlow > 0 ? const Color(0xFFF87171) : Colors.white24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalFlow > 0 ? 'Thu $incomePercent%' : 'Chưa có dòng tiền',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        if (totalFlow > 0)
                          Text(
                            'Chi $expensePercent%',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancePill({
    required IconData icon,
    required String label,
    required double amount,
    required String type,
    required Color color,
  }) {
    return AnimatedScaleButton(
      scaleDown: 0.94,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNavigateTab?.call(1, isExpense: type == 'expense');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isBalanceVisible ? CurrencyUtils.formatCurrency(amount) : '•••••• ₫',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === BỘ 4 NÚT THAO TÁC NHANH (QUICK ACTIONS GRID) ===
  Widget _buildQuickActionsGrid(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQuickActionItem(
            icon: Icons.swap_horiz_rounded,
            label: context.tr('quick_transfer'),
            color: const Color(0xFF14B8A6),
            isDark: isDark,
            onTap: () {
              widget.onNavigateTab?.call(2); // Chuyển sang Tab Ví
            },
          ),
          _buildQuickActionItem(
            icon: Icons.document_scanner_rounded,
            label: context.tr('quick_scan'),
            color: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              PageTransitions.slideRight(const TransactionGalleryScreen()),
            ),
          ),
          _buildQuickActionItem(
            icon: Icons.track_changes_rounded,
            label: context.tr('quick_budget'),
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              PageTransitions.slideRight(const BudgetAndGoalsScreen()),
            ),
          ),
          _buildQuickActionItem(
            icon: Icons.auto_awesome_rounded,
            label: context.tr('quick_mono'),
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              PageTransitions.slideRight(const AiAssistantScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AnimatedScaleButton(
        scaleDown: 0.92,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.35 : 0.22),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.16 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

