import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../utils/category_utils.dart';
import '../../features/group_expense/presentation/screens/group_list_screen.dart';
import '../../utils/page_transitions.dart';

class CategoryScreen extends StatefulWidget {
  final bool isIncome;
  const CategoryScreen({super.key, required this.isIncome});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late bool _isIncomeTab;

  final List<IconData> _expenseIcons = [
    Icons.restaurant_outlined, Icons.medical_services_outlined, Icons.directions_car_outlined,
    Icons.menu_book_outlined, Icons.shopping_bag_outlined, Icons.home_outlined,
    Icons.pets_outlined, Icons.receipt_long_outlined, Icons.local_activity_outlined,
    Icons.flight_outlined, Icons.favorite_outline, Icons.card_giftcard_outlined,
    Icons.spa_outlined, Icons.water_drop_outlined, Icons.flash_on_outlined,
    Icons.child_care_outlined, Icons.checkroom_outlined, Icons.phone_android_outlined,
    Icons.coffee_outlined, Icons.sports_esports_outlined, Icons.smoking_rooms_outlined,
  ];

  final List<IconData> _incomeIcons = [
    Icons.work_outline, Icons.bar_chart_outlined, Icons.storefront_outlined,
    Icons.volunteer_activism_outlined, Icons.sell_outlined, Icons.account_balance_wallet_outlined,
    Icons.savings_outlined, Icons.payments_outlined, Icons.trending_up_outlined,
    Icons.monetization_on_outlined, Icons.redeem_outlined, Icons.attach_money_outlined,
    Icons.price_change_outlined, Icons.account_balance_outlined, Icons.real_estate_agent_outlined,
  ];

  final List<String> _expenseGroups = ['Thiết yếu', 'Phát triển', 'Hưởng thụ', 'Khác'];

