import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedGender = 'Nam';
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF438883))),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ thông tin bắt buộc!', isError: true);
      return;
    }
    if (password.length < 8) {
      _showSnackBar('Mật khẩu phải có ít nhất 8 ký tự!', isError: true);
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('Mật khẩu nhập lại không khớp!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      name: name,
      email: email,
      phone: phone,
      gender: _selectedGender,
      password: password,
      dateOfBirth: _selectedDate,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      _showSnackBar(result.message);
      // Đăng ký thành công -> Vào thẳng Trang Chủ
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF438883),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

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
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                const Text('mono', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
                const Spacer(flex: 2),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng ký tài khoản', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                      const SizedBox(height: 8),
                      const Text('Vui lòng điền đầy đủ thông tin bên dưới để tham gia cùng chúng tôi.', style: TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.4)),
                      const SizedBox(height: 30),

                      _buildLabel('Tên người dùng'),
                      _buildTextField(controller: _nameController, hintText: 'Nhập tên người dùng của bạn'),
                      _buildLabel('Email'),
                      _buildTextField(controller: _emailController, hintText: 'Nhập email của bạn', keyboardType: TextInputType.emailAddress),
                      _buildLabel('Số điện thoại'),
                      _buildTextField(controller: _phoneController, hintText: 'Nhập số điện thoại', keyboardType: TextInputType.phone),

                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _buildLabel('Giới tính'),
                          Row(children: [_buildGenderOption('Nam'), const SizedBox(width: 8), _buildGenderOption('Nữ')]),
                        ])),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _buildLabel('Ngày sinh'),
                          InkWell(
                            onTap: _pickDate,
                            child: Container(
                              height: 50, padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDDDDD)), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(
                                  _selectedDate == null ? 'DD/MM/YYYY' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                  style: TextStyle(color: _selectedDate == null ? Colors.grey.shade400 : const Color(0xFF333333), fontSize: 14),
                                ),
                                const Icon(Icons.calendar_today, color: Color(0xFF438883), size: 18),
                              ]),
                            ),
                          ),
                        ])),
                      ]),

                      const SizedBox(height: 8),
                      _buildLabel('Mật khẩu'),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Nhập mật khẩu của bạn',
                        isObscure: _obscurePassword,
                        suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
                        child: Column(children: [
                          _buildPasswordRule('Tối thiểu 8 ký tự'),
                          _buildPasswordRule('Bao gồm chữ cái và chữ số'),
                          _buildPasswordRule('Bao gồm ký tự đặc biệt'),
                          _buildPasswordRule('Bao gồm chữ cái in hoa'),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Nhập lại mật khẩu'),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Nhập lại mật khẩu của bạn',
                        isObscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                      ),
                      const SizedBox(height: 40),

                      // NÚT ĐĂNG KÝ CÓ LOADING
                      InkWell(
                        onTap: _isLoading ? null : _handleRegister,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading ? [Colors.grey, Colors.grey.shade600] : [const Color(0xFF68AEA9), const Color(0xFF3E8681)],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [BoxShadow(color: const Color(0xFF3E8681).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('Đăng Ký', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, left: 2, top: 16), child: Text(text, style: const TextStyle(color: Color(0xFF666666), fontSize: 14, fontWeight: FontWeight.w500)));
  }

  Widget _buildTextField({required String hintText, TextEditingController? controller, bool isObscure = false, TextInputType keyboardType = TextInputType.text, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller, obscureText: isObscure, keyboardType: keyboardType, style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText, hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    bool isSelected = _selectedGender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = gender),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5F0) : Colors.transparent,
            border: Border.all(color: isSelected ? const Color(0xFF438883) : const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(gender, style: TextStyle(color: isSelected ? const Color(0xFF438883) : const Color(0xFF666666), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
        ),
      ),
    );
  }

  Widget _buildPasswordRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF8B9098), size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Color(0xFF8B9098), fontSize: 13)),
      ]),
    );
  }
}
