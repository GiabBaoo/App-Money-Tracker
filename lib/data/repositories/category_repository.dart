import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/user_model.dart';
import '../../services/category_style_service.dart';
import '../../utils/category_utils.dart';
import 'user_repository.dart';

/// Repository quản lý danh mục thu/chi — hợp nhất danh mục mặc định và tùy biến từ SQLite/Firestore.
class CategoryRepository {
  static final CategoryRepository _instance = CategoryRepository._internal();
  factory CategoryRepository() => _instance;
  CategoryRepository._internal();

  final UserRepository _userRepo = UserRepository();

  /// Danh mục chi tiêu mặc định hệ thống
  static const List<Map<String, dynamic>> _defaultExpenseList = [
    // Thiết yếu
    {'name': 'Ăn uống', 'icon': Icons.restaurant_outlined, 'group': 'Thiết yếu'},
    {'name': 'Sức khỏe', 'icon': Icons.medical_services_outlined, 'group': 'Thiết yếu'},
    {'name': 'Di chuyển', 'icon': Icons.directions_car_outlined, 'group': 'Thiết yếu'},
    {'name': 'Gửi xe', 'icon': Icons.local_parking_outlined, 'group': 'Thiết yếu'},
    {'name': 'Tiền nhà', 'icon': Icons.home_outlined, 'group': 'Thiết yếu'},
    {'name': 'Tiền điện', 'icon': Icons.water_drop_outlined, 'group': 'Thiết yếu'},
    {'name': 'Điện thoại', 'icon': Icons.phone_android_outlined, 'group': 'Thiết yếu'},
    {'name': 'Sửa chữa', 'icon': Icons.build_outlined, 'group': 'Thiết yếu'},

    // Phát triển
    {'name': 'Học tập', 'icon': Icons.menu_book_outlined, 'group': 'Phát triển'},
    {'name': 'Thể thao', 'icon': Icons.fitness_center_outlined, 'group': 'Phát triển'},
    {'name': 'Tiết kiệm', 'icon': Icons.savings_outlined, 'group': 'Phát triển'},
    {'name': 'Bảo hiểm', 'icon': Icons.shield_outlined, 'group': 'Phát triển'},
    {'name': 'Trả nợ', 'icon': Icons.credit_card_outlined, 'group': 'Phát triển'},

    // Hưởng thụ
    {'name': 'Mua sắm', 'icon': Icons.shopping_bag_outlined, 'group': 'Hưởng thụ'},
    {'name': 'Giải trí', 'icon': Icons.local_activity_outlined, 'group': 'Hưởng thụ'},
    {'name': 'Du lịch', 'icon': Icons.flight_outlined, 'group': 'Hưởng thụ'},
    {'name': 'Quà tặng', 'icon': Icons.card_giftcard_outlined, 'group': 'Hưởng thụ'},
    {'name': 'Làm đẹp', 'icon': Icons.spa_outlined, 'group': 'Hưởng thụ'},
    {'name': 'Đồ công nghệ', 'icon': Icons.devices_other_outlined, 'group': 'Hưởng thụ'},

    // Khác
    {'name': 'Thú cưng', 'icon': Icons.pets_outlined, 'group': 'Khác'},
    {'name': 'Con cái', 'icon': Icons.child_care_outlined, 'group': 'Khác'},
    {'name': 'Từ thiện', 'icon': Icons.volunteer_activism_outlined, 'group': 'Khác'},
    {'name': 'Chi khác', 'icon': Icons.receipt_long_outlined, 'group': 'Khác'},
  ];

  /// Lấy danh sách danh mục chi tiêu thực tế (mặc định + tùy biến người dùng)
  Future<List<CategoryModel>> getExpenseCategories({bool includeAllOption = true}) async {
    try {
      final user = await _userRepo.getUser();
      return _buildExpenseList(user, includeAllOption: includeAllOption);
    } catch (_) {
      return _buildExpenseList(null, includeAllOption: includeAllOption);
    }
  }

  /// Lắng nghe danh sách danh mục chi tiêu thay đổi theo Stream của User
  Stream<List<CategoryModel>> watchExpenseCategories({bool includeAllOption = true}) {
    return _userRepo.getUserStream().map((user) {
      return _buildExpenseList(user, includeAllOption: includeAllOption);
    });
  }

  /// Xây dựng danh sách CategoryModel từ UserModel và danh mục mặc định
  List<CategoryModel> _buildExpenseList(UserModel? user, {required bool includeAllOption}) {
    final result = <CategoryModel>[];

    // Tuỳ chọn "Tất cả" (dùng cho ngân sách tổng)
    if (includeAllOption) {
      result.add(
        CategoryModel(
          id: 'all',
          name: 'Tất cả',
          iconCode: Icons.account_balance_wallet_outlined.codePoint,
          group: 'Tổng hợp',
          isDefault: true,
        ),
      );
    }

    final customCats = user?.customCategories ?? [];

    // Bản đồ override danh mục hệ thống
    final Map<String, Map<String, dynamic>> overrideMap = {};
    for (var item in customCats) {
      if (item is Map && item['isOverride'] == true && item['name'] != null) {
        overrideMap[item['name'] as String] = Map<String, dynamic>.from(item);
      }
    }

    // Nạp danh mục chi tiêu mặc định (kèm override nếu có)
    for (var def in _defaultExpenseList) {
      final name = def['name'] as String;
      final defaultIcon = def['icon'] as IconData;
      final group = def['group'] as String;

      final override = overrideMap[name];
      final style = CategoryStyleService.instance.styleFor(name);

      final iconCode = override?['iconCode'] ?? style?.iconCode ?? defaultIcon.codePoint;
      final colorValue = override?['colorValue'] ?? style?.colorValue ?? CategoryUtils.getVibrantColor(name).toARGB32();

      result.add(
        CategoryModel(
          id: 'default_$name',
          name: name,
          iconCode: iconCode is num ? iconCode.toInt() : defaultIcon.codePoint,
          colorValue: colorValue is num ? colorValue.toInt() : null,
          group: group,
          isDefault: true,
          isOverride: override != null,
        ),
      );
    }

    // Nạp danh mục chi tiêu tự tạo của người dùng
    for (int i = 0; i < customCats.length; i++) {
      final item = customCats[i];
      if (item is Map && item['isIncome'] != true && item['isOverride'] != true) {
        final name = (item['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;

        // Tránh trùng tên với danh mục mặc định
        if (result.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
          continue;
        }

        final iconCode = item['iconCode'] is num ? (item['iconCode'] as num).toInt() : Icons.category_outlined.codePoint;
        final colorVal = item['colorValue'] is num ? (item['colorValue'] as num).toInt() : null;
        final group = (item['group'] as String?) ?? 'Khác';

        result.add(
          CategoryModel(
            id: 'custom_${name}_$i',
            name: name,
            iconCode: iconCode,
            colorValue: colorVal,
            group: group,
            isCustom: true,
          ),
        );
      }
    }

    return result;
  }
}
