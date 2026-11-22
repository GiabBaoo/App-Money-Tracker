import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_parse.dart';

enum DebtStatus { active, settled, partiallySettled }

class DebtModel {
  final String id;
  final String groupId;
  final String debtorId;
  final String creditorId;
  final double amount;
  final DebtStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DebtModel({
    required this.id,
    required this.groupId,
    required this.debtorId,
    required this.creditorId,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  int get amountVnd => amount.round();

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    final statusStr = FirestoreParse.parseString(
      json['status'],
      defaultValue: 'active',
    );
    final status = DebtStatus.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          statusStr.replaceAll('_', '').toLowerCase(),
      orElse: () => DebtStatus.active,
    );

    return DebtModel(
      id: FirestoreParse.parseString(json['id']),
      groupId: FirestoreParse.parseString(json['groupId']),
      debtorId: FirestoreParse.parseString(json['debtorId']),
      creditorId: FirestoreParse.parseString(json['creditorId']),
      amount: FirestoreParse.parseDouble(json['amount']),
      status: status,
      createdAt: FirestoreParse.parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: FirestoreParse.parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'debtorId': debtorId,
      'creditorId': creditorId,
      'amount': amount,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DebtModel copyWith({
    String? id,
    String? groupId,
    String? debtorId,
    String? creditorId,
    double? amount,
    DebtStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      debtorId: debtorId ?? this.debtorId,
      creditorId: creditorId ?? this.creditorId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
