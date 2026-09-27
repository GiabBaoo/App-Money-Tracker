import 'package:flutter/material.dart';

/// Utility class cung cấp các hiệu ứng chuyển trang đẹp mắt, mượt mà (chuẩn Material 3 / iOS).
///
/// Tất cả transitions đều có:
/// - **Parallax exit**: trang cũ trượt nhẹ sang trái + mờ nhẹ khi trang mới vào
/// - **Optimized timing**: 300ms forward / 250ms reverse (sweet spot cho 60fps)
/// - **easeOutCubic curve**: mượt hơn fastOutSlowIn trên mobile
class PageTransitions {
  static const Duration _duration = Duration(milliseconds: 300);
  static const Duration _reverseDuration = Duration(milliseconds: 250);
  static const Curve _curve = Curves.easeOutCubic;
  static const Curve _reverseCurve = Curves.easeInCubic;

  /// Hiệu ứng trượt từ phải sang trái + mờ dần nhẹ + parallax exit
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildSlideRightTransition(animation, secondaryAnimation, child);
      },
    );
  }

  /// Hiệu ứng trượt từ dưới lên (dùng cho modal / thêm giao dịch) + parallax exit.
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);

        // Parallax exit cho trang cũ (đẩy nhẹ xuống + mờ)
        final secondaryCurved = CurvedAnimation(parent: secondaryAnimation, curve: _curve, reverseCurve: _reverseCurve);

        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 0.0), end: const Offset(0.0, -0.03))
              .animate(secondaryCurved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.92).animate(secondaryCurved),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(curved),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Hiệu ứng mờ dần (dùng cho auth flow, overlay)
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  /// Hiệu ứng phóng to (scale) + mờ dần (dùng cho Success Screen).
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Helper: Slide-right transition tái sử dụng với parallax exit
  static Widget _buildSlideRightTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);

    // Parallax exit: trang cũ trượt nhẹ sang trái + mờ nhẹ khi trang mới đẩy vào
    final secondaryCurved = CurvedAnimation(parent: secondaryAnimation, curve: _curve, reverseCurve: _reverseCurve);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.0, 0.0), end: const Offset(-0.15, 0.0))
          .animate(secondaryCurved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.88).animate(secondaryCurved),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.8, 0.0), end: Offset.zero).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      ),
    );
  }
}
