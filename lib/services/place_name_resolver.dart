import 'dart:convert';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String placeName;
  final double latitude;
  final double longitude;
  final double? distanceMeters;

  const LocationResult({
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
  });

  LocationResult copyWith({
    String? placeName,
    double? latitude,
    double? longitude,
    double? distanceMeters,
  }) {
    return LocationResult(
      placeName: placeName ?? this.placeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  @override
  String toString() =>
      'LocationResult(placeName: $placeName, lat: $latitude, lon: $longitude, dist: $distanceMeters)';
}

/// Ưu tiên địa chỉ đọc được (không hiển thị tọa độ thô).
/// Hỗ trợ cả reverse geocoding (tọa độ -> địa chỉ) và forward geocoding (địa chỉ -> tọa độ).
class PlaceNameResolver {
  PlaceNameResolver._();
  static final PlaceNameResolver instance = PlaceNameResolver._();

  static const String _userAgent = 'MoneyTrackerApp/2.0 (Flutter)';

  /// Tính khoảng cách Haversine (mét) giữa 2 tọa độ GPS.
  static double distanceMetersBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Gộp trùng lặp (trong ~50m), gắn khoảng cách và sắp xếp gần nhất lên đầu.
  static List<LocationResult> rankByProximity(
    List<LocationResult> items, {
    required double userLat,
    required double userLon,
    int? limit,
  }) {
    final withDist = items
        .map(
          (item) => item.copyWith(
            distanceMeters: distanceMetersBetween(
              userLat,
              userLon,
              item.latitude,
              item.longitude,
            ),
          ),
        )
        .toList();

    withDist.sort(
      (a, b) => (a.distanceMeters ?? double.infinity).compareTo(
        b.distanceMeters ?? double.infinity,
      ),
    );

    final deduped = <LocationResult>[];
    for (final candidate in withDist) {
      final isDup = deduped.any(
        (kept) =>
            distanceMetersBetween(
              kept.latitude,
              kept.longitude,
              candidate.latitude,
              candidate.longitude,
            ) <
            50.0,
      );
      if (!isDup) {
        deduped.add(candidate);
        if (limit != null && deduped.length >= limit) break;
      }
    }
    return deduped;
  }

  Future<String?> resolveDisplayName({
    required double latitude,
    required double longitude,
  }) async {
    final fromPlacemark = await _fromPlacemark(latitude, longitude);
    if (fromPlacemark != null && fromPlacemark.trim().isNotEmpty) {
      return fromPlacemark.trim();
    }
    return _nominatimReverse(latitude, longitude);
  }

  /// Tìm danh sách vị trí (tên hiển thị + tọa độ) từ chuỗi địa chỉ/địa điểm nhập vào.
  /// Khi có [nearLatitude]/[nearLongitude], tự động ưu tiên & sắp xếp các địa điểm
  /// gần vị trí người dùng nhất (ví dụ gõ "Bách Hóa Xanh" -> ra cửa hàng gần nhất).
  Future<List<LocationResult>> searchAddress(
    String query, {
    int limit = 6,
    bool preferVietnam = true,
    double? nearLatitude,
    double? nearLongitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final hasUserLocation = nearLatitude != null && nearLongitude != null;
    final fetchLimit = math.max(limit * 2, 12);

    if (hasUserLocation) {
      // Chạy song song Photon (location-biased POI) + Nominatim trong bán kính ~25km
      final parallel = await Future.wait<List<LocationResult>>([
        _photonSearch(
          trimmed,
          limit: fetchLimit,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
          preferVietnam: preferVietnam,
        ),
        _nominatimSearch(
          trimmed,
          limit: fetchLimit,
          countryCodes: preferVietnam ? 'vn' : null,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
          bounded: true,
          radiusDeg: 0.25,
        ),
      ]);

      final localMerged = <LocationResult>[...parallel[0], ...parallel[1]];
      if (localMerged.isNotEmpty) {
        return rankByProximity(
          localMerged,
          userLat: nearLatitude,
          userLon: nearLongitude,
          limit: limit,
        );
      }

      // Fallback mở rộng toàn quốc (vẫn ưu tiên gần viewbox & sắp xếp theo khoảng cách)
      var wide = await _nominatimSearch(
        trimmed,
        limit: fetchLimit,
        countryCodes: preferVietnam ? 'vn' : null,
        nearLat: nearLatitude,
        nearLon: nearLongitude,
        bounded: false,
        radiusDeg: 0.5,
      );
      if (wide.isEmpty && preferVietnam) {
        wide = await _nominatimSearch(trimmed, limit: limit);
      }
      if (wide.isNotEmpty) {
        return rankByProximity(
          wide,
          userLat: nearLatitude,
          userLon: nearLongitude,
          limit: limit,
        );
      }

      final native = await _nativeForwardGeocode(trimmed, limit: limit);
      return rankByProximity(
        native,
        userLat: nearLatitude,
        userLon: nearLongitude,
        limit: limit,
      );
    }

    // Không có tọa độ người dùng: tìm Nominatim ưu tiên Việt Nam + fallback Photon / native
    List<LocationResult> results = await _nominatimSearch(
      trimmed,
      limit: limit,
      countryCodes: preferVietnam ? 'vn' : null,
    );

    if (results.isEmpty) {
      results = await _photonSearch(
        trimmed,
        limit: limit,
        preferVietnam: preferVietnam,
      );
    }

    if (results.isEmpty && preferVietnam) {
      results = await _nominatimSearch(trimmed, limit: limit);
    }

    if (results.isNotEmpty) return results;

    return _nativeForwardGeocode(trimmed, limit: limit);
  }

  Future<List<LocationResult>> _photonSearch(
    String query, {
    int limit = 10,
    double? nearLat,
    double? nearLon,
    bool preferVietnam = true,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'limit': limit.toString(),
      };
      if (nearLat != null && nearLon != null) {
        params['lat'] = nearLat.toStringAsFixed(6);
        params['lon'] = nearLon.toStringAsFixed(6);
      }

      final uri = Uri.https('photon.komoot.io', '/api', params);
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final features = decoded['features'];
      if (features is! List) return const [];

      final results = <LocationResult>[];
      final seen = <String>{};

      for (final f in features) {
        if (f is! Map<String, dynamic>) continue;
        final geom = f['geometry'];
        final props = f['properties'];
        if (geom is! Map<String, dynamic> || props is! Map<String, dynamic>) {
          continue;
        }
        final coords = geom['coordinates'];
        if (coords is! List || coords.length < 2) continue;
        final lon = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        if (preferVietnam) {
          final cc = (props['countrycode'] as String?)?.toLowerCase();
          if (cc != null && cc.isNotEmpty && cc != 'vn') continue;
        }

        final display = _formatPhotonProps(props);
        if (display.isEmpty) continue;

        final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        results.add(
          LocationResult(placeName: display, latitude: lat, longitude: lon),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  String _formatPhotonProps(Map<String, dynamic> props) {
    final parts = <String>[];
    void addPart(String? v) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return;
      if (parts.any((p) => p.toLowerCase() == t.toLowerCase())) return;
      parts.add(t);
    }

    addPart(props['name'] as String?);
    final streetLine = [
      if (props['housenumber'] != null) '${props['housenumber']}'.trim(),
      if (props['street'] != null) '${props['street']}'.trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    addPart(streetLine);
    addPart(props['district'] as String?);
    addPart(props['locality'] as String?);
    addPart(props['city'] as String?);
    addPart(props['county'] as String?);
    addPart(props['state'] as String?);
    addPart(props['country'] as String?);

    return parts.join(', ');
  }

  Future<List<LocationResult>> _nominatimSearch(
    String query, {
    int limit = 5,
    String? countryCodes,
    double? nearLat,
    double? nearLon,
    bool bounded = false,
    double radiusDeg = 0.25,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'accept-language': 'vi,en',
      };
      if (countryCodes != null && countryCodes.isNotEmpty) {
        params['countrycodes'] = countryCodes;
      }
      if (nearLat != null && nearLon != null) {
        final left = (nearLon - radiusDeg).toStringAsFixed(5);
        final top = (nearLat + radiusDeg).toStringAsFixed(5);
        final right = (nearLon + radiusDeg).toStringAsFixed(5);
        final bottom = (nearLat - radiusDeg).toStringAsFixed(5);
        params['viewbox'] = '$left,$top,$right,$bottom';
        if (bounded) {
          params['bounded'] = '1';
        }
      }

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];

      final results = <LocationResult>[];
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse('${item['lat'] ?? ''}');
        final lon = double.tryParse('${item['lon'] ?? ''}');
        final display = (item['display_name'] as String?)?.trim() ?? '';
        if (lat == null || lon == null || display.isEmpty) continue;

        final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        results.add(
          LocationResult(placeName: display, latitude: lat, longitude: lon),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<List<LocationResult>> _nativeForwardGeocode(
    String query, {
    int limit = 5,
  }) async {
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) return const [];

      final results = <LocationResult>[];
      final seen = <String>{};
      for (final loc in locations.take(limit)) {
        final key =
            '${loc.latitude.toStringAsFixed(4)},${loc.longitude.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final resolved = await _fromPlacemark(loc.latitude, loc.longitude);
        final displayName = (resolved != null && resolved.trim().isNotEmpty)
            ? resolved.trim()
            : query;
        results.add(
          LocationResult(
            placeName: displayName,
            latitude: loc.latitude,
            longitude: loc.longitude,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _fromPlacemark(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return null;
      return _formatPlacemark(marks.first);
    } catch (_) {
      return null;
    }
  }

  String? _formatPlacemark(Placemark p) {
    final parts = <String>[];

    final streetLine = [
      if (p.subThoroughfare != null && p.subThoroughfare!.trim().isNotEmpty)
        p.subThoroughfare!.trim(),
      if (p.thoroughfare != null && p.thoroughfare!.trim().isNotEmpty)
        p.thoroughfare!.trim(),
    ].join(' ').trim();

    if (streetLine.isNotEmpty) {
      parts.add(streetLine);
    } else if (p.street != null && p.street!.trim().isNotEmpty) {
      parts.add(p.street!.trim());
    }

    if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) {
      parts.add(p.subLocality!.trim());
    }
    if (p.locality != null && p.locality!.trim().isNotEmpty) {
      parts.add(p.locality!.trim());
    }
    if (p.administrativeArea != null &&
        p.administrativeArea!.trim().isNotEmpty) {
      parts.add(p.administrativeArea!.trim());
    }
    if (p.country != null && p.country!.trim().isNotEmpty) {
      parts.add(p.country!.trim());
    }

    if (parts.isEmpty && p.name != null && p.name!.trim().isNotEmpty) {
      return p.name!.trim();
    }

    final s = parts.join(', ').trim();
    return s.isEmpty ? null : s;
  }

  Future<String?> _nominatimReverse(double lat, double lon) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'accept-language': 'vi,en',
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'MoneyTrackerApp/1.0 (Flutter)'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is! Map<String, dynamic>) return null;
      final display = map['display_name'] as String?;
      final t = display?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }
}
