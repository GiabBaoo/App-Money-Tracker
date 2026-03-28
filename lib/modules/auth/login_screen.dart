import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

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
      
      // Kiem tra xem email co da xac nhan khong
      final currentUser = _authService.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        _showSnackBar('Vui long xac nhan email truoc khi dang nhap!', isError: true);
        await _authService.logout();
        return;
      }
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            color: const Color(0xFF5E9387),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 35, offset: const Offset(0, 22))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: Text('Đăng Nhập', style: TextStyle(color: Color(0xFF549B96), fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
                        const SizedBox(height: 30),
                        const Text('Email', style: TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Nhập email của bạn', hintStyle: TextStyle(color: Colors.black.withOpacity(0.29), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Mật khẩu', style: TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            hintText: 'Nhập mật khẩu của bạn', hintStyle: TextStyle(color: Colors.black.withOpacity(0.29), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                            suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            SizedBox(width: 24, height: 24, child: Checkbox(value: _rememberMe, activeColor: const Color(0xFF438883), onChanged: (v) => setState(() => _rememberMe = v ?? false))),
                            const SizedBox(width: 8),
                            const Text('Ghi nhớ mật khẩu', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                          ]),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
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
                              boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('Đăng Nhập', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: const Text.rich(TextSpan(children: [
                      TextSpan(text: 'Chưa có tài khoản? ', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
                      TextSpan(text: 'Đăng ký ngay', style: TextStyle(color: Color(0xFF4E8F8A), fontWeight: FontWeight.bold, fontSize: 14)),
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
