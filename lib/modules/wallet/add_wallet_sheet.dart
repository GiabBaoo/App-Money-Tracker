import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/wallet_model.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../utils/currency_format_utils.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/top_toast.dart';

/// BottomSheet Thêm / Chỉnh sửa Ví tiền với Công thái học hiện đại (Thumb Zone)
/// Triệt tiêu hoàn toàn lỗi RenderFlex Overflow và tối ưu 60/120 FPS
class AddWalletSheet extends StatefulWidget {
  final WalletModel? wallet;
  final VoidCallback? onWalletSaved;

  const AddWalletSheet({
    super.key,
    this.wallet,
    this.onWalletSaved,
  });

  /// Phương thức hiển thị BottomSheet với hiệu ứng vuốt trượt mượt mà
  static Future<void> show(
    BuildContext context, {
    WalletModel? wallet,
    VoidCallback? onWalletSaved,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AddWalletSheet(
        wallet: wallet,
        onWalletSaved: onWalletSaved,
      ),
    );
  }

  @override
  State<AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<AddWalletSheet> {
  static const List<int> _paletteColors = [
    0xFF438883, // Mono Emerald
    0xFF006E33, // Vietcombank Green
    0xFF0068FF, // ZaloPay Blue
    0xFF1429A0, // MB Blue
    0xFFD82D8B, // MoMo Pink
    0xFFE31B23, // Techcombank Red
    0xFF8338EC, // Violet
    0xFFFFB703, // Amber Gold
    0xFF2A9D8F, // Mint Emerald
    0xFF0284C7, // Ocean Blue
    0xFF334155, // Slate Gray
    0xFF0F172A, // Obsidian Black
  ];

  static const List<IconData> _walletIcons = [
    Icons.payments_rounded,
    Icons.account_balance_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.phone_android_rounded,
    Icons.qr_code_rounded,
    Icons.attach_money_rounded,
    Icons.card_giftcard_rounded,
    Icons.shopping_bag_rounded,
    Icons.storefront_rounded,
    Icons.flight_takeoff_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.security_rounded,
    Icons.local_atm_rounded,
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _noteController;

  late String _selectedType;
  late int _selectedColor;
  late int _selectedIconCode;
  late bool _isDefault;
  bool _isSaving = false;

  final WalletRepository _walletRepo = WalletRepository();
  final TransactionRepository _txRepo = TransactionRepository();

  bool get _isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wallet;
    _nameController = TextEditingController(text: w?.name ?? '');
    _balanceController = TextEditingController(
      text: w != null ? (w.balance == 0 ? '0' : CurrencyUtils.formatNumberOnly(w.balance)) : '',
    );
    _noteController = TextEditingController(text: w?.note ?? '');

    _selectedType = w?.type ?? WalletType.cash;
    _selectedColor = w?.colorValue ?? _paletteColors[0];
    _selectedIconCode = w?.iconCode ?? Icons.payments_rounded.codePoint;
    _isDefault = w?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = LanguageScope.of(context).isVietnamese;
    final currentParsedBalance = CurrencyUtils.parseCurrency(_balanceController.text);
    final activeColor = Color(_selectedColor);

    String typeDisplay = isVi ? 'Tiền mặt' : 'Cash';
    if (_selectedType == WalletType.bank) {
      typeDisplay = isVi ? 'Tài khoản Ngân hàng' : 'Bank Account';
    } else if (_selectedType == WalletType.eWallet) {
      typeDisplay = isVi ? 'Ví điện tử' : 'E-Wallet';
    } else if (_selectedType == WalletType.credit) {
      typeDisplay = isVi ? 'Thẻ tín dụng' : 'Credit Card';
    } else if (_selectedType == WalletType.savings) {
      typeDisplay = isVi ? 'Sổ tiết kiệm' : 'Savings';
    }

    final presets = [
      {
        'name': isVi ? 'Tiền mặt' : 'Cash',
        'type': WalletType.cash,
        'color': 0xFF438883,
        'icon': Icons.payments_rounded.codePoint,
        'label': isVi ? '💵 Tiền mặt' : '💵 Cash',
      },
      {
        'name': 'Ví MoMo',
        'type': WalletType.eWallet,
        'color': 0xFFD82D8B,
        'icon': Icons.phone_android_rounded.codePoint,
        'label': '👛 MoMo',
      },
      {
        'name': 'Ví ZaloPay',
        'type': WalletType.eWallet,
        'color': 0xFF0068FF,
        'icon': Icons.qr_code_rounded.codePoint,
        'label': '🔵 ZaloPay',
      },
      {
        'name': 'Vietcombank',
        'type': WalletType.bank,
        'color': 0xFF006E33,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 Vietcombank',
      },
      {
        'name': 'MB Bank',
        'type': WalletType.bank,
        'color': 0xFF1429A0,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 MB Bank',
      },
      {
        'name': 'Techcombank',
        'type': WalletType.bank,
        'color': 0xFFE31B23,
        'icon': Icons.account_balance_rounded.codePoint,
        'label': '🏦 Techcombank',
      },
      {
        'name': isVi ? 'Thẻ tín dụng' : 'Credit Card',
        'type': WalletType.credit,
        'color': 0xFF8338EC,
        'icon': Icons.credit_card_rounded.codePoint,
        'label': isVi ? '💳 Tín dụng' : '💳 Credit',
      },
      {
        'name': isVi ? 'Heo đất tiết kiệm' : 'Piggy Bank',
        'type': WalletType.savings,
        'color': 0xFFFFB703,
        'icon': Icons.savings_rounded.codePoint,
        'label': isVi ? '🐷 Tiết kiệm' : '🐷 Savings',
      },
    ];

    final quickAmounts = [
      {'label': isVi ? '0 đ' : '0', 'add': false, 'val': 0.0},
      {'label': '+500k', 'add': true, 'val': 500000.0},
      {'label': isVi ? '+1tr' : '+1M', 'add': true, 'val': 1000000.0},
      {'label': isVi ? '+5tr' : '+5M', 'add': true, 'val': 5000000.0},
      {'label': isVi ? '+10tr' : '+10M', 'add': true, 'val': 10000000.0},
    ];

    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding + 16,
        left: 20,
        right: 20,
        top: 2,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề Sheet & Nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          IconData(_selectedIconCode, fontFamily: 'MaterialIcons'),
                          color: activeColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isEditing ? context.tr('edit_wallet') : context.tr('add_wallet'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: isVi ? 'Đóng' : 'Close',
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ════════════ 1. LIVE WALLET CARD PREVIEW (THẺ XEM TRƯỚC CO GIÃN TỰ NHIÊN - ZERO OVERFLOW) ════════════
            _buildWalletCardPreview(
              activeColor: activeColor,
              typeDisplay: typeDisplay,
              currentParsedBalance: currentParsedBalance,
              isDark: isDark,
              isVi: isVi,
            ),

            const SizedBox(height: 10),

            // ════════════ 2. GỢI Ý VÍ & NGÂN HÀNG PHỔ BIẾN (1 CHẠM TỰ ĐIỀN) ════════════
            if (!_isEditing) ...[
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: activeColor),
                  const SizedBox(width: 6),
                  Text(
                    isVi ? 'Gợi ý ví & ngân hàng phổ biến (1 chạm):' : 'Popular wallet & bank suggestions (1-tap):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: presets.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final p = presets[idx];
                    final isCur = _nameController.text == p['name'];
                    final pColor = Color(p['color'] as int);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        splashColor: pColor.withValues(alpha: 0.12),
                        highlightColor: pColor.withValues(alpha: 0.08),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _nameController.text = p['name'] as String;
                            _selectedType = p['type'] as String;
                            _selectedColor = p['color'] as int;
                            _selectedIconCode = p['icon'] as int;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCur
                                ? pColor.withValues(alpha: isDark ? 0.35 : 0.18)
                                : (isDark ? AppColors.inputBgDark : AppColors.inputBgLight),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: isCur ? pColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                              width: isCur ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p['label'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
                              color: isCur
                                  ? (isDark ? Colors.white : pColor)
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ════════════ 3. SỐ DƯ BAN ĐẦU (HERO BALANCE INPUT - CHUẨN HÓA ERGONOMICS) ════════════
            Text(
              _isEditing ? context.tr('current_balance_label') : context.tr('initial_balance_label'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: activeColor,
                letterSpacing: 0.5,
              ),
              cursorColor: activeColor,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                prefixText: '₫  ',
                prefixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
                suffixIcon: _balanceController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel_rounded,
                          size: 19,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        splashRadius: 18,
                        tooltip: isVi ? 'Xóa số tiền' : 'Clear amount',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _balanceController.clear();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                final parsed = CurrencyUtils.parseCurrency(val);
                setState(() {});
                if (parsed > 0) {
                  final formatted = CurrencyUtils.formatNumberOnly(parsed);
                  _balanceController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),

            // Hàng chip nạp số dư nhanh (Horizontal Chips cuộn mượt mà, Pill-shaped)
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: quickAmounts.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final q = quickAmounts[idx];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      splashColor: activeColor.withValues(alpha: 0.15),
                      highlightColor: activeColor.withValues(alpha: 0.08),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final isAdd = q['add'] as bool;
                        final val = q['val'] as double;
                        double newBal = 0.0;
                        if (isAdd) {
                          newBal = currentParsedBalance + val;
                        } else {
                          newBal = val;
                        }
                        setState(() {
                          _balanceController.text = newBal == 0 ? '0' : CurrencyUtils.formatNumberOnly(newBal);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          q['label'] as String,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ════════════ 4. TÊN VÍ TIỀN ════════════
            Text(
              context.tr('wallet_name_label'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: _nameController,
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: activeColor, size: 19),
                filled: true,
                fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            // ════════════ 5. LOẠI VÍ TIỀN (LƯỚI 2 CỘT CÂN ĐỐI, ELLIPSIS CHỐNG VỠ CHỮ) ════════════
            Text(
              context.tr('wallet_type_label'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            _buildWalletTypeGrid(activeColor: activeColor, isDark: isDark),

            const SizedBox(height: 12),

            // ════════════ 6. BỘ CHỌN MÀU SẮC PHỐI SẴN & TÙY CHỌN ════════════
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('color_label'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final customColor = await _showCustomColorPickerDialog(context, _selectedColor);
                      if (customColor != null) {
                        setState(() => _selectedColor = customColor);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.red, Colors.amber, Colors.green, Colors.blue, Colors.purple],
                            ).createShader(bounds),
                            child: const Icon(Icons.palette_rounded, size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVi ? 'Tùy chọn màu sắc...' : 'Choose color...',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: activeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Nút mở Bảng màu tùy biến với biểu tượng cầu vồng
                  GestureDetector(
                    onTap: () async {
                      final customColor = await _showCustomColorPickerDialog(context, _selectedColor);
                      if (customColor != null) {
                        setState(() => _selectedColor = customColor);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.amber,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        border: Border.all(
                          color: !_paletteColors.contains(_selectedColor) ? Colors.white : Colors.transparent,
                          width: !_paletteColors.contains(_selectedColor) ? 2 : 0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.inputBgDark : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.colorize_rounded,
                            size: 11,
                            color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Nếu màu được chọn là màu tùy biến không có trong bảng _paletteColors thì hiển thị riêng ở đây
                  if (!_paletteColors.contains(_selectedColor))
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final customColor = await _showCustomColorPickerDialog(context, _selectedColor);
                        if (customColor != null) {
                          setState(() => _selectedColor = customColor);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(_selectedColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Color(_selectedColor).withValues(alpha: 0.65),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      ),
                    ),

                  // Danh sách các màu trong _paletteColors
                  ..._paletteColors.map((color) {
                    final isSel = color == _selectedColor;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedColor = color);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: isSel ? 2 : 0,
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: Color(color).withValues(alpha: isDark ? 0.7 : 0.45),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ════════════ 7. BỘ CHỌN ICON BIỂU TƯỢNG VÍ ════════════
            Text(
              context.tr('icon_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _walletIcons.length,
                itemBuilder: (context, i) {
                  final icon = _walletIcons[i];
                  final isSel = icon.codePoint == _selectedIconCode;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIconCode = icon.codePoint);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSel
                            ? activeColor.withValues(alpha: isDark ? 0.28 : 0.15)
                            : (isDark ? AppColors.inputBgDark : AppColors.inputBgLight),
                        border: Border.all(
                          color: isSel ? activeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          width: isSel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: isDark ? 0.35 : 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSel ? activeColor : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                        size: 23,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ════════════ 8. ĐẶT LÀM VÍ MẶC ĐỊNH & GHI CHÚ ════════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr('default_wallet_label'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  isVi ? 'Tự động chọn ví này khi ghi nhận thu chi mới' : 'Automatically select this wallet for new transactions',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                value: _isDefault,
                activeThumbColor: activeColor,
                onChanged: (val) => setState(() => _isDefault = val),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                labelText: context.tr('note_optional_label'),
                labelStyle: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                prefixIcon: Icon(
                  Icons.note_alt_outlined,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                filled: true,
                fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ════════════ 9. NÚT HÀNH ĐỘNG (LƯU / HỦY) ════════════
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Text(
                      context.tr('cancel'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: AnimatedScaleButton(
                    onTap: _isSaving ? null : _saveWallet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor,
                            Color.lerp(activeColor, const Color(0xFF0F172A), 0.2) ?? activeColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: isDark ? 0.45 : 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditing ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? context.tr('save_changes') : context.tr('create_wallet_btn'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ════════════ LIVE WALLET CARD PREVIEW COMPONENT ════════════
  Widget _buildWalletCardPreview({
    required Color activeColor,
    required String typeDisplay,
    required double currentParsedBalance,
    required bool isDark,
    required bool isVi,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            activeColor,
            activeColor.withValues(alpha: 0.85),
            Color.lerp(activeColor, const Color(0xFF0F172A), 0.25) ?? activeColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: isDark ? 0.3 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Họa tiết trang trí vòng tròn mờ sang trọng
            Positioned(
              right: -15,
              top: -15,
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -20,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Nội dung thẻ co giãn gọn gàng, vừa vặn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng trên: Icon ví + Badge mặc định + Badge loại ví
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          IconData(_selectedIconCode, fontFamily: 'MaterialIcons'),
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDefault) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 9, color: Colors.black87),
                                  const SizedBox(width: 2),
                                  Text(
                                    isVi ? 'Mặc định' : 'Default',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              typeDisplay.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Hàng dưới: Tên ví & Số dư thời gian thực
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _nameController.text.trim().isNotEmpty
                                  ? _nameController.text.trim()
                                  : (isVi ? 'Tên chiếc ví của bạn' : 'Your wallet name'),
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: _nameController.text.trim().isNotEmpty ? 1.0 : 0.75,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 4),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.formatCurrency(currentParsedBalance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.contactless_rounded, color: Colors.white60, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════ LƯỚI CHỌN LOẠI VÍ TIỀN (GRID 2 CỘT CHUẨN CÔNG THÁI HỌC) ════════════
  Widget _buildWalletTypeGrid({
    required Color activeColor,
    required bool isDark,
  }) {
    final walletTypes = [
      {'type': WalletType.cash, 'name': context.tr('wallet_cash'), 'icon': Icons.payments_rounded},
      {'type': WalletType.bank, 'name': context.tr('wallet_bank'), 'icon': Icons.account_balance_rounded},
      {'type': WalletType.eWallet, 'name': context.tr('wallet_e_wallet'), 'icon': Icons.account_balance_wallet_rounded},
      {'type': WalletType.credit, 'name': context.tr('wallet_credit'), 'icon': Icons.credit_card_rounded},
      {'type': WalletType.savings, 'name': context.tr('wallet_savings'), 'icon': Icons.savings_rounded},
    ];

    if (!walletTypes.any((t) => t['type'] == _selectedType)) {
      walletTypes.add({
        'type': _selectedType,
        'name': WalletType.getDisplayName(_selectedType, context),
        'icon': WalletType.getDefaultIcon(_selectedType),
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: walletTypes.map((item) {
            final String typeVal = item['type'] as String;
            final String typeName = item['name'] as String;
            final IconData typeIcon = item['icon'] as IconData;
            final bool isSelected = _selectedType == typeVal;

            return SizedBox(
              width: cardWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor: activeColor.withValues(alpha: 0.12),
                  highlightColor: activeColor.withValues(alpha: 0.08),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedType = typeVal;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    constraints: const BoxConstraints(minHeight: 42),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                          : (isDark ? AppColors.inputBgDark : AppColors.inputBgLight),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? activeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? activeColor.withValues(alpha: 0.22)
                                : (isDark ? AppColors.cardDark : Colors.white),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    width: 0.8,
                                  ),
                          ),
                          child: Icon(
                            typeIcon,
                            size: 15,
                            color: isSelected
                                ? activeColor
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            typeName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: activeColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ════════════ LƯU DỮ LIỆU VÍ TIỀN AN TOÀN ════════════
  Future<void> _saveWallet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopToast.show(context, context.tr('enter_wallet_name_error'), isError: true);
      return;
    }
    final balance = CurrencyUtils.parseCurrency(_balanceController.text);
    final uid = AuthService().currentUid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_isEditing) {
        final wallet = widget.wallet!;
        final allTxs = await _txRepo.getAllTransactions();
        final txs = allTxs.where((t) => t.walletId == wallet.id);
        double inc = 0.0;
        double exp = 0.0;
        for (final t in txs) {
          if (t.type == 'income') {
            inc += t.amount;
          } else {
            exp += t.amount;
          }
        }
        final calcInitial = balance - (inc - exp);
        final updated = wallet.copyWith(
          name: name,
          balance: balance,
          initialBalance: calcInitial,
          type: _selectedType,
          colorValue: _selectedColor,
          iconCode: _selectedIconCode,
          isDefault: _isDefault,
          note: _noteController.text.trim(),
        );
        await _walletRepo.updateWallet(updated);
      } else {
        final newWallet = WalletModel(
          id: '',
          uid: uid,
          name: name,
          balance: balance,
          initialBalance: balance,
          type: _selectedType,
          colorValue: _selectedColor,
          iconCode: _selectedIconCode,
          isDefault: _isDefault,
          createdAt: DateTime.now(),
          note: _noteController.text.trim(),
        );
        await _walletRepo.addWallet(newWallet);
      }

      widget.onWalletSaved?.call();

      if (mounted) {
        Navigator.pop(context);
        TopToast.show(
          context,
          _isEditing ? context.tr('update_wallet_success') : context.tr('create_wallet_success'),
        );
      }
    } catch (e) {
      if (mounted) {
        TopToast.show(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ════════════ BẢNG MÀU TÙY BIẾN 36 SẮC ĐỘ ════════════
  Future<int?> _showCustomColorPickerDialog(BuildContext context, int initialColor) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int pickedColor = initialColor;
    Color currentColor = Color(initialColor);
    HSVColor hsv = HSVColor.fromColor(currentColor);
    double currentHue = hsv.hue;
    double currentSaturation = hsv.saturation.clamp(0.15, 1.0);
    double currentValue = hsv.value.clamp(0.25, 1.0);

    final hexController = TextEditingController(
      text: initialColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );

    final isVi = LanguageScope.of(context).isVietnamese;
    final categorizedColors = <String, List<int>>{
      isVi ? 'Đỏ & Hồng' : 'Red & Pink': [
        0xFFE53935, 0xFFD82D8B, 0xFFE91E63, 0xFFF43F5E, 0xFFC2185B, 0xFF880E4F,
      ],
      isVi ? 'Cam & Vàng' : 'Orange & Yellow': [
        0xFFFF9800, 0xFFF77F00, 0xFFE07A5F, 0xFFFFB703, 0xFFF59E0B, 0xFFFF6F00,
      ],
      isVi ? 'Xanh lá & Bạc hà' : 'Green & Mint': [
        0xFF438883, 0xFF10B981, 0xFF006E33, 0xFF06D6A0, 0xFF2A9D8F, 0xFF558B2F,
      ],
      isVi ? 'Xanh dương & Biển' : 'Blue & Ocean': [
        0xFF0077B6, 0xFF0068FF, 0xFF3A86FF, 0xFF1429A0, 0xFF0284C7, 0xFF0369A1,
      ],
      isVi ? 'Tím & Chàm' : 'Purple & Indigo': [
        0xFF8338EC, 0xFF7209B7, 0xFF6366F1, 0xFF5B21B6, 0xFF9333EA, 0xFF4C1D95,
      ],
      isVi ? 'Trung tính & Sang trọng' : 'Neutral & Luxury': [
        0xFF2B2D42, 0xFF1E293B, 0xFF334155, 0xFF6F4E37, 0xFF475569, 0xFF0F172A,
      ],
    };

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            void updateFromHsv() {
              final newColor = HSVColor.fromAHSV(1.0, currentHue, currentSaturation, currentValue).toColor();
              pickedColor = newColor.toARGB32();
              hexController.text = pickedColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'Bảng màu tùy biến' : 'Custom Color Palette',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(Icons.close_rounded, size: 20, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Xem trước màu đã chọn & Mã HEX
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(pickedColor),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Color(pickedColor).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            style: TextStyle(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            decoration: InputDecoration(
                              prefixText: '# ',
                              prefixStyle: TextStyle(
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                fontWeight: FontWeight.bold,
                              ),
                              labelText: isVi ? 'Mã màu HEX' : 'HEX Code',
                              labelStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              filled: true,
                              fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: (val) {
                              final clean = val.replaceAll('#', '').trim();
                              if (clean.length == 6) {
                                final parsed = int.tryParse('FF$clean', radix: 16);
                                if (parsed != null) {
                                  setPickerState(() {
                                    pickedColor = parsed;
                                    final hsvVal = HSVColor.fromColor(Color(parsed));
                                    currentHue = hsvVal.hue;
                                    currentSaturation = hsvVal.saturation.clamp(0.15, 1.0);
                                    currentValue = hsvVal.value.clamp(0.25, 1.0);
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thanh trượt Tone màu Hue
                    Text(
                      isVi ? 'Tông màu sắc (Hue):' : 'Hue Slider:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 18,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
                          thumbColor: Colors.white,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: currentHue,
                          min: 0,
                          max: 360,
                          onChanged: (val) {
                            setPickerState(() {
                              currentHue = val;
                              updateFromHsv();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Danh sách màu tuyển chọn theo nhóm
                    ...categorizedColors.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: entry.value.map((colVal) {
                                final isSel = pickedColor == colVal;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setPickerState(() {
                                      pickedColor = colVal;
                                      final h = HSVColor.fromColor(Color(colVal));
                                      currentHue = h.hue;
                                      currentSaturation = h.saturation;
                                      currentValue = h.value;
                                      hexController.text = colVal.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                                    });
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Color(colVal),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel ? Colors.white : Colors.transparent,
                                        width: isSel ? 2.5 : 0,
                                      ),
                                      boxShadow: isSel
                                          ? [
                                              BoxShadow(
                                                color: Color(colVal).withValues(alpha: 0.8),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Nút xác nhận chọn màu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(dialogCtx, pickedColor);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(pickedColor),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        child: Text(
                          isVi ? 'Xác nhận áp dụng màu này' : 'Apply Selected Color',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
