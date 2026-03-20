import 'package:flutter/material.dart';
import '../settings/success_screen.dart'; // Đảm bảo import trang báo Thành Công đa năng
import 'login_screen.dart'; // Import trang Đăng nhập

class ResetPasswordScreen extends StatefulWidget {
  // BIẾN MỚI: Xác định luồng hiện tại.
  // true = Luồng Đổi MK trong Cài đặt | false = Luồng Quên MK
  final bool isFromSecurity;

  const ResetPasswordScreen({super.key, this.isFromSecurity = false});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Trạng thái ẩn/hiện mật khẩu
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER (Nút Back và Logo Mono / Tiêu đề)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Nếu từ Cài đặt thì hiện chữ "Đổi mật khẩu", nếu Quên MK thì hiện logo "mono"
                  widget.isFromSecurity
                      ? const Text(
                          'Đổi mật khẩu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const Text(
                          'mono',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5,
                          ),
                        ),
                  const Spacer(flex: 2), // Cân bằng không gian
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG FORM MÀU TRẮNG
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TIÊU ĐỀ
                      const Text(
                        'Đặt lại mật khẩu',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF549B96), // Màu xanh theo thiết kế
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng nhập mật khẩu mới của bạn để bảo mật tài khoản.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // MẬT KHẨU MỚI
                      _buildLabel('Nhập mật khẩu mới'),
                      _buildTextField(
                        hintText: 'Nhập mật khẩu mới của bạn',
                        isObscure: _obscureNewPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // BẢNG YÊU CẦU MẬT KHẨU
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildPasswordRule('Tối thiểu 8 ký tự'),
                            _buildPasswordRule('Bao gồm chữ cái và chữ số'),
                            _buildPasswordRule('Bao gồm ký tự đặc biệt'),
                            _buildPasswordRule('Bao gồm chữ cái in hoa'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // NHẬP LẠI MẬT KHẨU MỚI
                      _buildLabel('Nhập lại mật khẩu mới'),
                      _buildTextField(
                        hintText: 'Nhập lại mật khẩu mới của bạn',
                        isObscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // NÚT LƯU MẬT KHẨU (ĐÃ TÁCH LOGIC 2 LUỒNG)
                      InkWell(
                        onTap: () {
                          // LOGIC: Lưu thành công -> Hiện trang Success
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SuccessScreen(
                                appBarTitle: widget.isFromSecurity
                                    ? 'Đổi mật khẩu'
                                    : 'Khôi phục mật khẩu',
                                successTitle: 'Thành công!',
                                successMessage: widget.isFromSecurity
                                    ? 'Mật khẩu của bạn đã được cập nhật an toàn.'
                                    : 'Mật khẩu của bạn đã được đặt lại thành công. Vui lòng đăng nhập lại.',
                                buttonText: widget.isFromSecurity
                                    ? 'Quay lại Bảo mật'
                                    : 'Đăng nhập ngay',
                                onButtonPressed: () {
                                  if (widget.isFromSecurity) {
                                    // LUỒNG 2: Nếu từ Cài đặt -> Lùi 3 bước về trang Security
                                    int count = 0;
                                    Navigator.popUntil(context, (route) {
                                      return count++ == 3;
                                    });
                                  } else {
                                    // LUỒNG 1: Nếu từ Quên MK -> Nhảy thẳng về trang Login
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF68AEA9), Color(0xFF3E8681)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF3E8681,
                                ).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Lưu mật khẩu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
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

  // --- CÁC HÀM TIỆN ÍCH GIÚP CODE GỌN GÀNG HƠN ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    bool isObscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      obscureText: isObscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.3),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildPasswordRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF8B9098),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF8B9098), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
