import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/group_expense/presentation/providers/group_expense_providers.dart';
import '../../features/group_expense/data/models/fund_transaction_model.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import 'category_screen.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddTransactionScreen({super.key, this.initialData});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  bool isIncome = false; // Mặc định là Khoản Chi theo yêu cầu
  bool _isLoading = false;

  String selectedCategoryName = 'Chọn danh mục';
  IconData selectedCategoryIcon = Icons.category;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo data nếu được truyền từ Voice Input hoặc Fund Action
    if (widget.initialData != null) {
      isIncome = widget.initialData!['type'] == 'income';
      
      // Nếu là Góp quỹ, set mặc định danh mục
      if (widget.initialData!['fundActionType'] == 'contribute') {
        selectedCategoryName = 'Chi khác';
        selectedCategoryIcon = Icons.receipt_long_rounded;
      } else {
        selectedCategoryName = widget.initialData!['category'] ?? 'Chọn danh mục';
        if (widget.initialData!['iconCode'] != null) {
          selectedCategoryIcon = IconData(widget.initialData!['iconCode'], fontFamily: 'MaterialIcons');
        }
      }
      _amountController = TextEditingController(
          text: widget.initialData!['amount'] != null 
                ? NumberFormat.currency(locale: 'vi_VN', symbol: '').format(widget.initialData!['amount']).trim()
                : ''
      );
      _descriptionController = TextEditingController(text: widget.initialData!['description'] ?? '');
      
      if (widget.initialData!['hour'] != null && widget.initialData!['minute'] != null) {
        _selectedTime = TimeOfDay(hour: widget.initialData!['hour'], minute: widget.initialData!['minute']);
      }
    } else {
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
    }
  }

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

    final amount = CurrencyUtils.parseCurrency(_amountController.text);
    if (amount <= 0) {
      _showSnackBar('Vui lòng nhập số tiền hợp lệ!', isError: true);
      return;
    }
    if (selectedCategoryName == 'Chọn danh mục') {
      _showSnackBar('Vui lòng chọn danh mục!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isFundAction = widget.initialData?['isFundAction'] == true;
      
      if (isFundAction) {
        final groupId = widget.initialData!['groupId'];
        final fundActionType = widget.initialData!['fundActionType'] == 'withdraw' 
            ? TransactionType.withdraw 
            : TransactionType.contribute;
        final isPersonalGroup = widget.initialData?['isPersonalGroup'] == true;
        
        final userNameAsync = await ref.read(currentUserNameProvider.future);
        
        await ref.read(fundTransactionRepositoryProvider).create(
          groupId: groupId,
          userId: uid,
          userName: userNameAsync,
          amount: amount,
          type: fundActionType,
          notes: _descriptionController.text.trim(),
          category: selectedCategoryName,
          categoryIconCode: selectedCategoryIcon.codePoint,
          isPersonalGroup: isPersonalGroup,
        );
      } else {
        final transaction = TransactionModel(
          uid: uid,
          type: isIncome ? 'income' : 'expense',
          category: selectedCategoryName,
          categoryIconCode: selectedCategoryIcon.codePoint,
          amount: amount,
          date: _selectedDate,
          time: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          description: _descriptionController.text.trim(),
        );

        await _firestoreService.addTransaction(transaction);
      }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormatted = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeFormatted = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
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
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24, right: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TAB CHUYỂN ĐỔI CHI / THU
                      if (widget.initialData?['isFundAction'] != true) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(children: [
                            _buildTab('Khoản Chi', !isIncome, () => setState(() { isIncome = false; selectedCategoryName = 'Chọn danh mục'; selectedCategoryIcon = Icons.category; })),
                            _buildTab('Khoản Thu', isIncome, () => setState(() { isIncome = true; selectedCategoryName = 'Chọn danh mục'; selectedCategoryIcon = Icons.category; })),
                          ]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // CHỌN DANH MỤC (Ẩn khi Góp quỹ per user request)
                      if (widget.initialData?['fundActionType'] != 'contribute') ...[
                        _buildLabel(isIncome ? 'Nguồn thu' : 'Nguồn Chi'),
                        InkWell(
                          onTap: () async {
                            final result = await Navigator.push(context, PageTransitions.slideRight(CategoryScreen(isIncome: isIncome)));
                            if (result != null) setState(() { selectedCategoryName = result['name']; selectedCategoryIcon = result['icon']; });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                              border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: CategoryUtils.getLightBgColor(selectedCategoryName, isDark),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  selectedCategoryIcon, 
                                  color: CategoryUtils.getVibrantColor(selectedCategoryName), 
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                selectedCategoryName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.grey),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // SỐ TIỀN
                      _buildLabel('Số tiền'),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        decoration: InputDecoration(
                          hintText: '0đ', hintStyle: const TextStyle(color: Color(0xFF1A7B73)),
                          filled: true, fillColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE8F5F3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFF1A7B73)),
                          ),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A7B73), width: 2)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF1A7B73), size: 18),
                            onPressed: () => _amountController.clear(),
                          ),
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
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Thêm nội dung',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF666666),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // THÔNG BÁO CÁCH LY VÍ (Nếu là quỹ nhóm)
                      if (widget.initialData?['isFundAction'] == true && 
                          widget.initialData?['isPersonalGroup'] != true)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  'Giao dịch này sẽ không tính vào ví cá nhân',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.blue[200] : Colors.blue[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 30),

                      // NÚT LƯU
                      InkWell(
                        onTap: _isLoading ? null : _handleSave,
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey : const Color(0xFF1A7B73),
                            borderRadius: BorderRadius.circular(30),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1A7B73) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
        ],
      ),
    );
  }
}
