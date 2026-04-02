import 'package:flutter/material.dart';
import '../../utils/device_utils.dart';
import '../../utils/time_utils.dart';
import '../../services/firestore_service.dart';
import '../../models/device_session_model.dart';

class ActiveDevicesScreen extends StatelessWidget {
  const ActiveDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Thiết bị đang hoạt động', 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: StreamBuilder<List<DeviceSessionModel>>(
                        stream: firestoreService.getDeviceSessionsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                          }
                          
                          final sessions = snapshot.data ?? [];
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) {
                              final s = sessions[index];
                              return _buildDeviceItem(
                                context: context,
                                session: s,
                                onRemove: () => firestoreService.removeDeviceSession(s.id),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 24, right: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.security_update_good_rounded, color: Color(0xFF438883), size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Quản lý phiên đăng nhập', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Các thiết bị hiện đang đăng nhập vào\ntài khoản của bạn sẽ được hiển thị ở đây.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDeviceItem({
    required BuildContext context,
    required DeviceSessionModel session,
    required VoidCallback onRemove,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = TimeUtils.timeAgo(session.lastActive);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              session.deviceType == 'mobile' ? Icons.phone_android_rounded : Icons.computer_rounded,
              color: const Color(0xFF438883), size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.deviceName, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${session.location} • ${session.deviceType.toUpperCase()}', 
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(timeStr == 'Vừa mới đổi' ? 'Đang hoạt động' : 'Hoạt động $timeStr',
                    style: const TextStyle(color: Color(0xFF438883), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
