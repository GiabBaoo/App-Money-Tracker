import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_parse.dart';

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
      id: FirestoreParse.parseString(json['id']),
      groupId: FirestoreParse.parseString(json['groupId']),
      userId: FirestoreParse.parseString(json['userId']),
      userName: FirestoreParse.parseString(
        json['userName'],
        defaultValue: 'Người dùng',
      ),
      amount: FirestoreParse.parseDouble(json['amount']),
      type: json['type'] == 'contribute'
          ? TransactionType.contribute
          : TransactionType.withdraw,
      createdAt: FirestoreParse.parseDate(json['createdAt']) ?? DateTime.now(),
      notes: json['notes']?.toString(),
    );
  }
}
