import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitMethod { equal, custom, singlePayer, percentage, shares, exact }

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
  final int categoryIconCode;
  final DateTime date;
  final String? notes;
  final List<String> photoUrls;
  final String createdBy;
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String syncStatus;
  final int version;

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
    this.categoryIconCode = 0,
    required this.date,
    this.notes,
    required this.photoUrls,
    required this.createdBy,
    this.linkedTransactionId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = 'synced',
    this.version = 1,
  });

  /// Số tiền làm tròn nguyên đồng VND
  int get amountVnd => amount.round();

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int)
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawParticipants = json['participantIds'];
    List<String> participants = [];
    if (rawParticipants is List) {
      participants = rawParticipants.map((e) => e.toString()).toList();
    }

    final rawShares = json['shares'];
    Map<String, double> sharesMap = {};
    if (rawShares is Map) {
      sharesMap = rawShares.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
    }

    final rawPhotos = json['photoUrls'];
    List<String> photos = [];
    if (rawPhotos is List) {
      photos = rawPhotos.map((e) => e.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.isNotEmpty) {
      try {
        photos = List<String>.from(jsonDecode(rawPhotos) as List);
      } catch (_) {}
    }

    final splitMethodStr = json['splitMethod'] as String? ?? 'equal';
    final split = SplitMethod.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          splitMethodStr.toLowerCase(),
      orElse: () => SplitMethod.equal,
    );

    return ExpenseModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      payerId: json['payerId'] as String,
      participantIds: participants,
      splitMethod: split,
      shares: sharesMap,
      category: json['category'] as String? ?? 'Khác',
      categoryIconCode: (json['categoryIconCode'] as num?)?.toInt() ?? 0,
      date: parseDate(json['date']),
      notes: json['notes'] as String?,
      photoUrls: photos,
      createdBy: json['createdBy'] as String? ?? json['payerId'] as String,
      linkedTransactionId: json['linkedTransactionId'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      isDeleted: json['isDeleted'] == true || json['isDeleted'] == 1,
      deletedAt: json['deletedAt'] != null
          ? parseDate(json['deletedAt'])
          : null,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
      version: (json['version'] as num?)?.toInt() ?? 1,
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
      'categoryIconCode': categoryIconCode,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'linkedTransactionId': linkedTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'syncStatus': syncStatus,
      'version': version,
    };
  }

  factory ExpenseModel.fromSqflite(
    Map<String, dynamic> map, {
    List<String>? participants,
    Map<String, double>? shares,
  }) {
    List<String> photos = [];
    final rawPhotos = map['photoUrls'] as String?;
    if (rawPhotos != null && rawPhotos.isNotEmpty) {
      try {
        photos = List<String>.from(jsonDecode(rawPhotos) as List);
      } catch (_) {}
    }

    final splitMethodStr = map['splitMethod'] as String? ?? 'equal';
    final split = SplitMethod.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          splitMethodStr.toLowerCase(),
      orElse: () => SplitMethod.equal,
    );

    return ExpenseModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      payerId: map['payerId'] as String,
      participantIds:
          participants ?? (shares != null ? shares.keys.toList() : []),
      splitMethod: split,
      shares: shares ?? {},
      category: map['category'] as String? ?? 'Khác',
      categoryIconCode: (map['categoryIconCode'] as num?)?.toInt() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int,
        isUtc: true,
      ),
      notes: map['notes'] as String?,
      photoUrls: photos,
      createdBy: map['createdBy'] as String,
      linkedTransactionId: map['linkedTransactionId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] as int,
        isUtc: true,
      ),
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
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toSqflite() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'amount': amountVnd,
      'payerId': payerId,
      'createdBy': createdBy,
      'splitMethod': splitMethod.toString().split('.').last,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'date': date.toUtc().millisecondsSinceEpoch,
      'notes': notes ?? '',
      'photoUrls': jsonEncode(photoUrls),
      'linkedTransactionId': linkedTransactionId,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      'syncStatus': syncStatus,
      'version': version,
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? groupId,
    String? name,
    double? amount,
    String? payerId,
    List<String>? participantIds,
    SplitMethod? splitMethod,
    Map<String, double>? shares,
    String? category,
    int? categoryIconCode,
    DateTime? date,
    String? notes,
    List<String>? photoUrls,
    String? createdBy,
    String? linkedTransactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? syncStatus,
    int? version,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      payerId: payerId ?? this.payerId,
      participantIds: participantIds ?? this.participantIds,
      splitMethod: splitMethod ?? this.splitMethod,
      shares: shares ?? this.shares,
      category: category ?? this.category,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }
}
