import 'package:flutter/material.dart';
import '../../services/language_service.dart';
import '../../utils/page_transitions.dart';
import 'support_request_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageService = LanguageScope.of(context);
    final isVi = languageService.isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark 
        ? const Color(0xFF0F2625) 
        : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
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
                    isVi ? 'Chính sách bảo mật' : 'Privacy Policy',
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

            // 2. KHUNG NỘI DUNG MÀU TRẮNG
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 30,
                    bottom: 60,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lời chào và cam kết
                      Text(
                        isVi 
                          ? 'Sự riêng tư của bạn là ưu tiên hàng đầu' 
                          : 'Your privacy is our top priority',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isVi
                          ? 'Chào mừng bạn đến với ứng dụng của chúng tôi. Chúng tôi cam kết bảo vệ thông tin cá nhân và quyền riêng tư của bạn một cách tuyệt đối theo các tiêu chuẩn bảo mật hiện đại nhất.'
                          : 'Welcome to our application. We are committed to protecting your personal information and privacy with the highest modern security standards.',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Nút cập nhật lần cuối
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark 
                            ? const Color(0xFF3E3E3E) 
                            : const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF4A9B7F),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVi ? 'CẬP NHẬT LẦN CUỐI: 24-5-2024' : 'LAST UPDATED: 24-05-2024',
                              style: const TextStyle(
                                color: Color(0xFF4A9B7F),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // CÁC ĐIỀU KHOẢN (Danh sách)
                      _buildPolicyItem(
                        step: '1',
                        title: isVi ? 'Thu thập dữ liệu' : 'Data Collection',
                        content: isVi
                            ? 'Chúng tôi thu thập thông tin mà bạn cung cấp khi đăng ký tài khoản, bao gồm:\n\n• Họ tên và thông tin liên lạc\n• Thông tin đăng nhập\n• Dữ liệu thiết bị và địa chỉ IP'
                            : 'We collect information you provide when registering an account, including:\n\n• Name and contact info\n• Login credentials\n• Device data and IP address',
                      ),
                      _buildPolicyItem(
                        step: '2',
                        title: isVi ? 'Sử dụng thông tin' : 'Information Usage',
                        content: isVi
                            ? 'Dữ liệu của bạn được sử dụng để cung cấp và cải thiện dịch vụ, cá nhân hóa trải nghiệm và gửi các thông báo quan trọng về bảo mật.'
                            : 'Your data is used to provide and enhance services, personalize user experience, and send important security notifications.',
                      ),
                      _buildPolicyItem(
                        step: '3',
                        title: isVi ? 'Bảo mật dữ liệu' : 'Data Security',
                        content: isVi
                            ? 'Chúng tôi áp dụng các biện pháp mã hóa và tường lửa tiên tiến để ngăn chặn truy cập trái phép vào thông tin cá nhân của bạn.'
                            : 'We implement advanced encryption and firewall measures to prevent unauthorized access to your personal information.',
                      ),
                      _buildPolicyItem(
                        step: '4',
                        title: isVi ? 'Chia sẻ với bên thứ ba' : 'Third-Party Sharing',
                        content: isVi
                            ? 'Chúng tôi không bán hoặc cho thuê dữ liệu của bạn. Thông tin chỉ được chia sẻ khi có yêu cầu hợp pháp từ cơ quan chức năng hoặc các đối tác cung cấp dịch vụ được chọn lọc.'
                            : 'We do not sell or lease your data. Information is only shared upon lawful request by authorities or with vetted service partners.',
                      ),
                      _buildPolicyItem(
                        step: '5',
                        title: isVi ? 'Quyền của người dùng' : 'User Rights',
                        content: isVi
                            ? 'Bạn có quyền truy cập, chỉnh sửa, tải xuống hoặc yêu cầu xóa toàn bộ dữ liệu cá nhân của mình bất kỳ lúc nào thông qua phần Cài đặt.'
                            : 'You have the right to access, edit, download, or request deletion of all your personal data at any time via Settings.',
                      ),

                      const SizedBox(height: 10),

                      // HỘP LIÊN HỆ HỖ TRỢ
                      Builder(
                        builder: (context) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVi ? 'Bạn có câu hỏi?' : 'Have Questions?',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF333333),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isVi
                                    ? 'Nếu bạn có bất kỳ thắc mắc nào về Chính sách bảo mật này, xin liên hệ với chúng tôi.'
                                    : 'If you have any questions regarding this Privacy Policy, please contact us.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF666666),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageTransitions.slideRight(const SupportRequestScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.support_agent,
                                          color: Color(0xFF4A9B7F),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isVi ? 'Liên hệ hỗ trợ' : 'Contact Support',
                                          style: const TextStyle(
                                            color: Color(0xFF4A9B7F),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
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

  // --- HÀM TẠO TỪNG MỤC TRONG CHÍNH SÁCH ---
  Widget _buildPolicyItem({
    required String step,
    required String title,
    required String content,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB),
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: const Border(),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Color(0xFF4A9B7F),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF333333),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 16),
                child: Text(
                  content,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF666666),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
