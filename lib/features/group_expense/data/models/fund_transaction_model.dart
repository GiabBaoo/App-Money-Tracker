import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { contribute, withdraw }

class FundTransactionModel {
  final String id;
  final String groupId;
  final String userId;
  final String userName; // Tên người dùng
  final double amount;
  final TransactionType type;
  final DateTime createdAt;
  final String? notes;

  FundTransactionModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }

  factory FundTransactionModel.fromJson(Map<String, dynamic> json) {
    return FundTransactionModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? 'Người dùng',
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'contribute' 
          ? TransactionType.contribute 
          : TransactionType.withdraw,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      notes: json['notes'] as String?,
    );
  }
}
