import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../services/smart_notification_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/language_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/voice_input_bottom_sheet.dart';
import '../../widgets/animated_scale_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _remindersEnabled = true;
  bool _spendingReportEnabled = true;
  bool _smartAdviceEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _dailyLimitEnabled = false;
  double _dailySpendingLimit = 0.0;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _remindersEnabled = prefs.getBool('notif_reminders') ?? true;
      _spendingReportEnabled = prefs.getBool('notif_spending_report') ?? true;
      _smartAdviceEnabled = prefs.getBool('notif_smart_advice') ?? true;
      _budgetAlertsEnabled = prefs.getBool('notif_budget_alerts') ?? true;
      _dailyLimitEnabled = prefs.getBool('daily_limit_enabled') ?? false;
      _dailySpendingLimit = prefs.getDouble('daily_spending_limit') ?? 0.0;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'settings': {
            'notifications': {
              'reminders': _remindersEnabled,
              'spendingReport': _spendingReportEnabled,
              'smartAdvice': _smartAdviceEnabled,
              'budgetAlerts': _budgetAlertsEnabled,
              'dailyLimitEnabled': _dailyLimitEnabled,
            },
          },
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    // Cập nhật toàn bộ các lịch thông báo thực tế ngoài màn hình
    await SmartNotificationService.instance
        .scheduleAllBackgroundNotifications();
  }

  Future<void> _saveDailySpendingLimit(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('daily_spending_limit', amount);
    await prefs.setBool('daily_limit_enabled', true);

    setState(() {
      _dailySpendingLimit = amount;
      _dailyLimitEnabled = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'settings': {'dailySpendingLimit': amount, 'dailyLimitEnabled': true},
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (mounted) {
      TopToast.show(context, context.tr('daily_limit_saved'));
    }
  }

  Future<void> _testSendSystemNotification() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final granted = await LocalNotificationService.instance.requestPermission();
    if (!granted) {
      if (!mounted) return;
      TopToast.show(
        context,
        isVi
            ? 'Vui lòng cấp quyền thông báo cho ứng dụng trong cài đặt điện thoại!'
            : 'Please grant notification permissions in phone settings!',
        isError: true,
      );
      return;
    }

    await LocalNotificationService.instance.showInstantNotification(
      id: 999,
      title: isVi
          ? '🔔 Thông báo thử nghiệm từ Mono'
          : '🔔 Test notification from Mono',
      body: isVi
          ? 'Tuyệt vời! Thiết bị của bạn đã kích hoạt thành công tính năng thông báo tài chính thông minh ra màn hình khóa & thanh trạng thái.'
          : 'Awesome! Your device has successfully activated smart financial alerts on your lock screen & status bar.',
    );

    if (!mounted) return;
    TopToast.show(
      context,
      isVi
          ? 'Đã gửi thông báo thử nghiệm ra thanh trạng thái điện thoại!'
          : 'Test notification sent to phone status bar!',
    );
  }

  Future<void> _testScheduledNotificationIn5Seconds() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final granted = await LocalNotificationService.instance.requestPermission();
    if (!granted) {
      if (!mounted) return;
      TopToast.show(
        context,
        isVi
            ? 'Vui lòng cấp quyền thông báo cho ứng dụng trong cài đặt điện thoại!'
            : 'Please grant notification permissions in phone settings!',
        isError: true,
      );
      return;
    }

    await LocalNotificationService.instance.scheduleTestNotification(
      id: 998,
      delaySeconds: 5,
      title: isVi
          ? '📝 Nhắc nhở chi tiêu Mono (Thử nghiệm 5s)'
          : '📝 Mono Expense Reminder (5s Test)',
      body: isVi
          ? 'Tuyệt vời! Thông báo ngoài màn hình hoạt động hoàn hảo. Lịch hẹn 20:00 mỗi tối của bạn đã được kích hoạt!'
          : 'Awesome! Lock screen alerts work properly. Your 20:00 daily reminder is active!',
    );

    if (!mounted) return;
    TopToast.show(
      context,
      isVi
          ? '⏳ Đã lập lịch! Hãy khóa màn hình hoặc về Home, sau 5 giây thông báo sẽ xuất hiện!'
          : '⏳ Scheduled! Lock your screen or return Home; notification will appear in 5 seconds!',
    );
  }

  Future<void> _triggerInstantAnalysis() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    setState(() => _isAnalyzing = true);
    try {
      final count = await SmartNotificationService.instance
          .generateSmartFinancialNotifications(forceRefresh: true);
      if (!mounted) return;
      TopToast.show(
        context,
        count > 0
            ? (isVi
                  ? 'Đã tạo $count thông báo phân tích chi tiêu mới và đẩy ra điện thoại!'
                  : 'Generated $count new spending analysis alerts and sent to phone!')
            : (isVi
                  ? 'Dữ liệu chi tiêu của bạn đã được phân tích mới nhất!'
                  : 'Your spending data is already up to date!'),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showSetDailyLimitDialog() {
    final controller = TextEditingController(
      text: CurrencyUtils.formatNumberOnly(_dailySpendingLimit),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(modalCtx).bottom + 24,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('daily_limit_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: context.colors.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('daily_limit_desc'),
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // TextField nhập số tiền
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.brandColor,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('daily_limit_amount'),
                  suffixText: '₫',
                  suffixStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.brandColor,
                  ),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.brandColor,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (val) {
                  final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
                  if (cleaned.isNotEmpty) {
                    final num = double.tryParse(cleaned) ?? 0;
                    final formatted = CurrencyUtils.formatNumberOnly(num);
                    controller.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Quick amount chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickAddChip(
                      '+50.000',
                      50000,
                      controller,
                      setModalState,
                    ),
                    _buildQuickAddChip(
                      '+100.000',
                      100000,
                      controller,
                      setModalState,
                    ),
                    _buildQuickAddChip(
                      '+200.000',
                      200000,
                      controller,
                      setModalState,
                    ),
                    _buildQuickAddChip(
                      '+500.000',
                      500000,
                      controller,
                      setModalState,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = CurrencyUtils.parseCurrency(controller.text);
                    if (amount <= 0) {
                      TopToast.show(
                        context,
                        LanguageScope.of(context).isVietnamese
                            ? 'Vui lòng nhập số tiền hợp lệ!'
                            : 'Please enter a valid amount!',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.pop(modalCtx);
                    _saveDailySpendingLimit(amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brandColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.tr('save'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddChip(
    String label,
    double addAmount,
    TextEditingController controller,
    StateSetter setModalState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          final current = CurrencyUtils.parseCurrency(controller.text);
          final newVal = current + addAmount;
          final formatted = CurrencyUtils.formatNumberOnly(newVal);
          setModalState(() {
            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          });
        },
      ),
    );
  }

  void _openVoiceSetLimit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceInputBottomSheet(),
    ).then((_) {
      // Sau khi voice bottom sheet đóng, nạp lại giá trị limit mới nhất
      _loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // === FINTECH GLASSMORPHISM HEADER ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    context.tr('notification_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ════════ PHẦN HẠN MỨC CHI TIÊU HÀNG NGÀY ════════
                      _buildSectionTitle(
                        context,
                        context.tr('daily_limit_title').toUpperCase(),
                      ),
                      _buildInfoBox(context, [
                        _buildToggleRow(
                          context,
                          icon: Icons.track_changes_rounded,
                          title: context.tr('daily_limit_enabled'),
                          subtitle: context.tr('daily_limit_desc'),
                          value: _dailyLimitEnabled,
                          onChanged: (val) {
                            setState(() => _dailyLimitEnabled = val);
                            _updateSetting('daily_limit_enabled', val);
                          },
                          showDivider: _dailyLimitEnabled,
                        ),
                        if (_dailyLimitEnabled)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: context.brandColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.brandColor.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('daily_limit_amount'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                context.colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyUtils.formatCurrency(
                                            _dailySpendingLimit,
                                          ),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: context.brandColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Nút nói giọng nói
                                  IconButton(
                                    icon: Icon(
                                      Icons.mic,
                                      color: context.brandColor,
                                    ),
                                    tooltip: context.tr(
                                      'daily_limit_set_voice',
                                    ),
                                    onPressed: _openVoiceSetLimit,
                                    style: IconButton.styleFrom(
                                      backgroundColor: context.brandColor
                                          .withValues(alpha: 0.15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Nút sửa thủ công
                                  ElevatedButton.icon(
                                    onPressed: _showSetDailyLimitDialog,
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isVi ? 'Sửa' : 'Edit',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.brandColor,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 28),

                      // ════════ THÔNG BÁO TÀI CHÍNH THÔNG MINH ════════
                      _buildSectionTitle(
                        context,
                        isVi
                            ? 'THÔNG BÁO TÀI CHÍNH THÔNG MINH'
                            : 'SMART FINANCIAL ALERTS',
                      ),
                      _buildInfoBox(context, [
                        _buildToggleRow(
                          context,
                          icon: Icons.pie_chart_rounded,
                          title: isVi
                              ? 'Cảnh báo ngân sách (80% & 100%)'
                              : 'Budget Alerts (80% & 100%)',
                          subtitle: isVi
                              ? 'Nhận thông báo khi danh mục chi tiêu chạm 80% hoặc vượt hạn mức ngân sách'
                              : 'Get notified when category spending reaches 80% or exceeds budget limit',
                          value: _budgetAlertsEnabled,
                          onChanged: (val) {
                            setState(() => _budgetAlertsEnabled = val);
                            _updateSetting('notif_budget_alerts', val);
                          },
                          showDivider: true,
                        ),
                        _buildToggleRow(
                          context,
                          icon: Icons.trending_up_rounded,
                          title: isVi
                              ? 'Báo cáo chi tiêu so kỳ trước'
                              : 'Period Spending Report',
                          subtitle: isVi
                              ? 'So sánh chi tiêu tháng này với tháng trước (cảnh báo tăng / khen tiết kiệm)'
                              : 'Compare spending this month vs last month (growth warning / saving praise)',
                          value: _spendingReportEnabled,
                          onChanged: (val) {
                            setState(() => _spendingReportEnabled = val);
                            _updateSetting('notif_spending_report', val);
                          },
                          showDivider: true,
                        ),
                        _buildToggleRow(
                          context,
                          icon: Icons.lightbulb_outline_rounded,
                          title: isVi
                              ? 'Gợi ý chi tiêu khoa học'
                              : 'Smart Spending Guidance',
                          subtitle: isVi
                              ? 'Gợi ý hạn mức chi tiêu trung bình mỗi ngày dựa trên số dư ví còn lại'
                              : 'Suggest daily spending allowance based on remaining wallet balance',
                          value: _smartAdviceEnabled,
                          onChanged: (val) {
                            setState(() => _smartAdviceEnabled = val);
                            _updateSetting('notif_smart_advice', val);
                          },
                          showDivider: true,
                        ),
                        _buildToggleRow(
                          context,
                          icon: Icons.edit_note_rounded,
                          title: isVi
                              ? 'Nhắc nhở ghi chép mỗi ngày'
                              : 'Daily Expense Reminder',
                          subtitle: isVi
                              ? 'Nhắc nhở ghi lại chi tiêu nếu hôm nay bạn chưa có giao dịch'
                              : 'Remind you to log expenses if you haven\'t recorded any transaction today',
                          value: _remindersEnabled,
                          onChanged: (val) {
                            setState(() => _remindersEnabled = val);
                            _updateSetting('notif_reminders', val);
                          },
                          showDivider: false,
                        ),
                      ]),
                      const SizedBox(height: 32),

                      // NÚT PHÂN TÍCH TỨC THÌ
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.brandColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _isAnalyzing
                                  ? null
                                  : _triggerInstantAnalysis,
                              icon: _isAnalyzing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                _isAnalyzing
                                    ? (isVi
                                          ? 'Đang phân tích...'
                                          : 'Analyzing...')
                                    : (isVi
                                          ? 'Phân tích & Cập nhật thông báo ngay'
                                          : 'Analyze & Update Alerts Now'),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.income,
                                side: BorderSide(
                                  color: context.income,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _testScheduledNotificationIn5Seconds,
                              icon: const Icon(Icons.timer_outlined, size: 20),
                              label: Text(
                                isVi
                                    ? 'Thử nghiệm thông báo sau 5 giây (Khóa màn hình để test)'
                                    : 'Test alert in 5s (Lock screen to test)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? const Color(0xFF00E5FF)
                                    : context.brandColor,
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF00E5FF)
                                      : context.brandColor,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _testSendSystemNotification,
                              icon: const Icon(
                                Icons.notifications_active_rounded,
                                size: 20,
                              ),
                              label: Text(
                                isVi
                                    ? 'Bắn thử thông báo ra màn hình điện thoại ngay'
                                    : 'Send instant test notification to phone',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2827)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.income.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: context.income,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isVi
                                    ? 'Để nhận thông báo 20:00 đều đặn ngoài màn hình (đặc biệt trên Xiaomi, Samsung, Oppo), vui lòng cho phép Mono tự khởi chạy và tắt "Tiết kiệm pin" trong Cài đặt ứng dụng của máy.'
                                    : 'To receive daily 20:00 alerts reliably on your lock screen (especially on Xiaomi, Samsung, Oppo), please enable Mono Auto-start and disable Battery Saver in app settings.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVi
                            ? 'Hệ thống sẽ tự động quét các giao dịch và ví tiền thực tế để tạo báo cáo chi tiêu và cảnh báo vượt hạn mức kịp thời cho bạn.'
                            : 'The system automatically scans transactions and wallet balances to generate spending reports and timely budget alerts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
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
          color: context.colors.onSurfaceVariant,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.2 : 0.03,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: context.brandColor,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.dividerColor,
            indent: 64,
            endIndent: 16,
          ),
      ],
    );
  }
}
