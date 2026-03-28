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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _secureUidKey = 'biometric_uid';

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

  Future<bool> authenticateFingerprint() async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: 'Xác thực vân tay để đăng nhập',
        // Chỉ cho phép sinh trắc học (không fallback sang PIN/mật khẩu).
        biometricOnly: true,
        // Khi app bị background, plugin sẽ tự retry thay vì thất bại.
        persistAcrossBackgrounding: true,
      );
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFingerprintEnabledForUser(String uid) async {
    final doc =
        await _firestore.collection('biometric_prefs').doc(uid).get();
    final data = doc.data();
    return (data?['fingerprintEnabled'] ?? false) == true;
  }

  Future<void> setFingerprintEnabledForUser({
    required String uid,
    required bool enabled,
  }) async {
    await _firestore
        .collection('biometric_prefs')
        .doc(uid)
        .set(
      {
        'fingerprintEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (enabled) {
      await _secureStorage.write(key: _secureUidKey, value: uid);
    }
  }

  Future<void> clearCachedBiometricUid() async {
    await _secureStorage.delete(key: _secureUidKey);
  }

  Future<void> recordFingerprintLogin({
    required String uid,
  }) async {
    await _firestore
        .collection('biometric_prefs')
        .doc(uid)
        .set(
      {'lastFingerprintLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}

