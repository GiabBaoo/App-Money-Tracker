import 'package:flutter/material.dart';

/// Utility class cung cấp các hiệu ứng chuyển trang đẹp mắt cho toàn bộ ứng dụng.
class PageTransitions {
  /// Hiệu ứng trượt từ phải sang trái + mờ dần (dùng cho đa số màn hình).
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Hiệu ứng trượt từ dưới lên (dùng cho modal / thêm giao dịch).
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.3, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  /// Hiệu ứng mờ dần (dùng cho splash → home, login, v.v.).
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
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
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}
