import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/user_repository.dart';
import '../models/user_model.dart';

/// Cấu hình hiển thị (icon + màu) user đã chọn cho một danh mục.
@immutable
class CategoryStyle {
  final int? iconCode;
  final int? colorValue;

  const CategoryStyle({this.iconCode, this.colorValue});

  @override
  bool operator ==(Object other) =>
      other is CategoryStyle &&
      other.iconCode == iconCode &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(iconCode, colorValue);
}

/// Nguồn dữ liệu DUY NHẤT cho icon/màu danh mục do user tuỳ chỉnh.
///
/// Đọc từ `UserModel.customCategories` (SQLite + Firestore), gồm:
/// - Danh mục tự tạo: `{name, iconCode, colorValue, isIncome, group}`
/// - Override danh mục mặc định: `{name, iconCode, colorValue, isIncome, isOverride: true}`
///
/// Các màn hình hiển thị lắng nghe service này (qua `ListenableBuilder`) để
/// tự rebuild khi user đổi màu/biểu tượng — không cần sửa dữ liệu giao dịch.
class CategoryStyleService extends ChangeNotifier {
  static final CategoryStyleService instance = CategoryStyleService._internal();
  factory CategoryStyleService() => instance;

  CategoryStyleService._internal() {
    final cached = UserRepository().currentUser;
    if (cached != null) _rebuild(cached.customCategories, notify: false);
    _sub = UserRepository().getUserStream().listen(_onUser, onError: (_) {});
  }

  StreamSubscription<UserModel?>? _sub;
  Map<String, CategoryStyle> _styles = const {};

  /// Đảm bảo service đã khởi tạo (gọi ở main để bắt đầu lắng nghe sớm).
  static void ensureInitialized() => instance;

  void _onUser(UserModel? user) => _rebuild(user?.customCategories ?? const []);

  /// Cho phép cập nhật ngay lập tức sau khi lưu (không đợi stream).
  void applyCustomCategories(List<dynamic> customCategories) =>
      _rebuild(customCategories);

  void _rebuild(List<dynamic> customCategories, {bool notify = true}) {
    final next = <String, CategoryStyle>{};
    // Danh mục tự tạo trước, override sau → override (nếu trùng tên) được ưu tiên
    final ordered = [
      ...customCategories.where((e) => e is Map && e['isOverride'] != true),
      ...customCategories.where((e) => e is Map && e['isOverride'] == true),
    ];
    for (final raw in ordered) {
      final item = raw as Map;
      final name = item['name'];
      if (name is! String || name.isEmpty) continue;
      final icon = item['iconCode'];
      final color = item['colorValue'];
      next[name] = CategoryStyle(
        iconCode: icon is num ? icon.toInt() : null,
        colorValue: color is num ? color.toInt() : null,
      );
    }
    if (mapEquals(next, _styles)) return;
    _styles = Map.unmodifiable(next);
    if (notify) notifyListeners();
  }

  /// Style user đã chọn cho [name], hoặc `null` nếu chưa tuỳ chỉnh.
  CategoryStyle? styleFor(String name) => _styles[name];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
