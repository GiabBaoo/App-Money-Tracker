import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/page_transitions.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/biometric_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../auth/login_screen.dart';

// Screens
import 'account_info_screen.dart';
import 'security_screen.dart';
import 'privacy_screen.dart';
import 'message_center_screen.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'notification_settings_screen.dart';
import 'dart:async';
import 'avatar_crop_screen.dart';
import 'about_app_screen.dart';
import 'ai_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUploadingAvatar = false;

  // ════════ XỬ LÝ ĐĂNG XUẤT ════════
  Future<void> _handleLogout(BuildContext context) async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final isVi = languageService.isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              isVi ? 'Đăng xuất' : 'Log out',
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
              ? 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?'
              : 'Are you sure you want to log out of this account?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              isVi ? 'Đăng xuất' : 'Log out',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService().logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageTransitions.fade(const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // ════════ CHỌN & ĐỔI AVATAR TRỰC TIẾP ════════
  Future<void> _showAvatarPickerSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = Provider.of<LanguageService>(context, listen: false).isVietnamese;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                isVi ? 'Thay đổi ảnh đại diện' : 'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              // Chọn ảnh mẫu preset
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF438883).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF438883)),
                ),
                title: Text(
                  isVi ? 'Chọn ảnh mẫu có sẵn (Preset)' : 'Choose Preset Avatar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  isVi ? 'Bộ sưu tập avatar phong cách gradient' : 'Stylish gradient icons',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showPresetPickerSheet(context);
                },
              ),

              // Chụp ảnh mới
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                ),
                title: Text(
                  isVi ? 'Chụp ảnh mới' : 'Take a photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),

              // Chọn từ thư viện ảnh
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.orange),
                ),
                title: Text(
                  isVi ? 'Chọn từ thư viện ảnh' : 'Choose from gallery',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetPickerSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = Provider.of<LanguageService>(context, listen: false).isVietnamese;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi ? 'Chọn ảnh mẫu đại diện' : 'Select Preset Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                itemCount: UserAvatar.presetAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final preset = UserAvatar.presetAvatars[index];
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _applyAvatarUrl(preset.id, localPath: '');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: preset.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: preset.gradient.first.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(preset.icon, color: Colors.white, size: 28),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? picked = await BiometricService.instance.runWithPickerSuspended(() async {
        return await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 92,
        );
      });
      if (picked == null) return;

      if (!mounted) return;
      final croppedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => AvatarCropScreen(imageFile: File(picked.path)),
        ),
      );
      if (croppedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      // 1. Phản hồi tức thì trên giao diện (Zero-latency) bằng file đã căn chỉnh
      await UserRepository().updateAvatar(croppedFile.path, localPath: croppedFile.path);

      if (mounted) {
        TopToast.show(context, 'Cập nhật ảnh đại diện thành công!');
      }

      // 2. Tải ngầm lên Firebase Storage & đồng bộ Firestore mà không làm gián đoạn người dùng
      unawaited(() async {
        try {
          final downloadUrl = await _storageService.uploadAvatar(croppedFile);
          await _applyAvatarUrl(downloadUrl, localPath: croppedFile.path);
        } catch (e) {
          debugPrint('Lỗi upload avatar lên Firebase: $e');
        }
      }());
    } catch (e) {
      if (mounted) {
        TopToast.show(context, 'Lỗi cập nhật ảnh: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _applyAvatarUrl(String avatarUrl, {String? localPath}) async {
    final updateData = <String, dynamic>{
      'avatarUrl': avatarUrl,
      'avatarLocalPath': localPath ?? '',
    };

    try {
      // 1. Cập nhật Firebase Auth
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(avatarUrl);
    } catch (_) {}

    try {
      // 2. Cập nhật Firestore
      await FirestoreService().updateUserProfile(updateData);
    } catch (_) {}

    // 3. Cập nhật SQLite và phát signal cho toàn bộ giao diện
    await UserRepository().updateAvatar(avatarUrl, localPath: localPath);
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = languageService.isVietnamese;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final headerColor = isDark ? const Color(0xFF0F2625) : const Color(0xFF438883);

    return Scaffold(
      backgroundColor: headerColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── 1. TOP APP BAR (ĐỒNG BỘ VÍ TIỀN & TRANG CHỦ) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi ? 'Cài đặt & Hồ sơ' : 'Profile & Settings',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      // Nút Hòm thư tin nhắn
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(context, PageTransitions.slideRight(const MessageCenterScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Chỉnh sửa thông tin nhanh
                      AnimatedScaleButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(context, PageTransitions.slideRight(const AccountInfoScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── 2. HERO PROFILE CARD (TƯƠNG ĐỒNG NET WORTH CARD TRANG VÍ) ───
            StreamBuilder<UserModel?>(
              initialData: UserRepository().currentUser,
              stream: UserRepository().getUserStream(),
              builder: (context, snapshot) {
                final user = snapshot.data ?? UserRepository().currentUser;
                final authUser = FirebaseAuth.instance.currentUser;
                final fallbackName = authUser?.displayName ??
                    (authUser?.email?.split('@').first ?? (isVi ? 'Người dùng' : 'User'));
                final displayName = (user?.name != null && user!.name.trim().isNotEmpty)
                    ? user.name
                    : fallbackName;
                final displayEmail = (user?.email != null && user!.email.trim().isNotEmpty)
                    ? user.email
                    : (authUser?.email ?? '');
                final displayAvatarUrl = (user?.avatarUrl != null && user!.avatarUrl.trim().isNotEmpty)
                    ? user.avatarUrl
                    : authUser?.photoURL;
                final avatarLocalPath = user?.avatarLocalPath;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(context, PageTransitions.slideRight(const AccountInfoScreen()));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF163230) : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar với camera badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              UserAvatar(
                                radius: 34,
                                name: displayName,
                                avatarUrl: displayAvatarUrl,
                                avatarLocalPath: avatarLocalPath,
                                showBorder: true,
                                borderColor: Colors.white.withValues(alpha: 0.6),
                                borderWidth: 2.5,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showAvatarPickerSheet(context);
                                },
                              ),
                              if (_isUploadingAvatar)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _showAvatarPickerSheet(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(5.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF438883),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 15),
                          // Name, Email, Status Badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayEmail.isNotEmpty ? displayEmail : (isVi ? 'Chưa liên kết email' : 'No email linked'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_user_rounded, color: Color(0xFF68AEA9), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            isVi ? 'Tài khoản Mono' : 'Mono Member',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        user?.currency.isNotEmpty == true ? user!.currency : 'VND',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Arrow forward
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ─── 3. PHẦN THÂN: KHỐI CHUYỂN TIẾP BO TRÒN (RADIUS 30) ───
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── NHÓM 1: TÀI KHOẢN & BẢO MẬT ───
                        _buildSectionHeader(isVi ? 'TÀI KHOẢN & BẢO MẬT' : 'ACCOUNT & SECURITY', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildMenuItem(
                                context: context,
                                icon: Icons.shield_outlined,
                                title: context.tr('login_and_security'),
                                subtitle: isVi ? 'Vân tay sinh trắc học, đổi mật khẩu' : 'Biometrics, change password',
                                badgeText: isVi ? 'Bảo vệ' : 'Secure',
                                badgeColor: const Color(0xFF438883),
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const SecurityScreen())),
                                showDivider: true,
                              ),
                              _buildMenuItem(
                                context: context,
                                icon: Icons.cloud_sync_outlined,
                                title: context.tr('data_and_privacy'),
                                subtitle: isVi ? 'Đồng bộ đám mây, sao lưu dữ liệu' : 'Cloud sync, data backup',
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const PrivacyScreen())),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── NHÓM 2: TRẢI NGHIỆM & TRỢ LÝ ───
                        _buildSectionHeader(isVi ? 'TRẢI NGHIỆM & TRỢ LÝ' : 'PREFERENCES & AI', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildMenuItem(
                                context: context,
                                icon: Icons.auto_awesome_rounded,
                                title: 'Trợ lý Mono (AI)',
                                subtitle: isVi ? 'Gợi ý tài chính thông minh Gemini' : 'Smart financial AI assistant',
                                badgeText: 'AI Gemini',
                                badgeGradient: const [Color(0xFF7928CA), Color(0xFF2A5298)],
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const AiSettingsScreen())),
                                showDivider: true,
                              ),
                              _buildMenuItem(
                                context: context,
                                icon: Icons.palette_outlined,
                                title: context.tr('appearance_dark_mode'),
                                subtitle: isVi ? 'Chế độ sáng, tối hoặc theo hệ thống' : 'Light, dark, system theme',
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const AppearanceScreen())),
                                showDivider: true,
                              ),
                              _buildMenuItem(
                                context: context,
                                icon: Icons.language_rounded,
                                title: context.tr('language_setting'),
                                subtitle: isVi ? 'Chọn ngôn ngữ hiển thị' : 'Choose app display language',
                                badgeText: isVi ? 'Tiếng Việt' : 'English',
                                badgeColor: const Color(0xFF0077B6),
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const LanguageScreen())),
                                showDivider: true,
                              ),
                              _buildMenuItem(
                                context: context,
                                icon: Icons.notifications_none_rounded,
                                title: context.tr('notification_title'),
                                subtitle: isVi ? 'Nhắc nhở ghi chép 20h hằng ngày' : 'Daily reminder at 8 PM',
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const NotificationSettingsScreen())),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── NHÓM 3: HỆ THỐNG & HỖ TRỢ ───
                        _buildSectionHeader(isVi ? 'HỆ THỐNG & HỖ TRỢ' : 'SYSTEM & SUPPORT', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildMenuItem(
                                context: context,
                                icon: Icons.mail_outline_rounded,
                                title: context.tr('message_center'),
                                subtitle: isVi ? 'Hộp thư tin tức và thông báo' : 'Notifications and messages',
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const MessageCenterScreen())),
                                showDivider: true,
                              ),
                              _buildMenuItem(
                                context: context,
                                icon: Icons.info_outline_rounded,
                                title: isVi ? 'Về ứng dụng Mono' : 'About Mono App',
                                subtitle: isVi ? 'Thông tin phiên bản, điều khoản' : 'Version info, policy terms',
                                badgeText: 'v1.0.0',
                                badgeColor: Colors.grey.shade600,
                                onTap: () => Navigator.push(context, PageTransitions.slideRight(const AboutAppScreen())),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ─── NÚT ĐĂNG XUẤT AN TOÀN ───
                        Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _handleLogout(context),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF3E2020) : const Color(0xFFFDE8E8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFE53935),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      isVi ? 'Đăng xuất' : 'Log out',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFE53935),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    String? badgeText,
    Color? badgeColor,
    List<Color>? badgeGradient,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFF1F5F4);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Squircle Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F6F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF438883),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Optional Badge Pill
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: badgeGradient == null ? (badgeColor ?? const Color(0xFF438883)).withValues(alpha: 0.12) : null,
                      gradient: badgeGradient != null
                          ? LinearGradient(colors: badgeGradient)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeGradient != null ? Colors.white : (badgeColor ?? const Color(0xFF438883)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Trailing Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 70,
            endIndent: 16,
            color: dividerColor,
          ),
      ],
    );
  }
}
