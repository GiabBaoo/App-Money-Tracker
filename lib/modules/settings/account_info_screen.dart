import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final AuthService _authService = AuthService();
  late Stream<UserModel?> _userProfileStream;

  @override
  void initState() {
    super.initState();
    _userProfileStream = _authService.getUserProfileStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Thông tin tài khoản', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(width: 48),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                child: StreamBuilder<UserModel?>(
                  stream: _userProfileStream,
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                            child: Column(children: [
                              Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFCCFEEB), shape: BoxShape.circle), child: const Icon(Icons.person, size: 40, color: Color(0xFF2F7E79))),
                              const SizedBox(height: 12),
                              Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                              const SizedBox(height: 8),
                              Text('ID: ${user.uid.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
                            ]),
                          ),
                          const SizedBox(height: 30),

                          _buildSectionTitle('THÔNG TIN CÁ NHÂN'),
                          _buildInfoBox([
                            _buildInfoRow(Icons.badge_outlined, 'Họ và tên', user.name),
                            _buildDivider(),
                            _buildInfoRow(Icons.male, 'Giới tính', user.gender),
                            _buildDivider(),
                            _buildInfoRow(Icons.cake_outlined, 'Ngày sinh', user.dateOfBirth != null ? '${user.dateOfBirth!.day.toString().padLeft(2, '0')}/${user.dateOfBirth!.month.toString().padLeft(2, '0')}/${user.dateOfBirth!.year}' : 'Chưa cập nhật'),
                            _buildDivider(),
                            _buildInfoRow(Icons.payments_outlined, 'Loại tiền tệ', user.currency),
                          ]),
                          const SizedBox(height: 30),

                          _buildSectionTitle('THÔNG TIN LIÊN LẠC'),
                          _buildInfoBox([
                            _buildInfoRow(Icons.email_outlined, 'Email', user.email),
                            _buildDivider(),
                            _buildInfoRow(Icons.phone_outlined, 'Số điện thoại', user.phone.isNotEmpty ? user.phone : 'Chưa cập nhật'),
                          ]),
                          const SizedBox(height: 30),

                          _buildSectionTitle('CHI TIẾT TÀI KHOẢN'),
                          _buildInfoBox([
                            _buildInfoRow(Icons.star_border, 'Loại tài khoản', user.accountType),
                            _buildDivider(),
                            _buildInfoRow(Icons.calendar_month_outlined, 'Ngày gia nhập', '${user.joinDate.day.toString().padLeft(2, '0')}/${user.joinDate.month.toString().padLeft(2, '0')}/${user.joinDate.year}'),
                          ]),
                          const SizedBox(height: 30),

                          // NÚT ĐĂNG XUẤT
                          InkWell(
                            onTap: () async {
                              await _authService.logout();
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                            },
                            child: Container(
                              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(color: const Color(0xFFCCFEEB), borderRadius: BorderRadius.circular(30)),
                              child: const Center(child: Text('Đăng xuất', style: TextStyle(color: Color(0xFF2F7E79), fontSize: 16, fontWeight: FontWeight.w600))),
                            ),
                          ),
                          const SizedBox(height: 20),
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

  // --- HÀM TẠO TIÊU ĐỀ NHỎ ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- HÀM TẠO KHUNG BO VIỀN CHỨA CÁC DÒNG ---
  Widget _buildInfoBox(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  // --- HÀM TẠO TỪNG DÒNG THÔNG TIN ---
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Icon xanh nhạt
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F0), // Xanh ngọc rất nhạt
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF438883), size: 24),
          ),
          const SizedBox(width: 16),
          // Label và Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HÀM TẠO ĐƯỜNG KẺ NGANG ---
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: Color(0xFFF0F0F0),
      indent: 70,
      endIndent: 16,
    );
  }
}
