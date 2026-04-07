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
                    
                    // Banner - Card Style (Refined)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.12),
                            primaryColor.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.12),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon + Title Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon Container
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  size: 28,
                                  color: primaryColor.withOpacity(0.65),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Chuyển tiền,',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                        height: 1.2,
                                      ),
                                    ),
                                    Text(
                                      'thanh toán mọi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Subtitle badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '📱 dịch vụ với quỹ',
                              style: TextStyle(
                                fontSize: 13,
                                color: primaryColor.withOpacity(0.65),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        tabs: const [
                          Tab(text: 'Cá nhân'),
                          Tab(text: 'Cặp đôi'),
                          Tab(text: 'Tích lũy'),
                          Tab(text: 'Hội nhóm'),
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
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTemplate = template['name'];
                                      _selectedIcon = template['icon'];
                                      _nameController.text = template['name'];
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor.withOpacity(0.1)
                                          : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? primaryColor : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      template['name'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected
                                            ? primaryColor
                                            : (isDark ? Colors.white70 : Colors.black87),
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
                            
                            // Create button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _nameController.text.trim().isEmpty
                                    ? null
                                    : () => _createGroup(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  disabledBackgroundColor: Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Tạo quỹ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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

    final dto = CreateGroupDto(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      iconCode: _selectedIcon.codePoint,
      memberIds: [],
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
