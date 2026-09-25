// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../auth/fingerprint_unlock_screen.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';
import '../../services/biometric_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _checkAndNavigate() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? effectiveUid = user?.uid;

      if (effectiveUid != null) {
        AuthService().setOnlineUid(effectiveUid);
      } else {
        // Nếu không có kết nối hoặc Firebase Auth chưa có token, kiểm tra offline session
        String? lastUid;
        try {
          lastUid = await const FlutterSecureStorage().read(key: 'last_offline_uid');
        } catch (e) {
          debugPrint('SplashScreen: Error reading secure storage: $e');
        }
        if (lastUid != null && lastUid.isNotEmpty) {
          effectiveUid = lastUid;
          if (ConnectivityService().isOnline) {
            AuthService().setOnlineUid(lastUid);
          } else {
            AuthService().setOfflineUid(lastUid);
          }
        }
      }

      if (!mounted) return;

      if (effectiveUid == null) {
        Navigator.pushReplacement(
          context,
          PageTransitions.fade(const OnboardingScreen()),
        );
        return;
      }

      // Kiểm tra xem có pendingGroupId không (sau khi login)
      final prefs = await SharedPreferences.getInstance();
      final pendingGroupId = prefs.getString('pendingGroupId');
      if (pendingGroupId != null && pendingGroupId.isNotEmpty) {
        await prefs.remove('pendingGroupId');
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => JoinGroupScreen(groupId: pendingGroupId),
            ),
          );
          return;
        }
      }

      bool fingerprintEnabled = false;
      if (!kIsWeb) {
        try {
          fingerprintEnabled = await BiometricService.instance.isFingerprintEnabledForUser(effectiveUid);
        } catch (_) {}
      }

      if (!mounted) return;

      if (fingerprintEnabled) {
        Navigator.pushReplacement(
          context,
          PageTransitions.fade(
            FingerprintUnlockScreen(
              destination: const HomeScreen(),
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageTransitions.fade(const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback to onboarding if error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageTransitions.fade(const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Điều hướng ngay sau khi frame đầu tiên render xong (<300ms)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF5E9387),
      body: Center(child: Image.asset('assets/images/logo.png', width: 150)),
    );
  }
}
