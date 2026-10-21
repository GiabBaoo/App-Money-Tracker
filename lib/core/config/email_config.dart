import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cấu hình SMTP đọc lúc runtime từ `.env` (không hardcode trong mã nguồn).
/// Xem `.env.example` để biết các key cần khai báo.
class EmailConfig {
  static const String defaultSenderName = 'Mono App';

  final String senderEmail;
  final String appPassword;
  final String senderName;

  const EmailConfig({
    required this.senderEmail,
    required this.appPassword,
    this.senderName = defaultSenderName,
  });

  bool get isConfigured => senderEmail.isNotEmpty && appPassword.isNotEmpty;

  factory EmailConfig.fromMap(Map<String, String> env) {
    final name = env['SMTP_SENDER_NAME']?.trim() ?? '';
    return EmailConfig(
      senderEmail: env['SMTP_SENDER_EMAIL']?.trim() ?? '',
      // Google hiển thị App Password dạng "xxxx xxxx xxxx xxxx"
      appPassword: env['SMTP_APP_PASSWORD']?.replaceAll(' ', '') ?? '',
      senderName: name.isNotEmpty ? name : defaultSenderName,
    );
  }

  factory EmailConfig.fromEnv() =>
      EmailConfig.fromMap(dotenv.isInitialized ? dotenv.env : const {});
}
