import '../../../../services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../widgets/animated_scale_button.dart';
import '../../../../widgets/mono_toast.dart';
import '../providers/group_expense_providers.dart';
import '../../data/dtos/create_group_dto.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late TabController _tabController;
  String _selectedTemplate = '';
  IconData _selectedIcon = Icons.person_outline_rounded;
  bool _isLoading = false;

  List<Map<String, dynamic>> get _templates => [
    {'name': isVi ? 'Quỹ cá nhân' : 'Personal Fund', 'icon': Icons.person_outline_rounded},
    {'name': isVi ? 'Ăn uống 🍜' : 'Dining 🍜', 'icon': Icons.restaurant_outlined},
    {'name': isVi ? 'Cafe, trà sữa ☕' : 'Coffee ☕', 'icon': Icons.local_cafe_outlined},
    {'name': isVi ? 'Grab, xăng xe 🚗' : 'Transport 🚗', 'icon': Icons.local_taxi_outlined},
    {'name': isVi ? 'Du lịch ✈️' : 'Travel ✈️', 'icon': Icons.flight_outlined},
    {'name': isVi ? 'Mua sắm 🛍️' : 'Shopping 🛍️', 'icon': Icons.shopping_bag_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // Design Tokens
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inputBgColor = isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── ERGONOMIC TOP APP BAR ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  AnimatedScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cardBgColor,
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'Tạo Quỹ Mới' : 'Create New Fund',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          isVi ? 'Thiết lập quỹ tài chính cho mục tiêu chung' : 'Set up a collective finance fund',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── SCROLLABLE FORM BODY ───
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Group Type Segmented Selector
                    Text(
                      isVi ? 'MÔ HÌNH QUỸ' : 'FUND TYPE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: textSecondary,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        tabs: [
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.person_rounded, size: 18),
                            iconMargin: const EdgeInsets.only(bottom: 2),
                            text: isVi ? 'Cá nhân' : 'Personal',
                          ),
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.favorite_rounded, size: 18),
                            iconMargin: const EdgeInsets.only(bottom: 2),
                            text: isVi ? 'Cặp đôi' : 'Couple',
                          ),
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.savings_rounded, size: 18),
                            iconMargin: const EdgeInsets.only(bottom: 2),
                            text: isVi ? 'Tích lũy' : 'Savings',
                          ),
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.groups_rounded, size: 18),
                            iconMargin: const EdgeInsets.only(bottom: 2),
                            text: isVi ? 'Nhóm' : 'Group',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Fund Name Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'TÊN QUỸ *' : 'FUND NAME *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${_nameController.text.length}/60',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: TextField(
                        controller: _nameController,
                        maxLength: 60,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: _selectedTemplate.isEmpty
                              ? (isVi ? 'Nhập tên quỹ (ví dụ: Chuyến đi Đà Lạt)' : 'Enter fund name...')
                              : _selectedTemplate,
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 14),
                          prefixIcon: Icon(
                            _selectedIcon,
                            color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterText: '',
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Quick Preset Templates
                    Text(
                      isVi ? 'GỢI Ý TÊN QUỸ NHANH' : 'QUICK TEMPLATES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates.map((template) {
                        final isSelected = _selectedTemplate == template['name'];
                        return AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedTemplate = template['name'];
                              _selectedIcon = template['icon'];
                              _nameController.text = template['name'];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF2DD4BF).withValues(alpha: 0.18) : primaryColor.withValues(alpha: 0.12))
                                  : cardBgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF2DD4BF) : primaryColor)
                                    : borderColor,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  template['icon'] as IconData,
                                  size: 15,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF2DD4BF) : primaryColor)
                                      : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  template['name'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF2DD4BF) : primaryColor)
                                        : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // 4. Fund Description Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'MÔ TẢ MỤC ĐÍCH QUỸ' : 'FUND DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${_descriptionController.text.length}/300',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLength: 300,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: isVi
                              ? 'Dự phòng cho chi phí đột xuất, khẩn cấp hoặc các khoản chi tiêu định kỳ...'
                              : 'For emergency or scheduled collective expenses...',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterText: '',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Terms Notice
                    Text(
                      isVi
                          ? 'Bằng việc tạo quỹ, bạn có thể mời các thành viên cùng tham gia đóng góp và theo dõi minh bạch.'
                          : 'By creating a fund, you can invite members to contribute and track expenses transparently.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── ERGONOMIC THUMB-FRIENDLY BOTTOM ACTION BAR ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border(top: BorderSide(color: borderColor, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: AnimatedScaleButton(
                  onTap: (_nameController.text.trim().isEmpty || _isLoading)
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _createGroup(context);
                        },
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: _nameController.text.trim().isEmpty
                          ? null
                          : LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _nameController.text.trim().isEmpty
                          ? (isDark ? Colors.white.withValues(alpha: 0.08) : inputBgColor)
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _nameController.text.trim().isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: _nameController.text.trim().isEmpty ? textSecondary : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isVi ? 'Tạo Quỹ Ngay' : 'Create Fund Now',
                                  style: TextStyle(
                                    color: _nameController.text.trim().isEmpty ? textSecondary : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      MonoToast.warning(
        context,
        isVi ? 'Vui lòng đăng nhập!' : 'Please log in!',
      );
      return;
    }

    String groupType = 'group';
    switch (_tabController.index) {
      case 0:
        groupType = 'personal';
        break;
      case 1:
        groupType = 'couple';
        break;
      case 2:
        groupType = 'savings';
        break;
      case 3:
        groupType = 'group';
        break;
    }

    final dto = CreateGroupDto(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      iconCode: _selectedIcon.codePoint,
      memberIds: [],
      groupType: groupType,
    );

    setState(() => _isLoading = true);
    try {
      await ref.read(groupServiceProvider).createGroup(dto, userId);
      if (context.mounted) {
        Navigator.pop(context);
        MonoToast.success(
          context,
          isVi ? 'Tạo quỹ thành công!' : 'Fund created successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        MonoToast.error(
          context,
          '${isVi ? 'Lỗi' : 'Error'}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
