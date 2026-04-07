import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/notification_model.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), 
                  onPressed: () => Navigator.pop(context)
                ),
                const Text('Thông báo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white), 
                  onPressed: () async {
                    try {
                      await firestoreService.pushMockNotifications();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật dữ liệu thông báo mới!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  }
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<List<NotificationModel>>(
                  stream: firestoreService.getNotificationsStream(),
                  builder: (context, snapshot) {
                    // XỬ LÝ LỖI TRUY VẤN (Nếu thiếu Index Firebase)
                    if (snapshot.hasError) {
                      print('NOTIFICATION STREAM ERROR: ${snapshot.error}');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Lỗi kết nối Firebase: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 20),
                              const Text('Gợi ý: Hãy kiểm tra Log terminal hoặc tạo Index cho collection "notifications" trên Firebase Console.', 
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: () {
                                  // Refresh lại link (Thực tế là rebuild widget)
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                                },
                                child: const Text('Thử lại'),
                              )
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }

                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 80,
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                            const SizedBox(height: 20),
                            const Text('Chưa có thông báo nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF438883),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              onPressed: () async {
                                try {
                                  await firestoreService.pushMockNotifications();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khởi tạo: $e')));
                                  }
                                }
                              },
                              child: const Text('Khởi tạo dữ liệu mẫu', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final noti = notifications[index];
                        return _buildNotificationItem(
                          context: context,
                          firestoreService: firestoreService,
                          notification: noti,
                        );
                      },
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

  Widget _buildNotificationItem({
    required BuildContext context,
    required FirestoreService firestoreService,
    required NotificationModel notification,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = '${notification.createdAt.day.toString().padLeft(2, '0')}/${notification.createdAt.month.toString().padLeft(2, '0')}/${notification.createdAt.year}';
    
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          firestoreService.markNotificationAsRead(notification.id);
        }
        
        // Handle group invite notifications
        if (notification.type == 'group_invite' && notification.groupId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JoinGroupScreen(groupId: notification.groupId!),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark) BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF438883),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
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
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Color(0xFF438883), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.grey.shade400,
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
