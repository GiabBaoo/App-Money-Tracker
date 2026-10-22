import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/mono_toast.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import 'forgot_password_confirmation_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPasswordReset() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final email = _emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      _showSnackBar(isVi ? 'Vui lòng nhập email!' : 'Please enter your email!', isError: true);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar(isVi ? 'Email không hợp lệ!' : 'Invalid email address!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Goi API Firebase de gui email reset password
    final result = await _authService.sendPasswordResetEmail(email: email);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar(result.message, isError: false);
      // Chuyen sang trang xac nhan
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageTransitions.slideRight(
              ForgotPasswordConfirmationScreen(email: email),
            ),
          );
        }
      });
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
      backgroundColor: isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                AnimatedScaleButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.onPrimary.withValues(alpha: 0.15),
                      border: Border.all(color: context.colors.onPrimary.withValues(alpha: 0.24), width: 1),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: context.colors.onPrimary,
                      size: 18,
                    ),
                  ),
                ),
                const Spacer(),
                AppLogo.wordmark(height: 32, color: context.colors.onPrimary),
                const Spacer(flex: 2),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: AppShadows.modal(isDark),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Quên mật khẩu' : 'Forgot Password',
                        style: context.textTheme.headlineMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng nhập email của bạn. Chúng tôi sẽ gửi link đặt lại mật khẩu.'
                            : 'Please enter your email. We will send you a password reset link.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'Email',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _emailController,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.inputBgColor,
                          hintText: isVi ? 'Nhập email của bạn' : 'Enter your email',
                          hintStyle: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: context.colors.primary, width: 1.8),
                          ),
                          suffixIcon: Icon(Icons.mail_outline, color: context.colors.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Center(
                        child: AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              isVi ? 'Quay lại Đăng nhập' : 'Back to Login',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedScaleButton(
                        onTap: _isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _handleSendPasswordReset();
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [context.colors.surfaceContainerHighest, context.colors.surfaceContainerHighest]
                                  : [AppColors.primaryTealLight, AppColors.primaryTeal],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.primary.withValues(alpha: 0.3),
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
                                    isVi ? 'Gửi email đặt lại mật khẩu' : 'Send Reset Link',
                                    style: context.textTheme.titleMedium?.copyWith(
                                      color: context.colors.onPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
}
