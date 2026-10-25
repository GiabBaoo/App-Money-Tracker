import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/category_utils.dart';

class TransactionModel {
  final String id;
  final String uid;
  final String type; // 'income' hoặc 'expense'
  final String category;
  final int
  categoryIconCode; // Lưu icon.codePoint vì Firestore không lưu được IconData
  final double amount;
  final DateTime date;
  final String time;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? groupId; // ID của quỹ (nếu là giao dịch quỹ)
  final int? groupIconCode; // Icon code của quỹ (nếu là giao dịch quỹ)
  final String source; // 'personal' hoặc 'fund' - để phân biệt loại giao dịch

  // Ảnh (hóa đơn, đồ ăn, vật dụng...)
  final bool hasPhoto;
  final String photoUrl; // URL tải ảnh từ Firebase Storage
  final String photoStoragePath; // Path trong Storage để xóa khi xóa giao dịch
  final String photoLocalPath; // Path ảnh lưu cục bộ trên thiết bị

  // Ví tiền / Nơi chứa tiền
  final String walletId;

  // Định danh chuyển tiền & mục tiêu tài chính
  final String? transferId; // Mã định danh liên kết cặp bút toán chuyển khoản
  final String? goalId; // Mã định danh mục tiêu tài chính liên quan

  // Trạng thái đồng bộ: 'synced', 'pending', 'failed'
  final String syncStatus;

  // Định danh vị trí GPS (Tên địa danh & Tọa độ)
  final String? location;
  final double? latitude;
  final double? longitude;

  // Soft Delete (Tombstone)
  final bool isDeleted;
  final DateTime? deletedAt;

  // Liên kết Sổ cái nhóm (Dual-Ledger)
  final String? groupExpenseId;

