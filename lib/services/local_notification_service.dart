import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Dịch vụ quản lý Thông báo Đẩy Cục bộ (Local Push Notifications) trên thiết bị
class LocalNotificationService {
  LocalNotificationService._internal();
  static final LocalNotificationService instance = LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'mono_financial_channel';
  static const String channelName = 'Thông báo tài chính Mono';
  static const String channelDescription = 'Cảnh báo chi tiêu, gợi ý số dư và nhắc nhở ghi chép mỗi ngày';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Khởi tạo plugin thông báo và timezone
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Khởi tạo dữ liệu múi giờ cho timezone scheduling (chuẩn múi giờ Việt Nam)
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (_) {}

      // 2. Cài đặt icon thông báo Android (sử dụng ic_launcher đã có trong res/mipmap)
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. Cài đặt iOS / macOS
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // 4. Tạo Notification Channel trên Android với độ ưu tiên cao nhất
      if (!kIsWeb && Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.createNotificationChannel(androidChannel);
      }

      _isInitialized = true;
      debugPrint('LocalNotificationService initialized successfully');
    } catch (e) {
      debugPrint('LocalNotificationService initialization error: $e');
    }
  }

  /// Xin quyền gửi thông báo từ người dùng (đặc biệt bắt buộc trên Android 13+)
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (!_isInitialized) await init();

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return true;
  }

  /// Kiểm tra trạng thái cấp quyền thông báo hiện tại
  Future<bool> checkPermissionStatus() async {
    if (kIsWeb) return false;
    if (!_isInitialized) await init();

    try {
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidImpl?.areNotificationsEnabled() ?? false;
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
    }
    return true;
  }

  /// Bắn thông báo ngay lập tức ra thanh trạng thái (Status Bar) & Màn hình khóa
  Future<void> showInstantNotification({
    int id = 1,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Thông báo Mono',
        styleInformation: BigTextStyleInformation(''),
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final safeId = (id & 0x7FFFFFFF);
      await _notificationsPlugin.show(
        safeId == 0 ? 1 : safeId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }

  /// Lập lịch thông báo thử nghiệm sau [delaySeconds] giây (để người dùng khóa màn hình và kiểm tra)
  Future<void> scheduleTestNotification({
    int id = 998,
    int delaySeconds = 5,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Thử nghiệm thông báo Mono',
        styleInformation: BigTextStyleInformation(''),
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      debugPrint('Test notification scheduled in $delaySeconds seconds successfully');
    } catch (e) {
      debugPrint('Error scheduling test notification: $e');
    }
  }

  /// Lập lịch thông báo định kỳ mỗi ngày (ví dụ 20:00 hàng ngày)
  Future<void> scheduleDailyReminder({
    int id = 100,
    int hour = 20,
    int minute = 0,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Thông báo Mono',
        styleInformation: BigTextStyleInformation(''),
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      // Tính toán thời điểm tiếp theo lúc hour:minute
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        // Fallback sang inexact nếu thiết bị chưa cho phép exact alarm
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      debugPrint('Daily reminder scheduled at $hour:$minute successfully');
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
    }
  }

  /// Lập lịch thông báo gợi ý chi tiêu hàng ngày (11:30)
  Future<void> scheduleDailyAdvice({
    int id = 201,
    int hour = 11,
    int minute = 30,
    required String title,
    required String body,
  }) async {
    await scheduleDailyReminder(
      id: id,
      hour: hour,
      minute: minute,
      title: title,
      body: body,
    );
  }

  /// Lập lịch thông báo báo cáo chi tiêu tuần (Chủ Nhật lúc hour:minute)
  Future<void> scheduleWeeklyReport({
    int id = 202,
    int dayOfWeek = DateTime.sunday, // 7
    int hour = 20,
    int minute = 30,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Báo cáo tuần Mono',
        styleInformation: BigTextStyleInformation(''),
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Tìm ngày Chủ Nhật tiếp theo
      while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      debugPrint('Weekly report scheduled at day $dayOfWeek $hour:$minute successfully');
    } catch (e) {
      debugPrint('Error scheduling weekly report: $e');
    }
  }

  /// Hủy thông báo theo ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Hủy toàn bộ thông báo và lịch hẹn
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
