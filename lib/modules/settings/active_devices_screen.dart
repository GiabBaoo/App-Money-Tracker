import 'package:flutter/material.dart';
import '../../utils/time_utils.dart';
import '../../utils/device_utils.dart';
import '../../utils/page_transitions.dart';
import '../../services/firestore_service.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../models/device_session_model.dart';
import '../auth/login_screen.dart';

class ActiveDevicesScreen extends StatefulWidget {
  const ActiveDevicesScreen({super.key});

  @override
  State<ActiveDevicesScreen> createState() => _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends State<ActiveDevicesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  Map<String, String>? _currentDeviceInfo;
  String? _currentInstallationId;
  String? _currentSessionId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentDevice();
  }

  Future<void> _loadCurrentDevice() async {
    try {
      final info = await DeviceUtils.getDeviceInfo();
      final installId = await DeviceUtils.getInstallationId();
      final uid = _authService.currentUid;
      final sessionId = uid != null ? await DeviceUtils.getSessionId(uid) : null;

      if (mounted) {
        setState(() {
          _currentDeviceInfo = info;
          _currentInstallationId = installId;
          _currentSessionId = sessionId;
          _isLoading = false;
        });
      }
      await _firestoreService.ensureCurrentDeviceRegistered();
    } catch (e) {
      debugPrint('ActiveDevicesScreen load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmLogoutCurrentDevice(bool isVi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVi ? 'Đăng xuất thiết bị này?' : 'Log out this device?'),
        content: Text(
          isVi
              ? 'Bạn sẽ đăng xuất khỏi ứng dụng trên thiết bị hiện tại và cần đăng nhập lại.'
              : 'You will be logged out of the app on this device and need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Đăng xuất' : 'Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageTransitions.fade(const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmRemoveSession(DeviceSessionModel session, bool isVi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVi ? 'Hủy phiên đăng nhập?' : 'Revoke session?'),
        content: Text(
          isVi
              ? 'Thiết bị "${session.deviceName}" sẽ bị đăng xuất khỏi tài khoản của bạn.'
              : 'The device "${session.deviceName}" will be logged out from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Đăng xuất' : 'Revoke'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _firestoreService.removeDeviceSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Đã gỡ phiên đăng nhập thành công.' : 'Session revoked successfully.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmLogoutAllOtherDevices(String currentSessionId, bool isVi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVi ? 'Đăng xuất tất cả thiết bị khác?' : 'Log out all other devices?'),
        content: Text(
          isVi
              ? 'Tất cả các phiên đăng nhập khác ngoại trừ thiết bị hiện tại sẽ bị hủy bỏ.'
              : 'All sessions on other devices except this current device will be terminated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Đăng xuất tất cả' : 'Log out all'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _firestoreService.removeOtherDeviceSessions(currentSessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Đã đăng xuất khỏi tất cả thiết bị khác.' : 'Logged out of all other devices.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
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
                  Text(
                    isVi ? 'Thiết bị đang hoạt động' : 'Active Devices',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    tooltip: isVi ? 'Làm mới' : 'Refresh',
                    onPressed: () {
                      _loadCurrentDevice();
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF438883)))
                    : StreamBuilder<List<DeviceSessionModel>>(
                        stream: _firestoreService.getDeviceSessionsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                          }

                          final sessions = snapshot.data ?? [];
                          final currentName = _currentDeviceInfo?['name']?.toLowerCase() ?? '';

                          // Phân loại thiết bị hiện tại và thiết bị khác dựa trên session ID hoặc install UUID
                          DeviceSessionModel? currentSession;
                          final otherSessions = <DeviceSessionModel>[];

                          for (var s in sessions) {
                            final bool isThisDevice = (_currentSessionId != null && s.id == _currentSessionId) ||
                                (_currentInstallationId != null && s.id.endsWith(_currentInstallationId!)) ||
                                (currentSession == null && currentName.isNotEmpty && s.deviceName.toLowerCase() == currentName);

                            if (isThisDevice && currentSession == null) {
                              currentSession = s;
                            } else {
                              otherSessions.add(s);
                            }
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(context, isVi ? 'THIẾT BỊ HIỆN TẠI' : 'CURRENT DEVICE'),
                                _buildInfoBox(context, [
                                  if (currentSession != null)
                                    _buildDeviceItem(
                                      context,
                                      session: currentSession,
                                      isCurrent: true,
                                      isVi: isVi,
                                      onRemove: () => _confirmLogoutCurrentDevice(isVi),
                                      showDivider: false,
                                    )
                                  else
                                    _buildSyncingDeviceItem(context, isVi, isDark),
                                ]),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionTitle(context, isVi ? 'CÁC PHIÊN ĐĂNG NHẬP KHÁC' : 'OTHER SESSIONS'),
                                    if (otherSessions.isNotEmpty)
                                      TextButton(
                                        onPressed: () => _confirmLogoutAllOtherDevices(
                                          currentSession?.id ?? _currentSessionId ?? '',
                                          isVi,
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: Text(
                                          isVi ? 'Đăng xuất tất cả' : 'Log out all',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (otherSessions.isEmpty)
                                  _buildEmptyOtherSessions(context, isDark, isVi)
                                else
                                  _buildInfoBox(
                                    context,
                                    otherSessions.asMap().entries.map((e) {
                                      final s = e.value;
                                      return _buildDeviceItem(
                                        context,
                                        session: s,
                                        isCurrent: false,
                                        isVi: isVi,
                                        onRemove: () => _confirmRemoveSession(s, isVi),
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

  Widget _buildSyncingDeviceItem(BuildContext context, bool isVi, bool isDark) {
    final devName = _currentDeviceInfo?['name'] ?? (isVi ? 'Thiết bị này' : 'This device');
    final devType = _currentDeviceInfo?['type'] ?? 'mobile';

    return Padding(
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
              devType == 'mobile' ? Icons.phone_android_rounded : Icons.computer_rounded,
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
                        devName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isVi ? 'Đang đồng bộ...' : 'Syncing...',
                        style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isVi ? 'Đang đăng ký phiên thiết bị...' : 'Registering device session...',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOtherSessions(BuildContext context, bool isDark, bool isVi) {
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
            isVi ? 'Chỉ có thiết bị này đang kết nối' : 'Only this device is connected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isVi
                ? 'Không phát hiện phiên đăng nhập nào khác trên tài khoản của bạn.'
                : 'No other login sessions detected on your account.',
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
    required bool isVi,
    required VoidCallback? onRemove,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = isCurrent ? (isVi ? 'Đang hoạt động' : 'Active now') : TimeUtils.timeAgo(session.lastActive, isVi: isVi);

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
                            child: Text(
                              isVi ? 'Thiết bị này' : 'This device',
                              style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
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
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: isCurrent
                      ? (isVi ? 'Đăng xuất khỏi thiết bị này' : 'Log out this device')
                      : (isVi ? 'Gỡ phiên đăng nhập này' : 'Revoke this session'),
                  icon: Icon(
                    Icons.logout_rounded,
                    color: isCurrent ? Colors.grey : Colors.redAccent,
                    size: 20,
                  ),
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

