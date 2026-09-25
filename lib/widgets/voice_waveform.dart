import 'dart:math';
import 'package:flutter/material.dart';

/// Widget sóng âm thanh cao cấp với hiệu ứng sóng uốn lượn mượt mà & phản hồi theo âm lượng
class VoiceWaveform extends StatefulWidget {
  final bool isListening;
  final double currentLevel;

  const VoiceWaveform({
    super.key,
    required this.isListening,
    this.currentLevel = 0,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: SmoothWaveformPainter(
              animationValue: _controller.value,
              isListening: widget.isListening,
              soundLevel: widget.currentLevel,
            ),
          );
        },
      ),
    );
  }
}

class SmoothWaveformPainter extends CustomPainter {
  final double animationValue;
  final bool isListening;
  final double soundLevel;

  SmoothWaveformPainter({
    required this.animationValue,
    required this.isListening,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 36;
    const double barWidth = 4.0;
    const double spacing = 4.5;
    final double totalWidth = barCount * (barWidth + spacing) - spacing;
    final double startX = (size.width - totalWidth) / 2;
    final double centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      // Gaussian distribution for pleasant middle-heavy curve
      final double normalizedX = (i - (barCount / 2)) / (barCount / 2.6);
      final double envelope = exp(-0.5 * normalizedX * normalizedX);

      double height = 6.0;
      double alpha = 0.25;

      if (isListening) {
        // Multi-frequency sine waves
        final double phase1 = (animationValue * 2 * pi) + (i * 0.28);
        final double phase2 = (animationValue * 3 * pi) - (i * 0.35);
        final double dynamicWave = (sin(phase1) * 0.6 + cos(phase2) * 0.4);
        
        final double levelBoost = (soundLevel.clamp(0.0, 10.0) * 5.0) + (soundLevel > 0 ? 12.0 : 4.0);
        height = (8.0 + (envelope * levelBoost * (1.2 + dynamicWave))).clamp(6.0, size.height * 0.95);
        alpha = 0.6 + (envelope * 0.4);
      } else {
        height = 6.0 + (envelope * 4.0);
      }

      final double x = startX + i * (barWidth + spacing);
      final double top = centerY - (height / 2);

      final rect = Rect.fromLTWH(x, top, barWidth, height);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2));

      // Gradient fill from Teal to Mint Emerald
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF5EEAD4).withValues(alpha: alpha), // Mint
            const Color(0xFF14B8A6).withValues(alpha: alpha * 0.9), // Teal
            const Color(0xFF0F766E).withValues(alpha: alpha * 0.8), // Dark Emerald
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SmoothWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isListening != isListening ||
        oldDelegate.soundLevel != soundLevel;
  }
}
