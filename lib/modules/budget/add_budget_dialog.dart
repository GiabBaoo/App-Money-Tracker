import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../utils/category_utils.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';

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
      _amountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '')
          .format(widget.existingBudget!.limitAmount)
          .trim();
      _selectedMonth = widget.existingBudget!.month;
      _selectedYear = widget.existingBudget!.year;
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

    if (amount <= 0) {
      TopToast.show(context, 'Vui lòng nhập số tiền hạn mức hợp lệ');
      return;
    }

    final iconData = _selectedCategory == 'Tất cả'
        ? Icons.account_balance_wallet_rounded
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
      if (mounted) TopToast.show(context, 'Đã cập nhật ngân sách!');
    } else {
      await _budgetRepo.addBudget(budget);
      if (mounted) TopToast.show(context, 'Đã tạo ngân sách mới!');
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

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
                  Text(
                    widget.existingBudget != null ? 'Sửa Ngân Sách' : 'Thiết Lập Ngân Sách',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chọn danh mục
              const Text('Danh mục áp dụng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                      final icon = c == 'Tất cả' ? Icons.account_balance_wallet_rounded : CategoryUtils.getCategoryIcon(c);
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: primaryColor),
                            const SizedBox(width: 10),
                            Text(c, style: const TextStyle(fontSize: 14)),
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
              const Text('Hạn mức chi tiêu (VNĐ)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: 3.000.000',
                    border: InputBorder.none,
                    suffixText: 'đ',
                    suffixStyle: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Thời gian áp dụng
              Text(
                'Tháng áp dụng: Tháng $_selectedMonth/$_selectedYear',
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
                      widget.existingBudget != null ? 'Cập Nhật' : 'Tạo Ngân Sách',
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
