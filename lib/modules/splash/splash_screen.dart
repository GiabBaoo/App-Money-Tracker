// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../auth/fingerprint_unlock_screen.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _checkAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (user == null) {
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
        print('DEBUG: Found pendingGroupId after login: $pendingGroupId');
        // Xóa pendingGroupId
        await prefs.remove('pendingGroupId');
        
        // Chuyển đến JoinGroupScreen
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

      // Skip biometric check on web to avoid errors
      final fingerprintEnabled = false; // Temporarily disabled
      // final fingerprintEnabled = await BiometricService.instance.isFingerprintEnabledForUser(user.uid);

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
      print('Navigation error: $e');
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
    Timer(Duration(seconds: 2), () {
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
