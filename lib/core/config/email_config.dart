import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cấu hình Email service.
/// Lưu ý: Theo tiêu chuẩn Phase 1 Security, ứng dụng đã chuyển sang Firebase Auth Native SDK
/// để gửi email xác thực và đặt lại mật khẩu, không còn lưu trữ SMTP credentials trên client.
class EmailConfig {
  static const String defaultSenderName = 'Mono App';

  final String senderEmail;
  final String appPassword;
  final String senderName;

  const EmailConfig({
    this.senderEmail = '',
    this.appPassword = '',
    this.senderName = defaultSenderName,
  });

  bool get isConfigured => senderEmail.isNotEmpty && appPassword.isNotEmpty;

  factory EmailConfig.fromMap(Map<String, String> env) {
    final name = env['SMTP_SENDER_NAME']?.trim() ?? '';
    return EmailConfig(
      senderEmail: env['SMTP_SENDER_EMAIL']?.trim() ?? '',
      appPassword: env['SMTP_APP_PASSWORD']?.replaceAll(' ', '') ?? '',
      senderName: name.isNotEmpty ? name : defaultSenderName,
    );
  }

  factory EmailConfig.fromEnv() =>
      EmailConfig.fromMap(dotenv.isInitialized ? dotenv.env : const {});
}
