import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/language_service.dart';
import '../../models/user_model.dart';
import '../../services/voice_service.dart';
import '../../services/device_contacts_service.dart';
import '../../data/repositories/user_repository.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
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
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi ? 'Sử dụng dữ liệu' : 'Data Usage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: StreamBuilder<UserModel?>(
                  stream: _firestoreService.getUserStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null)
                      return const Center(child: CircularProgressIndicator());

                    final isLocation = user.dataUsage['location'] == true;
                    final isContacts = user.dataUsage['contacts'] == true;
                    final isMicrophone = user.dataUsage['microphone'] == true;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        top: 30,
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            context,
                            isVi ? 'QUYỀN TRUY CẬP' : 'APP PERMISSIONS',
                          ),
                          _buildInfoBox(context, [
                            _buildToggleItem(
                              context,
                              icon: Icons.location_on_outlined,
                              title: isVi ? 'Vị trí' : 'Location',
                              subtitle: isVi
                                  ? 'Tối ưu hóa gợi ý địa phương'
                                  : 'Optimize local suggestions',
                              value: isLocation,
                              onChanged: (val) =>
                                  _updatePermission(user, 'location', val),
                              showDivider: true,
                            ),
                            _buildToggleItem(
                              context,
                              icon: Icons.contacts_outlined,
                              title: isVi ? 'Danh bạ' : 'Contacts',
                              subtitle: isVi
                                  ? 'Kết nối nhanh với bạn bè'
                                  : 'Quickly connect with contacts',
                              value: isContacts,
                              onChanged: (val) =>
                                  _updatePermission(user, 'contacts', val),
                              showDivider: true,
                            ),
                            _buildToggleItem(
                              context,
                              icon: Icons.mic_none_outlined,
                              title: 'Microphone',
                              subtitle: isVi
                                  ? 'Sử dụng giọng nói để nhập liệu'
                                  : 'Use voice commands for entry',
                              value: isMicrophone,
                              onChanged: (val) =>
                                  _updatePermission(user, 'microphone', val),
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
    try {
      if (val) {
        if (key == 'contacts') {
          final granted = await DeviceContactsService.instance
              .requestPermission();
          if (!granted) return;
        } else {
          Permission perm = key == 'location'
              ? Permission.location
              : Permission.microphone;
          final status = await perm.request();
          if (!status.isGranted) return;
          if (key == 'microphone') await VoiceService().init();
        }
      }
      await _firestoreService.updateDataUsagePreference(key, val);
      final updatedDataUsage = Map<String, dynamic>.from(user.dataUsage);
      updatedDataUsage[key] = val;
      await UserRepository().updateUserProfile({'dataUsage': updatedDataUsage});
    } catch (e) {
      debugPrint('DataUsageScreen _updatePermission error: $e');
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
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
    final isDark = context.isDark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.brandColor.withValues(
                    alpha: isDark ? 0.2 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.brandColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: context.brandColor,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.dividerColor,
            indent: 70,
            endIndent: 16,
          ),
      ],
    );
  }
}
