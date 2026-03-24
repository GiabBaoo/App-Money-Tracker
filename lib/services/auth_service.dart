import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lấy user hiện tại
  User? get currentUser => _auth.currentUser;

  // Stream theo dõi trạng thái đăng nhập (dùng cho StreamBuilder)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== ĐĂNG KÝ ====================
  Future<({bool success, String message})> register({
    required String name,
    required String email,
    required String phone,
    required String gender,
    required String password,
    DateTime? dateOfBirth,
  }) async {
    try {
      // 1. Tạo tài khoản trên Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // 2. Cập nhật tên hiển thị
      await credential.user?.updateDisplayName(name);

      // 3. Lưu thông tin chi tiết vào Firestore
      final user = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email.trim(),
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toFirestore());

      return (success: true, message: 'Đăng ký thành công!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi không xác định: $e');
    }
  }

  // ==================== ĐĂNG NHẬP ====================
  Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return (success: true, message: 'Đăng nhập thành công!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi không xác định: $e');
    }
  }

  // ==================== ĐĂNG XUẤT ====================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ==================== QUÊN MẬT KHẨU ====================
  Future<({bool success, String message})> resetPassword({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return (
        success: true,
        message: 'Email khôi phục đã được gửi! Vui lòng kiểm tra hộp thư.',
      );
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi không xác định: $e');
    }
  }

  // ==================== ĐỔI MẬT KHẨU ====================
  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Chưa đăng nhập!');
      }

      // Xác thực lại bằng mật khẩu hiện tại
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Đổi sang mật khẩu mới
      await user.updatePassword(newPassword);
      return (success: true, message: 'Đổi mật khẩu thành công!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return (success: false, message: 'Mật khẩu hiện tại không đúng!');
      }
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi không xác định: $e');
    }
  }

  // ==================== XÁC THỰC MẬT KHẨU HIỆN TẠI ====================
  Future<({bool success, String message})> verifyCurrentPassword({
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Chưa đăng nhập!');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return (success: true, message: 'Xác thực thành công!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return (success: false, message: 'Mật khẩu không đúng!');
      }
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi: $e');
    }
  }

  // ==================== XÓA TÀI KHOẢN ====================
  Future<({bool success, String message})> deleteAccount({
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Chưa đăng nhập!');
      }

      // Xác thực lại
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Xóa dữ liệu Firestore trước
      await _deleteUserData(user.uid);

      // Xóa tài khoản Auth
      await user.delete();
      return (success: true, message: 'Xóa tài khoản thành công!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi: $e');
    }
  }

  // Xóa toàn bộ dữ liệu user trong Firestore
  Future<void> _deleteUserData(String uid) async {
    final batch = _firestore.batch();

    // Xóa transactions
    final transactions = await _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .get();
    for (var doc in transactions.docs) {
      batch.delete(doc.reference);
    }

    // Xóa notifications
    final notifications = await _firestore
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .get();
    for (var doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    // Xóa user document
    batch.delete(_firestore.collection('users').doc(uid));

    await batch.commit();
  }

  // ==================== LẤY THÔNG TIN USER ====================
  Future<UserModel?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  // Stream thông tin user (realtime)
  Stream<UserModel?> getUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // ==================== HÀM CHUYỂN MÃ LỖI FIREBASE SANG TIẾNG VIỆT ====================
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email này đã được sử dụng bởi tài khoản khác!';
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ!';
      case 'weak-password':
        return 'Mật khẩu quá yếu! Cần ít nhất 6 ký tự.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này!';
      case 'wrong-password':
        return 'Mật khẩu không chính xác!';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng!';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa!';
      case 'too-many-requests':
        return 'Quá nhiều lần thử! Vui lòng đợi một lát.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng! Kiểm tra Internet.';
      default:
        return 'Đã xảy ra lỗi ($code)';
    }
  }
}
