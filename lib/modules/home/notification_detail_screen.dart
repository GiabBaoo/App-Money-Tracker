import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../utils/page_transitions.dart';
import '../../services/language_service.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_dialog.dart';
import '../budget/budget_and_goals_screen.dart';
import 'statistics_screen.dart';
import '../transaction/all_transactions_screen.dart';
import '../../features/group_expense/presentation/screens/group_detail_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final NotificationModel notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  late NotificationModel _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    _markRead();
  }

  Future<void> _markRead() async {
    if (!_notification.isRead && _notification.id.isNotEmpty) {
      await NotificationRepository().markAsRead(_notification.id);
    }
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute • $day/$month/$year';
  }

  String _getTypeDisplayName(String? type, bool isVi) {
    if (type == null) return isVi ? 'Thông báo' : 'Notification';
    if (type.contains('spike')) return isVi ? '⚡ Chi tiêu đột biến' : '⚡ Spending Spike';
    if (type.contains('spending_alert_high')) return isVi ? '⚠️ Cảnh báo chi tiêu' : '⚠️ Spending Alert';
    if (type.contains('spending_alert_saved')) return isVi ? '🎉 Tiết kiệm xuất sắc' : '🎉 Great Savings';
    if (type.contains('limit')) return isVi ? '🚨 Cảnh báo hạn mức' : '🚨 Limit Alert';
    if (type.contains('low_balance')) return isVi ? '⚠️ Cảnh báo số dư' : '⚠️ Low Balance Alert';
    if (type.contains('offline_sync')) return isVi ? '☁️ Đồng bộ dữ liệu' : '☁️ Data Sync';
    if (type.contains('spending')) return isVi ? '📊 Báo cáo chi tiêu' : '📊 Spending Report';
    if (type.contains('smart_advice') || type.contains('budget')) return isVi ? '💡 Gợi ý ngân sách' : '💡 Budget Advice';
    if (type.contains('transaction')) return isVi ? '💰 Giao dịch mới' : '💰 New Transaction';
    if (type.contains('daily_reminder')) return isVi ? '📝 Nhắc nhở ghi chép' : '📝 Daily Reminder';
    if (type.contains('group')) return isVi ? '👥 Chi tiêu nhóm' : '👥 Group Expense';
    if (type.contains('welcome')) return isVi ? '🎉 Chào mừng' : '🎉 Welcome';
    return isVi ? 'Thông báo hệ thống' : 'System Notification';
  }

  Color _getTypeColor(String? type, Color primaryColor) {
    if (type == null) return primaryColor;
    if (type.contains('spike')) return AppColors.warningAmber;
    if (type.contains('high') || type.contains('limit') || type.contains('low_balance')) return AppColors.expenseRose;
    if (type.contains('warning')) return AppColors.warningAmber;
    if (type.contains('saved') || type.contains('transaction')) return AppColors.incomeEmerald;
    if (type.contains('advice') || type.contains('budget')) return AppColors.infoAzure;
    if (type.contains('offline_sync')) return AppColors.textSecondaryDark;
    return primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;
    final primaryColor = context.colors.primary;
    final typeColor = _getTypeColor(_notification.type, primaryColor);

    return Scaffold(
      backgroundColor: isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // FINTECH GLASSMORPHISM HEADER
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
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  Text(
                    isVi ? 'Chi tiết thông báo' : 'Notification Details',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  AnimatedScaleButton(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final confirm = await MonoDialog.confirm(
                        context,
                        title: isVi ? 'Xác nhận xóa' : 'Confirm Delete',
                        message: isVi
                            ? 'Bạn có chắc chắn muốn xóa thông báo này không?'
                            : 'Are you sure you want to delete this notification?',
                        cancelText: isVi ? 'Hủy' : 'Cancel',
                        confirmText: isVi ? 'Xóa' : 'Delete',
                        isDestructive: true,
                        icon: Icons.delete_outline_rounded,
                      );
                      if (confirm == true && context.mounted) {
                        Navigator.pop(context, 'deleted');
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // CONTENT CARD
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW: ICON + TYPE BADGE + TIME
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(_notification.icon, color: typeColor, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getTypeDisplayName(_notification.type, isVi),
                                    style: context.textTheme.labelSmall?.copyWith(
                                      color: typeColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(_notification.createdAt),
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: context.textMutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // TITLE
                      Text(
                        _notification.title,
                        style: context.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimaryColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // DESCRIPTION CONTAINER - 18px Card Radius
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: AppRadius.card,
                          border: Border.all(
                            color: context.borderColor,
                          ),
                        ),
                        child: Text(
                          _notification.description,
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.6,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // CONTEXTUAL ACTION BUTTON
                      _buildActionButtons(context, primaryColor, typeColor),
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

  Widget _buildActionButtons(BuildContext context, Color primaryColor, Color typeColor) {
    final type = _notification.type ?? '';

    // Action 1: Báo cáo thống kê
    if (type.contains('spending') || type.contains('report') || type.contains('first')) {
      return AnimatedScaleButton(
        onTap: () {
          Navigator.push(context, PageTransitions.slideRight(const StatisticsScreen()));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, AppColors.primaryTealDark]),
            borderRadius: AppRadius.button,
            boxShadow: [
              BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isVi ? 'Xem Báo Cáo Thống Kê' : 'View Statistics Report',
                style: context.textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Action 2: Quản lý ngân sách
    if (type.contains('limit') || type.contains('budget') || type.contains('advice')) {
      return AnimatedScaleButton(
        onTap: () {
          Navigator.push(context, PageTransitions.slideRight(const BudgetAndGoalsScreen()));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, AppColors.primaryTealDark]),
            borderRadius: AppRadius.button,
            boxShadow: [
              BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.track_changes_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isVi ? 'Quản Lý Ngân Sách & Mục Tiêu' : 'Manage Budgets & Goals',
                style: context.textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Action 3: Xem chi tiêu nhóm
    if (type.contains('group') && _notification.groupId != null && _notification.groupId!.isNotEmpty) {
      return AnimatedScaleButton(
        onTap: () {
          Navigator.push(
            context,
            PageTransitions.slideRight(
              GroupDetailScreen(
                groupId: _notification.groupId!,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: AppRadius.button,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isVi ? 'Xem Chi Tiết Nhóm' : 'View Group Details',
                style: context.textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Action 4: Xem tất cả giao dịch
    return AnimatedScaleButton(
      onTap: () {
        Navigator.push(context, PageTransitions.slideRight(const AllTransactionsScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: AppRadius.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isVi ? 'Xem Lịch Sử Giao Dịch' : 'View Transaction History',
              style: context.textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
