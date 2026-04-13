import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import 'appearance_screen.dart';
import 'notification_settings_screen.dart';
import 'language_screen.dart';
import 'about_app_screen.dart';
import '../../utils/page_transitions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Cài đặt', 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                  children: [
                    _buildSectionTitle(context, 'TÙY CHỈNH CÁ NHÂN'),
                    _buildInfoBox(context, [
                      _buildSettingsItem(
                        context,
                        icon: Icons.palette_outlined,
                        title: 'Giao diện & Chế độ tối',
                        subtitle: _getThemeModeText(themeService.themeMode),
                        onTap: () => Navigator.push(context, PageTransitions.slideRight(const AppearanceScreen())),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 30),
                    _buildSectionTitle(context, 'ỨNG DỤNG'),
                    _buildInfoBox(context, [
                      _buildSettingsItem(
                        context,
                        icon: Icons.notifications_none_rounded,
                        title: 'Thông báo',
                        subtitle: 'Cài đặt nhắc nhở chi tiêu',
                        onTap: () => Navigator.push(context, PageTransitions.slideRight(const NotificationSettingsScreen())),
                        showDivider: true,
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.language_rounded,
                        title: 'Ngôn ngữ',
                        subtitle: 'Tiếng Việt',
                        onTap: () => Navigator.push(context, PageTransitions.slideRight(const LanguageScreen())),
                        showDivider: true,
                      ),
                      _buildSettingsItem(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: 'Về ứng dụng',
                        subtitle: 'Phiên bản 1.0.0',
                        onTap: () => Navigator.push(context, PageTransitions.slideRight(const AboutAppScreen())),
                        showDivider: false,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'Chế độ sáng';
      case ThemeMode.dark: return 'Chế độ tối';
      case ThemeMode.system: return 'Theo hệ thống';
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
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
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> children) {
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

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF438883), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 64, endIndent: 16),
      ],
    );
  }
}
