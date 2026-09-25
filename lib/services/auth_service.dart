import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../data/local/database_helper.dart';
import 'email_service.dart';
import 'firestore_service.dart';
import 'connectivity_service.dart';
import '../utils/device_utils.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/message_repository.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isOfflineSession = false;
  String? _offlineUid;

  /// Phiên offline chỉ đúng khi thực sự MẤT KẾT NỐI MẠNG hoặc đăng nhập offline không có Firebase Auth
  bool get isOfflineSession {
    if (ConnectivityService().isOnline && _auth.currentUser != null) {
      return false;
    }
    if (!ConnectivityService().isOnline) {
      return true;
    }
    return _isOfflineSession;
  }

  String? get offlineUid => _offlineUid;
  String? get currentUid => _auth.currentUser?.uid ?? _offlineUid;

  /// Thiết lập người dùng đăng nhập trực tuyến (Online)
  void setOnlineUid(String uid) {
    _offlineUid = uid;
    _isOfflineSession = false;
    _configureRepositories(uid);
  }

  /// Thiết lập người dùng ngoại tuyến (Offline)
  void setOfflineUid(String uid) {
    _offlineUid = uid;
    _isOfflineSession = true;
    _configureRepositories(uid);
  }

  /// Lấy UID offline đã lưu gần nhất
  Future<String?> getLastOfflineUid() async {
    try {
      return await _secureStorage.read(key: 'last_offline_uid');
    } catch (e) {
      return null;
    }
  }

  /// Khởi tạo phiên offline nếu có UID lưu trước đó
  Future<String?> initOfflineSession() async {
    if (_auth.currentUser != null) {
      setOnlineUid(_auth.currentUser!.uid);
      return _auth.currentUser!.uid;
    }
    final savedUid = await getLastOfflineUid();
    if (savedUid != null && savedUid.isNotEmpty) {
      setOfflineUid(savedUid);
      // Nếu có mạng, cố gắng silent re-authenticate để khôi phục quyền Firebase ngầm
      if (ConnectivityService().isOnline) {
        silentReauthenticateIfNeeded();
      }
      return savedUid;
    }
    return null;
  }

  /// Thực hiện xác thực ngầm với Firebase Auth nếu currentUser đang null
  /// (ví dụ: mở app từ phiên offline, mở lại app, hoặc đăng nhập bằng vân tay)
  Future<bool> silentReauthenticateIfNeeded() async {
    if (_auth.currentUser != null) {
      _isOfflineSession = false;
      return true;
    }

    if (!ConnectivityService().isOnline) {
      return false;
    }

    try {
      final email = await _secureStorage.read(key: 'last_offline_email');
      final pass = await _secureStorage.read(key: 'last_auth_password');
      final rememberPass = await _secureStorage.read(key: 'saved_login_password');
      final password = pass ?? rememberPass;

      if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
        debugPrint('AuthService: Running silent background re-authentication for $email...');
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        if (cred.user != null) {
          final uid = cred.user!.uid;
          setOnlineUid(uid);
          debugPrint('AuthService: Silent re-authentication succeeded for uid $uid');
          return true;
        }
      }
    } catch (e) {
      debugPrint('AuthService: Silent re-authentication error: $e');
    }
    return false;
  }

  void _configureRepositories(String uid) {
    TransactionRepository().setUid(uid);
    WalletRepository().setUid(uid);
    UserRepository().setUid(uid);
    NotificationRepository().setUid(uid);
    MessageRepository().setUid(uid);
  }

  static String _hashPassword(String email, String password) {
    final salt = 'MONO_OFFLINE_SALT_${email.trim().toLowerCase()}';
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _saveOfflineCredentials({
    required String email,
    required String password,
    required String uid,
  }) async {
    try {
      final hash = _hashPassword(email, password);
      final normalizedEmail = email.trim().toLowerCase();
      await _secureStorage.write(key: 'offline_auth_hash_$normalizedEmail', value: hash);
      await _secureStorage.write(key: 'offline_auth_uid_$normalizedEmail', value: uid);
      await _secureStorage.write(key: 'offline_auth_pass_$normalizedEmail', value: password);
      await _secureStorage.write(key: 'last_offline_email', value: normalizedEmail);
      await _secureStorage.write(key: 'last_offline_uid', value: uid);
      await _secureStorage.write(key: 'last_auth_password', value: password);
    } catch (e) {
      debugPrint('Error saving offline credentials: $e');
    }
  }

  Future<({bool success, String message})> loginOffline({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final savedHash = await _secureStorage.read(key: 'offline_auth_hash_$normalizedEmail');
      final savedUid = await _secureStorage.read(key: 'offline_auth_uid_$normalizedEmail');
      final savedPass = await _secureStorage.read(key: 'offline_auth_pass_$normalizedEmail');

      final inputHash = _hashPassword(email, password);

      if (savedHash != null && savedUid != null) {
        if (inputHash == savedHash || (savedPass != null && savedPass == password)) {
          setOfflineUid(savedUid);
          return (success: true, message: 'Đăng nhập ngoại tuyến thành công!');
        } else {
          return (success: false, message: 'Mật khẩu ngoại tuyến không chính xác!');
        }
      }

      // ─── CƠ CHẾ DỰ PHÒNG TỪ SQLITE KHI BẢO MẬT HỆ THỐNG RESET KEY ───
      try {
        final db = await DatabaseHelper().database;
        final results = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [normalizedEmail]);
        if (results.isNotEmpty) {
          final userMap = results.first;
          final uid = userMap['uid'] as String?;
          if (uid != null) {
            final lastPass = await _secureStorage.read(key: 'last_auth_password');
            final savedLoginPass = await _secureStorage.read(key: 'saved_login_password');
            if (lastPass == password || savedLoginPass == password) {
              await _saveOfflineCredentials(email: email, password: password, uid: uid);
              setOfflineUid(uid);
              return (success: true, message: 'Đăng nhập ngoại tuyến thành công!');
            }
          }
        }
      } catch (_) {}

      return (
        success: false,
        message: 'Không có kết nối mạng! Vui lòng kết nối Internet lần đầu để lưu dữ liệu ngoại tuyến.',
      );
    } catch (e) {
      return (success: false, message: 'Lỗi xác thực ngoại tuyến: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== GUI EMAIL XAC NHAN ====================
  Future<({bool success, String message})> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Khong tim thay nguoi dung!');
      }
      
      await user.sendEmailVerification();
      return (success: true, message: 'Email xac nhan da duoc gui!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi: $e');
    }
  }

  // ==================== RELOAD USER VA KIEM TRA EMAIL VERIFIED ====================
  Future<({bool success, String message, bool emailVerified})> reloadAndCheckEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Khong tim thay nguoi dung!', emailVerified: false);
      }
      
      await user.reload();
      final updatedUser = _auth.currentUser;
      
      if (updatedUser == null) {
        return (success: false, message: 'Co loi xay ra!', emailVerified: false);
      }
      
      if (updatedUser.emailVerified) {
        return (success: true, message: 'Email da duoc xac nhan!', emailVerified: true);
      } else {
        return (success: false, message: 'Email chua duoc xac nhan. Vui long kiem tra hop thu.', emailVerified: false);
      }
    } catch (e) {
      return (success: false, message: 'Loi: $e', emailVerified: false);
    }
  }

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
        debugPrint('Firestore loi (nhung Auth OK): $firestoreError');
      }

      // GUI EMAIL XAC NHAN
      try {
        await credential.user?.sendEmailVerification();
      } catch (emailError) {
        debugPrint('Gui email xac nhan loi: $emailError');
      }

      // ─── LƯU THÔNG TIN XÁC THỰC OFFLINE NGAY KHI ĐĂNG KÝ ───
      if (credential.user != null) {
        final uid = credential.user!.uid;
        await _saveOfflineCredentials(
          email: email,
          password: password,
          uid: uid,
        );
        try {
          final localUser = UserModel(
            uid: uid,
            name: name,
            email: email.trim(),
            phone: phone,
            gender: gender,
            dateOfBirth: dateOfBirth,
          );
          await UserRepository().saveUser(localUser);
        } catch (_) {}
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
    final normalizedEmail = email.trim().toLowerCase();

    // ─── BƯỚC 1: XÁC THỰC CỤC BỘ TỨC THÌ (FAST-PASS AUTH < 30ms) ───
    // Nếu người dùng đã từng đăng nhập tài khoản này trên thiết bị, kiểm tra hash an toàn ngay lập tức
    try {
      final savedHash = await _secureStorage.read(key: 'offline_auth_hash_$normalizedEmail');
      final savedUid = await _secureStorage.read(key: 'offline_auth_uid_$normalizedEmail');
      final savedPass = await _secureStorage.read(key: 'offline_auth_pass_$normalizedEmail');
      final inputHash = _hashPassword(email, password);

      final bool isLocalPasswordMatch = savedUid != null &&
          (inputHash == savedHash || (savedPass != null && savedPass == password));

      if (isLocalPasswordMatch) {
        final bool isConnOnline = ConnectivityService().isOnline;
        if (isConnOnline) {
          setOnlineUid(savedUid);
        } else {
          setOfflineUid(savedUid);
        }

        // Cập nhật lại mật khẩu xác thực mới nhất
        await _secureStorage.write(key: 'last_offline_email', value: normalizedEmail);
        await _secureStorage.write(key: 'last_offline_uid', value: savedUid);
        await _secureStorage.write(key: 'last_auth_password', value: password);

        // Kích hoạt đồng bộ ngầm và xác thực Firebase Auth ở chế độ nền (KHÔNG CHẶN MÀN HÌNH)
        if (isConnOnline) {
          unawaited(_runBackgroundAuthSync(normalizedEmail, password, savedUid));
        }

        return (
          success: true,
          message: isConnOnline ? 'Đăng nhập thành công!' : 'Đăng nhập ngoại tuyến thành công!',
        );
      }
    } catch (e) {
      debugPrint('AuthService: Fast-pass check error: $e');
    }

    // ─── BƯỚC 2: NẾU CHƯA CÓ TRÊN LOCAL HOẶC MẬT KHẨU SAI TRÊN LOCAL ───
    // Nếu không có mạng: Thử kiểm tra SQLite fallback hoặc báo lỗi mật khẩu
    final bool isConnOnline = ConnectivityService().isOnline;
    if (!isConnOnline) {
      return await loginOffline(email: email, password: password);
    }

    // Nếu có mạng: Gọi trực tiếp Firebase Auth (đối với thiết bị mới hoặc người dùng vừa đổi pass từ máy khác)
    try {
      // Đặt timeout 5 giây để không bị đơ app khi WiFi/4G không có internet thực
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(const Duration(seconds: 5));

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _isOfflineSession = false;
        _offlineUid = uid;
        _configureRepositories(uid);

        // Lưu thông tin xác thực an toàn vào FlutterSecureStorage
        await _saveOfflineCredentials(
          email: email,
          password: password,
          uid: uid,
        );

        // Đồng bộ dữ liệu ngầm không chặn luồng đăng nhập
        unawaited(_runBackgroundAuthSync(normalizedEmail, password, uid));
      }

      return (success: true, message: 'Đăng nhập thành công!');
    } on TimeoutException {
      debugPrint('AuthService: Login timed out, falling back to offline login');
      return await loginOffline(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      if (code == 'network-request-failed' ||
          code == 'unavailable' ||
          code == 'timeout' ||
          code == 'too-many-requests' ||
          code == 'unknown') {
        return await loginOffline(email: email, password: password);
      }
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('network') ||
          errStr.contains('socket') ||
          errStr.contains('host') ||
          errStr.contains('timeout') ||
          errStr.contains('offline') ||
          errStr.contains('clientexception') ||
          errStr.contains('handshake') ||
          errStr.contains('connection')) {
        return await loginOffline(email: email, password: password);
      }
      return (success: false, message: 'Lỗi không xác định: $e');
    }
  }

  /// Đồng bộ hồ sơ người dùng, thiết bị và xác thực Firebase Auth trong chế độ nền
  Future<void> _runBackgroundAuthSync(String email, String password, String uid) async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(const Duration(seconds: 5));
      }

      final activeUid = _auth.currentUser?.uid ?? uid;

      // 1. Đồng bộ hồ sơ từ Firestore về SQLite
      try {
        final userDoc = await _firestore.collection('users').doc(activeUid).get().timeout(const Duration(seconds: 4));
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          await UserRepository().saveUser(user);
        }
      } catch (_) {}

      // 2. Ghi lại thời điểm đăng nhập bằng mật khẩu
      try {
        await _firestore
            .collection('biometric_prefs')
            .doc(activeUid)
            .set(
              {'lastPasswordLoginAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            ).timeout(const Duration(seconds: 3));
      } catch (_) {}

      // 3. Đăng ký phiên thiết bị hoạt động
      try {
        final deviceInfo = await DeviceUtils.getDeviceInfo();
        await FirestoreService().registerDeviceSession(
          deviceName: deviceInfo['name']!,
          deviceType: deviceInfo['type']!,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('AuthService: _runBackgroundAuthSync error: $e');
    }
  }

  // ==================== DANG XUAT ====================
  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      // XÓA THIẾT BỊ HIỆN TẠI KHỎI LIST HOẠT ĐỘNG KHI ĐĂNG XUẤT
      try {
        final deviceInfo = await DeviceUtils.getDeviceInfo();
        final sessionId = DeviceUtils.getSessionId(user.uid, deviceInfo['name']!);
        await FirestoreService().removeDeviceSession(sessionId);
      } catch (_) {}
    }
    _isOfflineSession = false;
    _offlineUid = null;
    await _secureStorage.delete(key: 'last_auth_password');
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
      
      // CẬP NHẬT THỜI GIAN ĐỔI MK TRÊN FIRESTORE
      await _firestore.collection('users').doc(user.uid).update({
        'lastPasswordUpdate': FieldValue.serverTimestamp(),
      });

      // CẬP NHẬT MẬT KHẨU MỚI VÀO BỘ NHỚ XÁC THỰC OFFLINE
      if (user.email != null) {
        await _saveOfflineCredentials(
          email: user.email!,
          password: newPassword,
          uid: user.uid,
        );
      }

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

  // ==================== SEND PASSWORD RESET EMAIL (QUEN MAT KHAU) ====================
  Future<({bool success, String message})> sendPasswordResetEmail({required String email}) async {
    try {
      // Kiem tra email co hop le khong
      if (email.isEmpty) {
        return (success: false, message: 'Vui long nhap email!');
      }
      if (!email.contains('@') || !email.contains('.')) {
        return (success: false, message: 'Email khong hop le!');
      }

      // Gui email dat lai mat khau
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      return (success: true, message: 'Email dat lai mat khau da duoc gui den $email. Vui long kiem tra hop thu va click vao link.');
    } on FirebaseAuthException catch (e) {
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
      // Neu co OTP, xac thuc OTP truoc (cho luong cu)
      if (otpCode.isNotEmpty) {
        final verifyResult = await verifyOTP(email: email, otpCode: otpCode);
        if (!verifyResult.success) {
          return (success: false, message: verifyResult.message);
        }
      }
      // Neu khong co OTP, chi can gui email reset password (luong moi)

      // Gui email reset password
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      // Luu mat khau moi tam thoi (user se click link trong email de hoan thanh)
      await _firestore.collection('password_resets').doc(email.trim()).set({
        'email': email.trim(),
        'newPassword': newPassword,
        'createdAt': DateTime.now(),
        'expiresAt': DateTime.now().add(const Duration(hours: 1)),
      });

      return (success: true, message: 'Email dat lai mat khau da duoc gui!');
    } on FirebaseAuthException catch (e) {
      return (success: false, message: _getAuthErrorMessage(e.code));
    } catch (e) {
      return (success: false, message: 'Loi: $e');
    }
  }

  // ==================== DOI MAT KHAU KHI DA DANG NHAP ====================
  Future<({bool success, String message})> updateCurrentPassword({
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return (success: false, message: 'Chưa đăng nhập!');
      }
      await user.updatePassword(newPassword);

      // CẬP NHẬT THỜI GIAN ĐỔI MK TRÊN FIRESTORE
      await _firestore.collection('users').doc(user.uid).update({
        'lastPasswordUpdate': FieldValue.serverTimestamp(),
      });

      return (success: true, message: 'Cập nhật mật khẩu thành công!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return (success: false, message: 'Vui lòng xác thực lại mật khẩu hiện tại trước khi đổi.');
      }
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
    Future<void> deleteInChunks(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
      const chunkSize = 450;
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

    final transactions = await _firestore.collection('transactions').where('uid', isEqualTo: uid).get();
    await deleteInChunks(transactions.docs);

    final notifications = await _firestore.collection('notifications').where('uid', isEqualTo: uid).get();
    await deleteInChunks(notifications.docs);

    final messages = await _firestore.collection('messages').where('uid', isEqualTo: uid).get();
    await deleteInChunks(messages.docs);

    final deviceSessions = await _firestore.collection('device_sessions').where('uid', isEqualTo: uid).get();
    await deleteInChunks(deviceSessions.docs);

    // Xóa hồ sơ user
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
    if (user != null && ConnectivityService().isOnline) {
      return _firestore.collection('users').doc(user.uid).snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
    }
    // Fallback sang SQLite offline stream
    return UserRepository().getUserStream();
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
