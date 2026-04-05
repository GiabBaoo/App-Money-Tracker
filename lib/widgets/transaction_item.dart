import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/transaction_detail_screen.dart';
import '../utils/category_utils.dart';

class TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final bool showDate;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIncome = transaction.isIncome;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Màu sắc sống động từ CategoryUtils (Yêu cầu mới)
    final Color iconColor = CategoryUtils.getVibrantColor(transaction.category);
    final Color bgColor = CategoryUtils.getLightBgColor(transaction.category, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          PageTransitions.slideRight(TransactionDetailScreen(transaction: transaction)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              // Icon Hạng mục (Đồng bộ thiết kế mới)
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(transaction.icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              
              // Tên hạng mục và Mô tả
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.description.isNotEmpty ? transaction.description : "Không có mô tả"}${showDate ? "  •  ${CurrencyUtils.formatDate(transaction.date)}" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Số tiền và Phân loại
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatAmountWithSign(transaction.amount, isIncome),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: iconColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isIncome ? "KHOẢN THU" : "KHOẢN CHI",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: iconColor.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
