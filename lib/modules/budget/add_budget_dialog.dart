import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../utils/category_utils.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/mono_dialog.dart';
import '../../services/language_service.dart';

class AddBudgetDialog extends StatefulWidget {
  final BudgetModel? existingBudget;

  const AddBudgetDialog({super.key, this.existingBudget});

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  final BudgetRepository _budgetRepo = BudgetRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final TextEditingController _amountController = TextEditingController();

  String _selectedCategory = 'Tất cả';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _isLoadingCategories = true;
  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingBudget != null) {
      _selectedCategory = widget.existingBudget!.category;
      _amountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '')
          .format(widget.existingBudget!.limitAmount)
          .trim();
      _selectedMonth = widget.existingBudget!.month;
      _selectedYear = widget.existingBudget!.year;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await _categoryRepo.getExpenseCategories(includeAllOption: true);

      // Nếu đang chỉnh sửa ngân sách cũ mà danh mục đó đã bị xóa hoặc chưa có trong danh sách
      if (widget.existingBudget != null && !list.any((c) => c.name == widget.existingBudget!.category)) {
        list.insert(
          1,
          CategoryModel(
            id: 'legacy_${widget.existingBudget!.category}',
            name: widget.existingBudget!.category,
            iconCode: widget.existingBudget!.categoryIconCode,
            isCustom: true,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _categories = list;
          _isLoadingCategories = false;
          if (!_categories.any((c) => c.name == _selectedCategory)) {
            _selectedCategory = _categories.isNotEmpty ? _categories.first.name : 'Tất cả';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
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

    final matchedCat = _categories.firstWhere(
      (c) => c.name == _selectedCategory,
      orElse: () => CategoryModel(
        id: 'unknown',
        name: _selectedCategory,
        iconCode: CategoryUtils.getCategoryIcon(_selectedCategory).codePoint,
      ),
    );

    final iconData = _selectedCategory == 'Tất cả'
        ? Icons.account_balance_wallet_outlined
        : matchedCat.icon;

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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),

              if (_isLoadingCategories)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141E2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isVi ? 'Đang tải danh mục...' : 'Loading categories...',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                )
              else
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
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categories.any((c) => c.name == _selectedCategory) ? _selectedCategory : null,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      isExpanded: true,
                      items: _categories.map((c) {
                        final isAll = c.name == 'Tất cả';
                        final icon = isAll ? Icons.account_balance_wallet_outlined : c.icon;
                        final iconColor = isAll
                            ? (isDark ? const Color(0xFF2DD4BF) : primaryColor)
                            : (c.color ?? CategoryUtils.getVibrantColor(c.name));
                        final displayName = isAll ? (isVi ? 'Tất cả (Tổng ngân sách)' : 'All (Total Budget)') : context.trCat(c.name);

                        return DropdownMenuItem(
                          value: c.name,
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: iconColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (c.isCustom) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isVi ? 'Tùy biến' : 'Custom',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
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
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: isVi ? 'Ví dụ: 3.000.000' : 'e.g. 3,000,000',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Thời gian áp dụng
              Text(
                isVi
                    ? 'Tháng áp dụng: Tháng $_selectedMonth/$_selectedYear'
                    : 'Applicable period: Month $_selectedMonth/$_selectedYear',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                    color: isDark ? const Color(0xFF2DD4BF) : primaryColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF2DD4BF) : primaryColor).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.existingBudget != null
                          ? (isVi ? 'Cập Nhật' : 'Update')
                          : (isVi ? 'Tạo Ngân Sách' : 'Create Budget'),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF0F2625) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

  }
}
