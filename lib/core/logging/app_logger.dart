import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Định dạng và cấp độ bản ghi log của ứng dụng
enum AppLogLevel { debug, info, warning, error }

/// Bản ghi log trong bộ nhớ phục vụ chẩn đoán
class DiagnosticLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, Object?>? context;

  DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'tag': tag,
        'message': message,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (context != null) 'context': context,
      };

  @override
  String toString() {
    final sb = StringBuffer(
      '[${timestamp.toIso8601String()}][${level.name.toUpperCase()}][$tag] $message',
    );
    if (context != null && context!.isNotEmpty) {
      sb.write(' | context: $context');
    }
    if (error != null) {
      sb.write(' | error: $error');
    }
    return sb.toString();
  }
}

/// Hệ thống logging & quản lý lỗi tập trung chuẩn hoá cho toàn bộ ứng dụng.
/// - Không bao giờ nuốt lỗi im lặng (`catch (_) {}`).
/// - Tự động che mờ (redact) thông tin nhạy cảm (email, token, secret).
/// - Giữ In-Memory Ring Buffer 200 bản ghi phục vụ chẩn đoán & gửi báo cáo hỗ trợ.
class AppLogger {
  AppLogger._();

  static const int maxBufferSize = 200;
  static final DoubleLinkedQueue<DiagnosticLogEntry> _logBuffer =
      DoubleLinkedQueue<DiagnosticLogEntry>();

  /// Regex nhận diện email để che mờ PII
  static final RegExp _emailRegex =
      RegExp(r'([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})');

  /// Regex nhận diện các key/token nhạy cảm
  static final RegExp _secretRegex = RegExp(
    r'(password|apiKey|api_key|secret|token|hash|credential)["\s:=]+([^\s,;"]+)',
    caseSensitive: false,
  );

  /// Lấy danh sách snapshot bản ghi log trong ring buffer
  static List<DiagnosticLogEntry> get diagnosticLogs =>
      List.unmodifiable(_logBuffer);

  /// Xóa sạch bộ đệm (dùng khi kiểm thử hoặc chuyển phiên)
  static void clearBuffer() {
    _logBuffer.clear();
  }

  /// Che mờ dữ liệu nhạy cảm trước khi log
  static String redact(String input) {
    if (input.isEmpty) return input;
    var sanitized = input.replaceAllMapped(_emailRegex, (m) {
      final name = m.group(1) ?? '';
      final domain = m.group(2) ?? '';
      final ext = m.group(3) ?? '';
      if (name.length <= 2) return '***@$domain.$ext';
      return '${name.substring(0, 2)}***@$domain.$ext';
    });
    sanitized = sanitized.replaceAllMapped(_secretRegex, (m) {
      final key = m.group(1) ?? '';
      return '$key: [REDACTED]';
    });
    return sanitized;
  }

  static void _append(DiagnosticLogEntry entry) {
    if (_logBuffer.length >= maxBufferSize) {
      _logBuffer.removeFirst();
    }
    _logBuffer.addLast(entry);

    // Ở chế độ debug hoặc lỗi, xuất ra debugPrint
    if (kDebugMode || entry.level == AppLogLevel.error) {
      debugPrint(entry.toString());
      if (entry.stackTrace != null && entry.level == AppLogLevel.error) {
        debugPrint('Stack: ${entry.stackTrace}');
      }
    }
  }

  /// Ghi log debug
  static void debug(
    String message, {
    required String tag,
    Map<String, Object?>? context,
  }) {
    _append(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.debug,
        tag: tag,
        message: redact(message),
        context: context,
      ),
    );
  }

  /// Ghi log thông tin nghiệp vụ
  static void info(
    String message, {
    required String tag,
    Map<String, Object?>? context,
  }) {
    _append(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        tag: tag,
        message: redact(message),
        context: context,
      ),
    );
  }

  /// Ghi log cảnh báo hoặc lỗi fallback có dự liệu (ví dụ: mất mạng chuyển sang offline)
  static void warn(
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _append(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warning,
        tag: tag,
        message: redact(message),
        error: error != null ? redact(error.toString()) : null,
        stackTrace: stackTrace?.toString(),
        context: context,
      ),
    );
  }

  /// Ghi log lỗi nghiêm trọng / hỏng dữ liệu / lỗi SQLite / ngoại lệ không mong muốn
  static void error(
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _append(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        tag: tag,
        message: redact(message),
        error: error != null ? redact(error.toString()) : null,
        stackTrace: stackTrace?.toString(),
        context: context,
      ),
    );
  }
}

