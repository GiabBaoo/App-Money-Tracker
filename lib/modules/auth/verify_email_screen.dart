import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/mono_toast.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../home/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    // Tự động kiểm tra email verification mỗi 3 giây
    _startAutoCheck();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;

      final result = await _authService.reloadAndCheckEmailVerification();

      if (result.emailVerified && mounted) {
        _autoCheckTimer?.cancel();
        final isVi = LanguageScope.of(context).isVietnamese;
        _showSnackBar(
          isVi
              ? 'Email đã xác nhận! Đang nhập vào ứng dụng...'
              : 'Email verified! Logging into app...',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              PageTransitions.fade(const HomeScreen()),
              (route) => false,
            );
          }
        });
      }
    });
  }

  Future<void> _handleVerifyManually() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isLoading = true);

    final result = await _authService.reloadAndCheckEmailVerification();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.emailVerified) {
      _showSnackBar(
        isVi
            ? 'Email đã xác nhận! Đang nhập vào ứng dụng...'
            : 'Email verified! Logging into app...',
        isError: false,
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageTransitions.fade(const HomeScreen()),
            (route) => false,
          );
        }
      });
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  Future<void> _handleResendEmail() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isLoading = true);

    final result = await _authService.sendEmailVerification();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar(
        isVi ? 'Email xác nhận đã được gửi lại!' : 'Verification email resent!',
        isError: false,
      );
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    MonoToast.show(
      context,
      message,
      type: isError ? MonoToastType.error : MonoToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.primaryTealDark
          : AppColors.primaryTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: context.colors.onPrimary,
                      size: 20,
                    ),
                    onPressed: () {
                      _authService.logout();
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  AppLogo.wordmark(height: 32, color: context.colors.onPrimary),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: AppShadows.modal(isDark),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.mail_outline_rounded,
                          color: context.colors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        isVi ? 'Xác nhận email của bạn' : 'Verify your email',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        isVi
                            ? 'Chúng tôi đã gửi email xác nhận tới\n${widget.email}'
                            : 'We sent a verification email to\n${widget.email}',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng kiểm tra hộp thư và nhấp vào link để xác nhận.'
                            : 'Please check your inbox and click the link to verify.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Steps
                      _buildStep(
                        context,
                        1,
                        isVi
                            ? 'Mở email mà chúng tôi vừa gửi'
                            : 'Open the email we just sent',
                      ),
                      _buildStep(
                        context,
                        2,
                        isVi
                            ? 'Nhấp vào link xác nhận trong email'
                            : 'Click the verification link in the email',
                      ),
                      _buildStep(
                        context,
                        3,
                        isVi ? 'Quay trở lại ứng dụng' : 'Return to the app',
                      ),
                      const SizedBox(height: 40),

                      // Manual Check Button
                      InkWell(
                        onTap: _isLoading ? null : _handleVerifyManually,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [
                                      context.colors.surfaceContainerHighest,
                                      context.colors.surfaceContainerHighest,
                                    ]
                                  : [
                                      AppColors.primaryTealLight,
                                      AppColors.primaryTeal,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: context.colors.onPrimary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isVi
                                        ? 'Đã xác nhận email'
                                        : 'I have verified my email',
                                    style: context.textTheme.titleMedium
                                        ?.copyWith(
                                          color: context.colors.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Resend Email Button
                      InkWell(
                        onTap: _isLoading ? null : _handleResendEmail,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.colors.primary,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              isVi
                                  ? 'Gửi lại email xác nhận'
                                  : 'Resend verification email',
                              style: context.textTheme.titleSmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout Link
                      InkWell(
                        onTap: () {
                          _authService.logout();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Text(
                          isVi ? 'Quay lại Đăng nhập' : 'Back to Login',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, int number, String text) {
    final isDark = context.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? context.colors.primaryContainer
                  : context.colors.primary,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Text(
                '$number',
                style: context.textTheme.labelMedium?.copyWith(
                  color: isDark
                      ? context.colors.onPrimaryContainer
                      : context.colors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
