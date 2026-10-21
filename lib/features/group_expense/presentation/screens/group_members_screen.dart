import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_dialog.dart';
import '../../../../widgets/mono_toast.dart';
import '../providers/group_expense_providers.dart';

class GroupMembersScreen extends ConsumerWidget {
  final String groupId;
  final String groupName;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupStreamProvider(groupId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final currentUserId = ref.watch(currentUserIdProvider);

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
                          isVi ? 'Thành Viên' : 'Group Members',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          groupName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── MEMBERS LIST ───
            Expanded(
              child: groupAsync.when(
                data: (group) {
                  if (group == null) {
                    return Center(
                      child: Text(
                        isVi ? 'Không tìm thấy dữ liệu nhóm' : 'Group data not found',
                        style: TextStyle(color: textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: group.memberIds.length,
                    itemBuilder: (context, index) {
                      final memberId = group.memberIds[index];
                      final isOwner = group.adminId == memberId;
                      final isCurrentUser = currentUserId == memberId;
                      return _buildMemberItem(
                        context,
                        ref,
                        memberId,
                        isOwner,
                        isDark,
                        groupId,
                        group.adminId,
                        isCurrentUser,
                        group.memberIds.length,
                        cardBgColor,
                        textPrimary,
                        textSecondary,
                        borderColor,
                        primaryColor,
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                  ),
                ),
                error: (error, _) => Center(
                  child: Text(
                    '${isVi ? 'Lỗi' : 'Error'}: $error',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(
    BuildContext context,
    WidgetRef ref,
    String memberId,
    bool isOwner,
    bool isDark,
    String groupId,
    String adminId,
    bool isCurrentUser,
    int totalMembers,
    Color cardBgColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    Color primaryColor,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final name = userData['name'] as String? ?? (isVi ? 'Người dùng' : 'User');
        final email = userData['email'] as String? ?? '';
        final phone = userData['phone'] as String? ?? '';
        final avatarUrl = userData['avatarUrl'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.15),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Text(
                            isVi ? '(Bạn)' : '(You)',
                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 12, color: Colors.amber[700]),
                                const SizedBox(width: 2),
                                Text(
                                  isVi ? 'Chủ quỹ' : 'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 13, color: textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 13, color: textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            phone,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Popup
              if (isCurrentUser && !isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'leave') {
                      _showLeaveConfirmDialog(context, ref, groupId, name);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'leave',
                      child: Row(
                        children: [
                          const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(isVi ? 'Rời nhóm' : 'Leave Group', style: const TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textSecondary.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.more_vert, color: textSecondary, size: 18),
                  ),
                )
              else if (!isCurrentUser && ref.watch(currentUserIdProvider) == adminId && !isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') {
                      _showRemoveConfirmDialog(context, ref, groupId, memberId, name);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: [
                          const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(isVi ? 'Xóa khỏi nhóm' : 'Remove from Group', style: const TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textSecondary.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.more_vert, color: textSecondary, size: 18),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static void _showLeaveConfirmDialog(BuildContext context, WidgetRef ref, String groupId, String memberName) async {
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Rời Nhóm' : 'Leave Group',
      message: isVi
          ? 'Bạn có chắc muốn rời nhóm này không? Bạn sẽ không thể xem các giao dịch cũ và sẽ cần được mời lại để tham gia.'
          : 'Are you sure you want to leave this group? You will not be able to view old transactions and will need to be re-invited to join.',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Rời nhóm' : 'Leave Group',
      isDestructive: true,
      icon: Icons.exit_to_app_rounded,
    );

    if (confirmed == true && context.mounted) {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        try {
          await ref.read(groupServiceProvider).removeMember(
            groupId,
            currentUserId,
            currentUserId,
          );
          if (context.mounted) {
            Navigator.pop(context);
            MonoToast.success(
              context,
              isVi ? 'Đã rời khỏi nhóm' : 'Left the group successfully',
            );
          }
        } catch (e) {
          if (context.mounted) {
            MonoToast.error(
              context,
              '${isVi ? 'Lỗi' : 'Error'}: $e',
            );
          }
        }
      }
    }
  }

  static void _showRemoveConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String memberId,
    String memberName,
  ) async {
    final confirmed = await MonoDialog.confirm(
      context,
      title: isVi ? 'Xóa Thành Viên' : 'Remove Member',
      message: isVi
          ? 'Bạn có chắc muốn xóa $memberName khỏi nhóm không?'
          : 'Are you sure you want to remove $memberName from the group?',
      cancelText: isVi ? 'Hủy' : 'Cancel',
      confirmText: isVi ? 'Xóa' : 'Remove',
      isDestructive: true,
      icon: Icons.person_remove_rounded,
    );

    if (confirmed == true && context.mounted) {
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        try {
          await ref.read(groupServiceProvider).removeMember(
            groupId,
            memberId,
            currentUserId,
          );
          if (context.mounted) {
            MonoToast.success(
              context,
              isVi ? 'Đã xóa $memberName khỏi nhóm' : 'Removed $memberName from group',
            );
          }
        } catch (e) {
          if (context.mounted) {
            MonoToast.error(
              context,
              '${isVi ? 'Lỗi' : 'Error'}: $e',
            );
          }
        }
      }
    }
  }
}
