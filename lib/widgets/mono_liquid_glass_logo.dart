import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

enum MonoLogoVariant {
  /// Huy hiệu biểu tượng app (Khối 3D Soft Tactile Radial với chữ 'mono' đặc trưng tràn viền)
  badge,

  /// Chữ thương hiệu 'mono' thuần túy (Wordmark)
  wordmark,

  /// Biểu tượng thu nhỏ dùng cho Header / App Bar / Thẻ tóm tắt
  compact,
}

/// Widget hiển thị logo MONO chuẩn thương hiệu theo phong cách Subtle Modern Refresh:
/// - 90% Nhận diện gốc: Chữ "mono" viết thường ở chính giữa bằng font sans-serif dày dặn, cân đối
/// - 10% Chiều sâu 3D sang trọng: Khối chuyển sắc 3D Soft Radial (#6E9E94 -> #5E8C83 -> #4D776E)
/// - Hiệu ứng chữ: Nổi khối cực nhẹ với Contact Shadow & Ambient Shadow mịn phía dưới
/// - Tràn viền tuyệt đối (Full-bleed / Borderless): Không viền trắng bao quanh, phủ kín 100% diện tích
class MonoLiquidGlassLogo extends StatefulWidget {
  final MonoLogoVariant variant;
  final double size;
  final Color? color;
  final bool hasShadow;
  final bool hasGlow;
  final bool isInteractive;
  final bool animatedSheen;
  final BorderRadius? borderRadius;
  final double? externalSheen; // 0.0 -> 1.0 từ controller bên ngoài (Splash)

  const MonoLiquidGlassLogo({
    super.key,
    this.variant = MonoLogoVariant.badge,
    this.size = 72,
    this.color,
    this.hasShadow = true,
    this.hasGlow = true,
    this.isInteractive = false,
    this.animatedSheen = false,
    this.borderRadius,
    this.externalSheen,
  });

  /// Factory hiển thị Huy hiệu App Icon 3D Soft Shading tràn viền
  const MonoLiquidGlassLogo.badge({
    Key? key,
    double size = 72,
    bool isInteractive = false,
    bool animatedSheen = false,
    bool hasShadow = true,
    bool hasGlow = true,
    BorderRadius? borderRadius,
    double? externalSheen,
  }) : this(
         key: key,
         variant: MonoLogoVariant.badge,
         size: size,
         isInteractive: isInteractive,
         animatedSheen: animatedSheen,
         hasShadow: hasShadow,
         hasGlow: hasGlow,
         borderRadius: borderRadius,
         externalSheen: externalSheen,
       );

  /// Factory hiển thị Logo dạng chữ thương hiệu Wordmark
  const MonoLiquidGlassLogo.wordmark({
    Key? key,
    double height = 30,
    Color? color,
    bool hasGlow = false,
  }) : this(
         key: key,
         variant: MonoLogoVariant.wordmark,
         size: height,
         color: color,
         hasShadow: false,
         hasGlow: hasGlow,
       );

  /// Factory hiển thị Biểu tượng nhỏ gọn cho Header / App Bar
  const MonoLiquidGlassLogo.compact({
    Key? key,
    double size = 36,
    bool hasGlow = false,
    bool isInteractive = false,
  }) : this(
         key: key,
         variant: MonoLogoVariant.compact,
         size: size,
         hasShadow: true,
         hasGlow: hasGlow,
         isInteractive: isInteractive,
       );

  /// Convenience constructor: cỡ nhỏ (40px)
  const MonoLiquidGlassLogo.small({
    Key? key,
    double size = 40,
    bool isInteractive = false,
    bool animatedSheen = false,
    bool hasShadow = true,
    bool hasGlow = true,
    BorderRadius? borderRadius,
  }) : this(
         key: key,
         variant: MonoLogoVariant.badge,
         size: size,
         isInteractive: isInteractive,
         animatedSheen: animatedSheen,
         hasShadow: hasShadow,
         hasGlow: hasGlow,
         borderRadius: borderRadius,
       );

  /// Convenience constructor: cỡ vừa (72px)
  const MonoLiquidGlassLogo.medium({
    Key? key,
    double size = 72,
    bool isInteractive = false,
    bool animatedSheen = false,
    bool hasShadow = true,
    bool hasGlow = true,
    BorderRadius? borderRadius,
  }) : this(
         key: key,
         variant: MonoLogoVariant.badge,
         size: size,
         isInteractive: isInteractive,
         animatedSheen: animatedSheen,
         hasShadow: hasShadow,
         hasGlow: hasGlow,
         borderRadius: borderRadius,
       );

  /// Convenience constructor: cỡ lớn (96px)
  const MonoLiquidGlassLogo.large({
    Key? key,
    double size = 96,
    bool isInteractive = false,
    bool animatedSheen = false,
    bool hasShadow = true,
    bool hasGlow = true,
    BorderRadius? borderRadius,
  }) : this(
         key: key,
         variant: MonoLogoVariant.badge,
         size: size,
         isInteractive: isInteractive,
         animatedSheen: animatedSheen,
         hasShadow: hasShadow,
         hasGlow: hasGlow,
         borderRadius: borderRadius,
       );

  /// Convenience constructor: Hero cỡ đại (120px) cho Splash / Onboarding
  const MonoLiquidGlassLogo.hero({
    Key? key,
    double size = 120,
    bool isInteractive = false,
    bool animatedSheen = false,
    bool hasShadow = true,
    bool hasGlow = true,
    BorderRadius? borderRadius,
    double? externalSheen,
  }) : this(
         key: key,
         variant: MonoLogoVariant.badge,
         size: size,
         isInteractive: isInteractive,
         animatedSheen: animatedSheen,
         hasShadow: hasShadow,
         hasGlow: hasGlow,
         borderRadius: borderRadius,
         externalSheen: externalSheen,
       );

