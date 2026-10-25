import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../utils/time_utils.dart';
import '../../widgets/animated_scale_button.dart';
import 'active_devices_screen.dart';
import 'biometric_screen.dart';
import '../auth/verify_password_screen.dart';
import '../../services/language_service.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isDark = context.isDark;
    final isVi = LanguageScope.of(context).isVietnamese;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.bgDark
          : Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    isVi ? 'Đăng nhập và bảo mật' : 'Login & Security',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Content Body
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: StreamBuilder<UserModel?>(
                  stream: authService.getUserProfileStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final passwordNote = user?.lastPasswordUpdate != null
                        ? (isVi
                              ? 'Cập nhật ${TimeUtils.timeAgo(user!.lastPasswordUpdate, isVi: true)}'
                              : 'Updated ${TimeUtils.timeAgo(user!.lastPasswordUpdate, isVi: false)}')
                        : (isVi
                              ? 'Mật khẩu đang được bảo vệ an toàn'
                              : 'Password is secure and protected');

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Security Health Banner
                          _buildSecurityHeroCard(context, isDark, isVi),
                          const SizedBox(height: 24),

                          // Section 1: PHƯƠNG THỨC XÁC THỰC
                          _buildSectionTitle(
                            context,
                            isVi
                                ? 'PHƯƠNG THỨC XÁC THỰC'
                                : 'AUTHENTICATION METHODS',
                          ),
                          _buildCardContainer(
                            context,
                            isDark: isDark,
                            children: [
                              _buildSecurityRow(
                                context,
                                isDark: isDark,
                                icon: Icons.lock_outline_rounded,
                                title: isVi
                                    ? 'Đổi mật khẩu'
                                    : 'Change Password',
                                subtitle: passwordNote,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    PageTransitions.slideRight(
                                      const VerifyPasswordScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildDivider(context, isDark),
                              _buildSecurityRow(
                                context,
                                isDark: isDark,
                                icon: Icons.fingerprint_rounded,
                                title: isVi
                                    ? 'Đăng nhập sinh trắc học'
                                    : 'Biometric Login',
                                subtitle: isVi
                                    ? 'Vân tay hoặc FaceID để truy cập tức thì'
                                    : 'Fingerprint or FaceID for instant access',
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    PageTransitions.slideRight(
                                      const BiometricScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildDivider(context, isDark),
                              _buildSecurityRow(
                                context,
                                isDark: isDark,
                                icon: Icons.devices_rounded,
                                title: isVi
                                    ? 'Thiết bị đang hoạt động'
                                    : 'Active Devices',
                                subtitle: isVi
                                    ? 'Kiểm tra và đăng xuất khỏi các thiết bị lạ'
                                    : 'Review and log out of unrecognized devices',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.brandColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isVi ? '1 thiết bị' : '1 device',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.brandColor,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    PageTransitions.slideRight(
                                      const ActiveDevicesScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section 2: TÍNH NĂNG BẢO MẬT NÂNG CAO
                          _buildSectionTitle(
                            context,
                            isVi ? 'TÍNH NĂNG BẢO VỆ' : 'SECURITY FEATURES',
                          ),
                          _buildCardContainer(
                            context,
                            isDark: isDark,
                            children: [
                              _buildSecurityRow(
                                context,
                                isDark: isDark,
                                icon: Icons.security_update_good_rounded,
                                title: isVi
                                    ? 'Ghi nhớ đăng nhập'
                                    : 'Remember Login',
                                subtitle: isVi
                                    ? 'Duy trì trạng thái đăng nhập để mở app nhanh chóng'
                                    : 'Stay logged in to quickly open the app',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.income.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isVi ? 'Đang bật' : 'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.income,
                                    ),
                                  ),
                                ),
                              ),
                              _buildDivider(context, isDark),
                              _buildSecurityRow(
                                context,
                                isDark: isDark,
                                icon: Icons.shield_moon_outlined,
                                title: isVi
                                    ? 'Bảo vệ dữ liệu cục bộ'
                                    : 'Local Data Protection',
                                subtitle: isVi
                                    ? 'Mã hóa cơ sở dữ liệu SQLite chuẩn AES-256'
                                    : 'AES-256 encrypted local SQLite database',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.brandColor.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isVi ? 'Đã kích hoạt' : 'Enabled',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.brandColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityHeroCard(BuildContext context, bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.brandGradientDark
            : AppColors.brandGradientLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : context.brandColor).withValues(
              alpha: 0.35,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isVi ? 'Tài khoản an toàn' : 'Account Secure',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isVi ? 'Cấp độ cao' : 'High Level',
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isVi
                      ? 'Thông tin xác thực và dữ liệu thu chi của bạn đang được mã hóa và bảo vệ tối đa.'
                      : 'Your credentials and transaction data are encrypted and fully protected.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style:
            context.textTheme.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ) ??
            TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  Widget _buildCardContainer(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSecurityRow(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? context.surfaceElevatedColor
                    : context.brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: context.brandColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ) ??
                        TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style:
                        context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.25,
                        ) ??
                        TextStyle(
                          fontSize: 12.5,
                          color: context.colors.onSurfaceVariant,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 8), badge],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: context.dividerColor,
    );
  }
}
