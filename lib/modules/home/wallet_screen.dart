import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/transaction_item.dart';
import '../../widgets/top_toast.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
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

  String? _selectedWalletId; // Ví được chọn (null = tất cả)
  List<WalletModel> _latestWallets = [];
  bool _isBalanceVisible = true; // Bật / tắt ẩn số dư tổng tài sản

  // Bảng màu 12 sắc độ hiện đại dành cho tùy biến ví
  static const List<int> _paletteColors = [
    0xFF438883, // Emerald (Màu chủ đạo của app)
    0xFF0077B6, // Ocean Blue
    0xFF3A86FF, // Electric Blue
    0xFF7209B7, // Royal Purple
    0xFF8338EC, // Violet
    0xFFE07A5F, // Terracotta
    0xFFF77F00, // Sunset Orange
    0xFFD62828, // Crimson Red
    0xFF2A9D8F, // Teal
    0xFF06D6A0, // Mint Green
    0xFFFFB703, // Amber Gold
    0xFF2B2D42, // Midnight Dark
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
    final uid = AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      _txRepo.setUid(uid);
      _walletRepo.ensureDefaultWalletExists(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === 1. TOP HEADER ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('wallets_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      // Nút Chuyển tiền giữa các ví
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showTransferDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Thêm ví mới
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showWalletForm(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === 2. TỔNG TÀI SẢN (HERO NET WORTH CARD - FINTECH GLASSMORPHISM) ===
            StreamBuilder<double>(
              stream: _walletRepo.getTotalBalanceStream(),
              builder: (context, snapshot) {
                final totalBalance = snapshot.data ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1A3835), const Color(0xFF112523)]
                            : [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.12)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                                  Flexible(
                                    child: Text(
                                      context.tr('total_net_worth'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _isBalanceVisible = !_isBalanceVisible;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isBalanceVisible
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<List<WalletModel>>(
                              stream: _walletRepo.getWalletsStream(),
                              builder: (context, wSnap) {
                                final count = wSnap.data?.length ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '$count ${context.tr('wallets_title').toLowerCase()}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isBalanceVisible
                              ? CurrencyUtils.formatCurrency(totalBalance)
                              : '•••••••• ₫',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Quick Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedScaleButton(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showTransferDialog(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Chuyển tiền',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AnimatedScaleButton(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showWalletForm(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Thêm ví',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

            // === 3. PHẦN THÂN: CAROUSEL VÍ & GIAO DỊCH GẦN ĐÂY (TỐI GIẢN) ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  key: const PageStorageKey('wallet_minimal_scroll'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề thanh lịch "Ví của bạn"
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ví của bạn',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: 0.2,
                              ),
                            ),
                            StreamBuilder<List<WalletModel>>(
                              stream: _walletRepo.getWalletsStream(),
                              builder: (context, snapshot) {
                                final count = snapshot.data?.length ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count tài khoản',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Carousel thẻ ví nằm ngang
                      SizedBox(
                        height: 190,
                        child: StreamBuilder<List<WalletModel>>(
                          stream: _walletRepo.getWalletsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                            }
                            final allWallets = snapshot.data ?? [];
                            _latestWallets = allWallets;
                            final totalBalance = allWallets.fold<double>(0.0, (sum, w) => sum + w.balance);

                            final int totalCardCount = allWallets.length + 1; // +1 cho thẻ "Tất cả ví"

                            return ListView.builder(
                              key: const PageStorageKey('wallet_cards_list'),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: totalCardCount,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return StaggeredListItem(
                                    index: 0,
                                    child: _buildAllWalletsCard(
                                      context,
                                      allWallets,
                                      totalBalance,
                                      _selectedWalletId == null,
                                      isDark,
                                    ),
                                  );
                                }
                                final wallet = allWallets[index - 1];
                                final isCurrentSelected = _selectedWalletId == wallet.id;
                                return StaggeredListItem(
                                  index: index,
                                  child: _buildWalletCard(context, wallet, isCurrentSelected, isDark),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3.3. Thẻ tổng quan dòng tiền tháng này (gọn gàng, tinh tế)
                      _buildMonthlyCashflowCard(isDark),

                      const SizedBox(height: 16),

                      // 3.4. Section Giao dịch gần đây (3-5 giao dịch)
                      _buildRecentTransactionsSection(isDark),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
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
    return Padding(
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
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<List<TransactionModel>>(
        stream: _txRepo.getTransactionsStream(),
        builder: (context, snapshot) {
          final allTx = snapshot.data ?? [];
          final filteredTx = _selectedWalletId == null
              ? List<TransactionModel>.from(allTx)
              : allTx.where((t) => t.walletId == _selectedWalletId).toList();

          filteredTx.sort(CurrencyUtils.compareTransactionsChronological);

          // Lấy 4 giao dịch mới nhất làm bản xem nhanh
          final recentTx = filteredTx.take(4).toList();

          final effectiveWallets = _latestWallets.isNotEmpty
              ? _latestWallets
              : _walletRepo.latestWallets;

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
                  WalletModel? txWallet;
                  try {
                    txWallet = effectiveWallets.firstWhere((w) => w.id == tx.walletId);
                  } catch (_) {}
                  return TransactionItem(
                    transaction: tx,
                    showDate: true,
                    runningTotal: reverseBalances[tx.id],
                    wallet: txWallet,
                  );
                }),
            ],
          );
        },
      ),
    );
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

  // === FORM THÊM / SỬA VÍ TIỀN ===
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Text(
                      isEditing ? context.tr('edit_wallet') : context.tr('add_wallet'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: context.tr('wallet_name_label'),
                        hintText: context.tr('wallet_name_hint'),
                        prefixIcon: Icon(Icons.wallet, color: Color(selectedColor)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: isEditing ? context.tr('current_balance_label') : context.tr('initial_balance_label'),
                        hintText: '0 đ',
                        prefixIcon: Icon(Icons.attach_money, color: Color(selectedColor)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        final parsed = CurrencyUtils.parseCurrency(val);
                        if (parsed > 0) {
                          final formatted = CurrencyUtils.formatCurrency(parsed);
                          balanceController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('wallet_type_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: isDark ? const Color(0xFF222C2A) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: WalletType.cash, child: Text(context.tr('wallet_cash'))),
                        DropdownMenuItem(value: WalletType.bank, child: Text(context.tr('wallet_bank'))),
                        DropdownMenuItem(value: WalletType.eWallet, child: Text(context.tr('wallet_e_wallet'))),
                        DropdownMenuItem(value: WalletType.credit, child: const Text('Tín dụng')),
                        DropdownMenuItem(value: WalletType.savings, child: Text(context.tr('wallet_savings'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('icon_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _walletIcons.length,
                        itemBuilder: (context, i) {
                          final icon = _walletIcons[i];
                          final isSel = icon.codePoint == selectedIconCode;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIconCode = icon.codePoint),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSel ? Color(selectedColor).withValues(alpha: 0.2) : Colors.transparent,
                                border: Border.all(
                                  color: isSel ? Color(selectedColor) : (isDark ? Colors.white24 : Colors.grey.shade300),
                                  width: isSel ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: isSel ? Color(selectedColor) : (isDark ? Colors.white70 : Colors.grey.shade700), size: 22),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr('color_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _paletteColors.length,
                        itemBuilder: (context, i) {
                          final color = _paletteColors[i];
                          final isSel = color == selectedColor;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = color),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        context.tr('default_wallet_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      value: isDefault,
                      activeThumbColor: const Color(0xFF438883),
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: context.tr('note_optional_label'),
                        prefixIcon: const Icon(Icons.note_alt_outlined),
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
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                TopToast.show(context, context.tr('enter_wallet_name_error'), isError: true);
                                return;
                              }
                              final balance = CurrencyUtils.parseCurrency(balanceController.text);
                              final uid = AuthService().currentUid;
                              if (uid == null) return;

                              if (isEditing) {
                                final updated = wallet.copyWith(
                                  name: name,
                                  balance: balance,
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF438883),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(isEditing ? context.tr('save_changes') : context.tr('create_wallet_btn')),
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
