import 'package:flutter/material.dart';
import '../../utils/time_utils.dart';
import '../../utils/device_utils.dart';
import '../../services/firestore_service.dart';
import '../../models/device_session_model.dart';

class ActiveDevicesScreen extends StatefulWidget {
  const ActiveDevicesScreen({super.key});

  @override
  State<ActiveDevicesScreen> createState() => _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends State<ActiveDevicesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, String>? _currentDeviceInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentDevice();
  }

  Future<void> _loadCurrentDevice() async {
    try {
      final info = await DeviceUtils.getDeviceInfo();
      if (mounted) {
        setState(() => _currentDeviceInfo = info);
      }
      await _firestoreService.ensureCurrentDeviceRegistered();
    } catch (_) {}
  }

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
                  const Text(
                    'Thiết bị đang hoạt động',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    tooltip: 'Làm mới',
                    onPressed: () {
                      _loadCurrentDevice();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<List<DeviceSessionModel>>(
                  stream: _firestoreService.getDeviceSessionsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }

                    final sessions = snapshot.data ?? [];
                    final currentName = _currentDeviceInfo?['name']?.toLowerCase() ?? '';

                    // Phân loại thiết bị hiện tại và thiết bị khác
                    DeviceSessionModel? currentSession;
                    final otherSessions = <DeviceSessionModel>[];

                    for (var s in sessions) {
                      if (currentSession == null &&
                          currentName.isNotEmpty &&
                          s.deviceName.toLowerCase().contains(currentName)) {
                        currentSession = s;
                      } else {
                        otherSessions.add(s);
                      }
                    }

                    // Nếu không match được từ Firestore, tạo mock session cho thiết bị hiện tại
                    currentSession ??= DeviceSessionModel(
                      id: 'current_device',
                      uid: '',
                      deviceName: _currentDeviceInfo?['name'] ?? 'Thiết bị này',
                      deviceType: _currentDeviceInfo?['type'] ?? 'mobile',
                      location: 'Thiết bị hiện hành',
                      lastActive: DateTime.now(),
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'THIẾT BỊ HIỆN TẠI'),
                          _buildInfoBox(context, [
                            _buildDeviceItem(
                              context,
                              session: currentSession,
                              isCurrent: true,
                              onRemove: null,
                              showDivider: false,
                            ),
                          ]),
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'CÁC PHIÊN ĐĂNG NHẬP KHÁC'),
                          if (otherSessions.isEmpty)
                            _buildEmptyOtherSessions(context, isDark)
                          else
                            _buildInfoBox(
                              context,
                              otherSessions.asMap().entries.map((e) {
                                final s = e.value;
                                return _buildDeviceItem(
                                  context,
                                  session: s,
                                  isCurrent: false,
                                  onRemove: () => _firestoreService.removeDeviceSession(s.id),
                                  showDivider: e.key != otherSessions.length - 1,
                                );
                              }).toList(),
                            ),
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

  Widget _buildEmptyOtherSessions(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.green.shade400, size: 36),
          const SizedBox(height: 8),
          Text(
            'Chỉ có thiết bị này đang kết nối',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Không phát hiện phiên đăng nhập nào khác trên tài khoản của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.w700,
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
    required bool isCurrent,
    required VoidCallback? onRemove,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = isCurrent ? 'Đang hoạt động' : TimeUtils.timeAgo(session.lastActive);

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
                  color: const Color(0xFF438883),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            session.deviceName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Thiết bị này',
                              style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.location} • $timeStr',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isCurrent && onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Đăng xuất thiết bị này',
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0),
            indent: 70,
            endIndent: 16,
          ),
      ],
    );
  }
}
