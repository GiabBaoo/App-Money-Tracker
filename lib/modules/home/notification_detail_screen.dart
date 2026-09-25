import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
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

  String _getTypeDisplayName(String? type) {
    if (type == null) return 'Thông báo';
    if (type.contains('spending_alert_high')) return '⚠️ Cảnh báo chi tiêu';
    if (type.contains('spending_alert_saved')) return '🎉 Tiết kiệm xuất sắc';
    if (type.contains('spending_alert_stable')) return '📊 Báo cáo ổn định';
    if (type.contains('spending')) return '📊 Báo cáo chi tiêu';
    if (type.contains('smart_advice')) return '💡 Lời khuyên tài chính';
    if (type.contains('limit')) return '🚨 Cảnh báo hạn mức';
    if (type.contains('transaction')) return '💰 Giao dịch mới';
    if (type.contains('group')) return '👥 Chi tiêu nhóm';
    if (type.contains('welcome')) return '🎉 Chào mừng';
    return 'Thông báo hệ thống';
  }

  Color _getTypeColor(String? type, Color primaryColor) {
    if (type == null) return primaryColor;
    if (type.contains('high') || type.contains('limit')) return const Color(0xFFEF4444);
    if (type.contains('saved') || type.contains('transaction')) return const Color(0xFF10B981);
    if (type.contains('advice')) return const Color(0xFFF59E0B);
    return primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final typeColor = _getTypeColor(_notification.type, primaryColor);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // HEADER BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Chi tiết thông báo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa thông báo',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 22),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Xác nhận xóa'),
                          content: const Text('Bạn có chắc chắn muốn xóa thông báo này không?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        Navigator.pop(context, 'deleted');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
                                    _getTypeDisplayName(_notification.type),
                                    style: TextStyle(
                                      color: typeColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(_notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black45,
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // DESCRIPTION CONTAINER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2928) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          _notification.description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155),
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
            gradient: LinearGradient(colors: [primaryColor, const Color(0xFF2F7E79)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Xem Báo Cáo Thống Kê',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
            gradient: const LinearGradient(colors: [Color(0xFF438883), Color(0xFF326E69)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFF438883).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.track_changes_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Quản Lý Ngân Sách & Mục Tiêu',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
            color: const Color(0xFF438883),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Xem Chi Tiết Nhóm',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
          color: const Color(0xFF438883),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Xem Lịch Sử Giao Dịch',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
