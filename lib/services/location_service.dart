import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'place_name_resolver.dart';

export 'place_name_resolver.dart' show LocationResult;

/// Service quản lý lấy tọa độ GPS, tìm kiếm địa điểm thông minh & lịch sử địa điểm gần đây
class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();
  factory LocationService() => instance;

  static const String _recentPlacesKey = 'recent_searched_locations_v1';
  static const int _maxRecentPlaces = 15;

  double? _cachedLat;
  double? _cachedLon;
  DateTime? _cachedAt;
  List<LocationResult>? _recentCache;

  /// Tìm vị trí (tên hiển thị + tọa độ) từ chuỗi địa chỉ người dùng nhập.
  /// Nếu truyền [nearLatitude]/[nearLongitude] (hoặc đã có cache GPS),
  /// kết quả sẽ ưu tiên các địa điểm khớp nhất & gần nhất.
  Future<List<LocationResult>> searchAddress(
    String query, {
    int limit = 8,
    bool preferVietnam = true,
    double? nearLatitude,
    double? nearLongitude,
    String? sessionToken,
  }) async {
    return PlaceNameResolver.instance.searchAddress(
      query,
      limit: limit,
      preferVietnam: preferVietnam,
      nearLatitude: nearLatitude ?? _cachedLat,
      nearLongitude: nearLongitude ?? _cachedLon,
      sessionToken: sessionToken,
    );
  }

  /// Lấy tọa độ & địa chỉ chi tiết cho gợi ý autocomplete (Google / Goong / ArcGIS suggest).
  Future<LocationResult?> resolvePlaceDetail(
    LocationResult candidate, {
    String? sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) async {
    return PlaceNameResolver.instance.resolvePlaceDetail(
      candidate,
      sessionToken: sessionToken,
      nearLatitude: nearLatitude ?? _cachedLat,
      nearLongitude: nearLongitude ?? _cachedLon,
    );
  }

  /// Lấy danh sách địa điểm người dùng đã chọn gần đây (0ms cache / SharedPreferences).
  Future<List<LocationResult>> getRecentPlaces() async {
    if (_recentCache != null) return List.unmodifiable(_recentCache!);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_recentPlacesKey) ?? const [];
      final parsed = <LocationResult>[];
      for (final item in rawList) {
        try {
          final map = jsonDecode(item);
          if (map is Map<String, dynamic>) {
            final loc = LocationResult.fromJson(map);
            if (loc.placeName.isNotEmpty) parsed.add(loc);
          }
        } catch (_) {}
      }
      _recentCache = parsed;
      return List.unmodifiable(parsed);
    } catch (e) {
      debugPrint('LocationService.getRecentPlaces error: $e');
      return const [];
    }
  }

  /// Lưu địa điểm vừa chọn lên đầu danh sách gần đây (giống Google Maps Recent).
  Future<void> saveRecentPlace(LocationResult place) async {
    if (place.placeName.trim().isEmpty) return;
    try {
      final current = List<LocationResult>.from(await getRecentPlaces());
      final normTarget = PlaceNameResolver.foldVietnamese(place.placeName);
      current.removeWhere(
        (e) => PlaceNameResolver.foldVietnamese(e.placeName) == normTarget,
      );
      current.insert(
        0,
        place.copyWith(provider: 'recent', requiresDetailLookup: false),
      );
      if (current.length > _maxRecentPlaces) {
        current.removeRange(_maxRecentPlaces, current.length);
      }
      _recentCache = current;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentPlacesKey,
        current.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('LocationService.saveRecentPlace error: $e');
    }
  }

  /// Xóa một địa điểm khỏi lịch sử gần đây.
  Future<void> removeRecentPlace(String placeName) async {
    try {
      final current = List<LocationResult>.from(await getRecentPlaces());
      final normTarget = PlaceNameResolver.foldVietnamese(placeName);
      current.removeWhere(
        (e) => PlaceNameResolver.foldVietnamese(e.placeName) == normTarget,
      );
      _recentCache = current;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentPlacesKey,
        current.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('LocationService.removeRecentPlace error: $e');
    }
  }

  /// Lấy nhanh tọa độ hiện tại (có cache 3 phút + fallback lastKnownPosition)
  /// phục vụ sắp xếp địa điểm tìm kiếm gần nhất mà không làm chậm UI.
  Future<({double latitude, double longitude})?> getCurrentCoordinates({
    Duration timeout = const Duration(seconds: 3),
    bool requestPermissionIfDenied = false,
  }) async {
    if (_cachedLat != null &&
        _cachedLon != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 3)) {
      return (latitude: _cachedLat!, longitude: _cachedLon!);
    }

    try {
      final isServiceEnabled = await isLocationServiceEnabled();
      if (!isServiceEnabled) return null;

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied &&
          requestPermissionIfDenied) {
        permission = await requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      // Ưu tiên lastKnownPosition nếu còn mới (< 10 phút) để phản hồi tức thì
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp) <
              const Duration(minutes: 10)) {
        _cachedLat = lastKnown.latitude;
        _cachedLon = lastKnown.longitude;
        _cachedAt = DateTime.now();
        return (latitude: lastKnown.latitude, longitude: lastKnown.longitude);
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        );
      } catch (_) {
        position = lastKnown;
      }

      if (position == null) return null;
      _cachedLat = position.latitude;
      _cachedLon = position.longitude;
      _cachedAt = DateTime.now();
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (e) {
      debugPrint('LocationService.getCurrentCoordinates error: $e');
      return null;
    }
  }

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
      if (permission == LocationPermission.denied &&
          requestPermissionIfDenied) {
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
        debugPrint(
          'LocationService.getCurrentPosition failed, trying last known position: $e',
        );
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('LocationService: Could not determine position');
        return null;
      }

      _cachedLat = position.latitude;
      _cachedLon = position.longitude;
      _cachedAt = DateTime.now();

      // 4. Phân giải tên địa danh bằng PlaceNameResolver
      String? resolvedName = await PlaceNameResolver.instance
          .resolveDisplayName(
            latitude: position.latitude,
            longitude: position.longitude,
          );

      final displayName =
          (resolvedName != null && resolvedName.trim().isNotEmpty)
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
