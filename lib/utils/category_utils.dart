import 'package:flutter/material.dart';

class CategoryUtils {
  static Color getVibrantColor(String name) {
    switch (name) {
      // Khoản Chi
      case 'Ăn uống': return const Color(0xFFF97316); // Vibrant Orange
      case 'Sức khỏe': return const Color(0xFF14B8A6); // Turquoise
      case 'Di chuyển': return const Color(0xFFFACC15); // Lemon Yellow
      case 'Học tập': return const Color(0xFF3B82F6); // Vibrant Blue
      case 'Giải trí': return const Color(0xFFDB2777); // Hot Pink
      case 'Du lịch': return const Color(0xFF0EA5E9); // Sky Blue
      case 'Chi khác': return const Color(0xFF4B5563); // Charcoal Grey
      // Khoản Thu
      case 'Tiền lương': return const Color(0xFF84CC16); // Lime Green
      case 'Tiền thưởng': return const Color(0xFFFFD700); // Gold
      case 'Kinh doanh': return const Color(0xFF0284C7); // Ocean Blue
      case 'Thu khác': return const Color(0xFFF43F5E); // Coral Red
      default: return const Color(0xFF438883); // Màu mặc định
    }
  }

  static Color getLightBgColor(String name, bool isDark) {
    final color = getVibrantColor(name);
    return isDark ? color.withOpacity(0.15) : color.withOpacity(0.1);
  }
}
