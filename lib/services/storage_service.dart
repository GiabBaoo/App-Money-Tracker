import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // Upload ảnh đại diện và trả về URL
  Future<String> uploadAvatar(File imageFile) async {
    if (_uid == null) throw Exception('User not logged in');

    try {
      // Tạo reference đến Firebase Storage
      final ref = _storage.ref().child('avatars/$_uid.jpg');
      
      // Upload file
      final uploadTask = await ref.putFile(imageFile);
      
      // Lấy URL download
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Lỗi upload ảnh: $e');
    }
  }

  // Xóa ảnh đại diện cũ
  Future<void> deleteAvatar() async {
    if (_uid == null) return;

    try {
      final ref = _storage.ref().child('avatars/$_uid.jpg');
      await ref.delete();
    } catch (e) {
      // Nếu file không tồn tại thì bỏ qua
      debugPrint('Lỗi xóa ảnh: $e');
    }
  }
}
