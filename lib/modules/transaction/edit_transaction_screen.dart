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
    
    _selectedDate = widget.transaction.date;
    
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
    _currentIconCode = widget.transaction.categoryIconCode;

    _currentPhotoUrl = widget.transaction.photoUrl;
    _currentPhotoLocalPath = widget.transaction.photoLocalPath;
    _currentPhotoStoragePath = widget.transaction.photoStoragePath;
    _hasPhoto = widget.transaction.hasPhoto;

    _loadWallets();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
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
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              Text(
                'Ảnh hóa đơn, chứng từ',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appMainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.photo_library_outlined, color: appMainColor),
                label: const Text('Chọn từ thư viện', style: TextStyle(fontWeight: FontWeight.w600, color: appMainColor)),
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
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hủy chỉnh sửa?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Các thay đổi của bạn chưa được lưu. Bạn có chắc muốn thoát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục sửa'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thoát'),
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
      backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
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
                      trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF438883)) : null,
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
        date: _selectedDate,
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
      TopToast.show(
        context,
        isOnline
            ? 'Đã cập nhật & đồng bộ lên Firebase thành công ☁️'
            : 'Đã cập nhật trên máy (sẽ tự động đẩy lên Firebase khi có mạng) 💾',
      );
      Navigator.pop(context, true); 
    } catch (e) {
      TopToast.show(context, 'Lỗi cập nhật: $e', isError: true);
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
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final currentIcon = IconData(_currentIconCode, fontFamily: 'MaterialIcons');

    final bool hasActivePhoto = _newPickedPhoto != null ||
        (!_photoRemoved &&
            ((_currentPhotoLocalPath.isNotEmpty && File(_currentPhotoLocalPath).existsSync()) ||
                _currentPhotoUrl.isNotEmpty));

    final typeColor = _isIncome ? const Color(0xFF24A869) : const Color(0xFFE17E5B);

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
        backgroundColor: appMainColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ══════ CUSTOM HEADER TRÊN NỀN XANH ══════
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        if (await _confirmExit()) {
                          navigator.pop();
                        }
                      },
                    ),
                    const Text(
                      'Chỉnh sửa giao dịch',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // SỐ TIỀN LỚN TRÊN NỀN XANH
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    Text(
                      _isIncome ? 'Khoản thu' : 'Khoản chi',
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
                              decoration: BoxDecoration(
                                color: !_isIncome ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Chi tiêu',
                                style: TextStyle(
                                  color: !_isIncome ? appMainColor : Colors.white70,
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
                                color: _isIncome ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Thu nhập',
                                style: TextStyle(
                                  color: _isIncome ? appMainColor : Colors.white70,
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

              // ══════ FORM BODY ══════
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          children: [
                            // ═══ CARD 1: THÔNG TIN GIAO DỊCH ═══
                            _buildFormCard(
                              isDark: isDark,
                              children: [
                                // Danh mục
                                _buildFieldRow(
                                  icon: Icons.category_rounded,
                                  iconColor: typeColor,
                                  label: 'Danh mục',
                                  isDark: isDark,
                                  child: InkWell(
                                    onTap: _selectCategory,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(currentIcon, color: typeColor, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _currentCategory,
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
                                  label: _isIncome ? 'Nhận vào ví' : 'Chi từ ví',
                                  isDark: isDark,
                                  child: InkWell(
                                    onTap: _pickWallet,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
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
                                                  _selectedWallet?.name ?? 'Chọn ví tiền',
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
                                      child: _buildFieldRow(
                                        icon: Icons.calendar_today_rounded,
                                        iconColor: appMainColor,
                                        label: 'Ngày',
                                        isDark: isDark,
                                        child: InkWell(
                                          onTap: _pickDate,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildFieldRow(
                                        icon: Icons.access_time_rounded,
                                        iconColor: appMainColor,
                                        label: 'Giờ',
                                        isDark: isDark,
                                        child: InkWell(
                                          onTap: _pickTime,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                          ),
                                        ),
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
                                      _buildQuickTimeChip('Hôm nay', () {
                                        final now = DateTime.now();
                                        setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
                                      }, isSelected: _isSameDay(_selectedDate, DateTime.now())),
                                      _buildQuickTimeChip('Hôm qua', () {
                                        final yesterday = DateTime.now().subtract(const Duration(days: 1));
                                        setState(() => _selectedDate = DateTime(yesterday.year, yesterday.month, yesterday.day));
                                      }, isSelected: _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1)))),
                                      _buildQuickTimeChip('Bây giờ', () {
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
                                  iconColor: appMainColor,
                                  label: 'Ghi chú',
                                  isDark: isDark,
                                  child: TextFormField(
                                    controller: _descriptionController,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Nhập ghi chú...',
                                      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400, fontSize: 13.5),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
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
                                  iconColor: appMainColor,
                                  label: 'Ảnh hóa đơn',
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
                                                    title: 'Hóa đơn xem chi tiết',
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
                                                        foregroundColor: appMainColor,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                                      label: const Text('Đổi ảnh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                      onPressed: _showPhotoPickerSheet,
                                                    ),
                                                    TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.redAccent,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                                      label: const Text('Xóa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F8FA),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.add_photo_alternate_outlined, color: isDark ? Colors.white54 : Colors.grey.shade500, size: 20),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Thêm ảnh chứng từ...',
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
                              ],
                            ),

                            const SizedBox(height: 20),

                            // NÚT XÓA GIAO DỊCH
                            Center(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Xóa giao dịch này', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                onPressed: _handleDelete,
                              ),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // NÚT CẬP NHẬT
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appMainColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shadowColor: appMainColor.withValues(alpha: 0.3),
                            ),
                            onPressed: _isLoading ? null : _handleSave,
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text('Xác nhận cập nhật', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                    ],
                                  ),
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
      ),
    );
  }

  // ══════ CARD HELPER WIDGETS ══════

  Widget _buildFormCard({required bool isDark, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEEF0F2),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected 
                ? appMainColor.withValues(alpha: 0.15) 
                : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? appMainColor 
                  : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected 
                  ? appMainColor 
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }
}
