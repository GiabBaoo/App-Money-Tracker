import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/logging/app_logger.dart';
import 'package:money_tracker_app/services/language_service.dart';
import 'package:money_tracker_app/services/theme_service.dart';

void main() {
  group('Phase 4 Regression Tests: Architecture & Centralized Logging', () {
    setUp(() {
      AppLogger.clearBuffer();
    });

    tearDown(() {
      AppLogger.clearBuffer();
    });

    test('ARCH-01: AppLogger ring buffer stores at most 200 items and drops oldest on overflow', () {
      expect(AppLogger.diagnosticLogs, isEmpty);

      // Ghi 250 log entries liên tiếp
      for (int i = 1; i <= 250; i++) {
        AppLogger.info('Message item $i', tag: 'TestTag');
      }

      final logs = AppLogger.diagnosticLogs;
      // Kích thước tối đa của ring buffer không bao giờ vượt quá 200
      expect(logs.length, 200);

      // Bản ghi đầu tiên trong bộ đệm phải là item 51 (50 item đầu tiên đã bị drop theo FIFO)
      expect(logs.first.message, 'Message item 51');
      // Bản ghi cuối cùng phải là item 250
      expect(logs.last.message, 'Message item 250');
    });

    test('ARCH-02: AppLogger masks sensitive fields (email, password, token)', () {
      const sensitiveText = 'User testuser@gmail.com logged in with password: "SuperSecret123!" and token=abcxyz987';
      final redacted = AppLogger.redact(sensitiveText);

      // Email phải bị che mờ phần tên
      expect(redacted, contains('te***@gmail.com'));
      expect(redacted, isNot(contains('testuser@gmail.com')));

      // Password và token phải bị che
      expect(redacted, contains('password: [REDACTED]'));
      expect(redacted, isNot(contains('SuperSecret123!')));
    });

    test('ARCH-03: AppLogger clearBuffer() empties the diagnostic log store', () {
      AppLogger.warn('Warning 1', tag: 'Sync');
      AppLogger.error('Error 2', tag: 'Database');
      expect(AppLogger.diagnosticLogs.length, 2);

      AppLogger.clearBuffer();
      expect(AppLogger.diagnosticLogs, isEmpty);
    });

    test('ARCH-04: AppLogger records levels and stack traces accurately', () {
      final st = StackTrace.current;
      AppLogger.error(
        'Database write failed',
        tag: 'DatabaseHelper',
        error: 'Disk full exception',
        stackTrace: st,
      );

      final logs = AppLogger.diagnosticLogs;
      expect(logs.length, 1);
      final entry = logs.first;
      expect(entry.level, AppLogLevel.error);
      expect(entry.tag, 'DatabaseHelper');
      expect(entry.message, 'Database write failed');
      expect(entry.error, 'Disk full exception');
      expect(entry.stackTrace, isNotNull);
    });

    test('ARCH-05: LanguageService t() provides zero-tech-leak fallback', () {
      final service = LanguageService.instance;

      // Từ khóa chuẩn đã có trong từ điển
      expect(service.t('cancel'), isNotEmpty);
      expect(service.t('save'), isNotEmpty);

      // Từ khóa chưa có nhưng chứa hậu tố kỹ thuật _label / _hint
      final fallbackResult = service.t('wallet_name_label');
      // Fallback không bị lộ chuỗi _label trơ trọi nếu tìm được từ cha
      expect(fallbackResult, isNotEmpty);
      expect(fallbackResult, isNot(contains('_label')));
    });

    test('ARCH-06: ThemeService textScaleDisplayName maps scale factor cleanly', () {
      final theme = ThemeService();

      theme.setTextScaleFactor(0.85);
      expect(theme.textScaleDisplayName, contains('Nhỏ'));

      theme.setTextScaleFactor(1.0);
      expect(theme.textScaleDisplayName, contains('Tiêu chuẩn'));

      theme.setTextScaleFactor(1.15);
      expect(theme.textScaleDisplayName, contains('Lớn'));

      theme.setTextScaleFactor(1.30);
      expect(theme.textScaleDisplayName, contains('Rất lớn'));
    });
  });
}

