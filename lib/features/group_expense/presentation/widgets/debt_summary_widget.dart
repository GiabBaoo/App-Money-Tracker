import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/debt_model.dart';
import '../providers/group_expense_providers.dart';
import '../screens/settlement_confirm_screen.dart';

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
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Không có công nợ'),
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
                  ? 'Bạn nợ ${debt.creditorId}'
                  : isCreditor
                      ? '${debt.debtorId} nợ bạn'
                      : '${debt.debtorId} nợ ${debt.creditorId}',
            ),
            subtitle: Text(currencyFormat.format(debt.amount)),
            trailing: isDebtor
                ? ElevatedButton(
                    onPressed: () => _showSettlementDialog(context, ref, debt),
                    child: const Text('Thanh toán'),
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
        title: const Text('Xác nhận thanh toán'),
        content: Text(
          'Bạn muốn thanh toán ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(debt.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createSettlement(context, ref, debt);
            },
            child: const Text('Xác nhận'),
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
          const SnackBar(content: Text('Đã tạo thanh toán, chờ xác nhận')),
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettlementConfirmScreen(settlementId: settlement.id),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}
