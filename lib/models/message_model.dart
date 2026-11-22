import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/utils/firestore_parse.dart';

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
  final DateTime? updatedAt;
  final String syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

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
    DateTime? updatedAt,
    this.syncStatus = 'synced',
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  // ════════ FIRESTORE ════════

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      uid: FirestoreParse.parseString(data['uid']),
      iconCode:
          FirestoreParse.parseInt(data['iconCode']) ?? Icons.message.codePoint,
      iconBgColorValue:
          FirestoreParse.parseInt(data['iconBgColorValue']) ?? 0xFF438883,
      title: FirestoreParse.parseString(data['title']),
      shortMessage: FirestoreParse.parseString(data['shortMessage']),
      fullMessage: FirestoreParse.parseString(data['fullMessage']),
      isUnread: FirestoreParse.parseBool(data['isUnread'], defaultValue: true),
      createdAt: FirestoreParse.parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: FirestoreParse.parseDate(data['updatedAt']),
      syncStatus: 'synced',
      isDeleted: FirestoreParse.parseBool(data['isDeleted']),
      deletedAt: FirestoreParse.parseDate(data['deletedAt']),
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
      'updatedAt': Timestamp.fromDate(updatedAt ?? createdAt),
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  // ════════ SQLITE ════════

  factory MessageModel.fromSqlite(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      uid: map['uid'] as String,
      iconCode: map['iconCode'] as int,
      iconBgColorValue: map['iconBgColorValue'] as int,
      title: map['title'] as String,
      shortMessage: map['shortMessage'] as String,
      fullMessage: map['fullMessage'] as String,
      isUnread: (map['isUnread'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
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
      'iconBgColorValue': iconBgColorValue,
      'title': title,
      'shortMessage': shortMessage,
      'fullMessage': fullMessage,
      'isUnread': isUnread ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': (updatedAt ?? createdAt).millisecondsSinceEpoch,
      'syncStatus': syncStatus,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }
}
