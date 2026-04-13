import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../auth/login_screen.dart'; // Đảm bảo bạn đã có file này
import '../auth/register_screen.dart'; // ĐÃ THÊM: Cần có file này để điều hướng khi bấm "Bắt đầu"

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình để tự động co dãn
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : Colors.white,
      // DÙNG STACK ĐỂ XẾP CHỒNG CÁC LỚP LÊN NHAU
      body: Stack(
        children: [
          // LỚP 1 (Nằm dưới cùng): HÌNH NỀN VÒNG TRÒN ĐỒNG TÂM
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/backgroud_onboarding.png',
              fit: BoxFit.fitWidth,
            ),
          ),

          // LỚP 2 (Nằm bên trên): NỘI DUNG CHÍNH
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // PHẦN HÌNH ẢNH NHÂN VẬT 3D (Đảm bảo ảnh này có nền trong suốt)
                Expanded(
                  child: Center(
                    child: Container(
                      width: size.width * 0.8, // Rộng 80% màn hình
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/onboarding.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // PHẦN NỘI DUNG CHỮ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Chi tiêu thông minh, tiết kiệm hơn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF68AEA9) : const Color(0xFF438883),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.72,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // NÚT BẮT ĐẦU -> ĐÃ SỬA ĐIỀU HƯỚNG TỚI TRANG ĐĂNG KÝ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: InkWell(
                    onTap: () {
                      // LUỒNG 1: Chuyển sang màn hình ĐĂNG KÝ
                      Navigator.push(context, PageTransitions.slideRight(const RegisterScreen()));
                    },
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF68AEA9), Color(0xFF3E8681)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF438883).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Bắt đầu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // DÒNG "ĐÃ CÓ TÀI KHOẢN? ĐĂNG NHẬP"
                TextButton(
                  onPressed: () {
                    // LUỒNG 2: Chuyển sang màn hình ĐĂNG NHẬP
                    Navigator.push(context, PageTransitions.slideRight(const LoginScreen()));
                  },
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Đã có tài khoản? ',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF444444),
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: 'Đăng nhập',
                          style: const TextStyle(
                            color: Color(0xFF438883),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
