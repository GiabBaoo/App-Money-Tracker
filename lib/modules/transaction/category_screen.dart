import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../models/user_model.dart';
import '../../utils/category_utils.dart';
import '../../features/group_expense/presentation/screens/group_list_screen.dart';
import '../../utils/page_transitions.dart';
import '../../services/language_service.dart';
import '../../widgets/top_toast.dart';

class CategoryScreen extends StatefulWidget {
  final bool isIncome;
  const CategoryScreen({super.key, required this.isIncome});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserRepository _userRepo = UserRepository();
  late bool _isIncomeTab;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<IconData> _expenseIcons = [
    Icons.restaurant_outlined, Icons.medical_services_outlined, Icons.directions_car_outlined,
    Icons.menu_book_outlined, Icons.shopping_bag_outlined, Icons.home_outlined,
    Icons.pets_outlined, Icons.receipt_long_outlined, Icons.local_activity_outlined,
    Icons.flight_outlined, Icons.favorite_outline, Icons.card_giftcard_outlined,
    Icons.spa_outlined, Icons.water_drop_outlined, Icons.flash_on_outlined,
    Icons.child_care_outlined, Icons.checkroom_outlined, Icons.phone_android_outlined,
    Icons.coffee_outlined, Icons.sports_esports_outlined, Icons.fitness_center_outlined,
    Icons.movie_outlined, Icons.sports_soccer_outlined, Icons.local_gas_station_outlined,
    Icons.build_outlined, Icons.savings_outlined, Icons.volunteer_activism_outlined,
    Icons.shield_outlined, Icons.devices_other_outlined, Icons.credit_card_outlined,
    Icons.celebration_outlined, Icons.school_outlined, Icons.home_repair_service_outlined,
  ];

  final List<IconData> _incomeIcons = [
    Icons.work_outline, Icons.bar_chart_outlined, Icons.storefront_outlined,
    Icons.volunteer_activism_outlined, Icons.sell_outlined, Icons.account_balance_wallet_outlined,
    Icons.savings_outlined, Icons.payments_outlined, Icons.trending_up_outlined,
    Icons.monetization_on_outlined, Icons.redeem_outlined, Icons.attach_money_outlined,
    Icons.price_change_outlined, Icons.account_balance_outlined, Icons.real_estate_agent_outlined,
    Icons.currency_exchange_outlined, Icons.currency_bitcoin_outlined,
    Icons.handshake_outlined, Icons.laptop_chromebook_outlined, Icons.school_outlined,
    Icons.replay_circle_filled_rounded,
  ];

  final List<String> _expenseGroups = ['Thiết yếu', 'Phát triển', 'Hưởng thụ', 'Khác'];
  final List<String> _incomeGroups = ['Thu nhập chính', 'Thu nhập phụ', 'Khác'];

