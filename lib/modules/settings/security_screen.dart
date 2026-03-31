import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'active_devices_screen.dart'; // Import trang Thiết bị đang hoạt động
import 'biometric_screen.dart'; // Đảm bảo đường dẫn đúng
import '../auth/verify_password_screen.dart'; // ĐÃ THÊM: Import trang xác minh mật khẩu cũ

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Đăng nhập và bảo mật',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ), // Khối tàng hình để cân bằng với nút Back
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(
                    0xFFF8F9FA,
                  ), // Nền hơi xám nhạt để làm nổi bật các Card
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 30,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BANNER BẢO MẬT (Xanh Gradient)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4A9B7F), Color(0xFF2F7E79)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2F7E79).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tài khoản an toàn',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cập nhật mật khẩu thường xuyên để tăng tính bảo mật.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // TIÊU ĐỀ SECTION
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'BẢO MẬT TÀI KHOẢN',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // DANH SÁCH CÁC TÙY CHỌN (Nằm trong 1 khối trắng)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ĐÃ CẬP NHẬT: Gắn lệnh chuyển sang VerifyPasswordScreen
                            _buildSecurityItem(
                              icon: Icons.lock_outline,
                              title: 'Đổi mật khẩu',
                              subtitle: 'Cập nhật lần cuối 3 tháng trước',
                              showDivider: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const VerifyPasswordScreen()),
                                );
                              },
                            ),
                            _buildSecurityItem(
                              icon: Icons.fingerprint,
                              title: 'Đăng nhập sinh trắc học',
                              subtitle: 'FaceID / Vân tay',
                              showDivider: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const BiometricScreen()),
                                );
                              },
                            ),

                            // Gắn lệnh chuyển trang vào mục Thiết bị đang hoạt động
                            _buildSecurityItem(
                              icon: Icons.devices,
                              title: 'Thiết bị đang hoạt động',
                              subtitle: '3 thiết bị đang kết nối',
                              showDivider:
                                  false, // Dòng cuối không cần kẻ ngang
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const ActiveDevicesScreen()),
                                );
                              },
                            ),
                          ],
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

  // ĐÃ CẬP NHẬT: Thêm tham số `required VoidCallback onTap`
  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
    required VoidCallback onTap, // Nhận lệnh bấm từ bên ngoài truyền vào
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap, // Sử dụng lệnh bấm ở đây
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon nền xanh ngọc nhạt
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F3), // Xanh ngọc rất nhạt
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF438883), size: 24),
                ),
                const SizedBox(width: 16),

                // Chữ
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mũi tên phải
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        // Đường kẻ ngang mờ mờ giữa các dòng
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 64,
            endIndent: 16,
          ),
      ],
    );
  }
}
