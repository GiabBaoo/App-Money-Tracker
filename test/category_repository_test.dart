import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/category_model.dart';
import 'package:money_tracker_app/data/repositories/category_repository.dart';

void main() {
  group('CategoryModel Tests', () {
    test('Model instantiation and getters work correctly', () {
      final model = CategoryModel(
        id: 'test_1',
        name: 'Ăn uống',
        iconCode: Icons.restaurant.codePoint,
        colorValue: const Color(0xFFF97316).toARGB32(),
        isIncome: false,
        group: 'Thiết yếu',
        isDefault: true,
      );

      expect(model.id, 'test_1');
      expect(model.name, 'Ăn uống');
      expect(model.icon.codePoint, Icons.restaurant.codePoint);
      expect(model.color?.toARGB32(), const Color(0xFFF97316).toARGB32());
      expect(model.isIncome, false);
      expect(model.group, 'Thiết yếu');
      expect(model.isDefault, true);
      expect(model.isCustom, false);
    });

    test('fromMap and toMap serialize properly', () {
      final map = {
        'id': 'cat_custom',
        'name': 'Nuôi mèo',
        'iconCode': Icons.pets.codePoint,
        'colorValue': const Color(0xFF10B981).toARGB32(),
        'isIncome': false,
        'group': 'Khác',
        'isDefault': false,
        'isCustom': true,
        'isOverride': false,
      };

      final cat = CategoryModel.fromMap(map);
      expect(cat.id, 'cat_custom');
      expect(cat.name, 'Nuôi mèo');
      expect(cat.iconCode, Icons.pets.codePoint);
      expect(cat.isCustom, true);
      expect(cat.toMap()['name'], 'Nuôi mèo');
    });
  });

  group('CategoryRepository Tests', () {
    test('getExpenseCategories returns default categories with All option', () async {
      final repo = CategoryRepository();
      final list = await repo.getExpenseCategories(includeAllOption: true);

      expect(list.isNotEmpty, true);
      expect(list.first.name, 'Tất cả');
      expect(list.any((c) => c.name == 'Ăn uống'), true);
      expect(list.any((c) => c.name == 'Mua sắm'), true);
      expect(list.any((c) => c.name == 'Di chuyển'), true);
    });

    test('getExpenseCategories without All option excludes Tất cả', () async {
      final repo = CategoryRepository();
      final list = await repo.getExpenseCategories(includeAllOption: false);

      expect(list.any((c) => c.name == 'Tất cả'), false);
      expect(list.any((c) => c.name == 'Ăn uống'), true);
    });
  });
}
