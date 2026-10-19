import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../utils/category_utils.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../services/language_service.dart';

class AddBudgetDialog extends StatefulWidget {
  final BudgetModel? existingBudget;

  const AddBudgetDialog({super.key, this.existingBudget});

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final TextEditingController _amountController = TextEditingController();

  String _selectedCategory = 'Ăn uống';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _categories = [
    'Tất cả',
    'Ăn uống',
    'Mua sắm',
    'Di chuyển',
    'Sức khỏe',
    'Giải trí',
    'Học tập',
    'Tiền nhà',
    'Tiền điện',
    'Điện thoại',
    'Du lịch',
    'Làm đẹp',
    'Chi khác',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingBudget != null) {
      _selectedCategory = widget.existingBudget!.category;
      if (!_categories.contains(_selectedCategory)) {
        _categories.add(_selectedCategory);
      }
      _amountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '')
          .format(widget.existingBudget!.limitAmount)
          .trim();
      _selectedMonth = widget.existingBudget!.month;
      _selectedYear = widget.existingBudget!.year;
    }
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    try {
      final user = await UserRepository().getUser();
      final customCats = user?.customCategories;
      if (customCats != null && mounted) {
        final customList = <String>[];
        for (var c in customCats) {
          if (c is Map && c['isIncome'] != true && c['name'] != null && c['isOverride'] != true) {
            final name = c['name'] as String;
            if (!_categories.contains(name)) {
              customList.add(name);
            }
          }
        }
        if (customList.isNotEmpty && mounted) {
          setState(() {
            _categories.addAll(customList);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final cleanAmount = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
    final amount = double.tryParse(cleanAmount) ?? 0.0;
    final isVi = LanguageScope.of(context).isVietnamese;

    if (amount <= 0) {
      TopToast.show(context, isVi ? 'Vui lòng nhập số tiền hạn mức hợp lệ' : 'Please enter a valid budget limit');
      return;
    }

    final iconData = _selectedCategory == 'Tất cả'
        ? Icons.account_balance_wallet_outlined
        : CategoryUtils.getCategoryIcon(_selectedCategory);

    final budget = BudgetModel(
      id: widget.existingBudget?.id ?? '',
      uid: '',
      category: _selectedCategory,
      categoryIconCode: iconData.codePoint,
      limitAmount: amount,
      month: _selectedMonth,
      year: _selectedYear,
    );

    if (widget.existingBudget != null) {
      await _budgetRepo.updateBudget(budget);
      if (mounted) TopToast.show(context, isVi ? 'Đã cập nhật ngân sách!' : 'Budget updated successfully!');
    } else {
      await _budgetRepo.addBudget(budget);
      if (mounted) TopToast.show(context, isVi ? 'Đã tạo ngân sách mới!' : 'New budget created successfully!');
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final isVi = LanguageScope.of(context).isVietnamese;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.existingBudget != null
                          ? (isVi ? 'Sửa Ngân Sách' : 'Edit Budget')
                          : (isVi ? 'Thiết Lập Ngân Sách' : 'Set Up Budget'),
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

              // Chọn danh mục
              Text(
                isVi ? 'Danh mục áp dụng' : 'Applicable category',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242424) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categories.map((c) {
                      final icon = c == 'Tất cả' ? Icons.account_balance_wallet_outlined : CategoryUtils.getCategoryIcon(c);
                      final displayName = c == 'Tất cả' ? (isVi ? 'Tất cả' : 'All') : context.trCat(c);
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: primaryColor),
                            const SizedBox(width: 10),
                            Text(displayName, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nhập số tiền hạn mức
              Text(
                isVi ? 'Hạn mức chi tiêu (VNĐ)' : 'Spending limit (VND)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242424) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: isVi ? 'Ví dụ: 3.000.000' : 'e.g. 3,000,000',
                    border: InputBorder.none,
                    suffixText: 'đ',
                    suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Thời gian áp dụng
              Text(
                isVi
                    ? 'Tháng áp dụng: Tháng $_selectedMonth/$_selectedYear'
                    : 'Applicable period: Month $_selectedMonth/$_selectedYear',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                  ),
                  child: Center(
                    child: Text(
                      widget.existingBudget != null
                          ? (isVi ? 'Cập Nhật' : 'Update')
                          : (isVi ? 'Tạo Ngân Sách' : 'Create Budget'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
