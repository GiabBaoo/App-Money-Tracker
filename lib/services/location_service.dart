import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'place_name_resolver.dart';

class LocationResult {
  final String placeName;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() =>
      'LocationResult(placeName: $placeName, lat: $latitude, lon: $longitude)';
}

/// Service quản lý lấy tọa độ GPS và phân giải tên địa danh
class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;

  /// Kiểm tra dịch vụ định vị phần cứng (GPS) có đang bật không
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService.isLocationServiceEnabled error: $e');
      return false;
    }
  }

  /// Kiểm tra quyền vị trí hiện tại
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('LocationService.checkPermission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Kiểm tra app đã được cấp quyền chưa (whileInUse hoặc always)
  Future<bool> hasPermission() async {
    final perm = await checkPermission();
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Yêu cầu cấp quyền vị trí
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('LocationService.requestPermission error: $e');
      return LocationPermission.denied;
    }
  }

  /// Mở cài đặt ứng dụng
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Mở cài đặt vị trí hệ thống (bật GPS)
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Lấy vị trí GPS và phân giải thành tên địa danh (PlaceNameResolver)
  /// Có cơ chế timeout an toàn tránh đứng luồng UI
  Future<LocationResult?> getCurrentPlaceName({
    Duration timeout = const Duration(seconds: 4),
    bool requestPermissionIfDenied = false,
  }) async {
    try {
      // 1. Kiểm tra GPS phần cứng
      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) {
        debugPrint('LocationService: GPS is disabled on device');
        return null;
      }

      // 2. Kiểm tra hoặc xin quyền
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied && requestPermissionIfDenied) {
        permission = await requestPermission();
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        debugPrint('LocationService: Permission not granted ($permission)');
        return null;
      }

      // 3. Lấy tọa độ GPS (getCurrentPosition kèm timeout, fallback về getLastKnownPosition)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        );
      } catch (e) {
        debugPrint('LocationService.getCurrentPosition failed, trying last known position: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('LocationService: Could not determine position');
        return null;
      }

      // 4. Phân giải tên địa danh bằng PlaceNameResolver
      String? resolvedName = await PlaceNameResolver.instance.resolveDisplayName(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final displayName = (resolvedName != null && resolvedName.trim().isNotEmpty)
          ? resolvedName.trim()
          : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      return LocationResult(
        placeName: displayName,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('LocationService.getCurrentPlaceName error: $e');
      return null;
    }
  }
}
