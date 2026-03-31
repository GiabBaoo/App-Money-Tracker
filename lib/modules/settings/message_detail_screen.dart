import 'package:flutter/material.dart';

class MessageDetailScreen extends StatelessWidget {
  // Các biến nhận dữ liệu từ màn hình danh sách truyền sang
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String time;
  final String fullMessage; // Nội dung chi tiết dài

  const MessageDetailScreen({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.time,
    required this.fullMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF438883),
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
                    'Chi tiết tin nhắn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Cân bằng với nút Back
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
                child: Column(
                  children: [
                    // NỘI DUNG CUỘN ĐƯỢC
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER CỦA TIN NHẮN (Icon + Tiêu đề + Thời gian)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF212121),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: isDark ? Colors.white54 : const Color(0xFFAAAAAA),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            time,
                                            style: TextStyle(
                                              color: isDark ? Colors.white54 : const Color(0xFFAAAAAA),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            Divider(
                              color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFEEEEEE),
                              height: 1,
                            ),
                            const SizedBox(height: 24),

                            // NỘI DUNG CHI TIẾT
                            Text(
                              fullMessage,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF444444),
                                fontSize: 16,
                                height: 1.6, // Giãn dòng cho dễ đọc
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Color(0xFF212121),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Color(0xFFAAAAAA),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            time,
                                            style: const TextStyle(
                                              color: Color(0xFFAAAAAA),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            const Divider(color: Color(0xFFEEEEEE), height: 1),
                            const SizedBox(height: 24),

                            // NỘI DUNG CHI TIẾT
                            Text(
                              fullMessage,
                              style: const TextStyle(
                                color: Color(0xFF444444),
                                fontSize: 16,
                                height: 1.6, // Giãn dòng cho dễ đọc
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // NÚT BẤM CỐ ĐỊNH DƯỚI CÙNG (Đã hiểu)
                    Container(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 40,
                        top: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: InkWell(
                        onTap: () => Navigator.pop(context), // Đóng trang
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5F0), // Nền xanh nhạt
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Đã hiểu',
                              style: TextStyle(
                                color: Color(0xFF4A9B7F),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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
}
