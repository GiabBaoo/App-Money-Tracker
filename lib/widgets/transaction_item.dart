import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../data/repositories/wallet_repository.dart';
import '../utils/currency_format_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/transaction_detail_screen.dart';
import '../utils/category_utils.dart';
import '../core/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/group_expense/presentation/providers/group_expense_providers.dart';
import 'animated_scale_button.dart';
import 'colored_amount_text.dart';
import '../services/language_service.dart';
import '../core/theme/app_theme.dart';

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
    ref.watch(categoryStyleProvider);
    final bool isIncome = transaction.isIncome;
    final isDark = context.isDarkMode;

    // Kiểm tra xem đây có phải là giao dịch quỹ không
    final bool isGroupTransaction =
        transaction.groupId != null && !transaction.isTransfer;

    // Lấy icon: ưu tiên cấu hình mới của danh mục, fallback icon đã lưu của transaction
    IconData displayIcon = CategoryUtils.getCategoryIcon(
      transaction.category,
      fallbackCode: transaction.categoryIconCode,
    );

    if (isGroupTransaction) {
      // Nếu có groupIconCode, dùng nó
      if (transaction.groupIconCode != null) {
        displayIcon = IconData(
          transaction.groupIconCode as int,
          fontFamily: 'MaterialIcons',
        );
      } else if (transaction.groupId != null && !transaction.isTransfer) {
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
    final Color bgColor = CategoryUtils.getLightBgColor(
      transaction.category,
      isDark,
    );

    // Xác định ví thực hiện giao dịch (để hiển thị tên + icon + số dư)
    WalletModel? effectiveWallet = wallet;
    if (effectiveWallet == null) {
      final allWallets = WalletRepository().latestWallets;
      if (transaction.walletId.isNotEmpty) {
        try {
          effectiveWallet = allWallets.firstWhere(
            (w) => w.id == transaction.walletId,
          );
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

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: AnimatedScaleButton(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              PageTransitions.slideRight(
                TransactionDetailScreen(transaction: transaction),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icon Hạng mục (48x48 cân đối, bo góc chuẩn Fintech 14px)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppRadius.iconContainer,
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
                                    context.trCat(transaction.category),
                                    style: context.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: context.colors.onSurface,
                                          letterSpacing: -0.3,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (transaction.isTransfer) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isDark
                                                  ? AppColors
                                                        .transferIndigoLight
                                                  : AppColors.transferIndigo)
                                              .withValues(alpha: 0.15),
                                      borderRadius: AppRadius.badge,
                                      border: Border.all(
                                        color:
                                            (isDark
                                                    ? AppColors
                                                          .transferIndigoLight
                                                    : AppColors.transferIndigo)
                                                .withValues(alpha: 0.3),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 11,
                                          color: isDark
                                              ? AppColors.transferIndigoLight
                                              : AppColors.transferIndigoDark,
                                        ),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          context.trCat('Chuyển ví'),
                                          style: context.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 10,
                                                color: isDark
                                                    ? AppColors
                                                          .transferIndigoLight
                                                    : AppColors
                                                          .transferIndigoDark,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: AppRadius.badge,
                                      border: Border.all(
                                        color: context.colors.primary
                                            .withValues(alpha: 0.25),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded,
                                          size: 11,
                                          color: context.colors.primary,
                                        ),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          context.trCat('Hóa đơn'),
                                          style: context.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 10,
                                                color: context.colors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (transaction.location != null &&
                                    transaction.location!
                                        .trim()
                                        .isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.warning.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: AppRadius.badge,
                                      border: Border.all(
                                        color: context.warning.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 10,
                                          color: context.warning,
                                        ),
                                        const SizedBox(width: 2),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 80,
                                          ),
                                          child: Text(
                                            transaction.location!.trim(),
                                            style: context.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 10,
                                                  color: context.warning,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ColoredAmountText(
                              amount: transaction.amount,
                              isIncome: isIncome,
                              isTransfer: transaction.isTransfer,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
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
                                _buildWalletChip(
                                  context,
                                  isDark,
                                  effectiveWallet,
                                ),
                                if (contextText.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Text(
                                      '•',
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 10,
                                            color: context
                                                .colors
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      contextText,
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            color:
                                                context.colors.onSurfaceVariant,
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
      ),
    );
  }

  /// Chip tag ví tiền hiển thị gọn gàng, mang màu sắc & icon đặc trưng của ví
  Widget _buildWalletChip(
    BuildContext context,
    bool isDark,
    WalletModel? wallet,
  ) {
    final Color themeColor = (wallet != null && wallet.colorValue != 0)
        ? Color(wallet.colorValue)
        : context.colors.primary;

    final IconData icon = (wallet != null && wallet.iconCode != 0)
        ? wallet.icon
        : (wallet != null
              ? WalletType.getDefaultIcon(wallet.type)
              : Icons.account_balance_wallet_rounded);

    final String name = (wallet != null && wallet.name.trim().isNotEmpty)
        ? wallet.name.trim()
        : context.tr('wallets_title');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: isDark ? 0.20 : 0.08),
        borderRadius: AppRadius.badge,
        border: Border.all(
          color: themeColor.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 11, color: themeColor),
          const SizedBox(width: 3.5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 85),
            child: Text(
              name,
              style: context.textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.9)
                    : themeColor,
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
    final String label = isCustomLabel
        ? runningTotalLabel!
        : context.tr('balance_prefix');
    final String formattedAmount = CurrencyUtils.formatCurrency(runningTotal!);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: formattedAmount,
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
