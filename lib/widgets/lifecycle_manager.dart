import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';
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
  DateTime? _backgroundTimestamp;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockStatus();
    }
  }

  Future<void> _checkLockStatus() async {
    if (_backgroundTimestamp == null || _isLocked) return;

    final now = DateTime.now();
    final difference = now.difference(_backgroundTimestamp!).inSeconds;

    // Reset background timestamp after check
    final savedTimestamp = _backgroundTimestamp;
    _backgroundTimestamp = null;

    if (difference >= 15) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final enabled = await BiometricService.instance.isFingerprintEnabledForUser(user.uid);
        if (enabled) {
          _lockApp();
        }
      }
    }
  }

  void _lockApp() {
    setState(() {
      _isLocked = true;
    });

    // Sử dụng navigatorKey để truy cập Navigator từ bất kỳ đâu
    final nav = widget.navigatorKey.currentState;
    if (nav == null) {
      setState(() => _isLocked = false);
      return;
    }
    
    nav.push(
      PageTransitions.fade(
        FingerprintUnlockScreen(
          onUnlock: () {
            setState(() {
              _isLocked = false;
            });
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
