import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../data/repositories/wallet_repository.dart';
import '../utils/currency_format_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/transaction_detail_screen.dart';
import '../utils/category_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/group_expense/presentation/providers/group_expense_providers.dart';
import 'animated_scale_button.dart';
import 'colored_amount_text.dart';

class TransactionItem extends ConsumerWidget {
  final TransactionModel transaction;
  final bool showDate;
  final double? runningTotal;
  final String? runningTotalLabel;
  final WalletModel? wallet;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.showDate = false,
    this.runningTotal,
    this.runningTotalLabel,
    this.wallet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isIncome = transaction.isIncome;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Kiểm tra xem đây có phải là giao dịch quỹ không
    final bool isGroupTransaction = transaction.groupId != null;
    
    // Lấy icon: nếu là giao dịch quỹ, lấy từ groupIconCode hoặc query group
    IconData displayIcon = transaction.icon;
    
    if (isGroupTransaction) {
      // Nếu có groupIconCode, dùng nó
      if (transaction.groupIconCode != null) {
        displayIcon = IconData(transaction.groupIconCode as int, fontFamily: 'MaterialIcons');
      } else if (transaction.groupId != null) {
        // Nếu không có groupIconCode nhưng có groupId, query group để lấy icon
        final groupAsync = ref.watch(groupStreamProvider(transaction.groupId!));
        displayIcon = groupAsync.maybeWhen(
          data: (group) => group?.iconCode != null 
              ? IconData(group!.iconCode as int, fontFamily: 'MaterialIcons')
              : Icons.group,
          orElse: () => Icons.group,
        );
      }
    }

    final Color iconColor = isGroupTransaction
        ? CategoryUtils.getVibrantColor(transaction.category)
        : CategoryUtils.getVibrantColor(transaction.category);
    final Color bgColor = CategoryUtils.getLightBgColor(transaction.category, isDark);

    // Xác định ví thực hiện giao dịch (để hiển thị tên + icon + số dư)
    WalletModel? effectiveWallet = wallet;
    if (effectiveWallet == null) {
      final allWallets = WalletRepository().latestWallets;
      if (transaction.walletId.isNotEmpty) {
        try {
          effectiveWallet = allWallets.firstWhere((w) => w.id == transaction.walletId);
        } catch (_) {}
      }
      if (effectiveWallet == null && allWallets.isNotEmpty) {
        try {
          effectiveWallet = allWallets.firstWhere((w) => w.isDefault);
        } catch (_) {
          effectiveWallet = allWallets.first;
        }
      }
    }

    // Chuẩn bị text phụ (Ghi chú hoặc Giờ/Ngày, không để chữ 'Không có mô tả' gây rối mắt)
    final hasDesc = transaction.description.trim().isNotEmpty;
    final datePart = showDate ? CurrencyUtils.formatDate(transaction.date) : '';

    String contextText = '';
    if (hasDesc) {
      contextText = transaction.description.trim();
      if (datePart.isNotEmpty) {
        contextText = '$contextText  •  $datePart';
      }
    } else {
      if (datePart.isNotEmpty) {
        contextText = datePart;
        if (transaction.time.isNotEmpty) {
          contextText = '$datePart  ${transaction.time}';
        }
      } else if (transaction.time.isNotEmpty) {
        contextText = transaction.time;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            PageTransitions.slideRight(TransactionDetailScreen(transaction: transaction)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icon Hạng mục (48x48 cân đối, hiện đại)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(displayIcon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // 2. Nội dung 2 hàng cân đối & logic
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HÀNG 1: Tên hạng mục (Trái) & Số tiền thu/chi (Phải)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  transaction.category,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (transaction.isTransfer) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.blueGrey.shade700 : const Color(0xFF0284C7)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz_rounded, size: 11, color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7)),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Chuyển ví',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (transaction.hasPhoto) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF438883).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_long_rounded, size: 11, color: Color(0xFF438883)),
                                      SizedBox(width: 2),
                                      Text(
                                        'Hóa đơn',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF438883), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ColoredAmountText(
                          amount: transaction.amount,
                          isIncome: isIncome,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // HÀNG 2: [Tag Ví] • Ghi chú/Thời gian (Trái) & Số dư ví sau GD (Phải)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Bên trái: Tag Ví rõ ràng theo từng loại + Ghi chú / Thời gian
                        Expanded(
                          child: Row(
                            children: [
                              _buildWalletChip(context, isDark, effectiveWallet),
                              if (contextText.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    contextText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Bên phải: Số dư ví tại thời điểm đó (hoặc tổng danh mục)
                        if (runningTotal != null) ...[
                          const SizedBox(width: 8),
                          _buildBalanceText(context, isDark),
                        ],
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

  /// Chip tag ví tiền hiển thị gọn gàng, mang màu sắc & icon đặc trưng của ví
  Widget _buildWalletChip(BuildContext context, bool isDark, WalletModel? wallet) {
    final Color themeColor = (wallet != null && wallet.colorValue != 0)
        ? Color(wallet.colorValue)
        : const Color(0xFF438883);

    final IconData icon = (wallet != null && wallet.iconCode != 0)
        ? wallet.icon
        : (wallet != null
            ? WalletType.getDefaultIcon(wallet.type)
            : Icons.account_balance_wallet_rounded);

    final String name = (wallet != null && wallet.name.trim().isNotEmpty)
        ? wallet.name.trim()
        : 'Ví tiền';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: themeColor.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 11,
            color: themeColor,
          ),
          const SizedBox(width: 3.5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 85),
            child: Text(
              name,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : themeColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị số dư ví rõ ràng, tinh tế bên dưới số tiền
  Widget _buildBalanceText(BuildContext context, bool isDark) {
    final bool isCustomLabel = runningTotalLabel != null;
    final String label = isCustomLabel ? runningTotalLabel! : 'Số dư';
    final String formattedAmount = CurrencyUtils.formatCurrency(runningTotal!);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          TextSpan(
            text: formattedAmount,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}
