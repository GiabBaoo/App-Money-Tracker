import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSplitModel {
  final String id;
  final String expenseId;
  final String userId;
  final int shareAmount; // Số tiền nguyên đồng VND
  final int
  allocatedRemainder; // Số đồng lẻ (1 VND) được gán trong thuật toán dư
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseSplitModel({
    required this.id,
    required this.expenseId,
    required this.userId,
    int? shareAmount,
    int? amountVnd,
    this.allocatedRemainder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : shareAmount = shareAmount ?? amountVnd ?? 0,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  int get amountVnd => shareAmount;
  Map<String, dynamic> toSqlite() => toSqflite();
  static ExpenseSplitModel fromSqlite(Map<String, dynamic> map) =>
      ExpenseSplitModel.fromSqflite(map);

  factory ExpenseSplitModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int)
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ExpenseSplitModel(
      id: json['id'] as String,
      expenseId: json['expenseId'] as String,
      userId: json['userId'] as String,
      shareAmount: (json['shareAmount'] as num).round(),
      allocatedRemainder: (json['allocatedRemainder'] as num?)?.round() ?? 0,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expenseId': expenseId,
      'userId': userId,
      'shareAmount': shareAmount,
      'allocatedRemainder': allocatedRemainder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExpenseSplitModel.fromSqflite(Map<String, dynamic> map) {
    return ExpenseSplitModel(
      id: map['id'] as String,
      expenseId: map['expenseId'] as String,
      userId: map['userId'] as String,
      shareAmount: (map['shareAmount'] as num).round(),
      allocatedRemainder: (map['allocatedRemainder'] as num?)?.round() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] as int,
        isUtc: true,
      ),
    );
  }

  Map<String, dynamic> toSqflite() {
    return {
      'id': id,
      'expenseId': expenseId,
      'userId': userId,
      'shareAmount': shareAmount,
      'allocatedRemainder': allocatedRemainder,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  ExpenseSplitModel copyWith({
    String? id,
    String? expenseId,
    String? userId,
    int? shareAmount,
    int? allocatedRemainder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseSplitModel(
      id: id ?? this.id,
      expenseId: expenseId ?? this.expenseId,
      userId: userId ?? this.userId,
      shareAmount: shareAmount ?? this.shareAmount,
      allocatedRemainder: allocatedRemainder ?? this.allocatedRemainder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
