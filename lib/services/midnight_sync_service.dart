import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/session/session_manager.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/message_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../firebase_options.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

/// Dịch vụ tự động sao lưu và đẩy dữ liệu lên Firebase vào mỗi nửa đêm (00:00).
///
/// Cơ chế bảo vệ:
/// 1. WorkManager trên Android đánh thức chạy ngầm lúc ~00:00 ngay cả khi đóng app.
/// 2. Bộ đếm thời gian trong bộ nhớ (Timer) làm phương án dự phòng khi app đang mở lúc 00:00.
/// 3. Chỉ sao lưu tự động trong khung giờ nửa đêm (00:00–02:59), không tạo bản sao lưu ban ngày khi mở app.
class MidnightSyncService {
  MidnightSyncService._internal();
  static final MidnightSyncService instance = MidnightSyncService._internal();

  Timer? _midnightTimer;
  bool _isSyncing = false;
  static const String _prefLastMidnightSyncKey = 'mono_last_midnight_sync_date';
  static const MethodChannel _settingsChannel = MethodChannel('app.mono/settings');

  static String dateKeyFor(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String dailyBackupIdForDate(String dateKey) => 'daily_$dateKey';

  static String formatDisplayDate(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Chỉ cho phép sao lưu tự động trong khung giờ nửa đêm (00:00–02:59)
  /// để tránh tạo bản sao lưu tự động vào ban ngày khi người dùng mới mở máy/app.
  static bool isWithinMidnightWindow(DateTime now) => now.hour < 3;

  static DateTime computeNextScheduleTime(
    DateTime now, {
    String? lastBackedUpDateKey,
  }) {
    final todayKey = dateKeyFor(now);
    final todayMidnight = DateTime(now.year, now.month, now.day, 0, 0, 5);
    if (now.isBefore(todayMidnight) && lastBackedUpDateKey != todayKey) {
      return todayMidnight;
    }
    return DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
  }

  /// Khởi tạo và lập lịch sao lưu tự động lúc nửa đêm (00:00)
  void init() {
    unawaited(_scheduleNextMidnightTimer());
    unawaited(_scheduleNativeMidnightWorker());
  }

  Future<void> _scheduleNativeMidnightWorker() async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
      await _settingsChannel.invokeMethod('scheduleMidnightBackup');
    } on MissingPluginException {
      // Bỏ qua trong môi trường unit test
    } catch (e) {
      debugPrint('MidnightSyncService: scheduleMidnightBackup error: $e');
    }
  }

  /// Tính toán thời gian tới 00:00:05 tiếp theo và lập lịch Timer khi app đang mở
  Future<void> _scheduleNextMidnightTimer() async {
    _midnightTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final lastSyncDate = prefs.getString(_prefLastMidnightSyncKey);
    final now = DateTime.now();
    final nextRun = computeNextScheduleTime(
      now,
      lastBackedUpDateKey: lastSyncDate,
    );
    final duration = nextRun.difference(now);

    debugPrint(
      'MidnightSyncService: Next midnight backup scheduled in ${duration.inHours}h ${duration.inMinutes % 60}m (at $nextRun)',
    );

    _midnightTimer = Timer(
      duration.isNegative ? Duration.zero : duration,
      () async {
        debugPrint(
          'MidnightSyncService: 00:00 Midnight reached! Triggering auto-sync...',
        );
        await triggerMidnightSync();
        await _scheduleNextMidnightTimer();
      },
    );
  }

  /// Kích hoạt tiến trình sao lưu tự động vào khung giờ nửa đêm
  Future<bool> triggerMidnightSync({
    String? dateKey,
    bool ignoreWindow = false,
  }) async {
    if (_isSyncing) return false;

    final now = DateTime.now();
    if (!ignoreWindow && !isWithinMidnightWindow(now)) {
      debugPrint(
        'MidnightSyncService: Outside midnight window (hour=${now.hour}), skipping auto backup.',
      );
      return false;
    }

    final uid = AuthService().currentUid;
    if (uid == null) {
      debugPrint(
        'MidnightSyncService: No logged in user, skipping midnight sync.',
      );
      return false;
    }

    final isOnline = ConnectivityService().isOnline;
    if (!isOnline) {
      final hasNet = await ConnectivityService().checkRealInternet();
      if (!hasNet) {
        debugPrint(
          'MidnightSyncService: Device is offline. Skipping midnight backup.',
        );
        return false;
      }
    }

    _isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString(_prefLastMidnightSyncKey);
      final targetDateKey = dateKey ?? dateKeyFor(now);

      if (lastSyncDate == targetDateKey) {
        debugPrint(
          'MidnightSyncService: Daily backup already recorded locally for $targetDateKey.',
        );
        return true;
      }

      final backupId = dailyBackupIdForDate(targetDateKey);
      debugPrint('MidnightSyncService: Checking cloud backup $backupId...');

      bool success;
      if (await SyncService().hasCloudBackup(backupId)) {
        // Máy khác hoặc worker khác đã sao lưu ngày này rồi -> chỉ đồng bộ 2 chiều, không ghi đè snapshot
        success = await SyncService().syncAll();
      } else {
        success = await SyncService().createCloudBackupSnapshot(
          label: 'Sao lưu tự động • ${formatDisplayDate(targetDateKey)}',
          backupId: backupId,
          backupType: CloudBackupType.autoDaily,
          dateKey: targetDateKey,
        );
        if (!success) {
          success = await SyncService().syncAll();
        }
      }

      if (success) {
        await prefs.setString(_prefLastMidnightSyncKey, targetDateKey);
        debugPrint(
          'MidnightSyncService: Daily backup/sync succeeded for $targetDateKey',
        );
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

  /// Hủy timer khi không cần dùng (hoặc đăng xuất)
  void dispose() {
    _midnightTimer?.cancel();
  }
}

/// Entrypoint chạy nền cho Android WorkManager vào lúc nửa đêm (00:00)
@pragma('vm:entry-point')
Future<void> midnightBackupBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  const channel = MethodChannel('app.mono/midnight_backup');
  var ok = false;

  try {
    final now = DateTime.now();
    if (!MidnightSyncService.isWithinMidnightWindow(now)) {
      ok = true;
      return;
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ok = true;
      return;
    }

    await ConnectivityService().init();
    await DatabaseHelper().database;

    final syncService = SyncService();
    syncService.init(
      transactionRepo: TransactionRepository(),
      walletRepo: WalletRepository(),
      userRepo: UserRepository(),
      notificationRepo: NotificationRepository(),
      messageRepo: MessageRepository(),
    );

    AuthService().setOnlineUid(currentUser.uid);
    SessionManager.instance.activate(currentUser.uid);

    ok = await MidnightSyncService.instance.triggerMidnightSync(
      dateKey: MidnightSyncService.dateKeyFor(now),
    );
  } catch (e) {
    debugPrint('midnightBackupBackgroundMain error: $e');
    ok = false;
  } finally {
    try {
      await channel.invokeMethod('complete', ok);
    } catch (_) {}
  }
}
