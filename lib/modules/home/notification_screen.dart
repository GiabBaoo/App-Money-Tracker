import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/notification_model.dart';

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
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Thông báo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(width: 48),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }

                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 60,
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có thông báo nào',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF999999),
                            fontSize: 16,
                          ),
                        ),
                      ]));
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
    
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          firestoreService.markNotificationAsRead(notification.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
            ? (notification.isRead ? const Color(0xFF2E2E2E) : const Color(0xFF3E3E3E))
            : (notification.isRead ? const Color(0xFFF9FAFB) : const Color(0xFFE8F5F0)),
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: const Color(0xFF3E3E3E)) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isDark
                ? (notification.isRead ? const Color(0xFF3E3E3E) : const Color(0xFF4E4E3E))
                : (notification.isRead ? const Color(0xFFE5E7EB) : const Color(0xFFFEF3C7)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              notification.icon,
              color: notification.isRead 
                ? (isDark ? Colors.white38 : const Color(0xFF6B7280))
                : const Color(0xFFF59E0B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              notification.title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification.description,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ])),
          if (!notification.isRead)
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF438883), shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
