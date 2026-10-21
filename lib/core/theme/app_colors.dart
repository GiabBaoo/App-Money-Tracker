import 'package:flutter/material.dart';

/// AppColors - Hệ thống mã màu và token thiết kế chuẩn Material 3 / iOS Deep Dark
class AppColors {
  AppColors._();

  // ─── THƯƠNG HIỆU (BRAND COLORS) ───
  static const Color primaryTeal = Color(0xFF438883);
  static const Color primaryTealLight = Color(0xFF68AEA9);
  static const Color primaryTealDark = Color(0xFF0F2625);
  static const Color primaryTealVibrant = Color(0xFF2DD4BF); // Neon Emerald cho Dark Mode

  // ─── MÀU NỀN TỔNG THỂ (BACKGROUNDS) ───
  // Chuẩn Slate Dark (#0F172A) & OLED Pure Dark (#0B0F19)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgDarkDeep = Color(0xFF0B1320);

  // ─── PHÂN LỚP BỀ MẶT (SURFACE ELEVATION) ───
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color surfaceElevatedDark = Color(0xFF243248); // Slate 750 (Cards, Sheets)
  static const Color surfaceHighestDark = Color(0xFF2D3D58); // Dialogs & Tooltips

  // ─── THẺ & Ô NHẬP LIỆU (CARDS & INPUTS) ───
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF182234);
  static const Color inputBgLight = Color(0xFFF1F5F9);
  static const Color inputBgDark = Color(0xFF141E2E);

  // ─── ĐƯỜNG VIỀN & PHÂN TÁCH (BORDERS & DIVIDERS) ───
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155); // Slate 700 - Rõ nét, không mờ nhạt
  static const Color borderDarkSubtle = Color(0x1FFFFFFF);
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF2A3649);

  // ─── MÀU CHỮ & ĐỘ TƯƠNG PHẢN (TYPOGRAPHY - HIGH CONTRAST) ───
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Trắng sáng Slate 50 - chuẩn WCAG AAA
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400 - Dịu mắt, sắc nét
  static const Color textMutedLight = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B); // Slate 500

  // ─── NGỮ NGHĨA TÀI CHÍNH (FINANCIAL SEMANTICS) ───
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color incomeGreenLight = Color(0xFF34D399);
  static const Color expenseCoral = Color(0xFFEF4444);
  static const Color expenseCoralLight = Color(0xFFF87171);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color infoAzure = Color(0xFF0EA5E9);

  // Helper tương thích cũ
  static Color getTealColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryTealDark
        : primaryTeal;
  }

  static Color getCardTealColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A3635)
        : const Color(0xFF2E7E78);
  }
}

/// Helper tiện ích cung cấp màu semantic thích ứng động giữa Chế độ Sáng & Tối
class AppThemeColors {
  static const Color primaryTeal = AppColors.primaryTeal;
  static const Color incomeGreen = AppColors.incomeGreen;
  static const Color expenseCoral = AppColors.expenseCoral;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Màu thương hiệu tương phản cao
  static Color brandPrimary(BuildContext context) =>
      isDark(context) ? AppColors.primaryTealVibrant : AppColors.primaryTeal;

  // Nền card chính
  static Color cardBackground(BuildContext context) =>
      isDark(context) ? AppColors.cardDark : AppColors.cardLight;

  // Nền phụ / Surface cấp 2
  static Color secondaryBackground(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : AppColors.inputBgLight;

  // Nền ô nhập liệu TextField / Dropdown
  static Color inputBackground(BuildContext context) =>
      isDark(context) ? AppColors.inputBgDark : AppColors.inputBgLight;

  // Nền Chip danh mục
  static Color chipBackground(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : const Color(0xFFF1F5F9);

  // Bề mặt nổi (BottomSheet, Dialog)
  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;

  // Chữ chính (Tiêu đề, số tiền, nội dung quan trọng)
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  // Chữ phụ (Ghi chú, nhãn ngày tháng, mô tả)
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  // Chữ mờ (Placeholder, gợi ý)
  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppColors.textMutedDark : AppColors.textMutedLight;

  // Viền ngăn cách (Border)
  static Color border(BuildContext context) =>
      isDark(context) ? AppColors.borderDark : AppColors.borderLight;

  // Viền tinh tế (Subtle Border)
  static Color borderSubtle(BuildContext context) =>
      isDark(context) ? AppColors.borderDarkSubtle : const Color(0xFFF1F5F9);

  // Đường gạch chia dòng
  static Color divider(BuildContext context) =>
      isDark(context) ? AppColors.dividerDark : AppColors.dividerLight;
}
