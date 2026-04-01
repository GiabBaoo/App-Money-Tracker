import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../home/notification_screen.dart';
import '../settings/account_info_screen.dart';
import '../settings/security_screen.dart';
import 'privacy_screen.dart';
import 'message_center_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            height: 280, width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF0F2625) 
                : const Color(0xFF438883), 
              borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(400, 60))
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const SizedBox(width: 32),
                    const Text('Hồ sơ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () => Navigator.push(context, PageTransitions.slideRight(const NotificationScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.notifications_none, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 30),

                // AVATAR & THÔNG TIN TỪ FIRESTORE
                StreamBuilder<UserModel?>(
                  stream: authService.getUserProfileStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    
                    return Column(children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                          shape: BoxShape.circle
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFEFEFEF),
                          backgroundImage: (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
                            ? NetworkImage(user.avatarUrl)
                            : null,
                          child: (user?.avatarUrl == null || user!.avatarUrl.isEmpty)
                            ? Icon(Icons.person, size: 50, color: Theme.of(context).iconTheme.color?.withOpacity(0.5))
                            : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user?.name ?? 'Đang tải...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF438883))),
                    ]);
                  },
                ),
                const SizedBox(height: 40),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildMenuItem(Icons.settings_outlined, 'Cài đặt', () => Navigator.push(context, PageTransitions.slideRight(const SettingsScreen()))),
                      _buildMenuItem(Icons.person_outline, 'Thông tin tài khoản', () => Navigator.push(context, PageTransitions.slideRight(const AccountInfoScreen()))),
                      _buildMenuItem(Icons.mail_outline, 'Trung tâm tin nhắn', () => Navigator.push(context, PageTransitions.slideRight(const MessageCenterScreen()))),
                      _buildMenuItem(Icons.shield_outlined, 'Đăng nhập và bảo mật', () => Navigator.push(context, PageTransitions.slideRight(const SecurityScreen()))),
                      _buildMenuItem(Icons.lock_outline, 'Dữ liệu và riêng tư', () => Navigator.push(context, PageTransitions.slideRight(const PrivacyScreen()))),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildMenuItem giữ nguyên
  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F6F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 24),
                ),
                const SizedBox(width: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Theme.of(context).iconTheme.color?.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        );
      }
    );
  }
}
