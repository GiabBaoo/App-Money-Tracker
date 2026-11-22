import 'dart:async';
import 'sync_service.dart';

/// Helper kích hoạt đồng bộ nền với debounce 2 giây (chỉ chạy khi online).
class SyncTrigger {
  SyncTrigger._();

  static Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  /// Yêu cầu đồng bộ sau 2 giây (gom nhiều thao tác liên tiếp thành 1 lượt sync).
  static void requestSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(SyncService().syncAll());
    });
  }

  /// Hủy timer đang chờ (dùng khi logout hoặc test).
  static void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
