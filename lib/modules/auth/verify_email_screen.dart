import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    // Tu dong kiem tra email verification moi 3 giay
    _startAutoCheck();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      
      final result = await _authService.reloadAndCheckEmailVerification();
      
      if (result.emailVerified && mounted) {
        _showSnackBar('Email da xac nhan! Dang nhap vao app...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        });
      }
    });
  }

  Future<void> _handleVerifyManually() async {
    setState(() => _isLoading = true);

    final result = await _authService.reloadAndCheckEmailVerification();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.emailVerified) {
      _showSnackBar('Email da xac nhan! Dang nhap vao app...', isError: false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      });
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() => _isLoading = true);

    final result = await _authService.sendEmailVerification();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar('Email xac nhan da duoc gui lai!', isError: false);
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF438883),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () {
                    _authService.logout();
                    Navigator.pop(context);
                  },
                ),
                const Spacer(),
                const Text('mono', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                const Spacer(flex: 2),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.mail_outline, color: Color(0xFF438883), size: 40),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Xac nhan email cua ban',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        'Chung toi da gui email xac nhan toi\n$widget.email',
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui long kiem tra hop thu va click vao link de xac nhan.',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Steps
                      _buildStep(1, 'Mo email ma chung toi vua gui'),
                      _buildStep(2, 'Click link xac nhan trong email'),
                      _buildStep(3, 'Quay tro lai ung dung'),
                      const SizedBox(height: 40),

                      // Manual Check Button
                      InkWell(
                        onTap: _isLoading ? null : _handleVerifyManually,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading ? [Colors.grey, Colors.grey.shade600] : [const Color(0xFF68AEA9), const Color(0xFF3E8681)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text(
                                    'Da xac nhan email',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Resend Email Button
                      InkWell(
                        onTap: _isLoading ? null : _handleResendEmail,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF438883), width: 1.5),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: Text(
                              'Gui lai email xac nhan',
                              style: TextStyle(color: const Color(0xFF438883), fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout Link
                      InkWell(
                        onTap: () {
                          _authService.logout();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          'Quay lai Dang nhap',
                          style: TextStyle(color: Color(0xFF438883), fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF438883),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
