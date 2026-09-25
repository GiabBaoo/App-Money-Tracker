import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/language_service.dart';

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
            // === APP BAR ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    context.tr('appearance_header'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // === MAIN CONTENT ===
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. THẺ XEM TRƯỚC ĐỘNG THỜI GIAN THỰC (HERO LIVE MOCKUP)
                      _buildSectionHeader(
                        icon: Icons.preview_rounded,
                        title: context.tr('preview_section'),
                        subtitle: context.tr('preview_sub'),
                      ),
                      const SizedBox(height: 12),
                      _buildLiveMockupCard(context, themeService, isDark),
                      const SizedBox(height: 28),

                      // 2. CHẾ ĐỘ MÀU SẮC (VISUAL CARD GRID)
                      _buildSectionHeader(
                        icon: Icons.palette_rounded,
                        title: context.tr('theme_mode_section'),
                        subtitle: context.tr('theme_mode_sub'),
                      ),
                      const SizedBox(height: 12),
                      _buildThemeCardGrid(context, themeService, isDark),
                      const SizedBox(height: 28),

                      // 3. KÍCH THƯỚC CHỮ HIỂN THỊ (SEGMENTED PILLS)
                      _buildSectionHeader(
                        icon: Icons.format_size_rounded,
                        title: context.tr('font_scale_section'),
                        subtitle: context.tr('font_scale_sub'),
                      ),
                      const SizedBox(height: 12),
                      _buildFontSizeSelector(context, themeService, isDark),
                      const SizedBox(height: 16),
                      _buildFontSizeDescriptionBox(themeService, isDark),
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

  // === TIÊU ĐỀ PHÂN ĐOẠN ===
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF438883)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF438883),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12.5, color: Colors.grey),
        ),
      ],
    );
  }

  // === 1. THẺ XEM TRƯỚC ĐỘNG THỜI GIAN THỰC ===
  Widget _buildLiveMockupCard(BuildContext context, ThemeService themeService, bool isDark) {
    // Xác định màu sắc hiển thị của mockup theo themeMode đang chọn
    final isPreviewDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final mockupBg = isPreviewDark ? const Color(0xFF1E2625) : Colors.white;
    final mockupHeaderBg = isPreviewDark ? const Color(0xFF0F2625) : const Color(0xFF438883);
    final textColor = isPreviewDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isPreviewDark ? Colors.white70 : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: mockupBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPreviewDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isPreviewDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          children: [
            // Header giả lập thu nhỏ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: mockupHeaderBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Chào bạn,', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            'Trần Hoàng Nam',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),

            // Nội dung bên dưới
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Thẻ số dư ví thu nhỏ
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPreviewDark ? const Color(0xFF2B3634) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF438883).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Color(0xFF438883), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tổng tài sản ví',
                                  style: TextStyle(fontSize: 12, color: subtextColor),
                                ),
                                Text(
                                  '48,500,000 đ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '+15% tháng',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Một giao dịch mẫu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_rounded, color: Colors.orange, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ăn uống & Cà phê',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                              ),
                              Text(
                                'Hôm nay • Tiền mặt',
                                style: TextStyle(fontSize: 11, color: subtextColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '- 65,000 đ',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === 2. CHẾ ĐỘ MÀU SẮC (VISUAL CARD GRID) ===
  Widget _buildThemeCardGrid(BuildContext context, ThemeService themeService, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildThemeCard(
            context: context,
            title: context.tr('theme_light'),
            subtitle: context.tr('theme_light_sub'),
            icon: Icons.wb_sunny_rounded,
            isSelected: themeService.themeMode == ThemeMode.light,
            previewColor: Colors.white,
            headerColor: const Color(0xFF438883),
            onTap: () => themeService.setThemeMode(ThemeMode.light),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildThemeCard(
            context: context,
            title: context.tr('theme_dark'),
            subtitle: context.tr('theme_dark_sub'),
            icon: Icons.nightlight_round,
            isSelected: themeService.themeMode == ThemeMode.dark,
            previewColor: const Color(0xFF1E1E1E),
            headerColor: const Color(0xFF0F2625),
            onTap: () => themeService.setThemeMode(ThemeMode.dark),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildThemeCard(
            context: context,
            title: context.tr('theme_system'),
            subtitle: context.tr('theme_system_sub'),
            icon: Icons.brightness_auto_rounded,
            isSelected: themeService.themeMode == ThemeMode.system,
            previewColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            headerColor: const Color(0xFF438883),
            onTap: () => themeService.setThemeMode(ThemeMode.system),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color previewColor,
    required Color headerColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeColor = const Color(0xFF438883);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222C2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Preview Circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: previewColor,
                shape: BoxShape.circle,
                border: Border.all(color: headerColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: headerColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isSelected ? activeColor : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // === 3. KÍCH THƯỚC CHỮ (SEGMENTED PILLS) ===
  Widget _buildFontSizeSelector(BuildContext context, ThemeService themeService, bool isDark) {
    final factors = [
      {'label': 'Nhỏ', 'scale': '0.85x', 'val': 0.85, 'symbol': 'A-'},
      {'label': 'Chuẩn', 'scale': '1.0x', 'val': 1.0, 'symbol': 'A'},
      {'label': 'Lớn', 'scale': '1.15x', 'val': 1.15, 'symbol': 'A+'},
      {'label': 'Cực đại', 'scale': '1.30x', 'val': 1.30, 'symbol': 'A++'},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222C2A) : const Color(0xFFEAEFEF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: factors.map((f) {
          final val = f['val'] as double;
          final isSelected = (themeService.textScaleFactor - val).abs() < 0.05;

          return Expanded(
            child: GestureDetector(
              onTap: () => themeService.setTextScaleFactor(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF438883) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      f['symbol'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF438883))
                            : (isDark ? Colors.white60 : Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : const Color(0xFF1E293B))
                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // === HỘP DIỄN GIẢI KÍCH THƯỚC CHỮ ĐANG CHỌN ===
  Widget _buildFontSizeDescriptionBox(ThemeService themeService, bool isDark) {
    String desc;
    if (themeService.textScaleFactor <= 0.88) {
      desc = 'Cỡ chữ Nhỏ (0.85x): Hiển thị được nhiều thông tin hơn trên cùng màn hình, phù hợp người thích bố cục gọn gàng.';
    } else if (themeService.textScaleFactor <= 1.05) {
      desc = 'Cỡ chữ Chuẩn (1.0x): Kích thước mặc định cân đối và sắc nét nhất cho hầu hết mọi màn hình điện thoại.';
    } else if (themeService.textScaleFactor <= 1.20) {
      desc = 'Cỡ chữ Lớn (1.15x): Chữ to rõ ràng, dễ đọc khi đang di chuyển và giảm đáng kể tình trạng mỏi mắt.';
    } else {
      desc = 'Cỡ chữ Cực đại (1.30x): Kích thước chữ tối đa, hỗ trợ đọc dễ dàng cho người lớn tuổi hoặc thị lực kém.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2625) : const Color(0xFFE8F5F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF438883).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF438883)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF2E615D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
