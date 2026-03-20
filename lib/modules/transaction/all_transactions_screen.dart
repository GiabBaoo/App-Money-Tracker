import 'package:flutter/material.dart';
import '../transaction/transaction_detail_screen.dart'; // Đảm bảo đường dẫn tới file chi tiết giao dịch đúng

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                      color: Color(0xFF222222),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Lịch sử giao dịch',
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Nút Bộ Lọc (Filter) hoặc Tìm kiếm
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list,
                      color: Color(0xFF222222),
                      size: 24,
                    ),
                    onPressed: () {
                      // Xử lý mở bộ lọc sau
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 2. DANH SÁCH GIAO DỊCH (Có thể cuộn)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- NHÓM 1: HÔM NAY ---
                    _buildDateHeader('Hôm nay'),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.computer,
                      title: 'Tiền lương Livestream',
                      date: 'Hôm nay',
                      amount: '+ 22.286.956đ',
                      isIncome: true,
                    ),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.fastfood,
                      title: 'Ăn trưa',
                      date: 'Hôm nay',
                      amount: '- 55.000đ',
                      isIncome: false,
                    ),

                    const SizedBox(height: 16),

                    // --- NHÓM 2: HÔM QUA ---
                    _buildDateHeader('Hôm qua'),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.swap_horiz,
                      title: 'Chuyển khoản',
                      date: 'Hôm qua',
                      amount: '- 2.228.695đ',
                      isIncome: false,
                    ),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.shopping_bag,
                      title: 'Siêu thị mini',
                      date: 'Hôm qua',
                      amount: '- 450.000đ',
                      isIncome: false,
                    ),

                    const SizedBox(height: 16),

                    // --- NHÓM 3: THÁNG TRƯỚC ---
                    _buildDateHeader('Tháng 1, 2025'),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.two_wheeler,
                      title: 'Đổ xăng Wave RSX',
                      date: '30 Thg 1, 2025',
                      amount: '- 80.000đ',
                      isIncome: false,
                    ),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.play_arrow,
                      title: 'Youtube Premium',
                      date: '16 Thg 1, 2025',
                      amount: '- 314.639đ',
                      isIncome: false,
                    ),
                    _buildTransactionItem(
                      context: context,
                      icon: Icons.work,
                      title: 'Dự án Freelance',
                      date: '10 Thg 1, 2025',
                      amount: '+ 15.000.000đ',
                      isIncome: true,
                    ),

                    const SizedBox(height: 40), // Đệm dưới cùng
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM TẠO TIÊU ĐỀ NGÀY THÁNG ---
  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        date,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- HÀM TẠO DÒNG GIAO DỊCH (Tái sử dụng giao diện) ---
  Widget _buildTransactionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                isIncome: isIncome,
                title: title,
                amount: amount,
                date: date,
                time: '14:30', // Demo time
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
              child: Icon(icon, color: const Color(0xFF438883), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
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
