import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/mono_toast.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
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
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""").hasMatch(password);
      _hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
      _passwordError = _validatePassword(password, isVi);
    });
  }

  String? _validatePassword(String? value, bool isVi) {
    if (value == null || value.isEmpty) return isVi ? 'Vui lòng nhập mật khẩu!' : 'Please enter password!';
    if (!_hasMinLength) return isVi ? 'Mật khẩu phải có ít nhất 8 ký tự!' : 'Password must be at least 8 characters!';
    if (!_hasLetter) return isVi ? 'Mật khẩu phải chứa ít nhất một chữ cái!' : 'Password must contain at least one letter!';
    if (!_hasNumber) return isVi ? 'Mật khẩu phải chứa ít nhất một chữ số!' : 'Password must contain at least one digit!';
    if (!_hasSpecialChar) return isVi ? 'Mật khẩu phải chứa ít nhất một ký tự đặc biệt!' : 'Password must contain at least one special character!';
    if (!_hasUpperCase) return isVi ? 'Mật khẩu phải chứa ít nhất một chữ cái in hoa!' : 'Password must contain at least one uppercase letter!';
    return null;
  }

  void _onConfirmPasswordChanged(String value) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = isVi ? 'Vui lòng nhập lại mật khẩu!' : 'Please re-enter password!';
      } else if (value != _newPasswordController.text) {
        _confirmPasswordError = isVi ? 'Mật khẩu nhập lại không khớp!' : 'Passwords do not match!';
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
    final isVi = LanguageScope.of(context).isVietnamese;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(isVi ? 'Vui lòng nhập đầy đủ mật khẩu!' : 'Please enter both passwords!', isError: true);
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
      _showSnackBar(isVi ? 'Mật khẩu nhập lại không khớp!' : 'Passwords do not match!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    if (widget.isFromSecurity) {
      // LUONG DOI MK TU CAI DAT
      final updateResult = await _authService.updateCurrentPassword(newPassword: newPassword);
      
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      if (!updateResult.success) {
        _showSnackBar(updateResult.message, isError: true);
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        PageTransitions.scale(
          SuccessScreen(
            appBarTitle: isVi ? 'Đổi mật khẩu' : 'Change Password',
            successTitle: isVi ? 'Thành công!' : 'Success!',
            successMessage: isVi
                ? 'Mật khẩu của bạn đã được cập nhật an toàn.'
                : 'Your password has been updated securely.',
            buttonText: isVi ? 'Quay lại Bảo mật' : 'Back to Security',
            onButtonPressed: () {
              int count = 0;
              Navigator.popUntil(context, (route) => count++ == 3);
            },
          ),
        ),
      );
    } else {
      // LUONG QUEN MK
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
              appBarTitle: isVi ? 'Khôi phục mật khẩu' : 'Reset Password',
              successTitle: isVi ? 'Thành công!' : 'Success!',
              successMessage: isVi
                  ? 'Email đặt lại mật khẩu đã được gửi đến ${widget.emailForReset}. Vui lòng kiểm tra hộp thư và làm theo hướng dẫn.'
                  : 'Password reset email sent to ${widget.emailForReset}. Please check your inbox and follow instructions.',
              buttonText: isVi ? 'Đăng nhập ngay' : 'Log in now',
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
        _showSnackBar(isVi ? 'Lỗi: Không tìm thấy email!' : 'Error: Email not found!', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    MonoToast.show(
      context,
      message,
      type: isError ? MonoToastType.error : MonoToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  widget.isFromSecurity
                      ? Text(
                          isVi ? 'Đổi mật khẩu' : 'Change Password',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        )
                      : const AppLogo.wordmark(height: 32, color: Colors.white),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: isDark ? Colors.black45 : Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Đặt lại mật khẩu' : 'Reset Password',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF549B96),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng nhập mật khẩu mới của bạn để bảo mật tài khoản.'
                            : 'Please enter your new password to secure your account.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildLabel(isVi ? 'Nhập mật khẩu mới' : 'Enter new password'),
                      _buildTextField(
                        controller: _newPasswordController,
                        hintText: isVi ? 'Nhập mật khẩu mới' : 'Enter new password',
                        isObscure: _obscureNewPassword,
                        errorText: _passwordError,
                        onChanged: _updatePasswordValidation,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                          onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(children: [
                          _buildPasswordRule(
                            isVi ? 'Hiển thị từ 8 ký tự trở lên' : 'At least 8 characters',
                            _hasMinLength,
                          ),
                          _buildPasswordRule(
                            isVi ? 'Bao gồm chữ cái và chữ số' : 'Includes letters and numbers',
                            _hasLetter && _hasNumber,
                          ),
                          _buildPasswordRule(
                            isVi ? 'Bao gồm ký tự đặc biệt' : 'Includes special characters',
                            _hasSpecialChar,
                          ),
                          _buildPasswordRule(
                            isVi ? 'Bao gồm chữ cái in hoa' : 'Includes uppercase letter',
                            _hasUpperCase,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(isVi ? 'Nhập lại mật khẩu mới' : 'Re-enter new password'),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: isVi ? 'Nhập lại mật khẩu mới' : 'Re-enter new password',
                        isObscure: _obscureConfirmPassword,
                        errorText: _confirmPasswordError,
                        onChanged: _onConfirmPasswordChanged,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: isDark ? const Color(0xFF94A3B8) : Colors.grey),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // NÚT LƯU MẬT KHẨU
                      InkWell(
                        onTap: _isLoading ? null : _handleSave,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey, Colors.grey.shade600]
                                  : [const Color(0xFF68AEA9), const Color(0xFF3E8681)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3E8681).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    isVi ? 'Lưu mật khẩu' : 'Save Password',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
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
      child: Text(text, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTextField({required String hintText, TextEditingController? controller, bool isObscure = false, Widget? suffixIcon, String? errorText, Function(String)? onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400, width: 2)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF141E2E) : const Color(0xFFF8FAFC),
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool isValid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(
          isValid ? Icons.check_circle : Icons.check_circle_outline,
          color: isValid ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF8B9098)),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isValid ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF8B9098)),
            fontSize: 13,
            fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ]),
    );
  }
}
