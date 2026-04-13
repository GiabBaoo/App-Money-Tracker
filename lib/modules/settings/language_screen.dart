import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'Tiếng Việt';

  final List<Map<String, String>> _languages = [
    {'name': 'Tiếng Việt', 'code': 'vi', 'flag': '🇻🇳'},
    {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
  ];

  @override
  Widget build(BuildContext context) {
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
                  const Text('Ngôn ngữ', 
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
                      _buildSectionTitle(context, 'CHỌN NGÔN NGỮ'),
                      _buildInfoBox(context, _languages.asMap().entries.map((e) {
                         final lang = e.value;
                         final isSelected = _selectedLanguage == lang['name'];
                         return _buildLanguageOption(
                           context,
                           title: lang['name']!,
                           flag: lang['flag']!,
                           isSelected: isSelected,
                           onTap: () => setState(() => _selectedLanguage = lang['name']!),
                           showDivider: e.key != _languages.length - 1,
                         );
                      }).toList()),
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

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required String flag,
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
                Text(flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
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
}
