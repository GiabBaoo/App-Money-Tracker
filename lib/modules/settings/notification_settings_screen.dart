import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _remindersEnabled = true;
  bool _weeklyReportsEnabled = true;
  bool _newsEnabled = false;

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
                  const Text('Thông báo', 
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
                      _buildSectionTitle(context, 'CÀI ĐẶT THÔNG BÁO'),
                      _buildInfoBox(context, [
                        _buildToggleRow(
                          context,
                          icon: Icons.notifications_active_outlined,
                          title: 'Nhắc nhở ghi chép',
                          subtitle: 'Nhắc bạn ghi lại giao dịch mỗi ngày',
                          value: _remindersEnabled,
                          onChanged: (val) => setState(() => _remindersEnabled = val),
                          showDivider: true,
                        ),
                        _buildToggleRow(
                          context,
                          icon: Icons.assignment_outlined,
                          title: 'Báo cáo hàng tuần',
                          subtitle: 'Gửi báo cáo tổng quát vào cuối tuần',
                          value: _weeklyReportsEnabled,
                          onChanged: (val) => setState(() => _weeklyReportsEnabled = val),
                          showDivider: true,
                        ),
                        _buildToggleRow(
                          context,
                          icon: Icons.campaign_outlined,
                          title: 'Tin tức & Ưu đãi',
                          subtitle: 'Cập nhật tính năng mới và chương trình',
                          value: _newsEnabled,
                          onChanged: (val) => setState(() => _newsEnabled = val),
                          showDivider: false,
                        ),
                      ]),
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

  Widget _buildToggleRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
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
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF438883),
                activeTrackColor: const Color(0xFF438883).withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFF0F0F0), indent: 64, endIndent: 16),
      ],
    );
  }
}
