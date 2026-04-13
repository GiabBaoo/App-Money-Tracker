import 'package:flutter/material.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import 'category_screen.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isIncome;
  
  // BIẾN QUẢN LÝ DANH MỤC MỚI THEO YÊU CẦU
  late String _currentCategory;
  late int _currentIconCode;
  
  bool _isLoading = false;

  static const Color appMainColor = Color(0xFF438883); 

  @override
  void initState() {
    super.initState();
    _isIncome = widget.transaction.type == 'income';
    _amountController = TextEditingController(
      text: CurrencyUtils.formatCurrency(widget.transaction.amount),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );
    
    // NÂNG CẤP LOGIC: Lưu giữ ngày gốc từ giao dịch, không tự ý reset sang ngày hiện tại
    _selectedDate = widget.transaction.date;
    
    final timeParts = widget.transaction.time.split(':');
    _selectedTime = TimeOfDay(
      hour: int.parse(timeParts[0]), 
      minute: int.parse(timeParts[1])
    );
    
    // Khởi tạo danh mục hiện tại và IconCode từ data gốc
    _currentCategory = widget.transaction.category;
    _currentIconCode = widget.transaction.categoryIconCode;
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: appMainColor)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: appMainColor)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // CHỌN DANH MỤC QUA MODAL BOTTOM SHEET HOẶC CATEGORY SCREEN (THEO YÊU CẦU)
  Future<void> _selectCategory() async {
    final result = await Navigator.push(
      context, 
      PageTransitions.slideRight(CategoryScreen(isIncome: _isIncome))
    );
    
    if (result != null) {
      setState(() {
        _currentCategory = result['name'];
        _currentIconCode = (result['icon'] as IconData).codePoint;
      });
    }
  }

  Future<void> _handleSave() async {
    final amount = CurrencyUtils.parseCurrency(_amountController.text);
    if (amount <= 0) {
      _showSnackBar('Vui lòng nhập số tiền hợp lệ!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      
      final updatedTransaction = TransactionModel(
        id: widget.transaction.id,
        uid: widget.transaction.uid,
        type: widget.transaction.type,
        category: _currentCategory, // Sử dụng giá trị mới
        categoryIconCode: _currentIconCode, // Sử dụng giá trị mới
        amount: amount,
        date: _selectedDate,
        time: timeStr,
        description: _descriptionController.text.trim(),
        createdAt: widget.transaction.createdAt,
        hasPhoto: widget.transaction.hasPhoto,
        photoUrl: widget.transaction.photoUrl,
        photoStoragePath: widget.transaction.photoStoragePath,
      );

      await _firestoreService.updateTransaction(updatedTransaction);
      
      if (!mounted) return;
      _showSnackBar('Cập nhật giao dịch thành công!');
      Navigator.pop(context, true); 
      Navigator.pop(context); 
    } catch (e) {
      _showSnackBar('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestoreService.deleteTransaction(widget.transaction.id);
      if (!mounted) return;
      _showSnackBar('Đã xóa giao dịch!');
      Navigator.pop(context); 
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
      backgroundColor: isError ? Colors.red.shade600 : appMainColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final currentIcon = IconData(_currentIconCode, fontFamily: 'MaterialIcons');

    return Scaffold(
      backgroundColor: appMainColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(_isIncome ? "Sửa Khoản Thu" : "Sửa Khoản Chi", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'delete') _handleDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Xóa giao dịch', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                   const SizedBox(height: 10),
                   
                   Center(
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                       decoration: BoxDecoration(
                         color: appMainColor.withValues(alpha: 0.12),
                         borderRadius: BorderRadius.circular(20),
                       ),
                       child: Text(
                         _isIncome ? 'PHÂN LOẠI: THU NHẬP' : 'PHÂN LOẠI: CHI TIÊU',
                         style: const TextStyle(color: appMainColor, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.1),
                       ),
                     ),
                   ),
                   const SizedBox(height: 30),

                  // TRƯỜNG CHỌN DANH MỤC MỚI
                  _buildLabel("Danh mục giao dịch"),
                  InkWell(
                    onTap: _selectCategory,
                    borderRadius: BorderRadius.circular(16),
                    child: _buildReadOnlyField(_currentCategory, currentIcon, appMainColor),
                  ),
                  const SizedBox(height: 30),

                  _buildLabel("Số tiền"),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: const TextStyle(color: appMainColor, fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2E2E2E) : appMainColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: appMainColor.withValues(alpha: 0.15))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: appMainColor, width: 1.8)),
                      suffixIcon: const Icon(Icons.edit_note, color: appMainColor),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Ngày giao dịch"),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: _buildReadOnlyField(dateStr, Icons.calendar_today_outlined, appMainColor),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Thời gian giao dịch"),
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(16),
                    child: _buildReadOnlyField(timeStr, Icons.access_time, appMainColor),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Ghi chú nội dung"),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Nhập ghi chú...",
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: appMainColor, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appMainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handleSave,
                child: const Text("XÁC NHẬN CẬP NHẬT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildReadOnlyField(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E2E2E) : Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
