import 'package:flutter/material.dart';

enum AppLogoVariant {
  /// Logo dạng chữ thương hiệu (wordmark) 'mono'
  wordmark,

  /// Huy hiệu biểu tượng ứng dụng (bo tròn hoặc squircle) chứa logo 'mono' ở giữa tương tự app launcher icon
  badge,
}

/// Widget hiển thị logo chuẩn thương hiệu của ứng dụng Mono Expense Tracker
class AppLogo extends StatelessWidget {
  /// Kiểu hiển thị logo
  final AppLogoVariant variant;

  /// Chiều cao của logo (đối với wordmark) hoặc kích thước đường kính (đối với badge)
  final double size;

  /// Màu sắc áp dụng cho logo chữ (nếu null sẽ giữ màu gốc trắng hoặc tự thích ứng theo theme)
  final Color? color;

  /// Đổ bóng cho badge
  final bool hasShadow;

  /// Bo góc cho badge (mặc định hình tròn nếu null)
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.wordmark,
    this.size = 28,
    this.color,
    this.hasShadow = true,
    this.borderRadius,
  });

  /// Factory tiện lợi hiển thị logo chữ Mono
  const AppLogo.wordmark({
    super.key,
    double height = 28,
    this.color,
  }) : variant = AppLogoVariant.wordmark,
       size = height,
       hasShadow = false,
       borderRadius = null;

  /// Factory tiện lợi hiển thị huy hiệu App Icon
  const AppLogo.badge({
    super.key,
    this.size = 68,
    this.hasShadow = true,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  @override
  Widget build(BuildContext context) {
    if (variant == AppLogoVariant.wordmark) {
      return Image.asset(
        'assets/images/logo.png',
        height: size,
        fit: BoxFit.contain,
        color: color,
        filterQuality: FilterQuality.high,
      );
    }

    // Biến thể Badge (Huy hiệu biểu tượng app launcher)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF438883), Color(0xFF2DD4BF)]
              : const [Color(0xFF5E9387), Color(0xFF3B7267)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF438883).withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: size * 0.16),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: size * 0.68,
          fit: BoxFit.contain,
          color: Colors.white,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