  @override
  void initState() {
    super.initState();
    _isIncomeTab = widget.isIncome;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // DEFAULT EXPENSES BY GROUP (With vibrant colors)
    final Map<String, List<Map<String, dynamic>>> defaultExpenseGroups = {
      'Thiết yếu': [
        {'name': 'Ăn uống', 'icon': Icons.restaurant_outlined, 'group': 'Thiết yếu'},
        {'name': 'Sức khỏe', 'icon': Icons.medical_services_outlined, 'group': 'Thiết yếu'},
        {'name': 'Di chuyển', 'icon': Icons.directions_car_outlined, 'group': 'Thiết yếu'},
        {'name': 'Tiền nhà', 'icon': Icons.home_outlined, 'group': 'Thiết yếu'},
        {'name': 'Tiền điện', 'icon': Icons.water_drop_outlined, 'group': 'Thiết yếu'},
      ],
      'Phát triển': [
        {'name': 'Học tập', 'icon': Icons.menu_book_outlined, 'group': 'Phát triển'},
        {'name': 'Thể thao', 'icon': Icons.fitness_center_outlined, 'group': 'Phát triển'},
      ],
      'Hưởng thụ': [
        {'name': 'Mua sắm', 'icon': Icons.shopping_bag_outlined, 'group': 'Hưởng thụ'},
        {'name': 'Giải trí', 'icon': Icons.local_activity_outlined, 'group': 'Hưởng thụ'},
        {'name': 'Du lịch', 'icon': Icons.flight_outlined, 'group': 'Hưởng thụ'},
        {'name': 'Quà tặng', 'icon': Icons.card_giftcard_outlined, 'group': 'Hưởng thụ'},
      ],
      'Khác': [
        {'name': 'Chi khác', 'icon': Icons.receipt_long_outlined, 'group': 'Khác'},
        {'name': 'Nhóm Chi Tiêu', 'icon': Icons.group, 'group': 'Khác', 'isSpecial': true},
      ]
    };

    final List<Map<String, dynamic>> defaultIncomeList = [
      {'name': 'Tiền lương', 'icon': Icons.work_outline},
      {'name': 'Tiền thưởng', 'icon': Icons.card_giftcard_outlined},
      {'name': 'Kinh doanh', 'icon': Icons.storefront_outlined},
      {'name': 'Được cho/Tặng', 'icon': Icons.volunteer_activism_outlined},
      {'name': 'Bán đồ', 'icon': Icons.sell_outlined},
      {'name': 'Thu khác', 'icon': Icons.account_balance_wallet_outlined},
    ];

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                   const Text('Phân loại danh mục', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                   const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Expanded(
                      child: StreamBuilder<UserModel?>(
                        stream: _firestoreService.getUserStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == null) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final user = snapshot.data!;
                          final customCategories = user.customCategories;

                          if (!_isIncomeTab) {
                            final Map<String, List<Map<String, dynamic>>> groupedData = {};
                            for (var g in _expenseGroups) {
                              groupedData[g] = List.from(defaultExpenseGroups[g] ?? []);
                            }
                            for (var item in customCategories) {
                              if (item['isIncome'] == false) {
                                String group = item['group'] ?? 'Khác';
                                if (!groupedData.containsKey(group)) groupedData[group] = [];
                                groupedData[group]!.add({
                                  'name': item['name'],
                                  'icon': IconData(item['iconCode'], fontFamily: 'MaterialIcons'),
                                  'isCustom': true,
                                });
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: CustomScrollView(
                                slivers: [
                                  for (var group in _expenseGroups) ...[
                                    if (groupedData[group]!.isNotEmpty || group == 'Khác') ...[
                                      _buildSectionHeader(group.toUpperCase()),
                                      SliverGrid(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 24, childAspectRatio: 0.9,
                                        ),
                                        delegate: SliverChildBuilderDelegate(
                                          (context, i) {
                                            if (group == 'Khác' && i == groupedData[group]!.length) return _buildAddItem(context);
                                            return _buildCategoryItem(context, groupedData[group]![i]);
                                          },
                                          childCount: group == 'Khác' ? groupedData[group]!.length + 1 : groupedData[group]!.length,
                                        ),
                                      ),
                                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                                    ],
                                  ],
                                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                                ],
                              ),
                            );
                          } else {
                            final List<Map<String, dynamic>> incomeList = List.from(defaultIncomeList);
                            for (var item in customCategories) {
                              if (item['isIncome'] == true) {
                                incomeList.add({
                                  'name': item['name'],
                                  'icon': IconData(item['iconCode'], fontFamily: 'MaterialIcons'),
                                  'isCustom': true,
                                });
                              }
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 24, childAspectRatio: 0.9,
                              ),
                              itemCount: incomeList.length + 1,
                              itemBuilder: (context, i) {
                                if (i == incomeList.length) return _buildAddItem(context);
                                return _buildCategoryItem(context, incomeList[i]);
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 4),
        child: Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }


  Widget _buildCategoryItem(BuildContext context, Map<String, dynamic> cat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = CategoryUtils.getVibrantColor(cat['name']);
    final bgColor = CategoryUtils.getLightBgColor(cat['name'], isDark);

    return GestureDetector(
      onTap: () {
        // Nếu là "Nhóm Chi Tiêu", navigate đến GroupListScreen
        if (cat['isSpecial'] == true && cat['name'] == 'Nhóm Chi Tiêu') {
          Navigator.push(
            context,
            PageTransitions.slideRight(const GroupListScreen()),
          );
        } else {
          // Trả về category như bình thường
          Navigator.pop(context, {
            'name': cat['name'],
            'icon': cat['icon'],
            'color': color,
          });
        }
      },
      child: Column(
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24)),
            child: Icon(cat['icon'], color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(cat['name'], textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF333333), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAddItem(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showAddCategoryDialog(context),
      child: Column(
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(24),
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.grey, size: 28),
          ),
          const SizedBox(height: 8),
          const Text('Thêm mới', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final List<IconData> currentIcons = _isIncomeTab ? _incomeIcons : _expenseIcons;
    IconData tempSelectedIcon = currentIcons[0];
    String selectedGroup = _expenseGroups[0];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 32, left: 24, right: 24),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạo danh mục mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              
              if (!_isIncomeTab) ...[
                const Text('Chọn nhóm phân loại', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGroup,
                      isExpanded: true,
                      onChanged: (val) => setModalState(() => selectedGroup = val!),
                      items: _expenseGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tên danh mục...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Chọn biểu tượng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 12),
                  itemCount: currentIcons.length,
                  itemBuilder: (context, i) {
                    final icon = currentIcons[i];
                    final isSelected = tempSelectedIcon == icon;
                    
                    // Palette màu ngẫu nhiên cho dialog thêm mới
                    final List<Color> dialogColors = [
                      Colors.orange, Colors.teal, Colors.pink, Colors.blue, Colors.purple,
                      Colors.green, Colors.amber, Colors.indigo, Colors.cyan, Colors.deepOrange
                    ];
                    final itemColor = dialogColors[i % dialogColors.length];

                    return GestureDetector(
                      onTap: () => setModalState(() => tempSelectedIcon = icon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? itemColor : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon, 
                          color: isSelected ? Colors.white : itemColor, 
                          size: 24
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    await _saveCategory(nameController.text.trim(), tempSelectedIcon.codePoint, selectedGroup);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF438883),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Lưu danh mục', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _saveCategory(String name, int iconCode, String group) async {
    final user = await _firestoreService.getUserStream().first;
    if (user == null) return;
    final currentCustom = List<dynamic>.from(user.customCategories);
    currentCustom.add({
      'name': name,
      'iconCode': iconCode,
      'isIncome': _isIncomeTab,
      'group': _isIncomeTab ? null : group,
    });
    await _firestoreService.updateUserProfile({'customCategories': currentCustom});
  }
}
