import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/message_model.dart';
import 'success_screen.dart'; // Import trang Thành Công đa năng của bạn

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
    return Scaffold(
      backgroundColor: const Color(0xFF438883), // Nền xanh lá mạ
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
                  const Text(
                    'Gửi yêu cầu hỗ trợ',
                    style: TextStyle(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chúng tôi có thể giúp gì cho bạn?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng mô tả chi tiết vấn đề bạn đang gặp phải, đội ngũ CSKH sẽ phản hồi trong thời gian sớm nhất.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // CHỌN CHỦ ĐỀ
                      _buildLabel('Chủ đề'),
                      DropdownButtonFormField<String>(
                        value: _selectedTopic,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF438883),
                        ),
                        decoration: _buildInputDecoration(),
                        items: _topics.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
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
                      _buildLabel('Tiêu đề'),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 16),
                        decoration: _buildInputDecoration(
                          hintText: 'Nhập tiêu đề ngắn gọn',
                        ),
                      ),

                      const SizedBox(height: 20),

                      // NỘI DUNG CHI TIẾT
                      _buildLabel('Nội dung chi tiết'),
                      TextFormField(
                        controller: _detailsController,
                        maxLines: 5, // Cho phép nhập nhiều dòng
                        style: const TextStyle(fontSize: 16, height: 1.5),
                        decoration: _buildInputDecoration(
                          hintText: 'Mô tả chi tiết vấn đề của bạn...',
                        ),
                      ),

                      const SizedBox(height: 40),

                      // NÚT GỬI YÊU CẦU
                      InkWell(
                        onTap: _isLoading ? null : () async {
                          if (_titleController.text.trim().isEmpty || _detailsController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Vui lòng nhập đầy đủ tiêu đề và nội dung!'),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            // Tạo tin nhắn tự động phản hồi
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              final randomId = Random().nextInt(90000) + 10000; // random 10000 -> 99999
                              final message = MessageModel(
                                uid: user.uid,
                                iconCode: Icons.headset_mic.codePoint,
                                iconBgColorValue: 0xFF6C5CE7,
                                title: 'Hỗ trợ khách hàng #$randomId',
                                shortMessage: 'Yêu cầu hỗ trợ của bạn đã được tiếp nhận.',
                                fullMessage: 'Chào bạn,\n\nYêu cầu hỗ trợ về "${_titleController.text.trim()}" (Mã số: #$randomId) của bạn đã được gửi đến bộ phận Chăm sóc khách hàng. Tư vấn viên của chúng tôi sẽ liên hệ lại với bạn trong vòng 24 giờ tới.\n\nTrân trọng!',
                              );
                              await _firestoreService.addMessage(message);
                            }

                            if (!context.mounted) return;
                            
                            // GỬI THÀNH CÔNG -> GỌI TRANG SUCCESS_SCREEN ĐA NĂNG
                            Navigator.push(
                              context,
                              PageTransitions.scale(
                                SuccessScreen(
                                  appBarTitle: 'Gửi yêu cầu',
                                  successTitle: 'Gửi yêu cầu thành công',
                                  successMessage:
                                      'Yêu cầu của bạn đã được chuyển đến bộ phận Chăm sóc khách hàng. Chúng tôi sẽ phản hồi sớm nhất có thể.',
                                  buttonText: 'Quay lại Hộp thư',
                                  onButtonPressed: () {
                                    // Bấm nút thì lùi về 2 bước (về lại trang Trung tâm tin nhắn)
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Có lỗi xảy ra: $e'),
                                backgroundColor: Colors.red.shade600,
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : const Color(0xFF4A9B7F), // Màu xanh hoặc xám
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A9B7F).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text(
                                    'Gửi yêu cầu',
                                    style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Hàm phụ tạo khung Input viền xanh cho đồng bộ
  InputDecoration _buildInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: const Color(0xFFF9FAFB), // Nền xám cực nhạt
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
      ),
    );
  }
}
