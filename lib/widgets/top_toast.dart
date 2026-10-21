import 'package:flutter/material.dart';
import 'mono_toast.dart';

export 'mono_toast.dart' show MonoToastType, MonoToast;

/// Facade tương thích ngược cho TopToast, sử dụng kiến trúc MonoToast mới
class TopToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    MonoToast.show(
      context,
      message,
      type: isError ? MonoToastType.error : MonoToastType.success,
      duration: duration,
    );
  }

  static void success(BuildContext context, String message) {
    MonoToast.success(context, message);
  }

  static void error(BuildContext context, String message) {
    MonoToast.error(context, message);
  }

  static void warning(BuildContext context, String message) {
    MonoToast.warning(context, message);
  }

  static void info(BuildContext context, String message) {
    MonoToast.info(context, message);
  }
}
