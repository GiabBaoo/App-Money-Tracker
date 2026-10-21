import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceUtils {
  static const String _installationIdKey = 'device_installation_id';
  static String? _cachedInstallationId;

  /// Lấy hoặc tạo mới UUID định danh duy nhất cho bản cài đặt thiết bị
  static Future<String> getInstallationId() async {
    if (_cachedInstallationId != null && _cachedInstallationId!.isNotEmpty) {
      return _cachedInstallationId!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_installationIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_installationIdKey, id);
      }
      _cachedInstallationId = id;
      return id;
    } catch (_) {
      // Fallback nếu storage gặp sự cố
      _cachedInstallationId ??= const Uuid().v4();
      return _cachedInstallationId!;
    }
  }

  static Future<Map<String, String>> getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    String deviceName = 'Thiết bị không xác định';
    String deviceType = 'mobile';
    final installId = await getInstallationId();

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
    return {
      'name': deviceName,
      'type': deviceType,
      'deviceId': installId,
    };
  }

  /// Lấy Session ID định danh duy nhất của phiên theo UID và installation UUID
  static Future<String> getSessionId(String uid) async {
    final installId = await getInstallationId();
    return '${uid}_$installId';
  }

  /// Tương thích ngược phiên bản cũ (dựa trên tên thiết bị)
  static String getLegacySessionId(String uid, String deviceName) {
    String sanitized = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    return '${uid}_$sanitized';
  }
}

