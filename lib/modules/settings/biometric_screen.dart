import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/biometric_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_toast.dart';
import '../../services/language_service.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _isFingerprintEnabled = false;
  bool _isSaving = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadCurrentPreference();
  }

  Future<void> _loadCurrentPreference() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final enabled = await BiometricService.instance.isFingerprintEnabledForUser(uid);
      if (!mounted) return;
      setState(() {
        _isFingerprintEnabled = enabled;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<bool> _persistPreference(bool enabled) async {
    HapticFeedback.selectionClick();
    final isVi = LanguageScope.of(context).isVietnamese;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return false;
      _showSnackbar(isVi ? 'Bạn cần đăng nhập để lưu cài đặt vân tay.' : 'Please log in to save biometric settings.', isError: true);
      return false;
    }

    if (enabled) {
      final status = await BiometricService.instance.getBiometricSupportStatus();
      if (status != BiometricSupportStatus.supported) {
        if (!mounted) return false;
        final message = status == BiometricSupportStatus.notEnrolled
            ? (isVi ? 'Thiết bị có hỗ trợ nhưng chưa đăng ký vân tay/FaceID. Hãy cài đặt trong Cài đặt hệ thống.' : 'Device supports biometrics but none enrolled. Please set up in system settings.')
            : (isVi ? 'Thiết bị này không hỗ trợ xác thực sinh trắc học.' : 'This device does not support biometric authentication.');
        _showSnackbar(message, isError: true);
        return false;
      }

      // Xác thực sinh trắc học thực tế trước khi kích hoạt
      final authenticated = await BiometricService.instance.authenticateFingerprint(
        localizedReason: isVi ? 'Xác nhận danh tính để kích hoạt đăng nhập sinh trắc học' : 'Confirm your identity to activate biometric login',
      );
      if (!authenticated) {
        if (!mounted) return false;
        _showSnackbar(isVi ? 'Xác thực thất bại. Chưa thể bật tính năng.' : 'Authentication failed. Feature cannot be enabled.', isError: true);
        return false;
      }
    }

    try {
      await BiometricService.instance.setFingerprintEnabledForUser(
        uid: uid,
        enabled: enabled,
      );
      if (!mounted) return false;
      _showSnackbar(
        enabled
            ? (isVi ? 'Đã kích hoạt đăng nhập sinh trắc học thành công!' : 'Biometric login enabled successfully!')
            : (isVi ? 'Đã tắt đăng nhập bằng sinh trắc học.' : 'Biometric login disabled.'),
        isError: false,
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      _showSnackbar(isVi ? 'Không thể lưu cài đặt sinh trắc học.' : 'Failed to save biometric settings.', isError: true);
      return false;
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    MonoToast.show(
      context,
      message,
      type: isError ? MonoToastType.error : MonoToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E2827) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOP APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  Text(
                    isVi ? 'Đăng nhập sinh trắc học' : 'Biometric Login',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. MAIN SHEET
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    children: [
                      // HERO AURA GLOW BIOMETRIC BADGE
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing Outer Halo
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isFingerprintEnabled ? const Color(0xFF10B981) : const Color(0xFF438883))
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isFingerprintEnabled ? const Color(0xFF10B981) : const Color(0xFF438883))
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _isFingerprintEnabled
                                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                      : [const Color(0xFF438883), const Color(0xFF2F6360)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isFingerprintEnabled ? const Color(0xFF10B981) : const Color(0xFF438883))
                                        .withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.fingerprint_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Status Header
                      Text(
                        _isFingerprintEnabled
                            ? (isVi ? 'Đang bảo vệ an toàn' : 'Secured & Active')
                            : (isVi ? 'Chưa bật sinh trắc học' : 'Biometrics Disabled'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _isFingerprintEnabled
                              ? (isVi
                                  ? 'Bạn có thể mở khóa sổ tay tài chính Mono ngay tức thì bằng vân tay hoặc FaceID.'
                                  : 'You can instantly unlock your Mono financial notebook using fingerprint or Face ID.')
                              : (isVi
                                  ? 'Kích hoạt để đăng nhập nhanh mà không cần nhập lại mật khẩu mỗi lần mở ứng dụng.'
                                  : 'Enable for quick login without re-entering your password every time you open the app.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // TOGGLE CARD
                      Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF438883).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: Color(0xFF438883),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVi ? 'Vân tay & Nhận diện khuôn mặt' : 'Fingerprint & Face Recognition',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isSaving
                                          ? (isVi ? 'Đang cập nhật...' : 'Updating...')
                                          : (_isFingerprintEnabled
                                              ? (isVi ? 'Đang hoạt động' : 'Active')
                                              : (isVi ? 'Đã vô hiệu hóa' : 'Disabled')),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _isFingerprintEnabled ? const Color(0xFF10B981) : Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isSaving)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF438883)),
                                )
                              else
                                Switch.adaptive(
                                  value: _isFingerprintEnabled,
                                  activeTrackColor: const Color(0xFF438883),
                                  onChanged: (val) async {
                                    setState(() => _isSaving = true);
                                    try {
                                      final ok = await _persistPreference(val);
                                      if (!mounted) return;
                                      if (ok) {
                                        setState(() => _isFingerprintEnabled = val);
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSaving = false);
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // PRIVACY & SECURITY HIGHLIGHTS CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF162524) : const Color(0xFFF1F8F6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark ? const Color(0xFF254B48) : const Color(0xFF438883).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, color: Color(0xFF438883), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isVi ? 'Cam kết bảo mật FinTech' : 'FinTech Security Guarantee',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF133633),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildInfoBullet(
                              icon: Icons.lock_outline_rounded,
                              title: isVi ? 'Xử lý qua Secure Enclave' : 'Processed via Secure Enclave',
                              desc: isVi
                                  ? 'Dữ liệu vân tay được lưu trữ an toàn trong chip bảo mật riêng của thiết bị và không bao giờ tải lên máy chủ.'
                                  : 'Biometric data is securely stored on your device\'s dedicated security chip and never uploaded to servers.',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoBullet(
                              icon: Icons.speed_rounded,
                              title: isVi ? 'Truy cập tức thì không gián đoạn' : 'Instant & Seamless Access',
                              desc: isVi
                                  ? 'Mở ứng dụng chỉ mất 0.2 giây mà vẫn đảm bảo riêng tư số dư cá nhân khi ở nơi công cộng.'
                                  : 'Open the app in just 0.2 seconds while keeping your balances private in public spaces.',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoBullet(
                              icon: Icons.security_rounded,
                              title: isVi ? 'Tự động khóa khi ẩn ứng dụng' : 'Auto-lock in background',
                              desc: isVi
                                  ? 'Ngay khi bạn chuyển app sang màn hình khác, Mono sẽ tự động kích hoạt lại lớp khóa bảo vệ.'
                                  : 'As soon as you switch apps or minimize Mono, the security lock is automatically re-engaged.',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBullet({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF438883).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF438883)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
