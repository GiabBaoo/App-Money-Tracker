import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_dialog.dart';
import '../../../../widgets/mono_toast.dart';
import '../providers/group_expense_providers.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import '../../../../utils/page_transitions.dart';

// Helper function để format tiền theo kiểu Việt (200000 -> 200.000)
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

    // Design Tokens
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── ERGONOMIC TOP APP BAR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBgColor,
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Quỹ Nhóm' : 'Group Funds',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          isVi ? 'Quản lý thu chi & mục tiêu chung' : 'Collaborative expense & fund tracker',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Group Counter Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        groupsAsync.when(
                          data: (groups) => Text(
                            '${groups.length}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => Text(
                            '•',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── MAIN CONTENT ───
            Expanded(
              child: groupsAsync.when(
                data: (groups) => _buildContent(
                  context,
                  ref,
                  groups,
                  isDark,
                  primaryColor,
                  cardBgColor,
                  textPrimary,
                  textSecondary,
                  borderColor,
                ),
                loading: () => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${isVi ? 'Không thể tải dữ liệu' : 'Could not load data'}: $error',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // ─── ERGONOMIC THUMB-FRIENDLY BOTTOM ACTION BAR ───
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AnimatedScaleButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                PageTransitions.slideUp(const CreateGroupScreen()),
              );
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isVi ? 'Tạo Quỹ Mới' : 'Create New Fund',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List groups,
    bool isDark,
    Color primaryColor,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final ownedCount = groups.where((g) => g.adminId == currentUserId).length;
    final memberCount = groups.length - ownedCount;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. TOP SUMMARY CARD (Airy, Ergonomic, Clean) ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E293B),
                        const Color(0xFF182334),
                      ]
                    : [
                        primaryColor,
                        Color.lerp(primaryColor, Colors.black, 0.15) ?? primaryColor,
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : primaryColor).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.savings_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVi ? 'TỔNG QUAN QUỸ NHÓM' : 'GROUP FUNDS OVERVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isVi ? '${groups.length} Quỹ' : '${groups.length} Funds',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Highlights
                Text(
                  isVi ? 'Không gian tài chính minh bạch' : 'Transparent collective finance',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isVi
                      ? 'Góp quỹ, chi tiêu và theo dõi phân chia công nợ tự động cùng bạn bè, đối tác.'
                      : 'Contribute, spend and track debts with friends and teammates seamlessly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Mini metric pills
                Row(
                  children: [
                    _buildSummaryPill(
                      icon: Icons.star_rounded,
                      label: isVi ? 'Quỹ sở hữu' : 'Admin of',
                      value: '$ownedCount',
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryPill(
                      icon: Icons.people_outline_rounded,
                      label: isVi ? 'Tham gia' : 'Member in',
                      value: '$memberCount',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─── 2. SECTION HEADER ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Danh Sách Quỹ Của Tôi' : 'My Funds List',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              if (groups.isNotEmpty)
                Text(
                  '${groups.length} ${isVi ? 'quỹ' : 'funds'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── 3. GROUPS LIST OR EMPTY STATE ───
          if (groups.isEmpty)
            _buildEmptyState(context, isDark, primaryColor, cardBgColor, textPrimary, textSecondary, borderColor)
          else
            ...groups.map((group) => _buildGroupCard(
                  context,
                  ref,
                  group,
                  isDark,
                  primaryColor,
                  cardBgColor,
                  textPrimary,
                  textSecondary,
                  borderColor,
                )),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isVi ? 'Chưa có quỹ nào' : 'No funds yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isVi
                ? 'Tạo quỹ mới để bắt đầu quản lý chi tiêu nhóm, ăn uống, du lịch cùng bạn bè.'
                : 'Create a new fund to start tracking group expenses with friends and family.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                PageTransitions.slideUp(const CreateGroupScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2DD4BF).withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVi ? 'Tạo quỹ ngay' : 'Create Fund Now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    WidgetRef ref,
    dynamic group,
    bool isDark,
    Color primaryColor,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final balanceAsync = ref.watch(groupBalanceProvider(group.id));
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwner = currentUserId == group.adminId;

    // Pick a subtle theme icon & color for the group
    final iconData = group.iconCode != null
        ? IconData(group.iconCode, fontFamily: 'MaterialIcons')
        : Icons.groups_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              PageTransitions.slideRight(GroupDetailScreen(groupId: group.id)),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Group Top Row (Icon, Name, Owner Badge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconData,
                        size: 22,
                        color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            group.description ?? (isVi ? '${group.memberIds.length} thành viên' : '${group.memberIds.length} members'),
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isOwner
                            ? Colors.amber.withValues(alpha: isDark ? 0.18 : 0.12)
                            : Colors.blue.withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOwner
                              ? Colors.amber.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOwner ? Icons.star_rounded : Icons.person_rounded,
                            size: 13,
                            color: isOwner ? Colors.amber[800] ?? Colors.amber : Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwner ? (isVi ? 'Chủ quỹ' : 'Admin') : (isVi ? 'Thành viên' : 'Member'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isOwner ? (isDark ? Colors.amber[300] : Colors.amber[900]) : (isDark ? Colors.blue[300] : Colors.blue[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 14),

                // 2. Group Bottom Row (Balance & Delete Action)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Số dư quỹ' : 'Current Balance',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        balanceAsync.when(
                          data: (balance) => Text(
                            '${_formatMoney(balance)}đ',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          loading: () => Text(
                            '...',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          error: (_, _) => Text(
                            '0đ',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        // Members count indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_outlined, size: 14, color: textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${group.memberIds.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          AnimatedScaleButton(
                            onTap: () => _deleteGroup(context, ref, group.id, group.name),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ],
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
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Xóa quỹ' : 'Delete fund',
      message: isVi
          ? 'Bạn có chắc chắn muốn xóa quỹ "$groupName" không? Hành động này không thể hoàn tác.'
          : 'Are you sure you want to delete fund "$groupName"? This action cannot be undone.',
      confirmText: isVi ? 'Xóa' : 'Delete',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed == true) {
      try {
        final groupRepository = ref.read(groupRepositoryProvider);
        await groupRepository.delete(groupId);

        if (context.mounted) {
          MonoToast.success(
            context,
            isVi ? 'Đã xóa quỹ "$groupName"' : 'Deleted fund "$groupName"',
          );
        }
      } catch (e) {
        if (context.mounted) {
          MonoToast.error(
            context,
            isVi ? 'Lỗi khi xóa quỹ: $e' : 'Error deleting fund: $e',
          );
        }
      }
    }
  }
}
