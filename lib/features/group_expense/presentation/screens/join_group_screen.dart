import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_toast.dart';
import '../providers/group_expense_providers.dart';
import '../../../../models/notification_model.dart';
import 'group_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../utils/page_transitions.dart';
import '../../../../utils/category_utils.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? notificationId;

  const JoinGroupScreen({
    super.key,
    required this.groupId,
    this.notificationId,
  });

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  bool _isJoining = false;
  bool _isRejecting = false;
  bool _isAccepted = false;
  bool _isRejected = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Delay nhỏ để đợi Firebase Auth cập nhật sau khi login
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkUserAuth();
        _checkNotificationStatus();
      }
    });
  }

  Future<void> _checkNotificationStatus() async {
    if (widget.notificationId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.notificationId)
          .get();

      if (doc.exists && mounted) {
        final status = doc.get('status') as String?;
        if (status == 'accepted') {
          setState(() => _isAccepted = true);
        } else if (status == 'rejected') {
          setState(() => _isRejected = true);
        }
      }
    } catch (e) {
      debugPrint('Error checking notification status: $e');
    }
  }

  Future<void> _sendNotificationToAdmin({
    required String adminId,
    required String groupName,
    required String title,
    required String description,
    required int iconCode,
  }) async {
    try {
      final notification = NotificationModel(
        uid: adminId,
        title: title,
        description: description,
        iconCode: iconCode,
        type: 'group_response',
        groupId: widget.groupId,
        groupName: groupName,
      );

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification.toFirestore());

      debugPrint('Notification sent to admin: $adminId');
    } catch (e) {
      debugPrint('Error sending notification to admin: $e');
    }
  }

  Future<String?> _getCurrentUserName() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return userDoc.get('name') as String?;
      }
    } catch (e) {
      debugPrint('Error getting user name: $e');
    }
    return null;
  }

  Future<void> _checkUserAuth() async {
    // Sử dụng FirebaseAuth trực tiếp để đảm bảo có user
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userId = firebaseUser?.uid;

    debugPrint(
      'DEBUG: Checking user - Firebase: ${firebaseUser?.uid}, Provider: ${ref.read(currentUserIdProvider)}',
    );

    if (userId == null) {
      // Chưa đăng nhập - lưu groupId vào SharedPreferences và chuyển đến login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingGroupId', widget.groupId);
      debugPrint(
        'DEBUG: Saved pendingGroupId to SharedPreferences: ${widget.groupId}',
      );

      setState(() {
        _errorMessage = isVi ? 'Đang chuyển đến trang đăng nhập...' : 'Redirecting to login...';
      });

      // Chờ 1 giây rồi chuyển đến login
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _joinGroup() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userId = firebaseUser?.uid;

    if (userId == null) {
      setState(() {
        _errorMessage = isVi ? 'Chưa đăng nhập' : 'Not logged in';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      // Kiểm tra xem group có tồn tại không
      final groupRepository = ref.read(groupRepositoryProvider);
      final group = await groupRepository.getById(widget.groupId);

      // Kiểm tra xem user đã là thành viên chưa
      if (group.memberIds.contains(userId)) {
        // Đã là thành viên, chuyển thẳng vào group detail
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageTransitions.slideRight(
              GroupDetailScreen(groupId: widget.groupId),
            ),
          );
        }
        return;
      }

      // Thêm user vào group bằng method addMember
      await groupRepository.addMember(widget.groupId, userId);

      // Lấy tên người dùng hiện tại
      final userName = await _getCurrentUserName() ?? (isVi ? 'Một người dùng' : 'A user');

      // Gửi thông báo tới admin về việc chấp nhận lời mời
      await _sendNotificationToAdmin(
        adminId: group.adminId,
        groupName: group.name,
        title: isVi ? '✅ Chấp nhận lời mời' : '✅ Accepted invitation',
        description:
            isVi ? '$userName đã chấp nhận lời mời tham gia quỹ "${group.name}"' : '$userName accepted invitation to join "${group.name}"',
        iconCode: Icons.check_circle.codePoint,
      );

      // Cập nhật trạng thái thông báo hiện tại
      if (widget.notificationId != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(widget.notificationId)
            .update({'status': 'accepted'});
      }

      if (mounted) {
        setState(() {
          _isJoining = false;
          _isAccepted = true;
        });

        MonoToast.success(
          context,
          isVi ? '🎉 Đã tham gia quỹ "${group.name}" thành công!' : '🎉 Joined fund "${group.name}" successfully!',
        );

        // Chuyển hướng vào trong quỹ sau 2 giây
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageTransitions.slideRight(
                GroupDetailScreen(groupId: widget.groupId),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('DEBUG ERROR in _joinGroup: $e');
      setState(() {
        _errorMessage = '${isVi ? 'Lỗi' : 'Error'}: $e';
        _isJoining = false;
      });
    }
  }

  Future<void> _rejectInvitation(String groupName, String adminId) async {
    setState(() {
      _isRejecting = true;
    });

    try {
      // Lấy tên người dùng hiện tại
      final userName = await _getCurrentUserName() ?? (isVi ? 'Một người dùng' : 'A user');

      // Gửi thông báo tới admin về việc từ chối lời mời
      await _sendNotificationToAdmin(
        adminId: adminId,
        groupName: groupName,
        title: isVi ? '❌ Từ chối lời mời' : '❌ Declined invitation',
        description: isVi ? '$userName đã từ chối lời mời tham gia quỹ "$groupName"' : '$userName declined invitation to join "$groupName"',
        iconCode: Icons.cancel.codePoint,
      );

      // Cập nhật trạng thái thông báo hiện tại
      if (widget.notificationId != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(widget.notificationId)
            .update({'status': 'rejected'});
      }

      if (mounted) {
        setState(() {
          _isRejecting = false;
          _isRejected = true;
        });

        MonoToast.info(
          context,
          isVi ? '👋 Đã từ chối lời mời' : '👋 Invitation declined',
        );
      }
    } catch (e) {
      debugPrint('Error rejecting invitation: $e');
      if (mounted) {
        Navigator.pop(context);
        MonoToast.info(
          context,
          isVi ? 'Đã từ chối lời mời' : 'Invitation declined',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final primaryColor = context.colors.primary;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBgColor = context.cardBg;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;
    final borderColor = context.borderColor;
    final groupAsync = ref.watch(groupDetailsProvider(widget.groupId));

    return Scaffold(
      backgroundColor: bgColor,
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: context.colors.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVi ? 'Quỹ không tồn tại' : 'Fund does not exist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi ? 'Lời mời có thể đã hết hạn hoặc quỹ đã bị xóa' : 'Invitation might have expired or fund was deleted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          isVi ? 'Quay lại' : 'Go back',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final groupIcon = group.iconCode != null
              ? IconData(group.iconCode as int, fontFamily: 'MaterialIcons')
              : Icons.group;
          final groupColor = CategoryUtils.getVibrantColor(group.name);

          return Stack(
            children: [
              // Header background
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [groupColor, groupColor.withValues(alpha: 0.6)],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
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
                                color: Colors.white.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.white30, width: 1),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isVi ? 'Lời mời tham gia quỹ' : 'Fund Invitation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 42),
                        ],
                      ),
                    ),

                    // Main content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),

                              // Group icon & name card
                              Center(
                                child: Column(
                                  children: [
                                    // Group Icon
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            groupColor,
                                            groupColor.withValues(alpha: 0.4),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: groupColor.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        groupIcon,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Group name
                                    Text(
                                      group.name,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (group.description != null &&
                                        group.description!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        group.description!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textSecondary,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Admin info
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(group.adminId)
                                    .get(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists) {
                                    return const SizedBox.shrink();
                                  }

                                  final adminData =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>;
                                  final adminName =
                                      adminData['name'] as String? ?? 'Admin';
                                  final adminAvatar =
                                      adminData['avatarUrl'] as String?;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: borderColor, width: 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi ? 'Người tạo quỹ' : 'Fund Creator',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: groupColor,
                                              backgroundImage:
                                                  adminAvatar != null
                                                  ? NetworkImage(adminAvatar)
                                                  : null,
                                              child: adminAvatar == null
                                                  ? Text(
                                                      adminName.isNotEmpty
                                                          ? adminName[0]
                                                                .toUpperCase()
                                                          : 'A',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    adminName,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isVi ? 'Chủ quỹ' : 'Owner',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: groupColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 24),

                              // Group stats
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      icon: Icons.people,
                                      label: isVi ? 'Thành viên' : 'Members',
                                      value: '${group.memberIds.length}',
                                      color: groupColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      icon: Icons.calendar_today,
                                      label: isVi ? 'Tạo vào' : 'Created on',
                                      value:
                                          '${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year}',
                                      color: groupColor,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Error message
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.colors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: context.colors.error,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: context.colors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: context.colors.error,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      border: Border(top: BorderSide(color: borderColor, width: 1)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: _isAccepted || _isRejected
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isAccepted
                                  ? context.income.withValues(alpha: 0.1)
                                  : context.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _isAccepted ? context.income : context.expense,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isAccepted
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: _isAccepted
                                      ? context.income
                                      : context.expense,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isAccepted
                                      ? (isVi ? 'Bạn đã chấp nhận lời mời' : 'You accepted the invitation')
                                      : (isVi ? 'Bạn đã từ chối lời mời' : 'You declined the invitation'),
                                  style: TextStyle(
                                    color: _isAccepted
                                        ? context.income
                                        : context.expense,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              // Reject button
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isRejecting || _isJoining
                                      ? null
                                      : () => _rejectInvitation(
                                          group.name,
                                          group.adminId,
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: context.colors.error.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _isRejecting
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  context.colors.error.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          isVi ? 'Từ chối' : 'Decline',
                                          style: TextStyle(
                                            color: context.colors.error,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Accept button
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isJoining || _isRejecting
                                      ? null
                                      : _joinGroup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: groupColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isJoining
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                  Color
                                                >(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          isVi ? 'Chấp nhận' : 'Accept',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Scaffold(
          backgroundColor: bgColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  isVi ? 'Đang tải thông tin quỹ...' : 'Loading fund info...',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: context.colors.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isVi ? 'Lỗi tải quỹ' : 'Failed to load fund',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVi ? 'Không thể tải thông tin quỹ. Vui lòng thử lại sau.' : 'Cannot load fund info. Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: Text(isVi ? 'Quay lại' : 'Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
