import 'package:flutter/material.dart';
import 'otp_screen.dart'; // ĐẢM BẢO IMPORT TRANG OTP VÀO ĐÂY

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedGender = 'Nam'; // Mặc định chọn Nam
  DateTime? _selectedDate; // Ngày sinh

  // Hàm mở lịch chọn ngày sinh
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // Mặc định mở ở năm 2000
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF438883), // Màu xanh app
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. HEADER (Nút Back và Logo Mono)
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
                  const Spacer(flex: 2), // Cân bằng không gian
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG FORM ĐĂNG KÝ MÀU TRẮNG
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
                        'Đăng ký tài khoản',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng điền đầy đủ thông tin bên dưới để tham gia cùng chúng tôi.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // TÊN NGƯỜI DÙNG
                      _buildLabel('Tên người dùng'),
                      _buildTextField(hintText: 'Nhập tên người dùng của bạn'),

                      // EMAIL
                      _buildLabel('Email'),
                      _buildTextField(
                        hintText: 'Nhập email của bạn',
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // SỐ ĐIỆN THOẠI
                      _buildLabel('Số điện thoại'),
                      _buildTextField(
                        hintText: 'Nhập số điện thoại',
                        keyboardType: TextInputType.phone,
                      ),

                      // HÀNG NGANG: GIỚI TÍNH & NGÀY SINH
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Giới tính
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Giới tính'),
                                Row(
                                  children: [
                                    _buildGenderOption('Nam'),
                                    const SizedBox(width: 8),
                                    _buildGenderOption('Nữ'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Ngày sinh
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Ngày sinh'),
                                InkWell(
                                  onTap: _pickDate,
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xFFDDDDDD),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedDate == null
                                              ? 'DD/MM/YYYY'
                                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                          style: TextStyle(
                                            color: _selectedDate == null
                                                ? Colors.grey.shade400
                                                : const Color(0xFF333333),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF438883),
                                          size: 18,
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

                      const SizedBox(height: 8),

                      // MẬT KHẨU
                      _buildLabel('Mật khẩu'),
                      _buildTextField(
                        hintText: 'Nhập mật khẩu của bạn',
                        isObscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
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

                      // NHẬP LẠI MẬT KHẨU
                      _buildLabel('Nhập lại mật khẩu'),
                      _buildTextField(
                        hintText: 'Nhập lại mật khẩu của bạn',
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

                      // NÚT ĐĂNG KÝ ĐÃ ĐƯỢC KHÔI PHỤC
                      InkWell(
                        onTap: () {
                          // BƯỚC 1: Chuyển sang trang xác thực OTP
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const OTPScreen(), // Chuyển tới trang OTP
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
                                color: const Color(0xFF3E8681).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Đăng Ký',
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

  // Hàm tạo Label
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2, top: 16),
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

  // Hàm tạo Ô nhập liệu (TextFormField)
  Widget _buildTextField({
    required String hintText,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      obscureText: isObscure,
      keyboardType: keyboardType,
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

  // Hàm tạo nút chọn Giới tính (Nam / Nữ)
  Widget _buildGenderOption(String gender) {
    bool isSelected = _selectedGender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = gender),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5F0) : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF438883)
                  : const Color(0xFFDDDDDD),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              gender,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF438883)
                    : const Color(0xFF666666),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Hàm tạo dòng kiểm tra điều kiện mật khẩu
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
