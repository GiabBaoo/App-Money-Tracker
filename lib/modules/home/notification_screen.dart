import 'package:flutter/material.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/animated_scale_button.dart';
import '../../services/firestore_service.dart';
import '../../services/smart_notification_service.dart';
import '../../services/auth_service.dart';
import '../../models/notification_model.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';
import '../../features/group_expense/presentation/screens/group_detail_screen.dart';
import '../../data/repositories/notification_repository.dart';
import '../../utils/page_transitions.dart';
import 'notification_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationRepository _notiRepo = NotificationRepository();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUid;
    if (uid != null) {
      _notiRepo.setUid(uid);
    }
    _autoInitAndMarkRead();
  }

  /// Tự động cập nhật thông báo đã đọc khi người dùng vào màn hình
  Future<void> _autoInitAndMarkRead() async {
    try {
      // 1. Cập nhật SQLite trước để badge chuông trên home tự mất NGAY LẬP TỨC
      await _notiRepo.markAllAsRead();
      // 2. Đồng bộ Firestore trong background (không chặn giao diện nếu mạng lỗi)
      _firestoreService.markAllNotificationsAsRead().catchError((e) {
        debugPrint('Firestore markAllNotificationsAsRead background error: $e');
      });
    } catch (e) {
      debugPrint('Error auto-init and mark read: $e');
    }
  }

  Future<void> _handleRefresh({bool forceAnalyze = false}) async {
    setState(() => _isRefreshing = true);
    try {
      final newCount = await SmartNotificationService.instance.generateSmartFinancialNotifications(forceRefresh: forceAnalyze);
      if (!forceAnalyze) {
        await _notiRepo.markAllAsRead();
        _firestoreService.markAllNotificationsAsRead().catchError((_) {});
      }
      if (forceAnalyze && mounted) {
        TopToast.show(context, newCount > 0
            ? 'Đã tạo $newCount báo cáo phân tích chi tiêu mới!'
            : 'Dữ liệu chi tiêu của bạn đã được cập nhật mới nhất!');
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === HEADER ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Thông báo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Phân tích chi tiêu thông minh',
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                        ),
                        onPressed: _isRefreshing ? null : () => _handleRefresh(forceAnalyze: true),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.done_all_rounded, color: Colors.white, size: 22),
                        tooltip: 'Đánh dấu tất cả đã đọc',
                        onPressed: () async {
                          await _firestoreService.markAllNotificationsAsRead();
                          // Đồng bộ SQLite → badge chuông trên home tự mất
                          await _notiRepo.markAllAsRead();
                          if (context.mounted) {
                            TopToast.show(context, 'Đã đánh dấu tất cả thông báo là đã đọc!');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // === DANH SÁCH THÔNG BÁO ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: StreamBuilder<List<NotificationModel>>(
                  stream: _notiRepo.getNotificationsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text(
                                'Lỗi tải thông báo: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _handleRefresh,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF438883)),
                      );
                    }

                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    return RefreshIndicator(
                      color: const Color(0xFF438883),
                      onRefresh: _handleRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                        itemCount: notifications.length,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemBuilder: (context, index) {
                          final noti = notifications[index];
                          return StaggeredListItem(
                            index: index,
                            child: AnimatedScaleButton(
                              scaleDown: 0.98,
                              onTap: () async {
                                if (!noti.isRead && noti.id.isNotEmpty) {
                                  await _notiRepo.markAsRead(noti.id);
                                }
                                if (!context.mounted) return;

                                if (noti.type == 'group_invite' && noti.groupId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JoinGroupScreen(
                                        groupId: noti.groupId!,
                                        notificationId: noti.id,
                                      ),
                                    ),
                                  );
                                } else if (noti.type == 'group_response' && noti.groupId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GroupDetailScreen(groupId: noti.groupId!),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    PageTransitions.slideRight(
                                      NotificationDetailScreen(notification: noti),
                                    ),
                                  );
                                }
                              },
                              child: _buildNotificationItem(
                                context: context,
                                notification: noti,
                                isDark: isDark,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFE8F5F1),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 44,
                color: isDark ? const Color(0xFF00BFA5) : const Color(0xFF438883),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có thông báo nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mọi thông tin về giao dịch, quỹ nhóm và nhắc nhở chi tiêu sẽ được hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF438883),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _handleRefresh(forceAnalyze: true),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Phân tích chi tiêu thông minh ngay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required NotificationModel notification,
    required bool isDark,
  }) {
    final dateStr =
        '${notification.createdAt.day.toString().padLeft(2, '0')}/${notification.createdAt.month.toString().padLeft(2, '0')}/${notification.createdAt.year}';

    Color iconColor = const Color(0xFF438883);
    IconData iconData = Icons.notifications_active_rounded;

    if (notification.type == 'spending_alert_high') {
      iconColor = Colors.deepOrange;
    } else if (notification.type == 'spending_alert_saved') {
      iconColor = Colors.green;
    } else if (notification.type == 'spending_alert_stable') {
      iconColor = Colors.teal;
    } else if (notification.type == 'smart_budget_suggestion') {
      iconColor = Colors.amber.shade700;
    } else if (notification.type == 'low_balance_alert') {
      iconColor = Colors.redAccent;
    } else if (notification.type == 'daily_reminder') {
      iconColor = const Color(0xFF438883);
    } else if (notification.type == 'group_invite' || notification.type == 'group_response') {
      iconColor = Colors.indigo;
      iconData = Icons.group_rounded;
    }

    String? statusLabel;
    Color? statusColor;

    if (notification.type == 'group_invite') {
      if (notification.status == 'accepted') {
        statusLabel = 'Đã tham gia';
        statusColor = Colors.green;
      } else if (notification.status == 'rejected') {
        statusLabel = 'Đã từ chối';
        statusColor = Colors.red;
      } else {
        statusLabel = 'Chờ phản hồi';
        statusColor = Colors.orange;
      }
    }

    final diff = DateTime.now().difference(notification.createdAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays} ngày trước';
    } else {
      timeAgo = dateStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222C2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFF438883).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon chuông hoặc trạng thái phân loại
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Nội dung thông báo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      if (statusLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor!.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
