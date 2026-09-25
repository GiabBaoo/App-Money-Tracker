import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/staggered_list_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/connectivity_service.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
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
    
    // ĐỊNH NGHĨA MÀU SẮC THEO YÊU CẦU ĐỒNG BỘ DARKMODE
    final Color activeColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF438883);
    final Color inactiveColor = isDark ? const Color(0xFF757575) : const Color(0xFF9E9E9E);
    final Color bottomBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        floatingActionButton: AnimatedScaleButton(
          onTap: () {
            Navigator.push(context, PageTransitions.slideUp(const AddTransactionScreen()));
          },
          child: Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883)).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 36),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          color: bottomBarColor,
          elevation: 10,
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // NHÓM BÊN TRÁI
                Row(
                  children: [
                    _buildNavItem(0, Icons.home_rounded, 'nav_home', activeColor, inactiveColor),
                    _buildNavItem(1, Icons.bar_chart_rounded, 'nav_stats', activeColor, inactiveColor),
                  ],
                ),
                // KHOẢNG TRỐNG CHO FAB
                const SizedBox(width: 40),
                // NHÓM BÊN PHẢI
                Row(
                  children: [
                    _buildNavItem(2, Icons.account_balance_wallet_rounded, 'nav_wallets', activeColor, inactiveColor),
                    _buildNavItem(3, Icons.settings_rounded, 'nav_profile', activeColor, inactiveColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String labelKey, Color activeColor, Color inactiveColor) {
    final bool isSelected = _selectedIndex == index;
    return Tooltip(
      message: context.tr(labelKey),
      child: MaterialButton(
        minWidth: 70, // Tăng width một chút cho thoải mái
        padding: EdgeInsets.zero,
        onPressed: () => _switchTab(index),
        child: Center(
          child: Icon(
            icon,
            size: 32, // Tăng kích thước Icon lên 32 theo yêu cầu
            color: isSelected ? activeColor : inactiveColor,
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
  late Stream<List<TransactionModel>> _transactionStream;

  bool _showOfflineBanner = false;
  Timer? _offlineBannerTimer;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _notiRepo.setUid(uid);
    }
    _walletRepo.getWallets();
    _transactionStream = TransactionRepository().getTransactionsStream();
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
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: const Color(0xFFEA580C),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('offline_mode'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
                            final displayName = (user?.name != null && user!.name.isNotEmpty)
                                ? user.name
                                : (FirebaseAuth.instance.currentUser?.displayName ?? fallbackName);
                            final avatarUrl = (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                                ? user.avatarUrl
                                : FirebaseAuth.instance.currentUser?.photoURL;
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
                    stream: _walletRepo.getTotalBalanceStream(),
                    builder: (context, walletSnapshot) {
                      final totalBalance = walletSnapshot.data ?? 0.0;
                      return StreamBuilder<List<TransactionModel>>(
                        stream: _transactionStream,
                        builder: (context, snapshot) {
                          double totalIncome = 0;
                          double totalExpense = 0;
                          if (snapshot.hasData) {
                            final now = DateTime.now();
                            for (var tx in snapshot.data!) {
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

        // PHÍM TẮT TIỆN ÍCH NHANH (NGÂN SÁCH & MỤC TIÊU, TRỢ LÝ MONO) - THIẾT KẾ TINH GỌN CAPSULE
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickFeatureCard(
                  context,
                  isDark: isDark,
                  icon: Icons.track_changes_rounded,
                  title: 'Ngân sách & Mục tiêu',
                  color: const Color(0xFF438883),
                  onTap: () => Navigator.push(
                    context,
                    PageTransitions.slideRight(const BudgetAndGoalsScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickFeatureCard(
                  context,
                  isDark: isDark,
                  icon: Icons.auto_awesome_rounded,
                  title: 'Trợ lý Mono',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(
                    context,
                    PageTransitions.slideRight(const AiAssistantScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),

        // TIÊU ĐỀ LỊCH SỬ GIAO DỊCH (TINH GỌN, ĐÃ BỎ NÚT LỊCH THU CHI)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('tx_history'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      PageTransitions.slideRight(const AllTransactionsScreen()),
                    ),
                    child: Text(context.tr('see_all'), style: const TextStyle(color: Color(0xFF438883))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF438883)),
                    onPressed: () => Navigator.push(
                      context,
                      PageTransitions.slideRight(const TransactionGalleryScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // PHẦN CUỘN ĐỘC LẬP: DANH SÁCH GIAO DỊCH
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: _transactionStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final now = DateTime.now();
              var transactions = (snapshot.data ?? [])
                  .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
                  .toList();
              transactions.sort((a, b) {
                DateTime dateA = DateTime(a.date.year, a.date.month, a.date.day);
                DateTime dateB = DateTime(b.date.year, b.date.month, b.date.day);
                int dateCompare = dateB.compareTo(dateA);
                if (dateCompare != 0) return dateCompare;
                int timeCompare = b.time.compareTo(a.time);
                if (timeCompare != 0) return timeCompare;
                return b.createdAt.compareTo(a.createdAt);
              });
              final allTx = snapshot.data ?? [];
              final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                allTransactions: allTx,
                wallets: _walletRepo.latestWallets,
              );
              final displayTransactions = transactions.take(10).toList();
              
              if (displayTransactions.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(context.tr('no_tx_month')),
                ));
              }

              return ListView.builder(
                key: const PageStorageKey('home_tx_list'),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                itemCount: displayTransactions.length,
                itemBuilder: (context, index) {
                  final tx = displayTransactions[index];
                  WalletModel? txWallet;
                  try {
                    txWallet = _walletRepo.latestWallets.firstWhere((w) => w.id == tx.walletId);
                  } catch (_) {}
                  return StaggeredListItem(
                    index: index,
                    child: TransactionItem(
                      transaction: tx,
                      showDate: true,
                      runningTotal: reverseBalances[tx.id],
                      wallet: txWallet,
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

  Widget _buildBalanceCard(double totalBalance, double income, double expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedScaleButton(
      scaleDown: 0.98,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNavigateTab?.call(1);
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF163230) : const Color(0xFF2F7E79),
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.15)) : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : const Color(0xFF438883).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('total_balance'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(CurrencyUtils.formatCurrency(totalBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBalanceInfo(Icons.arrow_downward, context.tr('income'), income, 'income'),
                _buildBalanceInfo(Icons.arrow_upward, context.tr('expense'), expense, 'expense'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(IconData icon, String label, double amount, String type) {
    return AnimatedScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNavigateTab?.call(1, isExpense: type == 'expense');
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(CurrencyUtils.formatCurrency(amount),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFeatureCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedScaleButton(
      scaleDown: 0.96,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202826) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  letterSpacing: 0.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
