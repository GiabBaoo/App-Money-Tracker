import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/currency_format_utils.dart';
import '../providers/group_expense_providers.dart';
import '../../data/models/fund_transaction_model.dart';
import 'create_expense_screen.dart';
import 'invite_member_screen.dart';
import 'group_members_screen.dart';
import 'group_all_transactions_screen.dart';
import 'group_expense_statistics_screen.dart';

// Helper function để format tiền theo kiểu Việt (200000 -> 200.000đ)
String _formatMoney(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
}

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupStreamProvider(groupId));
    final expensesAsync = ref.watch(groupExpensesStreamProvider(groupId));
    final debtsAsync = ref.watch(groupDebtsProvider(groupId));
    final fundTransactionsAsync = ref.watch(groupFundTransactionsProvider(groupId));
    final balanceAsync = ref.watch(groupBalanceProvider(groupId));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Bạn đã rời khỏi nhóm hoặc không có quyền truy cập'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại'),
                  ),
                ],
              ),
            );
          }
          final groupIcon = group.iconCode != null ? IconData(group.iconCode as int, fontFamily: 'MaterialIcons') : Icons.group;
          final groupColor = CategoryUtils.getVibrantColor(group.name);
          final groupBgColor = CategoryUtils.getLightBgColor(group.name, isDark);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Header & Balance Card Stack
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Background & Title Area
                    Container(
                      height: 320,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            primaryColor.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Navigation & Stats button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 28),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => GroupExpenseStatisticsScreen(
                                            groupId: group.id,
                                            groupName: group.name,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Group Info
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(groupIcon, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => GroupMembersScreen(
                                                  groupId: group.id,
                                                  groupName: group.name,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            '${group.memberIds.length} thành viên • Chi tiết >',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Invite button
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InviteMemberScreen(
                                            groupId: group.id,
                                            groupName: group.name,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                                          SizedBox(width: 6),
                                          Text('Mời', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Balance Card (Floating)
                    Positioned(
                      bottom: -80,
                      left: 20,
                      right: 20,
                      child: expensesAsync.when(
                        data: (expenses) => fundTransactionsAsync.when(
                          data: (transactions) {
                            double income = 0;
                            double expense = 0;
                            for (var tx in transactions) {
                              if (tx.type == TransactionType.contribute) income += tx.amount;
                              else expense += tx.amount;
                            }
                            for (var e in expenses) expense += e.amount;
                            return _buildBalanceCard(context, ref, group, income, expense, isDark);
                          },
                          loading: () => const SizedBox(height: 150),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        loading: () => const SizedBox(height: 150),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 100), // Spacing for floating balance card

                // 2. Action Buttons (Góp quỹ, Rút quỹ)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Góp quỹ',
                          icon: Icons.add_rounded,
                          color: const Color(0xFFFF1493),
                          onPressed: () => _showContributeDialog(context, ref, groupId, group.name, group.iconCode),
                        ),
                      ),
                      if (ref.watch(currentUserIdProvider) == group.adminId) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Rút quỹ',
                            icon: Icons.arrow_outward_rounded,
                            color: primaryColor,
                            onPressed: () => _showWithdrawDialog(context, ref, groupId, group.name, group.iconCode, group.adminId),
                            isOutlined: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 12),

                // 4. Debts Section
                debtsAsync.when(
                  data: (debts) {
                    if (debts.isEmpty) return const SizedBox.shrink();
                    return _buildSectionHeader(
                      context,
                      title: 'Công nợ',
                      icon: Icons.compare_arrows_rounded,
                      iconColor: Colors.orange,
                      isDark: isDark,
                      child: Column(
                        children: debts.take(3).map((debt) => _buildDebtItem(debt, isDark)).toList(),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // 5. Recent Activity
                fundTransactionsAsync.when(
                  data: (transactions) {
                    return _buildSectionHeader(
                      context,
                      title: 'Hoạt động gần đây',
                      icon: Icons.history_rounded,
                      iconColor: primaryColor,
                      isDark: isDark,
                      onSeeAll: transactions.length > 10 ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupAllTransactionsScreen(groupId: groupId, groupName: group.name),
                          ),
                        );
                      } : null,
                      child: transactions.isEmpty 
                        ? _buildEmptyActivity(isDark)
                        : Column(
                            children: transactions.take(10).map((tx) => _buildTransactionItem(context, tx, isDark)).toList(),
                          ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi: $e')),
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildBalanceCard(BuildContext context, WidgetRef ref, dynamic group, double income, double expense, bool isDark) {
    final balance = income - expense;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2F2E) : const Color(0xFF2F7E79),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Số dư quỹ nhóm', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('${_formatMoney(balance)}đ', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
              // Thu nhập/Chi phí removed per user request
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onPressed, bool isOutlined = false}) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: color.withOpacity(0.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, {required String title, required IconData icon, required Color iconColor, required bool isDark, required Widget child, VoidCallback? onSeeAll}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (onSeeAll != null) ...[
                const Spacer(),
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('Tất cả >', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
      ],
    );
  }

  Widget _buildDebtItem(dynamic debt, bool isDark) {
    final isOwed = debt.amount > 0;
    final color = isOwed ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(isOwed ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOwed ? 'Bạn phải trả' : 'Bạn sẽ nhận', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text('${_formatMoney(debt.amount.abs())}đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, FundTransactionModel tx, bool isDark) {
    final isContribute = tx.type == TransactionType.contribute;
    final color = isContribute ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: () => _detailRefactorTransactionDetail(context, tx, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isContribute ? Icons.add_rounded : Icons.arrow_downward_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isContribute ? 'Góp quỹ' : 'Rút quỹ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(tx.userName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${isContribute ? '+' : '-'}${_formatMoney(tx.amount)}đ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${tx.createdAt.day}/${tx.createdAt.month} • ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 50, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Chưa có hoạt động nào', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- External Dialogs & Details (Preserved from old code) ---

  static void _showContributeDialog(BuildContext context, WidgetRef ref, String groupId, String groupName, int? groupIconCode) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFFF1493).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.people, size: 40, color: Color(0xFFFF1493))),
              const SizedBox(height: 20),
              Text('Góp Quỹ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(groupName, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF1493)),
                decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26), border: InputBorder.none),
              ),
              Divider(color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(hintText: 'Ghi chú (tùy chọn)', hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), filled: true, fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Hủy')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                        if (amount != null && amount > 0) {
                          final userId = ref.read(currentUserIdProvider);
                          final userNameAsync = await ref.read(currentUserNameProvider.future);
                          if (userId != null) {
                            await ref.read(fundTransactionRepositoryProvider).create(
                              groupId: groupId, userId: userId, userName: userNameAsync, amount: amount, type: TransactionType.contribute, groupName: groupName, groupIconCode: groupIconCode, notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1493), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Góp quỹ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  static void _showWithdrawDialog(BuildContext context, WidgetRef ref, String groupId, String groupName, int? groupIconCode, String adminId) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF2E2E2E) : Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF438883).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.people, size: 40, color: Color(0xFF438883))),
              const SizedBox(height: 20),
              Text('Rút Quỹ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(groupName, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF438883)),
                decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26), border: InputBorder.none),
              ),
              Divider(color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(hintText: 'Ghi chú (tùy chọn)', hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), filled: true, fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Hủy')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                        if (amount != null && amount > 0) {
                          final userId = ref.read(currentUserIdProvider);
                          final userNameAsync = await ref.read(currentUserNameProvider.future);
                          if (userId != null) {
                            await ref.read(fundTransactionRepositoryProvider).create(
                              groupId: groupId, userId: userId, userName: userNameAsync, amount: amount, type: TransactionType.withdraw, groupName: groupName, groupIconCode: groupIconCode, notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF438883), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Rút quỹ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _detailRefactorTransactionDetail(BuildContext context, FundTransactionModel transaction, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (transaction.type == TransactionType.contribute ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle), child: Icon(transaction.type == TransactionType.contribute ? Icons.add_rounded : Icons.arrow_downward_rounded, color: transaction.type == TransactionType.contribute ? Colors.green : Colors.red, size: 28)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.type == TransactionType.contribute ? 'Góp quỹ' : 'Rút quỹ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(transaction.userName, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('SỐ TIỀN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('${_formatMoney(transaction.amount)}đ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: transaction.type == TransactionType.contribute ? Colors.green : Colors.red)),
            const SizedBox(height: 24),
            const Text('THỜI GIAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year} • ${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Đóng'))),
          ],
        ),
      ),
    );
  }
}
