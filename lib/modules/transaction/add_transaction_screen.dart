import 'package:flutter/material.dart';
import 'category_screen.dart'; // Đảm bảo bạn đã có file này cùng thư mục

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Biến quản lý trạng thái: true = Khoản Thu, false = Khoản Chi
  bool isIncome = true;

  // Biến lưu trữ danh mục được chọn (Mặc định chưa chọn gì)
  String selectedCategoryName = 'Chọn danh mục';
  IconData selectedCategoryIcon = Icons.category;

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
                  const SizedBox(width: 48), // Cân bằng không gian
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: 30,
                    bottom: 40,
                    left: 24,
                    right: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TAB CHUYỂN ĐỔI CHI / THU (Dạng nút viên thuốc)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isIncome = false;
                                    // Reset lại danh mục khi đổi tab để tránh nhầm lẫn
                                    selectedCategoryName = 'Chọn danh mục';
                                    selectedCategoryIcon = Icons.category;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isIncome
                                        ? const Color(0xFF1A7B73)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Khoản Chi',
                                      style: TextStyle(
                                        color: !isIncome
                                            ? Colors.white
                                            : const Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isIncome = true;
                                    // Reset lại danh mục khi đổi tab
                                    selectedCategoryName = 'Chọn danh mục';
                                    selectedCategoryIcon = Icons.category;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? const Color(0xFF1A7B73)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Khoản Thu',
                                      style: TextStyle(
                                        color: isIncome
                                            ? Colors.white
                                            : const Color(0xFF6B7280),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // DROPDOWN CHỌN DANH MỤC (Bấm vào để mở trang Lưới)
                      _buildLabel(isIncome ? 'Nguồn thu' : 'Nguồn Chi'),
                      InkWell(
                        onTap: () async {
                          // Bấm vào thì mở trang CategoryScreen và chờ đợi kết quả trả về
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryScreen(isIncome: isIncome),
                            ),
                          );

                          // Nếu người dùng có chọn 1 danh mục (không bấm nút back)
                          if (result != null) {
                            setState(() {
                              selectedCategoryName =
                                  result['name']; // Cập nhật tên
                              selectedCategoryIcon =
                                  result['icon']; // Cập nhật icon
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFFDBEAFE)
                                      : const Color(0xFFCCFBF1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  selectedCategoryIcon, // Icon sẽ thay đổi theo cái người dùng chọn
                                  color: isIncome
                                      ? Colors.blue
                                      : const Color(0xFF1A7B73),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedCategoryName, // Chữ sẽ thay đổi theo cái người dùng chọn
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Ô NHẬP SỐ TIỀN
                      _buildLabel('Số tiền'),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFF1A7B73),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '0đ',
                          hintStyle: const TextStyle(color: Color(0xFF1A7B73)),
                          filled: true,
                          fillColor: const Color(
                            0xFFE8F5F3,
                          ), // Màu nền xanh nhạt
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A7B73),
                            ), // Viền xanh
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A7B73),
                              width: 2,
                            ),
                          ),
                          suffixIcon: TextButton(
                            onPressed: () {
                              // Chức năng xóa trắng ô nhập liệu
                            },
                            child: const Text(
                              'Xóa',
                              style: TextStyle(
                                color: Color(0xFF1A7B73),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Ô NHẬP NGÀY
                      _buildLabel('Ngày'),
                      _buildTextField(
                        'Thứ ba, 22 Th2 2026',
                        Icons.calendar_today_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Ô NHẬP THỜI GIAN
                      _buildLabel('Thời gian'),
                      _buildTextField('14:30', Icons.access_time),
                      const SizedBox(height: 20),

                      // Ô NHẬP NỘI DUNG
                      _buildLabel('Nội dung'),
                      _buildTextField('Thêm nội dung', null),
                      const SizedBox(height: 40),

                      // NÚT LƯU
                      InkWell(
                        onTap: () {
                          // Bấm lưu xong thì đóng form này lại
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A7B73),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1A7B73).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Lưu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  // --- HÀM HỖ TRỢ ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData? suffixIcon) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.grey)
            : null,
      ),
    );
  }
}
