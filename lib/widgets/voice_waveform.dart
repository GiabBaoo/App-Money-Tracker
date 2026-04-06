import 'dart:math';
import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 1500),
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
      height: 80,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: WavePainter(
              animationValue: _controller.value,
              isListening: widget.isListening,
              currentLevel: widget.currentLevel,
            ),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final bool isListening;
  final double currentLevel;

  WavePainter({
    required this.animationValue,
    required this.isListening,
    required this.currentLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isListening 
          ? const Color(0xFF438883).withOpacity(0.8) 
          : Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final int barCount = 30;
    final double spacing = 6.0;
    final double barWidth = 4.0;
    final double totalWidth = barCount * (barWidth + spacing);
    final double startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < barCount; i++) {
        double height = 6.0;
        if (isListening) {
            // Fluid organic movement
            double wave = sin((animationValue * 2 * pi) + (i * 0.4)) * 10;
            double boost = currentLevel * 45;
            height = (10 + wave + boost).clamp(6.0, size.height);
        }

        final x = startX + i * (barWidth + spacing);
        final y = (size.height - height) / 2;
        
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, barWidth, height),
                const Radius.circular(2),
            ),
            paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.currentLevel != currentLevel || 
           oldDelegate.isListening != isListening;
  }
}
