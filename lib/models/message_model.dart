import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessageModel {
  final String id;
  final String uid;
  final int iconCode;
  final int iconBgColorValue;
  final String title;
  final String shortMessage;
  final String fullMessage;
  final bool isUnread;
  final DateTime createdAt;

  MessageModel({
    this.id = '',
    required this.uid,
    required this.iconCode,
    required this.iconBgColorValue,
    required this.title,
    required this.shortMessage,
    required this.fullMessage,
    this.isUnread = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      iconCode: data['iconCode'] ?? Icons.message.codePoint,
      iconBgColorValue: data['iconBgColorValue'] ?? 0xFF438883,
      title: data['title'] ?? '',
      shortMessage: data['shortMessage'] ?? '',
      fullMessage: data['fullMessage'] ?? '',
      isUnread: data['isUnread'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'iconCode': iconCode,
      'iconBgColorValue': iconBgColorValue,
      'title': title,
      'shortMessage': shortMessage,
      'fullMessage': fullMessage,
      'isUnread': isUnread,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
