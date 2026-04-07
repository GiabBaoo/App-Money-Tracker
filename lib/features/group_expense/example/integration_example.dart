/// Integration Example for Group Expense Management Feature
/// 
/// This file shows how to integrate the Group Expense feature into your main app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/group_list_screen.dart';

/// Example 1: Add to Navigation Drawer
class MainAppWithDrawer extends StatelessWidget {
  const MainAppWithDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Money Tracker')),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text(
                'Money Tracker',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Trang chủ'),
              onTap: () {
                // Navigate to home
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Ví của tôi'),
              onTap: () {
                // Navigate to wallet
              },
            ),
            // GROUP EXPENSE FEATURE INTEGRATION
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Chi tiêu nhóm'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Cài đặt'),
              onTap: () {
                // Navigate to settings
              },
            ),
          ],
        ),
      ),
      body: const Center(child: Text('Main App Content')),
    );
  }
}

/// Example 2: Add to Bottom Navigation Bar
class MainAppWithBottomNav extends StatefulWidget {
  const MainAppWithBottomNav({super.key});

  @override
  State<MainAppWithBottomNav> createState() => _MainAppWithBottomNavState();
}

class _MainAppWithBottomNavState extends State<MainAppWithBottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text('Home Screen')),
    const Center(child: Text('Wallet Screen')),
    const GroupListScreen(), // GROUP EXPENSE FEATURE
    const Center(child: Text('Profile Screen')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Ví',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Nhóm', // GROUP EXPENSE
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

/// Example 3: Add as Card on Home Screen
class HomeScreenWithGroupExpense extends StatelessWidget {
  const HomeScreenWithGroupExpense({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Money Tracker')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Ví của tôi',
            color: Colors.blue,
            onTap: () {
              // Navigate to wallet
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.receipt_long,
            title: 'Giao dịch',
            color: Colors.green,
            onTap: () {
              // Navigate to transactions
            },
          ),
          // GROUP EXPENSE FEATURE CARD
          _buildFeatureCard(
            context,
            icon: Icons.group,
            title: 'Chi tiêu nhóm',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupListScreen(),
                ),
              );
            },
          ),
          _buildFeatureCard(
            context,
            icon: Icons.bar_chart,
            title: 'Thống kê',
            color: Colors.orange,
            onTap: () {
              // Navigate to statistics
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example 4: Complete Main App Setup
class CompleteAppExample extends StatelessWidget {
  const CompleteAppExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'Money Tracker',
        debugShowCheckedModeBanner: false,
        home: MainAppWithBottomNav(),
      ),
    );
  }
}

/// Example 5: Direct Navigation from Any Screen
void navigateToGroupExpense(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const GroupListScreen(),
    ),
  );
}

/// Example 6: Using as Modal Bottom Sheet
void showGroupExpenseModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SizedBox(
      height: 600,
      child: GroupListScreen(),
    ),
  );
}

/// Example 7: Using with Named Routes
class AppWithNamedRoutes extends StatelessWidget {
  const AppWithNamedRoutes({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Money Tracker',
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreenWithGroupExpense(),
          '/group-expense': (context) => const GroupListScreen(),
        },
      ),
    );
  }
}

// Navigate using named route:
// Navigator.pushNamed(context, '/group-expense');

/// Example 8: Checking User Authentication Before Access
void navigateToGroupExpenseWithAuth(BuildContext context, WidgetRef ref) {
  // Assuming you have an auth provider
  // final user = ref.read(firebaseAuthProvider).currentUser;
  
  // if (user == null) {
  //   // Show login screen
  //   Navigator.pushNamed(context, '/login');
  // } else {
  //   // Navigate to group expense
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => const GroupListScreen(),
  //     ),
  //   );
  // }
}

/// Example 9: Deep Link to Specific Group
void navigateToSpecificGroup(BuildContext context, String groupId) {
  // Import the screen first:
  // import '../presentation/screens/group_detail_screen.dart';
  
  // Navigator.push(
  //   context,
  //   MaterialPageRoute(
  //     builder: (context) => GroupDetailScreen(groupId: groupId),
  //   ),
  // );
}

/// Example 10: Using with GetX or other navigation packages
// For GetX:
// Get.to(() => const GroupListScreen());

// For go_router:
// context.go('/group-expense');

/// RECOMMENDED INTEGRATION:
/// 
/// 1. Add to your main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   runApp(const ProviderScope(child: MyApp()));
/// }
/// ```
/// 
/// 2. Add navigation option in your home screen or drawer
/// 
/// 3. Ensure Firebase Auth is configured and user is logged in
/// 
/// 4. Test the complete flow!
