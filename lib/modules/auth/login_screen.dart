import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/app_logo.dart';
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
          PageTransitions.fade(JoinGroupScreen(groupId: pendingGroupId)),
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
    final primaryColor = const Color(0xFF438883);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF091716) : const Color(0xFFF4F7F6),
      body: Stack(
        children: [
          // Nền Gradient & Hiệu ứng quầng sáng Aura mềm mại
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2DD4BF).withValues(alpha: isDark ? 0.2 : 0.15),
                    const Color(0xFF2DD4BF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // 1. BRAND HERO: Biểu tượng & Logo FinTech mono
                    const AppLogo.badge(
                      size: 74,
                      borderRadius: BorderRadius.all(Radius.circular(37)),
                    ),
                    const SizedBox(height: 14),
                    AppLogo.wordmark(
                      height: 32,
                      color: isDark ? Colors.white : const Color(0xFF0F2625),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quản lý tài chính cá nhân thông minh',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 2. THẺ ĐĂNG NHẬP SQUIRCLE FINTECH (FROSTED GLASS CARD)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132220) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đăng Nhập',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chào mừng bạn trở lại với Mono',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Trường Email
                          Text(
                            'Email',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1B2E2C) : const Color(0xFFF8FAFC),
                              hintText: 'Nhập email của bạn',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Trường Mật khẩu
                          Text(
                            'Mật khẩu',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1B2E2C) : const Color(0xFFF8FAFC),
                              hintText: 'Nhập mật khẩu của bạn',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Ghi nhớ & Quên mật khẩu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ghi nhớ đăng nhập',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(context, PageTransitions.slideRight(const ForgotPasswordScreen()));
                                },
                                child: Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          // NÚT CHÍNH: ĐĂNG NHẬP
                          AnimatedScaleButton(
                            onTap: _isLoading
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    _handleLogin();
                                  },
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isLoading
                                      ? [Colors.grey, Colors.grey.shade600]
                                      : [const Color(0xFF438883), const Color(0xFF2DD4BF)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Đăng Nhập',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          // NÚT PHỤ: ĐĂNG NHẬP BẰNG SINH TRẮC HỌC VÂN TAY
                          if (_canUseBiometric) ...[
                            const SizedBox(height: 14),
                            AnimatedScaleButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _handleBiometricLogin();
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.35),
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fingerprint_rounded,
                                      size: 24,
                                      color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Đăng nhập nhanh bằng vân tay',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3. ĐIỀU HƯỚNG SANG ĐĂNG KÝ
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, PageTransitions.slideRight(const RegisterScreen()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Chưa có tài khoản? ',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  fontSize: 14.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Đăng ký ngay',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
