import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../services/voice_service.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _locationLoading = false;
  bool _contactsLoading = false;
  bool _microphoneLoading = false;

  @override
  Widget build(BuildContext context) {
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
                  const Text('Sử dụng dữ liệu', 
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
                child: StreamBuilder<UserModel?>(
                  stream: _firestoreService.getUserStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) return const Center(child: CircularProgressIndicator());

                    final isLocation = user.dataUsage['location'] == true;
                    final isContacts = user.dataUsage['contacts'] == true;
                    final isMicrophone = user.dataUsage['microphone'] == true;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'QUYỀN TRUY CẬP'),
                          _buildInfoBox(context, [
                            _buildToggleItem(
                              context,
                              icon: Icons.location_on_outlined,
                              title: 'Vị trí',
                              subtitle: 'Tối ưu hóa gợi ý địa phương',
                              value: isLocation,
                              onChanged: (val) => _updatePermission(user, 'location', val),
                              showDivider: true,
                            ),
                            _buildToggleItem(
                              context,
                              icon: Icons.contacts_outlined,
                              title: 'Danh bạ',
                              subtitle: 'Kết nối nhanh với bạn bè',
                              value: isContacts,
                              onChanged: (val) => _updatePermission(user, 'contacts', val),
                              showDivider: true,
                            ),
                            _buildToggleItem(
                              context,
                              icon: Icons.mic_none_outlined,
                              title: 'Microphone',
                              subtitle: 'Sử dụng giọng nói để nhập liệu',
                              value: isMicrophone,
                              onChanged: (val) => _updatePermission(user, 'microphone', val),
                              showDivider: false,
                            ),
                          ]),
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

  Future<void> _updatePermission(UserModel user, String key, bool val) async {
    if (val) {
      Permission perm = key == 'location' ? Permission.location : (key == 'contacts' ? Permission.contacts : Permission.microphone);
      final status = await perm.request();
      if (!status.isGranted) return;
      if (key == 'microphone') await VoiceService().init();
    }
    await _firestoreService.updateDataUsagePreference(key, val);
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

  Widget _buildToggleItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                child: Icon(icon, color: const Color(0xFF438883), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF438883),
                activeTrackColor: const Color(0xFF438883).withOpacity(0.3),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 70, endIndent: 16),
      ],
    );
  }
}
