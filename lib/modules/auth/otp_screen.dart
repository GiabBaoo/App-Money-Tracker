import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'reset_password_screen.dart';

class OTPScreen extends StatefulWidget {
  final String email;
  final bool isFromForgotPass;

  const OTPScreen({
    super.key,
    required this.email,
    this.isFromForgotPass = false,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final AuthService _authService = AuthService();
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _countdown = 59;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 59;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  // Che email: rexmcg1234@gmail.com -> rexm******@gmail.com
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 4) {
      // Email ngan: chi hien 1 ky tu dau + ***
      return '${name[0]}${'*' * (name.length - 1)}@$domain';
    }
    // Email dai: hien 4 ky tu dau + ***
    return '${name.substring(0, 4)}${'*' * (name.length - 4)}@$domain';
  }

  Future<void> _handleVerify() async {
    final code = _otpCode;
    if (code.length != 6) {
      _showSnackBar('Vui long nhap du 6 so!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.verifyOTP(email: widget.email, otpCode: code);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      if (widget.isFromForgotPass) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(isFromSecurity: false, emailForReset: widget.email, otpCode: code),
        ));
      } else {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
      }
    } else {
      _showSnackBar(result.message, isError: true);
      for (var c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _handleResend() async {
    if (_countdown > 0) return;

    setState(() => _isLoading = true);
    final otpResult = await _authService.sendOTP(email: widget.email);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (otpResult.success) {
      _showSnackBar('Ma OTP moi da duoc gui den email cua ban');
      _startCountdown();
      for (var c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
    } else {
      _showSnackBar(otpResult.message, isError: true);
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            color: const Color(0xFF5E9387),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 10),
                Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('mono', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -2))),
                  const SizedBox(width: 48),
                ]),
              ]),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 100, bottom: 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 35, offset: const Offset(0, 22))]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Ma xac thuc OTP', style: TextStyle(color: Color(0xFF5E9387), fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // HIEN THI EMAIL DA CHE
                      Text(
                        'Ma xac thuc da gui ve $_maskedEmail',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // 6 O NHAP OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) => _buildOTPBox(index)),
                      ),
                      const SizedBox(height: 30),

                      const Text('Ban chua nhan duoc ma?', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (_countdown > 0) Text('Gui lai ma sau 00:${_countdown.toString().padLeft(2, '0')} | ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        GestureDetector(
                          onTap: _countdown == 0 ? _handleResend : null,
                          child: Text('Gui lai ma', style: TextStyle(color: _countdown == 0 ? const Color(0xFF5E9387) : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 30),

                      // NUT XAC NHAN
                      InkWell(
                        onTap: _isLoading ? null : _handleVerify,
                        child: Container(
                          width: double.infinity, height: 55,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: _isLoading ? [Colors.grey, Colors.grey.shade600] : [const Color(0xFF68AEA9), const Color(0xFF3E8681)]), borderRadius: BorderRadius.circular(30)),
                          child: Center(child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Xac Nhan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    return SizedBox(
      height: 50, width: 42,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_otpCode.length == 6) _handleVerify();
        },
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '', contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5E9387), width: 2)),
        ),
      ),
    );
  }
}
