import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceSessionModel {
  final String id; // Document ID (thường là mã hash của thiết bị)
  final String uid; // ID của người dùng
  final String deviceName; // iPhone 13 Pro, Trình duyệt Chrome...
  final String deviceType; // mobile, desktop, laptop
  final String location; // Vị trí (VD: IP hiện tại)
  final DateTime lastActive; // Lần đăng nhập cuối

  DeviceSessionModel({
    required this.id,
    required this.uid,
    required this.deviceName,
    required this.deviceType,
    required this.location,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  factory DeviceSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceSessionModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      deviceName: data['deviceName'] ?? 'Thiết bị không xác định',
      deviceType: data['deviceType'] ?? 'mobile',
      location: data['location'] ?? 'Không rõ',
      lastActive: data['lastActive'] != null
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
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
}
