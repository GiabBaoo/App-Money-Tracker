import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../widgets/mono_dialog.dart';
import '../../widgets/animated_scale_button.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/transaction_balance_service.dart';
import '../../services/sync_service.dart';
import '../../services/location_service.dart';
import '../../data/repositories/user_repository.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/category_utils.dart';
import '../../services/category_style_service.dart';
import '../../services/language_service.dart';
import 'category_screen.dart';
import 'widgets/fintech_keypad.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../services/frequent_amount_service.dart';
import 'widgets/category_keyword_suggestions.dart';

/// Màn hình Thêm Giao Dịch Thu / Chi thế hệ mới
/// - Tối ưu 60-120fps, triệt tiêu hoàn toàn giật lag
/// - Bàn phím số Fintech tích hợp (.000, haptic, phím lớn)
/// - Bộ gợi ý số tiền thông minh theo thời gian thực (7 -> 7k, 70k, 700k, 7tr)
/// - Dải danh mục nhanh 1 chạm (Quick Category Chips)
/// - Ô GHI NỘI DUNG INLINE TRỰC TIẾP (Zero Jank, không popup)
/// - Dải Tag gợi ý nội dung nhanh theo danh mục (Ăn sáng, Cafe, Đổ xăng... 1 chạm là xong)
/// - Tách rời Pop animation và tác vụ nền để đóng màn hình mượt mà tuyệt đối
class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final DateTime? initialDate;
  final bool? initialIsIncome;

  const AddTransactionScreen({
    super.key,
    this.initialData,
    this.initialDate,
    this.initialIsIncome,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final WalletRepository _walletRepo = WalletRepository();
  final ImagePicker _imagePicker = ImagePicker();

  // State tách rời để gõ phím siêu tốc không rebuild toàn bộ màn hình
  final ValueNotifier<String> _amountRawNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _isTypingNoteNotifier = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  final ValueNotifier<bool> _isKeypadCollapsedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isHabitAutofilledNotifier = ValueNotifier<bool>(false);
  Timer? _debounceHabitAutofillTimer;
  String? _autoFilledCategory;
  String? _autoFilledDescription;
  bool get _isManualEntry => widget.initialData == null;

  bool isIncome = false; // Mặc định là Khoản Chi
  bool _isLoading = false;

  XFile? _pickedPhoto;

  String selectedCategoryName = 'Ăn uống';
  IconData selectedCategoryIcon = Icons.restaurant_outlined;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();

  WalletModel? _selectedWallet;
  List<WalletModel> _wallets = [];

  // Vị trí địa danh GPS
  String? _locationName;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  // Top danh mục chi phổ biến nhất
  static const List<String> _topExpenseCategories = [
    'Ăn uống',
    'Mua sắm',
    'Di chuyển',
    'Tiền điện',
    'Tiền nhà',
    'Giải trí',
    'Sức khỏe',
    'Chi khác',
  ];

  // Top danh mục thu phổ biến nhất
  static const List<String> _topIncomeCategories = [
    'Tiền lương',
    'Tiền thưởng',
    'Kinh doanh',
    'Đầu tư',
    'Bán đồ',
    'Tiền lãi',
    'Thu khác',
  ];

  @override
  void initState() {
    super.initState();
    DateTime initial = widget.initialDate ?? DateTime.now();
    if (widget.initialData != null) {
      if (widget.initialData!['date'] is DateTime) {
        initial = widget.initialData!['date'] as DateTime;
      } else if (widget.initialData!['date'] is String) {
        final parsed = DateTime.tryParse(widget.initialData!['date']);
        if (parsed != null) initial = parsed;
      }
    }
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _loadWallets();

    // Lắng nghe focus của ô ghi chú với ValueNotifier để cô lập render, không rebuild toàn trang
    _noteFocusNode.addListener(() {
      final hasFocus = _noteFocusNode.hasFocus;
      if (_isTypingNoteNotifier.value != hasFocus) {
        _isTypingNoteNotifier.value = hasFocus;
      }
      if (hasFocus) {
        // Tự động cuộn êm ái đưa ô ghi chú vào tầm mắt khi mở bàn phím
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    });

    // Khởi tạo loại giao dịch
    if (widget.initialIsIncome != null) {
      isIncome = widget.initialIsIncome!;
    }

    if (widget.initialData != null) {
      isIncome = widget.initialData!['type'] == 'income';

      if (widget.initialData!['fundActionType'] == 'contribute') {
        selectedCategoryName = 'Chi khác';
        selectedCategoryIcon = Icons.receipt_long_outlined;
      } else {
        selectedCategoryName = widget.initialData!['category'] ??
            (isIncome ? 'Tiền lương' : 'Ăn uống');
        if (widget.initialData!['iconCode'] != null) {
          selectedCategoryIcon = IconData(
            widget.initialData!['iconCode'],
            fontFamily: 'MaterialIcons',
          );
        } else {
          selectedCategoryIcon =
              CategoryUtils.getCategoryIcon(selectedCategoryName);
        }
      }

      if (widget.initialData!['amount'] != null) {
        final amt = widget.initialData!['amount'];
        if (amt is num && amt > 0) {
          _amountRawNotifier.value = amt.toInt().toString();
        }
      }

      _descriptionController.text = widget.initialData!['description'] ?? '';

      if (widget.initialData!['hour'] != null &&
          widget.initialData!['minute'] != null) {
        _selectedTime = TimeOfDay(
          hour: widget.initialData!['hour'],
          minute: widget.initialData!['minute'],
        );
      } else if (widget.initialData!['time'] != null &&
          widget.initialData!['time'].toString().contains(':')) {
        final parts = widget.initialData!['time'].toString().split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            _selectedTime = TimeOfDay(hour: h, minute: m);
          }
        }
      }

      if (widget.initialData!['photoPath'] != null &&
          widget.initialData!['photoPath'].toString().isNotEmpty) {
        final path = widget.initialData!['photoPath'].toString();
        if (File(path).existsSync()) {
          _pickedPhoto = XFile(path);
        }
      }

      if (widget.initialData!['location'] != null) {
        _locationName = widget.initialData!['location'].toString();
      }
      if (widget.initialData!['latitude'] != null) {
        _latitude = (widget.initialData!['latitude'] as num?)?.toDouble();
      }
      if (widget.initialData!['longitude'] != null) {
        _longitude = (widget.initialData!['longitude'] as num?)?.toDouble();
      }
    } else {
      selectedCategoryName = isIncome ? 'Tiền lương' : 'Ăn uống';
      selectedCategoryIcon = CategoryUtils.getCategoryIcon(selectedCategoryName);
      if (!isIncome) {
        _tryAutoFetchLocation();
      }
    }
    CategoryStyleService.instance.addListener(_onCategoryStyleChanged);
  }

  void _onCategoryStyleChanged() {
    if (mounted) {
      setState(() {
        selectedCategoryIcon = CategoryUtils.getCategoryIcon(
          selectedCategoryName,
          fallbackCode: selectedCategoryIcon.codePoint,
        );
      });
    }
  }

  @override
  void dispose() {
    CategoryStyleService.instance.removeListener(_onCategoryStyleChanged);
    _debounceHabitAutofillTimer?.cancel();
    _amountRawNotifier.dispose();
    _isTypingNoteNotifier.dispose();
    _isKeypadCollapsedNotifier.dispose();
    _isHabitAutofilledNotifier.dispose();
    _scrollController.dispose();
    _descriptionController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadWallets() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid;
    if (uid != null) {
      _walletRepo.setUid(uid);
      await _walletRepo.ensureDefaultWalletExists(uid);
      final wallets = await _walletRepo.getWallets();
      if (mounted) {
        setState(() {
          _wallets = wallets;
          WalletModel? targetWallet;
          if (widget.initialData?['walletName'] != null && wallets.isNotEmpty) {
            final wName =
                widget.initialData!['walletName'].toString().toLowerCase();
            final matched =
                wallets.where((w) => w.name.toLowerCase().contains(wName));
            if (matched.isNotEmpty) {
              targetWallet = matched.first;
            }
          }
          _selectedWallet = targetWallet ??
              (wallets.isNotEmpty
                  ? wallets.firstWhere((w) => w.isDefault,
                      orElse: () => wallets.first)
                  : null);
        });
      }
    }
  }

  void _onAmountChanged(String rawText) {
    _debounceHabitAutofillTimer?.cancel();

    if (!_isManualEntry) return;

    final cleanDigits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      if (_isHabitAutofilledNotifier.value) {
        if (selectedCategoryName == _autoFilledCategory) {
          setState(() {
            selectedCategoryName = isIncome ? 'Tiền lương' : 'Ăn uống';
            selectedCategoryIcon = CategoryUtils.getCategoryIcon(selectedCategoryName);
          });
        }
        if (_descriptionController.text == _autoFilledDescription) {
          _descriptionController.clear();
        }
        _isHabitAutofilledNotifier.value = false;
        _autoFilledCategory = null;
        _autoFilledDescription = null;
      }
      return;
    }

    final amount = double.tryParse(cleanDigits) ?? 0.0;
    if (amount <= 0) return;

    _debounceHabitAutofillTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final pattern = FrequentAmountService.findRecurringPattern(
        transactions: TransactionRepository().latestTransactions,
        isIncome: isIncome,
        amount: amount,
        minOccurrences: 2,
      );

      if (pattern != null) {
        setState(() {
          selectedCategoryName = pattern.category;
          selectedCategoryIcon = CategoryUtils.getCategoryIcon(pattern.category);
        });
        if (pattern.description.isNotEmpty) {
          _descriptionController.text = pattern.description;
        } else if (_descriptionController.text == _autoFilledDescription) {
          _descriptionController.clear();
        }
        _autoFilledCategory = pattern.category;
        _autoFilledDescription = pattern.description;
        _isHabitAutofilledNotifier.value = true;
        HapticFeedback.selectionClick();
      } else {
        if (_isHabitAutofilledNotifier.value) {
          if (selectedCategoryName == _autoFilledCategory) {
            setState(() {
              selectedCategoryName = isIncome ? 'Tiền lương' : 'Ăn uống';
              selectedCategoryIcon = CategoryUtils.getCategoryIcon(selectedCategoryName);
            });
          }
          if (_descriptionController.text == _autoFilledDescription) {
            _descriptionController.clear();
          }
          _isHabitAutofilledNotifier.value = false;
          _autoFilledCategory = null;
          _autoFilledDescription = null;
        }
      }
    });
  }

  void _onCategorySelected(String name, IconData icon) {
    setState(() {
      selectedCategoryName = name;
      selectedCategoryIcon = icon;
    });
    if (selectedCategoryName != _autoFilledCategory) {
      _isHabitAutofilledNotifier.value = false;
      _autoFilledCategory = null;
    }
  }

  void _onKeypadPress(String value) {
    _noteFocusNode.unfocus();
    final current = _amountRawNotifier.value;
    if (current.length >= 13) return;

    if (current.isEmpty || current == '0') {
      if (value == '000') return;
      _amountRawNotifier.value = value;
    } else {
      _amountRawNotifier.value = current + value;
    }
    _onAmountChanged(_amountRawNotifier.value);
  }

  void _onKeypadDelete() {
    _noteFocusNode.unfocus();
    final current = _amountRawNotifier.value;
    if (current.isNotEmpty) {
      _amountRawNotifier.value = current.substring(0, current.length - 1);
    }
    _onAmountChanged(_amountRawNotifier.value);
  }

  void _onKeypadClear() {
    _noteFocusNode.unfocus();
    _amountRawNotifier.value = '';
    _isKeypadCollapsedNotifier.value = false;
    _onAmountChanged('');
  }


  void _onSelectKeywordTag(String keyword) {
    HapticFeedback.lightImpact();
    _descriptionController.text = keyword;
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
  }

  double get _currentAmountValue {
    final clean = _amountRawNotifier.value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _handleSave() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid;
    if (uid == null) return;

    final amount = _currentAmountValue;
    if (amount <= 0) {
      TopToast.show(context, context.tr('transfer_amount_error'), isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final isFundAction = widget.initialData?['isFundAction'] == true;

      if (isFundAction) {
        final groupId = widget.initialData!['groupId'];
        final fundActionType =
            widget.initialData!['fundActionType'] == 'withdraw'
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
          TopToast.show(context, context.tr('select_wallet_prompt'), isError: true);
          setState(() => _isLoading = false);
          return;
        }

        final walletId = _selectedWallet!.id;
        final transactionId = const Uuid().v4();

        String permanentLocalPath = '';
        String finalPhotoUrl = '';
        String finalStoragePath = '';

        if (_pickedPhoto != null) {
          final receiptRes =
              await ReceiptStorageService().processAndUploadReceipt(
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
          date: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          ),
          time:
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          description: _descriptionController.text.trim(),
          walletId: walletId,
          hasPhoto: _pickedPhoto != null,
          photoLocalPath: permanentLocalPath,
          photoUrl: finalPhotoUrl,
          photoStoragePath: finalStoragePath,
          location: _locationName,
          latitude: _latitude,
          longitude: _longitude,
        );

        // Lưu vào SQLite nguyên tử
        await TransactionBalanceService().addTransactionAtomic(transaction);

        // Chạy các tác vụ nền không chặn UI thread
        unawaited(_runBackgroundPostSaveTasks(amount, isIncome, selectedCategoryName));
      }

      if (!mounted) return;
      TopToast.show(
        context,
        isIncome ? context.tr('add_income_success') : context.tr('add_expense_success'),
      );
      // Đóng màn hình ngay lập tức để đạt độ mượt tối đa
      Navigator.pop(context, true);
    } catch (e) {
      TopToast.show(context, '${context.tr('error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runBackgroundPostSaveTasks(
    double amount,
    bool isInc,
    String catName,
  ) async {
    try {
      if (ConnectivityService().isOnline) {
        SyncService().syncNow();
      }
      SmartNotificationService.instance.syncDailyReminderState();
      if (!isInc) {
        SmartNotificationService.instance
            .checkDailySpendingLimit(newExpenseAmount: amount);
        SmartNotificationService.instance
            .checkMonthlySpendingLimit(newExpenseAmount: amount);
        SmartNotificationService.instance.checkSpendingSpike(
          amount: amount,
          category: catName,
        );
      }
    } catch (_) {}
  }

  void _resetForm() {
    _noteFocusNode.unfocus();
    _amountRawNotifier.value = '';
    _descriptionController.clear();
    setState(() {
      _pickedPhoto = null;
      _locationName = null;
      _latitude = null;
      _longitude = null;
      _isLocating = false;
      selectedCategoryName = isIncome ? 'Tiền lương' : 'Ăn uống';
      selectedCategoryIcon = CategoryUtils.getCategoryIcon(selectedCategoryName);
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay.now();
    });
    TopToast.show(context, context.tr('form_reset_toast'));
  }

  void _pickWallet() {
    _noteFocusNode.unfocus();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isIncome ? context.tr('transfer_to') : context.tr('transfer_from'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                ..._wallets.map((w) {
                  final isSel = _selectedWallet?.id == w.id;
                  final color = Color(w.colorValue);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEDF7F6))
                          : (isDark
                              ? const Color(0xFF141E2E)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel
                            ? (isDark ? const Color(0xFF2DD4BF) : const Color(0xFF438883))
                            : (isDark ? const Color(0xFF334155) : Colors.transparent),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(w.icon, color: color, size: 22),
                      ),
                      title: Text(
                        context.trWallet(w.name),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        '${context.tr('balance_prefix')}: ${CurrencyUtils.formatCurrency(w.balance)} • ${w.typeDisplayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF438883),
                              size: 24,
                            )
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
    _noteFocusNode.unfocus();
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF2DD4BF),
                  surface: Color(0xFF1E293B),
                  onSurface: Color(0xFFF8FAFC),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Color(0xFF1E293B),
                ),
              )
            : Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xFF438883)),
              ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    _noteFocusNode.unfocus();
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF2DD4BF),
                  surface: Color(0xFF1E293B),
                  onSurface: Color(0xFFF8FAFC),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Color(0xFF1E293B),
                ),
              )
            : Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Color(0xFF438883)),
              ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickTransactionPhotoFromSource(ImageSource source) async {
    _noteFocusNode.unfocus();
    final picked =
        await BiometricService.instance.runWithPickerSuspended(() async {
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
    _noteFocusNode.unfocus();
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
                context.tr('receipt_photo'),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(context.tr('take_photo'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickTransactionPhotoFromSource(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(context.tr('choose_from_gallery'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
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

  Future<bool> _confirmExit() async {
    if (_amountRawNotifier.value.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _pickedPhoto != null) {
      final shouldLeave = await MonoDialog.confirm(
        context,
        title: context.tr('discard_tx_title'),
        message: context.tr('discard_tx_content'),
        cancelText: context.tr('keep_editing'),
        confirmText: context.tr('discard'),
        isDestructive: true,
        icon: Icons.warning_amber_rounded,
      );
      return shouldLeave ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor =
        isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final dateFormatted =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}';

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
        resizeToAvoidBottomInset: true, // Tự động cuộn êm ái khi bàn phím chữ mở
        backgroundColor:
            isDark ? const Color(0xFF091615) : const Color(0xFFF8FAFC),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F2625), const Color(0xFF091615)]
                  : [const Color(0xFF438883), const Color(0xFFF8FAFC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.28],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ════════ TOP APP BAR ════════
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                      Text(
                        widget.initialData?['isFundAction'] == true
                            ? context.tr('fund_action')
                            : (isIncome ? context.tr('tx_income') : context.tr('tx_expense')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17.5,
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
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ════════ NỘI DUNG CUỘN CHÍNH ════════
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. LIQUID SEGMENTED SWITCHER: CHI VS THU
                        if (widget.initialData?['isFundAction'] != true) ...[
                          Container(
                            height: 46,
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.3 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                _buildTypeSegment(
                                  title: context.tr('tx_expense'),
                                  icon: Icons.arrow_upward_rounded,
                                  isSelected: !isIncome,
                                  activeColor: const Color(0xFFEF4444),
                                  isDark: isDark,
                                  onTap: () {
                                    if (isIncome) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isIncome = false;
                                        selectedCategoryName = 'Ăn uống';
                                        selectedCategoryIcon =
                                            CategoryUtils.getCategoryIcon('Ăn uống');
                                      });
                                      _isHabitAutofilledNotifier.value = false;
                                      _autoFilledCategory = null;
                                      _autoFilledDescription = null;
                                      _onAmountChanged(_amountRawNotifier.value);
                                    }
                                  },
                                ),
                                _buildTypeSegment(
                                  title: context.tr('tx_income'),
                                  icon: Icons.arrow_downward_rounded,
                                  isSelected: isIncome,
                                  activeColor: const Color(0xFF10B981),
                                  isDark: isDark,
                                  onTap: () {
                                    if (!isIncome) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        isIncome = true;
                                        selectedCategoryName = 'Tiền lương';
                                        selectedCategoryIcon =
                                            CategoryUtils.getCategoryIcon('Tiền lương');
                                      });
                                      _isHabitAutofilledNotifier.value = false;
                                      _autoFilledCategory = null;
                                      _autoFilledDescription = null;
                                      _onAmountChanged(_amountRawNotifier.value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 2. HERO AMOUNT CARD (Hiển thị số tiền to, rõ, không lag)
                        GestureDetector(
                          onTap: () {
                            _noteFocusNode.unfocus();
                            if (_isKeypadCollapsedNotifier.value) {
                              _isKeypadCollapsedNotifier.value = false;
                            }
                          },
                          child: ValueListenableBuilder<String>(
                            valueListenable: _amountRawNotifier,
                            builder: (context, rawText, _) {
                              final parsed = double.tryParse(rawText) ?? 0.0;
                              final formattedAmount = parsed > 0
                                  ? CurrencyUtils.formatCurrency(parsed)
                                  : CurrencyUtils.formatCurrency(0);

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: activeColor.withValues(
                                        alpha: isDark ? 0.35 : 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeColor.withValues(
                                          alpha: isDark ? 0.12 : 0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isIncome
                                              ? context.tr('income').toUpperCase()
                                              : context.tr('expense').toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.1,
                                            color: activeColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: activeColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'VND (₫)',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: activeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
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
                                          child: Text(
                                            formattedAmount,
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (rawText.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.cancel_rounded,
                                              size: 22,
                                            ),
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade400,
                                            onPressed: _onKeypadClear,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),



                        const SizedBox(height: 14),

                        // 4. DẢI DANH MỤC NHANH 1 CHẠM
                        _buildQuickCategorySection(isDark, activeColor),

                        const SizedBox(height: 14),

                        // 5. Ô GHI NỘI DUNG / GHI CHÚ TRỰC TIẾP (INLINE - TRIỆT TIÊU GIẬT LAG)
                        _buildInlineNoteSection(isDark, activeColor),

                        const SizedBox(height: 14),

                        // 6. THẺ NGUỒN TIỀN (VÍ), THỜI GIAN & HÓA ĐƠN
                        _buildOptionsRow(isDark, dateFormatted),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // ════════ BÀN PHÍM FINTECH HOẶC NÚT LƯU KHI ĐANG GÕ CHỮ ════════
                ValueListenableBuilder<bool>(
                  valueListenable: _isTypingNoteNotifier,
                  builder: (context, isTypingNote, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // THANH THU GỌN / ẨN BÀN PHÍM
                          ValueListenableBuilder<bool>(
                            valueListenable: _isKeypadCollapsedNotifier,
                            builder: (context, isCollapsed, _) {
                              final shouldShowKeypad = !isTypingNote && !isCollapsed;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Nút ẩn / hiện bàn phím
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (_noteFocusNode.hasFocus) {
                                        _noteFocusNode.unfocus();
                                      } else {
                                        _isKeypadCollapsedNotifier.value = !isCollapsed;
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white30 : Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            isTypingNote || !isCollapsed
                                                ? Icons.keyboard_hide_rounded
                                                : Icons.keyboard_rounded,
                                            size: 15,
                                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isTypingNote || !isCollapsed
                                                ? (LanguageService.instance.isVietnamese ? 'Ẩn bàn phím' : 'Hide keypad')
                                                : (LanguageService.instance.isVietnamese ? 'Hiện bàn phím' : 'Show keypad'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOutCubic,
                                    child: shouldShowKeypad
                                        ? RepaintBoundary(
                                            child: FintechKeypad(
                                              onKeyPress: _onKeypadPress,
                                              onDelete: _onKeypadDelete,
                                              onClear: _onKeypadClear,
                                              activeColor: activeColor,
                                              isDark: isDark,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                          ),

                          // NÚT LƯU GIAO DỊCH
                          Padding(
                            padding: EdgeInsets.only(
                              left: 14,
                              right: 14,
                              top: isTypingNote ? 12 : 4,
                              bottom: isTypingNote
                                  ? 12
                                  : MediaQuery.paddingOf(context).bottom + 8,
                            ),
                            child: AnimatedScaleButton(
                              onTap: () {
                                if (!_isLoading) {
                                  _handleSave();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isIncome
                                        ? [
                                            const Color(0xFF10B981),
                                            const Color(0xFF059669)
                                          ]
                                        : [
                                            const Color(0xFFEF4444),
                                            const Color(0xFFDC2626)
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isIncome
                                                  ? Icons.check_circle_rounded
                                                  : Icons.save_rounded,
                                              color: Colors.white,
                                              size: 19,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${context.tr('save')} ${isIncome ? context.tr('tx_income') : context.tr('tx_expense')}',
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
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════ CÁC WIDGET PHỤ TRỢ ════════

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
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

  Widget _buildQuickCategorySection(bool isDark, Color activeColor) {
    final categories = isIncome ? _topIncomeCategories : _topExpenseCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  (isIncome ? context.tr('top_income_categories') : context.tr('top_expense_categories')).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  _noteFocusNode.unfocus();
                  HapticFeedback.lightImpact();
                  final result = await Navigator.push(
                    context,
                    PageTransitions.slideRight(
                        CategoryScreen(isIncome: isIncome, lockType: true)),
                  );
                  if (result != null) {
                    _onCategorySelected(result['name'], result['icon']);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('see_all'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activeColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: activeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _isHabitAutofilledNotifier,
          builder: (context, isAuto, _) {
            if (!isAuto) return const SizedBox(height: 6);
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        context.tr('habit_autofilled'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return AnimatedScaleButton(
                  scaleDown: 0.92,
                  onTap: () async {
                    _noteFocusNode.unfocus();
                    HapticFeedback.lightImpact();
                    final result = await Navigator.push(
                      context,
                      PageTransitions.slideRight(
                          CategoryScreen(isIncome: isIncome, lockType: true)),
                    );
                    if (result != null) {
                      _onCategorySelected(result['name'], result['icon']);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.more_horiz_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        const SizedBox(width: 5),
                        Text(
                          '${context.tr('other')}...',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final catName = categories[index];
              final isSel = selectedCategoryName == catName;
              final catIcon = CategoryUtils.getCategoryIcon(catName);
              final vibrantColor = CategoryUtils.getVibrantColor(catName);

              return AnimatedScaleButton(
                scaleDown: 0.92,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _onCategorySelected(catName, catIcon);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? vibrantColor.withValues(alpha: isDark ? 0.35 : 0.2)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel
                          ? vibrantColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catIcon,
                          size: 16,
                          color: isSel
                              ? vibrantColor
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      const SizedBox(width: 6),
                      Text(
                        context.trCat(catName),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSel ? FontWeight.w700 : FontWeight.w600,
                          color: isSel
                              ? (isDark ? Colors.white : vibrantColor)
                              : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ════════ KHỐI NỘI DUNG / GHI CHÚ TRỰC TIẾP (INLINE & ZERO JANK) ════════
  Widget _buildInlineNoteSection(bool isDark, Color activeColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isTypingNoteNotifier,
      builder: (context, hasFocus, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasFocus
                  ? activeColor.withValues(alpha: 0.6)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              width: hasFocus ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Dải tag từ khóa thông minh theo danh mục (Ăn sáng, Cafe, Đổ xăng...)
              CategoryKeywordSuggestions(
                categoryName: selectedCategoryName,
                onSelectKeyword: _onSelectKeywordTag,
                activeColor: activeColor,
                isDark: isDark,
              ),

              const SizedBox(height: 10),

              // 2. Ô nhập văn bản trực tiếp (Inline TextField - Tách biệt State 100%)
              Container(
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF141E2E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 22,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _descriptionController,
                        focusNode: _noteFocusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _noteFocusNode.unfocus(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                        ),
                        decoration: InputDecoration(
                          hintText: context.tr('note_hint'),
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.normal,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        // Đã bỏ onChanged: setState - gõ chữ 120fps không lag
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _descriptionController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          color:
                              isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400,
                          onPressed: () => _descriptionController.clear(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionsRow(bool isDark, String dateFormatted) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Chọn ví
          _buildQuickOptionPill(
            icon: _selectedWallet?.icon ?? Icons.account_balance_wallet_rounded,
            label: _selectedWallet != null ? context.trWallet(_selectedWallet!.name) : context.tr('wallet'),
            iconColor: Color(_selectedWallet?.colorValue ?? 0xFF438883),
            isDark: isDark,
            onTap: _pickWallet,
          ),
          const SizedBox(width: 8),

          // 2. Chọn ngày
          _buildQuickOptionPill(
            icon: Icons.event_rounded,
            label: dateFormatted,
            iconColor: const Color(0xFF3B82F6),
            isDark: isDark,
            onTap: _pickDate,
          ),
          const SizedBox(width: 8),

          // 3. Giờ
          _buildQuickOptionPill(
            icon: Icons.schedule_rounded,
            label:
                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
            iconColor: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: _pickTime,
          ),
          const SizedBox(width: 8),

          // 4. Ảnh đính kèm
          _buildQuickOptionPill(
            icon: _pickedPhoto != null
                ? Icons.check_circle_rounded
                : Icons.add_a_photo_rounded,
            label: _pickedPhoto != null ? context.tr('done') : context.tr('receipt_photo'),
            iconColor: _pickedPhoto != null
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
            isDark: isDark,
            onTap: _showPhotoPickerSheet,
            isHighlighted: _pickedPhoto != null,
          ),
          const SizedBox(width: 8),

          // 5. Vị trí địa danh GPS
          _buildQuickOptionPill(
            icon: _isLocating
                ? Icons.sync_rounded
                : (_locationName != null && _locationName!.isNotEmpty
                    ? Icons.location_on_rounded
                    : Icons.add_location_alt_rounded),
            label: _isLocating
                ? (LanguageService.instance.isVietnamese ? 'Đang định vị...' : 'Locating...')
                : (_locationName != null && _locationName!.isNotEmpty
                    ? _locationName!
                    : (LanguageService.instance.isVietnamese ? 'Vị trí' : 'Location')),
            iconColor: _locationName != null && _locationName!.isNotEmpty
                ? const Color(0xFFF59E0B)
                : const Color(0xFF64748B),
            isDark: isDark,
            onTap: _handleLocationPillTap,
            isHighlighted: _locationName != null && _locationName!.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptionPill({
    required IconData icon,
    required String label,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return AnimatedScaleButton(
      scaleDown: 0.92,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? iconColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? iconColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryAutoFetchLocation() async {
    try {
      final user = await UserRepository().getUser();
      final isLocationAllowed = user?.dataUsage['location'] != false;
      if (!isLocationAllowed) return;

      final hasPerm = await LocationService.instance.hasPermission();
      if (!hasPerm) return;

      if (!mounted) return;
      setState(() => _isLocating = true);

      final res = await LocationService.instance.getCurrentPlaceName(
        timeout: const Duration(seconds: 4),
        requestPermissionIfDenied: false,
      );

      if (mounted) {
        setState(() {
          _isLocating = false;
          if (res != null) {
            _locationName = res.placeName;
            _latitude = res.latitude;
            _longitude = res.longitude;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _handleLocationPillTap() async {
    _noteFocusNode.unfocus();
    HapticFeedback.lightImpact();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageService.instance.isVietnamese;
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
                            HapticFeedback.lightImpact();
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

                            // Kiểm tra dịch vụ vị trí
                            final isServiceEnabled = await LocationService.instance.isLocationServiceEnabled();
                            if (!isServiceEnabled) {
                              setState(() => _isLocating = false);
                              if (mounted) {
                                _showGpsDisabledDialog(isVi);
                              }
                              return;
                            }

                            // Kiểm tra quyền
                            var perm = await LocationService.instance.checkPermission();
                            if (perm == LocationPermission.denied) {
                              perm = await LocationService.instance.requestPermission();
                            }

                            if (perm == LocationPermission.deniedForever) {
                              setState(() => _isLocating = false);
                              if (mounted) {
                                _showPermissionPermanentlyDeniedDialog(isVi);
                              }
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

  void _showGpsDisabledDialog(bool isVi) async {
    final open = await MonoDialog.confirm(
      context,
      title: isVi ? 'Dịch vụ vị trí đang tắt' : 'Location Services Disabled',
      message: isVi
          ? 'Vui lòng bật GPS trên thiết bị để ứng dụng tự động lấy địa danh.'
          : 'Please enable GPS on your device to automatically detect place names.',
      cancelText: isVi ? 'Đóng' : 'Close',
      confirmText: isVi ? 'Mở cài đặt' : 'Open Settings',
      icon: Icons.location_off_rounded,
    );
    if (open == true) {
      LocationService.instance.openLocationSettings();
    }
  }

  void _showPermissionPermanentlyDeniedDialog(bool isVi) async {
    final open = await MonoDialog.confirm(
      context,
      title: isVi ? 'Quyền vị trí bị chặn' : 'Location Permission Denied',
      message: isVi
          ? 'Bạn đã từ chối quyền vị trí vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền cho ứng dụng.'
          : 'Location permission is permanently denied. Please grant permission in App Settings.',
      cancelText: isVi ? 'Để sau' : 'Later',
      confirmText: isVi ? 'Mở Cài đặt' : 'Open Settings',
      icon: Icons.location_disabled_rounded,
    );
    if (open == true) {
      LocationService.instance.openAppSettings();
    }
  }
}
