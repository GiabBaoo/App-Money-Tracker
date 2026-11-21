import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';
import '../services/connectivity_service.dart';
import '../services/language_service.dart';
import '../services/location_service.dart';
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

/// Bottom sheet chọn vị trí giao dịch dùng chung cho Add/Edit Transaction:
/// - Nhập địa chỉ -> tự động gợi ý & xác định tọa độ (debounce + Nominatim / native geocoding)
/// - Lấy vị trí GPS hiện tại
/// - Hoặc áp dụng tên địa danh thủ công
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
  Timer? _debounce;
  bool _isLocatingGps = false;
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isOfflineHint = false;
  int _searchSeq = 0;
  List<LocationResult> _suggestions = const [];
  double? _userLat;
  double? _userLon;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _prefetchUserCoordinates();
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

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return;

    if (!ConnectivityService().isOnline) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _isOfflineHint = true;
        _suggestions = const [];
      });
      return;
    }

    final seq = ++_searchSeq;
    setState(() {
      _isSearching = true;
      _isOfflineHint = false;
    });

    // Đảm bảo có tọa độ người dùng để ưu tiên địa điểm gần nhất (vd: Bách Hóa Xanh gần nhất)
    if (_userLat == null || _userLon == null) {
      final coords = await LocationService.instance.getCurrentCoordinates(
        timeout: const Duration(seconds: 2),
      );
      if (coords != null) {
        _userLat = coords.latitude;
        _userLon = coords.longitude;
      }
    }

    final results = await LocationService.instance.searchAddress(
      query,
      nearLatitude: _userLat ?? widget.initialLatitude,
      nearLongitude: _userLon ?? widget.initialLongitude,
    );
    if (!mounted || seq != _searchSeq) return;

    setState(() {
      _isSearching = false;
      _hasSearched = true;
      _suggestions = results;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
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

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final hasInitial =
        widget.initialName != null && widget.initialName!.trim().isNotEmpty;

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
            // Ô nhập địa chỉ / tìm kiếm vị trí tự động
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: isVi
                    ? 'Nhập địa chỉ hoặc tên địa điểm để tự tìm...'
                    : 'Enter address or place name to search...',
                prefixIcon: Icon(
                  Icons.place_outlined,
                  color: context.brandColor,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearching)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.brandColor,
                          ),
                        ),
                      )
                    else ...[
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
                              _hasSearched = false;
                              _isOfflineHint = false;
                            });
                          },
                        ),
                      IconButton(
                        tooltip: isVi ? 'Tìm địa chỉ' : 'Search address',
                        icon: Icon(
                          Icons.search_rounded,
                          color: context.brandColor,
                        ),
                        onPressed: () => _performSearch(_controller.text),
                      ),
                    ],
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
                            ? 'Cần kết nối mạng để tự động xác định địa chỉ'
                            : 'Internet connection required to search addresses',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Danh sách gợi ý địa chỉ đã định vị tọa độ (ưu tiên gần nhất)
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: context.inputBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 44,
                    color: context.dividerColor,
                  ),
                  itemBuilder: (_, index) {
                    final item = _suggestions[index];
                    final isNearest = index == 0 && item.distanceMeters != null;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        isNearest
                            ? Icons.near_me_rounded
                            : Icons.location_on_rounded,
                        color: isNearest
                            ? const Color(0xFFF59E0B)
                            : context.brandColor,
                        size: 20,
                      ),
                      title: Text(
                        item.placeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isNearest
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          if (item.distanceMeters != null) ...[
                            Text(
                              _formatDistance(item.distanceMeters!),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isNearest
                                    ? const Color(0xFFF59E0B)
                                    : context.brandColor,
                              ),
                            ),
                            if (isNearest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
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
                          ] else
                            Text(
                              '${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondaryColor,
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(
                          context,
                          LocationPickerResult(
                            placeName: item.placeName,
                            latitude: item.latitude,
                            longitude: item.longitude,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ] else if (_hasSearched && !_isSearching) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  isVi
                      ? 'Không tìm thấy địa chỉ phù hợp. Bạn có thể bấm "Áp dụng tên này" để lưu thủ công.'
                      : 'No matching address found. You can tap "Apply this name" to save manually.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
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
