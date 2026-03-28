import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

/// Ưu tiên địa chỉ đọc được (không hiển thị tọa độ thô).
class PlaceNameResolver {
  PlaceNameResolver._();
  static final PlaceNameResolver instance = PlaceNameResolver._();

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
          .get(
            uri,
            headers: {
              'User-Agent': 'MoneyTrackerApp/1.0 (Flutter)',
            },
          )
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
