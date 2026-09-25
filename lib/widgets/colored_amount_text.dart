import 'package:flutter/material.dart';
import '../utils/currency_format_utils.dart';

/// Widget hiển thị số tiền có màu sắc chuẩn hóa:
/// - Thu nhập: Xanh lá (#10B981) kèm tiền tố '+'
/// - Chi tiêu: Đỏ (#EF4444) kèm tiền tố '-'
class ColoredAmountText extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool showSign;

  const ColoredAmountText({
    super.key,
    required this.amount,
    required this.isIncome,
    this.fontSize = 17,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = -0.5,
    this.showSign = true,
  });

  /// Màu chuẩn hóa toàn app
  static const Color expenseColor = Color(0xFFEF4444); // Đỏ chi tiêu chuẩn Tailwind 500
  static const Color incomeColor = Color(0xFF10B981);  // Xanh ngọc thu nhập chuẩn Tailwind 500

  static Color getColor(bool isIncome) => isIncome ? incomeColor : expenseColor;

  /// Tạo badge nhãn 'KHOẢN THU' hoặc 'KHOẢN CHI' với màu sắc đồng bộ
  static Widget buildTypeBadge(bool isIncome, {double fontSize = 10}) {
    final color = getColor(isIncome);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isIncome ? 'KHOẢN THU' : 'KHOẢN CHI',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: 0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(isIncome);
    final text = showSign
        ? CurrencyUtils.formatAmountWithSign(amount, isIncome)
        : CurrencyUtils.formatCurrency(amount);

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
