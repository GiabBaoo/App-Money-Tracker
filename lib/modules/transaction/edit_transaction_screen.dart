import '../../services/language_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../services/sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/biometric_service.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/transaction_balance_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../utils/category_utils.dart';
import '../../services/category_style_service.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'category_screen.dart';

class EditTransactionScreen extends StatefulWidget {
  final TransactionModel transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  bool get isVi => LanguageService.instance.isVietnamese;
  final WalletRepository _walletRepo = WalletRepository();
  final ImagePicker _imagePicker = ImagePicker();
  
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isIncome;
  
  late String _currentCategory;
  late int _currentIconCode;

  // Quản lý ảnh
  XFile? _newPickedPhoto;
  bool _photoRemoved = false;
  late String _currentPhotoUrl;
  late String _currentPhotoLocalPath;
  late String _currentPhotoStoragePath;
  late bool _hasPhoto;
  
  WalletModel? _selectedWallet;
  List<WalletModel> _wallets = [];
  bool _isLoading = false;

  // Quản lý vị trí địa danh
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

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
    
    _selectedDate = DateTime(widget.transaction.date.year, widget.transaction.date.month, widget.transaction.date.day);
    
    final timeParts = widget.transaction.time.split(':');
    if (timeParts.length >= 2) {
      _selectedTime = TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? DateTime.now().hour, 
        minute: int.tryParse(timeParts[1]) ?? DateTime.now().minute,
      );
    } else {
      _selectedTime = TimeOfDay.now();
    }
    
    _currentCategory = widget.transaction.category;
    _currentIconCode = CategoryUtils.getCategoryIcon(
      _currentCategory,
      fallbackCode: widget.transaction.categoryIconCode,
    ).codePoint;

    _currentPhotoUrl = widget.transaction.photoUrl;
    _currentPhotoLocalPath = widget.transaction.photoLocalPath;
    _currentPhotoStoragePath = widget.transaction.photoStoragePath;
    _hasPhoto = widget.transaction.hasPhoto;

    _locationName = widget.transaction.location;
    _latitude = widget.transaction.latitude;
    _longitude = widget.transaction.longitude;

    CategoryStyleService.instance.addListener(_onCategoryStyleChanged);
    _loadWallets();
  }

  void _onCategoryStyleChanged() {
    if (mounted) {
      setState(() {
        _currentIconCode = CategoryUtils.getCategoryIcon(
          _currentCategory,
          fallbackCode: _currentIconCode,
        ).codePoint;
      });
    }
  }

  @override
  void dispose() {
    CategoryStyleService.instance.removeListener(_onCategoryStyleChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid;
      if (uid != null) {
        _walletRepo.setUid(uid);
        final wallets = await _walletRepo.getWallets();
        if (mounted) {
          setState(() {
            _wallets = wallets;
            if (widget.transaction.walletId.isNotEmpty) {
              _selectedWallet = wallets.cast<WalletModel?>().firstWhere(
                (w) => w?.id == widget.transaction.walletId, 
                orElse: () => null,
              );
            }
            if (_selectedWallet == null && wallets.isNotEmpty) {
              _selectedWallet = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('EditTransactionScreen: _loadWallets error: $e');
    }
  }

  Future<void> _pickTransactionPhotoFromSource(ImageSource source) async {
    final picked = await BiometricService.instance.runWithPickerSuspended(() async {
      return await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    });

    if (picked == null) return;
    setState(() {
      _newPickedPhoto = picked;
      _photoRemoved = false;
    });
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
            color: isDark ? const Color(0xFF162523) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Text(
                isVi ? 'Ảnh hóa đơn, chứng từ' : 'Receipt / Invoice Photo',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2DD4BF) : appMainColor,
                  foregroundColor: isDark ? const Color(0xFF0F2625) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(isVi ? 'Chụp ảnh mới' : 'Take new photo', style: const TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? const Color(0xFF2DD4BF) : appMainColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(Icons.photo_library_outlined, color: isDark ? const Color(0xFF2DD4BF) : appMainColor),
                label: Text(isVi ? 'Chọn từ thư viện' : 'Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF2DD4BF) : appMainColor)),
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

  bool get _hasUnsavedData {
    final currentAmount = CurrencyUtils.parseCurrency(_amountController.text);
    final isAmountChanged = currentAmount != widget.transaction.amount;
    final isDescChanged = _descriptionController.text.trim() != widget.transaction.description;
    final isCatChanged = _currentCategory != widget.transaction.category;
    final isWalletChanged = (_selectedWallet?.id ?? '') != widget.transaction.walletId;
    final isDateChanged = !_isSameDay(_selectedDate, widget.transaction.date);
    final isTypeChanged = (_isIncome ? 'income' : 'expense') != widget.transaction.type;
    final isPhotoChanged = _newPickedPhoto != null || _photoRemoved;
    return isAmountChanged || isDescChanged || isCatChanged || isWalletChanged || isDateChanged || isTypeChanged || isPhotoChanged;
  }

  Future<bool> _confirmExit() async {
    if (!_hasUnsavedData) return true;
    final isVi = LanguageScope.of(context).isVietnamese;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVi ? 'Hủy chỉnh sửa?' : 'Discard changes?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(isVi ? 'Các thay đổi của bạn chưa được lưu. Bạn có chắc muốn thoát?' : 'Your changes have not been saved. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Tiếp tục sửa' : 'Keep editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Thoát' : 'Discard'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  void _pickWallet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF162523) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isIncome ? 'Chọn ví nhận tiền' : 'Chọn ví thanh toán',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                if (_wallets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Chưa có ví tiền nào',
                        style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._wallets.map((w) {
                    final isSel = _selectedWallet?.id == w.id;
                    final color = Color(w.colorValue);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(w.icon, color: color, size: 22),
                      ),
                      title: Text(
                        w.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'Số dư: ${CurrencyUtils.formatCurrency(w.balance)} • ${w.typeDisplayName}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                      ),
                      trailing: isSel ? Icon(Icons.check_circle_rounded, color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883)) : null,
                      onTap: () {
                        setState(() => _selectedWallet = w);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: Color(0xFF2DD4BF),
                  onPrimary: Color(0xFF0F2625),
                  surface: Color(0xFF162523),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: appMainColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF1E293B),
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(
                  primary: Color(0xFF2DD4BF),
                  onPrimary: Color(0xFF0F2625),
                  surface: Color(0xFF162523),
                  onSurface: Colors.white,
                )
              : const ColorScheme.light(
                  primary: appMainColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF1E293B),
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _selectCategory() async {
    final result = await Navigator.push(
      context, 
      PageTransitions.slideRight(CategoryScreen(isIncome: _isIncome, lockType: true))
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
      TopToast.show(context, 'Vui lòng nhập số tiền hợp lệ!', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid ?? widget.transaction.uid;
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      
      final newType = _isIncome ? 'income' : 'expense';
      final newAmount = amount;
      final newWalletId = _selectedWallet?.id ?? '';

      // 1. Xử lý ảnh giao dịch:
      bool finalHasPhoto = _hasPhoto;
      String finalPhotoUrl = _currentPhotoUrl;
      String finalPhotoLocalPath = _currentPhotoLocalPath;
      String finalPhotoStoragePath = _currentPhotoStoragePath;

      if (_photoRemoved) {
        finalHasPhoto = false;
        finalPhotoUrl = '';
        finalPhotoLocalPath = '';
        finalPhotoStoragePath = '';
      } else if (_newPickedPhoto != null) {
        finalHasPhoto = true;

        try {
          final uploadRes = await ReceiptStorageService().processAndUploadReceipt(
            uid: uid,
            transactionId: widget.transaction.id,
            pickedFile: File(_newPickedPhoto!.path),
          );
          finalPhotoLocalPath = uploadRes.photoLocalPath;
          finalPhotoUrl = uploadRes.photoUrl;
          finalPhotoStoragePath = uploadRes.photoStoragePath;
        } catch (photoError) {
          debugPrint('EditTransaction: Upload photo error: $photoError');
          finalPhotoLocalPath = _newPickedPhoto!.path;
        }
      }

      final updatedTransaction = TransactionModel(
        id: widget.transaction.id,
        uid: widget.transaction.uid,
        type: newType,
        category: _currentCategory,
        categoryIconCode: _currentIconCode,
        amount: newAmount,
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        time: timeStr,
        description: _descriptionController.text.trim(),
        createdAt: widget.transaction.createdAt,
        hasPhoto: finalHasPhoto,
        photoUrl: finalPhotoUrl,
        photoStoragePath: finalPhotoStoragePath,
        photoLocalPath: finalPhotoLocalPath,
        groupId: widget.transaction.groupId,
        groupIconCode: widget.transaction.groupIconCode,
        source: widget.transaction.source,
        walletId: newWalletId,
        location: _locationName,
        latitude: _latitude,
        longitude: _longitude,
      );

      // 2. Cập nhật giao dịch và cân đối số dư ví trong 1 transaction nguyên tử
      await TransactionBalanceService().editTransactionAtomic(
        oldTx: widget.transaction,
        newTx: updatedTransaction,
      );

      // Kích hoạt sync đồng bộ lên Firestore trong nền nếu có mạng
      final isOnline = ConnectivityService().isOnline;
      if (isOnline) {
        try {
          SyncService().syncNow();
        } catch (_) {}
      }
      
      if (!mounted) return;
      // Đã bỏ thông báo thành công theo yêu cầu của người dùng
      Navigator.pop(context, true); 
    } catch (e) {
      TopToast.show(context, 'Lỗi cập nhật: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVi ? 'Xác nhận xóa' : 'Confirm Delete'),
        content: Text(isVi ? 'Bạn có chắc chắn muốn xóa giao dịch này không?' : 'Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isVi ? 'Hủy' : 'Cancel', style: const TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(isVi ? 'Xóa' : 'Delete', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Xóa trong SQLite và hoàn lại số dư ví trong 1 transaction nguyên tử
      await TransactionBalanceService().deleteTransactionAtomic(widget.transaction);

      // Đồng bộ ngay lên Firestore nếu có mạng
      try {
        SyncService().syncNow();
      } catch (_) {}

      if (!mounted) return;
      TopToast.show(context, 'Đã xóa giao dịch!');
      Navigator.pop(context, true); 
    } catch (e) {
      if (mounted) TopToast.show(context, 'Lỗi khi xóa: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPhotoPreviewWidget() {
    if (_newPickedPhoto != null) {
      return Image.file(
        File(_newPickedPhoto!.path),
        fit: BoxFit.contain,
        cacheWidth: 800,
      );
    }
    return ReceiptStorageService.buildReceiptImage(
      photoLocalPath: _currentPhotoLocalPath,
      photoUrl: _currentPhotoUrl,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final currentIcon = CategoryUtils.getCategoryIcon(_currentCategory, fallbackCode: _currentIconCode);

    final bool hasActivePhoto = _newPickedPhoto != null ||
        (!_photoRemoved &&
            ((_currentPhotoLocalPath.isNotEmpty && File(_currentPhotoLocalPath).existsSync()) ||
                _currentPhotoUrl.isNotEmpty));

    final typeColor = _isIncome 
        ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF24A869))
        : (isDark ? const Color(0xFFFB923C) : const Color(0xFFE17E5B));

    final headerBgColor = isDark ? const Color(0xFF0F2625) : appMainColor;
    final activeAccentColor = isDark ? const Color(0xFF2DD4BF) : appMainColor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: headerBgColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ══════ HEADER APPBAR CỐ ĐỊNH ══════
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          if (await _confirmExit()) {
                            navigator.pop();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: Text(
                        isVi ? 'Chỉnh sửa giao dịch' : 'Edit Transaction',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    AnimatedScaleButton(
                      scaleDown: 0.9,
                      onTap: _isLoading ? null : _handleSave,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.check_rounded, color: Colors.white, size: 21),
                      ),
                    ),
                  ],
                ),
              ),

              // ══════ LUỒNG CUỘN THỐNG NHẤT KHÔNG BỊ CẮT GÓC ══════
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // SỐ TIỀN & CHUYỂN ĐỔI THU/CHI
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              _isIncome ? (isVi ? 'Khoản thu' : 'Income') : (isVi ? 'Khoản chi' : 'Expense'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            IntrinsicWidth(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  suffixText: ' ₫',
                                  suffixStyle: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // TOGGLE THU/CHI CAPSULE
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_isIncome) {
                                        setState(() {
                                          _isIncome = false;
                                          _currentCategory = 'Chi khác';
                                          _currentIconCode = Icons.receipt_long_outlined.codePoint;
                                        });
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                          child: Text(
                                        context.tr('expense'),
                                        style: TextStyle(
                                          color: !_isIncome
                                              ? (isDark ? const Color(0xFF0F2625) : appMainColor)
                                              : Colors.white70,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (!_isIncome) {
                                        setState(() {
                                          _isIncome = true;
                                          _currentCategory = 'Tiền lương';
                                          _currentIconCode = Icons.work_outline.codePoint;
                                        });
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _isIncome ? (isDark ? const Color(0xFF2DD4BF) : Colors.white) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        context.tr('income'),
                                        style: TextStyle(
                                          color: _isIncome
                                              ? (isDark ? const Color(0xFF0F2625) : appMainColor)
                                              : Colors.white70,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ══════ FORM CONTAINER LIỀN MẠCH ══════
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ═══ CARD 1: THÔNG TIN GIAO DỊCH ═══
                            _buildFormCard(
                              isDark: isDark,
                              children: [
                                // Danh mục
                                _buildFieldRow(
                                  icon: Icons.category_rounded,
                                  iconColor: typeColor,
                                  label: context.tr('category'),
                                  isDark: isDark,
                                  child: InkWell(
                                    onTap: _selectCategory,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(currentIcon, color: typeColor, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              context.trCat(_currentCategory),
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                _buildFieldDivider(isDark),

                                // Ví tiền
                                _buildFieldRow(
                                  icon: Icons.account_balance_wallet_rounded,
                                  iconColor: Color(_selectedWallet?.colorValue ?? 0xFF438883),
                                  label: _isIncome ? (isVi ? 'Nhận vào ví' : 'Receive into wallet') : (isVi ? 'Chi từ ví' : 'Pay from wallet'),
                                  isDark: isDark,
                                  child: InkWell(
                                    onTap: _pickWallet,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Color(_selectedWallet?.colorValue ?? 0xFF438883).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _selectedWallet?.icon ?? Icons.account_balance_wallet_rounded,
                                              color: Color(_selectedWallet?.colorValue ?? 0xFF438883),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedWallet?.name ?? (isVi ? 'Chọn ví tiền' : 'Select wallet'),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                                  ),
                                                ),
                                                if (_selectedWallet != null)
                                                  Text(
                                                    CurrencyUtils.formatCurrency(_selectedWallet!.balance),
                                                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.grey.shade500),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ═══ CARD 2: THỜI GIAN ═══
                            _buildFormCard(
                              isDark: isDark,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateTimeTile(
                                        icon: Icons.calendar_today_rounded,
                                        iconColor: activeAccentColor,
                                        label: context.tr('date'),
                                        value: dateStr,
                                        isDark: isDark,
                                        onTap: _pickDate,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDateTimeTile(
                                        icon: Icons.access_time_rounded,
                                        iconColor: activeAccentColor,
                                        label: context.tr('time'),
                                        value: timeStr,
                                        isDark: isDark,
                                        onTap: _pickTime,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Chips chọn nhanh
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildQuickTimeChip(isVi ? 'Hôm nay' : 'Today', () {
                                        final now = DateTime.now();
                                        setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
                                      }, isSelected: _isSameDay(_selectedDate, DateTime.now())),
                                      _buildQuickTimeChip(isVi ? 'Hôm qua' : 'Yesterday', () {
                                        final yesterday = DateTime.now().subtract(const Duration(days: 1));
                                        setState(() => _selectedDate = DateTime(yesterday.year, yesterday.month, yesterday.day));
                                      }, isSelected: _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1)))),
                                      _buildQuickTimeChip(isVi ? 'Bây giờ' : 'Now', () {
                                        final now = TimeOfDay.now();
                                        setState(() => _selectedTime = now);
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ═══ CARD 3: GHI CHÚ & ẢNH ═══
                            _buildFormCard(
                              isDark: isDark,
                              children: [
                                _buildFieldRow(
                                  icon: Icons.edit_note_rounded,
                                  iconColor: activeAccentColor,
                                  label: context.tr('note'),
                                  isDark: isDark,
                                  child: TextFormField(
                                    controller: _descriptionController,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: isVi ? 'Nhập ghi chú...' : 'Enter note...',
                                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400, fontSize: 13.5),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                _buildFieldDivider(isDark),

                                // Ảnh hóa đơn
                                _buildFieldRow(
                                  icon: Icons.camera_alt_rounded,
                                  iconColor: activeAccentColor,
                                  label: isVi ? 'Ảnh hóa đơn' : 'Receipt photo',
                                  isDark: isDark,
                                  child: hasActivePhoto
                                      ? Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  ReceiptStorageService.showFullScreenViewer(
                                                    context,
                                                    photoLocalPath: _newPickedPhoto?.path ?? _currentPhotoLocalPath,
                                                    photoUrl: _newPickedPhoto != null ? '' : _currentPhotoUrl,
                                                    title: isVi ? 'Hóa đơn xem chi tiết' : 'Receipt Detail View',
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                                  child: Container(
                                                    constraints: const BoxConstraints(maxHeight: 200, minHeight: 100),
                                                    width: double.infinity,
                                                    color: isDark ? const Color(0xFF0D1615) : const Color(0xFFF1F5F9),
                                                    child: _buildPhotoPreviewWidget(),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: activeAccentColor,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                                      label: Text(isVi ? 'Đổi ảnh' : 'Change', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                      onPressed: _showPhotoPickerSheet,
                                                    ),
                                                    TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: isDark ? const Color(0xFFF87171) : Colors.redAccent,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                                      label: Text(isVi ? 'Xóa' : 'Delete', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                      onPressed: () {
                                                        setState(() {
                                                          _photoRemoved = true;
                                                          _newPickedPhoto = null;
                                                          _hasPhoto = false;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : InkWell(
                                          onTap: _showPhotoPickerSheet,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.add_photo_alternate_outlined, color: isDark ? Colors.white54 : Colors.grey.shade500, size: 20),
                                                const SizedBox(width: 10),
                                                Text(
                                                  isVi ? 'Thêm ảnh chứng từ...' : 'Add receipt photo...',
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                _buildFieldDivider(isDark),

                                // Vị trí địa danh GPS
                                _buildFieldRow(
                                  icon: Icons.location_on_rounded,
                                  iconColor: const Color(0xFFF59E0B),
                                  label: isVi ? 'Vị trí địa danh' : 'Location',
                                  isDark: isDark,
                                  child: InkWell(
                                    onTap: _handleLocationTap,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _locationName != null && _locationName!.isNotEmpty
                                                ? Icons.place_rounded
                                                : Icons.add_location_alt_outlined,
                                            color: _locationName != null && _locationName!.isNotEmpty
                                                ? const Color(0xFFF59E0B)
                                                : (isDark ? Colors.white54 : Colors.grey.shade500),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _locationName != null && _locationName!.isNotEmpty
                                                  ? _locationName!
                                                  : (isVi ? 'Thêm vị trí địa danh...' : 'Add location...'),
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: _locationName != null && _locationName!.isNotEmpty
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: _locationName != null && _locationName!.isNotEmpty
                                                    ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                                                    : (isDark ? Colors.white54 : Colors.grey.shade500),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_locationName != null && _locationName!.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(Icons.clear_rounded, size: 18),
                                              color: isDark ? Colors.white54 : Colors.grey.shade500,
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                setState(() {
                                                  _locationName = null;
                                                  _latitude = null;
                                                  _longitude = null;
                                                });
                                              },
                                            )
                                          else
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // ═══ NÚT XÓA GIAO DỊCH ═══
                            Center(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: Text(isVi ? 'Xóa giao dịch này' : 'Delete this transaction', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                onPressed: _handleDelete,
                              ),
                            ),


                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: AnimatedScaleButton(
            onTap: _isLoading ? null : _handleSave,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2DD4BF), const Color(0xFF14B8A6)]
                      : [const Color(0xFF438883), const Color(0xFF2DD4BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF438883).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isVi ? 'Cập nhật giao dịch' : 'Update Transaction',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════ CARD HELPER WIDGETS ══════

  Widget _buildFormCard({required bool isDark, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162523) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEF0F2),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F3F5),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildQuickTimeChip(String label, VoidCallback onTap, {bool isSelected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF2DD4BF) : appMainColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected 
                ? activeColor.withValues(alpha: 0.15) 
                : (isDark ? const Color(0xFF1E2D2B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? activeColor 
                  : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected 
                  ? activeColor 
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLocationTap() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController(text: _locationName ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2827) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isVi ? 'Vị trí giao dịch' : 'Transaction Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      if (_locationName != null && _locationName!.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(isVi ? 'Xóa' : 'Remove'),
                          onPressed: () {
                            setState(() {
                              _locationName = null;
                              _latitude = null;
                              _longitude = null;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Ô nhập địa danh thủ công
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: isVi ? 'Nhập tên quán / địa danh...' : 'Enter place name...',
                      prefixIcon: const Icon(Icons.place_outlined, color: Color(0xFF438883)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF142423) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF438883), width: 1.5),
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Nút lấy tọa độ GPS tự động
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF438883),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                    label: Text(
                      _isLocating
                          ? (isVi ? 'Đang xác định GPS...' : 'Locating GPS...')
                          : (isVi ? 'Lấy vị trí GPS hiện tại' : 'Get current GPS location'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _isLocating
                        ? null
                        : () async {
                            setModalState(() {});
                            setState(() => _isLocating = true);

                            final isServiceEnabled = await LocationService.instance.isLocationServiceEnabled();
                            if (!isServiceEnabled) {
                              setState(() => _isLocating = false);
                              if (mounted) _showGpsDisabledDialog(isVi);
                              return;
                            }

                            var perm = await LocationService.instance.checkPermission();
                            if (perm == LocationPermission.denied) {
                              perm = await LocationService.instance.requestPermission();
                            }

                            if (perm == LocationPermission.deniedForever) {
                              setState(() => _isLocating = false);
                              if (mounted) _showPermissionPermanentlyDeniedDialog(isVi);
                              return;
                            }

                            if (perm == LocationPermission.denied) {
                              setState(() => _isLocating = false);
                              if (mounted) {
                                TopToast.show(
                                  context,
                                  isVi ? 'Chưa cấp quyền vị trí' : 'Location permission denied',
                                  isError: true,
                                );
                              }
                              return;
                            }

                            final res = await LocationService.instance.getCurrentPlaceName(
                              timeout: const Duration(seconds: 5),
                            );

                            setState(() => _isLocating = false);

                            if (res != null) {
                              setState(() {
                                _locationName = res.placeName;
                                _latitude = res.latitude;
                                _longitude = res.longitude;
                              });
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                TopToast.show(
                                  context,
                                  isVi ? 'Đã định vị: ${res.placeName}' : 'Located: ${res.placeName}',
                                );
                              }
                            } else {
                              if (mounted) {
                                TopToast.show(
                                  context,
                                  isVi ? 'Không thể lấy vị trí. Vui lòng nhập tay.' : 'Could not locate. Please enter manually.',
                                  isError: true,
                                );
                              }
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  // Nút Lưu tên địa danh thủ công
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final customName = textController.text.trim();
                      setState(() {
                        if (customName.isNotEmpty) {
                          _locationName = customName;
                        } else {
                          _locationName = null;
                          _latitude = null;
                          _longitude = null;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      isVi ? 'Áp dụng tên này' : 'Apply this name',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    textController.dispose();
  }

  void _showGpsDisabledDialog(bool isVi) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isVi ? 'Dịch vụ vị trí đang tắt' : 'Location Services Disabled'),
        content: Text(
          isVi
              ? 'Vui lòng bật GPS trên thiết bị để ứng dụng tự động lấy địa danh.'
              : 'Please enable GPS on your device to automatically detect place names.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(isVi ? 'Đóng' : 'Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF438883),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dCtx);
              LocationService.instance.openLocationSettings();
            },
            child: Text(isVi ? 'Mở cài đặt' : 'Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog(bool isVi) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isVi ? 'Quyền vị trí bị chặn' : 'Location Permission Denied'),
        content: Text(
          isVi
              ? 'Bạn đã từ chối quyền vị trí vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.'
              : 'Location permission is permanently denied. Please grant permission in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(isVi ? 'Để sau' : 'Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF438883),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dCtx);
              LocationService.instance.openAppSettings();
            },
            child: Text(isVi ? 'Mở Cài đặt' : 'Open Settings'),
          ),
        ],
      ),
    );
  }
}
