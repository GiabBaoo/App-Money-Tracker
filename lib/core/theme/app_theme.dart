import 'package:flutter/material.dart';
import 'app_colors.dart';

/// AppTheme - Cấu hình Material 3 ThemeData hoàn chỉnh cho Light & Dark Theme
class AppTheme {
  AppTheme._();

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    },
  );

  // ══════════════════════════════════════════════════════════════
  // 1. LIGHT THEME (GIAO DIỆN SÁNG THANH LỊCH)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        pageTransitionsTheme: _pageTransitionsTheme,
        primaryColor: AppColors.primaryTeal,
        scaffoldBackgroundColor: AppColors.bgLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryTeal,
          onPrimary: Colors.white,
          secondary: AppColors.primaryTealVibrant,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.textPrimaryLight,
          onSurfaceVariant: AppColors.textSecondaryLight,
          outline: AppColors.borderLight,
          outlineVariant: Color(0xFFCBD5E1),
          error: AppColors.expenseCoral,
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
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceLight,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryLight,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textSecondaryLight,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBgLight,
          hintStyle: const TextStyle(
            color: AppColors.textMutedLight,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.8),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.inputBgLight,
          selectedColor: AppColors.primaryTeal.withValues(alpha: 0.15),
          side: const BorderSide(color: AppColors.borderLight, width: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryTeal,
          unselectedItemColor: AppColors.textMutedLight,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        textTheme: const TextTheme(
          labelSmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight, letterSpacing: 0.2),
          labelMedium: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
          labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          bodySmall: TextStyle(fontSize: 13.0, color: AppColors.textSecondaryLight, height: 1.35),
          bodyMedium: TextStyle(fontSize: 15.0, color: AppColors.textPrimaryLight, height: 1.4),
          bodyLarge: TextStyle(fontSize: 16.5, color: AppColors.textPrimaryLight, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          titleMedium: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
          titleLarge: TextStyle(fontSize: 20.5, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
          headlineSmall: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
          headlineMedium: TextStyle(fontSize: 26.0, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
        ),
      );

  // ══════════════════════════════════════════════════════════════
  // 2. DARK THEME (GIAO DIỆN TỐI SÂU CHUẨN MATERIAL 3 / SLATE 900)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        pageTransitionsTheme: _pageTransitionsTheme,
        primaryColor: AppColors.primaryTealDark, // Xanh rêu đậm sâu cho Header
        scaffoldBackgroundColor: AppColors.bgDark, // Chuẩn Slate 900 (#0F172A)
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryTealVibrant, // Teal ngọc lục bảo nổi bật trên nền tối
          onPrimary: AppColors.primaryTealDark,
          secondary: AppColors.primaryTealLight,
          surface: AppColors.surfaceDark, // Slate 800 (#1E293B)
          onSurface: AppColors.textPrimaryDark, // Trắng sáng (#F8FAFC) - Tương phản cực cao
          onSurfaceVariant: AppColors.textSecondaryDark, // Slate 400 (#94A3B8)
          outline: AppColors.borderDark, // Slate 700 (#334155) - Tách lớp rõ ràng
          outlineVariant: Color(0xFF475569),
          error: AppColors.expenseCoralLight,
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(color: AppColors.bgDark),
        dividerColor: AppColors.dividerDark,
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 1,
          space: 1,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardDark, // (#182234)
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.borderDark, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceDark,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.borderDark, width: 1.2),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryDark,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textSecondaryDark,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBgDark,
          hintStyle: const TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryTealVibrant, width: 1.8),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedColor: AppColors.primaryTealVibrant.withValues(alpha: 0.2),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryTealVibrant,
          unselectedItemColor: AppColors.textMutedDark,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
        ),
        textTheme: const TextTheme(
          labelSmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: AppColors.textSecondaryDark, letterSpacing: 0.2),
          labelMedium: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: AppColors.textSecondaryDark),
          labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
          bodySmall: TextStyle(fontSize: 13.0, color: AppColors.textSecondaryDark, height: 1.35),
          bodyMedium: TextStyle(fontSize: 15.0, color: AppColors.textPrimaryDark, height: 1.4),
          bodyLarge: TextStyle(fontSize: 16.5, color: AppColors.textPrimaryDark, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
          titleMedium: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
          titleLarge: TextStyle(fontSize: 20.5, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
          headlineSmall: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark),
          headlineMedium: TextStyle(fontSize: 26.0, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark),
        ),
      );
}
