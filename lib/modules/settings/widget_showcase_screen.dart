import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_widget_service.dart';
import '../../services/language_service.dart';
import '../../widgets/top_toast.dart';

class WidgetShowcaseScreen extends StatefulWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  State<WidgetShowcaseScreen> createState() => _WidgetShowcaseScreenState();
}

class _WidgetShowcaseScreenState extends State<WidgetShowcaseScreen> {
  Future<void> _pinWidget(String providerName, String widgetName) async {
    final isVi = LanguageScope.of(context).isVietnamese;
    HapticFeedback.mediumImpact();
    final success = await AppWidgetService.instance.requestPinWidget(providerName);
    if (!mounted) return;

    if (success == true) {
      TopToast.show(
        context,
        isVi
            ? 'Đã gửi yêu cầu ghim $widgetName ra màn hình chính!'
            : 'Pin request sent for $widgetName to home screen!',
      );
    } else {
      TopToast.show(
        context,
        isVi
            ? 'Bạn cũng có thể ấn giữ màn hình chính > Chọn Tiện ích > Mono để thêm thủ công.'
            : 'You can also press and hold home screen > Select Widgets > Mono to add manually.',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF2F7E79);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isVi ? 'Tiện ích Màn hình chính' : 'Home Screen Widgets',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Banner giới thiệu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF134E4A), const Color(0xFF0F2625)]
                    : [const Color(0xFFE6F4F1), const Color(0xFFCCECE6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.widgets_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Xem trước & Thêm Widget' : 'Preview & Add Widgets',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F2625),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVi
                            ? 'Theo dõi dòng tiền, số dư và ghi chép chi tiêu siêu tốc ngay từ màn hình chính!'
                            : 'Track cash flow, balance, and record expenses quickly right from your home screen!',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : const Color(0xFF285E5A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 1. WIDGET NHỎ (2x2)
          _buildWidgetCard(
            title: isVi ? '1. Widget Nhỏ (Small 2×2)' : '1. Small Widget (2×2)',
            badgeText: isVi ? 'Gọn nhẹ • Tối giản' : 'Compact • Minimal',
            badgeColor: Colors.blue,
            description: isVi
                ? 'Hiển thị số dư hiện tại, chi hôm nay và 2 nút thêm nhanh giao dịch.'
                : 'Displays current balance, today\'s spending, and 2 quick transaction buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi ? 'Ghim ra Màn hình chính' : 'Pin to Home Screen',
            onPinPressed: () => _pinWidget(
              AppWidgetService.smallWidgetProvider,
              isVi ? 'Widget Nhỏ' : 'Small Widget',
            ),
            previewContent: _buildSmallPreview(isDark, isVi),
          ),

          const SizedBox(height: 20),

          // 2. WIDGET VỪA #1 (4x2): SỐ DƯ & THAO TÁC NHANH
          _buildWidgetCard(
            title: isVi
                ? '2. Widget Vừa (Medium 4×2) - Phong cách Vibrant'
                : '2. Medium Widget (4×2) - Vibrant Style',
            badgeText: isVi ? 'Khuyên dùng • Phổ biến' : 'Recommended • Popular',
            badgeColor: primaryColor,
            description: isVi
                ? 'Thiết kế Vibrant sắc nét, hiển thị số dư to rõ, hạn mức an toàn và 2 nút Chi / Thu lớn công thái học.'
                : 'Sharp Vibrant design, prominent balance, daily allowance, and 2 ergonomic Expense / Income buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi ? 'Ghim ra Màn hình chính' : 'Pin to Home Screen',
            onPinPressed: () => _pinWidget(
              AppWidgetService.mediumWidgetProvider,
              isVi ? 'Widget Vừa (Số dư)' : 'Medium Widget (Balance)',
            ),
            previewContent: _buildMediumPreview(isDark, isVi),
          ),

          const SizedBox(height: 20),

          // 2.1 WIDGET VỪA #2 (4x2): TIẾN ĐỘ NGÂN SÁCH
          _buildWidgetCard(
            title: isVi
                ? '3. Widget Vừa (Medium 4×2) - Tiến độ Ngân sách'
                : '3. Medium Widget (4×2) - Budget Progress',
            badgeText: isVi ? 'Kiểm soát chi tiêu' : 'Spending Control',
            badgeColor: Colors.teal,
            description: isVi
                ? 'Thanh tiến độ ngân sách tháng trực quan (đổi màu Xanh/Cam/Đỏ), hạn mức ngày và nút Chi/Quét.'
                : 'Intuitive monthly budget progress bar (Green/Orange/Red), daily limit, and Expense/Scan buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi ? 'Ghim ra Màn hình chính' : 'Pin to Home Screen',
            onPinPressed: () => _pinWidget(
              AppWidgetService.budgetWidgetProvider,
              isVi ? 'Widget Ngân sách' : 'Budget Widget',
            ),
            previewContent: _buildBudgetPreview(isDark, isVi),
          ),

          const SizedBox(height: 20),

          // 3. WIDGET LỚN (4x4)
          _buildWidgetCard(
            title: isVi ? '4. Widget Lớn (Large 4×4)' : '4. Large Widget (4×4)',
            badgeText: isVi ? 'Bảng điều khiển tài chính' : 'Financial Dashboard',
            badgeColor: Colors.deepPurple,
            description: isVi
                ? 'Báo cáo toàn diện: Tab Tuần/Tháng, so sánh tháng trước, Top 3 danh mục và 4 nút đáy.'
                : 'Comprehensive report: Week/Month tabs, vs last month, Top 3 categories, and 4 bottom buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi ? 'Ghim ra Màn hình chính' : 'Pin to Home Screen',
            onPinPressed: () => _pinWidget(
              AppWidgetService.largeWidgetProvider,
              isVi ? 'Widget Lớn' : 'Large Widget',
            ),
            previewContent: _buildLargePreview(isDark, isVi),
          ),

          const SizedBox(height: 24),

          // Hướng dẫn thêm từ Launcher
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2F7E79), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isVi
                          ? 'Cách thêm thủ công từ màn hình chính'
                          : 'How to add manually from home screen',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isVi
                      ? '1. Chạm và giữ vào một vùng trống trên màn hình chính của điện thoại.\n'
                          '2. Chọn mục "Tiện ích" (hoặc "Widgets").\n'
                          '3. Cuộn tìm ứng dụng "Mono" để xem trước giao diện demo sắc nét.\n'
                          '4. Chạm và kéo widget mong muốn ra vị trí bạn thích.'
                      : '1. Touch and hold an empty space on your phone\'s home screen.\n'
                          '2. Select "Widgets".\n'
                          '3. Scroll to find "Mono".\n'
                          '4. Touch and drag the desired widget to your preferred position.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWidgetCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required String pinButtonLabel,
    required VoidCallback onPinPressed,
    required Widget previewContent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(fontSize: 13, color: textSecondary)),
          const SizedBox(height: 14),

          // Container mô phỏng widget thực tế
          Center(child: previewContent),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPinPressed,
              icon: const Icon(Icons.add_to_home_screen_rounded, size: 18),
              label: Text(
                pinButtonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F7E79),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Preview Widget Nhỏ (2x2)
  Widget _buildSmallPreview(bool isDark, bool isVi) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Mono', style: TextStyle(color: Color(0xFF2F7E79), fontSize: 12, fontWeight: FontWeight.bold)),
              Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isVi ? 'Tổng số dư' : 'Total Balance',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
          ),
          const Text('25.500.000đ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(
            isVi ? 'Hôm nay còn 250.000đ' : 'Today: 250,000đ left',
            style: const TextStyle(color: Color(0xFF059669), fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                  child: Center(
                    child: Text(
                      isVi ? '− Chi' : '− Exp',
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Center(
                    child: Text(
                      isVi ? '+ Thu' : '+ Inc',
                      style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Preview Widget Vừa #1 (4x2 - Số dư & Thao tác Vibrant Gradient)
  Widget _buildMediumPreview(bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Tiêu đề + Icon con mắt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F7E79),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isVi ? 'Tổng số dư' : 'Total Balance',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 15,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Số dư lớn + Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '45.280.000đ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13382C) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  isVi ? 'Hôm nay còn 250.000đ' : 'Remaining today: 250,000đ',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2 Nút thao tác nhanh lớn công thái học
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E1F24) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '− Chi tiền' : '− Expense',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13382C) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '+ Thu tiền' : '+ Income',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Preview Widget Vừa #2 (4x2 - Tiến độ Ngân sách)
  Widget _buildBudgetPreview(bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Cột trái: Tổng ngân sách & Hạn mức
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Ngân sách tháng' : 'Monthly budget',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    const Text('71%', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('4.25M / 6.00M', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(value: 0.71, minHeight: 6, backgroundColor: Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(Color(0xFF10B981))),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Text(
                    isVi ? 'Hôm nay còn 250.000đ' : 'Today: 250,000đ left',
                    style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Cột phải: 2 Hạng mục & 2 Nút
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isVi ? 'Ăn uống' : 'Dining', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const Text('85%', style: TextStyle(fontSize: 9.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(value: 0.85, minHeight: 4, backgroundColor: Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B))),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isVi ? 'Mua sắm' : 'Shopping', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const Text('45%', style: TextStyle(fontSize: 9.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(value: 0.45, minHeight: 4, backgroundColor: Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(Color(0xFF10B981))),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                        child: Center(
                          child: Text(
                            isVi ? '− Chi' : '− Exp',
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC7D2FE))),
                        child: Center(
                          child: Text(
                            isVi ? 'Quét' : 'Scan',
                            style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Preview Widget Lớn (4x4)
  Widget _buildLargePreview(bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Tài chính' : 'Finance',
                  style: const TextStyle(color: Color(0xFF2F7E79), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isVi ? 'Tuần' : 'Week',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF2F7E79), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  isVi ? 'Tháng' : 'Month',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Tổng số dư' : 'Total Balance',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        isVi ? '↓ 12% so với tháng trước' : '↓ 12% vs last month',
                        style: const TextStyle(color: Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Text('45.280.000đ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Tháng: +28tr • -15.5tr' : 'Month: +28M • -15.5M',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    const Text('+12.500.000đ', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Hạn mức hôm nay: 250k' : 'Today limit: 250k',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMiniBar(isVi ? 'T2' : 'M', 10, false),
                          _buildMiniBar(isVi ? 'T3' : 'T', 16, false),
                          _buildMiniBar(isVi ? 'T4' : 'W', 8, false),
                          _buildMiniBar(isVi ? 'T5' : 'T', 22, false),
                          _buildMiniBar(isVi ? 'T6' : 'F', 12, false),
                          _buildMiniBar(isVi ? 'T7' : 'S', 18, false),
                          _buildMiniBar(isVi ? 'CN' : 'S', 15, true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Chi nhiều nhất' : 'Top Spending',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(isVi ? '• Ăn uống: 5.2tr' : '• Dining: 5.2M', style: const TextStyle(fontSize: 9)),
                      Text(isVi ? '• Mua sắm: 3.8tr' : '• Shopping: 3.8M', style: const TextStyle(fontSize: 9)),
                      Text(isVi ? '• Di chuyển: 1.5tr' : '• Transport: 1.5M', style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLargeBtn(isVi ? '− Chi' : '− Exp', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
              const SizedBox(width: 4),
              _buildLargeBtn(isVi ? '+ Thu' : '+ Inc', const Color(0xFFD1FAE5), const Color(0xFF059669)),
              const SizedBox(width: 4),
              _buildLargeBtn(isVi ? 'Quét' : 'Scan', const Color(0xFFEEF2FF), const Color(0xFF4F46E5)),
              const SizedBox(width: 4),
              _buildLargeBtn(isVi ? 'Báo cáo' : 'Report', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeBtn(String label, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Center(
          child: Text(label, style: TextStyle(color: textColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  static Widget _buildMiniBar(String label, double height, bool isToday) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: isToday ? const Color(0xFFF59E0B) : const Color(0xFF4FD1C5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            color: isToday ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
