import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/message_model.dart';
import 'success_screen.dart';
import '../../widgets/mono_toast.dart';
import '../../services/language_service.dart';

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  // Danh sách các chủ đề hỗ trợ
  final List<String> _topics = [
    'Vấn đề tài khoản',
    'Góp ý tính năng',
    'Lỗi hệ thống',
    'Khác',
  ];

  String _getTopicLabel(String topic, bool isVi) {
    if (isVi) return topic;
    switch (topic) {
      case 'Vấn đề tài khoản':
        return 'Account issue';
      case 'Góp ý tính năng':
        return 'Feature feedback';
      case 'Lỗi hệ thống':
        return 'System bug';
      case 'Khác':
        return 'Other';
      default:
        return topic;
    }
  }

  // ĐÃ SỬA: Gán giá trị mặc định là phần tử đầu tiên của mảng _topics
  late String _selectedTopic = _topics[0];
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : context.brandColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR
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
                  Text(
                    isVi ? 'Gửi yêu cầu hỗ trợ' : 'Submit Support Request',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Cân bằng với nút Back
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. KHUNG NỘI DUNG MÀU TRẮNG BO GÓC
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Chúng tôi có thể giúp gì cho bạn?' : 'How can we help you?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isVi
                            ? 'Vui lòng mô tả chi tiết vấn đề bạn đang gặp phải, đội ngũ CSKH sẽ phản hồi trong thời gian sớm nhất.'
                            : 'Please describe the problem you are encountering, our support team will respond as soon as possible.',
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // CHỌN CHỦ ĐỀ
                      _buildLabel(isVi ? 'Chủ đề' : 'Topic'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTopic,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.brandColor,
                        ),
                        decoration: _buildInputDecoration(context),
                        items: _topics.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(_getTopicLabel(value, isVi)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedTopic = newValue!;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // TIÊU ĐỀ
                      _buildLabel(isVi ? 'Tiêu đề' : 'Title'),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 16, color: context.colors.onSurface),
                        decoration: _buildInputDecoration(
                          context,
                          hintText: isVi ? 'Nhập tiêu đề ngắn gọn' : 'Enter brief title',
                        ),
                      ),

                      const SizedBox(height: 20),

                      // NỘI DUNG CHI TIẾT
                      _buildLabel(isVi ? 'Nội dung chi tiết' : 'Detailed description'),
                      TextFormField(
                        controller: _detailsController,
                        maxLines: 5,
                        style: TextStyle(fontSize: 16, height: 1.5, color: context.colors.onSurface),
                        decoration: _buildInputDecoration(
                          context,
                          hintText: isVi ? 'Mô tả chi tiết vấn đề của bạn...' : 'Describe your problem in detail...',
                        ),
                      ),

                      const SizedBox(height: 40),

                      // NÚT GỬI YÊU CẦU
                      InkWell(
                        onTap: _isLoading ? null : () async {
                          if (_titleController.text.trim().isEmpty || _detailsController.text.trim().isEmpty) {
                            MonoToast.warning(
                              context,
                              isVi
                                  ? 'Vui lòng nhập đầy đủ tiêu đề và nội dung!'
                                  : 'Please enter both title and content!',
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            // Tạo tin nhắn tự động phản hồi
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final randomId = Random().nextInt(90000) + 10000;
                              final message = MessageModel(
                                uid: user.uid,
                                iconCode: Icons.headset_mic.codePoint,
                                iconBgColorValue: 0xFF6C5CE7,
                                title: isVi ? 'Hỗ trợ khách hàng #$randomId' : 'Customer Support #$randomId',
                                shortMessage: isVi
                                    ? 'Yêu cầu hỗ trợ của bạn đã được tiếp nhận.'
                                    : 'Your support request has been received.',
                                fullMessage: isVi
                                    ? 'Chào bạn,\n\nYêu cầu hỗ trợ về "${_titleController.text.trim()}" (Mã số: #$randomId) của bạn đã được gửi đến bộ phận Chăm sóc khách hàng. Tư vấn viên của chúng tôi sẽ liên hệ lại với bạn trong vòng 24 giờ tới.\n\nTrân trọng!'
                                    : 'Hello,\n\nYour support request regarding "${_titleController.text.trim()}" (ID: #$randomId) has been sent to Customer Support. An agent will contact you within the next 24 hours.\n\nBest regards!',
                              );
                              await _firestoreService.addMessage(message);
                            }

                            if (!context.mounted) return;
                            
                            // GỬI THÀNH CÔNG -> GỌI TRANG SUCCESS_SCREEN ĐA NĂNG
                            Navigator.push(
                              context,
                              PageTransitions.scale(
                                SuccessScreen(
                                  appBarTitle: isVi ? 'Gửi yêu cầu' : 'Submit Request',
                                  successTitle: isVi ? 'Gửi yêu cầu thành công' : 'Request Sent Successfully',
                                  successMessage: isVi
                                      ? 'Yêu cầu của bạn đã được chuyển đến bộ phận Chăm sóc khách hàng. Chúng tôi sẽ phản hồi sớm nhất có thể.'
                                      : 'Your request has been forwarded to our support team. We will respond as soon as possible.',
                                  buttonText: isVi ? 'Quay lại Hộp thư' : 'Back to Inbox',
                                  onButtonPressed: () {
                                    int count = 0;
                                    Navigator.popUntil(context, (route) {
                                      return count++ == 2;
                                    });
                                  },
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            MonoToast.error(
                              context,
                              isVi ? 'Có lỗi xảy ra: $e' : 'An error occurred: $e',
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoading ? context.colors.onSurfaceVariant.withValues(alpha: 0.3) : context.brandColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: context.brandColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isVi ? 'Gửi yêu cầu' : 'Submit Request',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
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

  // Hàm phụ tạo Label cho gọn
  Widget _buildLabel(String text) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Hàm phụ tạo khung Input viền đồng bộ
  InputDecoration _buildInputDecoration(BuildContext context, {String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: context.colors.onSurfaceVariant.withValues(alpha: 0.5),
        fontSize: 15,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: context.cardBg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: context.borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.brandColor, width: 1.5),
      ),
    );
  }
}
