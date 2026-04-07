import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Nhận Thanh Toán'),
      ),
      body: FutureBuilder<SettlementModel>(
        future: settlementService.getGroupSettlements(settlementId).then(
          (settlements) => settlements.firstWhere((s) => s.id == settlementId),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Không tìm thấy thanh toán'));
          }

          final settlement = snapshot.data!;
          final isPayee = settlement.payeeId == currentUserId;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin thanh toán',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Người trả:', settlement.payerId),
                        _buildInfoRow('Người nhận:', settlement.payeeId),
                        _buildInfoRow('Số tiền:', currencyFormat.format(settlement.amount)),
                        _buildInfoRow('Trạng thái:', _getStatusText(settlement.status)),
                        if (settlement.notes != null)
                          _buildInfoRow('Ghi chú:', settlement.notes!),
                        _buildInfoRow(
                          'Ngày tạo:',
                          DateFormat('dd/MM/yyyy HH:mm').format(settlement.createdAt),
                        ),
                        if (settlement.confirmedAt != null)
                          _buildInfoRow(
                            'Ngày xác nhận:',
                            DateFormat('dd/MM/yyyy HH:mm').format(settlement.confirmedAt!),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (isPayee && settlement.status == SettlementStatus.pendingConfirmation) ...[
                  ElevatedButton(
                    onPressed: () => _confirmSettlement(context, ref, settlementId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Xác Nhận Đã Nhận Tiền'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _rejectSettlement(context, ref, settlementId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Từ Chối'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusText(SettlementStatus status) {
    switch (status) {
      case SettlementStatus.pendingConfirmation:
        return 'Chờ xác nhận';
      case SettlementStatus.confirmed:
        return 'Đã xác nhận';
      case SettlementStatus.rejected:
        return 'Đã từ chối';
    }
  }

  Future<void> _confirmSettlement(BuildContext context, WidgetRef ref, String settlementId) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      await ref.read(settlementServiceProvider).confirmSettlement(settlementId, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận thanh toán')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _rejectSettlement(BuildContext context, WidgetRef ref, String settlementId) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      await ref.read(settlementServiceProvider).rejectSettlement(settlementId, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối thanh toán')),
        );
        Navigator.pop(context);
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
