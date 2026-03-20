import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh ngọc
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
                    onPressed: () =>
                        Navigator.pop(context), // Quay lại màn hình trước
                  ),
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ), // Khối tàng hình để cân bằng layout
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: ListView(
                  padding: const EdgeInsets.only(
                    top: 30,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  children: [
                    // MỤC: HÔM NAY
                    _buildDateHeader('Hôm nay'),
                    _buildNotificationItem(
                      icon: Icons.emoji_events,
                      iconBgColor: const Color(0xFFFEF3C7), // Vàng nhạt
                      iconColor: const Color(0xFFF59E0B), // Vàng cam
                      title: 'Chúc mừng',
                      description:
                          'Bạn đã đạt được mục tiêu tiết kiệm tuần này!',
                      time: '10:30',
                    ),
                    _buildNotificationItem(
                      icon: Icons.warning_amber_rounded,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Cảnh báo ngân sách',
                      description:
                          'Bạn đã dùng 90% ngân sách ăn uống tháng này.',
                      time: '08:15',
                    ),

                    const SizedBox(height: 10),

                    // MỤC: HÔM QUA
                    _buildDateHeader('Hôm qua'),
                    _buildNotificationItem(
                      icon: Icons.settings,
                      iconBgColor: const Color(0xFFDBEAFE), // Xanh dương nhạt
                      iconColor: const Color(0xFF3B82F6), // Xanh dương
                      title: 'Cập nhật hệ thống',
                      description:
                          'Tính năng báo cáo mới đã sẵn sàng. Khám phá ngay!',
                      time: '16:45',
                    ),
                    _buildNotificationItem(
                      icon: Icons.check_circle_outline,
                      iconBgColor: const Color(0xFFCCFBF1), // Xanh ngọc nhạt
                      iconColor: const Color(0xFF14B8A6), // Xanh ngọc
                      title: 'Thanh toán hoàn tất',
                      description:
                          'Hóa đơn gia hạn VIP tháng 3 của bạn đã được thanh toán.',
                      time: '09:10',
                    ),
                    _buildNotificationItem(
                      icon: Icons.card_giftcard,
                      iconBgColor: const Color(0xFFFCE7F3), // Hồng nhạt
                      iconColor: const Color(0xFFEC4899), // Hồng
                      title: 'Phần thưởng cho bạn',
                      description:
                          'Chúc mừng! Bạn đã nhận được mã giảm giá 50% cho nạp VIP lần đầu tiên.',
                      time: '07:20',
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

  // --- HÀM TẠO TIÊU ĐỀ NGÀY (Hôm nay, Hôm qua) ---
  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        date,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // --- HÀM TẠO TỪNG DÒNG THÔNG BÁO ---
  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String description,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // Nền xám rất nhạt
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon thông báo
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          // Nội dung thông báo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Thời gian
          Text(
            time,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
