import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/config/email_config.dart';
import 'package:money_tracker_app/services/email_service.dart';

void main() {
  group('EmailConfig.fromMap', () {
    test('đủ key -> isConfigured', () {
      final c = EmailConfig.fromMap({
        'SMTP_SENDER_EMAIL': ' bot@example.com ',
        'SMTP_APP_PASSWORD': 'abcdabcdabcdabcd',
        'SMTP_SENDER_NAME': 'Mono Test',
      });
      expect(c.isConfigured, isTrue);
      expect(c.senderEmail, 'bot@example.com');
      expect(c.senderName, 'Mono Test');
    });

    test('thiếu key -> chưa cấu hình', () {
      expect(EmailConfig.fromMap({}).isConfigured, isFalse);
      expect(
        EmailConfig.fromMap({'SMTP_SENDER_EMAIL': 'a@b.c'}).isConfigured,
        isFalse,
      );
      expect(
        EmailConfig.fromMap({'SMTP_APP_PASSWORD': 'x'}).isConfigured,
        isFalse,
      );
    });

    test('bỏ dấu cách trong App Password', () {
      final c = EmailConfig.fromMap({
        'SMTP_APP_PASSWORD': 'abcd efgh ijkl mnop',
      });
      expect(c.appPassword, 'abcdefghijklmnop');
    });

    test('tên người gửi mặc định khi trống', () {
      expect(
        EmailConfig.fromMap({'SMTP_SENDER_NAME': '  '}).senderName,
        EmailConfig.defaultSenderName,
      );
    });

    test('fromEnv khi dotenv chưa load -> rỗng, không throw', () {
      expect(EmailConfig.fromEnv().isConfigured, isFalse);
    });
  });

  test(
    'EmailService không cấu hình -> success false, không gửi mail',
    () async {
      final service = EmailService(
        config: const EmailConfig(senderEmail: '', appPassword: ''),
      );
      final res = await service.sendOtp(
        toEmail: 'user@example.com',
        otpCode: '123456',
      );
      expect(res.success, isFalse);
    },
  );
}
