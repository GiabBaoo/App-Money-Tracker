
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/group_expense_providers.dart';
import '../../../../models/notification_model.dart';
import 'group_detail_screen.dart';
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
        _errorMessage = 'Đang chuyển đến trang đăng nhập...';
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
        _errorMessage = 'Chưa đăng nhập';
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

      if (group == null) {
        setState(() {
          _errorMessage = 'Quỹ không tồn tại hoặc đã bị xóa';
          _isJoining = false;
        });
        return;
      }

      // Kiểm tra xem user đã là thành viên chưa
      if (group.memberIds.contains(userId)) {
        // Đã là thành viên, chuyển thẳng vào group detail
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: widget.groupId),
            ),
          );
        }
        return;
      }

      // Thêm user vào group bằng method addMember
      await groupRepository.addMember(widget.groupId, userId);

      // Lấy tên người dùng hiện tại
      final userName = await _getCurrentUserName() ?? 'Một người dùng';

      // Gửi thông báo tới admin về việc chấp nhận lời mời
      await _sendNotificationToAdmin(
        adminId: group.adminId,
        groupName: group.name,
        title: '✅ Chấp nhận lời mời',
        description:
            '$userName đã chấp nhận lời mời tham gia quỹ "${group.name}"',
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Đã tham gia quỹ "${group.name}" thành công!'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );

        // Chuyển hướng vào trong quỹ sau 2 giây
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    GroupDetailScreen(groupId: widget.groupId),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('DEBUG ERROR in _joinGroup: $e');
      setState(() {
        _errorMessage = 'Lỗi: $e';
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
      final userName = await _getCurrentUserName() ?? 'Một người dùng';

      // Gửi thông báo tới admin về việc từ chối lời mời
      await _sendNotificationToAdmin(
        adminId: adminId,
        groupName: groupName,
        title: '❌ Từ chối lời mời',
        description: '$userName đã từ chối lời mời tham gia quỹ "$groupName"',
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('👋 Đã từ chối lời mời'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error rejecting invitation: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối lời mời'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final groupAsync = ref.watch(groupDetailsProvider(widget.groupId));

    return Scaffold(
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return Scaffold(
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Quỹ không tồn tại',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lời mời có thể đã hết hạn hoặc quỹ đã bị xóa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
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
                        ),
                        child: const Text(
                          'Quay lại',
                          style: TextStyle(color: Colors.white),
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
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Text(
                            'Lời mời tham gia quỹ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 40),
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
                                        borderRadius: BorderRadius.circular(24),
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
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
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
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
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
                                      color: isDark
                                          ? const Color(0xFF2E2E2E)
                                          : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Người tạo quỹ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
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
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Chủ quỹ',
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
                                      label: 'Thành viên',
                                      value: '${group.memberIds.length}',
                                      color: groupColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      icon: Icons.calendar_today,
                                      label: 'Tạo vào',
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
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Colors.red,
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
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: _isAccepted || _isRejected
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isAccepted
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isAccepted ? Colors.green : Colors.red,
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
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isAccepted
                                      ? 'Bạn đã chấp nhận lời mời'
                                      : 'Bạn đã từ chối lời mời',
                                  style: TextStyle(
                                    color: _isAccepted
                                        ? Colors.green
                                        : Colors.red,
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
                                      color: Colors.red.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isRejecting
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.red.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                ),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Từ chối',
                                          style: TextStyle(
                                            color: Colors.red.withValues(
                                              alpha: 0.8,
                                            ),
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isJoining
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Chấp nhận',
                                          style: TextStyle(
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
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Đang tải thông tin quỹ...',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2E2E2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lỗi tải quỹ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Không thể tải thông tin quỹ. Vui lòng thử lại sau.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay lại'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
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
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
