import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Màn hình căn chỉnh, thu phóng (Scale / Crop) và xoay ảnh đại diện trước khi lưu
class AvatarCropScreen extends StatefulWidget {
  final File imageFile;

  const AvatarCropScreen({super.key, required this.imageFile});

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final GlobalKey _cropAreaKey = GlobalKey();
  late final TransformationController _transformationController;

  double _currentScale = 1.0;
  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;

  static const double _cropSize = 280.0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _onScaleChangedFromSlider(double newScale) {
    _currentScale = newScale;
    final center = _cropSize / 2;
    final offset = center * (1 - newScale);
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, newScale)
      ..setEntry(1, 1, newScale)
      ..setEntry(0, 3, offset)
      ..setEntry(1, 3, offset);
    _transformationController.value = matrix;
    setState(() {});
  }

  void _resetTransform() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentScale = 1.0;
      _rotationQuarterTurns = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _rotateImage() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  Future<void> _handleApplyCrop() async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final boundary = _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Vùng ảnh chưa sẵn sàng để cắt');

      // Chụp ở tỷ lệ pixelRatio 2.0 để ảnh đạt độ nét cao ~ 560x560px
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Không thể chuyển đổi dữ liệu ảnh');

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${tempDir.path}/avatars');
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final croppedFile = File('${avatarsDir.path}/$fileName');
      await croppedFile.writeAsBytes(buffer, flush: true);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cắt ảnh: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1413),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1413),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 26),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Căn chỉnh ảnh đại diện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isProcessing
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Color(0xFF438883), strokeWidth: 2.5),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _handleApplyCrop,
                    icon: const Icon(Icons.check_rounded, color: Color(0xFF68AEA9), size: 20),
                    label: const Text(
                      'Áp dụng',
                      style: TextStyle(color: Color(0xFF68AEA9), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Gợi ý thao tác
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pinch_rounded, color: Color(0xFF68AEA9), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Dùng 2 ngón tay thu phóng hoặc kéo để căn mặt',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),

            // Khu vực xem và cắt ảnh tương tác
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Khung chứa ảnh được cắt (RepaintBoundary)
                    SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: RepaintBoundary(
                        key: _cropAreaKey,
                        child: ClipOval(
                          child: Container(
                            color: Colors.black,
                            child: InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 1.0,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(double.infinity),
                              clipBehavior: Clip.none,
                              onInteractionUpdate: (_) {
                                final scale = _transformationController.value.getMaxScaleOnAxis();
                                if ((scale - _currentScale).abs() > 0.05) {
                                  setState(() => _currentScale = scale.clamp(1.0, 5.0));
                                }
                              },
                              child: SizedBox(
                                width: _cropSize,
                                height: _cropSize,
                                child: RotatedBox(
                                  quarterTurns: _rotationQuarterTurns,
                                  child: Image.file(
                                    widget.imageFile,
                                    fit: BoxFit.cover,
                                    width: _cropSize,
                                    height: _cropSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Viền chỉ dẫn tròn và tâm căn chỉnh
                    IgnorePointer(
                      child: Container(
                        width: _cropSize,
                        height: _cropSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF438883),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF438883).withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Thanh điều khiển Zoom Slider và các nút thao tác
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF141F1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slider thu phóng
                  Row(
                    children: [
                      const Icon(Icons.remove_rounded, color: Colors.white60, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                            activeTrackColor: const Color(0xFF438883),
                            inactiveTrackColor: Colors.white12,
                            thumbColor: const Color(0xFF68AEA9),
                            overlayColor: const Color(0xFF438883).withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _currentScale.clamp(1.0, 5.0),
                            min: 1.0,
                            max: 5.0,
                            onChanged: _onScaleChangedFromSlider,
                          ),
                        ),
                      ),
                      const Icon(Icons.add_rounded, color: Colors.white60, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentScale.toStringAsFixed(1)}x',
                        style: const TextStyle(color: Color(0xFF68AEA9), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nút Xoay & Nút Đặt lại
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.rotate_right_rounded,
                        label: 'Xoay 90°',
                        onTap: _rotateImage,
                      ),
                      _buildActionButton(
                        icon: Icons.restart_alt_rounded,
                        label: 'Đặt lại',
                        onTap: _resetTransform,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