  final List<Color> _paletteColors = [
    const Color(0xFF10B981), // Emerald
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFF43F5E), // Rose
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFFF97316), // Orange
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEC4899), // Pink
    const Color(0xFF84CC16), // Lime
    const Color(0xFF64748B), // Slate
  ];

  @override
  void initState() {
    super.initState();
    _isIncomeTab = widget.isIncome;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ════════ DEFAULT CATEGORIES DATA ════════

  Map<String, List<Map<String, dynamic>>> get _defaultExpenseGroups => {
    'Thiết yếu': [
      {'name': 'Ăn uống', 'icon': Icons.restaurant_outlined, 'group': 'Thiết yếu', 'desc': 'Ăn sáng, trưa, tối, cafe'},
      {'name': 'Sức khỏe', 'icon': Icons.medical_services_outlined, 'group': 'Thiết yếu', 'desc': 'Thuốc, khám bệnh, vitamin'},
      {'name': 'Di chuyển', 'icon': Icons.directions_car_outlined, 'group': 'Thiết yếu', 'desc': 'Xăng, xe bus, grab'},
      {'name': 'Tiền nhà', 'icon': Icons.home_outlined, 'group': 'Thiết yếu', 'desc': 'Thuê nhà, chung cư'},
      {'name': 'Tiền điện', 'icon': Icons.water_drop_outlined, 'group': 'Thiết yếu', 'desc': 'Điện, nước, internet'},
      {'name': 'Điện thoại', 'icon': Icons.phone_android_outlined, 'group': 'Thiết yếu', 'desc': 'Cước, nạp thẻ'},
      {'name': 'Sửa chữa', 'icon': Icons.build_outlined, 'group': 'Thiết yếu', 'desc': 'Sửa xe, sửa nhà, bảo dưỡng'},
    ],
    'Phát triển': [
      {'name': 'Học tập', 'icon': Icons.menu_book_outlined, 'group': 'Phát triển', 'desc': 'Sách, khóa học, học phí'},
      {'name': 'Thể thao', 'icon': Icons.fitness_center_outlined, 'group': 'Phát triển', 'desc': 'Gym, bơi, yoga'},
      {'name': 'Tiết kiệm', 'icon': Icons.savings_outlined, 'group': 'Phát triển', 'desc': 'Gửi ngân hàng, heo đất'},
      {'name': 'Bảo hiểm', 'icon': Icons.shield_outlined, 'group': 'Phát triển', 'desc': 'Bảo hiểm nhân thọ, xe'},
      {'name': 'Trả nợ', 'icon': Icons.credit_card_outlined, 'group': 'Phát triển', 'desc': 'Trả góp, trả nợ vay'},
    ],
    'Hưởng thụ': [
      {'name': 'Mua sắm', 'icon': Icons.shopping_bag_outlined, 'group': 'Hưởng thụ', 'desc': 'Quần áo, giày dép'},
      {'name': 'Giải trí', 'icon': Icons.local_activity_outlined, 'group': 'Hưởng thụ', 'desc': 'Phim, game, karaoke'},
      {'name': 'Du lịch', 'icon': Icons.flight_outlined, 'group': 'Hưởng thụ', 'desc': 'Khách sạn, tour'},
      {'name': 'Quà tặng', 'icon': Icons.card_giftcard_outlined, 'group': 'Hưởng thụ', 'desc': 'Sinh nhật, lễ, đám cưới'},
      {'name': 'Làm đẹp', 'icon': Icons.spa_outlined, 'group': 'Hưởng thụ', 'desc': 'Spa, cắt tóc, nail'},
      {'name': 'Đồ công nghệ', 'icon': Icons.devices_other_outlined, 'group': 'Hưởng thụ', 'desc': 'Laptop, điện thoại, phụ kiện'},
    ],
    'Khác': [
      {'name': 'Thú cưng', 'icon': Icons.pets_outlined, 'group': 'Khác', 'desc': 'Thức ăn, thú y'},
      {'name': 'Con cái', 'icon': Icons.child_care_outlined, 'group': 'Khác', 'desc': 'Bỉm, sữa, học phí'},
      {'name': 'Từ thiện', 'icon': Icons.volunteer_activism_outlined, 'group': 'Khác', 'desc': 'Quyên góp, ủng hộ'},
      {'name': 'Chi khác', 'icon': Icons.receipt_long_outlined, 'group': 'Khác', 'desc': 'Các khoản chi khác'},
    ],
  };

  Map<String, List<Map<String, dynamic>>> get _defaultIncomeGroups => {
    'Thu nhập chính': [
      {'name': 'Tiền lương', 'icon': Icons.work_outline, 'group': 'Thu nhập chính', 'desc': 'Lương tháng, tiền công'},
      {'name': 'Tiền thưởng', 'icon': Icons.card_giftcard_outlined, 'group': 'Thu nhập chính', 'desc': 'KPI, bonus, hoa hồng'},
      {'name': 'Kinh doanh', 'icon': Icons.storefront_outlined, 'group': 'Thu nhập chính', 'desc': 'Doanh thu, lợi nhuận'},
      {'name': 'Đầu tư', 'icon': Icons.trending_up_outlined, 'group': 'Thu nhập chính', 'desc': 'Chứng khoán, cổ tức, crypto'},
    ],
    'Thu nhập phụ': [
      {'name': 'Được cho/Tặng', 'icon': Icons.volunteer_activism_outlined, 'group': 'Thu nhập phụ', 'desc': 'Lì xì, cho tiền, biếu'},
      {'name': 'Bán đồ', 'icon': Icons.sell_outlined, 'group': 'Thu nhập phụ', 'desc': 'Thanh lý, pass lại'},
      {'name': 'Tiền thuê nhà', 'icon': Icons.real_estate_agent_outlined, 'group': 'Thu nhập phụ', 'desc': 'Cho thuê nhà, trọ'},
      {'name': 'Tiền lãi', 'icon': Icons.monetization_on_outlined, 'group': 'Thu nhập phụ', 'desc': 'Lãi tiết kiệm ngân hàng'},
      {'name': 'Thu nợ', 'icon': Icons.handshake_outlined, 'group': 'Thu nhập phụ', 'desc': 'Được trả nợ, đòi được nợ'},
      {'name': 'Làm thêm', 'icon': Icons.laptop_chromebook_outlined, 'group': 'Thu nhập phụ', 'desc': 'Freelance, việc bán thời gian'},
    ],
    'Khác': [
      {'name': 'Trợ cấp', 'icon': Icons.school_outlined, 'group': 'Khác', 'desc': 'Học bổng, tiền trợ cấp'},
      {'name': 'Hoàn tiền', 'icon': Icons.replay_circle_filled_rounded, 'group': 'Khác', 'desc': 'Cashback, hoàn voucher'},
      {'name': 'Thu khác', 'icon': Icons.account_balance_wallet_outlined, 'group': 'Khác', 'desc': 'Trúng số, nhặt được'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // TOP HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _isIncomeTab ? 'Danh mục thu nhập' : 'Danh mục chi tiêu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Nút tạo nhanh danh mục
                  TextButton.icon(
                    onPressed: () => _showAddOrEditCategoryModal(context),
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
                    label: Text(
                      context.tr('tab_expense') == 'Chi tiêu' ? 'Tạo' : 'Add',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // BODY CONTENT
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: Column(
                    children: [
                      // THANH TÌM KIẾM
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm danh mục...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white30 : Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                        _searchFocusNode.unfocus();
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      // DANH SÁCH DANH MỤC
                      Expanded(
                        child: StreamBuilder<UserModel?>(
                          stream: _userRepo.getUserStream(),
                          builder: (context, snapshot) {
                            final user = snapshot.data;
                            final customCategories = user?.customCategories ?? [];

                            if (!_isIncomeTab) {
                              return _buildExpenseCategoryList(customCategories, user, isDark);
                            } else {
                              return _buildIncomeCategoryList(customCategories, user, isDark);
                            }
                          },
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

  // ════════ EXPENSE LIST ════════
  Widget _buildExpenseCategoryList(List<dynamic> customCategories, UserModel? user, bool isDark) {
    final Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var g in _expenseGroups) {
      groupedData[g] = List.from(_defaultExpenseGroups[g] ?? []);
    }
    for (int idx = 0; idx < customCategories.length; idx++) {
      final item = customCategories[idx];
      if (item['isIncome'] == false) {
        String group = item['group'] ?? 'Khác';
        if (!groupedData.containsKey(group)) groupedData[group] = [];
        groupedData[group]!.add({
          'name': item['name'],
          'icon': IconData(item['iconCode'], fontFamily: 'MaterialIcons'),
          'color': item['colorValue'] != null ? Color(item['colorValue']) : null,
          'isCustom': true,
          'customIndex': idx,
          'group': group,
          'desc': 'Danh mục tự tạo',
        });
      }
    }

    // Filter theo search
    if (_searchQuery.isNotEmpty) {
      for (var key in groupedData.keys) {
        groupedData[key] = groupedData[key]!.where((cat) {
          final name = (cat['name'] as String).toLowerCase();
          final desc = (cat['desc'] as String? ?? '').toLowerCase();
          return name.contains(_searchQuery) || desc.contains(_searchQuery);
        }).toList();
      }
    }

    final hasResults = groupedData.values.any((list) => list.isNotEmpty);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (!hasResults) ...[
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy danh mục "$_searchQuery"',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
        // NÚT NHÓM CHI TIÊU nổi bật (luôn hiện, không filter)
        if (_searchQuery.isEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: InkWell(
                onTap: () => Navigator.push(context, PageTransitions.slideRight(const GroupListScreen())),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1A3A38), const Color(0xFF1E4842)]
                          : [const Color(0xFFE8F5F3), const Color(0xFFD5EDE9)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF438883).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF438883).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.group_rounded, color: Color(0xFF438883), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nhóm Chi Tiêu',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Quản lý chi tiêu nhóm, quỹ chung',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white38 : Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        for (var group in _expenseGroups) ...[
          if (groupedData[group]!.isNotEmpty) ...[
            _buildSectionHeader(context.trCat(group).toUpperCase()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return _buildCategoryListItem(context, groupedData[group]![i], user, isDark);
                  },
                  childCount: groupedData[group]!.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ════════ INCOME LIST ════════
  Widget _buildIncomeCategoryList(List<dynamic> customCategories, UserModel? user, bool isDark) {
    final Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (var g in _incomeGroups) {
      groupedData[g] = List.from(_defaultIncomeGroups[g] ?? []);
    }
    for (int idx = 0; idx < customCategories.length; idx++) {
      final item = customCategories[idx];
      if (item['isIncome'] == true) {
        String group = item['group'] ?? 'Khác';
        if (!groupedData.containsKey(group)) groupedData[group] = [];
        groupedData[group]!.add({
          'name': item['name'],
          'icon': IconData(item['iconCode'], fontFamily: 'MaterialIcons'),
          'color': item['colorValue'] != null ? Color(item['colorValue']) : null,
          'isCustom': true,
          'customIndex': idx,
          'group': group,
          'desc': 'Danh mục tự tạo',
        });
      }
    }

    // Filter theo search
    if (_searchQuery.isNotEmpty) {
      for (var key in groupedData.keys) {
        groupedData[key] = groupedData[key]!.where((cat) {
          final name = (cat['name'] as String).toLowerCase();
          final desc = (cat['desc'] as String? ?? '').toLowerCase();
          return name.contains(_searchQuery) || desc.contains(_searchQuery);
        }).toList();
      }
    }

    final hasResults = groupedData.values.any((list) => list.isNotEmpty);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (!hasResults) ...[
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy danh mục "$_searchQuery"',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
        for (var group in _incomeGroups) ...[
          if (groupedData[group]!.isNotEmpty) ...[
            _buildSectionHeader(context.trCat(group).toUpperCase()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return _buildCategoryListItem(context, groupedData[group]![i], user, isDark);
                  },
                  childCount: groupedData[group]!.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ════════ UI COMPONENTS ════════

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 8),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  /// List Item kiểu mới: 2 cột (icon + tên + mô tả) — thiết kế premium
  Widget _buildCategoryListItem(BuildContext context, Map<String, dynamic> cat, UserModel? user, bool isDark) {
    final isCustom = cat['isCustom'] == true;
    final Color color = cat['color'] ?? CategoryUtils.getVibrantColor(cat['name']);
    final Color bgColor = isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08);
    final String desc = cat['desc'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context, {
              'name': cat['name'],
              'icon': cat['icon'],
              'color': color,
            });
          },
          onLongPress: isCustom && user != null
              ? () => _showCustomCategoryOptions(context, cat, user)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCustom
                    ? color.withValues(alpha: 0.3)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.12)),
                width: isCustom ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cat['icon'], color: color, size: 24),
                ),
                const SizedBox(width: 14),
                // Tên + Mô tả
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.trCat(cat['name']),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Tùy chỉnh',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          desc,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// Hiển thị tùy chọn Sửa / Xóa cho danh mục tự tạo
  void _showCustomCategoryOptions(BuildContext context, Map<String, dynamic> cat, UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  Icon(cat['icon'], color: cat['color'] ?? const Color(0xFF438883), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cat['name'],
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF438883)),
                title: Text(context.tr('edit_category_title')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddOrEditCategoryModal(
                    context,
                    isEdit: true,
                    editCategoryIndex: cat['customIndex'],
                    initialName: cat['name'],
                    initialIcon: cat['icon'],
                    initialColor: cat['color'],
                    initialGroup: cat['group'] ?? (_isIncomeTab ? _incomeGroups[0] : _expenseGroups[0]),
                    initialIsIncome: _isIncomeTab,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(context.tr('delete_category'), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: Text(context.tr('delete_category')),
                      content: Text(context.tr('confirm_delete_category')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: Text(context.tr('cancel')),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text(context.tr('delete'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _deleteCustomCategory(cat['customIndex']);
                    if (context.mounted) {
                      TopToast.show(context, context.tr('success'));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BottomSheet thêm mới hoặc chỉnh sửa danh mục hoàn chỉnh
  void _showAddOrEditCategoryModal(
    BuildContext context, {
    bool isEdit = false,
    int? editCategoryIndex,
    String? initialName,
    IconData? initialIcon,
    Color? initialColor,
    String? initialGroup,
    bool? initialIsIncome,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: initialName ?? '');
    bool isIncomeLocal = initialIsIncome ?? _isIncomeTab;
    String selectedGroup = initialGroup ?? (isIncomeLocal ? _incomeGroups[0] : _expenseGroups[0]);
    Color selectedColor = initialColor ?? _paletteColors[0];

    final icons = isIncomeLocal ? _incomeIcons : _expenseIcons;
    IconData selectedIcon = initialIcon ?? icons[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final currentIcons = isIncomeLocal ? _incomeIcons : _expenseIcons;
          final currentGroups = isIncomeLocal ? _incomeGroups : _expenseGroups;
          if (!currentIcons.contains(selectedIcon)) {
            selectedIcon = currentIcons.first;
          }
          if (!currentGroups.contains(selectedGroup)) {
            selectedGroup = currentGroups.first;
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              top: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: Theme.of(modalCtx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? context.tr('edit_category_title') : context.tr('create_category_title'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Segmented Switch: Chi tiêu vs Thu nhập
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              isIncomeLocal = false;
                              selectedIcon = _expenseIcons.first;
                              selectedGroup = _expenseGroups.first;
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: !isIncomeLocal ? const Color(0xFF438883) : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                context.tr('tab_expense'),
                                style: TextStyle(
                                  color: !isIncomeLocal ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              isIncomeLocal = true;
                              selectedIcon = _incomeIcons.first;
                              selectedGroup = _incomeGroups.first;
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isIncomeLocal ? const Color(0xFF438883) : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                context.tr('tab_income'),
                                style: TextStyle(
                                  color: isIncomeLocal ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Group Choice Chips
                  Text(
                    context.tr('select_group'),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: currentGroups.map((group) {
                        final isSelected = selectedGroup == group;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(context.trCat(group)),
                            selected: isSelected,
                            onSelected: (_) => setModalState(() => selectedGroup = group),
                            selectedColor: const Color(0xFF438883),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tên danh mục TextField
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: context.tr('category_name_hint'),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                      prefixIcon: Icon(selectedIcon, color: selectedColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bảng chọn Màu sắc
                  Text(
                    context.tr('select_color'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _paletteColors.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) {
                        final c = _paletteColors[i];
                        final isSel = selectedColor == c;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
                                  : null,
                            ),
                            child: isSel
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bảng chọn Icon
                  Text(
                    context.tr('select_icon'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: currentIcons.length,
                      itemBuilder: (ctx, i) {
                        final icon = currentIcons[i];
                        final isSelected = selectedIcon == icon;

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor
                                  : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: selectedColor.withValues(alpha: 0.4), blurRadius: 6)]
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nút Lưu danh mục
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          TopToast.show(context, context.tr('empty_category_name'), isError: true);
                          return;
                        }

                        Navigator.pop(modalCtx);

                        if (isEdit && editCategoryIndex != null) {
                          await _updateCustomCategory(
                            editCategoryIndex,
                            name: name,
                            iconCode: selectedIcon.codePoint,
                            isIncome: isIncomeLocal,
                            group: selectedGroup,
                            colorValue: selectedColor.toARGB32(),
                          );
                        } else {
                          await _saveCategory(
                            name: name,
                            iconCode: selectedIcon.codePoint,
                            isIncome: isIncomeLocal,
                            group: selectedGroup,
                            colorValue: selectedColor.toARGB32(),
                          );
                        }

                        if (context.mounted) {
                          TopToast.show(context, context.tr('success'));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF438883),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        context.tr('save_category'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Thêm danh mục mới vào SQLite và Firestore
  Future<void> _saveCategory({
    required String name,
    required int iconCode,
    required bool isIncome,
    required String? group,
    required int colorValue,
  }) async {
    final user = await _userRepo.getUser();
    final currentCustom = List<dynamic>.from(user?.customCategories ?? []);
    currentCustom.add({
      'name': name,
      'iconCode': iconCode,
      'isIncome': isIncome,
      'group': group,
      'colorValue': colorValue,
    });

    await _userRepo.updateUserProfile({'customCategories': currentCustom});
    try {
      await _firestoreService.updateUserProfile({'customCategories': currentCustom});
    } catch (_) {}
  }

  /// Cập nhật danh mục đã có
  Future<void> _updateCustomCategory(
    int index, {
    required String name,
    required int iconCode,
    required bool isIncome,
    required String? group,
    required int colorValue,
  }) async {
    final user = await _userRepo.getUser();
    final currentCustom = List<dynamic>.from(user?.customCategories ?? []);
    if (index >= 0 && index < currentCustom.length) {
      currentCustom[index] = {
        'name': name,
        'iconCode': iconCode,
        'isIncome': isIncome,
        'group': group,
        'colorValue': colorValue,
      };
      await _userRepo.updateUserProfile({'customCategories': currentCustom});
      try {
        await _firestoreService.updateUserProfile({'customCategories': currentCustom});
      } catch (_) {}
    }
  }

  /// Xóa danh mục tự tạo
  Future<void> _deleteCustomCategory(int index) async {
    final user = await _userRepo.getUser();
    final currentCustom = List<dynamic>.from(user?.customCategories ?? []);
    if (index >= 0 && index < currentCustom.length) {
      currentCustom.removeAt(index);
      await _userRepo.updateUserProfile({'customCategories': currentCustom});
      try {
        await _firestoreService.updateUserProfile({'customCategories': currentCustom});
      } catch (_) {}
    }
  }
}
