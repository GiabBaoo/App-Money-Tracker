import '../../../../core/theme/app_theme.dart';
import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_toast.dart';
import '../../data/models/settlement_model.dart';
import '../providers/group_expense_providers.dart';

class SettlementConfirmScreen extends ConsumerWidget {
  final String settlementId;

  const SettlementConfirmScreen({super.key, required this.settlementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementService = ref.watch(settlementServiceProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isVi ? 'Xác Nhận Thanh Toán' : 'Confirm Settlement',
                    style: context.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark : AppColors.bgLight,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: FutureBuilder<SettlementModel>(
                  future: settlementService
                      .getGroupSettlements(settlementId)
                      .then(
                        (settlements) =>
                            settlements.firstWhere((s) => s.id == settlementId),
                      ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '${isVi ? 'Lỗi' : 'Error'}: ${snapshot.error}',
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return Center(
                        child: Text(
                          isVi
                              ? 'Không tìm thấy thanh toán'
                              : 'Settlement not found',
                        ),
                      );
                    }

                    final settlement = snapshot.data!;
                    final isPayee = settlement.payeeId == currentUserId;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: context.borderColor),
                              boxShadow: AppShadows.card(isDark),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        color: primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isVi
                                          ? 'Thông tin thanh toán'
                                          : 'Settlement Information',
                                      style: context.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: context.colors.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInfoRow(
                                  context,
                                  isVi ? 'Người trả:' : 'Payer:',
                                  settlement.payerId,
                                  isDark,
                                ),
                                _buildInfoRow(
                                  context,
                                  isVi ? 'Người nhận:' : 'Recipient:',
                                  settlement.payeeId,
                                  isDark,
                                ),
                                _buildInfoRow(
                                  context,
                                  isVi ? 'Số tiền:' : 'Amount:',
                                  currencyFormat.format(settlement.amount),
                                  isDark,
                                  isHighlight: true,
                                ),
                                _buildInfoRow(
                                  context,
                                  isVi ? 'Trạng thái:' : 'Status:',
                                  _getStatusText(settlement.status),
                                  isDark,
                                ),
                                if (settlement.notes != null)
                                  _buildInfoRow(
                                    context,
                                    isVi ? 'Ghi chú:' : 'Notes:',
                                    settlement.notes!,
                                    isDark,
                                  ),
                                _buildInfoRow(
                                  context,
                                  isVi ? 'Ngày tạo:' : 'Created date:',
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(settlement.createdAt),
                                  isDark,
                                ),
                                if (settlement.confirmedAt != null)
                                  _buildInfoRow(
                                    context,
                                    isVi ? 'Ngày xác nhận:' : 'Confirmed date:',
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(settlement.confirmedAt!),
                                    isDark,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (isPayee &&
                              settlement.status ==
                                  SettlementStatus.pendingConfirmation) ...[
                            AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _confirmSettlement(context, ref, settlementId);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: context.income,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: AppShadows.glow(
                                    context.income,
                                    alpha: 0.35,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    isVi
                                        ? 'Xác Nhận Đã Nhận Tiền'
                                        : 'Confirm Received Money',
                                    style: context.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _rejectSettlement(context, ref, settlementId);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: context.expense.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.expense.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    isVi ? 'Từ Chối' : 'Decline',
                                    style: context.textTheme.titleMedium
                                        ?.copyWith(
                                          color: context.expense,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                fontSize: isHighlight ? 18 : 14,
                color: isHighlight
                    ? context.colors.primary
                    : context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(SettlementStatus status) {
    switch (status) {
      case SettlementStatus.pendingConfirmation:
        return isVi ? 'Chờ xác nhận' : 'Pending Confirmation';
      case SettlementStatus.confirmed:
        return isVi ? 'Đã xác nhận' : 'Confirmed';
      case SettlementStatus.rejected:
        return isVi ? 'Đã từ chối' : 'Declined';
    }
  }

  Future<void> _confirmSettlement(
    BuildContext context,
    WidgetRef ref,
    String settlementId,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      await ref
          .read(settlementServiceProvider)
          .confirmSettlement(settlementId, currentUserId);

      if (context.mounted) {
        MonoToast.success(
          context,
          LanguageService.instance.isVietnamese
              ? 'Đã xác nhận thanh toán'
              : 'Payment confirmed',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        MonoToast.error(
          context,
          '${LanguageService.instance.isVietnamese ? 'Lỗi' : 'Error'}: $e',
        );
      }
    }
  }

  Future<void> _rejectSettlement(
    BuildContext context,
    WidgetRef ref,
    String settlementId,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      await ref
          .read(settlementServiceProvider)
          .rejectSettlement(settlementId, currentUserId);

      if (context.mounted) {
        MonoToast.info(
          context,
          LanguageService.instance.isVietnamese
              ? 'Đã từ chối thanh toán'
              : 'Payment declined',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        MonoToast.error(
          context,
          '${LanguageService.instance.isVietnamese ? 'Lỗi' : 'Error'}: $e',
        );
      }
    }
  }
}
