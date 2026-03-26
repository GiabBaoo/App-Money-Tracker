import 'package:flutter/material.dart';
import 'login_screen.dart';

class ForgotPasswordConfirmationScreen extends StatelessWidget {
  final String email;

  const ForgotPasswordConfirmationScreen({super.key, required this.email});

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
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.mail_outline, color: Color(0xFF438883), size: 40),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Kiem tra email cua ban',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Description with email
                      Text(
                        'Chung toi da gui email dat lai mat khau toi\n$email',
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui long kiem tra hop thu va click vao link de dat lai mat khau.',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Steps
                      _buildStep(1, 'Kiem tra hop thu (hoac tuc nhan) cua ban'),
                      _buildStep(2, 'Tim email toi tu "no-reply@accounts.google.com"'),
                      _buildStep(3, 'Click link "Dat lai mat khau" trong email'),
                      _buildStep(4, 'Tao mat khau moi va luu thay doi'),
                      const SizedBox(height: 40),

                      // Instruction box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFEAA7), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFF0AD4E), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Link se het han sau 1 gio. Neu khong nhan duoc email, kiem tra thu muc Spam hoac Promotions.',
                                style: const TextStyle(color: Color(0xFF856404), fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Back to login button
                      InkWell(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF68AEA9), Color(0xFF3E8681)]),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Center(
                            child: Text(
                              'Quay lai Dang nhap',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Contact support link
                      Center(
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Vui long lien he support@mono.com'),
                                backgroundColor: const Color(0xFF438883),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          child: const Text(
                            'Co van de? Lien he support',
                            style: TextStyle(color: Color(0xFF438883), fontSize: 13, fontWeight: FontWeight.w500),
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

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF438883),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
