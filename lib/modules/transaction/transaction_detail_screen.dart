import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/page_transitions.dart';
import 'edit_transaction_screen.dart';
import '../../utils/currency_format_utils.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isIncome = transaction.isIncome;
    final category = transaction.category;
    final description = transaction.description;
    final date = '${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}/${transaction.date.year}';
    final time = transaction.time;
    final amount = '${isIncome ? "+" : "-"} ${CurrencyUtils.formatCurrency(transaction.amount)}';
    
    // Kiểm tra xem đây có phải là giao dịch quỹ không
    final isGroupTransaction = transaction.groupIconCode != null && transaction.groupId != null;
    final icon = isGroupTransaction
        ? IconData(transaction.groupIconCode as int, fontFamily: 'MaterialIcons')
        : transaction.icon;

    // Tự động chọn màu tùy theo trạng thái Thu / Chi
    final Color statusColor = isIncome
        ? const Color(0xFF24A869) // Xanh lá đậm hơn cho rõ
        : const Color(0xFFE17E5B); // Cam đất (Thay cho Đỏ)
    final String statusText = isIncome ? 'Khoản Thu' : 'Khoản Chi';

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF0F2625) 
        : const Color(0xFF438883), // Nền xanh lá mạ
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Chi tiết giao dịch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(context, PageTransitions.slideRight(EditTransactionScreen(transaction: transaction)));
                      } else if (value == 'delete') {
                        // Gọi logic xóa từ một helper hoặc Navigator pop với kết quả
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Xác nhận xóa'),
                            content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          FirestoreService().deleteTransaction(transaction.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined, color: Color(0xFF438883), size: 20),
                            SizedBox(width: 10),
                            Text('Chỉnh sửa'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 10),
                            Text('Xóa giao dịch', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG BO GÓC TRÊN
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 40,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      // ICON GIAO DỊCH CHÍNH GIỮA
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isIncome
                              ? (isDark ? const Color(0xFF2E4E4C) : const Color(0xFFE8F5F3))
                              : (isDark ? const Color(0xFF4E2E2E) : const Color(0xFFFEE2E2)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: statusColor, size: 36),
                      ),
                      const SizedBox(height: 16),

                      // VIÊN THUỐC TRẠNG THÁI (Thu nhập / Chi phí)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SỐ TIỀN TO BỰ
                      Text(
                        amount,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF222222),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // KHỐI CHI TIẾT GIAO DỊCH
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chi tiết giao dịch',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF222222),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_up, color: isDark ? Colors.white54 : Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // CÁC DÒNG THÔNG TIN
                      _buildDetailRow('Danh mục', category),
                      _buildDetailRow('Nội dung', description.isEmpty ? 'Không có nội dung' : description),
                      _buildDetailRow('Thời gian', time),
                      _buildDetailRow('Ngày', date),

                      const SizedBox(height: 20),
                      Divider(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFEEEEEE), thickness: 1),
                      const SizedBox(height: 20),

                      // TỔNG CỘNG
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF666666),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            amount,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF222222),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  // --- HÀM TẠO TỪNG DÒNG CHI TIẾT ---
  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF666666),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF222222)),
                    fontSize: 16,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
