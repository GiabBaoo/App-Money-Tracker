import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';
import '../services/midnight_sync_service.dart';
import '../services/auth_service.dart';
import '../modules/auth/fingerprint_unlock_screen.dart';
import '../utils/page_transitions.dart';

class LifecycleManager extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const LifecycleManager({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<LifecycleManager> createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager> with WidgetsBindingObserver {
  bool _wasInBackground = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Tự động mở khóa cờ _isLocked khi người dùng đăng xuất
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && _isLocked && mounted) {
        setState(() {
          _isLocked = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Chỉ ghi nhận vào background nếu app KHÔNG phải đang hiển thị hộp thoại quét vân tay của hệ thống
      // VÀ KHÔNG PHẢI đang mở camera/thư viện ảnh hệ thống bên ngoài
      if (!BiometricService.instance.isAuthenticating &&
          !BiometricService.instance.isPickerActive &&
          !_isLocked) {
        _wasInBackground = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Tự động kiểm tra và bù trừ sao lưu nửa đêm nếu người dùng vừa mở lại ứng dụng
      MidnightSyncService.instance.checkAndRunCatchUpSync();

      if (_wasInBackground &&
          !_isLocked &&
          !BiometricService.instance.isAuthenticating &&
          !BiometricService.instance.isPickerActive) {
        _wasInBackground = false;
        _checkLockStatus();
      } else {
        _wasInBackground = false;
      }
    }
  }

  Future<void> _checkLockStatus() async {
    if (_isLocked || BiometricService.instance.isAuthenticating) return;

    final effectiveUid = AuthService().currentUid;
    if (effectiveUid != null) {
      final enabled = await BiometricService.instance.isFingerprintEnabledForUser(effectiveUid);
      if (enabled && !_isLocked && mounted) {
        _lockApp();
      }
    }
  }

  void _lockApp() {
    if (_isLocked) return;
    setState(() {
      _isLocked = true;
    });

    // Sử dụng navigatorKey để truy cập Navigator từ bất kỳ đâu
    final nav = widget.navigatorKey.currentState;
    if (nav == null) {
      if (mounted) {
        setState(() => _isLocked = false);
      }
      return;
    }
    
    nav.push(
      PageTransitions.fade(
        FingerprintUnlockScreen(
          onUnlock: () {
            if (mounted) {
              setState(() {
                _isLocked = false;
              });
            }
            nav.pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
