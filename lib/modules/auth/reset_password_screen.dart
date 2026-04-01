import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
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

  bool _hasMinLength = false;
  bool _hasLetter = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _hasUpperCase = false;
  String? _passwordError;
  String? _confirmPasswordError;

  void _updatePasswordValidation(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""").hasMatch(password);
      _hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
      _passwordError = _validatePassword(password);
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu!';
    if (!_hasMinLength) return 'Mật khẩu phải có ít nhất 8 ký tự!';
    if (!_hasLetter) return 'Mật khẩu phải chứa ít nhất một chữ cái!';
    if (!_hasNumber) return 'Mật khẩu phải chứa ít nhất một chữ số!';
    if (!_hasSpecialChar) return 'Mật khẩu phải chứa ít nhất một ký tự đặc biệt!';
    if (!_hasUpperCase) return 'Mật khẩu phải chứa ít nhất một chữ cái in hoa!';
    return null;
  }

  void _onConfirmPasswordChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = 'Vui lòng nhập lại mật khẩu!';
      } else if (value != _newPasswordController.text) {
        _confirmPasswordError = 'Mật khẩu nhập lại không khớp!';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

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
      _showSnackBar('Vui lòng nhập đầy đủ mật khẩu!', isError: true);
      return;
    }
    if (_passwordError != null) {
      _showSnackBar(_passwordError!, isError: true);
      return;
    }
    if (_confirmPasswordError != null) {
      _showSnackBar(_confirmPasswordError!, isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Mật khẩu nhập lại không khớp!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isFromSecurity) {
      // LUONG DOI MK TU CAI DAT: Doi mat khau truc tiep vi da xac thuc o man hinh truoc
      final updateResult = await _authService.updateCurrentPassword(newPassword: newPassword);
      
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      if (!updateResult.success) {
        _showSnackBar(updateResult.message, isError: true);
        return;
      }

      if (!mounted) return;
      // Hien trang thanh cong
      Navigator.push(
        context,
        PageTransitions.scale(
          SuccessScreen(
            appBarTitle: 'Đổi mật khẩu',
            successTitle: 'Thành công!',
            successMessage: 'Mật khẩu của bạn đã được cập nhật an toàn.',
            buttonText: 'Quay lại Bảo mật',
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
          PageTransitions.scale(
            SuccessScreen(
              appBarTitle: 'Khôi phục mật khẩu',
              successTitle: 'Thành công!',
              successMessage: 'Email đặt lại mật khẩu đã được gửi đến ${widget.emailForReset}. Vui lòng kiểm tra hộp thư và làm theo hướng dẫn.',
              buttonText: 'Đăng nhập ngay',
              onButtonPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  PageTransitions.fade(const LoginScreen()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
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
                      ? const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))
                      : const Text('mono', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đặt lại mật khẩu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF4A9B7F) : const Color(0xFF549B96))),
                      const SizedBox(height: 8),
                      Text('Vui lòng nhập mật khẩu mới của bạn để bảo mật tài khoản.', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666), fontSize: 14, height: 1.4)),
                      const SizedBox(height: 30),

                      _buildLabel('Nhập mật khẩu mới'),
                      _buildTextField(
                        controller: _newPasswordController,
                        hintText: 'Nhập mật khẩu mới',
                        isObscure: _obscureNewPassword,
                        errorText: _passwordError,
                        onChanged: _updatePasswordValidation,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF9FAFB), 
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Column(children: [
                          _buildPasswordRule('Hiển thị từ 8 ký tự trở lên', _hasMinLength),
                          _buildPasswordRule('Bao gồm chữ cái và chữ số', _hasLetter && _hasNumber),
                          _buildPasswordRule('Bao gồm ký tự đặc biệt', _hasSpecialChar),
                          _buildPasswordRule('Bao gồm chữ cái in hoa', _hasUpperCase),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel('Nhập lại mật khẩu mới'),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Nhập lại mật khẩu mới',
                        isObscure: _obscureConfirmPassword,
                        errorText: _confirmPasswordError,
                        onChanged: _onConfirmPasswordChanged,
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
                                : const Text('Lưu mật khẩu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField({required String hintText, TextEditingController? controller, bool isObscure = false, Widget? suffixIcon, String? errorText, Function(String)? onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black.withOpacity(0.3), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFDDDDDD))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
        suffixIcon: suffixIcon,
        filled: isDark,
        fillColor: isDark ? const Color(0xFF2E2E2E) : null,
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(
          isValid ? Icons.check_circle : Icons.check_circle_outline,
          color: isValid ? const Color(0xFF438883) : const Color(0xFF8B9098),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isValid ? const Color(0xFF438883) : const Color(0xFF8B9098),
            fontSize: 13,
            fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}
