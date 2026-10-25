import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_radius.dart';
export 'app_text_styles.dart';
export 'wallet_palette.dart';

/// AppTheme - Cấu hình Material 3 ThemeData hoàn chỉnh chuẩn Fintech Modern UI cho Light & Dark Theme
class AppTheme {
  AppTheme._();

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      );

  // ══════════════════════════════════════════════════════════════
  // 1. LIGHT THEME (GIAO DIỆN SÁNG THANH LỊCH, SANG TRỌNG)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    splashFactory: InkRipple.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: AppColors.primaryTeal.withValues(alpha: 0.08),
    pageTransitionsTheme: _pageTransitionsTheme,
    primaryColor: AppColors.primaryTeal,
    scaffoldBackgroundColor: AppColors.bgLight,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryTeal,
      onPrimary: Colors.white,
      secondary: AppColors.primaryTealVibrant,
      onSecondary: AppColors.primaryTealDark,
      tertiary: AppColors.transferIndigoDark,
      onTertiary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      onSurfaceVariant: AppColors.textSecondaryLight,
      outline: AppColors.borderLight,
      outlineVariant: AppColors.borderLightSubtle,
      error: AppColors.expenseRoseDark,
      onError: Colors.white,
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
    dividerColor: AppColors.dividerLight,
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: AppTextStyles.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        side: const BorderSide(color: AppColors.borderLight, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: AppTextStyles.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        textStyle: AppTextStyles.button,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.dialog,
        side: const BorderSide(color: AppColors.borderLight, width: 1.0),
      ),
      titleTextStyle: AppTextStyles.titleLarge.copyWith(
        color: AppColors.textPrimaryLight,
      ),
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceLight,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      dragHandleColor: Color(0xFFCBD5E1),
      dragHandleSize: Size(38, 4.5),
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBgLight,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textMutedLight,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(
          color: AppColors.expenseRoseDark,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(
          color: AppColors.expenseRoseDark,
          width: 1.8,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.inputBgLight,
      selectedColor: AppColors.primaryTeal.withValues(alpha: 0.15),
      side: const BorderSide(color: AppColors.borderLight, width: 0.8),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
      labelStyle: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textPrimaryLight,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primaryTeal,
      unselectedItemColor: AppColors.textMutedLight,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: AppTextStyles.createTextTheme(
      AppColors.textPrimaryLight,
      AppColors.textSecondaryLight,
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // 2. DARK THEME (GIAO DIỆN TỐI SÂU CHUẨN OLED DEEP DARK & FINTECH)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    splashFactory: InkRipple.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: AppColors.primaryTealVibrant.withValues(alpha: 0.08),
    pageTransitionsTheme: _pageTransitionsTheme,
    primaryColor: AppColors.primaryTealDark,
    scaffoldBackgroundColor: AppColors.bgDark, // Deep Slate OLED (#0B1320)
    colorScheme: const ColorScheme.dark(
      primary:
          AppColors.primaryTealVibrant, // Neon Emerald ngọc lục bảo nổi bật
      onPrimary: AppColors.primaryTealDark,
      secondary: AppColors.primaryTealLight,
      onSecondary: AppColors.primaryTealDark,
      tertiary: AppColors.transferIndigoLight,
      onTertiary: Color(0xFF0B1320),
      surface: AppColors.surfaceDark, // (#182234)
      onSurface: AppColors.textPrimaryDark, // Trắng sáng Slate 50
      onSurfaceVariant: AppColors.textSecondaryDark, // Slate 400
      outline: AppColors.borderDark, // Slate 700 (#334155) - Tách lớp rõ ràng
      outlineVariant: AppColors.borderDarkSubtle,
      error: AppColors.expenseRoseLight,
      onError: Color(0xFF0B1320),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: AppColors.bgDark),
    dividerColor: AppColors.dividerDark,
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primaryTealVibrant,
        foregroundColor: AppColors.primaryTealDark,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: AppTextStyles.button.copyWith(
          color: AppColors.primaryTealDark,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
        side: const BorderSide(color: AppColors.borderDark, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: AppTextStyles.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        textStyle: AppTextStyles.button,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevatedDark,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.dialog,
        side: const BorderSide(color: AppColors.borderDark, width: 1.2),
      ),
      titleTextStyle: AppTextStyles.titleLarge.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceElevatedDark,
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      dragHandleColor: Colors.white24,
      dragHandleSize: Size(38, 4.5),
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBgDark,
      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textMutedDark,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(
          color: AppColors.primaryTealVibrant,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(
          color: AppColors.expenseRoseLight,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(
          color: AppColors.expenseRoseLight,
          width: 1.8,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceElevatedDark,
      selectedColor: AppColors.primaryTealVibrant.withValues(alpha: 0.2),
      side: const BorderSide(color: AppColors.borderDark, width: 1),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
      labelStyle: AppTextStyles.labelLarge.copyWith(
        color: AppColors.textPrimaryDark,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryTealVibrant,
      unselectedItemColor: AppColors.textMutedDark,
      elevation: 10,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: AppTextStyles.createTextTheme(
      AppColors.textPrimaryDark,
      AppColors.textSecondaryDark,
    ),
  );
}

/// Extension tiện ích hỗ trợ truy xuất nhanh Theme & Design Tokens trực tiếp từ BuildContext
extension BuildContextThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── SEMANTIC FINANCIAL COLORS ──
  Color get income => AppThemeColors.income(this);
  Color get incomeBg => AppThemeColors.incomeBg(this);
  Color get incomeColor => AppThemeColors.income(this);
  Color get incomeBgColor => AppThemeColors.incomeBg(this);

  Color get expense => AppThemeColors.expense(this);
  Color get expenseBg => AppThemeColors.expenseBg(this);
  Color get expenseColor => AppThemeColors.expense(this);
  Color get expenseBgColor => AppThemeColors.expenseBg(this);

  Color get warning => AppThemeColors.warning(this);
  Color get warningBg => AppThemeColors.warningBg(this);
  Color get warningColor => AppThemeColors.warning(this);
  Color get warningBgColor => AppThemeColors.warningBg(this);

  Color get info => AppThemeColors.info(this);
  Color get infoBg => isDarkMode ? AppColors.infoBgDark : AppColors.infoBgLight;
  Color get infoColor => AppThemeColors.info(this);

  Color get transfer => AppThemeColors.transfer(this);
  Color get transferBg => AppThemeColors.transferBg(this);
  Color get transferColor => AppThemeColors.transfer(this);
  Color get transferBgColor => AppThemeColors.transferBg(this);

  // ── BRAND & SURFACE TOKENS ──
  Color get brandColor => AppThemeColors.brandPrimary(this);
  Color get cardBg => AppThemeColors.cardBackground(this);
  Color get cardBgColor => AppThemeColors.cardBackground(this);
  Color get inputBgColor => AppThemeColors.inputBackground(this);
  Color get surfaceElevatedColor => AppThemeColors.surfaceElevated(this);
  Color get textPrimaryColor => AppThemeColors.textPrimary(this);
  Color get textSecondaryColor => AppThemeColors.textSecondary(this);
  Color get textMutedColor => AppThemeColors.textMuted(this);
  Color get borderColor => AppThemeColors.border(this);
  Color get dividerColor => AppThemeColors.divider(this);
}
