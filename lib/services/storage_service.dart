import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // Upload ảnh đại diện và trả về URL (có phương án dự phòng Base64 nếu Firebase Storage bị khóa billing/lỗi mạng)
  Future<String> uploadAvatar(File imageFile) async {
    if (_uid == null) throw Exception('User not logged in');

    try {
      // 1. Thử upload lên Firebase Storage
      final ref = _storage.ref().child('avatars/$_uid.jpg');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );
      final uploadTask = await ref.putFile(imageFile, metadata);
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e. Kích hoạt fallback Base64 lưu Firestore...');
      
      // 2. Dự phòng: Nếu Firebase Storage gặp lỗi (HTTP 402 billing closed, mạng lỗi...),
      // Tự động chuyển sang Base64 Data URI để đồng bộ an toàn qua Cloud Firestore
      try {
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      } catch (fallbackError) {
        throw Exception('Lỗi xử lý ảnh: $fallbackError (Storage: $e)');
      }
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
