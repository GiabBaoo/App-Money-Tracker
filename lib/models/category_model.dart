import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCode;
  final int? colorValue;
  final bool isIncome;
  final String group;
  final bool isDefault;
  final bool isCustom;
  final bool isOverride;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    this.colorValue,
    this.isIncome = false,
    this.group = 'Khác',
    this.isDefault = false,
    this.isCustom = false,
    this.isOverride = false,
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color? get color => colorValue != null ? Color(colorValue!) : null;

  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? defaultId}) {
    return CategoryModel(
      id: map['id']?.toString() ?? defaultId ?? map['name']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      iconCode: map['iconCode'] is num
          ? (map['iconCode'] as num).toInt()
          : 0xe148,
      colorValue: map['colorValue'] is num
          ? (map['colorValue'] as num).toInt()
          : null,
      isIncome: map['isIncome'] == true,
      group: map['group']?.toString() ?? 'Khác',
      isDefault: map['isDefault'] == true,
      isCustom: map['isCustom'] == true,
      isOverride: map['isOverride'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isIncome': isIncome,
      'group': group,
      'isDefault': isDefault,
      'isCustom': isCustom,
      'isOverride': isOverride,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    int? iconCode,
    int? colorValue,
    bool? isIncome,
    String? group,
    bool? isDefault,
    bool? isCustom,
    bool? isOverride,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isIncome: isIncome ?? this.isIncome,
      group: group ?? this.group,
      isDefault: isDefault ?? this.isDefault,
      isCustom: isCustom ?? this.isCustom,
      isOverride: isOverride ?? this.isOverride,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
