import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import 'category_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool isIncome = true;
  bool _isLoading = false;

  String selectedCategoryName = 'Chọn danh mục';
  IconData selectedCategoryIcon = Icons.category;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF438883))), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF438883))), child: child!),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _handleSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountText.isEmpty || double.tryParse(amountText) == null || double.parse(amountText) <= 0) {
      _showSnackBar('Vui lòng nhập số tiền hợp lệ!', isError: true);
      return;
    }
    if (selectedCategoryName == 'Chọn danh mục') {
      _showSnackBar('Vui lòng chọn danh mục!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transaction = TransactionModel(
        uid: uid,
        type: isIncome ? 'income' : 'expense',
        category: selectedCategoryName,
        categoryIconCode: selectedCategoryIcon.codePoint,
        amount: double.parse(amountText),
        date: _selectedDate,
        time: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        description: _descriptionController.text.trim(),
      );

      await _firestoreService.addTransaction(transaction);

      if (!mounted) return;
      _showSnackBar('Đã lưu giao dịch thành công!');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF438883),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeFormatted = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF438883),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 48),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TAB CHUYỂN ĐỔI CHI / THU
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30)),
                        child: Row(children: [
                          _buildTab('Khoản Chi', !isIncome, () => setState(() { isIncome = false; selectedCategoryName = 'Chọn danh mục'; selectedCategoryIcon = Icons.category; })),
                          _buildTab('Khoản Thu', isIncome, () => setState(() { isIncome = true; selectedCategoryName = 'Chọn danh mục'; selectedCategoryIcon = Icons.category; })),
                        ]),
                      ),
                      const SizedBox(height: 30),

                      // CHỌN DANH MỤC
                      _buildLabel(isIncome ? 'Nguồn thu' : 'Nguồn Chi'),
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryScreen(isIncome: isIncome)));
                          if (result != null) setState(() { selectedCategoryName = result['name']; selectedCategoryIcon = result['icon']; });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: isIncome ? const Color(0xFFDBEAFE) : const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(selectedCategoryIcon, color: isIncome ? Colors.blue : const Color(0xFF1A7B73), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(selectedCategoryName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SỐ TIỀN
                      _buildLabel('Số tiền'),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFF1A7B73), fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0đ', hintStyle: const TextStyle(color: Color(0xFF1A7B73)),
                          filled: true, fillColor: const Color(0xFFE8F5F3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A7B73))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A7B73), width: 2)),
                          suffixIcon: TextButton(onPressed: () => _amountController.clear(), child: const Text('Xóa', style: TextStyle(color: Color(0xFF1A7B73), fontSize: 14))),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // NGÀY
                      _buildLabel('Ngày'),
                      InkWell(
                        onTap: _pickDate,
                        child: _buildReadOnlyField(dateFormatted, Icons.calendar_today_outlined),
                      ),
                      const SizedBox(height: 20),

                      // THỜI GIAN
                      _buildLabel('Thời gian'),
                      InkWell(
                        onTap: _pickTime,
                        child: _buildReadOnlyField(timeFormatted, Icons.access_time),
                      ),
                      const SizedBox(height: 20),

                      // NỘI DUNG
                      _buildLabel('Nội dung'),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Thêm nội dung', hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // NÚT LƯU
                      InkWell(
                        onTap: _isLoading ? null : _handleSave,
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : const Color(0xFF1A7B73),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: const Color(0xFF1A7B73).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildTab(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF1A7B73) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
          child: Center(child: Text(text, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 14))),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500)));
  }

  Widget _buildReadOnlyField(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(text, style: const TextStyle(color: Color(0xFF666666), fontSize: 14)),
        Icon(icon, color: Colors.grey),
      ]),
    );
  }
}
