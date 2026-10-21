import 'package:flutter/material.dart';
import 'mono_liquid_glass_logo.dart';

export 'mono_liquid_glass_logo.dart';

enum AppLogoVariant {
  /// Logo dạng chữ thương hiệu (wordmark) 'mono'
  wordmark,

  /// Huy hiệu biểu tượng ứng dụng chuẩn Subtle Modern Refresh 3D
  badge,
}

/// Widget hiển thị logo chuẩn thương hiệu của ứng dụng Mono Expense Tracker
/// Tích hợp trực tiếp công nghệ Subtle Modern Refresh tràn viền full-bleed
class AppLogo extends StatelessWidget {
  /// Kiểu hiển thị logo
  final AppLogoVariant variant;

  /// Chiều cao của logo (đối với wordmark) hoặc kích thước đường kính (đối với badge)
  final double size;

  /// Màu sắc áp dụng cho logo chữ (nếu null sẽ tự thích ứng theo theme)
  final Color? color;

  /// Đổ bóng cho badge
  final bool hasShadow;

  /// Hiệu ứng vầng hào quang phát sáng (glow aura)
  final bool hasGlow;

  /// Tự động phát hiệu ứng tia sáng quét mặt kính
  final bool animatedSheen;

  /// Cho phép tương tác chạm để phát sáng mặt kính
  final bool isInteractive;

  /// Bo góc cho badge (mặc định squircle bo tròn 28% nếu null)
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.wordmark,
    this.size = 28,
    this.color,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  });

  /// Factory tiện lợi hiển thị logo chữ Mono
  const AppLogo.wordmark({
    super.key,
    double height = 28,
    this.color,
    this.hasGlow = false,
  }) : variant = AppLogoVariant.wordmark,
       size = height,
       hasShadow = false,
       animatedSheen = false,
       isInteractive = false,
       borderRadius = null;

  /// Factory tiện lợi hiển thị huy hiệu App Icon
  const AppLogo.badge({
    super.key,
    this.size = 68,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  /// Factory tiện lợi cỡ nhỏ (40px)
  const AppLogo.small({
    super.key,
    this.size = 40,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  /// Factory tiện lợi cỡ vừa (72px)
  const AppLogo.medium({
    super.key,
    this.size = 72,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  /// Factory tiện lợi cỡ lớn (96px)
  const AppLogo.large({
    super.key,
    this.size = 96,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  /// Factory tiện lợi Hero cỡ đại (120px) cho Splash / Onboarding
  const AppLogo.hero({
    super.key,
    this.size = 120,
    this.hasShadow = true,
    this.hasGlow = true,
    this.animatedSheen = false,
    this.isInteractive = false,
    this.borderRadius,
  }) : variant = AppLogoVariant.badge,
       color = null;

  @override
  Widget build(BuildContext context) {
    if (variant == AppLogoVariant.wordmark) {
      return MonoLiquidGlassLogo.wordmark(
        height: size,
        color: color,
        hasGlow: hasGlow,
      );
    }

    return MonoLiquidGlassLogo.badge(
      size: size,
      hasShadow: hasShadow,
      hasGlow: hasGlow,
      animatedSheen: animatedSheen,
      isInteractive: isInteractive,
      borderRadius: borderRadius,
    );
  }
}
