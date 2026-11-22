import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/app_theme.dart';
import '../services/connectivity_service.dart';
import '../services/language_service.dart';
import '../services/location_service.dart';
import '../services/place_name_resolver.dart';
import 'mini_location_map.dart';
import 'mono_dialog.dart';
import 'top_toast.dart';

/// Kết quả trả về từ [LocationPickerSheet].
class LocationPickerResult {
  final String? placeName;
  final double? latitude;
  final double? longitude;
  final bool removed;

  const LocationPickerResult({
    this.placeName,
    this.latitude,
    this.longitude,
    this.removed = false,
  });
}

/// Bottom sheet chọn vị trí giao dịch mô phỏng trải nghiệm tìm kiếm Google Maps:
/// - Gợi ý tức thì địa điểm gần đây (0ms, hỗ trợ cả offline)
/// - Debounce 220ms, tìm kiếm đa tầng (Google Places / Goong / ArcGIS POI / Photon / Nominatim)
/// - Hiển thị 2 dòng tách biệt (Tên quán nổi bật + Địa chỉ đầy đủ) kèm in đậm từ khóa không dấu
/// - Nút mũi tên chéo điền nhanh từ khóa giống Google Maps + resolve tọa độ chính xác khi chọn
class LocationPickerSheet extends StatefulWidget {
  final String? initialName;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerSheet({
    super.key,
    this.initialName,
    this.initialLatitude,
    this.initialLongitude,
  });

