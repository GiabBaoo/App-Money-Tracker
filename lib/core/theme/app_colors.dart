import 'package:flutter/material.dart';

/// AppColors - Hệ thống mã màu và token thiết kế chuẩn Fintech Modern UI (Material 3 & iOS Deep Dark)
class AppColors {
  AppColors._();

  // ══════════════════════════════════════════════════════════════
  // 1. MÀU THƯƠNG HIỆU MONO (BRAND COLORS)
  // ══════════════════════════════════════════════════════════════
  static const Color primaryTeal = Color(
    0xFF438883,
  ); // Xanh Teal ngọc trầm - Brand gốc
  static const Color primaryTealLight = Color(0xFF68AEA9);
  static const Color primaryTealDark = Color(0xFF0F2625); // Xanh rêu đậm sâu
  static const Color primaryTealVibrant = Color(
    0xFF2DD4BF,
  ); // Neon Emerald ngọc lục bảo cho Dark Mode
  static const Color brandJade = Color(0xFF0D9488); // Teal Jade hiện đại

  // Logo Brand Tokens (Subtle Modern Refresh)
  static const Color logoAura = Color(0xFF5E8C83);
  static const Color logoRadialCenter = Color(0xFF6E9E94); // Tâm sáng dịu
  static const Color logoRadialBase = Color(0xFF5E8C83); // Xanh sage đặc trưng
  static const Color logoRadialMid = Color(0xFF55857C); // Chuyển sắc mượt mà
  static const Color logoRadialShade = Color(
    0xFF4D776E,
  ); // Đổ bóng chiều sâu 3D
  static const Color logoRadialDark = Color(0xFF3F675F); // Góc sâu
  static const Color logoTextShadow = Color(0xFF0F2D27); // Đổ bóng chữ

