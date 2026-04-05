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
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                child: StreamBuilder<List<DeviceSessionModel>>(
                  stream: firestoreService.getDeviceSessionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }
                    
                    final sessions = snapshot.data ?? [];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'CÁC PHIÊN ĐĂNG NHẬP'),
                          _buildInfoBox(context, sessions.asMap().entries.map((e) {
                            final s = e.value;
                            return _buildDeviceItem(
                              context,
                              session: s,
                              onRemove: () => firestoreService.removeDeviceSession(s.id),
                              showDivider: e.key != sessions.length - 1,
                            );
                          }).toList()),
                        ],
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context, {
    required DeviceSessionModel session,
    required VoidCallback onRemove,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = TimeUtils.timeAgo(session.lastActive);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
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
                    Text(session.deviceName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text('${session.location} • Hoạt động $timeStr', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20)),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 70, endIndent: 16),
      ],
    );
  }
}
