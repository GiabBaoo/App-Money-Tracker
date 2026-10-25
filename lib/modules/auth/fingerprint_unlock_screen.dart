import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../services/biometric_service.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../core/session/session_manager.dart';
import 'login_screen.dart';

/// Màn hình mở khóa bằng sinh trắc học (Vân tay / FaceID)
/// Thiết kế tối giản, thanh lịch, tinh gọn chuẩn ứng dụng ngân hàng / Fintech hiện đại.
class FingerprintUnlockScreen extends StatefulWidget {
  final Widget? destination;
  final VoidCallback? onUnlock;

  const FingerprintUnlockScreen({super.key, this.destination, this.onUnlock});

  @override
  State<FingerprintUnlockScreen> createState() =>
      _FingerprintUnlockScreenState();
}

class _FingerprintUnlockScreenState extends State<FingerprintUnlockScreen> {
  String? _errorMessage;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Tự động kích hoạt hộp thoại cảm biến vân tay ngay khi màn hình sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _isAuthenticating = true;
    });

    final supported = await BiometricService.instance.canCheckBiometrics();
    if (!mounted) return;

    if (!supported) {
      // Nếu thiết bị không hỗ trợ hoặc chưa đăng ký, bỏ qua để không kẹt app
      _goNext();
      return;
    }

    final isVi = LanguageScope.of(context).isVietnamese;
    final ok = await BiometricService.instance.authenticateFingerprint(
      localizedReason: isVi
          ? 'Chạm cảm biến để mở khóa ứng dụng Mono'
          : 'Touch sensor to unlock Mono app',
    );
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      final effectiveUid = AuthService().currentUid;
      if (effectiveUid != null) {
        if (SessionManager.instance.uidOrNull != effectiveUid) {
          SessionManager.instance.activate(effectiveUid);
        }
        unawaited(
          BiometricService.instance
              .recordFingerprintLogin(uid: effectiveUid)
              .catchError((_) {}),
        );
        unawaited(
          AuthService().silentReauthenticateIfNeeded().catchError((_) => false),
        );
      }
      _goNext();
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _isAuthenticating = false;
        _errorMessage = isVi
            ? 'Chưa nhận diện được vân tay. Vui lòng chạm lại!'
            : 'Fingerprint not recognized. Please try again!';
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
    HapticFeedback.lightImpact();
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
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;
    final primaryColor = context.colors.primary;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // 1. BIỂU TƯỢNG VÂN TAY TINH TẾ & TỐI GIẢN
                AnimatedScaleButton(
                  onTap: _isAuthenticating ? null : _authenticate,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _errorMessage != null
                            ? [
                                context.colors.error,
                                context.colors.error.withValues(alpha: 0.8),
                              ]
                            : [primaryColor, AppColors.primaryTealVibrant],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_errorMessage != null
                                      ? context.colors.error
                                      : primaryColor)
                                  .withValues(alpha: isDark ? 0.35 : 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _errorMessage != null
                            ? Icons.fingerprint_outlined
                            : Icons.fingerprint_rounded,
                        size: 58,
                        color: context.colors.onPrimary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // 2. TIÊU ĐỀ & HƯỚNG DẪN NGẮN GỌN
                Text(
                  isVi ? 'Xác thực sinh trắc học' : 'Biometric Authentication',
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ??
                      (isVi
                          ? 'Chạm vào cảm biến vân tay để mở khóa ứng dụng'
                          : 'Touch the fingerprint sensor to unlock the app'),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _errorMessage != null
                        ? context.colors.error
                        : context.colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _authenticate,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      isVi ? 'Chạm để quét lại' : 'Tap to scan again',
                      style: context.textTheme.labelLarge?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // 3. TÙY CHỌN DÙNG MẬT KHẨU (TỐI GIẢN PHÍA DƯỚI)
                AnimatedScaleButton(
                  onTap: _logoutToLogin,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                      boxShadow: AppShadows.card(isDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: context.colors.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVi
                              ? 'Đăng nhập bằng mật khẩu'
                              : 'Log in with password',
                          style: context.textTheme.labelLarge?.copyWith(
                            color: context.colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
