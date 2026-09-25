import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/page_transitions.dart';
import '../../utils/time_utils.dart';
import 'active_devices_screen.dart';
import 'biometric_screen.dart';
import '../auth/verify_password_screen.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Đăng nhập và bảo mật',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content Body
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<UserModel?>(
                  stream: authService.getUserProfileStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final passwordNote = user?.lastPasswordUpdate != null
                        ? 'Cập nhật ${TimeUtils.timeAgo(user!.lastPasswordUpdate)}'
                        : 'Mật khẩu đang được bảo vệ an toàn';

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Security Health Banner
                          _buildSecurityHeroCard(isDark),
                          const SizedBox(height: 24),

                          // Section 1: PHƯƠNG THỨC XÁC THỰC
                          _buildSectionTitle(context, 'PHƯƠNG THỨC XÁC THỰC'),
                          _buildCardContainer(
                            isDark: isDark,
                            children: [
                              _buildSecurityRow(
                                isDark: isDark,
                                icon: Icons.lock_outline_rounded,
                                title: 'Đổi mật khẩu',
                                subtitle: passwordNote,
                                onTap: () => Navigator.push(
                                  context,
                                  PageTransitions.slideRight(const VerifyPasswordScreen()),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSecurityRow(
                                isDark: isDark,
                                icon: Icons.fingerprint_rounded,
                                title: 'Đăng nhập sinh trắc học',
                                subtitle: 'Vân tay hoặc FaceID để truy cập tức thì',
                                onTap: () => Navigator.push(
                                  context,
                                  PageTransitions.slideRight(const BiometricScreen()),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSecurityRow(
                                isDark: isDark,
                                icon: Icons.devices_rounded,
                                title: 'Thiết bị đang hoạt động',
                                subtitle: 'Kiểm tra và đăng xuất khỏi các thiết bị lạ',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF438883).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '1 thiết bị',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF438883),
                                    ),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  PageTransitions.slideRight(const ActiveDevicesScreen()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section 2: TÍNH NĂNG BẢO MẬT NÂNG CAO
                          _buildSectionTitle(context, 'TÍNH NĂNG BẢO VỆ'),
                          _buildCardContainer(
                            isDark: isDark,
                            children: [
                              _buildSecurityRow(
                                isDark: isDark,
                                icon: Icons.security_update_good_rounded,
                                title: 'Ghi nhớ đăng nhập',
                                subtitle: 'Duy trì trạng thái đăng nhập để mở app nhanh chóng',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Đang bật',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSecurityRow(
                                isDark: isDark,
                                icon: Icons.shield_moon_outlined,
                                title: 'Bảo vệ dữ liệu cục bộ',
                                subtitle: 'Mã hóa cơ sở dữ liệu SQLite chuẩn AES-256',
                                badge: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF438883).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Đã kích hoạt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF438883),
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

  Widget _buildSecurityHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E3A37), Color(0xFF132A27)]
              : const [Color(0xFF438883), Color(0xFF2E635F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2E5E57) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF438883)).withValues(alpha: 0.35),
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
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Tài khoản an toàn',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Cấp độ cao',
                        style: TextStyle(color: Color(0xFF1B5E20), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Thông tin xác thực và dữ liệu thu chi của bạn đang được mã hóa và bảo vệ tối đa.',
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
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSecurityRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF438883), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge,
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
    );
  }
}
