import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String gender;
  final DateTime? dateOfBirth;
  final String avatarUrl;
  final String accountType;
  final DateTime joinDate;
  final String currency;
<<<<<<< HEAD
  final String role;
=======
  final Map<String, bool> dataUsage;
>>>>>>> funcionsettinggit

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.gender = 'Nam',
    this.dateOfBirth,
    this.avatarUrl = '',
    this.accountType = 'FREE',
    DateTime? joinDate,
    this.currency = 'VND',
<<<<<<< HEAD
    this.role = 'user',
  }) : joinDate = joinDate ?? DateTime.now();
=======
    Map<String, bool>? dataUsage,
  })  : joinDate = joinDate ?? DateTime.now(),
        dataUsage = dataUsage ??
            {
              'location': true,
              'contacts': false,
            };
>>>>>>> funcionsettinggit

  // Chuyển từ Firestore Document sang Object
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
<<<<<<< HEAD
      role: data['role'] ?? 'user',
=======
      dataUsage: data['dataUsage'] != null
          ? Map<String, bool>.from(data['dataUsage'] as Map)
          : null,
>>>>>>> funcionsettinggit
    );
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
<<<<<<< HEAD
      'role': role,
=======
      'dataUsage': dataUsage,
>>>>>>> funcionsettinggit
    };
  }
}
