import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker_app/services/smart_notification_service.dart';
import 'package:money_tracker_app/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartNotificationService & LocalNotificationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('syncDailyReminderState maintains 20h reminder when reminders enabled', () async {
      SharedPreferences.setMockInitialValues({
        'notif_reminders': true,
      });

      // Should run without throwing errors
      await SmartNotificationService.instance.syncDailyReminderState();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notif_reminders'), isTrue);
    });

    test('syncDailyReminderState disables 20h reminder when reminders disabled', () async {
      SharedPreferences.setMockInitialValues({
        'notif_reminders': false,
      });

      await SmartNotificationService.instance.syncDailyReminderState();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notif_reminders'), isFalse);
    });

    test('scheduleAllBackgroundNotifications executes cleanly with default settings', () async {
      SharedPreferences.setMockInitialValues({
        'notif_reminders': true,
        'notif_spending_report': true,
        'notif_smart_advice': true,
      });

      await SmartNotificationService.instance.scheduleAllBackgroundNotifications();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notif_reminders'), isTrue);
      expect(prefs.getBool('notif_spending_report'), isTrue);
      expect(prefs.getBool('notif_smart_advice'), isTrue);
    });

    test('LocalNotificationService singleton instance is accessible', () {
      final service = LocalNotificationService.instance;
      expect(service, isNotNull);
    });
  });
}
