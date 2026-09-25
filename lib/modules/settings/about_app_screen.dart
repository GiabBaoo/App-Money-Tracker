import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/top_toast.dart';
import 'privacy_policy_screen.dart';
import 'support_request_screen.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  void _showRatingDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int selectedRating = 5;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
          title: Text(
            'Đánh giá Mono',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bạn cảm thấy trải nghiệm sử dụng Mono như thế nào?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCBD5E1) : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB800),
                      size: 34,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Để sau', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF438883),
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                TopToast.show(context, 'Cảm ơn bạn đã đánh giá $selectedRating sao cho Mono! ❤️');
              },
              child: const Text('Gửi đánh giá', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
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
        title: Text(
          'Điều khoản dịch vụ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            '1. Chấp thuận điều khoản: Bằng việc sử dụng Mono, bạn đồng ý với các quy định về lưu trữ và bảo mật dữ liệu.\n\n'
            '2. Quyền riêng tư: Mọi thông tin thu chi cá nhân thuộc quyền sở hữu riêng của bạn và được bảo vệ theo chuẩn mã hóa cao nhất.\n\n'
            '3. Tính sẵn sàng: Hệ thống hỗ trợ làm việc ngoại tuyến (Offline SQLite) và tự động đồng bộ khi có kết nối Internet.\n\n'
            '4. Trợ lý AI: Tính năng AI Gemini hỗ trợ phân tích và gợi ý quản lý chi tiêu mang tính chất tham khảo hữu ích cho kế hoạch tài chính của bạn.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF438883),
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
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
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Về ứng dụng',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      // App Identity Hero Box
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5AB4AC), Color(0xFF387A75)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 46),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mono Expense Tracker',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý chi tiêu thông minh & cá nhân hóa',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Version Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF438883).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF438883)),
                            SizedBox(width: 6),
                            Text(
                              'Phiên bản 1.0.0 (Mới nhất)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF438883),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Feature Highlights Grid
                      _buildFeaturesGrid(isDark),
                      const SizedBox(height: 24),

                      // Information & Links
                      _buildCardContainer(
                        isDark: isDark,
                        children: [
                          _buildAboutRow(
                            isDark: isDark,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Chính sách bảo mật',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const PrivacyPolicyScreen()),
                            ),
                          ),
                          _buildDivider(isDark),
                          _buildAboutRow(
                            isDark: isDark,
                            icon: Icons.description_outlined,
                            title: 'Điều khoản dịch vụ',
                            onTap: () => _showTermsDialog(context),
                          ),
                          _buildDivider(isDark),
                          _buildAboutRow(
                            isDark: isDark,
                            icon: Icons.star_outline_rounded,
                            title: 'Đánh giá ứng dụng',
                            onTap: () => _showRatingDialog(context),
                          ),
                          _buildDivider(isDark),
                          _buildAboutRow(
                            isDark: isDark,
                            icon: Icons.support_agent_rounded,
                            title: 'Liên hệ & Phản hồi hỗ trợ',
                            onTap: () => Navigator.push(
                              context,
                              PageTransitions.slideRight(const SupportRequestScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Footer
                      Text(
                        'Phát triển với ❤️ bởi Nhóm Mono\nBản quyền © 2024 - 2026. Tất cả các quyền được bảo lưu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
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

  Widget _buildFeaturesGrid(bool isDark) {
    final features = [
      {'icon': Icons.sync_rounded, 'title': 'Đồng bộ 2 chiều', 'desc': 'Offline SQLite & Cloud'},
      {'icon': Icons.security_rounded, 'title': 'Bảo mật tuyệt đối', 'desc': 'Mã hóa tài khoản an toàn'},
      {'icon': Icons.auto_awesome_rounded, 'title': 'Trợ lý Mono AI', 'desc': 'Phân tích tài chính thông minh'},
      {'icon': Icons.pie_chart_outline_rounded, 'title': 'Báo cáo chi tiết', 'desc': 'Biểu đồ trực quan sinh động'},
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
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF438883).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(f['icon'] as IconData, size: 18, color: const Color(0xFF438883)),
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
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f['desc'] as String,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
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

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAboutRow({
    required bool isDark,
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
                color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE8F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF438883), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
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
