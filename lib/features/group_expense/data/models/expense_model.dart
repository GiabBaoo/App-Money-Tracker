import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitMethod { equal, custom, singlePayer }

class ExpenseModel {
  final String id;
  final String groupId;
  final String name;
  final double amount;
  final String payerId;
  final List<String> participantIds;
  final SplitMethod splitMethod;
  final Map<String, double> shares;
  final String category;
  final DateTime date;
  final String? notes;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.amount,
    required this.payerId,
    required this.participantIds,
    required this.splitMethod,
    required this.shares,
    required this.category,
    required this.date,
    this.notes,
    required this.photoUrls,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      payerId: json['payerId'] as String,
      participantIds: List<String>.from(json['participantIds'] as List),
      splitMethod: SplitMethod.values.firstWhere(
        (e) => e.toString() == 'SplitMethod.${json['splitMethod']}',
      ),
      shares: Map<String, double>.from(
        (json['shares'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
      category: json['category'] as String,
      date: (json['date'] as Timestamp).toDate(),
      notes: json['notes'] as String?,
      photoUrls: List<String>.from(json['photoUrls'] as List),
      createdBy: json['createdBy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'amount': amount,
      'payerId': payerId,
      'participantIds': participantIds,
      'splitMethod': splitMethod.toString().split('.').last,
      'shares': shares,
      'category': category,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
