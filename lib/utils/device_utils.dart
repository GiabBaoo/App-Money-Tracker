import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static Future<Map<String, String>> getDeviceInfo() async {
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
            deviceName = '${androidInfo.brand} ${androidInfo.model}'.toUpperCase();
            deviceType = 'mobile';
            break;
          case TargetPlatform.iOS:
            final iosInfo = await deviceInfoPlugin.iosInfo;
            deviceName = iosInfo.name;
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
          default:
            deviceName = 'Thiết bị khác';
            deviceType = 'mobile';
        }
      }
    } catch (e) {
      deviceName = 'Lỗi thông tin thiết bị';
    }
    return {'name': deviceName, 'type': deviceType};
  }

  static String getSessionId(String uid, String deviceName) {
    String sanitized = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    return '${uid}_$sanitized';
  }
}
