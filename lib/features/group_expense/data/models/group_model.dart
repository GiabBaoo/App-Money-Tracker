import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int? iconCode;
  final String ownerId;
  final List<String> memberIds;
  final String
  groupType; // 'personal', 'couple', 'savings', 'group', 'trip', 'home'
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String syncStatus;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.iconCode,
    String? ownerId,
    String? adminId,
    required this.memberIds,
    this.groupType = 'group',
    this.currency = 'VND',
    required this.createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = 'synced',
  }) : ownerId = ownerId ?? adminId ?? '',
       updatedAt = updatedAt ?? createdAt;

  /// Getter tương thích ngược cho mã nguồn cũ sử dụng adminId
  String get adminId => ownerId;

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int)
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final owner =
        json['ownerId'] as String? ?? json['adminId'] as String? ?? '';
    final rawMembers = json['memberIds'];
    List<String> members = [];
    if (rawMembers is List) {
      members = rawMembers.map((e) => e.toString()).toList();
    } else if (rawMembers is String && rawMembers.isNotEmpty) {
      try {
        members = List<String>.from(jsonDecode(rawMembers) as List);
      } catch (_) {}
    }

    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      iconCode: json['iconCode'] as int?,
      ownerId: owner,
      memberIds: members,
      groupType: json['groupType'] as String? ?? 'group',
      currency: json['currency'] as String? ?? 'VND',
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
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
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'iconCode': iconCode,
      'ownerId': ownerId,
      'adminId':
          ownerId, // Lưu cả adminId phục vụ Firestore rules cũ và backward compatibility
      'memberIds': memberIds,
      'groupType': groupType,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'syncStatus': syncStatus,
    };
  }

  factory GroupModel.fromSqflite(
    Map<String, dynamic> map, {
    List<String>? members,
  }) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      iconUrl: map['iconUrl'] as String?,
      iconCode: map['iconCode'] as int?,
      ownerId: map['ownerId'] as String,
      memberIds: members ?? [],
      groupType: map['groupType'] as String? ?? 'group',
      currency: map['currency'] as String? ?? 'VND',
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
    );
  }

  Map<String, dynamic> toSqflite() {
    return {
      'id': id,
      'name': name,
      'description': description ?? '',
      'iconUrl': iconUrl ?? '',
      'iconCode': iconCode ?? 58145,
      'ownerId': ownerId,
      'groupType': groupType,
      'currency': currency,
      'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.toUtc().millisecondsSinceEpoch,
      'syncStatus': syncStatus,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    int? iconCode,
    String? ownerId,
    String? adminId,
    List<String>? memberIds,
    String? groupType,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      iconCode: iconCode ?? this.iconCode,
      ownerId: ownerId ?? adminId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      groupType: groupType ?? this.groupType,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
