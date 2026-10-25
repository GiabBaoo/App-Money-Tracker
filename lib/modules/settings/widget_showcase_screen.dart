import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_widget_service.dart';
import '../../services/widget_snapshot_builder.dart';
import '../../services/language_service.dart';
import '../../widgets/top_toast.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../core/theme/app_theme.dart';

class WidgetShowcaseScreen extends StatefulWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  State<WidgetShowcaseScreen> createState() => _WidgetShowcaseScreenState();
}

class _WidgetShowcaseScreenState extends State<WidgetShowcaseScreen> {
  WidgetSnapshotData? _snapshot;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadRealSnapshot();
  }

  Future<void> _loadRealSnapshot() async {
    try {
      final wallets = await WalletRepository().getWallets();
      final transactions = await TransactionRepository().getAllTransactions();
      final budgets = await BudgetRepository().getBudgetsWithSpent();
      final goals = await GoalRepository().getAllGoals();
      final snap = WidgetSnapshotBuilder.build(
        wallets: wallets,
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        isLoggedIn: true,
      );
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final s = val.trim();
      if (s.isEmpty) return 0.0;
      if (s.contains('đ') ||
          s.contains('₫') ||
          RegExp(r'\d+\.\d{3}').hasMatch(s)) {
        final clean = s.replaceAll(RegExp(r'[^0-9\-]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      final direct = num.tryParse(s);
      if (direct != null) return direct.toDouble();
      final clean = s.replaceAll(RegExp(r'[^0-9\-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  String _formatCompact(double amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}M';
    } else if (amount >= 1000) {
      final val = amount / 1000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 0)}k';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _pinWidget(String providerName, String widgetName) async {
    final isVi = LanguageScope.of(context).isVietnamese;
    HapticFeedback.mediumImpact();
    final success = await AppWidgetService.instance.requestPinWidget(
      providerName,
    );
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
    final primaryColor = context.brandColor;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;
    final textPrimary = context.colors.onSurface;
    final textSecondary = context.colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isVi ? 'Tiện ích Màn hình chính' : 'Home Screen Widgets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: context.colors.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colors.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                    ? [
                        context.brandColor.withValues(alpha: 0.35),
                        const Color(0xFF0F2625),
                      ]
                    : [
                        context.brandColor.withValues(alpha: 0.12),
                        context.brandColor.withValues(alpha: 0.05),
                      ],
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
                  child: const Icon(
                    Icons.widgets_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi
                            ? 'Xem trước & Thêm Widget'
                            : 'Preview & Add Widgets',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVi
                            ? 'Theo dõi dòng tiền, số dư và ghi chép chi tiêu siêu tốc ngay từ màn hình chính!'
                            : 'Track cash flow, balance, and record expenses quickly right from your home screen!',
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
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
            pinButtonLabel: isVi
                ? 'Ghim ra Màn hình chính'
                : 'Pin to Home Screen',
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
            badgeText: isVi
                ? 'Khuyên dùng • Phổ biến'
                : 'Recommended • Popular',
            badgeColor: primaryColor,
            description: isVi
                ? 'Thiết kế Vibrant sắc nét, hiển thị số dư to rõ, hạn mức an toàn và 2 nút Chi / Thu lớn công thái học.'
                : 'Sharp Vibrant design, prominent balance, daily allowance, and 2 ergonomic Expense / Income buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi
                ? 'Ghim ra Màn hình chính'
                : 'Pin to Home Screen',
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
            pinButtonLabel: isVi
                ? 'Ghim ra Màn hình chính'
                : 'Pin to Home Screen',
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
            badgeText: isVi
                ? 'Bảng điều khiển tài chính'
                : 'Financial Dashboard',
            badgeColor: Colors.deepPurple,
            description: isVi
                ? 'Báo cáo toàn diện: Tab Tuần/Tháng, so sánh tháng trước, Top 3 danh mục và 4 nút đáy.'
                : 'Comprehensive report: Week/Month tabs, vs last month, Top 3 categories, and 4 bottom buttons.',
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            pinButtonLabel: isVi
                ? 'Ghim ra Màn hình chính'
                : 'Pin to Home Screen',
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
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2F7E79),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVi
                          ? 'Cách thêm thủ công từ màn hình chính'
                          : 'How to add manually from home screen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textPrimary,
                      ),
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
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: textSecondary,
                  ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Mono',
                style: TextStyle(
                  color: Color(0xFF2F7E79),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isVi ? 'Tổng số dư' : 'Total Balance',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
          ),
          Text(
            _snapshot?.totalBalance ?? (_isLoadingData ? '...' : '0đ'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            isVi
                ? 'Hôm nay còn ${_snapshot?.safeDailySpend ?? '0đ'}'
                : 'Today: ${_snapshot?.safeDailySpend ?? '0đ'} left',
            style: const TextStyle(
              color: Color(0xFF059669),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '− Chi' : '− Exp',
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '+ Thu' : '+ Inc',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 11,
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

  // Preview Widget Vừa #1 (4x2 - Số dư & Thao tác Vibrant Gradient)
  Widget _buildMediumPreview(bool isDark, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
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
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.remove_red_eye_outlined,
                size: 15,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Số dư lớn + Badge trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _snapshot?.totalBalance ?? (_isLoadingData ? '...' : '0đ'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF13382C)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF065F46)
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  isVi
                      ? 'Hôm nay còn ${_snapshot?.safeDailySpend ?? '0đ'}'
                      : 'Remaining today: ${_snapshot?.safeDailySpend ?? '0đ'}',
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
                    color: isDark
                        ? const Color(0xFF3E1F24)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '− Chi tiền' : '− Expense',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFF87171)
                            : const Color(0xFFDC2626),
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
                    color: isDark
                        ? const Color(0xFF13382C)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF065F46)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isVi ? '+ Thu tiền' : '+ Income',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669),
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
    List<dynamic> budgetsList = [];
    try {
      if (_snapshot?.budgetsJson != null) {
        final decoded = jsonDecode(_snapshot!.budgetsJson);
        if (decoded is List) {
          budgetsList = decoded;
        }
      }
    } catch (_) {}

    double totalSpent = 0;
    double totalLimit = 0;
    for (final b in budgetsList) {
      totalSpent += _parseAmount(b['spent_raw'] ?? b['spent']);
      totalLimit += _parseAmount(b['limit_raw'] ?? b['limit']);
    }
    final overallPercent = totalLimit > 0
        ? (totalSpent / totalLimit * 100).round()
        : 0;
    final progressVal = totalLimit > 0
        ? (totalSpent / totalLimit).clamp(0.0, 1.0)
        : 0.0;

    String spentDisplay = _formatCompact(totalSpent);
    String limitDisplay = _formatCompact(totalLimit);
    if (totalLimit == 0 && budgetsList.isEmpty) {
      spentDisplay = '0';
      limitDisplay = '0';
    }

    String cat1Name = isVi ? 'Ăn uống' : 'Dining';
    String cat1Percent = '0%';
    double cat1Ratio = 0.0;
    String cat2Name = isVi ? 'Mua sắm' : 'Shopping';
    String cat2Percent = '0%';
    double cat2Ratio = 0.0;

    if (budgetsList.isNotEmpty) {
      final b1 = budgetsList[0];
      cat1Name = (b1['category'] ?? b1['name'] ?? (isVi ? 'Ăn uống' : 'Dining'))
          .toString();
      final spent1 = _parseAmount(b1['spent_raw'] ?? b1['spent']);
      final limit1 = _parseAmount(b1['limit_raw'] ?? b1['limit']);
      final p1 = limit1 > 0 ? (spent1 / limit1 * 100).round() : 0;
      cat1Percent = '$p1%';
      cat1Ratio = limit1 > 0 ? (spent1 / limit1).clamp(0.0, 1.0) : 0.0;
    }

    if (budgetsList.length > 1) {
      final b2 = budgetsList[1];
      cat2Name =
          (b2['category'] ?? b2['name'] ?? (isVi ? 'Mua sắm' : 'Shopping'))
              .toString();
      final spent2 = _parseAmount(b2['spent_raw'] ?? b2['spent']);
      final limit2 = _parseAmount(b2['limit_raw'] ?? b2['limit']);
      final p2 = limit2 > 0 ? (spent2 / limit2 * 100).round() : 0;
      cat2Percent = '$p2%';
      cat2Ratio = limit2 > 0 ? (spent2 / limit2).clamp(0.0, 1.0) : 0.0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
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
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '$overallPercent%',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$spentDisplay / $limitDisplay',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    isVi
                        ? 'Hôm nay còn ${_snapshot?.safeDailySpend ?? '0đ'}'
                        : 'Today: ${_snapshot?.safeDailySpend ?? '0đ'} left',
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
                    Expanded(
                      child: Text(
                        cat1Name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      cat1Percent,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: cat1Ratio,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cat2Name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      cat2Percent,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: cat2Ratio,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Center(
                          child: Text(
                            isVi ? '− Chi' : '− Exp',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Center(
                          child: Text(
                            isVi ? 'Quét' : 'Scan',
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 10,
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
          ),
        ],
      ),
    );
  }

  // Preview Widget Lớn (4x4)
  Widget _buildLargePreview(bool isDark, bool isVi) {
    List<dynamic> topCats = [];
    try {
      if (_snapshot?.topCategoriesJson != null) {
        final decoded = jsonDecode(_snapshot!.topCategoriesJson);
        if (decoded is List) {
          topCats = decoded;
        }
      }
    } catch (_) {}

    List<dynamic> sevenDays = [];
    try {
      if (_snapshot?.sevenDaysChartJson != null) {
        final decoded = jsonDecode(_snapshot!.sevenDaysChartJson);
        if (decoded is List) {
          sevenDays = decoded;
        }
      }
    } catch (_) {}

    double maxDayExpense = 1.0;
    for (final day in sevenDays) {
      final amt = _parseAmount(day['amount_raw'] ?? day['amount']);
      if (amt > maxDayExpense) maxDayExpense = amt;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
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
                  style: const TextStyle(
                    color: Color(0xFF2F7E79),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isVi ? 'Tuần' : 'Week',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F7E79),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isVi ? 'Tháng' : 'Month',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.remove_red_eye_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
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
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        isVi
                            ? '${_snapshot?.monthVsLastMonthStatus == 'negative' ? '↑' : '↓'} ${_snapshot?.monthVsLastMonthPercent ?? '0%'} so với tháng trước'
                            : '${_snapshot?.monthVsLastMonthStatus == 'negative' ? '↑' : '↓'} ${_snapshot?.monthVsLastMonthPercent ?? '0%'} vs last month',
                        style: TextStyle(
                          color: _snapshot?.monthVsLastMonthStatus == 'negative'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _snapshot?.totalBalance ?? (_isLoadingData ? '...' : '0đ'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi
                          ? 'Tháng: +${_formatCompact(_snapshot?.monthIncomeRaw ?? 0)} • -${_formatCompact(_snapshot?.monthExpenseRaw ?? 0)}'
                          : 'Month: +${_formatCompact(_snapshot?.monthIncomeRaw ?? 0)} • -${_formatCompact(_snapshot?.monthExpenseRaw ?? 0)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _snapshot?.monthDifference ?? '0đ',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi
                            ? 'Hạn mức: ${_snapshot?.safeDailySpend ?? '0đ'}'
                            : 'Daily limit: ${_snapshot?.safeDailySpend ?? '0đ'}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: sevenDays.length == 7
                            ? List.generate(7, (i) {
                                final day = sevenDays[i];
                                final label = (day['label'] ?? day['day'] ?? '')
                                    .toString();
                                final amt = _parseAmount(
                                  day['amount_raw'] ?? day['amount'],
                                );
                                final isToday =
                                    day['isToday'] == true ||
                                    day['is_today'] == true;
                                final h = maxDayExpense > 0
                                    ? ((amt / maxDayExpense) * 22).clamp(
                                        4.0,
                                        24.0,
                                      )
                                    : 6.0;
                                return _buildMiniBar(label, h, isToday);
                              })
                            : [
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
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Chi nhiều nhất' : 'Top Spending',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (topCats.isNotEmpty)
                        ...topCats.take(3).map((c) {
                          final name = c['name'] ?? '';
                          final amt = _parseAmount(
                            c['amount_raw'] ?? c['amount'],
                          );
                          return Text(
                            '• $name: ${_formatCompact(amt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9),
                          );
                        })
                      else ...[
                        Text(
                          isVi ? '• Chưa có chi tiêu' : '• No spending yet',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLargeBtn(
                isVi ? '− Chi' : '− Exp',
                const Color(0xFFFEE2E2),
                const Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              _buildLargeBtn(
                isVi ? '+ Thu' : '+ Inc',
                const Color(0xFFD1FAE5),
                const Color(0xFF059669),
              ),
              const SizedBox(width: 4),
              _buildLargeBtn(
                isVi ? 'Quét' : 'Scan',
                const Color(0xFFEEF2FF),
                const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 4),
              _buildLargeBtn(
                isVi ? 'Báo cáo' : 'Report',
                const Color(0xFFE0F2FE),
                const Color(0xFF0284C7),
              ),
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
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
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
