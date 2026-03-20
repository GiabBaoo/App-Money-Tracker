import 'package:flutter/material.dart';

class ActiveDevicesScreen extends StatelessWidget {
  const ActiveDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dữ liệu mô phỏng (Mock Data) các thiết bị
    final List<Map<String, dynamic>> devices = [
      {
        'name': 'iPhone 13 Pro',
        'type': 'mobile',
        'location': 'Hà Nội, Việt Nam',
        'status': 'Đang hoạt động',
        'isCurrent': true, // Đánh dấu thiết bị hiện tại
      },
      {
        'name': 'MacBook Pro 14',
        'type': 'laptop',
        'location': 'Hà Nội, Việt Nam',
        'status': '2 giờ trước',
        'isCurrent': false,
      },
      {
        'name': 'Samsung Galaxy S22',
        'type': 'mobile',
        'location': 'TP. Hồ Chí Minh, Việt Nam',
        'status': '1 ngày trước',
        'isCurrent': false,
      },
      {
        'name': 'Windows PC - Chrome',
        'type': 'desktop',
        'location': 'Đà Nẵng, Việt Nam',
        'status': '3 ngày trước',
        'isCurrent': false,
      },
    ];

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
                    'Thiết bị đang hoạt động',
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
                child: Column(
                  children: [
                    // HEADER CỦA BOX (Icon khiên bảo vệ)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 40,
                        bottom: 20,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F3), // Xanh ngọc nhạt
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.shield,
                              color: Color(0xFF438883),
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Quản lý phiên đăng nhập',
                            style: TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Xem và quản lý tất cả các thiết bị đang\ntruy cập vào tài khoản của bạn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // DANH SÁCH THIẾT BỊ (Cuộn được)
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            return _buildDeviceItem(devices[index]);
                          },
                        ),
                      ),
                    ),

                    // PHẦN CẢNH BÁO VÀ NÚT ĐĂNG XUẤT (Dính ở dưới cùng)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 10,
                        bottom: 40,
                      ),
                      child: Column(
                        children: [
                          // Hộp thông báo màu vàng
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB), // Vàng rất nhạt
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Nếu bạn thấy bất kỳ thiết bị nào lạ, hãy đăng xuất khỏi thiết bị đó ngay lập tức và đổi mật khẩu để bảo vệ tài khoản của bạn.',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Nút đăng xuất tất cả
                          InkWell(
                            onTap: () {
                              // Hành động đăng xuất
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A9B7F), // Màu xanh nút
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4A9B7F,
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.logout,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Đăng xuất khỏi tất cả thiết bị',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM TẠO TỪNG DÒNG THIẾT BỊ ---
  Widget _buildDeviceItem(Map<String, dynamic> device) {
    IconData getDeviceIcon(String type) {
      if (type == 'mobile') return Icons.phone_iphone;
      if (type == 'laptop') return Icons.laptop_mac;
      return Icons.desktop_windows;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Căn trên cùng để giống thiết kế
        children: [
          // Icon nền xanh nhạt
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              getDeviceIcon(device['type']),
              color: const Color(0xFF438883),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Thông tin thiết bị
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device['name'],
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nếu là thiết bị HIỆN TẠI thì thêm nhãn xanh
                    if (device['isCurrent'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HIỆN TẠI',
                          style: TextStyle(
                            color: Color(0xFF438883),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${device['location']} · ${device['status']}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Icon 3 chấm (Menu tùy chọn)
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.grey),
            onPressed: () {
              // Mở popup đăng xuất thiết bị này
            },
          ),
        ],
      ),
    );
  }
}
