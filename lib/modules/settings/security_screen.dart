import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../utils/time_utils.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
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
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Đăng nhập và bảo mật', 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                        ? TimeUtils.timeAgo(user!.lastPasswordUpdate)
                        : 'Mật khẩu của bạn đang an toàn';

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSecurityBanner(context),
                          const SizedBox(height: 30),
                          _buildSectionTitle(context, 'BẢO MẬT TÀI KHOẢN'),
                          _buildInfoBox(context, [
                            _buildSecurityItem(
                              context,
                              icon: Icons.lock_outline,
                              title: 'Đổi mật khẩu',
                              subtitle: passwordNote,
                              showDivider: true,
                              onTap: () => Navigator.push(context, PageTransitions.slideRight(const VerifyPasswordScreen())),
                            ),
                            _buildSecurityItem(
                              context,
                              icon: Icons.fingerprint,
                              title: 'Đăng nhập sinh trắc học',
                              subtitle: 'Vân tay/FaceID',
                              showDivider: true,
                              onTap: () => Navigator.push(context, PageTransitions.slideRight(const BiometricScreen())),
                            ),
                            _buildSecurityItem(
                              context,
                              icon: Icons.devices,
                              title: 'Thiết bị đang hoạt động',
                              subtitle: 'Quản lý phiên đăng nhập',
                              showDivider: false,
                              onTap: () => Navigator.push(context, PageTransitions.slideRight(const ActiveDevicesScreen())),
                            ),
                          ]),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A9B7F), Color(0xFF2F7E79)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2F7E79).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
            child: const Icon(Icons.security, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tài khoản an toàn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Cập nhật mật khẩu thường xuyên để tăng tính bảo mật.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSecurityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF438883), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 64, endIndent: 16),
      ],
    );
  }
}
