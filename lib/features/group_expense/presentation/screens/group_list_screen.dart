import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/group_expense_providers.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

// Helper function để format tiền theo kiểu Việt (200000 -> 200.000đ)
String _formatMoney(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
}

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Quỹ Nhóm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: groupsAsync.when(
                  data: (groups) => _buildContent(context, ref, groups, isDark, primaryColor),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('Lỗi: $error'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List groups, bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exclusive Feature Banner
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative circle background
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TÍNH NĂNG ĐẶC BIỆT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Title with icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Một quỹ, một',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const Text(
                                'việc',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Decorative icon circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    const Text(
                      'Quản lý tài chính hợp tác cho mục tiêu chung. Xây dựng tương lai cùng nhau với độ chính xác và dễ dàng.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Create Fund Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateGroupScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(
                        Icons.add_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      label: Text(
                        'Tạo Quỹ',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Groups list
          Text(
            'Quỹ của tôi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (groups.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 80,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có quỹ nào',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo quỹ mới để bắt đầu!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...groups.map((group) => _buildGroupCard(context, ref, group, isDark)),
        ],
      ),
    );
  }



  Widget _buildGroupCard(BuildContext context, WidgetRef ref, dynamic group, bool isDark) {
    final gradients = [
      [const Color(0xFFFFF4E6), const Color(0xFFFFE4CC)], // Orange
      [const Color(0xFFE8F5FF), const Color(0xFFD0EBFF)], // Blue
      [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)], // Purple
      [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)], // Green
    ];
    
    final gradient = gradients[group.name.hashCode % gradients.length];
    final balanceAsync = ref.watch(groupBalanceProvider(group.id));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : null,
        gradient: isDark 
            ? null 
            : LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(groupId: group.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chủ quỹ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  group.description ?? '${group.memberIds.length} thành viên',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  'Tạo ngày ${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year} lúc ${group.createdAt.hour.toString().padLeft(2, '0')}:${group.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black38,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          balanceAsync.when(
                            data: (balance) => Text(
                              '${_formatMoney(balance)}đ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            loading: () => const Text(
                              '...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            error: (_, __) => const Text(
                              '0đ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    if (ref.watch(currentUserIdProvider) == group.adminId)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _deleteGroup(context, ref, group.id, group.name),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref, String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa quỹ'),
        content: Text('Bạn có chắc chắn muốn xóa quỹ "$groupName" không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final groupRepository = ref.read(groupRepositoryProvider);
        await groupRepository.delete(groupId);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa quỹ "$groupName"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa quỹ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


}