  // Gradient thương hiệu cho Thẻ ví / Header
  static const LinearGradient brandGradientLight = LinearGradient(
    colors: [Color(0xFF438883), Color(0xFF2E6B66)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientDark = LinearGradient(
    colors: [Color(0xFF1E3A37), Color(0xFF0F2625)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ══════════════════════════════════════════════════════════════
  // 2. NGỮ NGHĨA TÀI CHÍNH (FINANCIAL SEMANTICS - CAO CẤP & TƯƠNG PHẢN CAO)
  // ══════════════════════════════════════════════════════════════

  // ── THU NHẬP (INCOME - XANH NGỌC / EMERALD) ──
  static const Color incomeEmerald = Color(0xFF10B981); // Emerald 500
  static const Color incomeEmeraldDark = Color(
    0xFF059669,
  ); // Emerald 600 - tương phản cao cho Light Mode
  static const Color incomeEmeraldLight = Color(
    0xFF34D399,
  ); // Emerald 400 - phát sáng rõ cho Dark Mode
  static const Color incomeGreen = incomeEmerald; // Tương thích ngược
  static const Color incomeGreenLight = incomeEmeraldLight; // Tương thích ngược
  static const Color incomeBgLight = Color(0xFFECFDF5); // Emerald 50
  static const Color incomeBgDark = Color(0xFF064E3B); // Emerald 900
  static const Color incomeBorderLight = Color(0xFFA7F3D0);
  static const Color incomeBorderDark = Color(0xFF047857);

  // ── CHI TIÊU (EXPENSE - ĐỎ SAN HÔ / ROSE) ──
  static const Color expenseRose = Color(0xFFF43F5E); // Rose 500
  static const Color expenseRoseDark = Color(
    0xFFE11D48,
  ); // Rose 600 - tương phản cao cho Light Mode
  static const Color expenseRoseLight = Color(
    0xFFFB7185,
  ); // Rose 400 - phát sáng rõ cho Dark Mode
  static const Color expenseCoral = Color(
    0xFFEF4444,
  ); // Coral Red - alias tương thích ngược
  static const Color expenseCoralLight = Color(0xFFF87171); // Tương thích ngược
  static const Color expenseBgLight = Color(0xFFFFF1F2); // Rose 50
  static const Color expenseBgDark = Color(0xFF881337); // Rose 900
  static const Color expenseBorderLight = Color(0xFFFECDD3);
  static const Color expenseBorderDark = Color(0xFFBE123C);

  // ── CHUYỂN KHOẢN (TRANSFER - XANH DƯƠNG / INDIGO) ──
  static const Color transferIndigo = Color(0xFF6366F1); // Indigo 500
  static const Color transferIndigoDark = Color(
    0xFF4F46E5,
  ); // Indigo 600 - tương phản cao cho Light Mode
  static const Color transferIndigoLight = Color(
    0xFF818CF8,
  ); // Indigo 400 - phát sáng rõ cho Dark Mode
  static const Color transferBlue = Color(0xFF0284C7); // Sky/Blue alias
  static const Color transferBgLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color transferBgDark = Color(0xFF312E81); // Indigo 900
  static const Color transferBorderLight = Color(0xFFC7D2FE);
  static const Color transferBorderDark = Color(0xFF4338CA);

  // ── CẢNH BÁO (WARNING / AMBER) ──
  static const Color warningAmber = Color(0xFFF59E0B); // Amber 500
  static const Color warningAmberLight = Color(0xFFFBBF24); // Amber 400
  static const Color warningBgLight = Color(0xFFFFFBEB);
  static const Color warningBgDark = Color(0xFF78350F);

  // ── THÔNG TIN (INFO / AZURE) ──
  static const Color infoAzure = Color(0xFF0EA5E9); // Azure 500
  static const Color infoAzureLight = Color(0xFF38BDF8); // Azure 400
  static const Color infoBgLight = Color(0xFFF0F9FF);
  static const Color infoBgDark = Color(0xFF0C4A6E);

  // ══════════════════════════════════════════════════════════════
  // 3. MÀU NỀN TỔNG THỂ & PHÂN LỚP BỀ MẶT (FINTECH SLATE / OLED)
  // ══════════════════════════════════════════════════════════════
  // Nền ứng dụng (Scaffold Background)
  static const Color bgLight = Color(0xFFF8FAFC); // Slate 50
  static const Color bgDark = Color(
    0xFF0B1320,
  ); // OLED Slate Deep Dark (Sâu thẳm, tiết kiệm pin OLED)
  static const Color bgDarkDeep = Color(0xFF0B1320); // Tương thích ngược

  // Bề mặt phân tầng (Surface Elevation)
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(
    0xFF182234,
  ); // Slate 850 (Bề mặt thẻ/nền chính)
  static const Color surfaceElevatedDark = Color(
    0xFF1E293B,
  ); // Slate 800 (Cards, Sheets, Bars)
  static const Color surfaceHighestDark = Color(
    0xFF243248,
  ); // Slate 750 (Dialogs, Tooltips, Menus)

  // Thẻ & Ô nhập liệu (Cards & Inputs)
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF182234);
  static const Color inputBgLight = Color(0xFFF1F5F9); // Slate 100
  static const Color inputBgDark = Color(0xFF141E2E); // Deep Slate Input

  // ══════════════════════════════════════════════════════════════
  // 4. ĐƯỜNG VIỀN & PHÂN TÁCH (BORDERS & DIVIDERS)
  // ══════════════════════════════════════════════════════════════
  static const Color borderLight = Color(
    0xFFE2E8F0,
  ); // Slate 200 - Nhẹ nhàng, sắc nét
  static const Color borderLightSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color borderDark = Color(
    0xFF334155,
  ); // Slate 700 - Chuẩn tương phản cạnh, không mờ nhạt
  static const Color borderDarkSubtle = Color(0xFF1E293B); // Slate 800
  static const Color borderDarkHighlight = Color(
    0x29FFFFFF,
  ); // Specular Highlight viền kính
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF263345);

  // ══════════════════════════════════════════════════════════════
  // 5. MÀU CHỮ & ĐỘ TƯƠNG PHẢN (HIGH CONTRAST TYPOGRAPHY - WCAG AAA)
  // ══════════════════════════════════════════════════════════════
  static const Color textPrimaryLight = Color(
    0xFF0F172A,
  ); // Slate 900 - Đen chữ chuẩn
  static const Color textPrimaryDark = Color(
    0xFFF8FAFC,
  ); // Slate 50 - Trắng sáng rực rỡ
  static const Color textSecondaryLight = Color(
    0xFF475569,
  ); // Slate 600 - Rõ ràng
  static const Color textSecondaryDark = Color(
    0xFF94A3B8,
  ); // Slate 400 - Dịu mắt, sắc nét
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedDark = Color(0xFF64748B); // Slate 500

  // ══════════════════════════════════════════════════════════════
  // 6. HELPER TƯƠNG THÍCH CŨ
  // ══════════════════════════════════════════════════════════════
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

/// AppThemeColors - Tiện ích truy xuất nhanh màu sắc thích ứng động theo Light/Dark Mode
class AppThemeColors {
  AppThemeColors._();

  static const Color primaryTeal = AppColors.primaryTeal;
  static const Color incomeGreen = AppColors.incomeGreen;
  static const Color expenseCoral = AppColors.expenseCoral;
  static const Color transferIndigo = AppColors.transferIndigo;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── MÀU THƯƠNG HIỆU ──
  static Color brandPrimary(BuildContext context) =>
      isDark(context) ? AppColors.primaryTealVibrant : AppColors.primaryTeal;

  static Color brandJade(BuildContext context) =>
      isDark(context) ? AppColors.primaryTealVibrant : AppColors.brandJade;

  // ── NGỮ NGHĨA TÀI CHÍNH THÍCH ỨNG (DYNAMIC FINANCIAL COLORS) ──
  static Color income(BuildContext context) => isDark(context)
      ? AppColors.incomeEmeraldLight
      : AppColors.incomeEmeraldDark;

  static Color incomeBg(BuildContext context) => isDark(context)
      ? AppColors.incomeEmeraldDark.withValues(alpha: 0.22)
      : AppColors.incomeBgLight;

  static Color expense(BuildContext context) =>
      isDark(context) ? AppColors.expenseRoseLight : AppColors.expenseRoseDark;

  static Color expenseBg(BuildContext context) => isDark(context)
      ? AppColors.expenseRoseDark.withValues(alpha: 0.22)
      : AppColors.expenseBgLight;

  static Color transfer(BuildContext context) => isDark(context)
      ? AppColors.transferIndigoLight
      : AppColors.transferIndigoDark;

  static Color transferBg(BuildContext context) => isDark(context)
      ? AppColors.transferIndigoDark.withValues(alpha: 0.22)
      : AppColors.transferBgLight;

  static Color warning(BuildContext context) =>
      isDark(context) ? AppColors.warningAmberLight : AppColors.warningAmber;

  static Color warningBg(BuildContext context) => isDark(context)
      ? AppColors.warningAmber.withValues(alpha: 0.22)
      : AppColors.warningBgLight;

  static Color info(BuildContext context) =>
      isDark(context) ? AppColors.infoAzureLight : AppColors.infoAzure;

  // ── PHÂN LỚP BỀ MẶT & CARD ──
  static Color background(BuildContext context) =>
      isDark(context) ? AppColors.bgDark : AppColors.bgLight;

  static Color cardBackground(BuildContext context) =>
      isDark(context) ? AppColors.cardDark : AppColors.cardLight;

  static Color secondaryBackground(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : AppColors.inputBgLight;

  static Color inputBackground(BuildContext context) =>
      isDark(context) ? AppColors.inputBgDark : AppColors.inputBgLight;

  static Color chipBackground(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : const Color(0xFFF1F5F9);

  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;

  static Color surfaceHighest(BuildContext context) =>
      isDark(context) ? AppColors.surfaceHighestDark : AppColors.surfaceLight;

  // ── TYPOGRAPHY ──
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

  static Color textSecondary(BuildContext context) => isDark(context)
      ? AppColors.textSecondaryDark
      : AppColors.textSecondaryLight;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppColors.textMutedDark : AppColors.textMutedLight;

  // ── ĐƯỜNG VIỀN & PHÂN TÁCH ──
  static Color border(BuildContext context) =>
      isDark(context) ? AppColors.borderDark : AppColors.borderLight;

  static Color borderSubtle(BuildContext context) => isDark(context)
      ? AppColors.borderDarkSubtle
      : AppColors.borderLightSubtle;

  static Color divider(BuildContext context) =>
      isDark(context) ? AppColors.dividerDark : AppColors.dividerLight;
}
