import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_parse.dart';

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
    final rawParticipants = json['participantIds'];
    List<String> participants = [];
    if (rawParticipants is List) {
      participants = rawParticipants.map((e) => e.toString()).toList();
    }

    final rawShares = json['shares'];
    Map<String, double> sharesMap = {};
    if (rawShares is Map) {
      sharesMap = rawShares.map(
        (key, value) => MapEntry(
          key.toString(),
          FirestoreParse.parseDouble(value),
        ),
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

    final splitMethodStr = FirestoreParse.parseString(
      json['splitMethod'],
      defaultValue: 'equal',
    );
    final split = SplitMethod.values.firstWhere(
      (e) =>
          e.toString().split('.').last.toLowerCase() ==
          splitMethodStr.toLowerCase(),
      orElse: () => SplitMethod.equal,
    );

    final payerId = FirestoreParse.parseString(json['payerId']);
    return ExpenseModel(
      id: FirestoreParse.parseString(json['id']),
      groupId: FirestoreParse.parseString(json['groupId']),
      name: FirestoreParse.parseString(json['name']),
      amount: FirestoreParse.parseDouble(json['amount']),
      payerId: payerId,
      participantIds: participants,
      splitMethod: split,
      shares: sharesMap,
      category: FirestoreParse.parseString(
        json['category'],
        defaultValue: 'Khác',
      ),
      categoryIconCode: FirestoreParse.parseInt(json['categoryIconCode']) ?? 0,
      date: FirestoreParse.parseDate(json['date']) ?? DateTime.now(),
      notes: json['notes']?.toString(),
      photoUrls: photos,
      createdBy: FirestoreParse.parseString(
        json['createdBy'],
        defaultValue: payerId,
      ),
      linkedTransactionId: json['linkedTransactionId']?.toString(),
      createdAt: FirestoreParse.parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: FirestoreParse.parseDate(json['updatedAt']) ?? DateTime.now(),
      isDeleted: FirestoreParse.parseBool(json['isDeleted']),
      deletedAt: FirestoreParse.parseDate(json['deletedAt']),
      syncStatus: FirestoreParse.parseString(
        json['syncStatus'],
        defaultValue: 'synced',
      ),
      version: FirestoreParse.parseInt(json['version']) ?? 1,
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
