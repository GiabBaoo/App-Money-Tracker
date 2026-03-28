import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/device_session_model.dart';

class ActiveDevicesScreen extends StatelessWidget {
  const ActiveDevicesScreen({super.key});

  Future<Map<String, String>> _getDeviceInfoAndRegister() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String deviceName = 'Thiết bị không xác định';
    String deviceType = 'mobile';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        final browserName = webInfo.browserName.name.toUpperCase();
        deviceName = 'Trình duyệt $browserName';
        deviceType = 'desktop';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final androidInfo = await deviceInfoPlugin.androidInfo;
            deviceName = '${androidInfo.brand} ${androidInfo.model}'.toUpperCase(); //VD: SAMSUNG SM-G998B
            deviceType = 'mobile';
            break;
          case TargetPlatform.iOS:
            final iosInfo = await deviceInfoPlugin.iosInfo;
            deviceName = iosInfo.name; // VD: iPhone 13 Pro
            deviceType = 'mobile';
            break;
          case TargetPlatform.windows:
            final windowsInfo = await deviceInfoPlugin.windowsInfo;
            deviceName = 'Windows PC (${windowsInfo.computerName})';
            deviceType = 'desktop';
            break;
          case TargetPlatform.macOS:
            final macInfo = await deviceInfoPlugin.macOsInfo;
            deviceName = 'MacBook (${macInfo.computerName})';
            deviceType = 'laptop';
            break;
          case TargetPlatform.linux:
            final linuxInfo = await deviceInfoPlugin.linuxInfo;
            deviceName = 'Linux PC (${linuxInfo.name})';
            deviceType = 'desktop';
            break;
          default:
            deviceName = 'Thiết bị khác';
            deviceType = 'mobile';
        }
      }
    } catch (e) {
      deviceName = 'Lỗi lấy thông tin thiết bị';
    }

    // Đăng ký trực tiếp thiết bị hiện hành vào Firestore của User
    await FirestoreService().registerDeviceSession(
      deviceName: deviceName,
      deviceType: deviceType,
    );

    return {'name': deviceName, 'type': deviceType};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getDeviceInfoAndRegister(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF438883),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        final localDeviceName = snapshot.data?['name'] ?? 'Lỗi';

        return StreamBuilder<List<DeviceSessionModel>>(
          stream: FirestoreService().getDeviceSessionsStream(),
          builder: (context, streamSnapshot) {
            if (streamSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF438883),
                body: Center(child: CircularProgressIndicator(color: Colors.white)),
              );
            }
            
            final sessions = streamSnapshot.data ?? [];

            return Scaffold(
              backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // 1. CUSTOM APP BAR
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
                          const Text(
                            'Thiết bị đang hoạt động',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 48), // Cân bằng không gian
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA), // Nền xám nhạt
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Column(
                          children: [
                            // HEADER CỦA BOX (Icon khiên bảo vệ)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(
                                top: 40,
                                bottom: 20,
                                left: 24,
                                right: 24,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(30),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5F3), // Xanh ngọc nhạt
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.shield,
                                      color: Color(0xFF438883),
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Quản lý phiên đăng nhập',
                                    style: TextStyle(
                                      color: Color(0xFF333333),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Xem và quản lý tất cả các thiết bị đang\ntruy cập vào tài khoản của bạn.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // DANH SÁCH THIẾT BỊ (Cuộn được)
                            Expanded(
                              child: Container(
                                color: Colors.white,
                                child: streamSnapshot.connectionState == ConnectionState.waiting
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF438883)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 10,
                                        ),
                                        itemCount: sessions.length,
                                        itemBuilder: (context, index) {
                                          final s = sessions[index];
                                          
                                          // Hiển thị thời gian
                                          String timeStr = 'Đang hoạt động';
                                          final diff = DateTime.now().difference(s.lastActive);
                                          if (diff.inDays > 0) timeStr = '${diff.inDays} ngày trước';
                                          else if (diff.inHours > 0) timeStr = '${diff.inHours} giờ trước';
                                          else if (diff.inMinutes > 0) timeStr = '${diff.inMinutes} phút trước';
                                          
                                          return _buildDeviceItem(
                                            name: s.deviceName,
                                            type: s.deviceType,
                                            location: s.location,
                                            status: timeStr,
                                            isCurrent: s.deviceName == localDeviceName, // So khớp xem có phải thiết bị đang mở app ko
                                            onRemove: () {
                                                FirestoreService().removeDeviceSession(s.id);
                                            }
                                          );
                                        },
                                      ),
                              ),
                            ),

                            // NÚT ĐĂNG XUẤT CUỐI MÀN HÌNH
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.only(
                                left: 24,
                                right: 24,
                                top: 10,
                                bottom: 40,
                              ),
                              child: Column(
                                children: [
                                  // Hộp thông báo màu vàng
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB), // Vàng rất nhạt
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Icon(
                                          Icons.info_outline,
                                          color: Color(0xFFD97706),
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Nếu bạn thấy bất kỳ thiết bị nào lạ, hãy đăng xuất khỏi thiết bị đó ngay lập tức và đổi mật khẩu để bảo vệ tài khoản của bạn.',
                                            style: TextStyle(
                                              color: Color(0xFF92400E),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Nút đăng xuất tất cả
                                  InkWell(
                                    onTap: () async {
                                      // Hành động đăng xuất
                                      await AuthService().logout();
                                      if (context.mounted) {
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      }
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A9B7F), // Màu xanh nút
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF4A9B7F,
                                            ).withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.logout,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Đăng xuất khỏi thiết bị này', // Thay đổi Title một chút 
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  // --- HÀM TẠO TỪNG DÒNG THIẾT BỊ ---
  Widget _buildDeviceItem({
      required String name, 
      required String type, 
      required String location, 
      required String status, 
      required bool isCurrent, 
      required VoidCallback onRemove
  }) {
    IconData getDeviceIcon(String type) {
      if (type == 'mobile') return Icons.phone_iphone;
      if (type == 'laptop') return Icons.laptop_mac;
      return Icons.desktop_windows;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Căn trên cùng để giống thiết kế
        children: [
          // Icon nền xanh nhạt
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              getDeviceIcon(type),
              color: const Color(0xFF438883),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Thông tin thiết bị
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nếu là thiết bị HIỆN TẠI thì thêm nhãn xanh
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HIỆN TẠI',
                          style: TextStyle(
                            color: Color(0xFF438883),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$location · $status',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Icon thùng rác thay cho 3 chấm để xóa/đăng xuất thiết bị con
          if (!isCurrent)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
