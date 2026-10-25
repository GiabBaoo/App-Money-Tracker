import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/category_utils.dart';

class BudgetModel {
  final String id;
  final String uid;
  final String category; // Tên danh mục hoặc 'Tất cả' cho tổng ngân sách
  final int categoryIconCode;
  final double limitAmount;
  final String period; // 'monthly' hoặc 'weekly'
  final int month;
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

  // Transient/calculated fields (không cần lưu SQLite nếu tính theo transactions)
  final double currentSpent;

  BudgetModel({
    required this.id,
    required this.uid,
    required this.category,
    this.categoryIconCode = 0xe148, // Icons.category
    required this.limitAmount,
    this.period = 'monthly',
    required this.month,
    required this.year,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'synced',
    this.currentSpent = 0.0,
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  IconData get icon {
    if (category == 'Tất cả') {
      return Icons.account_balance_wallet_outlined;
    }
    return CategoryUtils.getCategoryIcon(
      category,
      fallbackCode: categoryIconCode,
    );
  }

  double get remainingAmount => limitAmount - currentSpent;
  double get progressPercentage =>
      limitAmount > 0 ? (currentSpent / limitAmount).clamp(0.0, 2.0) : 0.0;
  bool get isOverBudget => currentSpent > limitAmount;
  bool get isNearLimit => currentSpent >= (limitAmount * 0.8) && !isOverBudget;

  BudgetModel copyWith({
    String? id,
    String? uid,
    String? category,
    int? categoryIconCode,
    double? limitAmount,
    String? period,
    int? month,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    double? currentSpent,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      category: category ?? this.category,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      currentSpent: currentSpent ?? this.currentSpent,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'limitAmount': limitAmount,
      'period': period,
      'month': month,
      'year': year,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory BudgetModel.fromSqlite(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      category: map['category'] as String? ?? '',
      categoryIconCode: map['categoryIconCode'] as int? ?? 0xe148,
      limitAmount: (map['limitAmount'] as num?)?.toDouble() ?? 0.0,
      period: map['period'] as String? ?? 'monthly',
      month: map['month'] as int? ?? DateTime.now().month,
      year: map['year'] as int? ?? DateTime.now().year,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] as int? ?? 0,
      ),
      syncStatus: map['syncStatus'] as String? ?? 'synced',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'limitAmount': limitAmount,
      'period': period,
      'month': month,
      'year': year,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BudgetModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      category: data['category'] as String? ?? '',
      categoryIconCode: data['categoryIconCode'] as int? ?? 0xe148,
      limitAmount: (data['limitAmount'] as num?)?.toDouble() ?? 0.0,
      period: data['period'] as String? ?? 'monthly',
      month: data['month'] as int? ?? DateTime.now().month,
      year: data['year'] as int? ?? DateTime.now().year,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      syncStatus: 'synced',
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
