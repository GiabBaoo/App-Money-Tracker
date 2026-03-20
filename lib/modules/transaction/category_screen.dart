import 'package:flutter/material.dart';

class CategoryScreen extends StatelessWidget {
  // Thêm một biến để màn hình này biết nó đang được gọi từ Tab nào
  final bool isIncome;

  // Bắt buộc phải truyền biến isIncome vào khi gọi màn hình này
  const CategoryScreen({super.key, required this.isIncome});

  @override
  Widget build(BuildContext context) {
    // 1. DATA KHOẢN CHI
    final List<Map<String, dynamic>> expenseCategories = [
      {
        'name': 'Ăn uống',
        'icon': Icons.restaurant,
        'bgColor': const Color(0xFFFFEDD5),
        'iconColor': const Color(0xFFF97316),
      },
      {
        'name': 'Di chuyển',
        'icon': Icons.directions_car,
        'bgColor': const Color(0xFFFEF9C3),
        'iconColor': const Color(0xFFEAB308),
      },
      {
        'name': 'Quà tặng',
        'icon': Icons.card_giftcard,
        'bgColor': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFF59E0B),
      },
      {
        'name': 'Mua sắm',
        'icon': Icons.shopping_bag,
        'bgColor': const Color(0xFFFCE7F3),
        'iconColor': const Color(0xFFEC4899),
      },
      {
        'name': 'Nhà cửa',
        'icon': Icons.home,
        'bgColor': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF3B82F6),
      },
      {
        'name': 'Thú cưng',
        'icon': Icons.pets,
        'bgColor': const Color(0xFFFCE7F3),
        'iconColor': const Color(0xFFEC4899),
      },
      {
        'name': 'Hóa đơn',
        'icon': Icons.receipt_long,
        'bgColor': const Color(0xFFCCFBF1),
        'iconColor': const Color(0xFF14B8A6),
      },
      {
        'name': 'Giải trí',
        'icon': Icons.local_activity,
        'bgColor': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFF59E0B),
      },
      {
        'name': 'Du lịch',
        'icon': Icons.flight,
        'bgColor': const Color(0xFFE0F2FE),
        'iconColor': const Color(0xFF0EA5E9),
      },
      {
        'name': 'Sức khỏe',
        'icon': Icons.favorite,
        'bgColor': const Color(0xFFFEE2E2),
        'iconColor': const Color(0xFFEF4444),
      },
      {
        'name': 'Giáo dục',
        'icon': Icons.menu_book,
        'bgColor': const Color(0xFFEDE9FE),
        'iconColor': const Color(0xFF8B5CF6),
      },
    ];

    // 2. DATA KHOẢN THU (Mới thêm)
    final List<Map<String, dynamic>> incomeCategories = [
      {
        'name': 'Lương',
        'icon': Icons.work,
        'bgColor': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF3B82F6),
      },
      {
        'name': 'Thưởng',
        'icon': Icons.card_giftcard,
        'bgColor': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFF59E0B),
      },
      {
        'name': 'Cho thuê',
        'icon': Icons.home,
        'bgColor': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFF59E0B),
      },
      {
        'name': 'Tiết kiệm',
        'icon': Icons.savings,
        'bgColor': const Color(0xFFCCFBF1),
        'iconColor': const Color(0xFF14B8A6),
      },
      {
        'name': 'Quà tặng',
        'icon': Icons.redeem,
        'bgColor': const Color(0xFFFCE7F3),
        'iconColor': const Color(0xFFEC4899),
      },
      {
        'name': 'Làm thêm',
        'icon': Icons.schedule,
        'bgColor': const Color(0xFFCFFAFE),
        'iconColor': const Color(0xFF06B6D4),
      },
      {
        'name': 'Bán hàng',
        'icon': Icons.storefront,
        'bgColor': const Color(0xFFFFEDD5),
        'iconColor': const Color(0xFFF97316),
      },
      {
        'name': 'Đầu tư',
        'icon': Icons.trending_up,
        'bgColor': const Color(0xFFEDE9FE),
        'iconColor': const Color(0xFF8B5CF6),
      },
      {
        'name': 'Tiền lãi',
        'icon': Icons.account_balance,
        'bgColor': const Color(0xFFDCFCE7),
        'iconColor': const Color(0xFF22C55E),
      },
    ];

    // 3. TỰ ĐỘNG CHỌN LIST DỮ LIỆU DỰA VÀO BIẾN `isIncome`
    final currentCategories = isIncome ? incomeCategories : expenseCategories;
    final String screenTitle = isIncome
        ? 'Danh mục khoản thu'
        : 'Danh mục khoản chi';

    return Scaffold(
      backgroundColor: const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
                    screenTitle, // Tiêu đề thay đổi linh hoạt
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 30),

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
                child: GridView.builder(
                  padding: const EdgeInsets.only(
                    top: 40,
                    left: 24,
                    right: 24,
                    bottom: 40,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 30,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: currentCategories.length,
                  itemBuilder: (context, index) {
                    final cat = currentCategories[index];
                    return _buildCategoryItem(context, cat);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, Map<String, dynamic> cat) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, cat);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: cat['bgColor'],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(cat['icon'], color: cat['iconColor'], size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            cat['name'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
