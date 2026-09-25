import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String gender;
  final DateTime? dateOfBirth;
  final String avatarUrl;
  final String avatarLocalPath;
  final String accountType;
  final DateTime joinDate;
  final String currency;
  final String role;
  final Map<String, dynamic> dataUsage;
  final List<dynamic> customCategories;
  final DateTime? lastPasswordUpdate;
  final String syncStatus;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.gender = 'Nam',
    this.dateOfBirth,
    this.avatarUrl = '',
    this.avatarLocalPath = '',
    this.accountType = 'FREE',
    DateTime? joinDate,
    this.currency = 'VND',
    this.role = 'user',
    Map<String, dynamic>? dataUsage,
    this.customCategories = const [],
    this.lastPasswordUpdate,
    this.syncStatus = 'synced',
  })  : joinDate = joinDate ?? DateTime.now(),
        dataUsage = dataUsage ??
            {
              'location': true,
              'contacts': false,
            };

  // ════════ FIRESTORE ════════

  // Chuyển từ Firestore Document sang Object
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return UserModel(
        uid: doc.id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        gender: data['gender'] ?? 'Nam',
        dateOfBirth: data['dateOfBirth'] != null
            ? (data['dateOfBirth'] as Timestamp).toDate()
            : null,
        avatarUrl: data['avatarUrl'] ?? '',
        accountType: data['accountType'] ?? 'FREE',
        joinDate: data['joinDate'] != null
            ? (data['joinDate'] as Timestamp).toDate()
            : DateTime.now(),
        currency: data['currency'] ?? 'VND',
        role: data['role'] ?? 'user',
        dataUsage: data['dataUsage'] is Map
            ? Map<String, dynamic>.from(data['dataUsage'] as Map)
            : {'location': true, 'contacts': false},
        customCategories: data['customCategories'] is List
            ? List<dynamic>.from(data['customCategories'] as List)
            : [],
        lastPasswordUpdate: data['lastPasswordUpdate'] != null
            ? (data['lastPasswordUpdate'] as Timestamp).toDate()
            : null,
        syncStatus: 'synced',
      );
    } catch (e) {
      debugPrint('UserModel parse error: $e');
      // Trả về object tối thiểu để tránh sập app hoàn toàn
      return UserModel(
        uid: doc.id,
        name: 'User',
        email: '',
        dataUsage: {'location': true, 'contacts': false},
        customCategories: [],
      );
    }
  }

  // Chuyển Object sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'avatarUrl': avatarUrl,
      'accountType': accountType,
      'joinDate': Timestamp.fromDate(joinDate),
      'currency': currency,
      'role': role,
      'dataUsage': dataUsage,
      'customCategories': customCategories,
      'lastPasswordUpdate': lastPasswordUpdate != null
          ? Timestamp.fromDate(lastPasswordUpdate!)
          : null,
    };
  }

  // ════════ SQLITE ════════

  factory UserModel.fromSqlite(Map<String, dynamic> map) {
    Map<String, dynamic> dataUsage;
    try {
      dataUsage = map['dataUsage'] != null
          ? Map<String, dynamic>.from(json.decode(map['dataUsage'] as String))
          : {'location': true, 'contacts': false};
    } catch (_) {
      dataUsage = {'location': true, 'contacts': false};
    }

    List<dynamic> customCategories;
    try {
      customCategories = map['customCategories'] != null
          ? List<dynamic>.from(json.decode(map['customCategories'] as String))
          : [];
    } catch (_) {
      customCategories = [];
    }

    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      gender: map['gender'] as String? ?? 'Nam',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] as int)
          : null,
      avatarUrl: map['avatarUrl'] as String? ?? '',
      avatarLocalPath: map['avatarLocalPath'] as String? ?? '',
      accountType: map['accountType'] as String? ?? 'FREE',
      joinDate: DateTime.fromMillisecondsSinceEpoch(map['joinDate'] as int),
      currency: map['currency'] as String? ?? 'VND',
      role: map['role'] as String? ?? 'user',
      dataUsage: dataUsage,
      customCategories: customCategories,
      lastPasswordUpdate: map['lastPasswordUpdate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastPasswordUpdate'] as int)
          : null,
      syncStatus: map['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'avatarUrl': avatarUrl,
      'avatarLocalPath': avatarLocalPath,
      'accountType': accountType,
      'joinDate': joinDate.millisecondsSinceEpoch,
      'currency': currency,
      'role': role,
      'dataUsage': json.encode(dataUsage),
      'customCategories': json.encode(customCategories),
      'lastPasswordUpdate': lastPasswordUpdate?.millisecondsSinceEpoch,
      'syncStatus': syncStatus,
    };
  }
}

