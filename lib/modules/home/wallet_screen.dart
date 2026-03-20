import 'package:flutter/material.dart';
import '../transaction/transaction_detail_screen.dart'; // Đảm bảo đường dẫn này đúng với project của bạn
import '../home/notification_screen.dart'; // Đảm bảo đường dẫn này đúng với file NotificationScreen của bạn
// Ví dụ: import '../home/notification_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF438883,
      ), // Nền xanh lá mạ bao phủ phần trên

      body: SafeArea(
        bottom: false, // Để phần nền trắng tràn xuống tận cùng màn hình
        child: Column(
          children: [
            // 1. CUSTOM APP BAR (Đã bỏ nút Back, Tiêu đề, Chuông)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Khối tàng hình để cân bằng layout, giữ chữ "Ví" ở chính giữa
                  const SizedBox(width: 32),

                  const Text(
                    'Ví',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // ĐÃ SỬA: Thêm InkWell và Navigator để điều hướng tới trang Thông báo
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );

                      print("Đã bấm vào nút thông báo"); // Log tạm thời
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 30,
            ), // Khoảng cách từ Appbar xuống phần trắng
            // 2. PHẦN NỘI DUNG MÀU TRẮNG BO GÓC TRÊN
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30),
                  ), // Bo cong 2 góc trên
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 40,
                    bottom: 120,
                  ), // Padding dưới để không bị thanh Nav đè
                  child: Column(
                    children: [
                      // TỔNG SỐ DƯ
                      const Text(
                        'Tổng số dư',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '66.808.429 đ',
                        style: TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // NÚT "TRANSACTIONS" HÌNH VIÊN THUỐC (Pill)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F6),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Transactions',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // DANH SÁCH GIAO DỊCH
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Gọi hàm kèm theo context
                            _buildTransactionItem(
                              context: context,
                              icon: Icons.work_outline,
                              iconColor: Colors.lightGreen,
                              title: 'Upwork',
                              date: 'Hôm Nay',
                              amount: '+ 22.286.956đ',
                              isIncome: true,
                            ),
                            _buildTransactionItem(
                              context: context,
                              icon: Icons.person_outline,
                              iconColor: Colors.blueGrey,
                              title: 'Transfer',
                              date: 'Hôm Qua',
                              amount: '- 2.228.695đ',
                              isIncome: false,
                            ),
                            _buildTransactionItem(
                              context: context,
                              icon: Icons.payment,
                              iconColor: Colors.blue,
                              title: 'Paypal',
                              date: 'Th1 30, 2022',
                              amount: '+ 36.865.247đ',
                              isIncome: true,
                            ),
                            _buildTransactionItem(
                              context: context,
                              icon: Icons.play_arrow,
                              iconColor: Colors.red,
                              title: 'Youtube',
                              date: 'Th1 16, 2022',
                              amount: '- 314.639đ',
                              isIncome: false,
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

  // --- WIDGET TẠO TỪNG DÒNG GIAO DỊCH ---
  Widget _buildTransactionItem({
    required BuildContext context, // Thêm context để Navigator hoạt động
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        // Bọc InkWell để bắt sự kiện nhấn
        onTap: () {
          // BẤM VÀO ĐỂ MỞ MÀN HÌNH CHI TIẾT GIAO DỊCH
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                isIncome: isIncome,
                title: title,
                amount: amount,
                date: date,
                time: '14:30', // Tạm thời hardcode
                icon: icon,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isIncome
                    ? const Color(0xFF24A869)
                    : const Color(0xFFF95B51),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
