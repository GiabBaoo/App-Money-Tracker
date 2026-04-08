import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/page_transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import 'category_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddTransactionScreen({super.key, this.initialData});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  bool isIncome = false; // Mặc định là Khoản Chi theo yêu cầu
  bool _isLoading = false;

  XFile? _pickedPhoto; // Ảnh người dùng chọn/chụp (1 ảnh)

  String selectedCategoryName = 'Chọn danh mục';
  IconData selectedCategoryIcon = Icons.category;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo data nếu được truyền từ Voice Input
    if (widget.initialData != null) {
      isIncome = widget.initialData!['type'] == 'income';
      selectedCategoryName = widget.initialData!['category'] ?? 'Chọn danh mục';
      if (widget.initialData!['iconCode'] != null) {
         selectedCategoryIcon = IconData(widget.initialData!['iconCode'], fontFamily: 'MaterialIcons');
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

  Future<void> _pickTransactionPhotoFromSource(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (picked == null) return;
    setState(() => _pickedPhoto = picked);
  }

  Future<void> _showPhotoPickerSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Text(
                'Thêm ảnh',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF438883),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Chụp ảnh'),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Chọn từ thư viện'),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Upload ảnh lên Firebase Storage và trả về photoUrl + storagePath
  Future<({String photoUrl, String photoStoragePath})> _uploadTransactionPhoto({
    required String uid,
    required String transactionId,
    required XFile pickedPhoto,
  }) async {
    final ext = pickedPhoto.name.contains('.')
        ? pickedPhoto.name.split('.').last.toLowerCase()
        : 'jpg';

    final fileName = '$transactionId.${ext.isEmpty ? 'jpg' : ext}';
    final photoStoragePath = 'transaction_images/$uid/$transactionId/$fileName';

    final storageRef = FirebaseStorage.instance.ref().child(photoStoragePath);

    // Tách lỗi rõ ràng để dễ xác định nguyên nhân:
    // - Nếu lỗi ở putFile => upload không thành công (rule/network/uri/file...)
    // - Nếu lỗi ở getDownloadURL => object tồn tại nhưng không lấy được link (rule/permission/bucket...)
    try {
      await storageRef.putFile(File(pickedPhoto.path));
    } on FirebaseException catch (e) {
      throw Exception('Upload failed (${e.code}): ${e.message} (path: $photoStoragePath)');
    } catch (e) {
      throw Exception('Upload failed: $e (path: $photoStoragePath)');
    }

    late final String photoUrl;
    try {
      photoUrl = await storageRef.getDownloadURL();
    } on FirebaseException catch (e) {
      throw Exception('getDownloadURL failed (${e.code}): ${e.message} (path: $photoStoragePath)');
    } catch (e) {
      throw Exception('getDownloadURL failed: $e (path: $photoStoragePath)');
    }

    return (photoUrl: photoUrl, photoStoragePath: photoStoragePath);
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

      // 1) Tạo doc Firestore trước để lấy id
      final transactionId = await _firestoreService.addTransactionAndGetId(transaction);

      // 2) Nếu có ảnh -> upload lên Storage -> lưu link vào Firestore
      if (_pickedPhoto != null) {
        final uploadRes = await _uploadTransactionPhoto(
          uid: uid,
          transactionId: transactionId,
          pickedPhoto: _pickedPhoto!,
        );

        await _firestoreService.updateTransactionPhoto(
          transactionId: transactionId,
          photoUrl: uploadRes.photoUrl,
          photoStoragePath: uploadRes.photoStoragePath,
        );
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
                      const SizedBox(height: 30),

                      // CHỌN DANH MỤC
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
                      const SizedBox(height: 18),

                      // ẢNH
                      _buildLabel('Ảnh (hóa đơn, đồ ăn...)'),
                      InkWell(
                        onTap: _showPhotoPickerSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                            border: Border.all(color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF438883).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF438883)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _pickedPhoto == null ? 'Chụp ảnh để lưu kèm giao dịch' : 'Đã chọn ảnh',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.75),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_right,
                                color: isDark ? Colors.white54 : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_pickedPhoto != null) ...[
                        const SizedBox(height: 12),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_pickedPhoto!.path),
                                width: double.infinity,
                                height: 170,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Material(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(14),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  onPressed: () => setState(() => _pickedPhoto = null),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 40),

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
