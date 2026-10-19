import '../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/animated_scale_button.dart';

/// Dải gợi ý từ khóa nội dung nhanh theo từng Danh mục (Smart Note Chips)
/// Giúp người dùng chọn 1 chạm là điền xong nội dung chi tiêu mà không cần gõ bàn phím
class CategoryKeywordSuggestions extends StatelessWidget {
  final String categoryName;
  final ValueChanged<String> onSelectKeyword;
  final Color activeColor;
  final bool isDark;

  const CategoryKeywordSuggestions({
    super.key,
    required this.categoryName,
    required this.onSelectKeyword,
    required this.activeColor,
    required this.isDark,
  });

  static const Map<String, List<String>> _keywordsMap = {
    // KHOẢN CHI
    'Ăn uống': [
      'Ăn sáng',
      'Ăn trưa',
      'Ăn tối',
      'Cà phê',
      'Trà sữa',
      'Đi chợ',
      'Ăn vặt',
      'Tiệc / Nhậu',
      'Bánh mì',
      'Cơm trưa',
    ],
    'Di chuyển': [
      'Đổ xăng',
      'Grab / Be',
      'Gửi xe',
      'Rửa xe',
      'Bảo dưỡng xe',
      'Vé tàu / Xe',
      'Vé máy bay',
      'Cầu đường',
    ],
    'Mua sắm': [
      'Siêu thị',
      'Quần áo',
      'Đồ gia dụng',
      'Mỹ phẩm',
      'Shopee / Lazada',
      'Đồ công nghệ',
      'Giày dép',
    ],
    'Hóa đơn': [
      'Tiền điện',
      'Tiền nước',
      'Internet / Wifi',
      'Tiền phòng / Nhà',
      'Nạp card ĐT',
      'Phí dịch vụ',
    ],
    'Tiền nhà': [
      'Tiền thuê nhà',
      'Phí chung cư',
      'Sửa chữa nhà',
      'Nội thất',
      'Dọn dẹp',
    ],
    'Giải trí': [
      'Xem phim',
      'Chơi game',
      'Du lịch',
      'Sách báo',
      'Karaoke',
      'Bida',
      'Dã ngoại',
    ],
    'Sức khỏe': [
      'Mua thuốc',
      'Khám bệnh',
      'Nha khoa',
      'Tập gym / Yoga',
      'Vitamin',
      'Bảo hiểm',
    ],
    'Chi khác': [
      'Chi tiêu cá nhân',
      'Đám tiệc / Cưới',
      'Biếu tặng',
      'Đóng phạt',
      'Phát sinh',
    ],

    // KHOẢN THU
    'Lương': [
      'Lương tháng này',
      'Tạm ứng lương',
      'Lương làm thêm (OT)',
      'Lương dự án',
    ],
    'Tiền thưởng': [
      'Thưởng KPI',
      'Thưởng lễ / Tết',
      'Hoa hồng (Comm)',
      'Thưởng nóng',
    ],
    'Kinh doanh': [
      'Doanh thu bán hàng',
      'Khách thanh toán',
      'Tiền đặt cọc',
      'Lợi nhuận',
    ],
    'Đầu tư': [
      'Lãi chứng khoán',
      'Lãi tiền gửi',
      'Bán tài sản',
      'Cổ tức',
    ],
    'Bán đồ': [
      'Thanh lý đồ cũ',
      'Bán xe',
      'Bán điện thoại',
      'Bán phế liệu',
    ],
    'Tiền lãi': [
      'Lãi tiết kiệm',
      'Lãi suất ngân hàng',
      'Tiền cho vay',
    ],
    'Thu khác': [
      'Được tặng / Cho',
      'Đòi nợ thành công',
      'Hoàn tiền (Cashback)',
      'Trợ cấp',
    ],
  };

  static const Map<String, List<String>> _enKeywordsMap = {
    'Ăn uống': ['Breakfast', 'Lunch', 'Dinner', 'Coffee', 'Milk Tea', 'Groceries', 'Snacks', 'Dining Out'],
    'Di chuyển': ['Gasoline', 'Grab/Taxi', 'Parking', 'Car Wash', 'Maintenance', 'Bus/Train', 'Flight Ticket'],
    'Mua sắm': ['Supermarket', 'Clothes', 'Home Decor', 'Cosmetics', 'Electronics', 'Footwear'],
    'Hóa đơn': ['Electricity', 'Water', 'Internet', 'Mobile Topup', 'Service Fee'],
    'Tiền nhà': ['House Rent', 'Apartment Fee', 'Repairs', 'Furniture', 'Cleaning'],
    'Giải trí': ['Movies', 'Gaming', 'Travel', 'Books', 'Outing', 'Concert'],
    'Sức khỏe': ['Pharmacy', 'Doctor Visit', 'Vitamins', 'Gym/Yoga', 'Health Insurance'],
    'Chi khác': ['Personal', 'Wedding/Party', 'Donation', 'Fees', 'Miscellaneous'],
    'Lương': ['Monthly Salary', 'Advance Salary', 'Overtime (OT)', 'Project Payout'],
    'Tiền thưởng': ['KPI Bonus', 'Holiday Bonus', 'Commission', 'Cash Prize'],
    'Kinh doanh': ['Product Sales', 'Client Payment', 'Deposit', 'Profit'],
    'Đầu tư': ['Stock Gain', 'Deposit Interest', 'Asset Sale', 'Dividends'],
    'Bán đồ': ['Used Items', 'Vehicle Sale', 'Phone Sale', 'Recycling'],
    'Tiền lãi': ['Savings Interest', 'Bank Yield', 'Lending Interest'],
    'Thu khác': ['Gift Received', 'Debt Collected', 'Cashback', 'Allowance'],
  };

  List<String> _getKeywords(bool isVi) {
    if (isVi) {
      return _keywordsMap[categoryName] ??
          const [
            'Khoản chi tiêu',
            'Chi tiêu hàng ngày',
            'Mua đồ',
            'Phát sinh',
            'Thanh toán',
          ];
    } else {
      return _enKeywordsMap[categoryName] ??
          const [
            'Expense',
            'Daily spending',
            'Shopping',
            'Payment',
            'Other',
          ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageScope.of(context).isVietnamese;
    final keywords = _getKeywords(isVi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 13,
                color: activeColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                isVi ? 'Gợi ý nội dung nhanh (${context.trCat(categoryName)}):' : 'Quick note suggestions (${context.trCat(categoryName)}):',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: keywords.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final keyword = keywords[index];

              return AnimatedScaleButton(
                scaleDown: 0.92,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelectKeyword(keyword);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF142423)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      keyword,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
