import 'package:flutter/material.dart';

/// AppRadius - Hệ thống bo góc thống nhất toàn app theo chuẩn Fintech Modern UI
class AppRadius {
  AppRadius._();

  // ─── GIÁ TRỊ SỐ (NUMERIC VALUES) ───
  static const double badgeRadius = 6.0;
  static const double chipRadius = 8.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;
  static const double iconContainerRadius = 14.0;
  static const double cardRadius = 18.0;
  static const double cardLargeRadius = 20.0;
  static const double dialogRadius = 24.0;
  static const double bottomSheetRadius = 24.0;
  static const double pillRadius = 999.0;

  // ─── BORDERRADIUS OBJECTS ───
  static const BorderRadius badge = BorderRadius.all(
    Radius.circular(badgeRadius),
  );
  static const BorderRadius chip = BorderRadius.all(
    Radius.circular(chipRadius),
  );
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonRadius),
  );
  static const BorderRadius input = BorderRadius.all(
    Radius.circular(inputRadius),
  );
  static const BorderRadius iconContainer = BorderRadius.all(
    Radius.circular(iconContainerRadius),
  );
  static const BorderRadius card = BorderRadius.all(
    Radius.circular(cardRadius),
  );
  static const BorderRadius cardLarge = BorderRadius.all(
    Radius.circular(cardLargeRadius),
  );
  static const BorderRadius dialog = BorderRadius.all(
    Radius.circular(dialogRadius),
  );
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(bottomSheetRadius),
  );
  static const BorderRadius pill = BorderRadius.all(
    Radius.circular(pillRadius),
  );
}

/// AppShadows - Đổ bóng đa lớp mềm mại (Soft Shadows) phong cách Fintech cao cấp
class AppShadows {
  AppShadows._();

  // ─── ĐỔ BÓNG CARD ───
  static List<BoxShadow> card(bool isDark) {
    if (isDark) {
      return const [
        BoxShadow(
          color: Color(0x38000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x050F172A), blurRadius: 2, offset: Offset(0, 1)),
    ];
  }

  // ─── ĐỔ BÓNG NỔI (FLOATING BUTTONS, TOASTS, CAPSULES) ───
  static List<BoxShadow> floating(bool isDark) {
    if (isDark) {
      return const [
        BoxShadow(
          color: Color(0x52000000),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 2)),
    ];
  }

  // ─── ĐỔ BÓNG DIALOG & MODAL ───
  static List<BoxShadow> modal(bool isDark) {
    if (isDark) {
      return const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 32,
          offset: Offset(0, 10),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x1F0F172A),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
    ];
  }

  // ─── VẦNG SÁNG NHẸ (AMBIENT GLOW) ───
  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.25,
    double blur = 14,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: alpha),
        blurRadius: blur,
        offset: const Offset(0, 3),
      ),
    ];
  }
}

/// AppDecorations - Tiện ích tạo hiệu ứng Frosted Glass và viền kính mỏng nhẹ
class AppDecorations {
  AppDecorations._();

  /// Container kính mờ (Subtle Glassmorphism)
  static BoxDecoration glassmorphic({
    required bool isDark,
    BorderRadius? borderRadius,
    Color? customBg,
    Color? customBorder,
  }) {
    final bg =
        customBg ??
        (isDark
            ? const Color(0xFF182234).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.90));
    final border =
        customBorder ??
        (isDark
            ? const Color(0xFF334155).withValues(alpha: 0.6)
            : const Color(0xFFE2E8F0));

    return BoxDecoration(
      color: bg,
      borderRadius: borderRadius ?? AppRadius.card,
      border: Border.all(color: border, width: 1.0),
      boxShadow: AppShadows.card(isDark),
    );
  }
}
