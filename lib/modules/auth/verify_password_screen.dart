import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/language_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_toast.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import 'reset_password_screen.dart';

class VerifyPasswordScreen extends StatefulWidget {
  const VerifyPasswordScreen({super.key});

  @override
  State<VerifyPasswordScreen> createState() => _VerifyPasswordScreenState();
}

class _VerifyPasswordScreenState extends State<VerifyPasswordScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  final AuthService _authService = AuthService();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      final isVi = LanguageScope.of(context).isVietnamese;
      MonoToast.error(context, isVi ? 'Vui lòng nhập mật khẩu!' : 'Please enter your password!');
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.verifyCurrentPassword(password: password);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result.success) {
      Navigator.push(context, PageTransitions.slideRight(const ResetPasswordScreen(isFromSecurity: true)));
    } else {
      MonoToast.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
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
                  Expanded(
                    child: Text(
                      isVi ? 'Xác thực bảo mật' : 'Security Verification',
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colors.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42), // Cân bằng layout
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: AppShadows.modal(isDark),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Nhập mật khẩu hiện tại' : 'Enter Current Password',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi ? 'Vui lòng nhập mật khẩu bạn đang sử dụng để xác minh danh tính trước khi đổi mật khẩu mới.' : 'Please enter your current password to verify your identity before changing your password.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          isVi ? 'Mật khẩu hiện tại' : 'Current Password',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: isVi ? 'Nhập mật khẩu hiện tại' : 'Enter Current Password',
                          hintStyle: context.textTheme.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: context.inputBgColor,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: context.colors.primary,
                              width: 1.8,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: context.colors.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // NÚT TIẾP TỤC
                      AnimatedScaleButton(
                        onTap: _isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _handleVerify();
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
                                color: context.colors.primary.withValues(alpha: 0.35),
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
                                    isVi ? 'Tiếp tục' : 'Continue',
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
