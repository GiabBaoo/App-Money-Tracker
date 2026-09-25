import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';
import 'connectivity_service.dart';
import 'local_notification_service.dart';
import 'auth_service.dart';

/// Dịch vụ tự động sao lưu và đẩy dữ liệu lên Firebase vào mỗi giữa đêm (00:00).
///
/// Cơ chế bảo vệ đa lớp:
/// 1. Bộ đếm thời gian chính xác (Midnight Precision Timer) kích hoạt đúng lúc 00:00.
/// 2. Bù trừ tự động (Catch-up sync) khi mở lại app nếu máy tắt hoặc app ngủ lúc nửa đêm.
/// 3. Bắn thông báo xác nhận sao lưu an toàn ra thanh thông báo hệ thống.
class MidnightSyncService {
  MidnightSyncService._internal();
  static final MidnightSyncService instance = MidnightSyncService._internal();

  Timer? _midnightTimer;
  bool _isSyncing = false;
  static const String _prefLastMidnightSyncKey = 'mono_last_midnight_sync_date';

  /// Khởi tạo và lập lịch sao lưu nửa đêm
  void init() {
    _scheduleNextMidnightTimer();
    // Kiểm tra ngay khi khởi động xem có bỏ lỡ lần sao lưu nửa đêm hôm nay không
    checkAndRunCatchUpSync();
  }

  /// Tính toán thời gian tới 00:00:05 tiếp theo và lập lịch Timer
  void _scheduleNextMidnightTimer() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    // 5 giây sau nửa đêm để đảm bảo đồng hồ hệ thống đã qua ngày mới
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    final duration = nextMidnight.difference(now);

    debugPrint('MidnightSyncService: Next midnight sync scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m (at $nextMidnight)');

    _midnightTimer = Timer(duration, () async {
      debugPrint('MidnightSyncService: 00:00 Midnight reached! Triggering auto-sync...');
      await triggerMidnightSync(isCatchUp: false);
      // Tiếp tục lập lịch cho nửa đêm tiếp theo
      _scheduleNextMidnightTimer();
    });
  }

  /// Kích hoạt tiến trình sao lưu nửa đêm
  Future<bool> triggerMidnightSync({bool isCatchUp = false}) async {
    if (_isSyncing) return false;

    final uid = AuthService().currentUid;
    if (uid == null) {
      debugPrint('MidnightSyncService: No logged in user, skipping midnight sync.');
      return false;
    }

    final isOnline = ConnectivityService().isOnline;
    if (!isOnline) {
      debugPrint('MidnightSyncService: Device is offline at midnight. Will sync when network is restored.');
      return false;
    }

    _isSyncing = true;
    try {
      debugPrint('MidnightSyncService: Starting midnight full backup to Firebase...');
      final success = await SyncService().syncAll();

      if (success) {
        final now = DateTime.now();
        final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastMidnightSyncKey, todayStr);

        // Bắn thông báo xác nhận thành công ra thanh trạng thái
        await LocalNotificationService.instance.showInstantNotification(
          id: 777000,
          title: '🌙 Sao lưu nửa đêm thành công',
          body: isCatchUp
              ? 'Dữ liệu chi tiêu của bạn đã được cập nhật và lưu trữ an toàn trên Firebase.'
              : 'Đúng 00:00, Mono đã tự động sao lưu toàn bộ dữ liệu của bạn lên đám mây.',
          payload: 'midnight_backup',
        );
        debugPrint('MidnightSyncService: Midnight sync succeeded and recorded for $todayStr');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('MidnightSyncService: Error during midnight sync: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Kiểm tra bù trừ: Nếu hôm nay chưa chạy sao lưu nửa đêm (ví dụ app bị đóng), chạy bù ngay
  Future<void> checkAndRunCatchUpSync() async {
    try {
      final uid = AuthService().currentUid;
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString(_prefLastMidnightSyncKey);

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Nếu ngày lưu lần cuối khác hôm nay, tức là chưa thực hiện sao lưu của ngày mới
      if (lastSyncDate != todayStr) {
        debugPrint('MidnightSyncService: Catch-up sync triggered (Last: $lastSyncDate, Today: $todayStr)');
        await triggerMidnightSync(isCatchUp: true);
      }
    } catch (e) {
      debugPrint('MidnightSyncService: checkAndRunCatchUpSync error: $e');
    }
  }

  /// Hủy timer khi không cần dùng (hoặc đăng xuất)
  void dispose() {
    _midnightTimer?.cancel();
  }
}
