import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/top_toast.dart';
import 'message_detail_screen.dart';
import 'support_request_screen.dart';

class MessageCenterScreen extends StatefulWidget {
  const MessageCenterScreen({super.key});

  @override
  State<MessageCenterScreen> createState() => _MessageCenterScreenState();
}

class _MessageCenterScreenState extends State<MessageCenterScreen> {
  late Stream<List<MessageModel>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirestoreService().getMessagesStream();
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} ngày trước';
    if (diff.inHours > 0) return '${diff.inHours} giờ trước';
    if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
    return 'Vừa xong';
  }

  Map<String, dynamic> _getCategoryInfo(String title, int iconCode) {
    final lower = title.toLowerCase();
    if (lower.contains('hỗ trợ') || lower.contains('kỹ thuật') || lower.contains('ticket') || lower.contains('yêu cầu')) {
      return {
        'label': 'Hỗ trợ',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.support_agent_rounded,
      };
    }
    if (lower.contains('bảo mật') || lower.contains('đăng nhập') || lower.contains('mật khẩu') || lower.contains('cảnh báo')) {
      return {
        'label': 'Bảo mật',
        'color': const Color(0xFFEF4444),
        'icon': Icons.shield_rounded,
      };
    }
    if (lower.contains('số dư') || lower.contains('ví') || lower.contains('giao dịch') || lower.contains('tiền')) {
      return {
        'label': 'Biến động',
        'color': const Color(0xFF10B981),
        'icon': Icons.account_balance_wallet_rounded,
      };
    }
    return {
      'label': 'Hệ thống',
      'color': const Color(0xFF3B82F6),
      'icon': Icons.notifications_active_rounded,
    };
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
                    'Hòm thư tin nhắn',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 24),
                    tooltip: 'Gửi yêu cầu hỗ trợ',
                    onPressed: () => Navigator.push(
                      context,
                      PageTransitions.slideRight(const SupportRequestScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF438883)),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF438883).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mail_outline_rounded, size: 40, color: Color(0xFF438883)),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Hòm thư đang trống',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bạn chưa có thông báo hoặc phản hồi hỗ trợ nào. Khi có tin nhắn từ hệ thống hoặc CSKH, chúng sẽ hiển thị tại đây.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      itemCount: messages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final timeStr = _formatRelativeTime(msg.createdAt);
                        final catInfo = _getCategoryInfo(msg.title, msg.iconCode);
                        final Color catColor = catInfo['color'] as Color;
                        final String catLabel = catInfo['label'] as String;
                        final IconData itemIcon = IconData(msg.iconCode, fontFamily: 'MaterialIcons');

                        return Dismissible(
                          key: Key(msg.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            FirestoreService().deleteMessage(msg.id);
                            TopToast.show(context, 'Đã xóa tin nhắn');
                          },
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageTransitions.slideRight(
                                  MessageDetailScreen(
                                    icon: itemIcon,
                                    iconBgColor: catColor,
                                    title: msg.title,
                                    time: timeStr,
                                    fullMessage: msg.fullMessage.isNotEmpty ? msg.fullMessage : msg.shortMessage,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Squircle Icon with category badge
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(itemIcon, color: catColor, size: 24),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Category Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: catColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                catLabel,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: catColor,
                                                ),
                                              ),
                                            ),
                                            // Timestamp & Unread Indicator
                                            Row(
                                              children: [
                                                Text(
                                                  timeStr,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                                                  ),
                                                ),
                                                if (msg.isUnread) ...[
                                                  const SizedBox(width: 6),
                                                   Container(
                                                     width: 8,
                                                     height: 8,
                                                     decoration: BoxDecoration(
                                                       shape: BoxShape.circle,
                                                       color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF438883),
                                                     ),
                                                   ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          msg.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: msg.isUnread ? FontWeight.bold : FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          msg.shortMessage,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
