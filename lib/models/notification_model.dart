import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String uid;
  final int iconCode;
  final String title;
  final String description;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? type; // 'group_invite', etc.
  final String? groupId;
  final String? groupName;
  final String? status; // 'accepted', 'rejected', etc.
  final String syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

  NotificationModel({
    this.id = '',
    required this.uid,
    required this.iconCode,
    required this.title,
    required this.description,
    this.isRead = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.type,
    this.groupId,
    this.groupName,
    this.status,
    this.syncStatus = 'synced',
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  // ════════ FIRESTORE ════════

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      iconCode: data['iconCode'] ?? Icons.notifications.codePoint,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      type: data['type'] as String?,
      groupId: data['groupId'] as String?,
      groupName: data['groupName'] as String?,
      status: data['status'] as String?,
      syncStatus: 'synced',
      isDeleted: data['isDeleted'] == true,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'iconCode': iconCode,
      'title': title,
      'description': description,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? createdAt),
      if (type != null) 'type': type,
      if (groupId != null) 'groupId': groupId,
      if (groupName != null) 'groupName': groupName,
      if (status != null) 'status': status,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  // ════════ SQLITE ════════

  factory NotificationModel.fromSqlite(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      uid: map['uid'] as String,
      iconCode: map['iconCode'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      isRead: (map['isRead'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      type: map['type'] as String?,
      groupId: map['groupId'] as String?,
      groupName: map['groupName'] as String?,
      status: map['status'] as String?,
      syncStatus: map['syncStatus'] as String? ?? 'synced',
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'iconCode': iconCode,
      'title': title,
      'description': description,
      'isRead': isRead ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': (updatedAt ?? createdAt).millisecondsSinceEpoch,
      'type': type,
      'groupId': groupId,
      'groupName': groupName,
      'status': status,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }
}
