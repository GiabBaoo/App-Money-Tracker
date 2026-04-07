import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pendingConfirmation, confirmed, rejected }

class SettlementModel {
  final String id;
  final String groupId;
  final String payerId;
  final String payeeId;
  final double amount;
  final SettlementStatus status;
  final String? notes;
  final String? proofPhotoUrl;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.status,
    this.notes,
    this.proofPhotoUrl,
    required this.createdAt,
    this.confirmedAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      payerId: json['payerId'] as String,
      payeeId: json['payeeId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: SettlementStatus.values.firstWhere(
        (e) => e.toString() == 'SettlementStatus.${json['status']}',
      ),
      notes: json['notes'] as String?,
      proofPhotoUrl: json['proofPhotoUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      confirmedAt: json['confirmedAt'] != null
          ? (json['confirmedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'payeeId': payeeId,
      'amount': amount,
      'status': status.toString().split('.').last,
      'notes': notes,
      'proofPhotoUrl': proofPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
    };
  }

  SettlementModel copyWith({
    String? id,
    String? groupId,
    String? payerId,
    String? payeeId,
    double? amount,
    SettlementStatus? status,
    String? notes,
    String? proofPhotoUrl,
    DateTime? createdAt,
    DateTime? confirmedAt,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerId: payerId ?? this.payerId,
      payeeId: payeeId ?? this.payeeId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}
