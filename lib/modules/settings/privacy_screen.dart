import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'data_usage_screen.dart'; // Đảm bảo đường dẫn đúng
import 'delete_confirmation_screen.dart'; // Import trang hỏi xác nhận xóa
import 'privacy_policy_screen.dart'; // Đảm bảo đường dẫn đúng

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF0F2625) 
        : const Color(0xFF438883),
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
                    'Dữ liệu và riêng tư',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Cân bằng không gian
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
                      // Tiêu đề khối
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Quản lý dữ liệu',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Hộp chứa các cài đặt
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF2E2E2E) 
                            : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            // Sử dụng dữ liệu
                            _buildPrivacyItem(
                              icon: Icons.data_usage,
                              iconBgColor: const Color(
                                0xFFE8F5F0,
                              ), // Xanh ngọc nhạt
                              iconColor: const Color(0xFF438883),
                              title: 'Sử dụng dữ liệu',
                              subtitle:
                                  'Kiểm soát cách ứng dụng sử dụng dữ liệu của bạn',
                              showDivider: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const DataUsageScreen()),
                                );
                              },
                            ),

                            // CHÍNH SÁCH BẢO MẬT (Đã thay đổi từ Tải xuống dữ liệu)
                            _buildPrivacyItem(
                              icon: Icons.policy_outlined,
                              iconBgColor: const Color(0xFFE8F5F0),
                              iconColor: const Color(0xFF438883),
                              title: 'Chính sách bảo mật',
                              subtitle:
                                  'Tìm hiểu cách chúng tôi bảo vệ thông tin của bạn',
                              showDivider: true,
                              onTap: () {
                                // GỌI MÀN HÌNH CHÍNH SÁCH VỪA TẠO
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const PrivacyPolicyScreen()),
                                );
                              },
                            ),

                            // Xóa tài khoản
                            _buildPrivacyItem(
                              icon: Icons.delete_outline,
                              iconBgColor: const Color(0xFFFEE2E2), // Đỏ nhạt
                              iconColor: const Color(0xFFE63946), // Đỏ đậm
                              title: 'Xóa tài khoản',
                              subtitle:
                                  'Xóa vĩnh viễn tài khoản và tất cả dữ liệu',
                              titleColor: const Color(0xFFE63946), // Chữ đỏ
                              showDivider: false, // Dòng cuối không kẻ ngang
                              onTap: () {
                                // CHUYỂN TỚI MÀN HÌNH HỎI XÁC NHẬN ĐẦU TIÊN TRONG LUỒNG XÓA
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                      const DeleteConfirmationScreen()),
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

  // --- HÀM TẠO TỪNG TÙY CHỌN DỮ LIỆU ---
  Widget _buildPrivacyItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? titleColor,
    required bool showDivider,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3E3E3E) : iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // Nội dung
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: titleColor ?? (isDark ? Colors.white : const Color(0xFF333333)),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF888888),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mũi tên điều hướng
                    Icon(
                      Icons.arrow_forward_ios,
                      color: isDark ? Colors.white54 : Colors.grey,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            // Kẻ ngang
            if (showDivider)
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF3E3E3E) : Colors.grey.shade200,
                indent: 76,
                endIndent: 16,
              ),
          ],
        );
      }
    );
  }
}
