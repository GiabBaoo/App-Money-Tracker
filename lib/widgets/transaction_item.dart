import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/transaction_detail_screen.dart';
import '../utils/category_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/group_expense/presentation/providers/group_expense_providers.dart';

class TransactionItem extends ConsumerWidget {
  final TransactionModel transaction;
  final bool showDate;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.showDate = false,
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
              // Icon Hạng mục (Đồng bộ thiết kế mới) - Hiển thị group icon nếu là giao dịch quỹ
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(displayIcon, color: iconColor, size: 26),
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
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
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
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isIncome ? "KHOẢN THU" : "KHOẢN CHI",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: iconColor.withValues(alpha: 0.8),
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
