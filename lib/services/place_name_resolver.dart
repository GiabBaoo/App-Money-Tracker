import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationResult {
  final String placeName;
  final String? title;
  final String? subtitle;
  final double latitude;
  final double longitude;
  final double? distanceMeters;
  final String? placeId;
  final String? provider;
  final String? category;
  final bool requiresDetailLookup;

  const LocationResult({
    required this.placeName,
    required this.latitude,
    required this.longitude,
    this.title,
    this.subtitle,
    this.distanceMeters,
    this.placeId,
    this.provider,
    this.category,
    this.requiresDetailLookup = false,
  });

  /// Tên chính hiển thị dòng đầu (giống Google Maps: tên quán / địa điểm).
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final idx = placeName.indexOf(',');
    if (idx > 0) return placeName.substring(0, idx).trim();
    return placeName.trim();
  }

  /// Địa chỉ đầy đủ hiển thị dòng phụ (số nhà, đường, phường, quận, thành phố).
  String? get displaySubtitle {
    final s = subtitle?.trim();
    if (s != null && s.isNotEmpty) return s;
    final idx = placeName.indexOf(',');
    if (idx > 0 && idx + 1 < placeName.length) {
      final rest = placeName.substring(idx + 1).trim();
      if (rest.isNotEmpty) return rest;
    }
    return null;
  }

  LocationResult copyWith({
    String? placeName,
    String? title,
    String? subtitle,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    String? placeId,
    String? provider,
    String? category,
    bool? requiresDetailLookup,
  }) {
    return LocationResult(
      placeName: placeName ?? this.placeName,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      placeId: placeId ?? this.placeId,
      provider: provider ?? this.provider,
      category: category ?? this.category,
      requiresDetailLookup: requiresDetailLookup ?? this.requiresDetailLookup,
    );
  }

  Map<String, dynamic> toJson() => {
    'placeName': placeName,
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'latitude': latitude,
    'longitude': longitude,
    if (category != null) 'category': category,
  };

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      placeName: (json['placeName'] as String? ?? '').trim(),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      provider: 'recent',
    );
  }

  @override
  String toString() =>
      'LocationResult(placeName: $placeName, lat: $latitude, lon: $longitude, dist: $distanceMeters)';
}

class _CacheEntry {
  final List<LocationResult> results;
  final DateTime createdAt;

  const _CacheEntry(this.results, this.createdAt);
}

/// Bộ máy tìm kiếm & phân giải địa điểm thông minh đa tầng (giống cơ chế Google Maps):
/// - Tầng 1 (nếu cấu hình API key trong .env): Google Places API (New) / Goong Maps v2
/// - Tầng 2 (miễn phí, hoạt động ngay không cần key):
///   ArcGIS World GeocodeServer (POI thương mại HERE/TomTom: Katinat, Hồng Trà Ngô Gia...)
///   + Photon (OSM location-biased) + Nominatim (OSM addressdetails=1)
/// - Tích hợp chuẩn hóa tiếng Việt không dấu, cache LRU 0ms, chấm điểm kết hợp
///   độ khớp từ khóa + khoảng cách GPS, và resolve chi tiết tọa độ khi chọn gợi ý.
class PlaceNameResolver {
  PlaceNameResolver._();
  static final PlaceNameResolver instance = PlaceNameResolver._();

  static const String _userAgent = 'MoneyTrackerApp/2.0 (Flutter)';
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const int _maxCacheEntries = 60;

  final Map<String, _CacheEntry> _searchCache = {};

  /// Đọc key từ .env an toàn (không ném lỗi nếu dotenv chưa init trong unit test).
  static String? _envKey(String name) {
    try {
      if (!dotenv.isInitialized) return null;
      final val = dotenv.env[name]?.trim();
      return (val != null && val.isNotEmpty) ? val : null;
    } catch (_) {
      return null;
    }
  }

