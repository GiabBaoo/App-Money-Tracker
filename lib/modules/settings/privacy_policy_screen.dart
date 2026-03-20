import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
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
                  const Text(
                    'Chính sách bảo mật',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Cân bằng không gian
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white, // Nền trắng toàn bộ
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                // NỘI DUNG CÓ THỂ CUỘN (Đã bỏ khối Expanded và Column bọc ngoài thừa thãi)
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 30,
                    bottom: 60,
                    left: 24,
                    right: 24,
                  ), // Tăng bottom padding lên 60
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lời chào và cam kết
                      const Text(
                        'Sự riêng tư của bạn là ưu tiên hàng đầu',
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chào mừng bạn đến với ứng dụng của chúng tôi. Chúng tôi cam kết bảo vệ thông tin cá nhân và quyền riêng tư của bạn một cách tuyệt đối theo các tiêu chuẩn bảo mật hiện đại nhất.',
                        style: TextStyle(
                          color: Color(0xFF666666),
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
                          color: const Color(0xFFE8F5F0), // Xanh ngọc nhạt
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.calendar_today,
                              color: Color(0xFF4A9B7F),
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'CẬP NHẬT LẦN CUỐI: 24-5-2024',
                              style: TextStyle(
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
                        title: 'Thu thập dữ liệu',
                        content:
                            'Chúng tôi thu thập thông tin mà bạn cung cấp khi đăng ký tài khoản, bao gồm:\n\n• Họ tên và thông tin liên lạc\n• Thông tin đăng nhập\n• Dữ liệu thiết bị và địa chỉ IP',
                      ),
                      _buildPolicyItem(
                        step: '2',
                        title: 'Sử dụng thông tin',
                        content:
                            'Dữ liệu của bạn được sử dụng để cung cấp và cải thiện dịch vụ, cá nhân hóa trải nghiệm và gửi các thông báo quan trọng về bảo mật.',
                      ),
                      _buildPolicyItem(
                        step: '3',
                        title: 'Bảo mật dữ liệu',
                        content:
                            'Chúng tôi áp dụng các biện pháp mã hóa và tường lửa tiên tiến để ngăn chặn truy cập trái phép vào thông tin cá nhân của bạn.',
                      ),
                      _buildPolicyItem(
                        step: '4',
                        title: 'Chia sẻ với bên thứ ba',
                        content:
                            'Chúng tôi không bán hoặc cho thuê dữ liệu của bạn. Thông tin chỉ được chia sẻ khi có yêu cầu hợp pháp từ cơ quan chức năng hoặc các đối tác cung cấp dịch vụ được chọn lọc.',
                      ),
                      _buildPolicyItem(
                        step: '5',
                        title: 'Quyền của người dùng',
                        content:
                            'Bạn có quyền truy cập, chỉnh sửa, tải xuống hoặc yêu cầu xóa toàn bộ dữ liệu cá nhân của mình bất kỳ lúc nào thông qua phần Cài đặt.',
                      ),

                      const SizedBox(height: 10),

                      // HỘP LIÊN HỆ HỖ TRỢ
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bạn có câu hỏi?',
                              style: TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nếu bạn có bất kỳ thắc mắc nào về Chính sách bảo mật này, xin liên hệ với chúng tôi.',
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () {
                                // TODO: Mở trang liên hệ
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE8F5F0,
                                  ), // Xanh ngọc nhạt
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.support_agent,
                                      color: Color(0xFF4A9B7F),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Liên hệ hỗ trợ',
                                      style: TextStyle(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5F0),
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
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 16),
            child: Text(
              content,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
