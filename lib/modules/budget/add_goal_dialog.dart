import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/goal_model.dart';
import '../../data/repositories/goal_repository.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_dialog.dart';
import '../../services/language_service.dart';

class AddGoalDialog extends StatefulWidget {
  final GoalModel? existingGoal;

  const AddGoalDialog({super.key, this.existingGoal});

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final GoalRepository _goalRepo = GoalRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _currentAmountController = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 90));
  int _selectedColor = 0xFF438883;
  int _selectedIconCode = 0xe532; // Icons.savings

  final List<int> _colors = [
    0xFF438883,
    0xFF0EA5E9,
    0xFFF97316,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF10B981,
    0xFFEAB308,
  ];

  final List<IconData> _icons = [
    Icons.savings_rounded,
    Icons.two_wheeler_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.flight_takeoff_rounded,
    Icons.laptop_mac_rounded,
    Icons.school_rounded,
    Icons.favorite_rounded,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingGoal != null) {
      final g = widget.existingGoal!;
      _titleController.text = g.title;
      _targetAmountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '').format(g.targetAmount).trim();
      _currentAmountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '').format(g.currentAmount).trim();
      _deadline = g.deadline;
      _selectedColor = g.colorValue;
      _selectedIconCode = g.iconCode;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      TopToast.show(context, isVi ? 'Vui lòng nhập tên mục tiêu' : 'Please enter a goal name');
      return;
    }

    final cleanTarget = _targetAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final target = double.tryParse(cleanTarget) ?? 0.0;
    if (target <= 0) {
      TopToast.show(context, isVi ? 'Số tiền mục tiêu phải lớn hơn 0' : 'Target amount must be greater than 0');
      return;
    }

    final cleanCurrent = _currentAmountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final current = double.tryParse(cleanCurrent) ?? 0.0;

    final goal = GoalModel(
      id: widget.existingGoal?.id ?? '',
      uid: '',
      title: title,
      targetAmount: target,
      currentAmount: current,
      deadline: _deadline,
      iconCode: _selectedIconCode,
      colorValue: _selectedColor,
    );

    if (widget.existingGoal != null) {
      await _goalRepo.updateGoal(goal);
      if (mounted) TopToast.show(context, isVi ? 'Đã cập nhật mục tiêu!' : 'Goal updated successfully!');
    } else {
      await _goalRepo.addGoal(goal);
      if (mounted) TopToast.show(context, isVi ? 'Đã tạo mục tiêu mới thành công!' : 'New savings goal created successfully!');
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(_selectedColor);
    final isVi = LanguageScope.of(context).isVietnamese;

    return MonoDialogContainer(
      maxWidth: 440,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.existingGoal != null
                          ? (isVi ? 'Sửa Mục Tiêu' : 'Edit Goal')
                          : (isVi ? 'Mục Tiêu Tài Chính Mới' : 'New Financial Goal'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tên mục tiêu
              Text(
                isVi ? 'Tên mục tiêu' : 'Goal name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: isVi ? 'Ví dụ: Mua xe máy mới, Du lịch Đà Lạt...' : 'e.g. Buy new bike, Travel...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Số tiền mục tiêu
              Text(
                isVi ? 'Số tiền cần tích lũy (VNĐ)' : 'Target amount (VND)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _targetAmountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: isVi ? 'Ví dụ: 30.000.000' : 'e.g. 30,000,000',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Số tiền đã có sẵn (ban đầu)
              Text(
                isVi ? 'Số tiền hiện có (VNĐ)' : 'Current saved amount (VND)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _currentAmountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: isVi ? 'Ví dụ: 5.000.000 (mặc định 0đ)' : 'e.g. 5,000,000 (default 0)',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Ngày hết hạn (Deadline)
              Text(
                isVi ? 'Thời hạn hoàn thành' : 'Target deadline',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setState(() => _deadline = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_deadline),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Chọn Icon
              Text(
                isVi ? 'Biểu tượng' : 'Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _icons.length,
                  separatorBuilder: (context, idx) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final icon = _icons[index];
                    final isSelected = icon.codePoint == _selectedIconCode;
                    return InkWell(
                      onTap: () => setState(() => _selectedIconCode = icon.codePoint),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF141E2E) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 2)
                              : Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // Chọn Màu
              Text(
                isVi ? 'Màu chủ đạo' : 'Color theme',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (context, idx) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final colorVal = _colors[index];
                    final isSelected = colorVal == _selectedColor;
                    return InkWell(
                      onTap: () => setState(() => _selectedColor = colorVal),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Nút Lưu
              AnimatedScaleButton(
                onTap: _handleSave,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.existingGoal != null
                          ? (isVi ? 'Cập Nhật Mục Tiêu' : 'Update Goal')
                          : (isVi ? 'Bắt Đầu Tích Lũy' : 'Start Saving'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),

            ],
          ),
        );
  }
}
