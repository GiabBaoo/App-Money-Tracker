import 'package:flutter/material.dart';
import 'otp_screen.dart'; // Đảm bảo import trang OTP

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER: Nút Back và Logo 'mono'
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
                  const Text(
                    'mono',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const Spacer(flex: 2), // Cân bằng
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG
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
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quên mật khẩu',
                        style: TextStyle(
                          color: Color(0xFF549B96),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng nhập Email hoặc Số điện thoại để nhận mã xác minh khôi phục mật khẩu.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // LABEL
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          'Email hoặc số điện thoại',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Ô NHẬP LIỆU (TEXT FIELD)
                      TextFormField(
                        style: const TextStyle(fontSize: 15),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Nhập email hoặc số điện thoại của bạn',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.3),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFDDDDDD),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF438883),
                              width: 1.5,
                            ),
                          ),
                          suffixIcon: const Icon(
                            Icons.mail_outline,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // DÒNG "QUAY LẠI ĐĂNG NHẬP"
                      Center(
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Quay lại Đăng nhập',
                            style: TextStyle(
                              color: Color(0xFF438883),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // NÚT "GỬI MÃ XÁC MINH"
                      InkWell(
                        onTap: () {
                          // ĐÃ SỬA CHỖ NÀY: Truyền thêm isFromForgotPass: true
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const OTPScreen(isFromForgotPass: true),
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
                              'Gửi mã Xác Minh',
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
