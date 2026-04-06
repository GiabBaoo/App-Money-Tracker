import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/voice_service.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import 'statistics_screen.dart';
import '../settings/profile_screen.dart';
import 'wallet_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import 'notification_screen.dart';
import '../../widgets/voice_input_bottom_sheet.dart';
import 'category_statistics_screen.dart';

import '../transaction/all_transactions_screen.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/transaction_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeBody(),
    const StatisticsScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ĐỊNH NGHĨA MÀU SẮC THEO YÊU CẦU ĐỒNG BỘ DARKMODE
    final Color activeColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF438883);
    final Color inactiveColor = isDark ? const Color(0xFF757575) : const Color(0xFF9E9E9E);
    final Color bottomBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _pages[_selectedIndex],
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, PageTransitions.slideUp(const AddTransactionScreen()));
          },
          backgroundColor: isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883),
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 36),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: bottomBarColor,
        elevation: 10,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // NHÓM BÊN TRÁI
              Row(
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Trang chủ', activeColor, inactiveColor),
                  _buildNavItem(1, Icons.bar_chart_rounded, 'Thống kê', activeColor, inactiveColor),
                ],
              ),
              // KHOẢNG TRỐNG CHO FAB
              const SizedBox(width: 40),
              // NHÓM BÊN PHẢI
              Row(
                children: [
                  _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Ví', activeColor, inactiveColor),
                  _buildNavItem(3, Icons.person_rounded, 'Tôi', activeColor, inactiveColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor, Color inactiveColor) {
    final bool isSelected = _selectedIndex == index;
    return MaterialButton(
      minWidth: 70, // Tăng width một chút cho thoải mái
      padding: EdgeInsets.zero,
      onPressed: () => setState(() => _selectedIndex = index),
      child: Center(
        child: Icon(
          icon,
          size: 32, // Tăng kích thước Icon lên 32 theo yêu cầu
          color: isSelected ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  final FirestoreService _firestoreService = FirestoreService();
  final VoiceService _voiceService = VoiceService();
  late Stream<List<TransactionModel>> _transactionStream;

  @override
  void initState() {
    super.initState();
    _transactionStream = _firestoreService.getTransactionsStream();
  }

  void _showVoiceInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceInputBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // PHẦN CỐ ĐỊNH: HEADER VÀ CARD SỐ DƯ
        Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chào buổi chiều,',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          StreamBuilder<UserModel?>(
                            stream: _firestoreService.getUserStream(),
                            builder: (context, snapshot) {
                              // Nếu chưa có cài đặt mic thì mặc định ẩn, nhưng theo yêu cầu này ta sẽ hiện mic luôn để test/sử dụng
                              // final micEnabled = snapshot.data?.dataUsage['microphone'] == true;
                              // if (!micEnabled) return const SizedBox(); 
                              
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.mic, color: Colors.white),
                                  onPressed: _showVoiceInput,
                                ),
                              );
                            }
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                              onPressed: () => Navigator.push(context, PageTransitions.slideRight(const NotificationScreen())),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // TỔNG SỐ DƯ CARD
                  StreamBuilder<List<TransactionModel>>(
                    stream: _transactionStream,
                    builder: (context, snapshot) {
                      double totalIncome = 0;
                      double totalExpense = 0;
                      if (snapshot.hasData) {
                        final now = DateTime.now();
                        for (var tx in snapshot.data!) {
                          // Chỉ tính cho tháng và năm hiện tại
                          if (tx.date.month == now.month && tx.date.year == now.year) {
                            if (tx.type == 'income') totalIncome += tx.amount;
                            else totalExpense += tx.amount;
                          }
                        }
                      }
                      return _buildBalanceCard(totalIncome, totalExpense);
                    }
                  ),
                ],
              ),
            ),
          ],
        ),

        // TIÊU ĐỀ LỊCH SỬ GIAO DỊCH (VẪN CỐ ĐỊNH)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lịch sử giao dịch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(context, PageTransitions.slideRight(const AllTransactionsScreen())),
                child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFF438883))),
              ),
            ],
          ),
        ),

        // PHẦN CUỘN ĐỘC LẬP: DANH SÁCH GIAO DỊCH
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: _transactionStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final now = DateTime.now();
              var transactions = (snapshot.data ?? [])
                  .where((tx) => tx.date.month == now.month && tx.date.year == now.year)
                  .toList();
              transactions.sort((a, b) {
                DateTime dateA = DateTime(a.date.year, a.date.month, a.date.day);
                DateTime dateB = DateTime(b.date.year, b.date.month, b.date.day);
                int dateCompare = dateB.compareTo(dateA);
                if (dateCompare != 0) return dateCompare;
                int timeCompare = b.time.compareTo(a.time);
                if (timeCompare != 0) return timeCompare;
                return b.createdAt.compareTo(a.createdAt);
              });
              final displayTransactions = transactions.take(10).toList();
              
              if (displayTransactions.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('Chưa có giao dịch trong tháng này'),
                ));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                itemCount: displayTransactions.length,
                itemBuilder: (context, index) {
                  return TransactionItem(
                    transaction: displayTransactions[index],
                    showDate: true,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(double income, double expense) {
    final balance = income - expense;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageTransitions.slideRight(const CategoryStatisticsScreen(type: 'expense')),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2F7E79),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF438883).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng số dư', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(CurrencyUtils.formatCurrency(balance),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBalanceInfo(Icons.arrow_downward, 'Thu nhập', income, 'income'),
                _buildBalanceInfo(Icons.arrow_upward, 'Chi phí', expense, 'expense'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(IconData icon, String label, double amount, String type) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageTransitions.slideRight(CategoryStatisticsScreen(type: type)),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(CurrencyUtils.formatCurrency(amount),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}