  /// Bỏ dấu tiếng Việt 1-1 giữ nguyên độ dài chuỗi & chuyển chữ thường.
  /// Giúp so khớp và highlight chính xác vị trí ký tự (vd: "hong tra" -> "Hồng Trà").
  static String foldVietnamese(String input) {
    const map = <String, String>{
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
      'đ': 'd',
    };
    final lower = input.toLowerCase();
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  /// Mở rộng viết tắt phổ biến tại Việt Nam (q1 -> Quận 1, tphcm -> Hồ Chí Minh, ...).
  static String normalizeVietnameseQuery(String raw) {
    var q = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return q;

    q = q.replaceAllMapped(
      RegExp(r'\bq\.?\s*(\d{1,2})\b', caseSensitive: false),
      (m) => 'Quận ${m[1]}',
    );
    q = q.replaceAllMapped(
      RegExp(r'\bp\.?\s*(\d{1,2})\b', caseSensitive: false),
      (m) => 'Phường ${m[1]}',
    );
    q = q.replaceAll(
      RegExp(r'\b(tp\.?\s*hcm|tphcm|hcm|sg)\b', caseSensitive: false),
      'Hồ Chí Minh',
    );
    q = q.replaceAll(
      RegExp(r'\b(tp\.?\s*hn|tphn|hn)\b', caseSensitive: false),
      'Hà Nội',
    );
    return q;
  }

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
          (item) => item.requiresDetailLookup
              ? item
              : item.copyWith(
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
            !kept.requiresDetailLookup &&
            !candidate.requiresDetailLookup &&
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

  /// Chấm điểm tổng hợp giống Google Maps:
  /// 1. Độ khớp từ khóa tiếng Việt không dấu (prefix / đủ token trong title & address)
  /// 2. Độ tin cậy nguồn POI (Google > Goong > ArcGIS > Photon/Nominatim)
  /// 3. Khoảng cách GPS (ưu tiên chi nhánh gần nhất khi cùng khớp thương hiệu)
  static List<LocationResult> rankSmartResults(
    List<LocationResult> items, {
    required String query,
    double? userLat,
    double? userLon,
    int? limit,
  }) {
    if (items.isEmpty) return const [];

    final foldedQuery = foldVietnamese(query.trim());
    final tokens = foldedQuery
        .split(RegExp(r'[\s,\-/]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final enriched = items.map((item) {
      if (!item.requiresDetailLookup &&
          item.distanceMeters == null &&
          userLat != null &&
          userLon != null) {
        return item.copyWith(
          distanceMeters: distanceMetersBetween(
            userLat,
            userLon,
            item.latitude,
            item.longitude,
          ),
        );
      }
      return item;
    }).toList();

    double scoreOf(LocationResult item) {
      final fTitle = foldVietnamese(item.displayTitle);
      final fFull = foldVietnamese(item.placeName);

      double score = 0.0;

      // 1. Khớp nguyên cụm
      if (fTitle == foldedQuery) {
        score += 120.0;
      } else if (fTitle.startsWith(foldedQuery)) {
        score += 95.0;
      } else if (fTitle.contains(foldedQuery)) {
        score += 75.0;
      } else if (fFull.contains(foldedQuery)) {
        score += 55.0;
      }

      // 2. Độ phủ từng từ khóa (vd: "katinat" + "cao" + "thang")
      if (tokens.isNotEmpty) {
        int matchedInFull = 0;
        int matchedInTitle = 0;
        for (final token in tokens) {
          if (fFull.contains(token)) matchedInFull++;
          if (fTitle.contains(token)) matchedInTitle++;
        }
        final fullRatio = matchedInFull / tokens.length;
        final titleRatio = matchedInTitle / tokens.length;
        score += fullRatio * 70.0 + titleRatio * 35.0;
        if (matchedInFull == tokens.length) {
          score += 30.0; // Thưởng mạnh khi khớp ĐẦY ĐỦ tất cả từ khóa
        }
      }

      // 3. Có địa chỉ phụ đầy đủ (giống Google Maps)
      if ((item.displaySubtitle ?? '').length >= 8) {
        score += 12.0;
      }

      // 4. Chất lượng nguồn dữ liệu POI
      switch (item.provider) {
        case 'google':
          score += 35.0;
          break;
        case 'goong':
          score += 32.0;
          break;
        case 'arcgis':
          score += 22.0;
          break;
        case 'arcgis_suggest':
          score += 18.0;
          break;
        case 'photon':
          score += 10.0;
          break;
        case 'nominatim':
          score += 8.0;
          break;
      }

      // 5. Ưu tiên gần vị trí người dùng (decay mượt theo km)
      final dist = item.distanceMeters;
      if (dist != null) {
        final km = dist / 1000.0;
        score += 45.0 / (1.0 + km * 0.25);
      }

      return score;
    }

    final scored = enriched
        .map((item) => (item: item, score: scoreOf(item)))
        .toList();

    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return (a.item.distanceMeters ?? double.infinity).compareTo(
        b.item.distanceMeters ?? double.infinity,
      );
    });

    // Khử trùng lặp thông minh (cùng tọa độ <60m HOẶC cùng tên chuẩn hóa)
    final deduped = <LocationResult>[];
    final seenNames = <String>{};

    for (final entry in scored) {
      final candidate = entry.item;
      final normKey = foldVietnamese(
        '${candidate.displayTitle}|${candidate.displaySubtitle ?? ''}',
      ).replaceAll(RegExp(r'[^a-z0-9]'), '');

      final isCoordDup =
          !candidate.requiresDetailLookup &&
          deduped.any(
            (kept) =>
                !kept.requiresDetailLookup &&
                distanceMetersBetween(
                      kept.latitude,
                      kept.longitude,
                      candidate.latitude,
                      candidate.longitude,
                    ) <
                    60.0 &&
                (foldVietnamese(kept.displayTitle) ==
                        foldVietnamese(candidate.displayTitle) ||
                    distanceMetersBetween(
                          kept.latitude,
                          kept.longitude,
                          candidate.latitude,
                          candidate.longitude,
                        ) <
                        25.0),
          );

      if (isCoordDup) continue;
      if (normKey.isNotEmpty && !seenNames.add(normKey)) continue;

      // Nếu đã có bản resolved trùng title (từ findAddressCandidates) thì bỏ bản suggest chưa resolved
      if (candidate.requiresDetailLookup) {
        final fCandTitle = foldVietnamese(candidate.displayTitle);
        final alreadyHasResolved = deduped.any(
          (kept) =>
              !kept.requiresDetailLookup &&
              foldVietnamese(kept.displayTitle) == fCandTitle,
        );
        if (alreadyHasResolved) continue;
      }

      deduped.add(candidate);
      if (limit != null && deduped.length >= limit) break;
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

  /// Tìm kiếm địa điểm thông minh (autocomplete giống Google Maps).
  Future<List<LocationResult>> searchAddress(
    String query, {
    int limit = 8,
    bool preferVietnam = true,
    double? nearLatitude,
    double? nearLongitude,
    String? sessionToken,
  }) async {
    final raw = query.trim();
    if (raw.length < 2) return const [];

    final normalized = normalizeVietnameseQuery(raw);
    final cacheKey =
        '${foldVietnamese(normalized)}|${nearLatitude?.toStringAsFixed(2)}|${nearLongitude?.toStringAsFixed(2)}|$preferVietnam|$limit';

    final cached = _searchCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return cached.results;
    }

    List<LocationResult> finalResults = const [];

    // ═══ Tầng 1A: Google Places API (New) nếu có GOOGLE_PLACES_API_KEY ═══
    final googleKey = _envKey('GOOGLE_PLACES_API_KEY');
    if (googleKey != null) {
      final googleRes = await _googlePlacesAutocomplete(
        normalized,
        apiKey: googleKey,
        preferVietnam: preferVietnam,
        nearLat: nearLatitude,
        nearLon: nearLongitude,
        sessionToken: sessionToken,
      );
      if (googleRes.isNotEmpty) {
        finalResults = googleRes.take(limit).toList();
      }
    }

    // ═══ Tầng 1B: Goong Maps v2 (chuyên POI Việt Nam) nếu có GOONG_API_KEY ═══
    if (finalResults.isEmpty) {
      final goongKey = _envKey('GOONG_API_KEY');
      if (goongKey != null) {
        final goongRes = await _goongAutocomplete(
          normalized,
          apiKey: goongKey,
          limit: limit,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
        );
        if (goongRes.isNotEmpty) {
          finalResults = goongRes.take(limit).toList();
        }
      }
    }

    // ═══ Tầng 2: Đa nguồn miễn phí chạy song song (ArcGIS POI + Photon + Nominatim) ═══
    if (finalResults.isEmpty) {
      final fetchLimit = math.max(limit * 2, 12);
      final futures = <Future<List<LocationResult>>>[
        _arcgisFindCandidates(
          normalized,
          limit: fetchLimit,
          preferVietnam: preferVietnam,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
        ),
        _arcgisSuggest(
          normalized,
          limit: limit,
          preferVietnam: preferVietnam,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
        ),
        _photonSearch(
          normalized,
          limit: fetchLimit,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
          preferVietnam: preferVietnam,
        ),
        _nominatimSearch(
          normalized,
          limit: fetchLimit,
          countryCodes: preferVietnam ? 'vn' : null,
          nearLat: nearLatitude,
          nearLon: nearLongitude,
          bounded: false,
          radiusDeg: 0.35,
        ),
      ];

      final parallel = await Future.wait<List<LocationResult>>(futures);
      final merged = <LocationResult>[
        for (final list in parallel) ...list,
      ];

      if (merged.isNotEmpty) {
        finalResults = rankSmartResults(
          merged,
          query: normalized,
          userLat: nearLatitude,
          userLon: nearLongitude,
          limit: limit,
        );
      } else {
        // Fallback: thử lại không giới hạn quốc gia / native geocoder
        final fallback = await _nominatimSearch(normalized, limit: limit);
        if (fallback.isNotEmpty) {
          finalResults = rankSmartResults(
            fallback,
            query: normalized,
            userLat: nearLatitude,
            userLon: nearLongitude,
            limit: limit,
          );
        } else {
          final native = await _nativeForwardGeocode(normalized, limit: limit);
          finalResults = rankSmartResults(
            native,
            query: normalized,
            userLat: nearLatitude,
            userLon: nearLongitude,
            limit: limit,
          );
        }
      }
    }

    if (finalResults.isNotEmpty) {
      if (_searchCache.length >= _maxCacheEntries) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = _CacheEntry(finalResults, DateTime.now());
    }

    return finalResults;
  }

  /// Lấy tọa độ & địa chỉ đầy đủ cho gợi ý chưa có tọa độ (Google / Goong / ArcGIS suggest).
  Future<LocationResult?> resolvePlaceDetail(
    LocationResult candidate, {
    String? sessionToken,
    double? nearLatitude,
    double? nearLongitude,
  }) async {
    if (!candidate.requiresDetailLookup) return candidate;

    final placeId = candidate.placeId;
    if (candidate.provider == 'google' && placeId != null) {
      final apiKey = _envKey('GOOGLE_PLACES_API_KEY');
      if (apiKey != null) {
        final detail = await _googlePlaceDetail(
          placeId,
          apiKey: apiKey,
          sessionToken: sessionToken,
        );
        if (detail != null) return detail;
      }
    }

    if (candidate.provider == 'goong' && placeId != null) {
      final apiKey = _envKey('GOONG_API_KEY');
      if (apiKey != null) {
        final detail = await _goongPlaceDetail(placeId, apiKey: apiKey);
        if (detail != null) return detail;
      }
    }

    if (candidate.provider == 'arcgis_suggest' && placeId != null) {
      final detail = await _arcgisResolveMagicKey(
        candidate.placeName,
        magicKey: placeId,
        nearLat: nearLatitude,
        nearLon: nearLongitude,
      );
      if (detail != null) return detail;
    }

    // Fallback: geocode theo tên đầy đủ
    final fallback = await _arcgisFindCandidates(
      candidate.placeName,
      limit: 1,
      nearLat: nearLatitude,
      nearLon: nearLongitude,
    );
    if (fallback.isNotEmpty) return fallback.first;

    final nom = await _nominatimSearch(
      candidate.placeName,
      limit: 1,
      countryCodes: 'vn',
    );
    if (nom.isNotEmpty) return nom.first;

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 1A: GOOGLE PLACES API (NEW)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<LocationResult>> _googlePlacesAutocomplete(
    String query, {
    required String apiKey,
    bool preferVietnam = true,
    double? nearLat,
    double? nearLon,
    String? sessionToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'input': query,
        'languageCode': 'vi',
        if (preferVietnam) 'includedRegionCodes': ['vn'],
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        if (nearLat != null && nearLon != null) ...{
          'locationBias': {
            'circle': {
              'center': {'latitude': nearLat, 'longitude': nearLon},
              'radius': 30000.0,
            },
          },
          'origin': {'latitude': nearLat, 'longitude': nearLon},
        },
      };

      final uri = Uri.https(
        'places.googleapis.com',
        '/v1/places:autocomplete',
      );
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'suggestions.placePrediction.placeId,'
                  'suggestions.placePrediction.text,'
                  'suggestions.placePrediction.structuredFormat,'
                  'suggestions.placePrediction.distanceMeters,'
                  'suggestions.placePrediction.types',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final suggestions = decoded['suggestions'];
      if (suggestions is! List) return const [];

      final results = <LocationResult>[];
      for (final item in suggestions) {
        if (item is! Map<String, dynamic>) continue;
        final pred = item['placePrediction'];
        if (pred is! Map<String, dynamic>) continue;

        final placeId = pred['placeId'] as String?;
        final fullText = (pred['text']?['text'] as String?)?.trim() ?? '';
        final sf = pred['structuredFormat'] as Map<String, dynamic>?;
        final mainText = (sf?['mainText']?['text'] as String?)?.trim();
        final secondaryText =
            (sf?['secondaryText']?['text'] as String?)?.trim();
        final dist = (pred['distanceMeters'] as num?)?.toDouble();
        final types = (pred['types'] as List?)?.cast<String>() ?? const [];

        final placeName = fullText.isNotEmpty
            ? fullText
            : [
                if (mainText != null && mainText.isNotEmpty) mainText,
                if (secondaryText != null && secondaryText.isNotEmpty)
                  secondaryText,
              ].join(', ');
        if (placeName.isEmpty || placeId == null) continue;

        results.add(
          LocationResult(
            placeName: placeName,
            title: mainText,
            subtitle: secondaryText,
            latitude: 0.0,
            longitude: 0.0,
            distanceMeters: dist,
            placeId: placeId,
            provider: 'google',
            category: _inferCategoryFromTypes(types, placeName),
            requiresDetailLookup: true,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<LocationResult?> _googlePlaceDetail(
    String placeId, {
    required String apiKey,
    String? sessionToken,
  }) async {
    try {
      final params = <String, String>{
        'languageCode': 'vi',
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
      };
      final uri = Uri.https(
        'places.googleapis.com',
        '/v1/places/$placeId',
        params,
      );
      final res = await http
          .get(
            uri,
            headers: {
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is! Map<String, dynamic>) return null;
      final loc = map['location'] as Map<String, dynamic>?;
      final lat = (loc?['latitude'] as num?)?.toDouble();
      final lon = (loc?['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final name = (map['displayName']?['text'] as String?)?.trim();
      final addr = (map['formattedAddress'] as String?)?.trim();
      final full = _combineTitleAndAddress(name, addr);

      return LocationResult(
        placeName: full,
        title: name,
        subtitle: addr,
        latitude: lat,
        longitude: lon,
        placeId: placeId,
        provider: 'google',
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 1B: GOONG MAPS API V2 (VIETNAM POI SPECIALIST)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<LocationResult>> _goongAutocomplete(
    String query, {
    required String apiKey,
    int limit = 8,
    double? nearLat,
    double? nearLon,
  }) async {
    try {
      final params = <String, String>{
        'input': query,
        'api_key': apiKey,
        'limit': limit.toString(),
        'more_compound': 'true',
      };
      if (nearLat != null && nearLon != null) {
        final locStr =
            '${nearLat.toStringAsFixed(6)},${nearLon.toStringAsFixed(6)}';
        params['location'] = locStr;
        params['origin'] = locStr;
      }

      final uri = Uri.https('rsapi.goong.io', '/v2/place/autocomplete', params);
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final preds = decoded['predictions'];
      if (preds is! List) return const [];

      final results = <LocationResult>[];
      for (final p in preds) {
        if (p is! Map<String, dynamic>) continue;
        final placeId = p['place_id'] as String?;
        final desc = (p['description'] as String?)?.trim() ?? '';
        final sf = p['structured_formatting'] as Map<String, dynamic>?;
        final mainText = (sf?['main_text'] as String?)?.trim();
        final secondaryText = (sf?['secondary_text'] as String?)?.trim();
        final dist = (p['distance_meters'] as num?)?.toDouble();
        if (desc.isEmpty || placeId == null) continue;

        results.add(
          LocationResult(
            placeName: desc,
            title: mainText,
            subtitle: secondaryText,
            latitude: 0.0,
            longitude: 0.0,
            distanceMeters: dist,
            placeId: placeId,
            provider: 'goong',
            category: _inferCategoryFromTypes(const [], desc),
            requiresDetailLookup: true,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<LocationResult?> _goongPlaceDetail(
    String placeId, {
    required String apiKey,
  }) async {
    try {
      final uri = Uri.https('rsapi.goong.io', '/v2/place/detail', {
        'place_id': placeId,
        'api_key': apiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final map = jsonDecode(res.body);
      if (map is! Map<String, dynamic>) return null;
      final result = map['result'] as Map<String, dynamic>?;
      final loc = result?['geometry']?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lon = (loc?['lng'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final name = (result?['name'] as String?)?.trim();
      final addr = (result?['formatted_address'] as String?)?.trim();
      final full = _combineTitleAndAddress(name, addr);

      return LocationResult(
        placeName: full,
        title: name,
        subtitle: addr,
        latitude: lat,
        longitude: lon,
        placeId: placeId,
        provider: 'goong',
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 2A: ARCGIS WORLD GEOCODER (FREE POI + ADDRESS AUTOCOMPLETE, NO KEY)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<LocationResult>> _arcgisFindCandidates(
    String query, {
    int limit = 10,
    bool preferVietnam = true,
    double? nearLat,
    double? nearLon,
  }) async {
    try {
      final params = <String, String>{
        'SingleLine': query,
        'f': 'json',
        'maxLocations': limit.toString(),
        'outFields': 'PlaceName,Place_addr,Type,ShortLabel,City,Subregion',
        'langCode': 'vi',
        'forStorage': 'false',
      };
      if (preferVietnam) {
        params['countryCode'] = 'VNM';
      }
      if (nearLat != null && nearLon != null) {
        // ArcGIS dùng định dạng lon,lat
        params['location'] =
            '${nearLon.toStringAsFixed(6)},${nearLat.toStringAsFixed(6)}';
      }

      final uri = Uri.https(
        'geocode.arcgis.com',
        '/arcgis/rest/services/World/GeocodeServer/findAddressCandidates',
        params,
      );
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final candidates = decoded['candidates'];
      if (candidates is! List) return const [];

      final results = <LocationResult>[];
      for (final c in candidates) {
        if (c is! Map<String, dynamic>) continue;
        final score = (c['score'] as num?)?.toDouble() ?? 0.0;
        if (score < 60.0) continue;

        final loc = c['location'] as Map<String, dynamic>?;
        final lon = (loc?['x'] as num?)?.toDouble();
        final lat = (loc?['y'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final attrs = c['attributes'] as Map<String, dynamic>? ?? const {};
        final placeNameAttr = (attrs['PlaceName'] as String?)?.trim() ?? '';
        final placeAddrAttr = (attrs['Place_addr'] as String?)?.trim() ?? '';
        final shortLabel = (attrs['ShortLabel'] as String?)?.trim() ?? '';
        final typeStr = (attrs['Type'] as String?)?.trim() ?? '';
        final rawAddress = (c['address'] as String?)?.trim() ?? '';

        String title = placeNameAttr.isNotEmpty
            ? placeNameAttr
            : (shortLabel.isNotEmpty ? shortLabel : rawAddress);
        String? subtitle = placeAddrAttr.isNotEmpty ? placeAddrAttr : null;

        if (subtitle == null && rawAddress.contains(',')) {
          final idx = rawAddress.indexOf(',');
          title = rawAddress.substring(0, idx).trim();
          subtitle = rawAddress.substring(idx + 1).trim();
        }

        final full = _combineTitleAndAddress(title, subtitle);
        if (full.isEmpty) continue;

        results.add(
          LocationResult(
            placeName: full,
            title: title,
            subtitle: subtitle,
            latitude: lat,
            longitude: lon,
            provider: 'arcgis',
            category: _inferCategoryFromTypes([typeStr], full),
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<List<LocationResult>> _arcgisSuggest(
    String query, {
    int limit = 8,
    bool preferVietnam = true,
    double? nearLat,
    double? nearLon,
  }) async {
    try {
      final params = <String, String>{
        'text': query,
        'f': 'json',
        'maxSuggestions': limit.toString(),
      };
      if (preferVietnam) {
        params['countryCode'] = 'VNM';
      }
      if (nearLat != null && nearLon != null) {
        params['location'] =
            '${nearLon.toStringAsFixed(6)},${nearLat.toStringAsFixed(6)}';
      }

      final uri = Uri.https(
        'geocode.arcgis.com',
        '/arcgis/rest/services/World/GeocodeServer/suggest',
        params,
      );
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final suggestions = decoded['suggestions'];
      if (suggestions is! List) return const [];

      final results = <LocationResult>[];
      for (final s in suggestions) {
        if (s is! Map<String, dynamic>) continue;
        if (s['isCollection'] == true) continue;

        final text = (s['text'] as String?)?.trim() ?? '';
        final magicKey = (s['magicKey'] as String?)?.trim();
        if (text.isEmpty || magicKey == null || magicKey.isEmpty) continue;

        String title = text;
        String? subtitle;
        final idx = text.indexOf(',');
        if (idx > 0) {
          title = text.substring(0, idx).trim();
          subtitle = text.substring(idx + 1).trim();
        }

        results.add(
          LocationResult(
            placeName: text,
            title: title,
            subtitle: subtitle,
            latitude: 0.0,
            longitude: 0.0,
            placeId: magicKey,
            provider: 'arcgis_suggest',
            category: _inferCategoryFromTypes(const [], text),
            requiresDetailLookup: true,
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<LocationResult?> _arcgisResolveMagicKey(
    String text, {
    required String magicKey,
    double? nearLat,
    double? nearLon,
  }) async {
    try {
      final params = <String, String>{
        'SingleLine': text,
        'magicKey': magicKey,
        'f': 'json',
        'maxLocations': '1',
        'outFields': 'PlaceName,Place_addr,Type,ShortLabel',
        'langCode': 'vi',
        'forStorage': 'false',
        'countryCode': 'VNM',
      };
      if (nearLat != null && nearLon != null) {
        params['location'] =
            '${nearLon.toStringAsFixed(6)},${nearLat.toStringAsFixed(6)}';
      }

      final uri = Uri.https(
        'geocode.arcgis.com',
        '/arcgis/rest/services/World/GeocodeServer/findAddressCandidates',
        params,
      );
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;

      final c = candidates.first as Map<String, dynamic>;
      final loc = c['location'] as Map<String, dynamic>?;
      final lon = (loc?['x'] as num?)?.toDouble();
      final lat = (loc?['y'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final attrs = c['attributes'] as Map<String, dynamic>? ?? const {};
      final name = (attrs['PlaceName'] as String?)?.trim() ?? '';
      final addr = (attrs['Place_addr'] as String?)?.trim() ?? '';
      final typeStr = (attrs['Type'] as String?)?.trim() ?? '';
      final rawAddr = (c['address'] as String?)?.trim() ?? text;

      final title = name.isNotEmpty ? name : rawAddr.split(',').first.trim();
      final subtitle = addr.isNotEmpty
          ? addr
          : (rawAddr.contains(',')
                ? rawAddr.substring(rawAddr.indexOf(',') + 1).trim()
                : null);

      return LocationResult(
        placeName: _combineTitleAndAddress(title, subtitle),
        title: title,
        subtitle: subtitle,
        latitude: lat,
        longitude: lon,
        provider: 'arcgis',
        category: _inferCategoryFromTypes([typeStr], '$title $subtitle'),
      );
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 2B: PHOTON & NOMINATIM (OSM)
  // ═══════════════════════════════════════════════════════════════════════════

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
          .timeout(const Duration(seconds: 6));
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

        final formatted = _formatPhotonStructured(props);
        if (formatted.full.isEmpty) continue;

        final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final osmVal = (props['osm_value'] as String?) ?? '';
        results.add(
          LocationResult(
            placeName: formatted.full,
            title: formatted.title,
            subtitle: formatted.subtitle,
            latitude: lat,
            longitude: lon,
            provider: 'photon',
            category: _inferCategoryFromTypes([osmVal], formatted.full),
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  ({String title, String? subtitle, String full}) _formatPhotonStructured(
    Map<String, dynamic> props,
  ) {
    final name = (props['name'] as String?)?.trim();
    final streetLine = [
      if (props['housenumber'] != null) '${props['housenumber']}'.trim(),
      if (props['street'] != null) '${props['street']}'.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    final addrParts = <String>[];
    void addPart(String? v) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return;
      if (addrParts.any((p) => p.toLowerCase() == t.toLowerCase())) return;
      addrParts.add(t);
    }

    String title;
    if (name != null && name.isNotEmpty) {
      title = name;
      addPart(streetLine);
    } else if (streetLine.isNotEmpty) {
      title = streetLine;
    } else {
      title =
          (props['district'] as String?)?.trim() ??
          (props['city'] as String?)?.trim() ??
          (props['state'] as String?)?.trim() ??
          '';
    }

    addPart(props['district'] as String?);
    addPart(props['locality'] as String?);
    addPart(props['city'] as String?);
    addPart(props['county'] as String?);
    addPart(props['state'] as String?);

    // Xóa phần trùng với title
    addrParts.removeWhere((p) => p.toLowerCase() == title.toLowerCase());

    final subtitle = addrParts.isEmpty ? null : addrParts.join(', ');
    final full = _combineTitleAndAddress(title, subtitle);
    return (title: title, subtitle: subtitle, full: full);
  }

  Future<List<LocationResult>> _nominatimSearch(
    String query, {
    int limit = 8,
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
        'addressdetails': '1',
        'namedetails': '1',
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
          .timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return const [];

      final decoded = jsonDecode(res.body);
      if (decoded is! List) return const [];

      final results = <LocationResult>[];
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final lat = double.tryParse('${item['lat'] ?? ''}');
        final lon = double.tryParse('${item['lon'] ?? ''}');
        if (lat == null || lon == null) continue;

        final formatted = _formatNominatimStructured(item);
        if (formatted.full.isEmpty) continue;

        final key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final typeStr = '${item['type'] ?? ''} ${item['class'] ?? ''}';
        results.add(
          LocationResult(
            placeName: formatted.full,
            title: formatted.title,
            subtitle: formatted.subtitle,
            latitude: lat,
            longitude: lon,
            provider: 'nominatim',
            category: _inferCategoryFromTypes([typeStr], formatted.full),
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  ({String title, String? subtitle, String full}) _formatNominatimStructured(
    Map<String, dynamic> item,
  ) {
    final namedetails = item['namedetails'] as Map<String, dynamic>?;
    final address = item['address'] as Map<String, dynamic>?;
    final displayName = (item['display_name'] as String?)?.trim() ?? '';

    final poiName =
        (namedetails?['name:vi'] as String?)?.trim() ??
        (namedetails?['name'] as String?)?.trim() ??
        (item['name'] as String?)?.trim();

    if (address == null) {
      final idx = displayName.indexOf(',');
      if (idx > 0) {
        final t = displayName.substring(0, idx).trim();
        final s = displayName.substring(idx + 1).trim();
        return (title: t, subtitle: s, full: displayName);
      }
      return (title: displayName, subtitle: null, full: displayName);
    }

    final streetLine = [
      if (address['house_number'] != null) '${address['house_number']}'.trim(),
      if (address['road'] != null) '${address['road']}'.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    final parts = <String>[];
    void addPart(String? v) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return;
      if (parts.any((p) => p.toLowerCase() == t.toLowerCase())) return;
      parts.add(t);
    }

    final title = (poiName != null && poiName.isNotEmpty)
        ? poiName
        : (streetLine.isNotEmpty
              ? streetLine
              : displayName.split(',').first.trim());

    if (streetLine.isNotEmpty &&
        streetLine.toLowerCase() != title.toLowerCase()) {
      addPart(streetLine);
    }
    addPart(address['quarter'] as String?);
    addPart(address['suburb'] as String?);
    addPart(address['neighbourhood'] as String?);
    addPart(address['city_district'] as String?);
    addPart(address['district'] as String?);
    addPart(address['county'] as String?);
    addPart(address['city'] as String?);
    addPart(address['town'] as String?);
    addPart(address['state'] as String?);

    parts.removeWhere((p) => p.toLowerCase() == title.toLowerCase());
    final subtitle = parts.isEmpty ? null : parts.join(', ');
    final full = _combineTitleAndAddress(title, subtitle);
    return (title: title, subtitle: subtitle, full: full);
  }

  static String _combineTitleAndAddress(String? title, String? address) {
    final t = title?.trim() ?? '';
    final a = address?.trim() ?? '';
    if (t.isEmpty) return a;
    if (a.isEmpty) return t;
    if (foldVietnamese(a).startsWith(foldVietnamese(t))) {
      return a;
    }
    return '$t, $a';
  }

  static String _inferCategoryFromTypes(List<String> types, String text) {
    final joined = foldVietnamese('${types.join(' ')} $text');
    if (joined.contains('cafe') ||
        joined.contains('coffee') ||
        joined.contains('ca phe') ||
        joined.contains('katinat') ||
        joined.contains('phuc long') ||
        joined.contains('highlands') ||
        joined.contains('starbucks') ||
        joined.contains('tra sua') ||
        joined.contains('hong tra') ||
        joined.contains('mixue') ||
        joined.contains('gong cha') ||
        joined.contains('tea')) {
      return 'cafe';
    }
    if (joined.contains('restaurant') ||
        joined.contains('food') ||
        joined.contains('pho') ||
        joined.contains('bun') ||
        joined.contains('com') ||
        joined.contains('nha hang') ||
        joined.contains('quan an') ||
        joined.contains('bakery') ||
        joined.contains('pizza') ||
        joined.contains('kfc') ||
        joined.contains('jollibee')) {
      return 'restaurant';
    }
    if (joined.contains('supermarket') ||
        joined.contains('convenience') ||
        joined.contains('shop') ||
        joined.contains('store') ||
        joined.contains('mall') ||
        joined.contains('bach hoa xanh') ||
        joined.contains('winmart') ||
        joined.contains('circle k') ||
        joined.contains('gs25') ||
        joined.contains('coopmart') ||
        joined.contains('aeon')) {
      return 'shop';
    }
    if (joined.contains('fuel') ||
        joined.contains('gas') ||
        joined.contains('petrol') ||
        joined.contains('cay xang')) {
      return 'gas';
    }
    if (joined.contains('hospital') ||
        joined.contains('pharmacy') ||
        joined.contains('benh vien') ||
        joined.contains('nha thuoc') ||
        joined.contains('long chau')) {
      return 'hospital';
    }
    if (joined.contains('bank') ||
        joined.contains('atm') ||
        joined.contains('ngan hang')) {
      return 'bank';
    }
    return 'place';
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
            provider: 'native',
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
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
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
