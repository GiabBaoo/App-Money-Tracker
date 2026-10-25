import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../../services/language_service.dart';
import 'login_screen.dart';

class ForgotPasswordConfirmationScreen extends StatelessWidget {
  final String email;

  const ForgotPasswordConfirmationScreen({super.key, required this.email});

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
                    onPressed: () => Navigator.pop(context),
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
                          Icons.mail_outline,
                          color: context.colors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        isVi ? 'Kiểm tra email của bạn' : 'Check your email',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description with email
                      Text(
                        isVi
                            ? 'Chúng tôi đã gửi email đặt lại mật khẩu tới\n$email'
                            : 'We sent a password reset email to\n$email',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng kiểm tra hộp thư và nhấp vào link để đặt lại mật khẩu.'
                            : 'Please check your inbox and click the link to reset your password.',
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
                            ? 'Kiểm tra hộp thư (hoặc thư rác) của bạn'
                            : 'Check your inbox (or spam folder)',
                      ),
                      _buildStep(
                        context,
                        2,
                        isVi
                            ? 'Tìm email từ "no-reply@accounts.google.com"'
                            : 'Look for an email from "no-reply@accounts.google.com"',
                      ),
                      _buildStep(
                        context,
                        3,
                        isVi
                            ? 'Nhấp vào link "Đặt lại mật khẩu" trong email'
                            : 'Click the "Reset password" link in the email',
                      ),
                      _buildStep(
                        context,
                        4,
                        isVi
                            ? 'Tạo mật khẩu mới và lưu thay đổi'
                            : 'Create a new password and save changes',
                      ),
                      const SizedBox(height: 40),

                      // Instruction box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.warningBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: context.warning.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: context.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isVi
                                    ? 'Link sẽ hết hạn sau 1 giờ. Nếu không nhận được email, kiểm tra thư mục Spam hoặc Promotions.'
                                    : 'The link expires after 1 hour. If you do not receive the email, check your Spam or Promotions folder.',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colors.onSurface,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Back to login button
                      InkWell(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            PageTransitions.fade(const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
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
                            child: Text(
                              isVi ? 'Quay lại Đăng nhập' : 'Back to Login',
                              style: context.textTheme.titleMedium?.copyWith(
                                color: context.colors.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact support link
                      Center(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isVi
                                      ? 'Vui lòng liên hệ support@mono.com'
                                      : 'Please contact support@mono.com',
                                ),
                                backgroundColor: context.colors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          },
                          child: Text(
                            isVi
                                ? 'Có vấn đề? Liên hệ hỗ trợ'
                                : 'Have issues? Contact support',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
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
