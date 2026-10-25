import 'package:flutter/foundation.dart';
import '../errors/business_exception.dart';

class DestructiveOpsGuard {
  /// Chỉ bật khi build với --dart-define=ENABLE_DESTRUCTIVE_OPS=true VÀ đang ở debug.
  static const bool _flag = bool.fromEnvironment('ENABLE_DESTRUCTIVE_OPS');
  static bool get enabled => kDebugMode && _flag;

  static void ensureEnabled(String op) {
    if (!enabled) {
      throw BusinessException(
        BusinessErrorCode.destructiveOpDisabled,
        '$op đã bị khóa ở bản phát hành',
      );
    }
  }
}
