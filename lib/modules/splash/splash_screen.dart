// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/mono_liquid_glass_logo.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../auth/fingerprint_unlock_screen.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';
import '../../services/biometric_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _sheenAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Khởi tạo Animation Controller 60fps đạt chuẩn điện ảnh (1250ms)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    // Giai đoạn 1 & 2: Scale đàn hồi & Fade-in mượt mà
    _scaleAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // Giai đoạn 3: Luồng sáng quét mặt kính Liquid Glass (Specular Sheen Sweep)
    _sheenAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.90, curve: Curves.easeInOutCubic),
      ),
    );

    // Giai đoạn 4: Typography & Tagline xuất hiện
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOut),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _startLaunchFlow();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Khởi chạy song song giữa Animation và Tải dữ liệu phiên người dùng
  Future<void> _startLaunchFlow() async {
    _animController.forward();

    // Chạy song song: Tối thiểu 1350ms để hiệu ứng hiển thị trọn vẹn 60fps
    final results = await Future.wait([
      _resolveDestination(),
      Future.delayed(const Duration(milliseconds: 1350)),
    ]);

    final destination = (results[0] as Widget?) ?? const OnboardingScreen();

    if (!mounted) return;

    _navigateToDestination(destination);
  }

  /// Xác định màn hình đích dựa trên trạng thái đăng nhập & sinh trắc học
  Future<Widget> _resolveDestination() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? effectiveUid = user?.uid;

      if (effectiveUid != null) {
        AuthService().setOnlineUid(effectiveUid);
      } else {
        // Kiểm tra phiên đăng nhập ngoại tuyến an toàn
        String? lastUid;
        try {
          lastUid = await const FlutterSecureStorage().read(key: 'last_offline_uid');
        } catch (e) {
          debugPrint('SplashScreen: Error reading secure storage: $e');
        }

        if (lastUid != null && lastUid.isNotEmpty) {
          effectiveUid = lastUid;
          if (ConnectivityService().isOnline) {
            AuthService().setOnlineUid(lastUid);
          } else {
            AuthService().setOfflineUid(lastUid);
          }
        }
      }

      if (effectiveUid == null) {
        return const OnboardingScreen();
      }

      // Kiểm tra tham gia nhóm pending qua Deep Link / Invite Code
      final prefs = await SharedPreferences.getInstance();
      final pendingGroupId = prefs.getString('pendingGroupId');
      if (pendingGroupId != null && pendingGroupId.isNotEmpty) {
        await prefs.remove('pendingGroupId');
        return JoinGroupScreen(groupId: pendingGroupId);
      }

      // Kiểm tra khóa bảo mật vân tay
      bool fingerprintEnabled = false;
      if (!kIsWeb) {
        try {
          fingerprintEnabled = await BiometricService.instance
              .isFingerprintEnabledForUser(effectiveUid);
        } catch (_) {}
      }

      if (fingerprintEnabled) {
        return FingerprintUnlockScreen(
          destination: const HomeScreen(),
        );
      }

      return const HomeScreen();
    } catch (e) {
      debugPrint('SplashScreen: Init error: $e');
      return const OnboardingScreen();
    }
  }

  /// Chuyển cảnh êm dịu, không giật lag
  void _navigateToDestination(Widget destination) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnim = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnim),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nền Aura thích ứng OLED Dark Mode và Light Mode (Tông màu xanh Teal đặc trưng của MONO)
    final bgColor = isDark ? const Color(0xFF091413) : const Color(0xFFF4FBF9);
    final auraCenterColor = isDark
        ? const Color(0xFF5E8C83).withValues(alpha: 0.32)
        : const Color(0xFF5E8C83).withValues(alpha: 0.25);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Nền Aura vầng sáng khuếch tán (Breathing Aura Light)
          Center(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        auraCenterColor.withValues(
                          alpha: auraCenterColor.a * _fadeAnimation.value,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Nội dung trung tâm: Khối kính Liquid Glass + Typography
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Khối Huy hiệu Liquid Glass Logo 120px
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: MonoLiquidGlassLogo.badge(
                          size: 116,
                          hasShadow: true,
                          hasGlow: true,
                          borderRadius: BorderRadius.circular(32),
                          externalSheen: _sheenAnimation.value,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Chữ 'mono' Wordmark & Tagline thương hiệu
                    FadeTransition(
                      opacity: _textFadeAnimation,
                      child: SlideTransition(
                        position: _textSlideAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MonoLiquidGlassLogo.wordmark(
                              height: 34,
                              color: isDark ? Colors.white : const Color(0xFF0F2625),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'FINANCIAL TRACKER',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF2DD4BF).withValues(alpha: 0.85)
                                    : const Color(0xFF0D9488),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Footer hiển thị Version 2.0.0 tinh tế ở đáy
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: FadeTransition(
              opacity: _textFadeAnimation,
              child: Center(
                child: Text(
                  'v${AppConstants.appVersion}',
                  style: TextStyle(
                    color: isDark ? Colors.white30 : Colors.black26,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
