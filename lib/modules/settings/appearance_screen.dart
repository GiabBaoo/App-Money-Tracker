import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  const Text('Giao diện & Chế độ tối', 
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'CHẾ ĐỘ MÀU SẮC'),
                      _buildInfoBox(context, [
                        _buildThemeOption(
                          context,
                          title: 'Chế độ Sáng',
                          subtitle: 'Phù hợp với môi trường ánh sáng mạnh',
                          icon: Icons.light_mode_outlined,
                          isSelected: themeService.themeMode == ThemeMode.light,
                          onTap: () => themeService.setThemeMode(ThemeMode.light),
                          showDivider: true,
                        ),
                        _buildThemeOption(
                          context,
                          title: 'Chế độ Tối',
                          subtitle: 'Giảm mỏi mắt trong bóng tối',
                          icon: Icons.dark_mode_outlined,
                          isSelected: themeService.themeMode == ThemeMode.dark,
                          onTap: () => themeService.setThemeMode(ThemeMode.dark),
                          showDivider: true,
                        ),
                        _buildThemeOption(
                          context,
                          title: 'Theo hệ thống',
                          subtitle: 'Tự động đồng bộ với máy',
                          icon: Icons.settings_brightness_outlined,
                          isSelected: themeService.themeMode == ThemeMode.system,
                          onTap: () => themeService.setThemeMode(ThemeMode.system),
                          showDivider: false,
                        ),
                      ]),
                      const SizedBox(height: 30),
                      _buildSectionTitle(context, 'XEM TRƯỚC GIAO DIỆN'),
                      _buildThemePreviews(context, themeService.themeMode),
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

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
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
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (isSelected) 
                  const Icon(Icons.check_circle, color: Color(0xFF438883), size: 24),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 64, endIndent: 16),
      ],
    );
  }

  Widget _buildThemePreviews(BuildContext context, ThemeMode mode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPreviewImage(context, 'Light', 'assets/images/light_preview.png', mode == ThemeMode.light),
          const SizedBox(width: 16),
          _buildPreviewImage(context, 'Dark', 'assets/images/dark_preview.png', mode == ThemeMode.dark),
          const SizedBox(width: 16),
          _buildPreviewImage(context, 'System', 'assets/images/system_preview.png', mode == ThemeMode.system),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(BuildContext context, String label, String imagePath, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 100, height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF438883) : Colors.transparent, width: 3),
            color: label == 'Dark' ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
              children: [
                Container(height: 30, color: label == 'Dark' ? const Color(0xFF0F2625) : const Color(0xFF438883)),
                const Expanded(child: Center(child: Icon(Icons.dashboard_outlined, size: 30, color: Colors.grey))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white70 : Colors.black54)),
      ],
    );
  }
}
