import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/mono_dialog.dart';
import '../../widgets/mono_liquid_glass_logo.dart';
import 'privacy_policy_screen.dart';
import 'support_request_screen.dart';
import '../../services/language_service.dart';
import '../../core/theme/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final ver = info.version.trim().replaceAll('+', '.');
      final build = info.buildNumber.trim();
      if (ver.isNotEmpty && build.isNotEmpty) {
        if (!ver.endsWith('.$build')) {
          return '$ver.$build';
        }
        return ver;
      } else if (ver.isNotEmpty) {
        return ver;
      }
      return AppConstants.appVersionFull;
    } catch (_) {
      return AppConstants.appVersionFull;
    }
  }

  void _showRatingDialog(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final commentController = TextEditingController();
    int selectedRating = 5;
    bool isSubmitting = false;

    MonoDialog.showCustom(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) => MonoDialogContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isVi ? 'Đánh giá Mono' : 'Rate Mono',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isVi
                    ? 'Bạn cảm thấy trải nghiệm sử dụng Mono như thế nào?'
                    : 'How do you feel about your experience using Mono?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB800),
                      size: 34,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () =>
                              setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: commentController,
                maxLines: 3,
                minLines: 2,
                enabled: !isSubmitting,
                style: TextStyle(fontSize: 13, color: context.colors.onSurface),
                decoration: InputDecoration(
                  hintText: isVi
                      ? 'Gửi thêm góp ý để nhóm phát triển cải thiện app nhé...'
                      : 'Share your feedback to help us improve...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  filled: true,
                  fillColor: context.cardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.brandColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: context.borderColor),
                      ),
                      child: Text(
                        isVi ? 'Để sau' : 'Later',
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setDialogState(() => isSubmitting = true);
                              final comment = commentController.text.trim();
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                final uid = user?.uid ?? 'anonymous';
                                await FirebaseFirestore.instance
                                    .collection('app_reviews')
                                    .add({
                                      'uid': uid,
                                      'rating': selectedRating,
                                      'comment': comment,
                                      'userEmail': user?.email ?? '',
                                      'platform': defaultTargetPlatform.name,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool('has_rated_app', true);
                              } catch (e) {
                                debugPrint('Error recording app review: $e');
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                TopToast.show(
                                  context,
                                  isVi
                                      ? 'Cảm ơn bạn đã gửi đánh giá $selectedRating sao cho Mono! ❤️'
                                      : 'Thank you for rating Mono $selectedRating stars! ❤️',
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isVi ? 'Gửi đánh giá' : 'Submit',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final message = isVi
        ? '1. Chấp thuận điều khoản: Bằng việc sử dụng Mono, bạn đồng ý với các quy định về lưu trữ và bảo mật dữ liệu.\n\n'
              '2. Quyền riêng tư: Mọi thông tin thu chi cá nhân thuộc quyền sở hữu riêng của bạn và được bảo vệ theo chuẩn mã hóa cao nhất.\n\n'
              '3. Tính sẵn sàng: Hệ thống hỗ trợ làm việc ngoại tuyến (Offline SQLite) và tự động đồng bộ khi có kết nối Internet.\n\n'
              '4. Trợ lý AI: Tính năng AI Gemini hỗ trợ phân tích và gợi ý quản lý chi tiêu mang tính chất tham khảo hữu ích cho kế hoạch tài chính của bạn.'
        : '1. Acceptance of Terms: By using Mono, agree to the provisions on data storage and security.\n\n'
              '2. Privacy: All personal financial data belongs solely to you and is protected under the highest encryption standards.\n\n'
              '3. Availability: The app supports offline operations (SQLite) and synchronizes seamlessly when Internet is restored.\n\n'
              '4. AI Assistant: AI insights provide helpful financial suggestions for reference in your personal financial planning.';

    MonoDialog.alert(
      context,
      title: isVi ? 'Điều khoản dịch vụ' : 'Terms of Service',
      message: message,
      buttonText: isVi ? 'Đã hiểu' : 'Understood',
      icon: Icons.description_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isVi ? 'Về ứng dụng' : 'About App',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content Body
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // App Identity Hero Box
                      const Center(
                        child: MonoLiquidGlassLogo.badge(
                          size: 96,
                          isInteractive: true,
                          animatedSheen: true,
                          hasShadow: true,
                          hasGlow: true,
                          borderRadius: BorderRadius.all(Radius.circular(26)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mono Expense Tracker',
                        style: TextStyle(
                          color: context.colors.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVi
                            ? 'Quản lý chi tiêu thông minh & cá nhân hóa'
                            : 'Smart & personalized expense management',
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Version Badge
                      FutureBuilder<String>(
                        future: _getAppVersion(),
                        builder: (context, snapshot) {
                          final versionStr =
                              snapshot.data ?? AppConstants.appVersionFull;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: context.brandColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.brandColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: context.brandColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isVi
                                      ? 'Phiên bản $versionStr (Mới nhất)'
                                      : 'Version $versionStr (Latest)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.brandColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      // Khối cập nhật Liquid Glass v2.0
                      _buildVersion2ChangelogCard(context, isDark, isVi),
                      const SizedBox(height: 22),

                      // Feature Highlights Grid
                      _buildFeaturesGrid(context, isDark, isVi),
                      const SizedBox(height: 24),

                      // Information & Links
                      _buildCardContainer(
                        context,
                        children: [
                          _buildAboutRow(
                            context,
                            icon: Icons.privacy_tip_outlined,
                            title: isVi
                                ? 'Chính sách bảo mật'
                                : 'Privacy Policy',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                const PrivacyPolicyScreen(),
                              ),
                            ),
                          ),
                          _buildDivider(context),
                          _buildAboutRow(
                            context,
                            icon: Icons.description_outlined,
                            title: isVi
                                ? 'Điều khoản dịch vụ'
                                : 'Terms of Service',
                            onTap: () => _showTermsDialog(context),
                          ),
                          _buildDivider(context),
                          _buildAboutRow(
                            context,
                            icon: Icons.star_outline_rounded,
                            title: isVi
                                ? 'Đánh giá ứng dụng'
                                : 'Rate Application',
                            onTap: () => _showRatingDialog(context),
                          ),
                          _buildDivider(context),
                          _buildAboutRow(
                            context,
                            icon: Icons.support_agent_rounded,
                            title: isVi
                                ? 'Liên hệ & Phản hồi hỗ trợ'
                                : 'Contact & Support',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(
                                const SupportRequestScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Footer
                      Text(
                        isVi
                            ? 'Phát triển với ❤️ bởi Nhóm Mono\nBản quyền © 2024 - 2026. Tất cả các quyền được bảo lưu.'
                            : 'Developed with ❤️ by Mono Team\nCopyright © 2024 - 2026. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.5,
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

  Widget _buildFeaturesGrid(BuildContext context, bool isDark, bool isVi) {
    final features = [
      {
        'icon': Icons.sync_rounded,
        'title': isVi ? 'Đồng bộ 2 chiều' : '2-Way Sync',
        'desc': 'Offline SQLite & Cloud',
      },
      {
        'icon': Icons.security_rounded,
        'title': isVi ? 'Bảo mật tuyệt đối' : 'High Security',
        'desc': isVi ? 'Mã hóa tài khoản an toàn' : 'Safe encryption',
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': isVi ? 'Trợ lý Mono AI' : 'Mono AI Assistant',
        'desc': isVi ? 'Phân tích tài chính thông minh' : 'Smart insights',
      },
      {
        'icon': Icons.pie_chart_outline_rounded,
        'title': isVi ? 'Báo cáo chi tiết' : 'Detailed Reports',
        'desc': isVi ? 'Biểu đồ trực quan sinh động' : 'Interactive charts',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.1,
      ),
      itemBuilder: (context, index) {
        final f = features[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  f['icon'] as IconData,
                  size: 18,
                  color: context.brandColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      f['title'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f['desc'] as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVersion2ChangelogCard(
    BuildContext context,
    bool isDark,
    bool isVi,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? context.cardBg : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.brandColor.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.brandColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: context.brandColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: context.brandColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.appReleaseName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isVi
                ? AppConstants.appReleaseDescriptionVi
                : AppConstants.appReleaseDescriptionEn,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFeaturePill(context, isDark, '💎 Liquid Glass Logo'),
              _buildFeaturePill(context, isDark, '⚡ 60fps Launch Sheen'),
              _buildFeaturePill(context, isDark, '🌙 Deep OLED Dark Mode'),
              _buildFeaturePill(context, isDark, '🚀 2.0 Engine'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(BuildContext context, bool isDark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.brandColor.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.brandColor,
        ),
      ),
    );
  }

  Widget _buildCardContainer(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.3 : 0.02,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAboutRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
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
                color: context.brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.brandColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: context.dividerColor,
    );
  }
}
