import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:flutter/services.dart'; // Thêm thư viện này để dùng FilteringTextInputFormatter chặn nhập chữ vào sđt
import '../../services/auth_service.dart';
import 'verify_email_screen.dart';

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

  // Real-time validation errors
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _dateError;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasLetter = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _hasUpperCase = false;

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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF438883)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _onDateChanged();
    }
  }

  // ==================== VALIDATION FUNCTIONS ====================
  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu!';
    if (password.length < 8) return 'Mật khẩu phải có tối thiểu 8 ký tự!';
    if (!RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Mật khẩu phải có chữ cái (vừa chữ hoa vừa chữ thường)!';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Mật khẩu phải có chữ số!';
    if (!RegExp(
      r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""",
    ).hasMatch(password)) {
      return 'Mật khẩu phải có ký tự đặc biệt (!@#\$%^&* ...)!';
    }
    return null;
  }

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại!';
    if (phone.length != 10) return 'Số điện thoại phải có đúng 10 chữ số!';
    if (!RegExp(r'^[0-9]+$').hasMatch(phone))
      return 'Số điện thoại chỉ chứa chữ số!';

    // Check nhanh đầu số hợp lệ của VN (03, 05, 07, 08, 09) và phải đủ 10 số
    if (!RegExp(r'^(03|05|07|08|09)[0-9]{8}$').hasMatch(phone)) {
      return 'Số điện thoại không có thực (phải bắt đầu bằng 03, 05, 07, 08 hoặc 09)!';
    }
    return null;
  }

  String? _validateDateOfBirth(DateTime? date) {
    if (date == null) return 'Vui lòng chọn ngày sinh!';
    final now = DateTime.now();
    final minAge = DateTime(now.year - 6, now.month, now.day);
    if (date.isAfter(minAge)) {
      return 'Bạn phải tối thiểu 6 tuổi để đăng ký tài khoản!';
    }
    return null;
  }

  void _updatePasswordValidation(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(
        r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""",
      ).hasMatch(password);
      _hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
      _passwordError = _validatePassword(password);
    });
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = value.trim().isEmpty ? 'Vui lòng nhập tên!' : null;
    });
  }

  void _onEmailChanged(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _emailError = 'Vui lòng nhập email!';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
        _emailError = 'Email không hợp lệ!';
      } else {
        _emailError = null;
      }
    });
  }

  void _onPhoneChanged(String value) {
    setState(() {
      _phoneError = _validatePhone(value);
    });
  }

  void _onConfirmPasswordChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = 'Vui lòng nhập lại mật khẩu!';
      } else if (value != _passwordController.text) {
        _confirmPasswordError = 'Mật khẩu nhập lại không khớp!';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _onDateChanged() {
    setState(() {
      _dateError = _validateDateOfBirth(_selectedDate);
    });
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate Name
    if (name.isEmpty) {
      _showSnackBar('Vui lòng nhập tên!', isError: true);
      return;
    }

    // Validate Email
    if (email.isEmpty) {
      _showSnackBar('Vui lòng nhập email!', isError: true);
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _showSnackBar('Email không hợp lệ!', isError: true);
      return;
    }

    // Validate Phone
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      _showSnackBar(phoneError, isError: true);
      return;
    }

    // Validate Password
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      _showSnackBar(passwordError, isError: true);
      return;
    }

    // Validate Confirm Password
    if (password != confirmPassword) {
      _showSnackBar('Mật khẩu nhập lại không khớp!', isError: true);
      return;
    }

    // Validate Date of Birth
    final dateError = _validateDateOfBirth(_selectedDate);
    if (dateError != null) {
      _showSnackBar(dateError, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final regResult = await _authService.register(
      name: name,
      email: email,
      phone: phone,
      gender: _selectedGender,
      password: password,
      dateOfBirth: _selectedDate,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (regResult.success) {
      Navigator.pushReplacement(
        context,
        PageTransitions.slideRight(VerifyEmailScreen(email: email)),
      );
    } else {
      _showSnackBar(regResult.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF438883),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
                  const Spacer(flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                        'Vui lòng điền đầy đủ thông tin bên dưới.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildLabel('Tên người dùng', error: _nameError),
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Nhập tên người dùng',
                        onChanged: _onNameChanged,
                        errorText: _nameError,
                      ),
                      _buildLabel('Email', error: _emailError),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'Nhập email',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: _onEmailChanged,
                        errorText: _emailError,
                      ),
                      _buildLabel('Số điện thoại', error: _phoneError),
                      _buildTextField(
                        controller: _phoneController,
                        hintText: 'Nhập số điện thoại',
                        keyboardType: TextInputType.phone,
                        onChanged: _onPhoneChanged,
                        errorText: _phoneError,
                        maxLength: 10,
                        // Thêm dòng dưới đây để chặn nhập chữ vào ô số điện thoại
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Ngày sinh', error: _dateError),
                                InkWell(
                                  onTap: _pickDate,
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: _dateError != null
                                            ? Colors.red
                                            : const Color(0xFFDDDDDD),
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
                                if (_dateError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      left: 12,
                                    ),
                                    child: Text(
                                      _dateError!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildLabel('Mật khẩu', error: _passwordError),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Nhập mật khẩu',
                        isObscure: _obscurePassword,
                        onChanged: _updatePasswordValidation,
                        errorText: _passwordError,
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildPasswordRule(
                              'Tối thiểu 8 ký tự',
                              _hasMinLength,
                            ),
                            _buildPasswordRule(
                              'Bao gồm chữ cái và chữ số',
                              _hasLetter && _hasNumber,
                            ),
                            _buildPasswordRule(
                              'Bao gồm ký tự đặc biệt (!@#\$%^&*)',
                              _hasSpecialChar,
                            ),
                            _buildPasswordRule(
                              'Bao gồm chữ cái in hoa',
                              _hasUpperCase,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(
                        'Nhập lại mật khẩu',
                        error: _confirmPasswordError,
                      ),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: 'Nhập lại mật khẩu',
                        isObscure: _obscureConfirmPassword,
                        onChanged: _onConfirmPasswordChanged,
                        errorText: _confirmPasswordError,
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
                      InkWell(
                        onTap: _isLoading ? null : _handleRegister,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey, Colors.grey.shade600]
                                  : [
                                      const Color(0xFF68AEA9),
                                      const Color(0xFF3E8681),
                                    ],
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
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Đăng ký',
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

  Widget _buildLabel(String t, {String? error}) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2, top: 16),
    child: Text(
      t,
      style: TextStyle(
        color: error != null ? Colors.red : const Color(0xFF666666),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _buildTextField({
    required String hintText,
    TextEditingController? controller,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    Function(String)? onChanged,
    String? errorText,
    int? maxLength,
    List<TextInputFormatter>?
    inputFormatters, // Thêm tham số này để hỗ trợ format
  }) {
    bool hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          maxLength: maxLength,
          inputFormatters: inputFormatters, // Truyền format vào TextFormField
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
            isDense: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFFDDDDDD),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF438883),
                width: 1.5,
              ),
            ),
            suffixIcon: suffixIcon,
            counterText: '',
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildGenderOption(String gender) {
    bool s = _selectedGender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = gender),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: s ? const Color(0xFFE8F5F0) : Colors.transparent,
            border: Border.all(
              color: s ? const Color(0xFF438883) : const Color(0xFFDDDDDD),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              gender,
              style: TextStyle(
                color: s ? const Color(0xFF438883) : const Color(0xFF666666),
                fontWeight: s ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.check_circle_outline,
            color: isValid ? Colors.green : const Color(0xFF8B9098),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? Colors.green : const Color(0xFF8B9098),
              fontSize: 13,
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
