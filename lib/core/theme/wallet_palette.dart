import 'package:flutter/material.dart';

/// Preset mẫu gradient cao cấp cho thẻ ví điện tử / ngân hàng (Fintech Wallet Cards)
class WalletColorPreset {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> gradient;
  final Color textColor;

  const WalletColorPreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.gradient,
    this.textColor = Colors.white,
  });

  LinearGradient toLinearGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(colors: gradient, begin: begin, end: end);
  }
}

/// WalletPalette - Bộ sưu tập màu sắc thẻ tài chính chuẩn Fintech hiện đại
class WalletPalette {
  WalletPalette._();

  static const WalletColorPreset monoEmerald = WalletColorPreset(
    id: 'mono_emerald',
    name: 'Mono Emerald',
    primaryColor: Color(0xFF438883),
    secondaryColor: Color(0xFF1E4844),
    gradient: [Color(0xFF438883), Color(0xFF1E4844)],
  );

  static const WalletColorPreset oceanBlue = WalletColorPreset(
    id: 'ocean_blue',
    name: 'Đại dương',
    primaryColor: Color(0xFF0284C7),
    secondaryColor: Color(0xFF0C4A6E),
    gradient: [Color(0xFF0284C7), Color(0xFF0C4A6E)],
  );

  static const WalletColorPreset royalIndigo = WalletColorPreset(
    id: 'royal_indigo',
    name: 'Indigo Hoàng gia',
    primaryColor: Color(0xFF6366F1),
    secondaryColor: Color(0xFF312E81),
    gradient: [Color(0xFF6366F1), Color(0xFF312E81)],
  );

  static const WalletColorPreset coralRose = WalletColorPreset(
    id: 'coral_rose',
    name: 'San hô Rose',
    primaryColor: Color(0xFFF43F5E),
    secondaryColor: Color(0xFF881337),
    gradient: [Color(0xFFF43F5E), Color(0xFF881337)],
  );

  static const WalletColorPreset amberGold = WalletColorPreset(
    id: 'amber_gold',
    name: 'Hoàng kim',
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFF78350F),
    gradient: [Color(0xFFF59E0B), Color(0xFF78350F)],
  );

  static const WalletColorPreset slatePlatinum = WalletColorPreset(
    id: 'slate_platinum',
    name: 'Bạch kim Slate',
    primaryColor: Color(0xFF475569),
    secondaryColor: Color(0xFF0F172A),
    gradient: [Color(0xFF475569), Color(0xFF0F172A)],
  );

  static const WalletColorPreset obsidianBlack = WalletColorPreset(
    id: 'obsidian_black',
    name: 'Hắc thạch OLED',
    primaryColor: Color(0xFF1E293B),
    secondaryColor: Color(0xFF0B1320),
    gradient: [Color(0xFF243248), Color(0xFF0B1320)],
  );

  static const WalletColorPreset violetLuxury = WalletColorPreset(
    id: 'violet_luxury',
    name: 'Tím Quý phái',
    primaryColor: Color(0xFF8B5CF6),
    secondaryColor: Color(0xFF4C1D95),
    gradient: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
  );

  static const List<WalletColorPreset> all = [
    monoEmerald,
    oceanBlue,
    royalIndigo,
    coralRose,
    amberGold,
    slatePlatinum,
    obsidianBlack,
    violetLuxury,
  ];

  /// Bảng 28 mã màu hex chuẩn Fintech cho tùy biến ví (Vietcombank, MB, Techcombank, MoMo, ZaloPay...)
  static const List<int> paletteColorValues = [
    0xFF438883, // Emerald (Màu chủ đạo app)
    0xFF10B981, // Mint Emerald
    0xFF006E33, // Vietcombank Deep Green
    0xFF06D6A0, // Neon Mint
    0xFF14B8A6, // Teal
    0xFF06B6D4, // Cyan
    0xFF0EA5E9, // Sky Blue
    0xFF0077B6, // Ocean Blue
    0xFF0068FF, // ZaloPay Blue
    0xFF3A86FF, // Electric Blue
    0xFF1429A0, // MB Bank Navy
    0xFF6366F1, // Indigo
    0xFF8338EC, // Violet
    0xFF7209B7, // Royal Purple
    0xFFD82D8B, // MoMo Pink
    0xFFEC4899, // Hot Pink
    0xFFF43F5E, // Rose
    0xFFD62828, // Crimson Red
    0xFFE31B23, // Techcombank Red
    0xFFF97316, // Orange
    0xFFF77F00, // Sunset Orange
    0xFFE07A5F, // Terracotta
    0xFFFFB703, // Amber Gold
    0xFFF59E0B, // Deep Amber
    0xFF84CC16, // Lime
    0xFF2B2D42, // Midnight Dark
    0xFF1E293B, // Dark Slate
    0xFF6F4E37, // Coffee Brown
  ];

  /// Danh sách Color object tương ứng 28 màu ví
  static List<Color> get paletteColors =>
      paletteColorValues.map((v) => Color(v)).toList();

  /// Bảng màu biểu đồ phân tích tài chính (Financial Chart Colors) tương phản cao
  static const List<Color> chartColors = [
    Color(0xFF438883), // Teal Emerald
    Color(0xFF6366F1), // Royal Indigo
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFFF43F5E), // Rose Coral
    Color(0xFF0EA5E9), // Sky Azure
    Color(0xFF8B5CF6), // Violet Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Hot Pink
    Color(0xFF10B981), // Mint Emerald
    Color(0xFFF97316), // Orange
    Color(0xFF84CC16), // Lime Green
    Color(0xFF64748B), // Slate Grey
  ];

  static WalletColorPreset findById(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => monoEmerald);
  }

  /// Tạo gradient 2 màu mượt mà từ mã màu gốc của ví
  static List<Color> getGradientFromColor(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final darker = hsl
        .withLightness((hsl.lightness - 0.22).clamp(0.08, 0.95))
        .toColor();
    return [baseColor, darker];
  }
}
