import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../core/config/email_config.dart';

class EmailService {
  /// Credentials đọc từ `.env` (xem `.env.example`). Inject [config] khi test.
  EmailService({EmailConfig? config}) : _config = config ?? EmailConfig.fromEnv();

  final EmailConfig _config;

  // Facade giữ tương thích với AuthService
  static Future<({bool success, String message})> sendOTPEmail({
    required String toEmail,
    required String otpCode,
  }) =>
      EmailService().sendOtp(toEmail: toEmail, otpCode: otpCode);

  // Gui email OTP
  Future<({bool success, String message})> sendOtp({
    required String toEmail,
    required String otpCode,
  }) async {
    if (!_config.isConfigured) {
      debugPrint('EmailService: thieu SMTP_SENDER_EMAIL / SMTP_APP_PASSWORD trong .env');
      return (success: false, message: 'Dich vu email chua duoc cau hinh.');
    }

    final smtpServer = gmail(_config.senderEmail, _config.appPassword);

    final message = Message()
      ..from = Address(_config.senderEmail, _config.senderName)
      ..recipients.add(toEmail)
      ..subject = 'Ma xac thuc OTP - Mono App'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 30px; background: #f8faf9; border-radius: 16px;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #438883; font-size: 32px; margin: 0;">mono</h1>
          </div>
          <div style="background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.06);">
            <h2 style="color: #333; font-size: 20px; margin-top: 0;">Ma xac thuc cua ban</h2>
            <p style="color: #666; font-size: 14px; line-height: 1.6;">
              Chao ban, day la ma OTP de xac thuc tai khoan cua ban tren ung dung Mono:
            </p>
            <div style="background: #e8f5f0; border: 2px solid #438883; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
              <span style="font-size: 36px; font-weight: bold; color: #438883; letter-spacing: 8px;">$otpCode</span>
            </div>
            <p style="color: #999; font-size: 13px;">
              Ma nay se het han sau <strong>5 phut</strong>. Vui long khong chia se ma nay voi bat ky ai.
            </p>
          </div>
          <p style="text-align: center; color: #aaa; font-size: 12px; margin-top: 20px;">
            Mono App - Quan ly chi tieu thong minh
          </p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      return (success: true, message: 'Email da duoc gui thanh cong!');
    } on MailerException catch (e) {
      debugPrint('Loi gui email: ${e.message}');
      return (success: false, message: 'Khong gui duoc email. Vui long thu lai.');
    } catch (e) {
      debugPrint('Loi: $e');
      return (success: false, message: 'Loi gui email: $e');
    }
  }
}
