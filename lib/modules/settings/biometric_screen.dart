import 'package:flutter/material.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  // Các biến để lưu trạng thái của công tắc
  bool _isFaceIdEnabled = true;
  bool _isFingerprintEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Nền chính của Scaffold là màu trắng
      body: Column(
        children: [
          // 1. PHẦN NỀN XANH BO CONG DƯỚI (Kết hợp AppBar và Icon to)
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Nền xanh ngọc
              Container(
                height: 320,
                width: double.infinity,
                padding: const EdgeInsets.only(
                  bottom: 60,
                ), // Chừa chỗ cho icon lòi ra
                decoration: const BoxDecoration(
                  color: Color(0xFF438883),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(50),
                  ), // Bo cong ở dưới
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // AppBar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
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
                              'Đăng nhập sinh trắc học',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 48), // Khối tàng hình
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ICON VÂN TAY TO BỰ CHÍNH GIỮA (Nằm đè lên cạnh dưới của nền xanh)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8), // Viền trắng bao quanh
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5F0), // Nền xanh nhạt
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4A9B7F),
                        width: 3,
                      ), // Viền xanh đậm
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      color: Color(0xFF4A9B7F),
                      size: 50,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // 2. KHUNG NỘI DUNG (Danh sách công tắc bật tắt)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // CÔNG TẮC FACE ID
                        _buildSwitchItem(
                          icon: Icons.face_retouching_natural,
                          title: 'Sử dụng FaceID',
                          subtitle: 'Đăng nhập bằng nhận diện khuôn mặt',
                          value: _isFaceIdEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isFaceIdEnabled = val;
                            });
                          },
                          showDivider: true,
                        ),

                        // CÔNG TẮC VÂN TAY
                        _buildSwitchItem(
                          icon: Icons.fingerprint,
                          title: 'Sử dụng Vân tay',
                          subtitle: 'Quét vân tay để mở khóa ứng dụng',
                          value: _isFingerprintEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isFingerprintEnabled = val;
                            });
                          },
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // NÚT LƯU CÀI ĐẶT
                  InkWell(
                    onTap: () {
                      // Lưu trạng thái và thoát
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9B7F),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A9B7F).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Lưu cài đặt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DÒNG CHỮ LƯU Ý
                  const Text(
                    'Dữ liệu sinh trắc học được bảo mật bởi hệ thống và không chia sẻ với bên thứ ba.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                      height: 1.5,
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

  // --- HÀM TẠO TỪNG DÒNG CÓ CÔNG TẮC BẬT TẮT ---
  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF438883), size: 24),
              ),
              const SizedBox(width: 16),

              // Chữ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Công tắc (Switch)
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF4A9B7F),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.grey.shade200,
            indent: 70,
            endIndent: 16,
          ),
      ],
    );
  }
}
