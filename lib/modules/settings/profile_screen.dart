import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../home/notification_screen.dart';
import '../settings/account_info_screen.dart';
import '../settings/security_screen.dart';
import 'privacy_screen.dart';
import 'message_center_screen.dart';

<<<<<<< HEAD
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

=======
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  late Stream<UserModel?> _userProfileStream;

  @override
  void initState() {
    super.initState();
    _userProfileStream = _authService.getUserProfileStream();
  }

  @override
  Widget build(BuildContext context) {
>>>>>>> funcionsettinggit
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 280, width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF438883), borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(400, 60))),
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
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
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
<<<<<<< HEAD
                  stream: authService.getUserProfileStream(),
=======
                  stream: _userProfileStream,
>>>>>>> funcionsettinggit
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return Column(children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const CircleAvatar(radius: 50, backgroundColor: Color(0xFFEFEFEF), child: Icon(Icons.person, size: 50, color: Colors.grey)),
                      ),
                      const SizedBox(height: 12),
                      Text(user?.name ?? 'Đang tải...', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
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
                      _buildMenuItem(Icons.person_outline, 'Thông tin tài khoản', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountInfoScreen()))),
                      _buildMenuItem(Icons.mail_outline, 'Trung tâm tin nhắn', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessageCenterScreen()))),
                      _buildMenuItem(Icons.shield_outlined, 'Đăng nhập và bảo mật', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityScreen()))),
                      _buildMenuItem(Icons.lock_outline, 'Dữ liệu và riêng tư', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyScreen()))),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF444444), size: 24),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
