import 'dart:math' as math;

/// Tiện ích xử lý số học tài chính chuẩn xác, triệt tiêu sai số IEEE 754.
class FinancePrecision {
  const FinancePrecision._();

  static const double epsilon = 1e-4; // 0.0001
  static const int defaultDecimals = 0; // VND mặc định 0 chữ số thập phân

  /// Làm tròn số tiền theo đơn vị tiền tệ (VND = 0, ngoại tệ khác = 2)
  static double roundCurrency(double value, {String currency = 'VND'}) {
    final decimals = (currency.toUpperCase() == 'VND') ? 0 : 2;
    if (decimals == 0) {
      return value.roundToDouble();
    }
    final factor = math.pow(10, decimals);
    return (value * factor).round() / factor;
  }

  /// So sánh hai giá trị tiền tệ có bằng nhau trong ngưỡng epsilon
  static bool areEqual(double a, double b) {
    return (a - b).abs() < epsilon;
  }

  /// Kiểm tra a lớn hơn b vượt ngoài epsilon
  static bool isGreaterThan(double a, double b) {
    return (a - b) > epsilon;
  }

  /// Kiểm tra a nhỏ hơn b vượt ngoài epsilon
  static bool isLessThan(double a, double b) {
    return (b - a) > epsilon;
  }

  /// Phép cộng số tiền chuẩn xác theo đơn vị tiền tệ
  static double add(double a, double b, {String currency = 'VND'}) {
    return roundCurrency(a + b, currency: currency);
  }

  /// Phép trừ số tiền chuẩn xác theo đơn vị tiền tệ
  static double subtract(double a, double b, {String currency = 'VND'}) {
    return roundCurrency(a - b, currency: currency);
  }

  /// Phép nhân số tiền với hệ số chuẩn xác theo đơn vị tiền tệ
  static double multiply(double a, double factor, {String currency = 'VND'}) {
    return roundCurrency(a * factor, currency: currency);
  }

  /// Kiểm tra giá trị bằng 0 trong ngưỡng epsilon
  static bool isZero(double value) {
    return areEqual(value, 0.0);
  }

  /// Kiểm tra giá trị dương ngoài ngưỡng epsilon
  static bool isPositive(double value) {
    return isGreaterThan(value, 0.0);
  }
}
