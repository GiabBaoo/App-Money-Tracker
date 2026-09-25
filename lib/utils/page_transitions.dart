import 'package:flutter/material.dart';

/// Utility class cung cấp các hiệu ứng chuyển trang đẹp mắt, mượt mà (chuẩn Material 3 / iOS).
class PageTransitions {
  static const Duration _duration = Duration(milliseconds: 400);
  static const Duration _reverseDuration = Duration(milliseconds: 350);
  static const Curve _curve = Curves.fastOutSlowIn;
  static const Curve _reverseCurve = Curves.fastOutSlowIn;

  /// Hiệu ứng trượt từ phải sang trái + mờ dần nhẹ
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Hiệu ứng trượt từ dưới lên (dùng cho modal / thêm giao dịch).
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _curve, reverseCurve: _reverseCurve);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Hiệu ứng mờ dần
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  /// Hiệu ứng phóng to (scale) + mờ dần (dùng cho Success Screen).
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _duration,
      reverseTransitionDuration: _reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}
