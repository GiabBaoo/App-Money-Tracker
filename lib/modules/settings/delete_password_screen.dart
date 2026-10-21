import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../widgets/mono_toast.dart';
import 'success_screen.dart';
import '../auth/login_screen.dart';

class DeletePasswordScreen extends StatefulWidget {
  const DeletePasswordScreen({super.key});

  @override
  State<DeletePasswordScreen> createState() => _DeletePasswordScreenState();
}

class _DeletePasswordScreenState extends State<DeletePasswordScreen> {
  final AuthService _authService = AuthService();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final password = _passwordController.text;
    if (password.isEmpty) {
      MonoToast.error(context, isVi ? 'Vui lòng nhập mật khẩu!' : 'Please enter your password!');
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.deleteAccount(password: password);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result.success) {
      Navigator.push(context, PageTransitions.scale(SuccessScreen(
        appBarTitle: isVi ? 'Xóa tài khoản' : 'Delete Account',
        successTitle: isVi ? 'Xóa tài khoản thành công' : 'Account Deleted Successfully',
        successMessage: isVi
            ? 'Tất cả dữ liệu tài chính cá nhân của bạn đã được gỡ bỏ vĩnh viễn khỏi hệ thống.'
            : 'All your personal financial data has been permanently removed from the system.',
        buttonText: isVi ? 'Quay về đăng nhập' : 'Back to Login',
        onButtonPressed: () {
          Navigator.pushAndRemoveUntil(context, PageTransitions.fade(const LoginScreen()), (route) => false);
        },
      )));
    } else {
      MonoToast.error(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF1E1E1E) 
        : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi ? 'Xác thực danh tính' : 'Identity Verification',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
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
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 40,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Nhập mật khẩu' : 'Enter Password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isVi
                            ? 'Vui lòng nhập mật khẩu của bạn để xác nhận hành động xóa tài khoản.'
                            : 'Please enter your password to confirm account deletion.',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          isVi ? 'Mật khẩu' : 'Password',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: isVi ? 'Nhập mật khẩu của bạn' : 'Enter your password',
                          hintStyle: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white38 
                              : const Color(0xFFAAAAAA),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF2E2E2E) 
                            : Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF3E3E3E) 
                                : const Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF438883),
                              width: 1.5,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      InkWell(
                        onTap: _isLoading ? null : _handleDelete,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE63946),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              isVi ? 'Xác nhận xóa' : 'Confirm Delete',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