  static Future<LocationPickerResult?> show(
    BuildContext context, {
    String? initialName,
    double? initialLatitude,
    double? initialLongitude,
  }) {
    return showModalBottomSheet<LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        initialName: initialName,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final TextEditingController _controller;
  late final String _sessionToken;
  Timer? _debounce;
  bool _isLocatingGps = false;
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isOfflineHint = false;
  int? _resolvingIndex;
  int _searchSeq = 0;
  List<LocationResult> _recentPlaces = const [];
  List<LocationResult> _suggestions = const [];
  double? _userLat;
  double? _userLon;

  @override
  void initState() {
    super.initState();
    _sessionToken = const Uuid().v4();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _loadRecentPlaces();
    _prefetchUserCoordinates();
  }

  Future<void> _loadRecentPlaces() async {
    final recents = await LocationService.instance.getRecentPlaces();
    if (!mounted) return;
    setState(() => _recentPlaces = recents);
  }

  Future<void> _prefetchUserCoordinates() async {
    final coords = await LocationService.instance.getCurrentCoordinates(
      timeout: const Duration(seconds: 3),
    );
    if (!mounted || coords == null) return;
    _userLat = coords.latitude;
    _userLon = coords.longitude;
    // Nếu người dùng đã gõ từ khóa trước khi GPS kịp xong, tự động làm mới gợi ý theo vị trí gần nhất
    final currentQuery = _controller.text.trim();
    if (currentQuery.length >= 2 && _hasSearched && !_isSearching) {
      _performSearch(currentQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<LocationResult> _matchingRecents(String query) {
    final fQuery = PlaceNameResolver.foldVietnamese(query.trim());
    if (fQuery.isEmpty) return _recentPlaces;
    final tokens = fQuery
        .split(RegExp(r'[\s,\-/]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return _recentPlaces.where((place) {
      final fFull = PlaceNameResolver.foldVietnamese(place.placeName);
      return tokens.every((t) => fFull.contains(t));
    }).toList();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < 2) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
        _hasSearched = false;
        _isOfflineHint = false;
      });
      return;
    }

    // Hiển thị ngay kết quả khớp trong lịch sử gần đây (0ms) trong lúc chờ API
    final instantRecents = _matchingRecents(trimmed);
    if (instantRecents.isNotEmpty && _suggestions.isEmpty) {
      setState(() {
        _suggestions = instantRecents;
      });
    } else {
      // Cập nhật nút clear ngay khi gõ
      setState(() {});
    }

    _debounce = Timer(const Duration(milliseconds: 220), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return;

    final matchedRecents = _matchingRecents(query);

    if (!ConnectivityService().isOnline) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _isOfflineHint = true;
        _suggestions = matchedRecents;
      });
      return;
    }

    final seq = ++_searchSeq;
    setState(() {
      _isSearching = true;
      _isOfflineHint = false;
    });

    // Đảm bảo có tọa độ người dùng để ưu tiên chi nhánh gần nhất
    if (_userLat == null || _userLon == null) {
      final coords = await LocationService.instance.getCurrentCoordinates(
        timeout: const Duration(milliseconds: 1200),
      );
      if (coords != null) {
        _userLat = coords.latitude;
        _userLon = coords.longitude;
      }
    }

    final results = await LocationService.instance.searchAddress(
      query,
      limit: 8,
      nearLatitude: _userLat ?? widget.initialLatitude,
      nearLongitude: _userLon ?? widget.initialLongitude,
      sessionToken: _sessionToken,
    );
    if (!mounted || seq != _searchSeq) return;

    // Ghép địa điểm gần đây khớp từ khóa lên đầu (không trùng lặp)
    final merged = <LocationResult>[];
    final seen = <String>{};
    for (final r in matchedRecents.take(2)) {
      final key = PlaceNameResolver.foldVietnamese(r.placeName);
      if (seen.add(key)) merged.add(r);
    }
    for (final item in results) {
      final key = PlaceNameResolver.foldVietnamese(item.placeName);
      if (seen.add(key)) merged.add(item);
    }

    setState(() {
      _isSearching = false;
      _hasSearched = true;
      _suggestions = merged;
    });
  }

  Future<void> _onSelectSuggestion(
    LocationResult item,
    int index,
    bool isVi,
  ) async {
    if (_resolvingIndex != null) return;
    HapticFeedback.selectionClick();

    LocationResult finalItem = item;
    if (item.requiresDetailLookup) {
      setState(() => _resolvingIndex = index);
      final resolved = await LocationService.instance.resolvePlaceDetail(
        item,
        sessionToken: _sessionToken,
        nearLatitude: _userLat ?? widget.initialLatitude,
        nearLongitude: _userLon ?? widget.initialLongitude,
      );
      if (!mounted) return;
      setState(() => _resolvingIndex = null);

      if (resolved != null) {
        finalItem = resolved;
      } else {
        // Không resolve được tọa độ -> vẫn trả về tên đầy đủ để không chặn người dùng
        await LocationService.instance.saveRecentPlace(item);
        if (!mounted) return;
        Navigator.pop(
          context,
          LocationPickerResult(placeName: item.placeName),
        );
        return;
      }
    }

    await LocationService.instance.saveRecentPlace(finalItem);
    if (!mounted) return;
    Navigator.pop(
      context,
      LocationPickerResult(
        placeName: finalItem.placeName,
        latitude: finalItem.latitude,
        longitude: finalItem.longitude,
      ),
    );
  }

  void _fillQueryFromSuggestion(LocationResult item) {
    HapticFeedback.selectionClick();
    final nextText = item.displayTitle;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
    _performSearch(nextText);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  IconData _iconForPlace(LocationResult item, bool isNearest) {
    if (item.provider == 'recent') return Icons.history_rounded;
    switch (item.category) {
      case 'cafe':
        return Icons.local_cafe_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shop':
        return Icons.storefront_rounded;
      case 'gas':
        return Icons.local_gas_station_rounded;
      case 'hospital':
        return Icons.local_pharmacy_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      default:
        return isNearest ? Icons.near_me_rounded : Icons.location_on_rounded;
    }
  }

  /// Tô đậm từ khóa trùng khớp không phân biệt dấu tiếng Việt (giống Google Maps).
  TextSpan _buildHighlightedSpan(
    String text,
    String query, {
    required TextStyle baseStyle,
    required TextStyle matchStyle,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final foldedText = PlaceNameResolver.foldVietnamese(text);
    final tokens = PlaceNameResolver.foldVietnamese(trimmedQuery)
        .split(RegExp(r'[\s,\-/]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final highlighted = List<bool>.filled(text.length, false);
    for (final token in tokens) {
      int start = 0;
      while (true) {
        final idx = foldedText.indexOf(token, start);
        if (idx < 0) break;
        final end = (idx + token.length).clamp(0, text.length);
        for (var i = idx; i < end; i++) {
          highlighted[i] = true;
        }
        start = idx + token.length;
      }
    }

    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final isMatch = highlighted[i];
      int j = i + 1;
      while (j < text.length && highlighted[j] == isMatch) {
        j++;
      }
      spans.add(
        TextSpan(
          text: text.substring(i, j),
          style: isMatch ? matchStyle : baseStyle,
        ),
      );
      i = j;
    }

    return TextSpan(children: spans);
  }

  Future<void> _handleGpsLocate(bool isVi) async {
    setState(() => _isLocatingGps = true);

    final isServiceEnabled = await LocationService.instance
        .isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (!mounted) return;
      setState(() => _isLocatingGps = false);
      _showGpsDisabledDialog(isVi);
      return;
    }

    var perm = await LocationService.instance.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await LocationService.instance.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _isLocatingGps = false);
      _showPermissionPermanentlyDeniedDialog(isVi);
      return;
    }

    if (perm == LocationPermission.denied) {
      if (!mounted) return;
      setState(() => _isLocatingGps = false);
      TopToast.show(
        context,
        isVi ? 'Chưa cấp quyền vị trí' : 'Location permission denied',
        isError: true,
      );
      return;
    }

    final res = await LocationService.instance.getCurrentPlaceName(
      timeout: const Duration(seconds: 5),
    );

    if (!mounted) return;
    setState(() => _isLocatingGps = false);

    if (res != null) {
      await LocationService.instance.saveRecentPlace(res);
      if (!mounted) return;
      Navigator.pop(
        context,
        LocationPickerResult(
          placeName: res.placeName,
          latitude: res.latitude,
          longitude: res.longitude,
        ),
      );
    } else {
      TopToast.show(
        context,
        isVi
            ? 'Không thể lấy vị trí. Vui lòng nhập tay.'
            : 'Could not locate. Please enter manually.',
        isError: true,
      );
    }
  }

  Future<void> _showGpsDisabledDialog(bool isVi) async {
    final open = await MonoDialog.confirm(
      context,
      title: isVi ? 'Dịch vụ vị trí đang tắt' : 'Location Services Disabled',
      message: isVi
          ? 'Vui lòng bật GPS trên thiết bị để ứng dụng tự động lấy địa danh.'
          : 'Please enable GPS on your device to automatically detect place names.',
      cancelText: isVi ? 'Đóng' : 'Close',
      confirmText: isVi ? 'Mở cài đặt' : 'Open Settings',
      icon: Icons.location_off_rounded,
    );
    if (open == true) {
      LocationService.instance.openLocationSettings();
    }
  }

  Future<void> _showPermissionPermanentlyDeniedDialog(bool isVi) async {
    final open = await MonoDialog.confirm(
      context,
      title: isVi ? 'Quyền vị trí bị chặn' : 'Location Permission Denied',
      message: isVi
          ? 'Bạn đã từ chối quyền vị trí vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.'
          : 'Location permission is permanently denied. Please grant permission in App Settings.',
      cancelText: isVi ? 'Để sau' : 'Later',
      confirmText: isVi ? 'Mở Cài đặt' : 'Open Settings',
      icon: Icons.location_disabled_rounded,
    );
    if (open == true) {
      LocationService.instance.openAppSettings();
    }
  }

  Widget _buildPlaceList(
    List<LocationResult> items, {
    required bool isVi,
    required bool isRecentMode,
  }) {
    final query = _controller.text.trim();
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: context.inputBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 58,
          color: context.dividerColor,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          final isRecent = item.provider == 'recent';
          final isNearest =
              !isRecentMode &&
              !isRecent &&
              index == 0 &&
              item.distanceMeters != null;
          final isResolving = _resolvingIndex == index;
          final badgeColor = isNearest
              ? const Color(0xFFF59E0B)
              : (isRecent ? context.textSecondaryColor : context.brandColor);
          final subtitle = item.displaySubtitle;

          return InkWell(
            onTap: () => _onSelectSuggestion(item, index, isVi),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cột trái: Icon địa điểm + khoảng cách (giống Google Maps)
                  SizedBox(
                    width: 42,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: isResolving
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: badgeColor,
                                  ),
                                )
                              : Icon(
                                  _iconForPlace(item, isNearest),
                                  color: badgeColor,
                                  size: 18,
                                ),
                        ),
                        if (item.distanceMeters != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _formatDistance(item.distanceMeters!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isNearest
                                  ? const Color(0xFFF59E0B)
                                  : context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cột giữa: Tên quán/địa điểm (highlight) + Địa chỉ đầy đủ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: _buildHighlightedSpan(
                                  item.displayTitle,
                                  isRecentMode ? '' : query,
                                  baseStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.textPrimaryColor,
                                  ),
                                  matchStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ),
                            if (isNearest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isVi ? 'Gần nhất' : 'Nearest',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: _buildHighlightedSpan(
                              subtitle,
                              isRecentMode ? '' : query,
                              baseStyle: TextStyle(
                                fontSize: 12,
                                color: context.textSecondaryColor,
                                height: 1.25,
                              ),
                              matchStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Cột phải: Xóa lịch sử (nếu là recent) hoặc mũi tên điền từ khóa (giống Google Maps)
                  if (isRecentMode)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: isVi ? 'Xóa khỏi gần đây' : 'Remove recent',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: context.textSecondaryColor,
                      ),
                      onPressed: () async {
                        await LocationService.instance.removeRecentPlace(
                          item.placeName,
                        );
                        await _loadRecentPlaces();
                      },
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: isVi ? 'Điền vào ô tìm kiếm' : 'Fill search',
                      icon: Icon(
                        Icons.north_west_rounded,
                        size: 17,
                        color: context.textSecondaryColor,
                      ),
                      onPressed: () => _fillQueryFromSuggestion(item),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final hasInitial =
        widget.initialName != null && widget.initialName!.trim().isNotEmpty;
    final queryEmpty = _controller.text.trim().length < 2;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi ? 'Vị trí giao dịch' : 'Transaction Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                if (hasInitial)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(isVi ? 'Xóa' : 'Remove'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(
                        context,
                        const LocationPickerResult(removed: true),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Ô nhập địa chỉ / tìm kiếm vị trí kiểu Google Maps
            TextField(
              controller: _controller,
              autofocus: !hasInitial,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: isVi
                    ? 'Tìm quán, địa chỉ (vd: Katinat Cao Thắng)...'
                    : 'Search place or address...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.brandColor,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: isVi ? 'Xóa nội dung' : 'Clear',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.textSecondaryColor,
                        ),
                        onPressed: () {
                          _debounce?.cancel();
                          _controller.clear();
                          setState(() {
                            _suggestions = const [];
                            _isSearching = false;
                            _hasSearched = false;
                            _isOfflineHint = false;
                          });
                        },
                      ),
                  ],
                ),
                filled: true,
                fillColor: context.inputBgColor,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.brandColor, width: 1.5),
                ),
              ),
              style: TextStyle(color: context.textPrimaryColor, fontSize: 14),
            ),

            // Thanh loading mảnh giống Google Maps (không gây giật layout)
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    color: context.brandColor,
                    backgroundColor: context.brandColor.withValues(alpha: 0.14),
                  ),
                ),
              ),

            // Thông báo khi mất mạng
            if (_isOfflineHint)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 15,
                      color: context.textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isVi
                            ? 'Cần kết nối mạng để tìm địa điểm mới'
                            : 'Internet connection required to search new places',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Danh sách gợi ý địa điểm (khi đang gõ)
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPlaceList(
                _suggestions,
                isVi: isVi,
                isRecentMode: false,
              ),
            ] else if (_hasSearched && !_isSearching) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  isVi
                      ? 'Không tìm thấy địa điểm phù hợp. Bạn có thể bấm "Áp dụng tên này" để lưu thủ công.'
                      : 'No matching place found. Tap "Apply this name" to save manually.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ] else if (queryEmpty && _recentPlaces.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  isVi ? 'Địa điểm gần đây' : 'Recent places',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
              _buildPlaceList(
                _recentPlaces.take(5).toList(),
                isVi: isVi,
                isRecentMode: true,
              ),
            ] else if (widget.initialLatitude != null &&
                widget.initialLongitude != null) ...[
              const SizedBox(height: 12),
              MiniLocationMap(
                latitude: widget.initialLatitude!,
                longitude: widget.initialLongitude!,
                placeName: widget.initialName,
                height: 130,
                showFooterBar: false,
              ),
            ],

            const SizedBox(height: 14),
            // Nút lấy tọa độ GPS tự động
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLocatingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded, size: 20),
              label: Text(
                _isLocatingGps
                    ? (isVi ? 'Đang xác định GPS...' : 'Locating GPS...')
                    : (isVi
                          ? 'Lấy vị trí GPS hiện tại'
                          : 'Get current GPS location'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _isLocatingGps ? null : () => _handleGpsLocate(isVi),
            ),
            const SizedBox(height: 10),
            // Nút lưu tên địa danh thủ công
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: context.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                final customName = _controller.text.trim();
                if (customName.isEmpty) {
                  Navigator.pop(
                    context,
                    const LocationPickerResult(removed: true),
                  );
                } else {
                  final unchanged = customName == widget.initialName?.trim();
                  Navigator.pop(
                    context,
                    LocationPickerResult(
                      placeName: customName,
                      latitude: unchanged ? widget.initialLatitude : null,
                      longitude: unchanged ? widget.initialLongitude : null,
                    ),
                  );
                }
              },
              child: Text(
                isVi ? 'Áp dụng tên này' : 'Apply this name',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
