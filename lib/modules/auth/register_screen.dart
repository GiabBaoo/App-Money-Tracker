import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_toast.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
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
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: context.colors.primary,
          ),
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
  String? _validatePassword(String password, bool isVi) {
    if (password.isEmpty) return isVi ? 'Vui lòng nhập mật khẩu!' : 'Please enter password!';
    if (password.length < 8) return isVi ? 'Mật khẩu phải có tối thiểu 8 ký tự!' : 'Password must be at least 8 characters!';
    if (!RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password)) {
      return isVi
          ? 'Mật khẩu phải có chữ cái (vừa chữ hoa vừa chữ thường)!'
          : 'Password must have uppercase and lowercase letters!';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) return isVi ? 'Mật khẩu phải có chữ số!' : 'Password must have digits!';
    if (!RegExp(
      r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""",
    ).hasMatch(password)) {
      return isVi
          ? 'Mật khẩu phải có ký tự đặc biệt (!@#\$%^&* ...)!'
          : 'Password must have special characters (!@#\$%^&*...)!';
    }
    return null;
  }

  String? _validatePhone(String phone, bool isVi) {
    if (phone.isEmpty) return isVi ? 'Vui lòng nhập số điện thoại!' : 'Please enter phone number!';
    if (phone.length != 10) return isVi ? 'Số điện thoại phải có đúng 10 chữ số!' : 'Phone number must have exactly 10 digits!';
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return isVi ? 'Số điện thoại chỉ chứa chữ số!' : 'Phone number can only contain digits!';
    }

    if (!RegExp(r'^(03|05|07|08|09)[0-9]{8}$').hasMatch(phone)) {
      return isVi
          ? 'Số điện thoại không có thực (phải bắt đầu bằng 03, 05, 07, 08 hoặc 09)!'
          : 'Invalid phone number (must start with 03, 05, 07, 08 or 09)!';
    }
    return null;
  }

  String? _validateDateOfBirth(DateTime? date, bool isVi) {
    if (date == null) return isVi ? 'Vui lòng chọn ngày sinh!' : 'Please select date of birth!';
    final now = DateTime.now();
    final minAge = DateTime(now.year - 6, now.month, now.day);
    if (date.isAfter(minAge)) {
      return isVi
          ? 'Bạn phải tối thiểu 6 tuổi để đăng ký tài khoản!'
          : 'You must be at least 6 years old to register an account!';
    }
    return null;
  }

  void _updatePasswordValidation(String password) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(
        r"""[!@#$%^&*()_+\-=\[\]{};:'",./<>?\\|`~]""",
      ).hasMatch(password);
      _hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
      _passwordError = _validatePassword(password, isVi);
    });
  }

  void _onNameChanged(String value) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      _nameError = value.trim().isEmpty ? (isVi ? 'Vui lòng nhập tên!' : 'Please enter your name!') : null;
    });
  }

  void _onEmailChanged(String value) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      if (value.trim().isEmpty) {
        _emailError = isVi ? 'Vui lòng nhập email!' : 'Please enter email!';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
        _emailError = isVi ? 'Email không hợp lệ!' : 'Invalid email!';
      } else {
        _emailError = null;
      }
    });
  }

  void _onPhoneChanged(String value) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      _phoneError = _validatePhone(value, isVi);
    });
  }

  void _onConfirmPasswordChanged(String value) {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = isVi ? 'Vui lòng nhập lại mật khẩu!' : 'Please re-enter password!';
      } else if (value != _passwordController.text) {
        _confirmPasswordError = isVi ? 'Mật khẩu nhập lại không khớp!' : 'Passwords do not match!';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _onDateChanged() {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() {
      _dateError = _validateDateOfBirth(_selectedDate, isVi);
    });
  }

  Future<void> _handleRegister() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate Name
    if (name.isEmpty) {
      _showSnackBar(isVi ? 'Vui lòng nhập tên!' : 'Please enter your name!', isError: true);
      return;
    }

    // Validate Email
    if (email.isEmpty) {
      _showSnackBar(isVi ? 'Vui lòng nhập email!' : 'Please enter your email!', isError: true);
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _showSnackBar(isVi ? 'Email không hợp lệ!' : 'Invalid email address!', isError: true);
      return;
    }

    // Validate Phone
    final phoneError = _validatePhone(phone, isVi);
    if (phoneError != null) {
      _showSnackBar(phoneError, isError: true);
      return;
    }

    // Validate Password
    final passwordError = _validatePassword(password, isVi);
    if (passwordError != null) {
      _showSnackBar(passwordError, isError: true);
      return;
    }

    // Validate Confirm Password
    if (password != confirmPassword) {
      _showSnackBar(isVi ? 'Mật khẩu nhập lại không khớp!' : 'Passwords do not match!', isError: true);
      return;
    }

    // Validate Date of Birth
    final dateError = _validateDateOfBirth(_selectedDate, isVi);
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
    MonoToast.show(
      context,
      message,
      type: isError ? MonoToastType.error : MonoToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.onPrimary.withValues(alpha: 0.15),
                        border: Border.all(color: context.colors.onPrimary.withValues(alpha: 0.24), width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.colors.onPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AppLogo.wordmark(
                    height: 32,
                    color: context.colors.onPrimary,
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: AppShadows.modal(isDark),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Đăng ký tài khoản' : 'Create Account',
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng điền đầy đủ thông tin bên dưới.'
                            : 'Please fill in the information below.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildLabel(isVi ? 'Tên người dùng' : 'Full Name', error: _nameError),
                      _buildTextField(
                        controller: _nameController,
                        hintText: isVi ? 'Nhập tên người dùng' : 'Enter your name',
                        onChanged: _onNameChanged,
                        errorText: _nameError,
                      ),
                      _buildLabel('Email', error: _emailError),
                      _buildTextField(
                        controller: _emailController,
                        hintText: isVi ? 'Nhập email' : 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: _onEmailChanged,
                        errorText: _emailError,
                      ),
                      _buildLabel(isVi ? 'Số điện thoại' : 'Phone Number', error: _phoneError),
                      _buildTextField(
                        controller: _phoneController,
                        hintText: isVi ? 'Nhập số điện thoại' : 'Enter your phone number',
                        keyboardType: TextInputType.phone,
                        onChanged: _onPhoneChanged,
                        errorText: _phoneError,
                        maxLength: 10,
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
                                _buildLabel(isVi ? 'Giới tính' : 'Gender'),
                                Row(
                                  children: [
                                    _buildGenderOption('Nam', isVi ? 'Nam' : 'Male'),
                                    const SizedBox(width: 8),
                                    _buildGenderOption('Nữ', isVi ? 'Nữ' : 'Female'),
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
                                _buildLabel(isVi ? 'Ngày sinh' : 'Date of Birth', error: _dateError),
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
                                            ? context.colors.error
                                            : context.borderColor,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      color: context.inputBgColor,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedDate == null
                                              ? 'DD/MM/YYYY'
                                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                          style: context.textTheme.bodyMedium?.copyWith(
                                            color: _selectedDate == null
                                                ? context.colors.onSurfaceVariant.withValues(alpha: 0.7)
                                                : context.colors.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          color: context.colors.primary,
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
                                      style: context.textTheme.bodySmall?.copyWith(
                                        color: context.colors.error,
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
                      _buildLabel(isVi ? 'Mật khẩu' : 'Password', error: _passwordError),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: isVi ? 'Nhập mật khẩu' : 'Enter password',
                        isObscure: _obscurePassword,
                        onChanged: _updatePasswordValidation,
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: context.colors.onSurfaceVariant,
                            size: 20,
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
                          color: context.inputBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          children: [
                            _buildPasswordRule(
                              isVi ? 'Tối thiểu 8 ký tự' : 'At least 8 characters',
                              _hasMinLength,
                            ),
                            _buildPasswordRule(
                              isVi ? 'Bao gồm chữ cái và chữ số' : 'Includes letters and numbers',
                              _hasLetter && _hasNumber,
                            ),
                            _buildPasswordRule(
                              isVi ? 'Bao gồm ký tự đặc biệt (!@#\$%^&*)' : 'Includes special characters (!@#\$%^&*)',
                              _hasSpecialChar,
                            ),
                            _buildPasswordRule(
                              isVi ? 'Bao gồm chữ cái in hoa' : 'Includes uppercase letter',
                              _hasUpperCase,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(
                        isVi ? 'Nhập lại mật khẩu' : 'Confirm Password',
                        error: _confirmPasswordError,
                      ),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: isVi ? 'Nhập lại mật khẩu' : 'Re-enter password',
                        isObscure: _obscureConfirmPassword,
                        onChanged: _onConfirmPasswordChanged,
                        errorText: _confirmPasswordError,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: context.colors.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      AnimatedScaleButton(
                        onTap: _isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _handleRegister();
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [context.colors.surfaceContainerHighest, context.colors.surfaceContainerHighest]
                                  : [
                                      AppColors.primaryTealLight,
                                      AppColors.primaryTeal,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: context.colors.onPrimary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    isVi ? 'Đăng ký' : 'Sign Up',
                                    style: context.textTheme.titleMedium?.copyWith(
                                      color: context.colors.onPrimary,
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

  Widget _buildLabel(String t, {String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2, top: 16),
      child: Text(
        t,
        style: context.textTheme.labelMedium?.copyWith(
          color: error != null ? context.colors.error : context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    TextEditingController? controller,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    Function(String)? onChanged,
    String? errorText,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
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
          inputFormatters: inputFormatters,
          style: context.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.inputBgColor,
            hintText: hintText,
            hintStyle: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.normal,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            isDense: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? context.colors.error : context.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? context.colors.error : context.colors.primary,
                width: 1.8,
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
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenderOption(String genderKey, String displayLabel) {
    final isDark = context.isDark;
    bool s = _selectedGender == genderKey;
    return Expanded(
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedGender = genderKey);
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: s
                ? context.colors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                : context.inputBgColor,
            border: Border.all(
              color: s ? context.colors.primary : context.borderColor,
              width: s ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (s) ...[
                  Icon(Icons.check_circle_rounded, color: context.colors.primary, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(
                  displayLabel,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: s
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                    fontWeight: s ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ],
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
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isValid ? context.income : context.colors.onSurfaceVariant.withValues(alpha: 0.6),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              color: isValid ? context.income : context.colors.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
