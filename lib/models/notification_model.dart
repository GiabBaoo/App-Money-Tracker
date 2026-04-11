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
  final String? type; // 'group_invite', etc.
  final String? groupId;
  final String? groupName;
  final String? status; // 'accepted', 'rejected', etc.

  NotificationModel({
    this.id = '',
    required this.uid,
    required this.iconCode,
    required this.title,
    required this.description,
    this.isRead = false,
    DateTime? createdAt,
    this.type,
    this.groupId,
    this.groupName,
    this.status,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      type: data['type'] as String?,
      groupId: data['groupId'] as String?,
      groupName: data['groupName'] as String?,
      status: data['status'] as String?,
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
      if (type != null) 'type': type,
      if (groupId != null) 'groupId': groupId,
      if (groupName != null) 'groupName': groupName,
      if (status != null) 'status': status,
    };
  }
}
