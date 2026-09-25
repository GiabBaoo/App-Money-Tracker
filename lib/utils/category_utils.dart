import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getCategoryIcon(String name) {
    switch (name) {
      // EXPENSES
      case 'Ăn uống': return Icons.restaurant_rounded;
      case 'Sức khỏe': return Icons.medical_services_rounded;
      case 'Di chuyển': return Icons.directions_car_rounded;
      case 'Học tập': return Icons.school_rounded;
      case 'Giải trí': return Icons.movie_rounded;
      case 'Du lịch': return Icons.flight_rounded;
      case 'Mua sắm': return Icons.shopping_bag_rounded;
      case 'Tiền nhà': return Icons.home_rounded;
      case 'Tiền điện': return Icons.bolt_rounded;
      case 'Điện thoại': return Icons.phone_android_rounded;
      case 'Thể thao': return Icons.fitness_center_rounded;
      case 'Tiết kiệm': return Icons.savings_rounded;
      case 'Bảo hiểm': return Icons.shield_rounded;
      case 'Quà tặng': return Icons.redeem_rounded;
      case 'Làm đẹp': return Icons.spa_rounded;
      case 'Thú cưng': return Icons.pets_rounded;
      case 'Con cái': return Icons.child_care_rounded;
      case 'Từ thiện': return Icons.favorite_rounded;
      case 'Sửa chữa': return Icons.build_rounded;
      case 'Đồ công nghệ': return Icons.devices_other_rounded;
      case 'Trả nợ': return Icons.credit_card_rounded;
      case 'Chi khác': return Icons.receipt_long_rounded;

      // INCOMES
      case 'Tiền lương':
      case 'Lương': return Icons.work_rounded;
      case 'Tiền thưởng': return Icons.card_giftcard_rounded;
      case 'Kinh doanh': return Icons.storefront_rounded;
      case 'Đầu tư': return Icons.trending_up_rounded;
      case 'Tiền lãi': return Icons.monetization_on_rounded;
      case 'Được cho/Tặng': return Icons.volunteer_activism_rounded;
      case 'Bán đồ': return Icons.sell_rounded;
      case 'Tiền thuê nhà': return Icons.real_estate_agent_rounded;
      case 'Thu nợ': return Icons.handshake_rounded;
      case 'Làm thêm': return Icons.laptop_chromebook_rounded;
      case 'Trợ cấp': return Icons.school_outlined;
      case 'Hoàn tiền': return Icons.replay_circle_filled_rounded;
      case 'Thu khác': return Icons.account_balance_wallet_rounded;

      // TRANSFERS
      case 'Chuyển tiền': return Icons.swap_horiz_rounded;
      case 'Nhận chuyển tiền': return Icons.call_received_rounded;
      case 'Chuyển ví': return Icons.sync_alt_rounded;
      default: return Icons.category_rounded;
    }
  }

  static Color getVibrantColor(String name) {
    switch (name) {
      // EXPENSES
      case 'Ăn uống': return const Color(0xFFF97316); // Orange
      case 'Sức khỏe': return const Color(0xFF14B8A6); // Teal
      case 'Di chuyển': return const Color(0xFFFACC15); // Yellow
      case 'Học tập': return const Color(0xFF3B82F6); // Blue
      case 'Giải trí': return const Color(0xFFDB2777); // Pink
      case 'Du lịch': return const Color(0xFF0EA5E9); // Light Blue
      case 'Mua sắm': return const Color(0xFFF43F5E); // Rose
      case 'Tiền nhà': return const Color(0xFF6366F1); // Indigo
      case 'Tiền điện': return const Color(0xFF06B6D4); // Cyan
      case 'Điện thoại': return const Color(0xFF0284C7); // Sky
      case 'Thể thao': return const Color(0xFF10B981); // Emerald
      case 'Tiết kiệm': return const Color(0xFF10B981); // Emerald
      case 'Bảo hiểm': return const Color(0xFF4F46E5); // Indigo
      case 'Quà tặng': return const Color(0xFFD946EF); // Fuchsia
      case 'Làm đẹp': return const Color(0xFFEC4899); // Pink
      case 'Thú cưng': return const Color(0xFFFB923C); // Light Orange
      case 'Con cái': return const Color(0xFFF472B6); // Rose Pink
      case 'Từ thiện': return const Color(0xFFEF4444); // Red
      case 'Sửa chữa': return const Color(0xFF78716C); // Stone Grey
      case 'Đồ công nghệ': return const Color(0xFF2563EB); // Royal Blue
      case 'Trả nợ': return const Color(0xFFDC2626); // Strong Red
      case 'Chi khác': return const Color(0xFF8B5CF6); // Purple

      // INCOMES
      case 'Tiền lương':
      case 'Lương': return const Color(0xFF22C55E); // Green
      case 'Tiền thưởng': return const Color(0xFFFFD700); // Gold
      case 'Kinh doanh': return const Color(0xFF6366F1); // Indigo
      case 'Đầu tư': return const Color(0xFFF59E0B); // Amber
      case 'Tiền lãi': return const Color(0xFF10B981); // Emerald
      case 'Được cho/Tặng': return const Color(0xFFF59E0B); // Amber
      case 'Bán đồ': return const Color(0xFFFB923C); // Light Orange
      case 'Tiền thuê nhà': return const Color(0xFF06B6D4); // Cyan
      case 'Thu nợ': return const Color(0xFF0284C7); // Sky Blue
      case 'Làm thêm': return const Color(0xFF8B5CF6); // Violet
      case 'Trợ cấp': return const Color(0xFFEC4899); // Pink
      case 'Hoàn tiền': return const Color(0xFF10B981); // Emerald
      case 'Thu khác': return const Color(0xFF14B8A6); // Teal

      // TRANSFERS
      case 'Chuyển tiền': return const Color(0xFF64748B); // Slate
      case 'Nhận chuyển tiền': return const Color(0xFF0D9488); // Teal
      case 'Chuyển ví': return const Color(0xFF0284C7); // Sky Blue
      default: return const Color(0xFF438883);
    }
  }

  static Color getLightBgColor(String name, bool isDark) {
    final color = getVibrantColor(name);
    return isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1);
  }
}
