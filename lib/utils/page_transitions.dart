import 'package:flutter/material.dart';

/// Utility class cung cấp các hiệu ứng chuyển trang đẹp mắt, mượt mà (chuẩn Material 3 / iOS).
///
/// Tất cả transitions đều có:
/// - **Parallax exit**: trang cũ trượt nhẹ sang trái + mờ nhẹ khi trang mới vào
/// - **Optimized timing**: 300ms forward / 250ms reverse (sweet spot cho 60fps)
/// - **easeOutCubic curve**: mượt hơn fastOutSlowIn trên mobile
class PageTransitions {
  static const Duration _duration = Duration(milliseconds: 220);
  static const Duration _reverseDuration = Duration(milliseconds: 180);
  static const Curve _curve = Curves.easeOutCubic;
  static const Curve _reverseCurve = Curves.easeInCubic;

  /// Hiệu ứng trượt từ phải sang trái mượt mà, tối ưu phần cứng 60-120fps
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => RepaintBoundary(child: page),
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildSlideRightTransition(animation, secondaryAnimation, child);
      },
    );
  }

  /// Hiệu ứng trượt từ dưới lên (modal / thêm giao dịch) siêu tốc và mượt mà
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => RepaintBoundary(child: page),
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);
        final secondaryCurved = CurvedAnimation(parent: secondaryAnimation, curve: _curve, reverseCurve: _reverseCurve);

        return SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(0.0, -0.03)).animate(secondaryCurved),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.12), end: Offset.zero).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Hiệu ứng mờ dần nhẹ nhàng, nhanh chóng
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => RepaintBoundary(child: page),
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  /// Hiệu ứng phóng to (scale) dứt khoát
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => RepaintBoundary(child: page),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.2, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Helper: Slide-right transition mượt mà 120Hz, giảm tải GPU compositing
  static Widget _buildSlideRightTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);
    final secondaryCurved = CurvedAnimation(parent: secondaryAnimation, curve: _curve, reverseCurve: _reverseCurve);

    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.06, 0.0)).animate(secondaryCurved),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.20, 0.0), end: Offset.zero).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
