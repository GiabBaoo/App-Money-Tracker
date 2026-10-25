import 'package:cloud_firestore/cloud_firestore.dart';

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
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int)
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final statusStr = json['status'] as String? ?? 'active';
    final status = DebtStatus.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          statusStr.replaceAll('_', '').toLowerCase(),
      orElse: () => DebtStatus.active,
    );

    return DebtModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      debtorId: json['debtorId'] as String,
      creditorId: json['creditorId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: status,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
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
