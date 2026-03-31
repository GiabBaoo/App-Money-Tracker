import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import '../settings/success_screen.dart'; // Import trang Thành công đa năng

class ExportReportScreen extends StatefulWidget {
  const ExportReportScreen({super.key});

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  // Biến lưu trạng thái thời gian và định dạng file
  String _selectedDateRange = 'Tháng này';
  final List<String> _dateRanges = [
    'Tháng này',
    'Tháng trước',
    '3 tháng qua',
    'Năm nay',
    'Tùy chỉnh',
  ];

  String _selectedFormat = 'PDF'; // Mặc định chọn PDF

  // BIẾN MỚI: Lưu trữ khoảng thời gian do người dùng tự chọn
  DateTimeRange? _customDateRange;

  // HÀM MỚI: Mở lịch để chọn khoảng thời gian
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // Cho phép lùi về năm 2020
      lastDate: DateTime.now(), // Ngày lớn nhất là hôm nay
      helpText: 'Chọn khoảng thời gian',
      cancelText: 'HỦY',
      confirmText: 'CHỌN',
      builder: (context, child) {
        // Tô màu bộ lịch cho tone-sur-tone với app
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF438883), // Màu nền header
              onPrimary: Colors.white, // Màu chữ header
              onSurface: Color(0xFF333333), // Màu chữ ngày tháng
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
    }
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
                    'Tải báo cáo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Tàng hình để cân bằng
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
                      // Tiêu đề
                      const Text(
                        'Tùy chọn tải xuống',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chọn thời gian và định dạng file bạn muốn xuất để lưu trữ dữ liệu thống kê.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // CHỌN THỜI GIAN (Dropdown)
                      _buildLabel('Thời gian xuất báo cáo'),
                      DropdownButtonFormField<String>(
                        value: _selectedDateRange,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF438883),
                        ),
                        decoration: _buildInputDecoration(),
                        items: _dateRanges.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedDateRange = newValue!;
                          });
                          // ĐÃ BỔ SUNG: Mở lịch ngay khi người dùng vừa chọn "Tùy chỉnh"
                          if (newValue == 'Tùy chỉnh') {
                            _pickDateRange();
                          }
                        },
                      ),

                      // ĐÃ BỔ SUNG: Hiện ô chọn ngày nếu người dùng đang ở chế độ "Tùy chỉnh"
                      if (_selectedDateRange == 'Tùy chỉnh') ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _pickDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: const Color(0xFF438883),
                                width: 1.2,
                              ), // Viền xanh nổi bật
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _customDateRange == null
                                      ? 'Bấm để chọn ngày...'
                                      : '${_customDateRange!.start.day.toString().padLeft(2, '0')}/${_customDateRange!.start.month.toString().padLeft(2, '0')}/${_customDateRange!.start.year}  -  ${_customDateRange!.end.day.toString().padLeft(2, '0')}/${_customDateRange!.end.month.toString().padLeft(2, '0')}/${_customDateRange!.end.year}',
                                  style: TextStyle(
                                    color: _customDateRange == null
                                        ? const Color(0xFFAAAAAA)
                                        : const Color(0xFF333333),
                                    fontSize: 15,
                                    fontWeight: _customDateRange == null
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF438883),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // CHỌN ĐỊNH DẠNG FILE (Nút chọn PDF hoặc Excel)
                      _buildLabel('Định dạng tệp'),
                      Row(
                        children: [
                          _buildFormatCard(
                            title: 'PDF',
                            icon: Icons.picture_as_pdf,
                            color: const Color(0xFFE63946), // Đỏ
                            isSelected: _selectedFormat == 'PDF',
                            onTap: () =>
                                setState(() => _selectedFormat = 'PDF'),
                          ),
                          const SizedBox(width: 16),
                          _buildFormatCard(
                            title: 'Excel',
                            icon: Icons.table_chart,
                            color: const Color(0xFF2EAF7D), // Xanh lá
                            isSelected: _selectedFormat == 'Excel',
                            onTap: () =>
                                setState(() => _selectedFormat = 'Excel'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // NÚT TẢI XUỐNG
                      InkWell(
                        onTap: () {
                          // Bắt lỗi nếu chọn Tùy chỉnh mà quên chưa chọn ngày
                          if (_selectedDateRange == 'Tùy chỉnh' &&
                              _customDateRange == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Vui lòng chọn khoảng thời gian!',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // TẢI THÀNH CÔNG -> GỌI TRANG SUCCESS_SCREEN
                          Navigator.push(
                            context,
                            PageTransitions.scale(
                              SuccessScreen(
                                appBarTitle: 'Tải báo cáo',
                                successTitle: 'Tải xuống thành công',
                                successMessage:
                                    'Báo cáo thống kê của bạn (định dạng $_selectedFormat) đã được lưu thành công vào thư mục Tải xuống trên thiết bị.',
                                buttonText: 'Quay lại Thống kê',
                                onButtonPressed: () {
                                  // Lùi về trang Thống kê (lùi 2 bước)
                                  int count = 0;
                                  Navigator.popUntil(context, (route) {
                                    return count++ == 2;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883), // Màu xanh chủ đạo
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.download,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tải xuống ngay',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

  // --- Hàm phụ: Thẻ chọn định dạng file ---
  Widget _buildFormatCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.1)
                : const Color(0xFFF9FAFB),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : const Color(0xFFAAAAAA),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF666666),
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Hàm phụ: Label ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- Hàm phụ: Khung Input ---
  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
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
