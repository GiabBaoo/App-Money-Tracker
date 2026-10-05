import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/category_utils.dart';

void main() {
  test('CategoryUtils maps parking categories correctly', () {
    expect(CategoryUtils.getCategoryIcon('Gửi xe'), equals(Icons.local_parking_outlined));
    expect(CategoryUtils.getCategoryIcon('Tiền gửi xe'), equals(Icons.local_parking_outlined));
    expect(CategoryUtils.getCategoryIcon('Đỗ xe'), equals(Icons.local_parking_outlined));

    expect(CategoryUtils.getVibrantColor('Gửi xe'), equals(const Color(0xFF0284C7)));
    expect(CategoryUtils.getVibrantColor('Tiền gửi xe'), equals(const Color(0xFF0284C7)));
  });
}
