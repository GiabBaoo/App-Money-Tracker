import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getCategoryIcon(String name) {
    switch (name) {
      // EXPENSES — Thống nhất dùng _outlined để khớp với CategoryScreen
      case 'Ăn uống': return Icons.restaurant_outlined;
      case 'Sức khỏe': return Icons.medical_services_outlined;
      case 'Di chuyển': return Icons.directions_car_outlined;
      case 'Gửi xe':
      case 'Tiền gửi xe':
      case 'Đỗ xe': return Icons.local_parking_outlined;
      case 'Học tập': return Icons.menu_book_outlined;
      case 'Giải trí': return Icons.local_activity_outlined;
      case 'Du lịch': return Icons.flight_outlined;
      case 'Mua sắm': return Icons.shopping_bag_outlined;
      case 'Tiền nhà': return Icons.home_outlined;
      case 'Tiền điện': return Icons.water_drop_outlined;
      case 'Điện thoại': return Icons.phone_android_outlined;
      case 'Thể thao': return Icons.fitness_center_outlined;
      case 'Tiết kiệm': return Icons.savings_outlined;
      case 'Bảo hiểm': return Icons.shield_outlined;
      case 'Quà tặng': return Icons.card_giftcard_outlined;
      case 'Làm đẹp': return Icons.spa_outlined;
      case 'Thú cưng': return Icons.pets_outlined;
      case 'Con cái': return Icons.child_care_outlined;
      case 'Từ thiện': return Icons.volunteer_activism_outlined;
      case 'Sửa chữa': return Icons.build_outlined;
      case 'Đồ công nghệ': return Icons.devices_other_outlined;
      case 'Trả nợ': return Icons.credit_card_outlined;
      case 'Chi khác': return Icons.receipt_long_outlined;

      // INCOMES — Thống nhất dùng _outlined để khớp với CategoryScreen
      case 'Tiền lương':
      case 'Lương': return Icons.work_outline;
      case 'Tiền thưởng': return Icons.card_giftcard_outlined;
      case 'Kinh doanh': return Icons.storefront_outlined;
      case 'Đầu tư': return Icons.trending_up_outlined;
      case 'Tiền lãi': return Icons.monetization_on_outlined;
      case 'Được cho/Tặng': return Icons.volunteer_activism_outlined;
      case 'Bán đồ': return Icons.sell_outlined;
      case 'Tiền thuê nhà': return Icons.real_estate_agent_outlined;
      case 'Thu nợ': return Icons.handshake_outlined;
      case 'Làm thêm': return Icons.laptop_chromebook_outlined;
      case 'Trợ cấp': return Icons.school_outlined;
      case 'Hoàn tiền': return Icons.replay_circle_filled_rounded;
      case 'Thu khác': return Icons.account_balance_wallet_outlined;

      // TRANSFERS
      case 'Chuyển tiền': return Icons.swap_horiz_rounded;
      case 'Nhận chuyển tiền': return Icons.call_received_rounded;
      case 'Chuyển ví': return Icons.sync_alt_rounded;
      default: return Icons.category_outlined;
    }
  }

  static Color getVibrantColor(String name) {
    switch (name) {
      // EXPENSES
      case 'Ăn uống': return const Color(0xFFF97316); // Orange
      case 'Sức khỏe': return const Color(0xFF14B8A6); // Teal
      case 'Di chuyển': return const Color(0xFFFACC15); // Yellow
      case 'Gửi xe':
      case 'Tiền gửi xe':
      case 'Đỗ xe': return const Color(0xFF0284C7); // Sky Blue
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
