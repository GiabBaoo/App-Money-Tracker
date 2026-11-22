import 'package:cloud_firestore/cloud_firestore.dart';
import '../logging/app_logger.dart';

/// Các hàm helper parse dữ liệu Firestore an toàn, không throw khi sai kiểu dữ liệu.
class FirestoreParse {
  FirestoreParse._();

  /// Parse Timestamp, int (millisecondsSinceEpoch), double, String ISO-8601, hoặc DateTime.
  static DateTime? parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.round());
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  /// Parse bool, 0/1, hoặc "true"/"false"/"1"/"0".
  static bool parseBool(dynamic v, {bool defaultValue = false}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final lower = v.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  /// Parse int, double, hoặc String số.
  static int? parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  /// Parse double từ num hoặc String.
  static double parseDouble(dynamic v, {double defaultValue = 0.0}) {
    if (v == null) return defaultValue;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Parse String an toàn.
  static String parseString(dynamic v, {String defaultValue = ''}) {
    if (v == null) return defaultValue;
    if (v is String) return v;
    return v.toString();
  }

  /// Parse danh sách DocumentSnapshot an toàn: bỏ qua + log doc lỗi thay vì làm hỏng cả đợt.
  static List<T> parseList<T>(
    Iterable<DocumentSnapshot> docs,
    T Function(DocumentSnapshot doc) parser, {
    String tag = 'FirestoreParse',
  }) {
    final result = <T>[];
    for (final doc in docs) {
      try {
        result.add(parser(doc));
      } catch (e, st) {
        AppLogger.warn(
          'Bỏ qua document lỗi khi parse (${doc.reference.path})',
          tag: tag,
          error: e,
          stackTrace: st,
        );
      }
    }
    return result;
  }
}
