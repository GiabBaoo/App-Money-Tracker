import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GoalModel {
  final String id;
  final String uid;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final int iconCode;
  final int colorValue;
  final String walletId;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

  GoalModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.deadline,
    this.iconCode = 0xe532, // Icons.savings
    this.colorValue = 0xFF438883,
    this.walletId = '',
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'synced',
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remainingAmount =>
      (targetAmount - currentAmount) > 0 ? (targetAmount - currentAmount) : 0.0;
  bool get isCompleted => currentAmount >= targetAmount;

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(deadline.year, deadline.month, deadline.day);
    return targetDay.difference(today).inDays;
  }

  double get recommendedDailySavings {
    if (isCompleted || daysRemaining <= 0) return 0.0;
    return remainingAmount / daysRemaining;
  }

  double get recommendedMonthlySavings {
    if (isCompleted || daysRemaining <= 0) return 0.0;
    final months = daysRemaining / 30.0;
    if (months <= 1) return remainingAmount;
    return remainingAmount / months;
  }

  GoalModel copyWith({
    String? id,
    String? uid,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    int? iconCode,
    int? colorValue,
    String? walletId,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      walletId: walletId ?? this.walletId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline.millisecondsSinceEpoch,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'walletId': walletId,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory GoalModel.fromSqlite(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: DateTime.fromMillisecondsSinceEpoch(
        map['deadline'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      iconCode: map['iconCode'] as int? ?? 0xe532,
      colorValue: map['colorValue'] as int? ?? 0xFF438883,
      walletId: map['walletId'] as String? ?? '',
      note: map['note'] as String? ?? '',
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
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'iconCode': iconCode,
      'colorValue': colorValue,
      'walletId': walletId,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GoalModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      iconCode: data['iconCode'] as int? ?? 0xe532,
      colorValue: data['colorValue'] as int? ?? 0xFF438883,
      walletId: data['walletId'] as String? ?? '',
      note: data['note'] as String? ?? '',
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
