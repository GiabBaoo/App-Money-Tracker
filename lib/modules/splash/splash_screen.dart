// splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';
import '../auth/fingerprint_unlock_screen.dart';
import '../../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _checkAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacement(
        context,
        PageTransitions.fade(const OnboardingScreen()),
      );
      return;
    }

    final fingerprintEnabled = await BiometricService.instance.isFingerprintEnabledForUser(user.uid);

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
