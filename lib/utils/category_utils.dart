import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getCategoryIcon(String name) {
    switch (name) {
      case 'Ăn uống': return Icons.restaurant_rounded;
      case 'Sức khỏe': return Icons.medical_services_rounded;
      case 'Di chuyển': return Icons.directions_car_rounded;
      case 'Học tập': return Icons.school_rounded;
      case 'Giải trí': return Icons.movie_rounded;
      case 'Du lịch': return Icons.flight_rounded;
      case 'Chi khác': return Icons.receipt_long_rounded;
      case 'Tiền lương': return Icons.account_balance_wallet_rounded;
      case 'Lương': return Icons.account_balance_wallet_rounded;
      case 'Tiền thưởng': return Icons.card_giftcard_rounded;
      case 'Kinh doanh': return Icons.storefront_rounded;
      case 'Đầu tư': return Icons.trending_up_rounded;
      case 'Tiền lãi': return Icons.monetization_on_rounded;
      case 'Quà tặng': return Icons.redeem_rounded;
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Tiền điện': return Icons.bolt_rounded;
      default: return Icons.category_rounded;
    }
  }

  static Color getVibrantColor(String name) {
    switch (name) {
      case 'Ăn uống': return const Color(0xFFF97316); // Orange
      case 'Sức khỏe': return const Color(0xFF14B8A6); // Teal
      case 'Di chuyển': return const Color(0xFFFACC15); // Yellow
      case 'Học tập': return const Color(0xFF3B82F6); // Blue
      case 'Giải trí': return const Color(0xFFDB2777); // Pink
      case 'Du lịch': return const Color(0xFF0EA5E9); // Light Blue
      case 'Chi khác': return const Color(0xFF8B5CF6); // Purple
      case 'Mua sắm': return const Color(0xFFF43F5E); // Rose
      case 'Tiền điện': return const Color(0xFF06B6D4); // Cyan
      case 'Quà tặng': return const Color(0xFFD946EF); // Fuchsia
      case 'Tiền lương': return const Color(0xFF22C55E); // Green
      case 'Lương': return const Color(0xFF22C55E); // Green
      case 'Tiền thưởng': return const Color(0xFFFFD700); // Gold
      case 'Kinh doanh': return const Color(0xFF6366F1); // Indigo
      case 'Đầu tư': return const Color(0xFFF59E0B); // Amber
      case 'Tiền lãi': return const Color(0xFF10B981); // Emerald
      default: return const Color(0xFF438883);
    }
  }


  static Color getLightBgColor(String name, bool isDark) {
    final color = getVibrantColor(name);
    return isDark ? color.withOpacity(0.15) : color.withOpacity(0.1);
  }
}
