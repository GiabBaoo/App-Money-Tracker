import 'package:flutter/material.dart';
import 'statistics_screen.dart'; // Import trang thống kê
import '../settings/profile_screen.dart'; // Import trang hồ sơ
import 'wallet_screen.dart'; // Import trang ví
import '../transaction/add_transaction_screen.dart'; // Import trang thêm giao dịch
import '../transaction/transaction_detail_screen.dart'; // Import trang chi tiết giao dịch
import 'notification_screen.dart'; // Import trang thông báo
import '../transaction/all_transactions_screen.dart'; // Đảm bảo import đúng trang bạn vừa tạo

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Biến quản lý tab hiện tại của thanh điều hướng
  int _selectedIndex = 0;

  // DANH SÁCH CÁC TRANG ĐỂ TRÁO ĐỔI
  final List<Widget> _pages = [
    const HomeBody(), // Index 0: Phần ruột Trang Chủ
    const StatisticsScreen(), // Index 1: Trang Thống Kê
    const WalletScreen(), // Index 2: Trang Ví
    const ProfileScreen(), // Index 3: Trang Hồ sơ
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ĐIỂM QUAN TRỌNG NHẤT LÀ ĐÂY: body thay đổi dựa theo nút được bấm
      body: _pages[_selectedIndex],

      // THANH ĐIỀU HƯỚNG NỔI
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: () {
            // Chuyển sang màn hình Thêm giao dịch
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddTransactionScreen(),
              ),
            );
          },
          backgroundColor: const Color(0xFF438883),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 36),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // THANH ĐIỀU HƯỚNG DƯỚI ĐÁY
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 75,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MaterialButton(
                    minWidth: 50,
                    onPressed: () => setState(() => _selectedIndex = 0),
                    child: Icon(
                      Icons.home_filled,
                      size: 32,
                      color: _selectedIndex == 0
                          ? const Color(0xFF438883)
                          : Colors.grey,
                    ),
                  ),
                  MaterialButton(
                    minWidth: 50,
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: Icon(
                      Icons.bar_chart,
                      size: 32,
                      color: _selectedIndex == 1
                          ? const Color(0xFF438883)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MaterialButton(
                    minWidth: 50,
                    onPressed: () => setState(() => _selectedIndex = 2),
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 32,
                      color: _selectedIndex == 2
                          ? const Color(0xFF438883)
                          : Colors.grey,
                    ),
                  ),
                  MaterialButton(
                    minWidth: 50,
                    onPressed: () => setState(() => _selectedIndex = 3),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: _selectedIndex == 3
                          ? const Color(0xFF438883)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// WIDGET HOME BODY: Chứa giao diện cũ của trang chủ
// ======================================================================
class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Nền xanh có bo góc cong ở dưới
        Container(
          height: 280,
          decoration: const BoxDecoration(
            color: Color(0xFF438883),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),

        // Nội dung chính có thể cuộn được
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context), // Truyền context vào đây
                const SizedBox(height: 20),
                _buildBalanceCard(),
                const SizedBox(height: 30),
                _buildTransactionHistory(context), // Truyền context vào đây
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Nhận context để chuyển sang trang Thông báo
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chào buổi chiều',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Lê Trung Cao',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Bọc chuông bằng GestureDetector
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7E78),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7E78).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Tổng số dư',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '66.808.429 đ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Thu nhập',
                        style: TextStyle(
                          color: Color(0xFFD0E5E3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '48.244.705 đ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Chi phí',
                        style: TextStyle(
                          color: Color(0xFFD0E5E3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '7.446.465 đ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lịch sử giao dịch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),

              // ĐÃ BỔ SUNG LỆNH CHUYỂN TRANG Ở ĐÂY
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTransactionsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ... Các hàm _transactionItem bên dưới giữ nguyên
        ],
      ),
    );
  }

  Widget _transactionItem({
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
        // Bọc InkWell để bấm được giống bên trang Ví
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(
                isIncome: isIncome,
                title: title,
                amount: amount,
                date: date,
                time: '14:30',
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
