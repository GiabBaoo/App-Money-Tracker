import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/firestore_parse.dart';

class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String role; // 'owner', 'admin', 'member'
  final String? nickname;
  final DateTime joinedAt;
  final String status; // 'active', 'left', 'removed'
  final DateTime? leftAt;
  final DateTime updatedAt;
  final String syncStatus;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    this.role = 'member',
    this.nickname,
    required this.joinedAt,
    this.status = 'active',
    this.leftAt,
    DateTime? updatedAt,
    this.syncStatus = 'synced',
  }) : updatedAt = updatedAt ?? joinedAt;

  Map<String, dynamic> toSqlite() => toSqflite();
  static GroupMemberModel fromSqlite(Map<String, dynamic> map) =>
      GroupMemberModel.fromSqflite(map);

  bool get isActive => status == 'active';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: FirestoreParse.parseString(json['id']),
      groupId: FirestoreParse.parseString(json['groupId']),
      userId: FirestoreParse.parseString(json['userId']),
      role: FirestoreParse.parseString(json['role'], defaultValue: 'member'),
      nickname: json['nickname']?.toString(),
      joinedAt: FirestoreParse.parseDate(json['joinedAt']) ?? DateTime.now(),
      status: FirestoreParse.parseString(json['status'], defaultValue: 'active'),
      leftAt: FirestoreParse.parseDate(json['leftAt']),
      updatedAt: FirestoreParse.parseDate(json['updatedAt']) ?? DateTime.now(),
      syncStatus: FirestoreParse.parseString(
        json['syncStatus'],
        defaultValue: 'synced',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'userId': userId,
      'role': role,
      'nickname': nickname,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'status': status,
      'leftAt': leftAt != null ? Timestamp.fromDate(leftAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'syncStatus': syncStatus,
    };
  }

  factory GroupMemberModel.fromSqflite(Map<String, dynamic> map) {
    return GroupMemberModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      userId: map['userId'] as String,
      role: map['role'] as String? ?? 'member',
      nickname: map['nickname'] as String?,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(
        map['joinedAt'] as int,
        isUtc: true,
      ),
      status: map['status'] as String? ?? 'active',
      leftAt: map['leftAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['leftAt'] as int,
              isUtc: true,
            )
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] as int,
        isUtc: true,
      ),
      syncStatus: map['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toSqflite() {
    return {
      'id': id,
      'groupId': groupId,
      'userId': userId,
      'role': role,
      'nickname': nickname ?? '',
      'joinedAt': joinedAt.toUtc().millisecondsSinceEpoch,
      'status': status,
      'leftAt': leftAt?.toUtc().millisecondsSinceEpoch,
      'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
      'syncStatus': syncStatus,
    };
  }

  GroupMemberModel copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? role,
    String? nickname,
    DateTime? joinedAt,
    String? status,
    DateTime? leftAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return GroupMemberModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      nickname: nickname ?? this.nickname,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      leftAt: leftAt ?? this.leftAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
