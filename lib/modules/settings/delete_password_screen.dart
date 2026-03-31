import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
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
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập mật khẩu!'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final result = await _authService.deleteAccount(password: password);
    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      Navigator.push(context, PageTransitions.scale(SuccessScreen(
        appBarTitle: 'Xóa tài khoản',
        successTitle: 'Xóa tài khoản thành công',
        successMessage: 'Tất cả dữ liệu tài chính cá nhân của bạn đã được gỡ bỏ vĩnh viễn khỏi hệ thống.',
        buttonText: 'Quay về đăng nhập',
        onButtonPressed: () {
          Navigator.pushAndRemoveUntil(context, PageTransitions.fade(const LoginScreen()), (route) => false);
        },
      )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Xác thực danh tính',
                    style: TextStyle(
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
                        'Nhập mật khẩu',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Vui lòng nhập mật khẩu của bạn để xác nhận hành động xóa tài khoản.',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'Mật khẩu',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                          hintText: 'Nhập mật khẩu của bạn',
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
                          child: const Center(
                            child: Text(
                              'Xác nhận xóa',
                              style: TextStyle(
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
