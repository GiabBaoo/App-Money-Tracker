import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  IconData _selectedIcon = Icons.person_outline;

  final List<Map<String, dynamic>> _templates = [
    {'name': 'Quỹ cá nhân', 'icon': Icons.person_outline, 'color': Colors.blue},
    {'name': 'Ăn uống 🍜', 'icon': Icons.restaurant_outlined, 'color': Colors.orange},
    {'name': 'Cafe, trà sữa ☕', 'icon': Icons.local_cafe_outlined, 'color': Colors.brown},
    {'name': 'Grab, xăng 🚗', 'icon': Icons.local_taxi_outlined, 'color': Colors.green},
    {'name': 'Du lịch ✈️', 'icon': Icons.flight_outlined, 'color': Colors.purple},
    {'name': 'Mua sắm 🛍️', 'icon': Icons.shopping_bag_outlined, 'color': Colors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Quỹ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    
                    // Banner - Inspirational Card Style
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor,
                              primaryColor.withValues(alpha: 0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Decorative circle background
                            Positioned(
                              right: -50,
                              top: -50,
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            // Content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Title with italic style
                                const Text(
                                  'Tạo Quỹ Mới',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Description
                                const Text(
                                  'Kiến tạo tương lai tài chính vững chắc với các giải pháp tiết kiệm ưu việt',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Tabs - Re-designed for Premium Look
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7F9),
                        borderRadius: BorderRadius.circular(22),
                        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        tabs: const [
                          Tab(
                            height: 54,
                            icon: Icon(Icons.person_rounded, size: 20),
                            iconMargin: EdgeInsets.only(bottom: 4),
                            text: 'Cá nhân',
                          ),
                          Tab(
                            height: 54,
                            icon: Icon(Icons.favorite_rounded, size: 20),
                            iconMargin: EdgeInsets.only(bottom: 4),
                            text: 'Cặp đôi',
                          ),
                          Tab(
                            height: 54,
                            icon: Icon(Icons.savings_rounded, size: 20),
                            iconMargin: EdgeInsets.only(bottom: 4),
                            text: 'Tích lũy',
                          ),
                          Tab(
                            height: 54,
                            icon: Icon(Icons.groups_rounded, size: 20),
                            iconMargin: EdgeInsets.only(bottom: 4),
                            text: 'Nhóm',
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Form
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name field
                            Text(
                              'Tên quỹ (${_nameController.text.length}/60)*',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              maxLength: 60,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: _selectedTemplate.isEmpty ? 'Nhập tên quỹ...' : _selectedTemplate,
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                counterText: '',
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Templates
                            Text(
                              'Chọn mẫu có sẵn',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _templates.map((template) {
                                final isSelected = _selectedTemplate == template['name'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTemplate = template['name'];
                                      _selectedIcon = template['icon'];
                                      _nameController.text = template['name'];
                                    });
                                  },
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 200),
                                    scale: isSelected ? 1.05 : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor.withValues(alpha: 0.12)
                                            : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6)),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected 
                                              ? primaryColor 
                                              : (isDark 
                                                  ? Colors.white.withValues(alpha: 0.1)
                                                  : Colors.black.withValues(alpha: 0.08)),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: primaryColor.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Text(
                                        template['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected
                                              ? primaryColor
                                              : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 24),

                            // Description field
                            Text(
                              'Mô tả quỹ (${_descriptionController.text.length}/300)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              maxLength: 300,
                              maxLines: 3,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Dự phòng cho chi phí đột xuất, khẩn cấp',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                counterText: '',
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Terms
                            Text(
                              'Bằng cách bấm Tạo quỹ, tôi đồng ý với Điều khoản và Điều kiện sử dụng dịch vụ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Create button with gradient
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _nameController.text.trim().isEmpty
                                      ? null
                                      : () => _createGroup(context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tạo quỹ',
                                          style: TextStyle(
                                            color: Colors.white,
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
                            
                            const SizedBox(height: 40),
                          ],
                        ),
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

  Future<void> _createGroup(BuildContext context) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập!')),
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

    try {
      await ref.read(groupServiceProvider).createGroup(dto, userId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tạo quỹ thành công!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}
