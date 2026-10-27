import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/config/email_config.dart';

/// Service quản lý gửi email của ứng dụng.
/// Theo Phase 1 Security, toàn bộ luồng gửi email được chuyển sang Firebase Auth Native SDK
/// để đảm bảo không lưu trữ bất kỳ thông tin SMTP bí mật nào trong client bundle.
class EmailService {
  EmailService({EmailConfig? config})
      : _config = config ?? EmailConfig.fromEnv();

  // ignore: unused_field
  final EmailConfig _config;

  /// Gửi link đặt lại mật khẩu an toàn qua Firebase Auth Native
  static Future<({bool success, String message})> sendPasswordReset({
    required String email,
  }) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return (
        success: true,
        message: 'Email đặt lại mật khẩu đã được gửi đến $email.',
      );
    } on FirebaseAuthException catch (e) {
      return (success: false, message: e.message ?? 'Lỗi gửi email.');
    } catch (e) {
      return (success: false, message: 'Lỗi gửi email: $e');
    }
  }

  /// @deprecated OTP client đã bị loại bỏ theo tiêu chuẩn Phase 1.
  /// Sử dụng Firebase Auth Native để xác thực email hoặc đặt lại mật khẩu.
  @Deprecated(
      'Sử dụng sendPasswordReset hoặc FirebaseAuth.currentUser?.sendEmailVerification')
  static Future<({bool success, String message})> sendOTPEmail({
    required String toEmail,
    required String otpCode,
  }) =>
      EmailService().sendOtp(toEmail: toEmail, otpCode: otpCode);

  @Deprecated(
      'Sử dụng sendPasswordReset hoặc FirebaseAuth.currentUser?.sendEmailVerification')
  Future<({bool success, String message})> sendOtp({
    required String toEmail,
    required String otpCode,
  }) async {
    debugPrint(
      'EmailService: Luồng OTP client đã ngừng hoạt động để bảo vệ an toàn tài khoản. Chuyển sang Firebase Auth Native.',
    );
    return (
      success: false,
      message:
          'Phương thức OTP đã được thay thế bằng liên kết xác thực Firebase an toàn.',
    );
  }
}
