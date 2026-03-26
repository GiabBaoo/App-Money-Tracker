import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../settings/success_screen.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final bool isFromSecurity;
  final String? emailForReset; // Email tu luong Quen MK (da xac thuc OTP)
  final String? otpCode; // Ma OTP da xac thuc

  const ResetPasswordScreen({
    super.key,
    this.isFromSecurity = false,
    this.emailForReset,
    this.otpCode,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthService _authService = AuthService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Vui long nhap day du mat khau!', isError: true);
      return;
    }
    if (newPassword.length < 8) {
      _showSnackBar('Mat khau phai co it nhat 8 ky tu!', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Mat khau nhap lai khong khop!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isFromSecurity) {
      // LUONG DOI MK TU CAI DAT: Khong can lam gi them (mat khau cu da xac thuc o trang truoc)
      // Chi can goi Firebase de doi mat khau
      // Nhung vi luong nay khong co mat khau cu o day, nen dung sendPasswordResetEmail
      await _authService.resetPasswordWithEmail(
        email: _authService.currentUser?.email ?? '',
        newPassword: newPassword,
        otpCode: widget.otpCode ?? '',
      );
      setState(() => _isLoading = false);

      if (!mounted) return;
      // Hien trang thanh cong
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            appBarTitle: 'Doi mat khau',
            successTitle: 'Thanh cong!',
            successMessage: 'Mat khau cua ban da duoc cap nhat an toan.',
            buttonText: 'Quay lai Bao mat',
            onButtonPressed: () {
              int count = 0;
              Navigator.popUntil(context, (route) => count++ == 3);
            },
          ),
        ),
      );
    } else {
      // LUONG QUEN MK: Gui email reset password qua Firebase
      if (widget.emailForReset != null) {
        await _authService.resetPasswordWithEmail(
          email: widget.emailForReset!,
          newPassword: newPassword,
          otpCode: widget.otpCode ?? '',
        );
        setState(() => _isLoading = false);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              appBarTitle: 'Khoi phuc mat khau',
              successTitle: 'Thanh cong!',
              successMessage: 'Email dat lai mat khau da duoc gui den ${widget.emailForReset}. Vui long kiem tra hop thu va lam theo huong dan.',
              buttonText: 'Dang nhap ngay',
              onButtonPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Loi: Khong tim thay email!', isError: true);
      }
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
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  widget.isFromSecurity
                      ? const Text('Doi mat khau', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))
                      : const Text('mono', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                  const Spacer(flex: 2),
                ],
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dat lai mat khau', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF549B96))),
                      const SizedBox(height: 8),
                      const Text('Vui long nhap mat khau moi cua ban de bao mat tai khoan.', style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.4)),
                      const SizedBox(height: 30),

                      _buildLabel('Nhap mat khau moi'),
                      _buildTextField(
                        controller: _newPasswordController,
                        hintText: 'Nhap mat khau moi cua ban',
                        isObscure: _obscureNewPassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
                        child: Column(children: [
                          _buildPasswordRule('Toi thieu 8 ky tu'),
                          _buildPasswordRule('Bao gom chu cai va chu so'),
                          _buildPasswordRule('Bao gom ky tu dac biet'),
                          _buildPasswordRule('Bao gom chu cai in hoa'),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Nhap lai mat khau moi'),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Nhap lai mat khau moi cua ban',
                        isObscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // NUT LUU MAT KHAU
                      InkWell(
                        onTap: _isLoading ? null : _handleSave,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading ? [Colors.grey, Colors.grey.shade600] : [const Color(0xFF68AEA9), const Color(0xFF3E8681)],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('Luu mat khau', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: const TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField({required String hintText, TextEditingController? controller, bool isObscure = false, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildPasswordRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF8B9098), size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFF8B9098), fontSize: 13)),
      ]),
    );
  }
}