  @override
  State<MonoLiquidGlassLogo> createState() => _MonoLiquidGlassLogoState();
}

class _MonoLiquidGlassLogoState extends State<MonoLiquidGlassLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _sheenController;
  Animation<double>? _sheenAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animatedSheen || widget.isInteractive) {
      _sheenController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      );
      _sheenAnimation = CurvedAnimation(
        parent: _sheenController!,
        curve: Curves.easeInOutCubic,
      );

      if (widget.animatedSheen) {
        _sheenController!.repeat(reverse: false, period: const Duration(seconds: 4));
      }
    }
  }

  @override
  void didUpdateWidget(covariant MonoLiquidGlassLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animatedSheen != oldWidget.animatedSheen) {
      if (widget.animatedSheen) {
        _sheenController?.repeat(reverse: false, period: const Duration(seconds: 4));
      } else {
        _sheenController?.stop();
      }
    }
  }

  @override
  void dispose() {
    _sheenController?.dispose();
    super.dispose();
  }

  void _triggerSheen() {
    if (_sheenController != null && !_sheenController!.isAnimating) {
      HapticFeedback.lightImpact();
      _sheenController!.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == MonoLogoVariant.wordmark) {
      return _buildWordmark(context);
    }

    final double s = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.borderRadius ?? BorderRadius.circular(s * 0.28);

    Widget badgeContent = RepaintBoundary(
      child: GestureDetector(
        onTap: widget.isInteractive ? _triggerSheen : null,
        child: AnimatedBuilder(
          animation: _sheenController ?? const AlwaysStoppedAnimation(0.0),
          builder: (context, child) {
            final double currentSheen = widget.externalSheen ??
                (_sheenAnimation != null ? _sheenAnimation!.value : 0.0);

            return Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                borderRadius: r,
                boxShadow: widget.hasShadow
                    ? [
                        // 1. Ambient Glow (Aura xanh Sage thương hiệu MONO)
                        if (widget.hasGlow)
                          BoxShadow(
                            color: AppColors.logoAura.withValues(
                              alpha: isDark ? 0.40 : 0.24,
                            ),
                            blurRadius: s * 0.35,
                            spreadRadius: s * 0.015,
                            offset: Offset(0, s * 0.08),
                          ),
                        // 2. Soft Drop Shadow (Đổ bóng mềm lập thể)
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.42 : 0.16,
                          ),
                          blurRadius: s * 0.22,
                          offset: Offset(0, s * 0.09),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Lớp 1: Khối nền 3D Soft Shading (Hệ chuyển sắc #6E9E94 -> #5E8C83 -> #4D776E)
                    // Tràn viền 100%, không viền trắng, không khe hở
                    Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(-0.15, -0.22),
                          radius: 0.96,
                          colors: [
                            AppColors.logoRadialCenter, // Tâm sáng dịu (soft luminous sage)
                            AppColors.logoRadialBase,   // Màu xanh sage đặc trưng thương hiệu gốc
                            AppColors.logoRadialMid,    // Chuyển sắc mượt mà
                            AppColors.logoRadialShade,  // Rìa đổ bóng chiều sâu 3D
                            AppColors.logoRadialDark,   // Góc sâu
                          ],
                          stops: [0.0, 0.40, 0.65, 0.88, 1.0],
                        ),
                      ),
                    ),

                    // Lớp 2: Khúc xạ vòm cầu 3D đỉnh khối (Top diffuse specular illumination)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: s * 0.44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: isDark ? 0.20 : 0.28),
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Lớp 3: Luồng sáng quét mặt kính 3D (Active Sheen Sweep)
                    if (currentSheen > 0.01 && currentSheen < 0.99)
                      CustomPaint(
                        size: Size(s, s),
                        painter: _SheenPainter(
                          progress: currentSheen,
                          sheenColor: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),

                    // Lớp 4: Chữ "mono" viết thường ở chính giữa với hiệu ứng nổi khối nhẹ
                    // Tỉ lệ chiều rộng ~60% size, căn giữa tuyệt đối
                    Center(
                      child: Container(
                        width: s * 0.60,
                        height: s * 0.60 * (57.0 / 255.0),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.logoTextShadow.withValues(alpha: 0.35),
                              blurRadius: math.max(2.0, s * 0.035),
                              offset: Offset(0, math.max(1.0, s * 0.016)),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          color: Colors.white,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    return badgeContent;
  }

  Widget _buildWordmark(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = widget.color ?? (isDark ? Colors.white : AppColors.primaryTealDark);

    return RepaintBoundary(
      child: Image.asset(
        'assets/images/logo.png',
        height: widget.size,
        fit: BoxFit.contain,
        color: defaultColor,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Vẽ tia sáng chéo quét qua mặt kính
class _SheenPainter extends CustomPainter {
  final double progress;
  final Color sheenColor;

  _SheenPainter({
    required this.progress,
    required this.sheenColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double totalWidth = size.width + size.height * 1.5;
    final double currentX = -size.height * 0.75 + totalWidth * progress;
    final double barWidth = size.width * 0.38;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          sheenColor.withValues(alpha: 0.15),
          sheenColor,
          sheenColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(currentX - barWidth, 0, barWidth * 2, size.height));

    final path = Path()
      ..moveTo(currentX - barWidth, 0)
      ..lineTo(currentX + barWidth, 0)
      ..lineTo(currentX + barWidth - size.height * 0.75, size.height)
      ..lineTo(currentX - barWidth - size.height * 0.75, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.sheenColor != sheenColor;
  }
}
