import 'package:flutter/material.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

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
                    'Thông tin tài khoản',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Khối tàng hình cân bằng
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC TRÊN
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
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
                      // KHỐI 1: HEADER PROFILE (Avatar, Tên, ID)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            // Avatar màu xanh nhạt
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                color: Color(0xFFCCFEEB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Color(0xFF2F7E79),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tên
                            const Text(
                              'Lê Trung Cao',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Username và Huy hiệu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '@letrung_cao',
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFEEB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Color(0xFF2F7E79),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã xác minh',
                                        style: TextStyle(
                                          color: Color(0xFF2F7E79),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ID
                            const Text(
                              'ID: FM-000023',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // KHỐI 2: THÔNG TIN CÁ NHÂN
                      _buildSectionTitle('THÔNG TIN CÁ NHÂN'),
                      _buildInfoBox([
                        _buildInfoRow(
                          Icons.badge_outlined,
                          'Họ và tên',
                          'Lê Trung Cao',
                        ),
                        _buildDivider(),
                        _buildInfoRow(Icons.male, 'Giới tính', 'Nam'),
                        _buildDivider(),
                        _buildInfoRow(
                          Icons.cake_outlined,
                          'Ngày sinh',
                          '15/05/1998',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          Icons.payments_outlined,
                          'Loại tiền tệ yêu thích',
                          'VND (Việt Nam Đồng)',
                        ),
                      ]),

                      const SizedBox(height: 30),

                      // KHỐI 3: THÔNG TIN LIÊN LẠC
                      _buildSectionTitle('THÔNG TIN LIÊN LẠC'),
                      _buildInfoBox([
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Email',
                          'letrung.cao@example.com',
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'Số điện thoại',
                          '+84 987 654 321',
                        ),
                      ]),

                      const SizedBox(height: 30),

                      // KHỐI 4: CHI TIẾT TÀI KHOẢN
                      _buildSectionTitle('CHI TIẾT TÀI KHOẢN'),
                      _buildInfoBox([
                        _buildInfoRow(
                          Icons.star_border,
                          'Loại tài khoản',
                          'PREMIUM',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFEEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Pro',
                              style: TextStyle(
                                color: Color(0xFF2F7E79),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _buildDivider(),
                        _buildInfoRow(
                          Icons.calendar_month_outlined,
                          'Ngày gia nhập hệ thống',
                          '12 tháng 01, 2023',
                        ),
                      ]),

                      const SizedBox(height: 30),

                      // NÚT ĐĂNG XUẤT
                      InkWell(
                        onTap: () {
                          // Lệnh đăng xuất
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFCCFEEB,
                            ), // Màu xanh nhạt theo thiết kế
                            borderRadius: BorderRadius.circular(
                              30,
                            ), // Bo tròn giống nút
                          ),
                          child: const Center(
                            child: Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: Color(0xFF2F7E79),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
