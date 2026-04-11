import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionModel {
  final String id;
  final String uid;
  final String type; // 'income' hoặc 'expense'
  final String category;
  final int categoryIconCode; // Lưu icon.codePoint vì Firestore không lưu được IconData
  final double amount;
  final DateTime date;
  final String time;
  final String description;
  final DateTime createdAt;
  final String? groupId; // ID của quỹ (nếu là giao dịch quỹ)
  final int? groupIconCode; // Icon code của quỹ (nếu là giao dịch quỹ)
  final String source; // 'personal' hoặc 'fund' - để phân biệt loại giao dịch

  TransactionModel({
    this.id = '',
    required this.uid,
    required this.type,
    required this.category,
    required this.categoryIconCode,
    required this.amount,
    required this.date,
    this.time = '',
    this.description = '',
    DateTime? createdAt,
    this.groupId,
    this.groupIconCode,
    this.source = 'personal', // Default là personal
  }) : createdAt = createdAt ?? DateTime.now();

  // Lấy IconData từ codePoint đã lưu
  IconData get icon => IconData(categoryIconCode, fontFamily: 'MaterialIcons');

  bool get isIncome => type == 'income';

  // Chuyển từ Firestore sang Object
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      categoryIconCode: data['categoryIconCode'] ?? Icons.category.codePoint,
      amount: (data['amount'] ?? 0).toDouble(),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      time: data['time'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      groupId: data['groupId'],
      groupIconCode: data['groupIconCode'],
      source: data['source'] ?? 'personal', // Backward compatibility
    );
  }

  // Chuyển Object sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'type': type,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'time': time,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'groupId': groupId,
      'groupIconCode': groupIconCode,
      'source': source, // Thêm field source
    };
  }
}
