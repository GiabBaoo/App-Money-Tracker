import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/debt_model.dart';
import '../providers/group_expense_providers.dart';
import '../screens/settlement_confirm_screen.dart';
import '../../../../utils/page_transitions.dart';
import '../../../../widgets/mono_dialog.dart';
import '../../../../widgets/mono_toast.dart';
import '../../../../widgets/animated_scale_button.dart';

class DebtSummaryWidget extends ConsumerWidget {
  final String groupId;
  final List<DebtModel> debts;

  const DebtSummaryWidget({
    super.key,
    required this.groupId,
    required this.debts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final currentUserId = ref.watch(currentUserIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    if (debts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            isVi
                ? 'Không có công nợ nào cần thanh toán'
                : 'No debts or balances',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        final isDebtor = debt.debtorId == currentUserId;
        final isCreditor = debt.creditorId == currentUserId;
        final color = isDebtor
            ? Colors.redAccent
            : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDebtor
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDebtor
                          ? (isVi
                                ? 'Bạn nợ ${debt.creditorId}'
                                : 'You owe ${debt.creditorId}')
                          : isCreditor
                          ? (isVi
                                ? '${debt.debtorId} nợ bạn'
                                : '${debt.debtorId} owes you')
                          : (isVi
                                ? '${debt.debtorId} nợ ${debt.creditorId}'
                                : '${debt.debtorId} owes ${debt.creditorId}'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(debt.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDebtor)
                AnimatedScaleButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showSettlementDialog(context, ref, debt);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isVi ? 'Thanh toán' : 'Settle',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSettlementDialog(
    BuildContext context,
    WidgetRef ref,
    DebtModel debt,
  ) async {
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Xác nhận thanh toán' : 'Confirm Settlement',
      message: isVi
          ? 'Bạn muốn thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(debt.amount)}?'
          : 'Do you want to settle ${NumberFormat.currency(locale: 'en_US', symbol: '\$').format(debt.amount)}?',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Xác nhận' : 'Confirm',
      icon: Icons.payments_outlined,
    );

    if (confirmed == true && context.mounted) {
      await _createSettlement(context, ref, debt);
    }
  }

  Future<void> _createSettlement(
    BuildContext context,
    WidgetRef ref,
    DebtModel debt,
  ) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      final dto = CreateSettlementDto(
        groupId: groupId,
        payerId: debt.debtorId,
        payeeId: debt.creditorId,
        amount: debt.amount,
      );

      final settlement = await ref
          .read(settlementServiceProvider)
          .createSettlement(dto, currentUserId);

      if (context.mounted) {
        MonoToast.success(
          context,
          LanguageService.instance.isVietnamese
              ? 'Đã tạo thanh toán, chờ xác nhận'
              : 'Settlement created, awaiting confirmation',
        );

        Navigator.push(
          context,
          PageTransitions.slideRight(
            SettlementConfirmScreen(settlementId: settlement.id),
          ),
        );
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
