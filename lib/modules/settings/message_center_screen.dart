import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/message_model.dart';
import 'message_detail_screen.dart'; // Đảm bảo import trang chi tiết vừa tạo
import 'support_request_screen.dart'; // Đảm bảo import trang Gửi yêu cầu hỗ trợ

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR ĐÃ ĐƯỢC CHỈNH SỬA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Tin nhắn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // ĐÂY LÀ NÚT DẤU CỘNG MỚI THÊM VÀO
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SupportRequestScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF438883)));
                    }
                    
                    final messages = snapshot.data ?? [];
                    
                    return ListView(
                      padding: const EdgeInsets.only(bottom: 60),
                      children: [
                        if (messages.isNotEmpty) _buildTimeHeader('MỚI NHẤT'),
                        ...messages.map((msg) {
                          String timeStr = 'Vừa xong';
                          final diff = DateTime.now().difference(msg.createdAt);
                          if (diff.inDays > 0) timeStr = '${diff.inDays} ngày trước';
                          else if (diff.inHours > 0) timeStr = '${diff.inHours} giờ trước';
                          else if (diff.inMinutes > 0) timeStr = '${diff.inMinutes} phút trước';
                          
                          return Dismissible(
                            key: Key(msg.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.red.shade400,
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                            ),
                            onDismissed: (direction) {
                              FirestoreService().deleteMessage(msg.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã xóa tin nhắn')),
                              );
                            },
                            child: Column(
                              children: [
                                _buildMessageItem(
                                  context: context,
                                  icon: IconData(msg.iconCode, fontFamily: 'MaterialIcons'),
                                  iconBgColor: Color(msg.iconBgColorValue),
                                  title: msg.title,
                                  shortMessage: msg.shortMessage,
                                  fullMessage: msg.fullMessage,
                                  time: timeStr,
                                  isUnread: msg.isUnread,
                                ),
                                _buildDivider(),
                              ],
                            ),
                          );
                        }),
                        
                        // NHÓM TRƯỚC ĐÓ (Dữ liệu mẫu để màn hình không trống)
                        _buildTimeHeader('TRƯỚC ĐÓ'),
                        _buildMessageItem(
                          context: context,
                          icon: Icons.support_agent,
                          iconBgColor: const Color(0xFFFF9800),
                          title: 'Phản hồi yêu cầu #12940',
                          shortMessage: 'Kỹ thuật đã xử lý xong yêu cầu của bạn.',
                          fullMessage:
                              'Xin chào,\n\nChúng tôi xin thông báo rằng yêu cầu hỗ trợ mã số #12940 của bạn về việc "Kiểm tra giao dịch bị treo" đã được bộ phận kỹ thuật xử lý thành công.\n\nSố tiền giao dịch đã được hoàn về ví của bạn. Vui lòng kiểm tra lại số dư.\n\nCảm ơn bạn đã kiên nhẫn chờ đợi và sử dụng dịch vụ của chúng tôi!',
                          time: '8 giờ trước',
                          isUnread: true,
                        ),
                        _buildDivider(),
                        _buildMessageItem(
                          context: context,
                          icon: Icons.build_circle,
                          iconBgColor: const Color(0xFF4CAF50),
                          title: 'Bảo trì hệ thống định kỳ',
                          shortMessage:
                              'Dịch vụ nâng cấp từ 01:00 đến 03:00 sáng mai.',
                          fullMessage:
                              'Thông báo bảo trì hệ thống định kỳ,\n\nĐể nâng cao chất lượng dịch vụ và tối ưu hóa hệ thống bảo mật, chúng tôi sẽ tiến hành bảo trì máy chủ từ 01:00 đến 03:00 sáng ngày mai.\n\nTrong khoảng thời gian này, các tính năng chuyển tiền và thanh toán có thể bị gián đoạn. \n\nMong bạn thông cảm cho sự bất tiện này.',
                          time: 'Hôm qua',
                          isUnread: true,
                        ),
                        _buildDivider(),
                        _buildMessageItem(
                          context: context,
                          icon: Icons.article_outlined,
                          iconBgColor: const Color(0xFF009688),
                          title: 'Thông báo chính sách mới',
                          shortMessage:
                              'Cập nhật điều khoản sử dụng dịch vụ mới, hiệu lực từ...',
                          fullMessage:
                              'Kính gửi quý khách,\n\nChúng tôi vừa cập nhật một số điều khoản mới trong Chính sách bảo mật và Điều khoản sử dụng dịch vụ.\n\nCác thay đổi này nhằm tuân thủ quy định mới của pháp luật và bảo vệ tốt hơn dữ liệu người dùng. Những thay đổi này sẽ có hiệu lực từ ngày 01/06.\n\nBạn có thể vào phần Cài đặt > Chính sách bảo mật để xem chi tiết.',
                          time: 'Hôm qua',
                          isUnread: false,
                        ),
                        _buildDivider(),
                        _buildMessageItem(
                          context: context,
                          icon: Icons.security,
                          iconBgColor: const Color(0xFF2196F3),
                          title: 'Cảnh báo bảo mật',
                          shortMessage:
                              'Phát hiện đăng nhập lạ từ trình duyệt Chrome trên Windows...',
                          fullMessage:
                              'Cảnh báo bảo mật tài khoản!\n\nHệ thống ghi nhận một lượt đăng nhập mới vào tài khoản của bạn:\n• Thiết bị: Windows PC - Chrome\n• Vị trí: Đà Nẵng, Việt Nam\n• Thời gian: 3 ngày trước\n\nNếu đây không phải là bạn, vui lòng đổi mật khẩu ngay lập tức để bảo vệ tài khoản!',
                          time: 'Hôm qua',
                          isUnread: false,
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --- HÀM TẠO TỪNG DÒNG TIN NHẮN ---
  Widget _buildMessageItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String shortMessage,
    required String fullMessage, // Chứa nội dung chi tiết
    required String time,
    required bool isUnread,
  }) {
    return InkWell(
      onTap: () {
        // MỞ TRANG CHI TIẾT VÀ TRUYỀN DỮ LIỆU SANG ĐÓ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MessageDetailScreen(
              icon: icon,
              iconBgColor: iconBgColor,
              title: title,
              time: time,
              fullMessage: fullMessage, // Truyền nội dung dài sang
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF212121),
                      fontSize: 16,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortMessage, // Hiển thị tin vắn tắt ở ngoài
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Text(
              time,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      color: Color(0xFFEEEEEE),
      indent: 84,
      endIndent: 20,
    );
  }
}
