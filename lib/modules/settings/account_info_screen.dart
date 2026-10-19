import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../../services/language_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/top_toast.dart';
import '../auth/login_screen.dart';
import 'avatar_crop_screen.dart';
import '../../widgets/animated_scale_button.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

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

  String _getGenderLabel(String? g, bool isVi) {
    if (g == 'Nam') return isVi ? 'Nam' : 'Male';
    if (g == 'Nữ') return isVi ? 'Nữ' : 'Female';
    return isVi ? 'Khác' : 'Other';
  }

  void _initializeControllers(UserModel user) {
    if (!_isEditing) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _selectedGender = user.gender.isNotEmpty ? user.gender : 'Nam';
      _selectedCurrency = user.currency.isNotEmpty ? user.currency : 'VND';
      _selectedDOB = user.dateOfBirth;
      _selectedImageFile = null;
      _newAvatarUrl = null;
    }
  }

  Future<void> _updateAvatarDirectly(String avatarUrl, {String? localPath}) async {
    final isVi = LanguageScope.of(context).isVietnamese;
    try {
      // 1. Cập nhật tức thì vào SQLite và phát tín hiệu cho toàn bộ UI
      await UserRepository().updateAvatar(avatarUrl, localPath: localPath);

      if (mounted) {
        setState(() {
          _selectedImageFile = null;
          _newAvatarUrl = null;
        });
        TopToast.show(
          context,
          isVi ? 'Cập nhật ảnh đại diện thành công!' : 'Profile picture updated successfully!',
        );
      }

      // 2. Đồng bộ ngầm lên Firestore & Firebase Auth mà không làm gián đoạn người dùng
      unawaited(() async {
        try {
          final updateData = <String, dynamic>{
            'avatarUrl': avatarUrl,
            'avatarLocalPath': localPath ?? '',
          };
          await FirebaseAuth.instance.currentUser?.updatePhotoURL(avatarUrl);
          await _firestoreService.updateUserProfile(updateData);
        } catch (e) {
          debugPrint('Lỗi đồng bộ avatar lên Firestore: $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Lỗi cập nhật ảnh: $e' : 'Failed to update avatar: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender ?? 'Khác',
        'currency': _selectedCurrency ?? 'VND',
        'dateOfBirth': _selectedDOB,
      };

      // 1. Luôn cập nhật vào SQLite trước để đảm bảo mượt mà và thành công ngay lập tức
      await UserRepository().updateUserProfile(updateData);

      // 2. Đồng bộ lên Firebase Auth & Firestore
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(_nameController.text.trim());
      } catch (_) {}

      try {
        await _firestoreService.updateUserProfile(updateData);
      } catch (e) {
        debugPrint('Lỗi đồng bộ hồ sơ lên Firestore: $e');
      }

      setState(() {
        _isEditing = false;
        _selectedImageFile = null;
        _newAvatarUrl = null;
        _isSaving = false;
      });

      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Cập nhật thông tin thành công!' : 'Profile updated successfully!',
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        TopToast.show(
          context,
          isVi ? 'Lỗi cập nhật: $e' : 'Update failed: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  isVi ? 'Chọn ảnh đại diện' : 'Choose Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF438883).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF438883)),
                  ),
                  title: Text(
                    isVi ? 'Chọn ảnh mẫu có sẵn (Preset)' : 'Choose preset avatar',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(isVi ? 'Bộ sưu tập icon phong cách' : 'Stylish avatar collection'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPresetPickerSheet();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                  ),
                  title: Text(
                    isVi ? 'Chụp ảnh mới' : 'Take a new photo',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.orange),
                  ),
                  title: Text(
                    isVi ? 'Chọn từ thư viện ảnh' : 'Choose from photo library',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      try {
        final XFile? pickedFile = await BiometricService.instance.runWithPickerSuspended(() async {
          return await _imagePicker.pickImage(
            source: source,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 92,
          );
        });

        if (pickedFile != null && mounted) {
          final croppedFile = await Navigator.push<File?>(
            context,
            PageTransitions.slideUp<File?>(AvatarCropScreen(imageFile: File(pickedFile.path))),
          );

          if (croppedFile != null && mounted) {
            // Cập nhật ngay tức thì bằng file đã crop
            await _updateAvatarDirectly(croppedFile.path, localPath: croppedFile.path);

            setState(() => _isUploadingImage = true);

            // Upload ngầm lên Firebase Storage & cập nhật Firestore
            unawaited(() async {
              try {
                final downloadUrl = await _storageService.uploadAvatar(croppedFile);
                final updateData = <String, dynamic>{
                  'avatarUrl': downloadUrl,
                  'avatarLocalPath': croppedFile.path,
                };
                await FirebaseAuth.instance.currentUser?.updatePhotoURL(downloadUrl);
                await _firestoreService.updateUserProfile(updateData);
                await UserRepository().updateAvatar(downloadUrl, localPath: croppedFile.path);
              } catch (e) {
                debugPrint('Lỗi upload avatar lên Firebase Storage: $e');
              } finally {
                if (mounted) setState(() => _isUploadingImage = false);
              }
            }());
          }
        }
      } catch (e) {
        if (mounted) {
          TopToast.show(
            context,
            isVi ? 'Lỗi chọn ảnh: $e' : 'Error choosing photo: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _showPresetPickerSheet() {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Chọn ảnh đại diện mẫu' : 'Choose Preset Avatar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: UserAvatar.presetAvatars.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final preset = UserAvatar.presetAvatars[index];
                    final isSelected = _newAvatarUrl == preset.id;

                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _updateAvatarDirectly(preset.id, localPath: '');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: preset.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: isSelected ? Border.all(color: const Color(0xFF438883), width: 3) : null,
                              boxShadow: [
                                BoxShadow(
                                  color: preset.gradient[0].withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(preset.icon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF438883)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDarkPicker = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDarkPicker
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF438883),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
                )
              : Theme.of(context).copyWith(
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

  void _showLogoutDialog() {
    final nav = Navigator.of(context);
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3E2020) : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              isVi ? 'Đăng xuất tài khoản' : 'Log Out Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn đăng xuất khỏi Mono không? Dữ liệu chưa đồng bộ sẽ được lưu an toàn trên máy.'
              : 'Are you sure you want to log out from Mono? Unsynced data will remain safely stored on your device.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _authService.logout();
              nav.pushAndRemoveUntil(PageTransitions.fade(const LoginScreen()), (route) => false);
            },
            child: Text(isVi ? 'Đăng xuất' : 'Log Out', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  Text(
                    isVi ? 'Thông tin tài khoản' : 'Account Info',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_isEditing)
                    AnimatedScaleButton(
                      onTap: () {
                        if (_isSaving) return;
                        HapticFeedback.lightImpact();
                        _saveProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF438883)),
                              )
                            : Text(
                                isVi ? 'Lưu' : 'Save',
                                style: const TextStyle(
                                  color: Color(0xFF438883),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    )
                  else
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isEditing = true);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Main Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<UserModel?>(
                  initialData: UserRepository().currentUser,
                  stream: UserRepository().getUserStream(),
                  builder: (context, snapshot) {
                    final user = snapshot.data ?? UserRepository().currentUser;
                    if (user == null) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }
                    _initializeControllers(user);

                    return Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hero Profile Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Avatar with Camera / Edit Overlay
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF63B3AB), Color(0xFF438883)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF438883).withValues(alpha: 0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: UserAvatar(
                                          radius: 44,
                                          name: user.name,
                                          avatarUrl: _newAvatarUrl ?? user.avatarUrl,
                                          avatarLocalPath: _selectedImageFile != null
                                              ? _selectedImageFile!.path
                                              : (_newAvatarUrl != null ? null : user.avatarLocalPath),
                                          showBorder: false,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF438883),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                      if (_isUploadingImage)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // User Name
                                  if (_isEditing)
                                    TextFormField(
                                      controller: _nameController,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                      ),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        hintText: isVi ? 'Nhập họ và tên...' : 'Enter full name...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF438883)),
                                        ),
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? (isVi ? 'Tên không được để trống' : 'Name cannot be empty') : null,
                                    )
                                  else
                                    Text(
                                      user.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  const SizedBox(height: 8),

                                  // UID badge & copy button
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: user.uid));
                                      TopToast.show(context, isVi ? 'Đã sao chép mã tài khoản vào bộ nhớ tạm' : 'Account ID copied to clipboard');
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'ID: ${user.uid.length > 8 ? user.uid.substring(0, 8).toUpperCase() : user.uid}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.copy_rounded,
                                            size: 13,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Group 1: THÔNG TIN CÁ NHÂN
                            _buildSectionHeader(isVi ? 'THÔNG TIN CÁ NHÂN' : 'PERSONAL INFORMATION'),
                            _buildCardContainer(
                              isDark: isDark,
                              children: [
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.badge_outlined,
                                  title: isVi ? 'Họ và tên' : 'Full Name',
                                  value: _isEditing ? null : user.name,
                                  customWidget: _isEditing
                                      ? TextFormField(
                                          controller: _nameController,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            hintText: isVi ? 'Nhập họ tên' : 'Enter name',
                                          ),
                                        )
                                      : null,
                                ),
                                _buildDivider(isDark),
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.wc_outlined,
                                  title: isVi ? 'Giới tính' : 'Gender',
                                  value: _isEditing ? null : _getGenderLabel(_selectedGender ?? user.gender, isVi),
                                  customWidget: _isEditing
                                      ? DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedGender,
                                            isDense: true,
                                            items: ['Nam', 'Nữ', 'Khác'].map((s) => DropdownMenuItem(value: s, child: Text(_getGenderLabel(s, isVi)))).toList(),
                                            onChanged: (val) => setState(() => _selectedGender = val),
                                          ),
                                        )
                                      : null,
                                ),
                                _buildDivider(isDark),
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.cake_outlined,
                                  title: isVi ? 'Ngày sinh' : 'Date of Birth',
                                  value: _selectedDOB != null
                                      ? DateFormat('dd/MM/yyyy').format(_selectedDOB!)
                                      : (isVi ? 'Chưa cập nhật' : 'Not updated'),
                                  trailingIcon: _isEditing ? Icons.calendar_today_rounded : null,
                                  onTap: _isEditing ? () => _selectDate(context) : null,
                                ),
                                _buildDivider(isDark),
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.currency_exchange_rounded,
                                  title: isVi ? 'Loại tiền tệ' : 'Currency',
                                  value: _isEditing ? null : (_selectedCurrency ?? user.currency),
                                  customWidget: _isEditing
                                      ? DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedCurrency,
                                            isDense: true,
                                            items: ['VND', 'USD', 'EUR', 'JPY']
                                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                                .toList(),
                                            onChanged: (val) => setState(() => _selectedCurrency = val),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Group 2: THÔNG TIN LIÊN LẠC
                            _buildSectionHeader(isVi ? 'THÔNG TIN LIÊN LẠC' : 'CONTACT INFORMATION'),
                            _buildCardContainer(
                              isDark: isDark,
                              children: [
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.alternate_email_rounded,
                                  title: 'Email',
                                  value: user.email,
                                  badge: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF438883).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isVi ? 'Đã xác thực' : 'Verified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF438883),
                                      ),
                                    ),
                                  ),
                                ),
                                _buildDivider(isDark),
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.phone_android_rounded,
                                  title: isVi ? 'Số điện thoại' : 'Phone Number',
                                  value: _isEditing ? null : (user.phone.isNotEmpty ? user.phone : (isVi ? 'Chưa cập nhật' : 'Not updated')),
                                  customWidget: _isEditing
                                      ? TextFormField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            hintText: isVi ? 'Nhập số điện thoại' : 'Enter phone number',
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Group 3: CHI TIẾT TÀI KHOẢN
                            _buildSectionHeader(isVi ? 'CHI TIẾT TÀI KHOẢN' : 'ACCOUNT DETAILS'),
                            _buildCardContainer(
                              isDark: isDark,
                              children: [
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.verified_user_outlined,
                                  title: isVi ? 'Loại tài khoản' : 'Account Type',
                                  value: user.accountType.isNotEmpty ? (user.accountType == 'Miễn phí' ? (isVi ? 'Miễn phí' : 'Free') : user.accountType) : (isVi ? 'Miễn phí' : 'Free'),
                                ),
                                _buildDivider(isDark),
                                _buildSettingRow(
                                  isDark: isDark,
                                  icon: Icons.calendar_month_rounded,
                                  title: isVi ? 'Ngày gia nhập' : 'Join Date',
                                  value: DateFormat('dd/MM/yyyy').format(user.joinDate),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Actions
                            if (_isEditing) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF438883),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                  ),
                                  child: _isSaving
                                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      : Text(
                                          isVi ? 'Lưu thay đổi' : 'Save Changes',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _isEditing = false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(
                                    isVi ? 'Hủy chỉnh sửa' : 'Cancel Editing',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: _showLogoutDialog,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.logout_rounded, color: Color(0xFFE63946), size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          isVi ? 'Đăng xuất' : 'Log Out',
                                          style: TextStyle(
                                            color: Color(0xFFE63946),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow({
    required bool isDark,
    required IconData icon,
    required String title,
    String? value,
    Widget? customWidget,
    Widget? badge,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF438883), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  customWidget ??
                      Text(
                        value ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                ],
              ),
            ),
            ?badge,
            if (trailingIcon != null)
              Icon(trailingIcon, size: 18, color: const Color(0xFF438883)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF3F4F6),
    );
  }
}
