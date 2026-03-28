import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'email_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== TAO VA GUI MA OTP QUA EMAIL ====================
  Future<({bool success, String message})> sendOTP({
    required String email,
  }) async {
    try {
      final code = (100000 + Random().nextInt(900000)).toString();
      final expiry = DateTime.now().add(const Duration(minutes: 5));

      // Luu OTP vao Firestore
      await _firestore.collection('otp_codes').doc(email.trim().toLowerCase()).set({
        'code': code,
        'email': email.trim().toLowerCase(),
        'expiry': Timestamp.fromDate(expiry),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gui email that qua SMTP
      final emailResult = await EmailService.sendOTPEmail(
        toEmail: email.trim(),
        otpCode: code,
      );

      if (emailResult.success) {
        return (success: true, message: 'Ma OTP da duoc gui den $email');
      } else {
        return (success: false, message: emailResult.message);
      }
    } catch (e) {
      return (success: false, message: 'Loi gui OTP: $e');
    }
  }

  // ==================== XAC THUC OTP ====================
  Future<({bool success, String message})> verifyOTP({
    required String email,
    required String otpCode,
  }) async {
    try {
      final doc = await _firestore
          .collection('otp_codes')
          .doc(email.trim().toLowerCase())
          .get();

      if (!doc.exists) {
        return (success: false, message: 'Khong tim thay ma OTP! Vui long gui lai.');
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiry = (data['expiry'] as Timestamp).toDate();

      if (DateTime.now().isAfter(expiry)) {
        await doc.reference.delete();
        return (success: false, message: 'Ma OTP da het han! Vui long gui lai.');
      }

      if (storedCode != otpCode) {
        return (success: false, message: 'Ma OTP khong dung!');
      }

      await doc.reference.delete();
      return (success: true, message: 'Xac thuc thanh cong!');
    } catch (e) {
      return (success: false, message: 'Loi xac thuc: $e');
    }
  }

  // ==================== DANG KY ====================
  Future<({bool success, String message})> register({
    required String name,
    required String email,
    required String phone,
    required String gender,
    required String password,
    DateTime? dateOfBirth,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      try {
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
      } catch (firestoreError) {
        print('Firestore loi (nhung Auth OK): $firestoreError');
      }

      return (success: true, message: 'Dang ky thanh cong!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Da xay ra loi: $e');
    }
  }

  // ==================== DANG NHAP ====================
  Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Ghi lại thời điểm đăng nhập để đồng bộ trạng thái sinh trắc học theo người dùng.
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore
            .collection('biometric_prefs')
            .doc(uid)
            .set(
              {'lastPasswordLoginAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
      }
      return (success: true, message: 'Dang nhap thanh cong!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi khong xac dinh: $e');
    }
  }

  // ==================== DANG XUAT ====================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ==================== DOI MAT KHAU ====================
  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (success: false, message: 'Chua dang nhap!');

      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return (success: true, message: 'Doi mat khau thanh cong!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return (success: false, message: 'Mat khau hien tai khong dung!');
      }
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi: $e');
    }
  }

  // ==================== GUI EMAIL RESET PASSWORD (LUONG QUEN MK) ====================
  Future<({bool success, String message})> resetPasswordWithEmail({
    required String email,
    required String newPassword,
    required String otpCode,
  }) async {
    try {
      // Xác thực OTP trước
      final verifyResult = await verifyOTP(email: email, otpCode: otpCode);
      if (!verifyResult.success) {
        return (success: false, message: verifyResult.message);
      }

      // Sau khi OTP hợp lệ, gửi email reset password
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      // Lưu mật khẩu mới tạm thời (user sẽ click link trong email để hoàn thành)
      await _firestore.collection('password_resets').doc(email.trim()).set({
        'email': email.trim(),
        'newPassword': newPassword,
        'createdAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(hours: 1)),
      });

      return (success: true, message: 'Email đặt lại mật khẩu đã được gửi!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Lỗi: $e');
    }
  }

  // ==================== XAC THUC MAT KHAU HIEN TAI ====================
  Future<({bool success, String message})> verifyCurrentPassword({
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (success: false, message: 'Chua dang nhap!');

      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return (success: true, message: 'Xac thuc thanh cong!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return (success: false, message: 'Mat khau khong dung!');
      }
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi: $e');
    }
  }

  // ==================== XOA TAI KHOAN ====================
  Future<({bool success, String message})> deleteAccount({
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (success: false, message: 'Chua dang nhap!');

      final rawEmail = user.email?.trim();
      final lowerEmail = rawEmail?.toLowerCase();

      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      await _deleteUserData(user.uid, rawEmail: rawEmail, lowerEmail: lowerEmail);
      await user.delete();
      return (success: true, message: 'Xoa tai khoan thanh cong!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi: $e');
    }
  }

  Future<void> _deleteUserData(
    String uid, {
    String? rawEmail,
    String? lowerEmail,
  }) async {
    // Firestore batch tối đa 500 thao tác/1 batch, nên cần chia nhỏ để tránh lỗi.
    Future<void> _deleteInChunks(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
      const chunkSize = 450; // dư địa an toàn so với limit 500
      final docList = docs.toList();
      for (int i = 0; i < docList.length; i += chunkSize) {
        final batch = _firestore.batch();
        final end = (i + chunkSize).clamp(0, docList.length);
        for (int j = i; j < end; j++) {
          batch.delete(docList[j].reference);
        }
        await batch.commit();
      }
    }

    final transactions = await _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteInChunks(transactions.docs);

    final notifications = await _firestore
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteInChunks(notifications.docs);

    final messages = await _firestore
        .collection('messages')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteInChunks(messages.docs);

    final deviceSessions = await _firestore
        .collection('device_sessions')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteInChunks(deviceSessions.docs);

    // Xóa hồ sơ user (dạng doc cố định theo uid)
    await _firestore.collection('users').doc(uid).delete();

    // Xóa cài đặt sinh trắc học của user
    await _firestore.collection('biometric_prefs').doc(uid).delete();

    // Xóa dữ liệu khôi phục tài khoản theo email (nếu tồn tại)
    if (lowerEmail != null && lowerEmail.isNotEmpty) {
      await _firestore.collection('otp_codes').doc(lowerEmail).delete();
    }
    if (rawEmail != null && rawEmail.isNotEmpty) {
      await _firestore.collection('password_resets').doc(rawEmail).delete();
    }
  }

  // ==================== LAY THONG TIN USER ====================
  Future<UserModel?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) { return null; }
  }

  Stream<UserModel?> getUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _firestore.collection('users').doc(user.uid).snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // ==================== MA LOI TIENG VIET ====================
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Email nay da duoc su dung!';
      case 'invalid-email': return 'Email khong hop le!';
      case 'weak-password': return 'Mat khau qua yeu!';
      case 'user-not-found': return 'Khong tim thay tai khoan!';
      case 'wrong-password': return 'Mat khau khong dung!';
      case 'invalid-credential': return 'Email hoac mat khau khong dung!';
      case 'user-disabled': return 'Tai khoan da bi khoa!';
      case 'too-many-requests': return 'Qua nhieu lan thu! Doi mot lat.';
      case 'network-request-failed': return 'Loi mang! Kiem tra Internet.';
      default: return 'Loi ($code)';
    }
  }
}
