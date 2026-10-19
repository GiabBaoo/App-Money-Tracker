import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/animated_scale_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

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
                    style: TextStyle(
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
                  color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: FutureBuilder<SettlementModel>(
                  future: settlementService.getGroupSettlements(settlementId).then(
                    (settlements) => settlements.firstWhere((s) => s.id == settlementId),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('${isVi ? 'Lỗi' : 'Error'}: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return Center(child: Text(isVi ? 'Không tìm thấy thanh toán' : 'Settlement not found'));
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
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.receipt_long_rounded, color: primaryColor, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isVi ? 'Thông tin thanh toán' : 'Settlement Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInfoRow(isVi ? 'Người trả:' : 'Payer:', settlement.payerId, isDark),
                                _buildInfoRow(isVi ? 'Người nhận:' : 'Recipient:', settlement.payeeId, isDark),
                                _buildInfoRow(isVi ? 'Số tiền:' : 'Amount:', currencyFormat.format(settlement.amount), isDark, isHighlight: true),
                                _buildInfoRow(isVi ? 'Trạng thái:' : 'Status:', _getStatusText(settlement.status), isDark),
                                if (settlement.notes != null)
                                  _buildInfoRow(isVi ? 'Ghi chú:' : 'Notes:', settlement.notes!, isDark),
                                _buildInfoRow(
                                  isVi ? 'Ngày tạo:' : 'Created date:',
                                  DateFormat('dd/MM/yyyy HH:mm').format(settlement.createdAt),
                                  isDark,
                                ),
                                if (settlement.confirmedAt != null)
                                  _buildInfoRow(
                                    isVi ? 'Ngày xác nhận:' : 'Confirmed date:',
                                    DateFormat('dd/MM/yyyy HH:mm').format(settlement.confirmedAt!),
                                    isDark,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (isPayee && settlement.status == SettlementStatus.pendingConfirmation) ...[
                            AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _confirmSettlement(context, ref, settlementId);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    isVi ? 'Xác Nhận Đã Nhận Tiền' : 'Confirm Received Money',
                                    style: TextStyle(
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    isVi ? 'Từ Chối' : 'Decline',
                                    style: TextStyle(
                                      color: Colors.red,
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

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                fontSize: isHighlight ? 18 : 14,
                color: isHighlight
                    ? const Color(0xFF438883)
                    : (isDark ? Colors.white : Colors.black87),
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

  Future<void> _confirmSettlement(BuildContext context, WidgetRef ref, String settlementId) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    try {
      await ref.read(settlementServiceProvider).confirmSettlement(settlementId, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.instance.isVietnamese ? 'Đã xác nhận thanh toán' : 'Payment confirmed')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LanguageService.instance.isVietnamese ? 'Lỗi' : 'Error'}: $e')),
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
          SnackBar(content: Text(LanguageService.instance.isVietnamese ? 'Đã từ chối thanh toán' : 'Payment declined')),
        );
        Navigator.pop(context);
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
