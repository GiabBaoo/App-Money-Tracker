import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';
import '../services/language_service.dart';
import '../utils/currency_format_utils.dart';

/// Widget hiển thị số tiền có màu sắc chuẩn hóa theo Hệ thống Fintech Modern UI:
/// - Thu nhập (Income): Xanh ngọc Emerald (#10B981 / #34D399) kèm tiền tố '+'
/// - Chi tiêu (Expense): Đỏ san hô Rose (#F43F5E / #FB7185) kèm tiền tố '-'
/// - Chuyển khoản (Transfer): Xanh dương Indigo (#6366F1 / #818CF8)
class ColoredAmountText extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final bool isTransfer;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool showSign;
  final Color? colorOverride;

  const ColoredAmountText({
    super.key,
    required this.amount,
    required this.isIncome,
    this.isTransfer = false,
    this.fontSize = 17,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = -0.5,
    this.showSign = true,
    this.colorOverride,
  });

  /// Màu chuẩn hóa toàn app (Tương thích ngược)
  static const Color expenseColor = AppColors.expenseRose; // Đỏ san hô Rose
  static const Color incomeColor = AppColors.incomeEmerald; // Xanh ngọc Emerald
  static const Color transferColor =
      AppColors.transferIndigo; // Xanh dương Indigo

  static Color getColor(
    bool isIncome, {
    bool isTransfer = false,
    bool isDark = false,
  }) {
    if (isTransfer) {
      return isDark
          ? AppColors.transferIndigoLight
          : AppColors.transferIndigoDark;
    }
    if (isIncome) {
      return isDark
          ? AppColors.incomeEmeraldLight
          : AppColors.incomeEmeraldDark;
    }
    return isDark ? AppColors.expenseRoseLight : AppColors.expenseRoseDark;
  }

  /// Tạo badge nhãn 'KHOẢN THU', 'KHOẢN CHI' hoặc 'CHUYỂN KHOẢN' chuẩn Fintech
  static Widget buildTypeBadge(
    bool isIncome, {
    bool isTransfer = false,
    double fontSize = 10,
    bool? isDarkOverride,
    BuildContext? context,
  }) {
    final bool isDark =
        isDarkOverride ??
        (context != null
            ? Theme.of(context).brightness == Brightness.dark
            : false);
    final color = getColor(isIncome, isTransfer: isTransfer, isDark: isDark);
    final isVi = LanguageService.instance.isVietnamese;

    String label;
    if (isTransfer) {
      label = isVi ? 'CHUYỂN KHOẢN' : 'TRANSFER';
    } else if (isIncome) {
      label = isVi ? 'KHOẢN THU' : 'INCOME';
    } else {
      label = isVi ? 'KHOẢN CHI' : 'EXPENSE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: AppRadius.badge,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.40 : 0.22),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge.copyWith(fontSize: fontSize, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        colorOverride ??
        getColor(isIncome, isTransfer: isTransfer, isDark: isDark);

    String text;
    if (isTransfer) {
      text = CurrencyUtils.formatCurrency(amount);
    } else if (showSign) {
      text = CurrencyUtils.formatAmountWithSign(amount, isIncome);
    } else {
      text = CurrencyUtils.formatCurrency(amount);
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
