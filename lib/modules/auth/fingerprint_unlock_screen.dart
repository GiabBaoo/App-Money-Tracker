import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/biometric_service.dart';
import 'login_screen.dart';

class FingerprintUnlockScreen extends StatefulWidget {
  final Widget? destination;
  final VoidCallback? onUnlock;

  const FingerprintUnlockScreen({
    super.key,
    this.destination,
    this.onUnlock,
  });

  @override
  State<FingerprintUnlockScreen> createState() =>
      _FingerprintUnlockScreenState();
}

class _FingerprintUnlockScreenState extends State<FingerprintUnlockScreen> {
  String? _error;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _error = null);

    final supported = await BiometricService.instance.canCheckBiometrics();
    if (!mounted) return;

    if (!supported) {
      // Nếu thiết bị không hỗ trợ, bỏ qua bước vân tay để không "kẹt" app.
      _goNext();
      return;
    }

    final ok = await BiometricService.instance.authenticateFingerprint();
    if (!mounted) return;

    if (ok) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await BiometricService.instance.recordFingerprintLogin(uid: uid);
      }
      _goNext();
    } else {
      setState(() {
        _isAuthenticating = false;
        _error = 'Không thể xác thực vân tay. Vui lòng thử lại.';
      });
    }
  }

  void _goNext() {
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    
    if (widget.onUnlock != null) {
      widget.onUnlock!();
      return;
    }

    if (widget.destination != null) {
      Navigator.pushReplacement(
        context,
        PageTransitions.fade(widget.destination!),
      );
    }
  }

  Future<void> _logoutToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageTransitions.fade(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Ngăn người dùng nhấn nút Back để thoát màn hình xác thực
      child: Scaffold(
        backgroundColor: const Color(0xFF438883),
        body: SafeArea(
          bottom: false,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: _logoutToLogin,
                  ),
                  const Text(
                    'Đăng nhập bằng vân tay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 3),
                      ),
                      child: const Icon(Icons.fingerprint, color: Colors.white, size: 50),
                    ),
                    const SizedBox(height: 24),
                    if (_isAuthenticating)
                      const CircularProgressIndicator(color: Colors.white)
                    else ...[
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.75,
                        child: ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F7E79),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Thử lại',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.75,
                        child: OutlinedButton(
                          onPressed: _logoutToLogin,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Dùng mật khẩu',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

