import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import 'statistics_screen.dart';
import '../settings/profile_screen.dart';
import 'wallet_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import 'notification_screen.dart';
import '../transaction/all_transactions_screen.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
      floatingActionButton: SizedBox(
        width: 65,
        height: 65,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(context, PageTransitions.slideUp(const AddTransactionScreen()));
          },
          backgroundColor: const Color(0xFF438883),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 36),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 75,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                MaterialButton(minWidth: 50, onPressed: () => setState(() => _selectedIndex = 0), child: Icon(Icons.home_filled, size: 32, color: _selectedIndex == 0 ? const Color(0xFF438883) : Colors.grey)),
                MaterialButton(minWidth: 50, onPressed: () => setState(() => _selectedIndex = 1), child: Icon(Icons.bar_chart, size: 32, color: _selectedIndex == 1 ? const Color(0xFF438883) : Colors.grey)),
              ]),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                MaterialButton(minWidth: 50, onPressed: () => setState(() => _selectedIndex = 2), child: Icon(Icons.account_balance_wallet, size: 32, color: _selectedIndex == 2 ? const Color(0xFF438883) : Colors.grey)),
                MaterialButton(minWidth: 50, onPressed: () => setState(() => _selectedIndex = 3), child: Icon(Icons.person, size: 32, color: _selectedIndex == 3 ? const Color(0xFF438883) : Colors.grey)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  static String formatCurrency(double amount) {
    String text = amount.toStringAsFixed(0);
    String result = '';
    int count = 0;
    for (int i = text.length - 1; i >= 0; i--) {
      count++;
      result = text[i] + result;
      if (count % 3 == 0 && i > 0) {
        result = '.$result';
      }
    }
    return '$result đ';
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Hôm nay';
    if (dateOnly == yesterday) return 'Hôm qua';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return Stack(
      children: [
        Container(
          height: 280,
          decoration: const BoxDecoration(
            color: Color(0xFF438883),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                StreamBuilder<UserModel?>(
                  stream: authService.getUserProfileStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final greeting = _getGreeting();
                    final name = user?.name ?? 'Người dùng';
                    return _buildHeader(context, greeting, name);
                  },
                ),
                const SizedBox(height: 20),
                StreamBuilder<({double balance, double totalIncome, double totalExpense})>(
                  stream: firestoreService.getBalanceStream(),
                  builder: (context, snapshot) {
                    final balance = snapshot.data?.balance ?? 0;
                    final income = snapshot.data?.totalIncome ?? 0;
                    final expense = snapshot.data?.totalExpense ?? 0;
                    return _buildBalanceCard(balance, income, expense);
                  },
                ),
                const SizedBox(height: 30),
                StreamBuilder<List<TransactionModel>>(
                  stream: firestoreService.getTransactionsStream(limit: 5),
                  builder: (context, snapshot) {
                    final transactions = snapshot.data ?? [];
                    return _buildTransactionHistory(context, transactions);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  Widget _buildHeader(BuildContext context, String greeting, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ]),
          GestureDetector(
            onTap: () => Navigator.push(context, PageTransitions.slideRight(const NotificationScreen())),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double income, double expense) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7E78),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7E78).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
            Text('Tổng số dư', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            Icon(Icons.more_horiz, color: Colors.white),
          ]),
          const SizedBox(height: 8),
          Text(formatCurrency(balance), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIncomeExpenseColumn('Thu nhập', formatCurrency(income), Icons.arrow_downward),
              _buildIncomeExpenseColumn('Chi phí', formatCurrency(expense), Icons.arrow_upward),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseColumn(String label, String amount, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFFD0E5E3), fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTransactionHistory(BuildContext context, List<TransactionModel> transactions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
            GestureDetector(
              onTap: () => Navigator.push(context, PageTransitions.slideRight(const AllTransactionsScreen())),
              child: const Text('Xem tất cả', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
            ),
          ]),
          const SizedBox(height: 20),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Chưa có giao dịch nào', style: TextStyle(color: Color(0xFF999999), fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Bấm nút + để thêm giao dịch đầu tiên', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14)),
              ]),
            )
          else
            ...transactions.map((tx) => _transactionItem(
                  context: context,
                  icon: tx.icon,
                  title: tx.category,
                  date: formatDate(tx.date),
                  amount: '${tx.isIncome ? "+" : "-"} ${formatCurrency(tx.amount)}',
                  isIncome: tx.isIncome,
                  transaction: tx,
                )),
          const SizedBox(height: 100),
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
    required TransactionModel transaction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              PageTransitions.slideRight(TransactionDetailScreen(
                        isIncome: isIncome,
                        title: title,
                        amount: amount,
                        date: date,
                        time: transaction.time,
                        icon: icon,
                      )));
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: const Color(0xFFF0F6F5), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF438883), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
            ])),
            Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF24A869) : const Color(0xFFF95B51))),
          ],
        ),
      ),
    );
  }
}