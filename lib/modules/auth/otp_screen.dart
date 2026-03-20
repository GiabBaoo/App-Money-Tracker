import 'package:flutter/material.dart';
import '../home/home_screen.dart'; // Import Trang Chủ
import 'reset_password_screen.dart'; // ĐÃ THÊM: Import trang Đặt Lại Mật Khẩu

class OTPScreen extends StatelessWidget {
  // BIẾN MỚI: Để app biết bạn đang đến từ luồng Quên mật khẩu hay Đăng ký
  final bool isFromForgotPass;

  const OTPScreen({
    super.key,
    this.isFromForgotPass = false,
  }); // Mặc định là false (Luồng đăng ký)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Nền xanh và Logo phía trên
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            color: const Color(0xFF5E9387), // Xanh lá mạ
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'mono',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                      ), // Cân bằng không gian cho chữ vào giữa
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Nội dung Card OTP
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 100, bottom: 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 35,
                        offset: const Offset(0, 22),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mã xác thực OTP',
                        style: TextStyle(
                          color: Color(0xFF5E9387),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mã xác thực đã gửi về r******@gmail.com',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // 6 Ô NHẬP OTP XẾP NGANG
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          6,
                          (index) => _buildOTPBox(context),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // DÒNG GỬI LẠI MÃ
                      const Text(
                        'Bạn chưa nhận được mã?',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Gửi lại mã sau 00:59 | ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: 'Gửi lại mã',
                              style: TextStyle(
                                color: Color(0xFF5E9387),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // NÚT XÁC NHẬN (LOGIC ĐÃ ĐƯỢC CHIA 2 LUỒNG)
                      InkWell(
                        onTap: () {
                          if (isFromForgotPass) {
                            // NẾU LÀ LUỒNG QUÊN MẬT KHẨU -> Sang trang Đặt Lại Mật Khẩu
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ResetPasswordScreen(),
                              ),
                            );
                          } else {
                            // NẾU LÀ LUỒNG ĐĂNG KÝ -> Bay thẳng vào Trang Chủ
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF68AEA9), Color(0xFF3E8681)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Center(
                            child: Text(
                              'Xác Nhận',
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
          ),
        ],
      ),
    );
  }

  // --- HÀM HỖ TRỢ TẠO Ô NHẬP OTP ---
  Widget _buildOTPBox(BuildContext context) {
    return SizedBox(
      height: 50,
      width: 42,
      child: TextFormField(
        autofocus: true,
        onChanged: (value) {
          if (value.length == 1) {
            FocusScope.of(context).nextFocus();
          }
        },
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        decoration: InputDecoration(
          counterText: "",
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF5E9387), width: 2),
          ),
        ),
      ),
    );
  }
}
