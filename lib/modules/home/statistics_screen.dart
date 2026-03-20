import 'package:flutter/material.dart';
import 'export_report_screen.dart'; // Đảm bảo đường dẫn đúng với file vừa tạo

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Mặc định chọn "Ngày" (index = 0)
  int _selectedTimeIndex = 0;

  // Danh sách các tab thời gian
  final List<String> _timeFilters = ['Ngày', 'Tuần', 'Tháng', 'Năm'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. CUSTOM APP BAR (Đã xóa nút Back)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Khoảng trống tàng hình để giữ chữ "Thống Kê" căn giữa hoàn hảo
                  const SizedBox(width: 40),

                  const Text(
                    'Thống Kê',
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  // Nút tải báo cáo bên góc phải
                  IconButton(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF222222),
                      size: 24,
                    ),
                    onPressed: () {
                      // GỌI TRANG TẢI BÁO CÁO MỚI TẠO VÀO ĐÂY
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExportReportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. THANH CHỌN THỜI GIAN (Ngày / Tuần / Tháng / Năm)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_timeFilters.length, (index) {
                  bool isSelected = _selectedTimeIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTimeIndex = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF438883)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _timeFilters[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // 3. NÚT CHỌN LOẠI GIAO DỊCH (Chi phí / Thu nhập) - Nằm góc phải
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Chi phí',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF666666),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // NỘI DUNG CUỘN BÊN DƯỚI (Biểu đồ + Danh sách)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4. BIỂU ĐỒ
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Tổng chi tiêu',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '9.320.287.362 đ',
                            style: TextStyle(
                              color: Color(0xFF438883),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Icon(
                            Icons.bar_chart,
                            size: 80,
                            color: const Color(0xFF438883).withOpacity(0.2),
                          ),
                          const Text(
                            '(Khu vực hiển thị biểu đồ)',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 5. TIÊU ĐỀ: CHI TIÊU HÀNG ĐẦU
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Chi tiêu hàng đầu',
                          style: TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.swap_vert, color: Color(0xFF666666)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 6. DANH SÁCH CHI TIÊU
                    _buildSpendingItem(
                      icon: Icons.local_cafe,
                      title: 'Starbucks',
                      date: 'Th1 12, 2022',
                      amount: '- 3.932.992 đ',
                      isHighlight: false,
                    ),
                    _buildSpendingItem(
                      icon: Icons.swap_horiz,
                      title: 'Transfer',
                      date: 'Hôm qua',
                      amount: '- 2.228.695 đ',
                      isHighlight: true,
                    ),
                    _buildSpendingItem(
                      icon: Icons.play_arrow,
                      title: 'Youtube',
                      date: 'Th1 16, 2022',
                      amount: '- 314.639 đ',
                      isHighlight: false,
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM TẠO ITEM CHI TIÊU HÀNG ĐẦU ---
  Widget _buildSpendingItem({
    required IconData icon,
    required String title,
    required String date,
    required String amount,
    required bool isHighlight,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFF29756F) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: const Color(0xFF29756F).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighlight
                  ? Colors.white.withOpacity(0.15)
                  : const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isHighlight ? Colors.white : const Color(0xFF666666),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isHighlight ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: isHighlight
                        ? const Color(0xFFEEEEEE)
                        : const Color(0xFF666666),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Text(
            amount,
            style: TextStyle(
              color: isHighlight ? Colors.white : const Color(0xFFF95B51),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
