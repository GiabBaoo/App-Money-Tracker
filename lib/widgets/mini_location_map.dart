import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../services/language_service.dart';

/// Mini map hiển thị vị trí tọa độ trên nền bản đồ OpenStreetMap (không cần API key).
/// Dùng chung cho:
/// - Trang chi tiết giao dịch (TransactionDetailScreen)
/// - Trang ghi thu/chi thủ công (AddTransactionScreen)
/// - Trang chỉnh sửa giao dịch (EditTransactionScreen)
/// - Sheet chọn vị trí (LocationPickerSheet)
class MiniLocationMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? placeName;
  final double height;
  final int initialZoom;
  final bool showZoomControls;
  final bool showFooterBar;
  final String? actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const MiniLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.height = 156,
    this.initialZoom = 16,
    this.showZoomControls = true,
    this.showFooterBar = true,
    this.actionLabel,
    this.onTap,
    this.onClear,
  });

  /// Chuyển đổi (lat, lon, zoom) sang tọa độ tile thập phân theo chuẩn Web Mercator.
  @visibleForTesting
  static ({double x, double y}) latLonToTile(
    double lat,
    double lon,
    int zoom,
  ) {
    final clampedLat = lat.clamp(-85.05112878, 85.05112878);
    final n = math.pow(2, zoom).toDouble();
    final x = ((lon + 180.0) / 360.0) * n;
    final latRad = clampedLat * math.pi / 180.0;
    final y =
        (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        n;
    return (x: x, y: y);
  }

  /// Mở hộp thoại xem bản đồ phóng to hơn.
  static Future<void> showExpanded(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? placeName,
  }) {
    final isVi = LanguageScope.of(context).isVietnamese;
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.cardBgColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isVi ? 'Bản đồ vị trí' : 'Location Map',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ctx.textPrimaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: ctx.textSecondaryColor,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MiniLocationMap(
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                height: 320,
                initialZoom: 17,
                showZoomControls: true,
                showFooterBar: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<MiniLocationMap> createState() => _MiniLocationMapState();
}

class _MiniLocationMapState extends State<MiniLocationMap> {
  static const double _tileSize = 256.0;
  static const Map<String, String> _tileHeaders = {
    'User-Agent': 'MoneyTrackerApp/2.0 (Flutter)',
  };

  late int _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom.clamp(12, 18);
  }

  @override
  void didUpdateWidget(covariant MiniLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialZoom != widget.initialZoom) {
      _zoom = widget.initialZoom.clamp(12, 18);
    }
  }

  void _changeZoom(int delta) {
    final next = (_zoom + delta).clamp(12, 18);
    if (next == _zoom) return;
    HapticFeedback.selectionClick();
    setState(() => _zoom = next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasName =
        widget.placeName != null && widget.placeName!.trim().isNotEmpty;
    final displayText = hasName
        ? widget.placeName!.trim()
        : '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}';

    return Container(
      decoration: BoxDecoration(
        color: context.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vùng bản đồ tile OSM + Pin marker ở tâm
            GestureDetector(
              onTap: widget.onTap,
              child: SizedBox(
                width: double.infinity,
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Nền lưới fallback khi offline hoặc đang tải tile
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MapFallbackGridPainter(isDark: isDark),
                          ),
                        ),
                        // Lưới tile OpenStreetMap canh chính xác theo (lat, lon)
                        _buildTileLayer(width, height, isDark),
                        // Pin marker ở đúng tâm bản đồ
                        Positioned(
                          left: width / 2 - 20,
                          top: height / 2 - 38,
                          child: const _MapPinMarker(),
                        ),
                        // Attribution nhỏ gọn ở góc dưới trái
                        Positioned(
                          left: 8,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '© OpenStreetMap',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        // Nút Zoom +/- và nút Xóa ở góc trên phải
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.showZoomControls) ...[
                                _buildMapControlButton(
                                  icon: Icons.add_rounded,
                                  isDark: isDark,
                                  onTap: _zoom < 18
                                      ? () => _changeZoom(1)
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                _buildMapControlButton(
                                  icon: Icons.remove_rounded,
                                  isDark: isDark,
                                  onTap: _zoom > 12
                                      ? () => _changeZoom(-1)
                                      : null,
                                ),
                              ],
                              if (widget.onClear != null) ...[
                                const SizedBox(width: 6),
                                _buildMapControlButton(
                                  icon: Icons.close_rounded,
                                  isDark: isDark,
                                  iconColor: Colors.redAccent,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onClear?.call();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Thanh địa chỉ phía dưới bản đồ
            if (widget.showFooterBar)
              InkWell(
                onTap: widget.onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.cardBgColor,
                    border: Border(
                      top: BorderSide(color: context.borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            Text(
                              '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.actionLabel != null && widget.onTap != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.brandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.brandColor,
                            ),
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
  }

  Widget _buildTileLayer(double width, double height, bool isDark) {
    final n = 1 << _zoom;
    final tileCoords = MiniLocationMap.latLonToTile(
      widget.latitude,
      widget.longitude,
      _zoom,
    );
    final centerTileX = tileCoords.x.floor();
    final centerTileY = tileCoords.y.floor();
    final offsetX = (tileCoords.x - centerTileX) * _tileSize;
    final offsetY = (tileCoords.y - centerTileY) * _tileSize;

    final colsRadius = math.max(1, (width / (_tileSize * 2)).ceil());
    final rowsRadius = math.max(1, (height / (_tileSize * 2)).ceil());

    final tiles = <Widget>[];
    for (int dy = -rowsRadius; dy <= rowsRadius; dy++) {
      final ty = centerTileY + dy;
      if (ty < 0 || ty >= n) continue;

      for (int dx = -colsRadius; dx <= colsRadius; dx++) {
        final tx = ((centerTileX + dx) % n + n) % n;
        final left = width / 2 - offsetX + dx * _tileSize;
        final top = height / 2 - offsetY + dy * _tileSize;

        final url = 'https://tile.openstreetmap.org/$_zoom/$tx/$ty.png';
        tiles.add(
          Positioned(
            left: left,
            top: top,
            width: _tileSize,
            height: _tileSize,
            child: CachedNetworkImage(
              imageUrl: url,
              httpHeaders: _tileHeaders,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      }
    }

    Widget layer = Stack(clipBehavior: Clip.none, children: tiles);

    if (isDark) {
      // Giảm chói nhẹ cho Dark Mode nhưng vẫn giữ rõ tên đường & địa điểm
      layer = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.82, 0, 0, 0, -10,
          0, 0.82, 0, 0, -10,
          0, 0, 0.86, 0, -6,
          0, 0, 0, 1, 0,
        ]),
        child: layer,
      );
    }

    return Positioned.fill(child: layer);
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required bool isDark,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(
        alpha: 0.9,
      ),
      borderRadius: BorderRadius.circular(10),
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: enabled
                ? (iconColor ?? (isDark ? Colors.white : Colors.black87))
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}

class _MapPinMarker extends StatelessWidget {
  const _MapPinMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 44,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Vòng bóng định vị tại điểm chân ghim
          Positioned(
            bottom: 1,
            child: Container(
              width: 14,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          // Icon ghim đỏ/cam nổi bật có viền trắng
          const Positioned(
            bottom: 4,
            child: Icon(
              Icons.location_on_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const Positioned(
            bottom: 6,
            child: Icon(
              Icons.location_on_rounded,
              size: 34,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFallbackGridPainter extends CustomPainter {
  final bool isDark;

  const _MapFallbackGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFEAF0EC);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapFallbackGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
