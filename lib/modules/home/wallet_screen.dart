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

  String _selectedFilter = 'all'; // 'all' hoặc các WalletType
  String? _selectedWalletId; // Ví được chọn để lọc giao dịch (null = tất cả)
  List<WalletModel> _latestWallets = [];
  late DateTime _selectedMonth;

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
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

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
            // === HEADER ===
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

            // === TỔNG TÀI SẢN (NET WORTH CARD) ===
            StreamBuilder<double>(
              stream: _walletRepo.getTotalBalanceStream(),
              builder: (context, snapshot) {
                final totalBalance = snapshot.data ?? 0.0;
                final isAllSelected = _selectedWalletId == null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedWalletId = null);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF163230) : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isAllSelected 
                              ? Colors.white.withValues(alpha: 0.55) 
                              : Colors.white.withValues(alpha: 0.2),
                          width: isAllSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
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
                                  Text(
                                    context.tr('personal_net_worth'),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (isAllSelected) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: StreamBuilder<List<WalletModel>>(
                                  stream: _walletRepo.getWalletsStream(),
                                  builder: (context, wSnap) {
                                    final count = wSnap.data?.length ?? 0;
                                    return Text(
                                      '$count ${context.tr('wallets_title').toLowerCase()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            CurrencyUtils.formatCurrency(totalBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // === PHẦN THÂN: DANH SÁCH VÍ & GIAO DỊCH ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Thanh bộ lọc phân loại ví
                    _buildFilterPills(isDark),
                    const SizedBox(height: 12),

                    // Danh sách ví nằm ngang dạng Cards (Bao gồm thẻ 'Tất cả ví' ở vị trí đầu tiên)
                    SizedBox(
                      height: 180,
                      child: StreamBuilder<List<WalletModel>>(
                        stream: _walletRepo.getWalletsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                          }
                          final allWallets = snapshot.data ?? [];
                          _latestWallets = allWallets;
                          final filteredWallets = _selectedFilter == 'all'
                              ? allWallets
                              : allWallets.where((w) => w.type == _selectedFilter).toList();
                          final totalBalance = allWallets.fold<double>(0.0, (sum, w) => sum + w.balance);

                          final int totalCardCount = filteredWallets.length + 1; // +1 cho thẻ "Tất cả ví"

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
                              final wallet = filteredWallets[index - 1];
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

                    const Divider(height: 24, thickness: 1),

                    // Tiêu đề phần giao dịch gắn với ví
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedWalletId == null 
                                  ? context.tr('tx_history') 
                                  : '${context.tr('wallet')}: ${_getWalletName(_selectedWalletId!)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedWalletId != null)
                            AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedWalletId = null);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF438883).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF438883).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.close_rounded, size: 14, color: Color(0xFF438883)),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('all_wallets'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF438883),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => _showMonthPickerSheet(context),
                              child: Row(
                                children: [
                                  Text(
                                    '${context.tr('date')} ${DateFormat('MM/yyyy').format(_selectedMonth)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF438883),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFF438883), size: 18),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Danh sách giao dịch
                    Expanded(
                      child: StreamBuilder<List<TransactionModel>>(
                        stream: _txRepo.getTransactionsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                          }

                          final allTx = snapshot.data ?? [];
                          final filteredTx = allTx.where((tx) {
                            if (_selectedWalletId != null) {
                              return tx.walletId == _selectedWalletId;
                            }
                            return (tx.date.year == _selectedMonth.year && tx.date.month == _selectedMonth.month) &&
                                tx.source == 'personal';
                          }).toList();

                          if (filteredTx.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Chưa có giao dịch nào',
                                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          final reverseBalances = CurrencyUtils.calculateReverseWalletBalances(
                            allTransactions: allTx,
                            wallets: _latestWallets,
                          );

                          return ListView.builder(
                            key: const PageStorageKey('wallet_tx_list'),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                            itemCount: filteredTx.length,
                            itemBuilder: (context, index) {
                              final tx = filteredTx[index];
                              WalletModel? txWallet;
                              try {
                                txWallet = _latestWallets.firstWhere((w) => w.id == tx.walletId);
                              } catch (_) {}
                              return StaggeredListItem(
                                index: index,
                                child: TransactionItem(
                                  transaction: tx,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === THANH LỌC PHÂN LOẠI ===
  Widget _buildFilterPills(bool isDark) {
    final isEnglish = context.tr('tab_expense') != 'Chi tiêu';
    final filters = [
      {'key': 'all', 'label': isEnglish ? 'All' : 'Tất cả'},
      {'key': WalletType.cash, 'label': context.tr('wallet_cash')},
      {'key': WalletType.bank, 'label': context.tr('wallet_bank')},
      {'key': WalletType.eWallet, 'label': context.tr('wallet_e_wallet')},
      {'key': WalletType.credit, 'label': isEnglish ? 'Credit' : 'Tín dụng'},
      {'key': WalletType.savings, 'label': context.tr('wallet_savings')},
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedFilter == f['key'];

          return AnimatedScaleButton(
            scaleDown: 0.94,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedFilter = f['key']!;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883))
                    : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFE8F5F1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF438883)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getWalletName(String walletId) {
    try {
      final match = _latestWallets.firstWhere((w) => w.id == walletId);
      return match.name;
    } catch (_) {
      return '';
    }
  }

  // === THẺ TẤT CẢ VÍ (ALL WALLETS CARD) ===
  Widget _buildAllWalletsCard(
    BuildContext context,
    List<WalletModel> wallets,
    double totalBalance,
    bool isSelected,
    bool isDark,
  ) {
    const cardColor = Color(0xFF438883);

    return AnimatedScaleButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedWalletId = null;
        });
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222C2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cardColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? cardColor.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: cardColor, size: 21),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            context.tr('all_wallets'),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${wallets.length} ${context.tr('wallets_title').toLowerCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: cardColor, size: 22)
                else
                  Icon(Icons.radio_button_unchecked_rounded,
                      color: isDark ? Colors.white24 : Colors.grey.shade400, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('total_balance'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyUtils.formatCurrency(totalBalance),
                          style: const TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: cardColor,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSelected ? (context.tr('see_all_wallets') != '✕ Xem tất cả ví' ? 'Selected' : 'Đang chọn') : (context.tr('see_all_wallets') != '✕ Xem tất cả ví' ? 'All' : 'Tất cả'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cardColor,
                        ),
                      ),
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

  // === THẺ VÍ (WALLET CARD) ===
  Widget _buildWalletCard(BuildContext context, WalletModel wallet, bool isSelected, bool isDark) {
    final walletColor = Color(wallet.colorValue);

    return AnimatedScaleButton(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedWalletId = (_selectedWalletId == wallet.id) ? null : wallet.id;
        });
      },
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222C2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? walletColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2)),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? walletColor.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: walletColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(wallet.icon, color: walletColor, size: 21),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            wallet.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          wallet.typeDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade600),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showWalletForm(context, wallet: wallet);
                    } else if (value == 'delete') {
                      _confirmDeleteWallet(context, wallet);
                    }
                  },
                  itemBuilder: (context) => [
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wallet.accountNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'STK: ${wallet.accountNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyUtils.formatCurrency(wallet.balance),
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: walletColor,
                          ),
                        ),
                      ),
                    ),
                    if (wallet.isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF438883).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Mặc định',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF438883),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
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
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? context.tr('edit_wallet') : context.tr('create_wallet'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Tên ví
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Tên ví *',
                        hintText: 'VD: Ví tiền mặt, MB Bank, MoMo...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Phân loại ví
                    const Text('Phân loại ví', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: WalletType.getAllTypes().map((type) {
                        final isSel = selectedType == type;
                        return ChoiceChip(
                          label: Text(WalletType.getDisplayName(type)),
                          selected: isSel,
                          selectedColor: isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedType = type;
                                selectedIconCode = WalletType.getDefaultIcon(type).codePoint;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 3. Số dư ban đầu
                    TextField(
                      controller: balanceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Số dư hiện tại (VNĐ)' : 'Số dư khởi tạo (VNĐ)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Bảng chọn Icon
                    const Text('Chọn biểu tượng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _walletIcons.length,
                        itemBuilder: (context, i) {
                          final iconData = _walletIcons[i];
                          final isSel = selectedIconCode == iconData.codePoint;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIconCode = iconData.codePoint),
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel ? Color(selectedColor) : Colors.grey.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                iconData,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 6. Bảng chọn Màu sắc
                    const Text('Chọn màu chủ đạo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _paletteColors.length,
                        itemBuilder: (context, i) {
                          final colorVal = _paletteColors[i];
                          final isSel = selectedColor == colorVal;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedColor = colorVal),
                            child: Container(
                              width: 38,
                              height: 38,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(colorVal),
                                border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: Color(colorVal).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 7. Đặt làm ví mặc định
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đặt làm ví mặc định', style: TextStyle(fontSize: 14)),
                      value: isDefault,
                      activeThumbColor: const Color(0xFF438883),
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),

                    const SizedBox(height: 20),

                    // Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(selectedColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            TopToast.show(context, 'Vui lòng nhập tên ví!', isError: true);
                            return;
                          }

                          final balance = CurrencyUtils.parseCurrency(balanceController.text);
                          final uid = AuthService().currentUid ?? '';

                          if (isEditing) {
                            final updated = wallet.copyWith(
                              name: nameController.text.trim(),
                              type: selectedType,
                              balance: balance,
                              iconCode: selectedIconCode,
                              colorValue: selectedColor,
                              isDefault: isDefault,
                              accountNumber: '',
                              note: noteController.text.trim(),
                            );
                            await _walletRepo.updateWallet(updated);
                          } else {
                            final newWallet = WalletModel(
                              id: '',
                              uid: uid,
                              name: nameController.text.trim(),
                              type: selectedType,
                              balance: balance,
                              initialBalance: balance,
                              iconCode: selectedIconCode,
                              colorValue: selectedColor,
                              isDefault: isDefault,
                              accountNumber: '',
                              note: noteController.text.trim(),
                            );
                            await _walletRepo.addWallet(newWallet);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          isEditing ? 'Lưu thay đổi' : 'Tạo ví mới',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  // === MODAL CHUYỂN TIỀN GIỮA CÁC VÍ ===
  void _showTransferDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallets = await _walletRepo.getWallets();

    if (wallets.length < 2) {
      if (context.mounted) {
        TopToast.show(context, 'Bạn cần có ít nhất 2 ví để thực hiện chuyển tiền!', isError: true);
      }
      return;
    }

    String fromId = wallets[0].id;
    String toId = wallets[1].id;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    if (!context.mounted) return;

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
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chuyển tiền giữa các ví',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chọn ví nguồn
                  const Text('Từ ví nguồn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: fromId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: wallets.map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.name} (${CurrencyUtils.formatCurrency(w.balance)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          fromId = val;
                          if (toId == fromId) {
                            toId = wallets.firstWhere((w) => w.id != fromId).id;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Chọn ví đích
                  const Text('Đến ví đích', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: toId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: wallets.where((w) => w.id != fromId).map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Text('${w.name} (${CurrencyUtils.formatCurrency(w.balance)})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => toId = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Số tiền
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Số tiền chuyển (VNĐ) *',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ghi chú
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú (tùy chọn)',
                      hintText: 'VD: Rút tiền mặt, nạp MoMo...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B3736) : const Color(0xFFF6F8F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nút chuyển tiền
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF438883),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final amount = CurrencyUtils.parseCurrency(amountController.text);
                        if (amount <= 0) {
                          TopToast.show(context, 'Vui lòng nhập số tiền hợp lệ!', isError: true);
                          return;
                        }

                        final fromW = wallets.firstWhere((w) => w.id == fromId);
                        if (fromW.balance < amount) {
                          TopToast.show(context, 'Số dư ví nguồn không đủ!', isError: true);
                          return;
                        }

                        final ok = await _walletRepo.transferMoney(
                          fromWalletId: fromId,
                          toWalletId: toId,
                          amount: amount,
                          note: noteController.text.trim(),
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted && ok) {
                          TopToast.show(context, 'Chuyển tiền thành công!');
                        }
                      },
                      child: const Text(
                        'Xác nhận chuyển tiền',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // === HỘP THOẠI XÁC NHẬN XÓA VÍ ===
  void _confirmDeleteWallet(BuildContext context, WalletModel wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa ví'),
        content: Text('Bạn có chắc chắn muốn xóa ví "${wallet.name}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              await _walletRepo.deleteWallet(wallet.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // === CHỌN THÁNG ===
  void _showMonthPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    int tempYear = _selectedMonth.year;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A2625) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thanh gạt (Drag handle)
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Tiêu đề & Điều hướng Năm
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('stats_filter_month') == 'Tháng'
                                  ? 'Chọn tháng xem giao dịch'
                                  : 'Select transaction month',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${context.tr('stats_filter_month') == 'Tháng' ? 'Năm' : 'Year'} $tempYear',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF438883),
                              ),
                            ),
                          ],
                        ),

                        // Nút chuyển năm (trước / sau)
                        Container(
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
                                  setSheetState(() {
                                    tempYear--;
                                  });
                                },
                              ),
                              Text(
                                '$tempYear',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                                    ? null // Không cho chọn năm tương lai
                                    : () {
                                        setSheetState(() {
                                          tempYear++;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Lưới 12 tháng (3 cột x 4 hàng)
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
                        // Khóa tháng ở tương lai: nếu năm > năm nay, hoặc cùng năm nay nhưng tháng > tháng này
                        final isFuture = (tempYear > now.year) || (tempYear == now.year && month > now.month);
                        final isCurrentMonth = (tempYear == now.year && month == now.month);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isFuture
                                ? null // Khóa hoàn toàn không cho bấm tháng tương lai
                                : () {
                                    setState(() {
                                      _selectedMonth = DateTime(tempYear, month);
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
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF438883).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isFuture) ...[
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 4),
                                  ] else if (isSel) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    context.tr('stats_filter_month') == 'Tháng'
                                        ? 'Tháng $month'
                                        : 'Month $month',
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Chú thích nhỏ bên dưới
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('stats_filter_month') == 'Tháng'
                              ? 'Các tháng tương lai chưa diễn ra được khóa'
                              : 'Future months are locked',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
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
      },
    );
  }
}
