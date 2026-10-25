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
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String syncStatus;

  SettlementModel({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.status,
    this.notes,
    this.proofPhotoUrl,
    this.linkedTransactionId,
    required this.createdAt,
    this.confirmedAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = 'synced',
  }) : updatedAt = updatedAt ?? createdAt;

  int get amountVnd => amount.round();

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int)
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final statusStr = json['status'] as String? ?? 'pendingConfirmation';
    final status = SettlementStatus.values.firstWhere((e) {
      final name = e.toString().split('.').last.toLowerCase();
      final raw = statusStr.replaceAll('_', '').toLowerCase();
      return name == raw;
    }, orElse: () => SettlementStatus.pendingConfirmation);

    return SettlementModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      payerId: json['payerId'] as String,
      payeeId: json['payeeId'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: status,
      notes: json['notes'] as String?,
      proofPhotoUrl: json['proofPhotoUrl'] as String?,
      linkedTransactionId: json['linkedTransactionId'] as String?,
      createdAt: parseDate(json['createdAt']),
      confirmedAt: json['confirmedAt'] != null
          ? parseDate(json['confirmedAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? parseDate(json['updatedAt'])
          : parseDate(json['createdAt']),
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
      deletedAt: json['deletedAt'] != null
          ? parseDate(json['deletedAt'])
          : null,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
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
      'linkedTransactionId': linkedTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null
          ? Timestamp.fromDate(confirmedAt!)
          : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'syncStatus': syncStatus,
    };
  }

  factory SettlementModel.fromSqflite(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'pending_confirmation';
    final status = SettlementStatus.values.firstWhere((e) {
      final name = e.toString().split('.').last.toLowerCase();
      final raw = statusStr.replaceAll('_', '').toLowerCase();
      return name == raw;
    }, orElse: () => SettlementStatus.pendingConfirmation);

    return SettlementModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      payerId: map['payerId'] as String,
      payeeId: map['payeeId'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: status,
      notes: map['notes'] as String?,
      proofPhotoUrl: map['proofPhotoUrl'] as String?,
      linkedTransactionId: map['linkedTransactionId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int,
        isUtc: true,
      ),
      confirmedAt: map['confirmedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['confirmedAt'] as int,
              isUtc: true,
            )
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] as int,
        isUtc: true,
      ),
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAt'] as int,
              isUtc: true,
            )
          : null,
      syncStatus: map['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toSqflite() {
    String sqliteStatus;
    switch (status) {
      case SettlementStatus.pendingConfirmation:
        sqliteStatus = 'pending_confirmation';
        break;
      case SettlementStatus.confirmed:
        sqliteStatus = 'confirmed';
        break;
      case SettlementStatus.rejected:
        sqliteStatus = 'rejected';
        break;
    }

    return {
      'id': id,
      'groupId': groupId,
      'payerId': payerId,
      'payeeId': payeeId,
      'amount': amountVnd,
      'status': sqliteStatus,
      'notes': notes ?? '',
      'proofPhotoUrl': proofPhotoUrl ?? '',
      'linkedTransactionId': linkedTransactionId,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'confirmedAt': confirmedAt?.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      'syncStatus': syncStatus,
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
    String? linkedTransactionId,
    DateTime? createdAt,
    DateTime? confirmedAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? syncStatus,
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
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
