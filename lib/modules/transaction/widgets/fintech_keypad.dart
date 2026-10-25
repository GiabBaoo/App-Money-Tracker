import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/animated_scale_button.dart';

/// Bàn phím số công thái học phong cách Fintech
/// Tối ưu tuyệt đối cho việc nhập liệu tài chính 60-120fps:
/// - Phím to, bấm êm, phản hồi rung nhẹ (Haptic Feedback)
/// - Có sẵn phím '.000' để điền 3 số không siêu tốc
/// - Không phụ thuộc bàn phím ảo của hệ điều hành, loại bỏ 100% tình trạng co giật khung hình
class FintechKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final Color activeColor;
  final bool isDark;

  const FintechKeypad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    required this.onClear,
    required this.activeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final keyBg = isDark
        ? context.colors.surfaceContainerHighest
        : context.inputBgColor;
    final keyBorder = context.borderColor;
    final textNumberColor = context.textPrimaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(
            context,
            ['1', '2', '3'],
            keyBg,
            keyBorder,
            textNumberColor,
          ),
          const SizedBox(height: 8),
          _buildRow(
            context,
            ['4', '5', '6'],
            keyBg,
            keyBorder,
            textNumberColor,
          ),
          const SizedBox(height: 8),
          _buildRow(
            context,
            ['7', '8', '9'],
            keyBg,
            keyBorder,
            textNumberColor,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Phím .000 (Nhân nghìn nhanh)
              Expanded(
                child: _buildSpecialKey(
                  context: context,
                  label: '.000',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onKeyPress('000');
                  },
                  bgColor: activeColor.withValues(alpha: isDark ? 0.16 : 0.1),
                  borderColor: activeColor.withValues(alpha: 0.3),
                  textColor: activeColor,
                  isBold: true,
                ),
              ),
              const SizedBox(width: 8),
              // Phím 0
              Expanded(
                child: _buildNumberKey(
                  context,
                  '0',
                  keyBg,
                  keyBorder,
                  textNumberColor,
                ),
              ),
              const SizedBox(width: 8),
              // Phím Xóa từng số (Backspace) & Giữ để xóa hết (Clear)
              Expanded(
                child: _buildActionKey(
                  icon: Icons.backspace_outlined,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    onClear();
                  },
                  bgColor: keyBg,
                  borderColor: keyBorder,
                  iconColor: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<String> keys,
    Color keyBg,
    Color keyBorder,
    Color textNumberColor,
  ) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildNumberKey(
              context,
              keys[i],
              keyBg,
              keyBorder,
              textNumberColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNumberKey(
    BuildContext context,
    String digit,
    Color keyBg,
    Color keyBorder,
    Color textColor,
  ) {
    return AnimatedScaleButton(
      scaleDown: 0.92,
      onTap: () {
        HapticFeedback.selectionClick();
        onKeyPress(digit);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: keyBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: keyBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: (context.textTheme.titleLarge ?? const TextStyle()).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    bool isBold = false,
  }) {
    return AnimatedScaleButton(
      scaleDown: 0.92,
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Center(
          child: Text(
            label,
            style: (context.textTheme.titleMedium ?? const TextStyle())
                .copyWith(
                  fontSize: 18,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return AnimatedScaleButton(
      scaleDown: 0.92,
      onTap: onTap,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 21)),
        ),
      ),
    );
  }
}
