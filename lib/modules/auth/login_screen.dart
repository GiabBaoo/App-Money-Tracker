import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../features/group_expense/presentation/screens/join_group_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _canUseBiometric = false;
  String? _lastOfflineUid;

  @override
  void initState() {
    super.initState();
    _checkSavedLoginAndBiometric();
  }

  Future<void> _checkSavedLoginAndBiometric() async {
    try {
      const secureStorage = FlutterSecureStorage();
      // Đọc song song SharedPreferences và SecureStorage để nạp siêu tốc (< 50ms)
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        secureStorage.read(key: 'saved_login_password'),
        secureStorage.read(key: 'last_offline_email'),
        secureStorage.read(key: 'last_offline_uid'),
        BiometricService.instance.canCheckBiometrics(),
      ]);

      final prefs = results[0] as SharedPreferences;
      final savedPassword = results[1] as String?;
      final lastEmail = results[2] as String?;
      final lastUid = results[3] as String?;
      final canBio = results[4] as bool;

      final savedEmail = prefs.getString('saved_login_email');
      final remember = prefs.getBool('saved_remember_me') ?? false;

      if (remember && savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
        if (savedPassword != null && savedPassword.isNotEmpty) {
          _passwordController.text = savedPassword;
        }
        if (mounted) setState(() => _rememberMe = true);
      } else if (lastEmail != null && lastEmail.isNotEmpty) {
        _emailController.text = lastEmail;
      }

      if (lastUid != null && lastUid.isNotEmpty) {
        final isBioEnabled = await BiometricService.instance.isFingerprintEnabledForUser(lastUid);
        if (mounted) {
          setState(() {
            _lastOfflineUid = lastUid;
            _canUseBiometric = isBioEnabled && canBio;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handleBiometricLogin() async {
    if (_lastOfflineUid == null) return;
    final authenticated = await BiometricService.instance.authenticateFingerprint(
      localizedReason: 'Quét vân tay để đăng nhập vào Mono',
    );
    if (authenticated && mounted) {
      _authService.setOfflineUid(_lastOfflineUid!);
      // Tự động re-authenticate Firebase Auth ngầm và ghi nhận vân tay (không await)
      unawaited(_authService.silentReauthenticateIfNeeded().catchError((_) => false));
      unawaited(BiometricService.instance.recordFingerprintLogin(uid: _lastOfflineUid!).catchError((_) {}));
      _showSnackBar('Đăng nhập bằng vân tay thành công!');
      Navigator.pushReplacement(
        context,
        PageTransitions.fade(const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ email và mật khẩu!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.login(email: email, password: password);
    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      const secureStorage = FlutterSecureStorage();
      if (_rememberMe) {
        await prefs.setString('saved_login_email', email);
        await prefs.setBool('saved_remember_me', true);
        await secureStorage.write(key: 'saved_login_password', value: password);
      } else {
        await prefs.remove('saved_login_email');
        await prefs.setBool('saved_remember_me', false);
        await secureStorage.delete(key: 'saved_login_password');
      }
      
      // Kiểm tra xác nhận email nếu đang có mạng trực tuyến (bỏ qua khi offline)
      final isOffline = _authService.isOfflineSession;
      final currentUser = _authService.currentUser;
      if (!isOffline && currentUser != null && currentUser.email != null && !currentUser.emailVerified) {
        _showSnackBar('Vui lòng xác nhận email trước khi đăng nhập!', isError: true);
        await _authService.logout();
        return;
      }
      
      // Kiểm tra xem có pendingGroupId không (sau khi login từ invite link)
      final pendingGroupId = prefs.getString('pendingGroupId');
      if (pendingGroupId != null && pendingGroupId.isNotEmpty) {
        await prefs.remove('pendingGroupId');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => JoinGroupScreen(groupId: pendingGroupId),
          ),
        );
        return;
      }

      if (isOffline) {
        _showSnackBar('Đang vào chế độ Ngoại tuyến. Dữ liệu sẽ tự động đồng bộ khi có mạng.');
      }
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageTransitions.fade(const HomeScreen()),
      );
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF438883),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            color: isDark ? const Color(0xFF163836) : const Color(0xFF5E9387),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('mono', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 50, fontFamily: 'Inter', fontWeight: FontWeight.w700, letterSpacing: -2)),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 140, bottom: 20),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
                      borderRadius: BorderRadius.circular(20), 
                      border: isDark ? Border.all(color: Colors.white12) : null,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.08), 
                          blurRadius: 35, 
                          offset: const Offset(0, 22)
                        )
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text('Đăng Nhập', style: TextStyle(color: isDark ? const Color(0xFF68AEA9) : const Color(0xFF549B96), fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                        const SizedBox(height: 30),
                        Text('Email', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
                            hintText: 'Nhập email của bạn', 
                            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.29), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFDDDDDD))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Mật khẩu', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
                            hintText: 'Nhập mật khẩu của bạn', 
                            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.29), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFDDDDDD))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                            suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            SizedBox(width: 24, height: 24, child: Checkbox(value: _rememberMe, activeColor: const Color(0xFF438883), onChanged: (v) => setState(() => _rememberMe = v ?? false))),
                            const SizedBox(width: 8),
                            Text('Ghi nhớ mật khẩu', style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF666666), fontSize: 13)),
                          ]),
                          GestureDetector(
                            onTap: () => Navigator.push(context, PageTransitions.slideRight(const ForgotPasswordScreen())),
                            child: const Text('Quên mật khẩu?', style: TextStyle(color: Color(0xFF438883), fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                        const SizedBox(height: 30),
                        // NÚT ĐĂNG NHẬP CÓ LOADING
                        InkWell(
                          onTap: _isLoading ? null : _handleLogin,
                          child: Container(
                            width: double.infinity, height: 55,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _isLoading ? [Colors.grey, Colors.grey.shade600] : [const Color(0xFF68AEA9), const Color(0xFF3E8681)]),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Đăng Nhập', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        if (_canUseBiometric) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _handleBiometricLogin,
                            icon: const Icon(Icons.fingerprint_rounded, size: 24, color: Color(0xFF438883)),
                            label: const Text(
                              'Đăng nhập nhanh bằng vân tay',
                              style: TextStyle(
                                color: Color(0xFF438883),
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: isDark ? const Color(0xFF242E2D) : Colors.transparent,
                              side: const BorderSide(color: Color(0xFF438883), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () => Navigator.push(context, PageTransitions.slideRight(const RegisterScreen())),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Chưa có tài khoản? ', style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF666666), fontSize: 14)),
                      TextSpan(text: 'Đăng ký ngay', style: TextStyle(color: isDark ? const Color(0xFF68AEA9) : const Color(0xFF4E8F8A), fontWeight: FontWeight.bold, fontSize: 14)),
                    ])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