  TransactionModel({
    this.id = '',
    required this.uid,
    required this.type,
    required this.category,
    required this.categoryIconCode,
    required this.amount,
    required this.date,
    this.time = '',
    this.description = '',
    this.hasPhoto = false,
    this.photoUrl = '',
    this.photoStoragePath = '',
    this.photoLocalPath = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.groupId,
    this.groupIconCode,
    this.source = 'personal', // Default là personal
    this.walletId = '',
    this.transferId,
    this.goalId,
    this.groupExpenseId,
    this.syncStatus = 'synced',
    this.location,
    this.latitude,
    this.longitude,
    this.isDeleted = false,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Lấy IconData linh hoạt theo cấu hình hiện tại (hoặc fallback về codePoint đã lưu)
  IconData get icon =>
      CategoryUtils.getCategoryIcon(category, fallbackCode: categoryIconCode);

  bool get isIncome => type == 'income';

  /// Kiểm tra giao dịch có phải là chuyển tiền giữa các ví hay không
  bool get isTransfer =>
      (transferId != null && transferId!.isNotEmpty) ||
      (groupId != null && groupId!.startsWith('transfer_')) ||
      category == 'Chuyển tiền' ||
      category == 'Nhận chuyển tiền' ||
      category == 'Chuyển ví';

  // ════════ FIRESTORE ════════

  // Chuyển từ Firestore sang Object
  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final photoUrl = data['photoUrl'] as String? ?? '';
    final photoStoragePath = data['photoStoragePath'] as String? ?? '';
    final hasPhoto = data['hasPhoto'] as bool? ?? photoUrl.isNotEmpty;

    return TransactionModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      categoryIconCode: data['categoryIconCode'] ?? Icons.category.codePoint,
      amount: (data['amount'] ?? 0).toDouble(),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      time: data['time'] ?? '',
      description: data['description'] ?? '',
      hasPhoto: hasPhoto,
      photoUrl: photoUrl,
      photoStoragePath: photoStoragePath,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now()),
      groupId: data['groupId'],
      groupIconCode: data['groupIconCode'],
      source: data['source'] ?? 'personal', // Backward compatibility
      walletId: data['walletId'] as String? ?? '',
      transferId: data['transferId'] as String?,
      goalId: data['goalId'] as String?,
      groupExpenseId: data['groupExpenseId'] as String?,
      syncStatus: 'synced',
      location: data['location'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Chuyển Object sang Map để lưu vào Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'type': type,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'time': time,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'groupId': groupId,
      'groupIconCode': groupIconCode,
      'source': source,
      'walletId': walletId,
      if (transferId != null) 'transferId': transferId,
      if (goalId != null) 'goalId': goalId,
      if (groupExpenseId != null) 'groupExpenseId': groupExpenseId,
      'hasPhoto': hasPhoto,
      'photoUrl': photoUrl,
      'photoStoragePath': photoStoragePath,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  // ════════ SQLITE ════════

  // Chuyển từ SQLite row sang Object
  factory TransactionModel.fromSqlite(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      uid: map['uid'] as String,
      type: map['type'] as String,
      category: map['category'] as String,
      categoryIconCode: map['categoryIconCode'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      time: map['time'] as String? ?? '',
      description: map['description'] as String? ?? '',
      hasPhoto: (map['hasPhoto'] as int? ?? 0) == 1,
      photoUrl: map['photoUrl'] as String? ?? '',
      photoStoragePath: map['photoStoragePath'] as String? ?? '',
      photoLocalPath: map['photoLocalPath'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      groupId: map['groupId'] as String?,
      groupIconCode: map['groupIconCode'] as int?,
      source: map['source'] as String? ?? 'personal',
      walletId: map['walletId'] as String? ?? '',
      transferId: map['transferId'] as String?,
      goalId: map['goalId'] as String?,
      groupExpenseId: map['groupExpenseId'] as String?,
      syncStatus: map['syncStatus'] as String? ?? 'synced',
      location: map['location'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
      deletedAt: map['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deletedAt'] as int)
          : null,
    );
  }

  // Chuyển Object sang Map để lưu vào SQLite
  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'type': type,
      'category': category,
      'categoryIconCode': categoryIconCode,
      'amount': amount.round(),
      'date': date.millisecondsSinceEpoch,
      'time': time,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'hasPhoto': hasPhoto ? 1 : 0,
      'photoUrl': photoUrl,
      'photoStoragePath': photoStoragePath,
      'photoLocalPath': photoLocalPath,
      'groupId': groupId,
      'groupIconCode': groupIconCode,
      'source': source,
      'walletId': walletId,
      'transferId': transferId,
      'goalId': goalId,
      'groupExpenseId': groupExpenseId,
      'syncStatus': syncStatus,
      'location': location ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  // ════════ COPY WITH ════════

  TransactionModel copyWith({
    String? id,
    String? uid,
    String? type,
    String? category,
    int? categoryIconCode,
    double? amount,
    DateTime? date,
    String? time,
    String? description,
    bool? hasPhoto,
    String? photoUrl,
    String? photoStoragePath,
    String? photoLocalPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? groupId,
    int? groupIconCode,
    String? source,
    String? walletId,
    String? transferId,
    String? goalId,
    String? groupExpenseId,
    String? syncStatus,
    String? location,
    double? latitude,
    double? longitude,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearLocation = false,
    bool clearTransferId = false,
    bool clearGoalId = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      category: category ?? this.category,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      time: time ?? this.time,
      description: description ?? this.description,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      photoUrl: photoUrl ?? this.photoUrl,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      groupId: groupId ?? this.groupId,
      groupIconCode: groupIconCode ?? this.groupIconCode,
      source: source ?? this.source,
      walletId: walletId ?? this.walletId,
      transferId: clearTransferId ? null : (transferId ?? this.transferId),
      goalId: clearGoalId ? null : (goalId ?? this.goalId),
      groupExpenseId: groupExpenseId ?? this.groupExpenseId,
      syncStatus: syncStatus ?? this.syncStatus,
      location: clearLocation ? null : (location ?? this.location),
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
