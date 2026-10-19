import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/debt_model.dart';
import '../providers/group_expense_providers.dart';
import '../screens/settlement_confirm_screen.dart';
import '../../../../utils/page_transitions.dart';

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

    if (debts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(isVi ? 'Không có công nợ' : 'No debts or balances'),
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

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              isDebtor ? Icons.arrow_upward : Icons.arrow_downward,
              color: isDebtor ? Colors.red : Colors.green,
            ),
            title: Text(
              isDebtor
                  ? (isVi ? 'Bạn nợ ${debt.creditorId}' : 'You owe ${debt.creditorId}')
                  : isCreditor
                      ? (isVi ? '${debt.debtorId} nợ bạn' : '${debt.debtorId} owes you')
                      : (isVi ? '${debt.debtorId} nợ ${debt.creditorId}' : '${debt.debtorId} owes ${debt.creditorId}'),
            ),
            subtitle: Text(currencyFormat.format(debt.amount)),
            trailing: isDebtor
                ? ElevatedButton(
                    onPressed: () => _showSettlementDialog(context, ref, debt),
                    child: Text(isVi ? 'Thanh toán' : 'Settle'),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showSettlementDialog(BuildContext context, WidgetRef ref, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVi ? 'Xác nhận thanh toán' : 'Confirm Settlement'),
        content: Text(
          isVi ? 'Bạn muốn thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(debt.amount)}?' : 'Do you want to settle ${NumberFormat.currency(locale: 'en_US', symbol: '\$').format(debt.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createSettlement(context, ref, debt);
            },
            child: Text(isVi ? 'Xác nhận' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSettlement(BuildContext context, WidgetRef ref, DebtModel debt) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      final dto = CreateSettlementDto(
        groupId: groupId,
        payerId: debt.debtorId,
        payeeId: debt.creditorId,
        amount: debt.amount,
      );

      final settlement = await ref.read(settlementServiceProvider).createSettlement(dto, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.instance.isVietnamese ? 'Đã tạo thanh toán, chờ xác nhận' : 'Settlement created, awaiting confirmation')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LanguageService.instance.isVietnamese ? 'Lỗi' : 'Error'}: $e')),
        );
      }
    }
  }
}
