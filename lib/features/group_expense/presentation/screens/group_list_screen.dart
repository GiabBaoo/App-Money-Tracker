import '../../../../core/theme/app_theme.dart';
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
    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;

    // Design Tokens
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBgColor = context.cardBg;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;
    final borderColor = context.borderColor;

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
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          isVi ? 'Quản lý thu chi & mục tiêu chung' : 'Collaborative expense & fund tracker',
                          style: context.textTheme.bodySmall?.copyWith(
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
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        groupsAsync.when(
                          data: (groups) => Text(
                            '${groups.length}',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => Text(
                            '•',
                            style: TextStyle(
                              color: primaryColor,
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
                    color: primaryColor,
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
                          color: context.expense.withValues(alpha: 0.8),
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
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppShadows.glow(primaryColor, alpha: 0.35),
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
                    style: context.textTheme.titleMedium?.copyWith(
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
                        AppColors.surfaceElevatedDark,
                        AppColors.surfaceDark,
                      ]
                    : [
                        primaryColor,
                        Color.lerp(primaryColor, Colors.black, 0.15) ?? primaryColor,
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isVi ? 'Chưa có quỹ nào' : 'No funds yet',
            style: context.textTheme.titleMedium?.copyWith(
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
            style: context.textTheme.bodyMedium?.copyWith(
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
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVi ? 'Tạo quỹ ngay' : 'Create Fund Now',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: AppShadows.card(isDark),
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
          borderRadius: BorderRadius.circular(18),
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
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconData,
                        size: 22,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: context.textTheme.titleMedium?.copyWith(
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
                            style: context.textTheme.bodySmall?.copyWith(
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
                            ? context.warning.withValues(alpha: isDark ? 0.18 : 0.12)
                            : context.info.withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOwner
                              ? context.warning.withValues(alpha: 0.3)
                              : context.info.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOwner ? Icons.star_rounded : Icons.person_rounded,
                            size: 13,
                            color: isOwner ? context.warning : context.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOwner ? (isVi ? 'Chủ quỹ' : 'Admin') : (isVi ? 'Thành viên' : 'Member'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isOwner ? context.warning : context.info,
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
                          style: context.textTheme.labelMedium?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        balanceAsync.when(
                          data: (balance) => Text(
                            '${_formatMoney(balance)}đ',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: primaryColor,
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
                                color: context.expense.withValues(alpha: isDark ? 0.15 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: context.expense,
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
