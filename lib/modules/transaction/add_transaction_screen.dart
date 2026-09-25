import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../features/group_expense/presentation/providers/group_expense_providers.dart';
import '../../features/group_expense/data/models/fund_transaction_model.dart';
import '../../utils/page_transitions.dart';
import '../../services/auth_service.dart';
import '../../services/smart_notification_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/biometric_service.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/animated_scale_button.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/transaction_balance_service.dart';
import '../../services/sync_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import 'category_screen.dart';

/// Màn hình Thêm Giao Dịch Thu / Chi (Công thái học, hiện đại, đồng bộ thiết kế)
class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final DateTime? initialDate;

  const AddTransactionScreen({super.key, this.initialData, this.initialDate});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  bool isIncome = false; // Mặc định là Khoản Chi
  bool _isLoading = false;

  XFile? _pickedPhoto;

  String selectedCategoryName = 'Chọn danh mục';
  IconData selectedCategoryIcon = Icons.category_rounded;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  WalletModel? _selectedWallet;
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadWallets();

    // Khởi tạo dữ liệu nếu được truyền từ Voice Assistant hoặc Fund Action
    if (widget.initialData != null) {
      isIncome = widget.initialData!['type'] == 'income';

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
            : '',
      );
      _descriptionController = TextEditingController(text: widget.initialData!['description'] ?? '');

      if (widget.initialData!['hour'] != null && widget.initialData!['minute'] != null) {
        _selectedTime = TimeOfDay(hour: widget.initialData!['hour'], minute: widget.initialData!['minute']);
      }

      if (widget.initialData!['photoPath'] != null &&
          widget.initialData!['photoPath'].toString().isNotEmpty) {
        final path = widget.initialData!['photoPath'].toString();
        if (File(path).existsSync()) {
          _pickedPhoto = XFile(path);
        }
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

  Future<void> _loadWallets() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      await _walletRepo.ensureDefaultWalletExists(uid);
      final wallets = await _walletRepo.getWallets();
      if (mounted) {
        setState(() {
          _wallets = wallets;
          WalletModel? targetWallet;
          if (widget.initialData?['walletName'] != null && wallets.isNotEmpty) {
            final wName = widget.initialData!['walletName'].toString().toLowerCase();
            final matched = wallets.where((w) => w.name.toLowerCase().contains(wName));
            if (matched.isNotEmpty) {
              targetWallet = matched.first;
            }
          }
          _selectedWallet = targetWallet ??
              (wallets.isNotEmpty
                  ? wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first)
                  : null);
        });
      }
    } else {
      final retryUid = await AuthService().initOfflineSession();
      if (retryUid != null && mounted) {
        _walletRepo.setUid(retryUid);
        await _walletRepo.ensureDefaultWalletExists(retryUid);
        final wallets = await _walletRepo.getWallets();
        if (mounted) {
          setState(() {
            _wallets = wallets;
            WalletModel? targetWallet;
            if (widget.initialData?['walletName'] != null && wallets.isNotEmpty) {
              final wName = widget.initialData!['walletName'].toString().toLowerCase();
              final matched = wallets.where((w) => w.name.toLowerCase().contains(wName));
              if (matched.isNotEmpty) {
                targetWallet = matched.first;
              }
            }
            _selectedWallet = targetWallet ??
                (wallets.isNotEmpty
                    ? wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first)
                    : null);
          });
        }
      }
    }
  }

  void _pickWallet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF162221) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  isIncome ? 'Chọn ví nhận tiền' : 'Chọn ví chi tiền',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                ..._wallets.map((w) {
                  final isSel = _selectedWallet?.id == w.id;
                  final color = Color(w.colorValue);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark ? const Color(0xFF1A3331) : const Color(0xFFEDF7F6))
                          : (isDark ? const Color(0xFF1D2A29) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? const Color(0xFF438883) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(w.icon, color: color, size: 22),
                      ),
                      title: Text(
                        w.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        'Số dư: ${CurrencyUtils.formatCurrency(w.balance)} • ${w.typeDisplayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF438883), size: 24)
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedWallet = w);
                        Navigator.pop(ctx);
                      },
                    ),
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
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF438883)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF438883)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
              Text(
                'Ảnh hóa đơn / chứng từ',
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Chụp ảnh ngay', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Chọn từ thư viện ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _handleSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid;
    if (uid == null) return;

    final amount = CurrencyUtils.parseCurrency(_amountController.text);
    if (amount <= 0) {
      TopToast.show(context, 'Vui lòng nhập số tiền hợp lệ!', isError: true);
      return;
    }
    if (selectedCategoryName == 'Chọn danh mục') {
      TopToast.show(context, 'Vui lòng chọn danh mục thu/chi!', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
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
        if (_selectedWallet == null) {
          TopToast.show(context, 'Vui lòng chọn ví tiền!', isError: true);
          setState(() => _isLoading = false);
          return;
        }
        final walletId = _selectedWallet!.id;
        final transactionId = const Uuid().v4();

        String permanentLocalPath = '';
        String finalPhotoUrl = '';
        String finalStoragePath = '';

        // 1. Lưu ảnh hóa đơn VĨNH VIỄN vào SQLite và tạo Base64 fallback đồng bộ Firestore
        if (_pickedPhoto != null) {
          final receiptRes = await ReceiptStorageService().processAndUploadReceipt(
            uid: uid,
            transactionId: transactionId,
            pickedFile: File(_pickedPhoto!.path),
          );
          permanentLocalPath = receiptRes.photoLocalPath;
          finalPhotoUrl = receiptRes.photoUrl;
          finalStoragePath = receiptRes.photoStoragePath;
        }

        final transaction = TransactionModel(
          id: transactionId,
          uid: uid,
          type: isIncome ? 'income' : 'expense',
          category: selectedCategoryName,
          categoryIconCode: selectedCategoryIcon.codePoint,
          amount: amount,
          date: _selectedDate,
          time: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          description: _descriptionController.text.trim(),
          walletId: walletId,
          hasPhoto: _pickedPhoto != null,
          photoLocalPath: permanentLocalPath,
          photoUrl: finalPhotoUrl,
          photoStoragePath: finalStoragePath,
        );

        // 2. Lưu vào SQLite và cân đối số dư ví trong 1 transaction nguyên tử
        await TransactionBalanceService().addTransactionAtomic(transaction);

        // 4. Kích hoạt sync nền
        final isOnline = ConnectivityService().isOnline;
        if (isOnline) {
          try {
            SyncService().syncNow();
          } catch (_) {}
        }

        // 5. Cập nhật trạng thái nhắc nhở hàng ngày (không bắn thông báo ra ngoài màn hình)
        SmartNotificationService.instance.syncDailyReminderState();

        // 6. Kiểm tra hạn mức chi tiêu
        if (!isIncome) {
          final prefs = await SharedPreferences.getInstance();
          final limitEnabled = prefs.getBool('daily_limit_enabled') ?? false;
          final limitAmount = prefs.getDouble('daily_spending_limit') ?? 0.0;
          if (limitEnabled && limitAmount > 0) {
            SmartNotificationService.instance.checkDailySpendingLimit(newExpenseAmount: amount);
          }
        }
      }

      if (!mounted) return;
      final isOnline = ConnectivityService().isOnline;
      TopToast.show(
        context,
        isOnline
            ? 'Đã lưu & đồng bộ lên Firebase thành công ☁️'
            : 'Đã lưu vào máy (sẽ tự động đồng bộ khi có mạng) 💾',
      );
      Navigator.pop(context);
    } catch (e) {
      TopToast.show(context, 'Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    setState(() {
      _pickedPhoto = null;
      selectedCategoryName = 'Chọn danh mục';
      selectedCategoryIcon = Icons.category_rounded;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
    TopToast.show(context, 'Đã làm mới thông tin giao dịch');
  }

  void _addQuickAmount(double delta) {
    HapticFeedback.lightImpact();
    final current = CurrencyUtils.parseCurrency(_amountController.text);
    final next = current + delta;
    _amountController.text = NumberFormat.currency(locale: 'vi_VN', symbol: '').format(next).trim();
    setState(() {});
  }

  void _clearAmount() {
    HapticFeedback.lightImpact();
    _amountController.clear();
    setState(() {});
  }

  bool get _hasUnsavedData {
    final hasAmount = _amountController.text.trim().isNotEmpty && _amountController.text.trim() != '0';
    final hasDesc = _descriptionController.text.trim().isNotEmpty;
    final hasPhoto = _pickedPhoto != null;
    return hasAmount || hasDesc || hasPhoto;
  }

  Future<bool> _confirmExit() async {
    if (!_hasUnsavedData) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hủy giao dịch?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Nội dung bạn đang nhập chưa được lưu. Bạn có chắc muốn thoát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục nhập'),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = isIncome ? const Color(0xFF2ECC71) : const Color(0xFFE63946);

    final dateFormatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeFormatted =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

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
        backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ════════ TOP APP BAR (ĐỒNG BỘ PHONG CÁCH) ════════
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedScaleButton(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        if (await _confirmExit()) {
                          nav.pop();
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    Text(
                      widget.initialData?['isFundAction'] == true
                          ? 'Góp / Rút Quỹ'
                          : (isIncome ? 'Thêm Khoản Thu' : 'Thêm Khoản Chi'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    AnimatedScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _resetForm();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ════════ MAIN CONTENT CONTAINER (CURVED TOP 30PX) ════════
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. SEGMENTED SWITCHER: CHI VS THU
                        if (widget.initialData?['isFundAction'] != true) ...[
                          Container(
                            height: 46,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2827) : const Color(0xFFEDF2F1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                _buildTypeSegment(
                                  title: 'Khoản Chi',
                                  icon: Icons.arrow_upward_rounded,
                                  isSelected: !isIncome,
                                  activeColor: const Color(0xFFE63946),
                                  isDark: isDark,
                                  onTap: () {
                                    if (isIncome) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isIncome = false;
                                        selectedCategoryName = 'Chọn danh mục';
                                        selectedCategoryIcon = Icons.category_rounded;
                                      });
                                    }
                                  },
                                ),
                                _buildTypeSegment(
                                  title: 'Khoản Thu',
                                  icon: Icons.arrow_downward_rounded,
                                  isSelected: isIncome,
                                  activeColor: const Color(0xFF2ECC71),
                                  isDark: isDark,
                                  onTap: () {
                                    if (!isIncome) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isIncome = true;
                                        selectedCategoryName = 'Chọn danh mục';
                                        selectedCategoryIcon = Icons.category_rounded;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 2. HERO AMOUNT CARD (CÔNG THÁI HỌC SỐ TIỀN)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF162423), const Color(0xFF131D1C)]
                                  : [Colors.white, const Color(0xFFFAFCFB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: activeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: isDark ? 0.08 : 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isIncome ? 'SỐ TIỀN THU VÀO' : 'SỐ TIỀN CHI RA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: activeColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: activeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'VND (₫)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: activeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    isIncome ? '+' : '-',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: activeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  if (_amountController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.cancel_rounded, size: 22),
                                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                                      onPressed: _clearAmount,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // QUICK-AMOUNT CHIPS (CÔNG THÁI HỌC CHẠM NHANH)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildQuickAmountChip('+10k', 10000, activeColor, isDark),
                                    _buildQuickAmountChip('+20k', 20000, activeColor, isDark),
                                    _buildQuickAmountChip('+50k', 50000, activeColor, isDark),
                                    _buildQuickAmountChip('+100k', 100000, activeColor, isDark),
                                    _buildQuickAmountChip('+200k', 200000, activeColor, isDark),
                                    _buildQuickAmountChip('+500k', 500000, activeColor, isDark),
                                    _buildQuickAmountChip('+1Tr', 1000000, activeColor, isDark),
                                    _buildClearChip(isDark),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. CARD: NGUỒN TIỀN & DANH MỤC
                        _buildSectionCard(
                          title: 'NGUỒN TIỀN & DANH MỤC',
                          icon: Icons.account_balance_wallet_rounded,
                          activeColor: activeColor,
                          isDark: isDark,
                          children: [
                            if (widget.initialData?['fundActionType'] != 'contribute') ...[
                              _buildSelectorTile(
                                isDark: isDark,
                                label: isIncome ? 'Danh mục thu' : 'Danh mục chi',
                                value: selectedCategoryName,
                                leadingIcon: selectedCategoryIcon,
                                iconColor: CategoryUtils.getVibrantColor(selectedCategoryName),
                                bgColor: CategoryUtils.getLightBgColor(selectedCategoryName, isDark),
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  final result = await Navigator.push(
                                    context,
                                    PageTransitions.slideRight(CategoryScreen(isIncome: isIncome)),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      selectedCategoryName = result['name'];
                                      selectedCategoryIcon = result['icon'];
                                    });
                                  }
                                },
                              ),
                              Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              ),
                            ],
                            if (widget.initialData?['isFundAction'] != true) ...[
                              _buildSelectorTile(
                                isDark: isDark,
                                label: isIncome ? 'Nhận vào ví' : 'Trừ từ ví',
                                value: _selectedWallet?.name ?? 'Chọn ví tiền',
                                subtitle: _selectedWallet != null
                                    ? 'Số dư: ${CurrencyUtils.formatCurrency(_selectedWallet!.balance)} • ${_selectedWallet!.typeDisplayName}'
                                    : null,
                                leadingIcon: _selectedWallet?.icon ?? Icons.account_balance_wallet_rounded,
                                iconColor: Color(_selectedWallet?.colorValue ?? 0xFF438883),
                                bgColor: Color(_selectedWallet?.colorValue ?? 0xFF438883).withValues(alpha: 0.15),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _pickWallet();
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 4. CARD: THỜI GIAN & GHI CHÚ
                        _buildSectionCard(
                          title: 'THỜI GIAN & GHI CHÚ',
                          icon: Icons.calendar_today_rounded,
                          activeColor: activeColor,
                          isDark: isDark,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniTile(
                                    isDark: isDark,
                                    label: 'Ngày ghi',
                                    value: dateFormatted,
                                    icon: Icons.event_rounded,
                                    onTap: _pickDate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniTile(
                                    isDark: isDark,
                                    label: 'Thời gian',
                                    value: timeFormatted,
                                    icon: Icons.schedule_rounded,
                                    onTap: _pickTime,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // CHIPS CHỌN NHANH THỜI GIAN
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildQuickTimeChip(
                                    'Hôm nay',
                                    () {
                                      final now = DateTime.now();
                                      setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
                                    },
                                    isSelected: _isSameDay(_selectedDate, DateTime.now()),
                                    isDark: isDark,
                                  ),
                                  _buildQuickTimeChip(
                                    'Hôm qua',
                                    () {
                                      final yesterday = DateTime.now().subtract(const Duration(days: 1));
                                      setState(() => _selectedDate = DateTime(yesterday.year, yesterday.month, yesterday.day));
                                    },
                                    isSelected: _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1))),
                                    isDark: isDark,
                                  ),
                                  _buildQuickTimeChip(
                                    'Hôm kia',
                                    () {
                                      final dayBefore = DateTime.now().subtract(const Duration(days: 2));
                                      setState(() => _selectedDate = DateTime(dayBefore.year, dayBefore.month, dayBefore.day));
                                    },
                                    isSelected: _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 2))),
                                    isDark: isDark,
                                  ),
                                  _buildQuickTimeChip(
                                    'Bây giờ',
                                    () => setState(() => _selectedTime = TimeOfDay.now()),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(
                              height: 1,
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            ),
                            const SizedBox(height: 14),

                            // Ô NHẬP NỘI DUNG / MÔ TẢ
                            TextFormField(
                              controller: _descriptionController,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập ghi chú hoặc mô tả chi tiết...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.edit_note_rounded,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  size: 22,
                                ),
                                suffixIcon: _descriptionController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _descriptionController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: isDark ? const Color(0xFF14201F) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: activeColor, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 5. CARD: HÓA ĐƠN & ẢNH ĐÍNH KÈM (FIX LỖI SCALE & CÔNG THÁI HỌC)
                        _buildSectionCard(
                          title: 'HÓA ĐƠN & ẢNH ĐÍNH KÈM',
                          icon: Icons.receipt_long_rounded,
                          activeColor: activeColor,
                          isDark: isDark,
                          children: [
                            if (_pickedPhoto == null)
                              InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showPhotoPickerSheet();
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF14201F) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: activeColor.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.add_a_photo_rounded, color: activeColor, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Chụp hoặc tải ảnh hóa đơn (tùy chọn)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              // Khung xem hóa đơn hiển thị trọn vẹn (Adaptive Scale - Không bị cắt xén)
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Chạm vào ảnh để mở InteractiveViewer phóng to cảm ứng đa điểm
                                    GestureDetector(
                                      onTap: () {
                                        ReceiptStorageService.showFullScreenViewer(
                                          context,
                                          photoLocalPath: _pickedPhoto!.path,
                                          photoUrl: '',
                                          title: 'Hóa đơn xem chi tiết',
                                        );
                                      },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                            child: Container(
                                              constraints: const BoxConstraints(maxHeight: 280, minHeight: 160),
                                              width: double.infinity,
                                              color: isDark ? const Color(0xFF0D1615) : const Color(0xFFF1F5F9),
                                              child: Image.file(
                                                File(_pickedPhoto!.path),
                                                fit: BoxFit.contain, // GIỮ NGUYÊN TỈ LỆ 100%, KHÔNG CẮT XÉN CHỮ
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.white24, width: 0.8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 15),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Chạm để phóng to xem chi tiết',
                                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Thanh công cụ dưới ảnh
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFF438883),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                            label: const Text('Đổi / Chụp lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            onPressed: _showPhotoPickerSheet,
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                            label: const Text('Xóa ảnh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              setState(() => _pickedPhoto = null);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // THÔNG BÁO QUỸ NHÓM NẾU CÓ
                        if (widget.initialData?['isFundAction'] == true &&
                            widget.initialData?['isPersonalGroup'] != true) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ════════ ERGONOMIC BOTTOM ACTION BAR (THUMB ZONE) ════════
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141E1D) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: AnimatedScaleButton(
            onTap: () {
              if (!_isLoading) {
                _handleSave();
              }
            },
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIncome
                      ? [const Color(0xFF2ECC71), const Color(0xFF27AE60)]
                      : [const Color(0xFFE63946), const Color(0xFFD62828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIncome ? Icons.check_circle_rounded : Icons.save_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isIncome ? 'Lưu Khoản Thu' : 'Lưu Khoản Chi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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

  // ════════ WIDGET BUILDERS PHỤ TRỢ ════════

  Widget _buildTypeSegment({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, double amount, Color activeColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScaleButton(
        onTap: () => _addQuickAmount(amount),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2E2C) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearChip(bool isDark) {
    return AnimatedScaleButton(
      onTap: _clearAmount,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
        ),
        child: const Text(
          'Xóa (C)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color activeColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172423) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: activeColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSelectorTile({
    required bool isDark,
    required String label,
    required String value,
    String? subtitle,
    required IconData leadingIcon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(leadingIcon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTile({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14201F) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF438883)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeChip(
    String label,
    VoidCallback onTap, {
    bool isSelected = false,
    required bool isDark,
  }) {
    const primaryColor = Color(0xFF438883);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedScaleButton(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? primaryColor : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }
}
