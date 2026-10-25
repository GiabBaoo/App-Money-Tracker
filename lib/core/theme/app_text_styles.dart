import 'package:flutter/material.dart';

/// AppTextStyles - Hệ thống phân cấp Typography chuẩn Fintech Modern UI:
/// - Balance (Số tiền lớn): Kích thước lớn, nét dày (w800/w700), khoảng cách chữ hẹp cho cảm giác tabular
/// - Titles (Tiêu đề): Rõ ràng, phân cấp từ Hero Headline tới Subtitle
/// - Body (Nội dung): Chiều cao dòng chuẩn 1.35 - 1.45 cho trải nghiệm đọc mượt mà
/// - Captions & Badges: Tinh tế, dễ nhìn, hỗ trợ uppercase tracking
class AppTextStyles {
  AppTextStyles._();

  // ─── 1. SỐ TIỀN & SỐ DƯ TÀI CHÍNH (BALANCE & AMOUNTS) ───
  /// Hero Balance trên thẻ ví chính (32px, ExtraBold)
  static const TextStyle balanceHero = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.2,
  );

  /// Số dư lớn trong trang chi tiết / thống kê (28px, ExtraBold)
  static const TextStyle balanceLarge = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.22,
  );

  /// Số tiền giao dịch hiển thị nổi bật (22px, Bold)
  static const TextStyle balanceMedium = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// Số tiền trên danh sách giao dịch (16.5px, ExtraBold)
  static const TextStyle balanceItem = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// Số dư phụ / running balance nhỏ (12px, Bold)
  static const TextStyle balanceSmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
  );

  // ─── 2. TIÊU ĐỀ (TITLES & HEADINGS) ───
  /// Tiêu đề trang / Màn hình chính (24px, ExtraBold)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.3,
  );

  /// Tiêu đề khối / Section Header (20px, Bold)
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Tiêu đề Card lớn / Dialog Header (18px, Bold)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// Tên danh mục / Tên ví / Tiêu đề nhóm (16px, SemiBold)
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// Tiêu đề phụ trong danh sách (14.5px, SemiBold)
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  // ─── 3. NỘI DUNG (BODY TEXT) ───
  /// Đoạn văn nổi bật / Text nút bấm lớn (16px, Medium)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Nội dung văn bản thông thường (14.5px, Regular)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.42,
  );

  /// Ghi chú phụ / Đoạn mô tả ngắn (13.0px, Regular)
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.38,
  );

  // ─── 4. PHỤ CHÚ & HUY HIỆU (LABELS, CAPTIONS, BADGES) ───
  /// Text nút bấm chuẩn (14.5px, SemiBold)
  static const TextStyle button = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// Label Tabbar / Input label (13.0px, SemiBold)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Phụ chú ngày giờ / Metadata (11.5px, Medium)
  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  /// Phụ chú nhỏ / Chip tag (10.5px, SemiBold)
  static const TextStyle captionSmall = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// Huy hiệu trạng thái KHOẢN THU / KHOẢN CHI / CHUYỂN KHOẢN (10.0px, ExtraBold)
  static const TextStyle badge = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  // ─── TẠO TEXTTHEME THEO CHUẨN MATERIAL 3 ───
  static TextTheme createTextTheme(
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return TextTheme(
      headlineLarge: headlineLarge.copyWith(color: primaryTextColor),
      headlineMedium: headlineMedium.copyWith(color: primaryTextColor),
      headlineSmall: titleLarge.copyWith(color: primaryTextColor),
      titleLarge: titleLarge.copyWith(color: primaryTextColor),
      titleMedium: titleMedium.copyWith(color: primaryTextColor),
      titleSmall: titleSmall.copyWith(color: primaryTextColor),
      bodyLarge: bodyLarge.copyWith(color: primaryTextColor),
      bodyMedium: bodyMedium.copyWith(color: primaryTextColor),
      bodySmall: bodySmall.copyWith(color: secondaryTextColor),
      labelLarge: labelLarge.copyWith(color: primaryTextColor),
      labelMedium: caption.copyWith(color: secondaryTextColor),
      labelSmall: captionSmall.copyWith(color: secondaryTextColor),
    );
  }
}
