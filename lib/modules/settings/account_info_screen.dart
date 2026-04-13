import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final authService = AuthService();
  final firestoreService = FirestoreService();
  final storageService = StorageService();
  final imagePicker = ImagePicker();

  bool _isEditing = false;
  bool _isUploadingImage = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String? _selectedGender;
  String? _selectedCurrency;
  DateTime? _selectedDOB;
  File? _selectedImageFile;
  String? _newAvatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeControllers(UserModel user) {
    if (!_isEditing) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _selectedGender = user.gender;
      _selectedCurrency = user.currency;
      _selectedDOB = user.dateOfBirth;
      _selectedImageFile = null;
      _newAvatarUrl = null;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Upload ảnh nếu có chọn ảnh mới
        String? avatarUrl;
        if (_selectedImageFile != null) {
          setState(() => _isUploadingImage = true);
          avatarUrl = await storageService.uploadAvatar(_selectedImageFile!);
          setState(() => _isUploadingImage = false);
        }

        // Cập nhật thông tin
        final updateData = {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'currency': _selectedCurrency,
          'dateOfBirth': _selectedDOB != null ? _selectedDOB : null,
        };

        // Thêm avatarUrl nếu có upload ảnh mới
        if (avatarUrl != null) {
          updateData['avatarUrl'] = avatarUrl;
        }

        await firestoreService.updateUserProfile(updateData);
        
        setState(() {
          _isEditing = false;
          _selectedImageFile = null;
          _newAvatarUrl = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật thông tin thành công!'), backgroundColor: Color(0xFF438883)),
          );
        }
      } catch (e) {
        setState(() => _isUploadingImage = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    // Hiển thị dialog chọn nguồn ảnh
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
        ? const Color(0xFF2E2E2E) 
        : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: isDark ? Colors.white : const Color(0xFF438883)),
                  title: Text('Chụp ảnh', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: isDark ? Colors.white : const Color(0xFF438883)),
                  title: Text('Chọn từ thư viện', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey),
                  title: Text('Hủy', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      try {
        final XFile? pickedFile = await imagePicker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          setState(() {
            _selectedImageFile = File(pickedFile.path);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi chọn ảnh: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF438883),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDOB) {
      setState(() => _selectedDOB = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const Text('Thông tin tài khoản', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                _isEditing
                    ? TextButton(onPressed: _saveProfile, child: const Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))
                    : IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
                        onPressed: () => setState(() => _isEditing = true),
                      ),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
                ),
                child: StreamBuilder<UserModel?>(
                  stream: authService.getUserProfileStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    if (user == null) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }
                    _initializeControllers(user);

                    return Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER
                            Container(
                              width: double.infinity, padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark 
                                  ? const Color(0xFF2E2E2E) 
                                  : Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Theme.of(context).brightness == Brightness.dark 
                                  ? null 
                                  : Border.all(color: const Color(0xFFE5E7EB))
                              ),
                              child: Column(children: [
                                // Avatar với nút chỉnh sửa
                                Stack(
                                  children: [
                                    Container(
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                          ? const Color(0xFF3E3E3E) 
                                          : const Color(0xFFE8F5F0),
                                        shape: BoxShape.circle,
                                        image: _selectedImageFile != null
                                          ? DecorationImage(
                                              image: FileImage(_selectedImageFile!),
                                              fit: BoxFit.cover,
                                            )
                                          : (user.avatarUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(user.avatarUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null),
                                      ),
                                      child: (_selectedImageFile == null && user.avatarUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 40, color: Color(0xFF438883))
                                        : null,
                                    ),
                                    if (_isEditing)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: GestureDetector(
                                          onTap: _pickImage,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF438883),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_isUploadingImage)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _isEditing
                                    ? TextFormField(
                                        controller: _nameController,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
                                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nhập họ và tên'),
                                        validator: (value) => (value == null || value.isEmpty) ? 'Tên không được để trống' : null,
                                      )
                                    : Text(user.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                const SizedBox(height: 8),
                                Text('ID: ${user.uid.substring(0, 8).toUpperCase()}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 14)),
                              ]),
                            ),
                            const SizedBox(height: 30),

                            _buildSectionTitle('THÔNG TIN CÁ NHÂN'),
                            _buildInfoBox([
                              _buildInfoRow(
                                Icons.badge_outlined,
                                'Họ và tên',
                                _isEditing
                                    ? null
                                    : user.name,
                                content: _isEditing
                                    ? TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                        validator: (value) => (value == null || value.isEmpty) ? 'Tên không được để trống' : null,
                                      )
                                    : null,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                Icons.male,
                                'Giới tính',
                                _isEditing ? null : user.gender,
                                content: _isEditing
                                    ? DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedGender,
                                          isDense: true,
                                          onChanged: (val) => setState(() => _selectedGender = val),
                                          items: ['Nam', 'Nữ', 'Khác'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                        ),
                                      )
                                    : null,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                Icons.cake_outlined,
                                'Ngày sinh',
                                _isEditing
                                    ? (_selectedDOB != null ? DateFormat('dd/MM/yyyy').format(_selectedDOB!) : 'Chưa cập nhật')
                                    : (user.dateOfBirth != null ? DateFormat('dd/MM/yyyy').format(user.dateOfBirth!) : 'Chưa cập nhật'),
                                onTap: _isEditing ? () => _selectDate(context) : null,
                                trailing: _isEditing ? const Icon(Icons.calendar_today, size: 16, color: Color(0xFF438883)) : null,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                Icons.payments_outlined,
                                'Loại tiền tệ',
                                _isEditing ? null : user.currency,
                                content: _isEditing
                                    ? DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCurrency,
                                          isDense: true,
                                          onChanged: (val) => setState(() => _selectedCurrency = val),
                                          items: ['VND', 'USD', 'EUR', 'JPY'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                        ),
                                      )
                                    : null,
                              ),
                            ]),
                            const SizedBox(height: 30),

                            _buildSectionTitle('THÔNG TIN LIÊN LẠC'),
                            _buildInfoBox([
                              _buildInfoRow(Icons.email_outlined, 'Email', user.email),
                              _buildDivider(),
                              _buildInfoRow(
                                Icons.phone_outlined,
                                'Số điện thoại',
                                _isEditing ? null : (user.phone.isNotEmpty ? user.phone : 'Chưa cập nhật'),
                                content: _isEditing
                                    ? TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Nhập số điện thoại'),
                                      )
                                    : null,
                              ),
                            ]),
                            const SizedBox(height: 30),

                            if (!_isEditing) ...[
                              _buildSectionTitle('CHI TIẾT TÀI KHOẢN'),
                              _buildInfoBox([
                                _buildInfoRow(Icons.star_border, 'Loại tài khoản', user.accountType),
                                _buildDivider(),
                                _buildInfoRow(Icons.calendar_month_outlined, 'Ngày gia nhập', DateFormat('dd/MM/yyyy').format(user.joinDate)),
                              ]),
                              const SizedBox(height: 30),

                              // NÚT ĐĂNG XUẤT
                              InkWell(
                                onTap: () async {
                                  await authService.logout();
                                  if (!context.mounted) return;
                                  Navigator.pushAndRemoveUntil(context, PageTransitions.fade(const LoginScreen()), (route) => false);
                                },
                                child: Container(
                                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(30)),
                                  child: const Center(child: Text('Đăng xuất', style: TextStyle(color: Color(0xFFE63946), fontSize: 16, fontWeight: FontWeight.w600))),
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: () => setState(() => _isEditing = false),
                                child: Container(
                                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30)),
                                  child: const Center(child: Text('Hủy chỉnh sửa', style: TextStyle(color: Color(0xFF666666), fontSize: 16, fontWeight: FontWeight.w600))),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM TẠO TIÊU ĐỀ NHỎ ---
  Widget _buildSectionTitle(String title) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // --- HÀM TẠO KHUNG BO VIỀN CHỨA CÁC DÒNG ---
  Widget _buildInfoBox(List<Widget> children) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(children: children),
        );
      }
    );
  }

  // --- HÀM TẠO TỪNG DÒNG THÔNG TIN ---
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value, {
    Widget? content,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icon xanh nhạt
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF438883), size: 24),
                ),
                const SizedBox(width: 16),
                // Label và Value/Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF999999),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      content ?? Text(
                        value ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        );
      }
    );
  }

  // --- HÀM TẠO ĐƯỜNG KẺ NGANG ---
  Widget _buildDivider() {
    return Builder(
      builder: (context) => Divider(
        height: 1,
        color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF3E3E3E) 
          : const Color(0xFFF0F0F0),
        indent: 70,
        endIndent: 16,
      ),
    );
  }
}

