import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceSessionModel {
  final String id; // Document ID (thường là mã hash của thiết bị)
  final String uid; // ID của người dùng
  final String deviceName; // iPhone 13 Pro, Trình duyệt Chrome...
  final String deviceType; // mobile, desktop, laptop
  final String location; // Vị trí (VD: IP hiện tại)
  final DateTime lastActive; // Lần đăng nhập cuối
  final String syncStatus;

  DeviceSessionModel({
    required this.id,
    required this.uid,
    required this.deviceName,
    required this.deviceType,
    required this.location,
    DateTime? lastActive,
    this.syncStatus = 'synced',
  }) : lastActive = lastActive ?? DateTime.now();

  // ════════ FIRESTORE ════════

  factory DeviceSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime lastActive = DateTime.now();
    final rawActive = data['lastActive'];
    if (rawActive is Timestamp) {
      lastActive = rawActive.toDate();
    } else if (rawActive is int) {
      lastActive = DateTime.fromMillisecondsSinceEpoch(rawActive);
    } else if (rawActive is String) {
      lastActive = DateTime.tryParse(rawActive) ?? DateTime.now();
    }
    return DeviceSessionModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      deviceName: data['deviceName'] ?? 'Thiết bị không xác định',
      deviceType: data['deviceType'] ?? 'mobile',
      location: data['location'] ?? 'Không rõ',
      lastActive: lastActive,
      syncStatus: 'synced',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'location': location,
      'lastActive': Timestamp.fromDate(lastActive),
    };
  }

  // ════════ SQLITE ════════

  factory DeviceSessionModel.fromSqlite(Map<String, dynamic> map) {
    DateTime lastActive = DateTime.now();
    final rawActive = map['lastActive'];
    if (rawActive is int) {
      lastActive = DateTime.fromMillisecondsSinceEpoch(rawActive);
    } else if (rawActive is String) {
      lastActive = DateTime.tryParse(rawActive) ?? DateTime.now();
    }
    return DeviceSessionModel(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Thiết bị không xác định',
      deviceType: map['deviceType'] as String? ?? 'mobile',
      location: map['location'] as String? ?? '',
      lastActive: lastActive,
      syncStatus: map['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'uid': uid,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'location': location,
      'lastActive': lastActive.millisecondsSinceEpoch,
      'syncStatus': syncStatus,
    };
  }
}

