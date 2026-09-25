import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricSupportStatus {
  supported,
  notSupported,
  notEnrolled,
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _secureUidKey = 'biometric_uid';
  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  bool _isPickerActive = false;
  DateTime? _pickerGraceUntil;

  /// Cho biết liệu ứng dụng có đang mở Camera / Gallery / Picker hệ thống bên ngoài không.
  /// Nếu đang mở hoặc đang trong khoảng đệm 1.5s sau khi quay lại app, cờ này trả về true để ngăn màn hình khóa vân tay.
  bool get isPickerActive {
    if (_isPickerActive) return true;
    if (_pickerGraceUntil != null) {
      if (DateTime.now().isBefore(_pickerGraceUntil!)) {
        return true;
      } else {
        _pickerGraceUntil = null;
      }
    }
    return false;
  }

  void setPickerActive(bool active) {
    _isPickerActive = active;
    if (!active) {
      _pickerGraceUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    } else {
      _pickerGraceUntil = null;
    }
  }

  /// Bọc các thao tác gọi picker ngoài (Camera, Gallery, File picker).
  /// Trong suốt quá trình picker hoạt động và 1.5 giây sau khi trở lại Flutter,
  /// cờ isPickerActive sẽ được kích hoạt để ngăn chặn LifecycleManager khóa ứng dụng.
  Future<T> runWithPickerSuspended<T>(Future<T> Function() action) async {
    setPickerActive(true);
    try {
      return await action();
    } finally {
      // Đặt bộ đệm trễ để đảm bảo sự kiện AppLifecycleState.resumed được tiêu thụ an toàn
      setPickerActive(false);
    }
  }

  Future<BiometricSupportStatus> getBiometricSupportStatus() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) {
        return BiometricSupportStatus.notSupported;
      }

      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        return BiometricSupportStatus.notEnrolled;
      }

      return BiometricSupportStatus.supported;
    } catch (_) {
      return BiometricSupportStatus.notSupported;
    }
  }

  Future<bool> canCheckBiometrics() async {
    final status = await getBiometricSupportStatus();
    return status == BiometricSupportStatus.supported;
  }

  Future<bool> authenticateFingerprint({
    String localizedReason = 'Xác thực vân tay để tiếp tục',
  }) async {
    _isAuthenticating = true;
    try {
      final result = await _localAuth.authenticate(
        localizedReason: localizedReason,
        // Chỉ cho phép sinh trắc học (không fallback sang PIN/mật khẩu).
        biometricOnly: true,
        // Khi app bị background, plugin sẽ tự retry thay vì thất bại.
        persistAcrossBackgrounding: true,
      );
      return result;
    } catch (_) {
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<bool> isFingerprintEnabledForUser(String uid) async {
    // 1. Đọc từ local secure storage trước để phản hồi tức thì (< 5ms)
    try {
      final cached = await _secureStorage.read(key: 'fingerprint_enabled_$uid');
      if (cached != null) {
        return cached == 'true';
      }
    } catch (_) {}

    // 2. Nếu chưa có trong local cache, thử đọc từ Firestore với timeout 1.5 giây (không đơ app khi offline)
    try {
      final doc = await _firestore
          .collection('biometric_prefs')
          .doc(uid)
          .get()
          .timeout(const Duration(milliseconds: 1500));
      final data = doc.data();
      final enabled = (data?['fingerprintEnabled'] ?? false) == true;
      await _secureStorage.write(
        key: 'fingerprint_enabled_$uid',
        value: enabled ? 'true' : 'false',
      );
      return enabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> setFingerprintEnabledForUser({
    required String uid,
    required bool enabled,
  }) async {
    // 1. Lưu local cache ngay tức khắc
    try {
      await _secureStorage.write(
        key: 'fingerprint_enabled_$uid',
        value: enabled ? 'true' : 'false',
      );
      if (enabled) {
        await _secureStorage.write(key: _secureUidKey, value: uid);
      } else {
        await _secureStorage.delete(key: _secureUidKey);
      }
    } catch (_) {}

    // 2. Đồng bộ Firestore
    try {
      await _firestore
          .collection('biometric_prefs')
          .doc(uid)
          .set(
        {
          'fingerprintEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> clearCachedBiometricUid() async {
    await _secureStorage.delete(key: _secureUidKey);
  }

  Future<void> recordFingerprintLogin({
    required String uid,
  }) async {
    try {
      await _firestore
          .collection('biometric_prefs')
          .doc(uid)
          .set(
        {'lastFingerprintLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

