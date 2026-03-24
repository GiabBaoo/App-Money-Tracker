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

  NotificationModel({
    this.id = '',
    required this.uid,
    required this.iconCode,
    required this.title,
    required this.description,
    this.isRead = false,
    DateTime? createdAt,
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
    };
  }
}
