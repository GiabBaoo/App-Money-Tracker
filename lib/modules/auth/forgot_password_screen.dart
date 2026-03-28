import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'forgot_password_confirmation_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendPasswordReset() async {
    final email = _emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      _showSnackBar('Vui long nhap email!', isError: true);
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showSnackBar('Email khong hop le!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Goi API Firebase de gui email reset password
    final result = await _authService.sendPasswordResetEmail(email: email);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      _showSnackBar(result.message, isError: false);
      // Chuyen sang trang xac nhan
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ForgotPasswordConfirmationScreen(email: email),
            ),
          );
        }
      });
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
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quen mat khau',
                        style: TextStyle(color: Color(0xFF549B96), fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui long nhap email cua ban. Chung toi se gui link dat lai mat khau.',
                        style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 40),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('Email', style: TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(fontSize: 15),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Nhap email cua ban',
                          hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
                          ),
                          suffixIcon: const Icon(Icons.mail_outline, color: Color(0xFFAAAAAA)),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Center(
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Quay lai Dang nhap',
                            style: TextStyle(color: Color(0xFF438883), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: _isLoading ? null : _handleSendPasswordReset,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey, Colors.grey.shade600]
                                  : const [Color(0xFF68AEA9), Color(0xFF3E8681)],
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3E8681).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Gui email dat lai mat khau',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
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
}

