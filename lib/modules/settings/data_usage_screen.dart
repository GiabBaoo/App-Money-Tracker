import 'package:flutter/material.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  // Quản lý trạng thái bật/tắt của các công tắc
  bool _isLocationEnabled = true;
  bool _isContactsEnabled = false;
  bool _isSearchHistoryEnabled = true;

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
                    'Sử dụng dữ liệu',
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA), // Nền xám nhạt
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
                      // TIÊU ĐỀ SECTION
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'DỮ LIỆU ĐƯỢC THU THẬP',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // DANH SÁCH CÁC QUYỀN
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
                            // Quyền: Vị trí
                            _buildToggleItem(
                              icon: Icons.location_on_outlined,
                              title: 'Vị trí',
                              subtitle:
                                  'Cho phép truy cập vị trí hiện tại để tối ưu hóa gợi ý địa phương',
                              value: _isLocationEnabled,
                              onChanged: (val) {
                                setState(() {
                                  _isLocationEnabled = val;
                                });
                              },
                              showDivider: true,
                            ),

                            // Quyền: Danh bạ
                            _buildToggleItem(
                              icon: Icons.contacts_outlined,
                              title: 'Danh bạ',
                              subtitle:
                                  'Đồng bộ hóa danh bạ để kết nối nhanh chóng với bạn bè',
                              value: _isContactsEnabled,
                              onChanged: (val) {
                                setState(() {
                                  _isContactsEnabled = val;
                                });
                              },
                              showDivider: true,
                            ),

                            // Quyền: Lịch sử tìm kiếm
                            _buildToggleItem(
                              icon: Icons.manage_search,
                              title: 'Lịch sử tìm kiếm',
                              subtitle:
                                  'Lưu lại các từ khóa để đề xuất nội dung phù hợp với sở thích',
                              value: _isSearchHistoryEnabled,
                              onChanged: (val) {
                                setState(() {
                                  _isSearchHistoryEnabled = val;
                                });
                              },
                              showDivider:
                                  false, // Dòng cuối không cần kẻ ngang
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // HỘP THÔNG BÁO CAM KẾT BẢO MẬT
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7F5), // Xanh ngọc rất nhạt
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCCFEEB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user,
                                color: Color(0xFF4A9B7F),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Cam kết bảo mật',
                                    style: TextStyle(
                                      color: Color(0xFF333333),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Dữ liệu của bạn được mã hóa và bảo vệ theo tiêu chuẩn quốc tế.',
                                    style: TextStyle(
                                      color: Color(0xFF666666),
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

  // --- HÀM TẠO TỪNG DÒNG CÓ CÔNG TẮC BẬT TẮT ---
  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon nền xanh nhạt
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F0), // Xanh ngọc rất nhạt
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

              const SizedBox(width: 8),

              // Công tắc (Switch)
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF4A9B7F),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 76,
            endIndent: 16,
          ),
      ],
    );
  }
}
