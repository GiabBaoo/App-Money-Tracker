import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/page_transitions.dart';
import '../../services/biometric_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/animated_scale_button.dart';
import 'login_screen.dart';

class FingerprintUnlockScreen extends StatefulWidget {
  final Widget? destination;
  final VoidCallback? onUnlock;

  const FingerprintUnlockScreen({
    super.key,
    this.destination,
    this.onUnlock,
  });

  @override
  State<FingerprintUnlockScreen> createState() =>
      _FingerprintUnlockScreenState();
}

class _FingerprintUnlockScreenState extends State<FingerprintUnlockScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  bool _isAuthenticating = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutQuad,
    );

    _authenticate();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _isAuthenticating = true;
    });

    final supported = await BiometricService.instance.canCheckBiometrics();
    if (!mounted) return;

    if (!supported) {
      // Nếu thiết bị không hỗ trợ, bỏ qua bước vân tay để không "kẹt" app.
      _goNext();
      return;
    }

    final ok = await BiometricService.instance.authenticateFingerprint(
      localizedReason: 'Xác thực vân tay để mở khóa ứng dụng Mono',
    );
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      final effectiveUid = AuthService().currentUid;
      if (effectiveUid != null) {
        // Ghi lại thời điểm đăng nhập chạy nền (không await để vào app tức thì < 50ms)
        unawaited(BiometricService.instance.recordFingerprintLogin(uid: effectiveUid).catchError((_) {}));
        // Tự động re-authenticate ngầm nếu có kết nối mạng
        unawaited(AuthService().silentReauthenticateIfNeeded().catchError((_) => false));
      }
      _goNext();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isAuthenticating = false;
        _error = 'Không thể nhận diện vân tay. Vui lòng thử lại hoặc đăng nhập bằng mật khẩu.';
      });
    }
  }

  void _goNext() {
    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (widget.onUnlock != null) {
      widget.onUnlock!();
      return;
    }

    if (widget.destination != null) {
      Navigator.pushReplacement(
        context,
        PageTransitions.fade(widget.destination!),
      );
    }
  }

  Future<void> _logoutToLogin() async {
    HapticFeedback.mediumImpact();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageTransitions.fade(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF438883);
    final secondaryColor = const Color(0xFF2DD4BF);
    final bgColor = isDark ? const Color(0xFF091716) : const Color(0xFFF4F7F6);
    final cardColor = isDark ? const Color(0xFF142423) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return PopScope(
      canPop: false, // Ngăn người dùng nhấn nút Back để thoát màn hình xác thực
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Quầng sáng Aura ambient phía trên và dưới
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: isDark ? 0.35 : 0.22),
                      primaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      secondaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      secondaryColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // App Bar / Top Navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedScaleButton(
                          onTap: _logoutToLogin,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                'Bảo mật sinh trắc học',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header Title
                            Text(
                              'Chào mừng bạn trở lại',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chạm vào cảm biến hoặc nhấn để quét lại',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Radar Biometric Scanner
                            AnimatedScaleButton(
                              onTap: _isAuthenticating ? null : _authenticate,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Radar Pulsing Outer Ring 2
                                  if (_isAuthenticating)
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        final scale = 1.0 + (_pulseAnimation.value * 0.45);
                                        final opacity = (1.0 - _pulseAnimation.value).clamp(0.0, 1.0);
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 140,
                                            height: 140,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: secondaryColor.withValues(alpha: opacity * 0.4),
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // Radar Pulsing Outer Ring 1
                                  if (_isAuthenticating)
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        final scale = 1.0 + (_pulseAnimation.value * 0.25);
                                        final opacity = (1.0 - _pulseAnimation.value).clamp(0.0, 1.0);
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 140,
                                            height: 140,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: primaryColor.withValues(alpha: opacity * 0.6),
                                                width: 2.5,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // Center Fingerprint Icon Container
                                  Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _error != null
                                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                            : [primaryColor, secondaryColor],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_error != null
                                                  ? const Color(0xFFEF4444)
                                                  : primaryColor)
                                              .withValues(alpha: 0.38),
                                          blurRadius: 28,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _error != null
                                            ? Icons.fingerprint_outlined
                                            : Icons.fingerprint_rounded,
                                        size: 64,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Trạng thái quét / Thông báo lỗi
                            if (_isAuthenticating) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Đang đợi cảm biến sinh trắc học...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 20,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFEF4444),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 36),

                            // Nút thao tác chính: Thử lại
                            AnimatedScaleButton(
                              onTap: _authenticate,
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF438883), Color(0xFF2DD4BF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Quét lại vân tay',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Nút phụ: Dùng mật khẩu (Chuyển sang LoginScreen)
                            AnimatedScaleButton(
                              onTap: _logoutToLogin,
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Đăng nhập bằng mật khẩu',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
