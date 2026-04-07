import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/group_list_screen.dart';

/// Demo app for Group Expense Management Feature
/// 
/// This demonstrates the complete flow:
/// 1. Create Group
/// 2. Add Expense
/// 3. View Debts
/// 4. Settlement
/// 
/// To run this demo:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   runApp(const GroupExpenseDemo());
/// }
/// ```
class GroupExpenseDemo extends StatelessWidget {
  const GroupExpenseDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'Group Expense Demo',
        debugShowCheckedModeBanner: false,
        home: GroupExpenseDemoHome(),
      ),
    );
  }
}

class GroupExpenseDemoHome extends StatelessWidget {
  const GroupExpenseDemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Expense Management Demo'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.group,
                size: 100,
                color: Colors.teal,
              ),
              const SizedBox(height: 24),
              const Text(
                'Quản Lý Chi Tiêu Nhóm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tạo nhóm, thêm chi tiêu, xem công nợ và thanh toán',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 48),
              _buildFeatureCard(
                icon: Icons.group_add,
                title: 'Tạo Nhóm',
                description: 'Tạo nhóm chi tiêu với bạn bè',
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                icon: Icons.receipt_long,
                title: 'Thêm Chi Tiêu',
                description: 'Ghi lại chi tiêu và chia đều',
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                icon: Icons.account_balance_wallet,
                title: 'Xem Công Nợ',
                description: 'Tự động tính toán ai nợ ai',
              ),
              const SizedBox(height: 16),
              _buildFeatureCard(
                icon: Icons.payment,
                title: 'Thanh Toán',
                description: 'Xác nhận thanh toán dễ dàng',
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GroupListScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Bắt Đầu',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.teal),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
      ),
    );
  }
}

/// Example usage in existing app:
/// 
/// ```dart
/// // In your main navigation or home screen
/// ListTile(
///   leading: const Icon(Icons.group),
///   title: const Text('Chi tiêu nhóm'),
///   onTap: () {
///     Navigator.push(
///       context,
///       MaterialPageRoute(
///         builder: (context) => const GroupListScreen(),
///       ),
///     );
///   },
/// )
/// ```
