import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../utils/currency_format_utils.dart';
import '../../../widgets/animated_scale_button.dart';
import '../../../services/language_service.dart';

/// Dải gợi ý số tiền thông minh theo thời gian thực (Smart Amount Auto-Suggestions)
/// - Khi người dùng gõ số cơ sở (vd: 7), tự động gợi ý: 7.000đ, 70.000đ, 700.000đ, 7.000.000đ
/// - Khi chưa gõ số nào, hiển thị các mức quen thuộc lặp lại + mốc chi tiêu phổ biến (20k, 50k, 100k...)
/// - Chạm 1 lần điền số ngay tức thì, giảm 80% thao tác bấm
class AmountSuggestionBar extends StatelessWidget {
  final String rawInput;
  final ValueChanged<double> onSelectAmount;
  final Color activeColor;
  final bool isDark;
  final List<double>? frequentAmounts;

  const AmountSuggestionBar({
    super.key,
    required this.rawInput,
    required this.onSelectAmount,
    required this.activeColor,
    required this.isDark,
    this.frequentAmounts,
  });

  List<double> _calculateSuggestions() {
    final cleanDigits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      final baseDefaults = [
        20000.0,
        50000.0,
        100000.0,
        200000.0,
        500000.0,
        1000000.0,
      ];
      if (frequentAmounts != null && frequentAmounts!.isNotEmpty) {
        final merged = <double>{...frequentAmounts!, ...baseDefaults};
        return merged.toList();
      }
      return baseDefaults;
    }

    final baseNumber = double.tryParse(cleanDigits) ?? 0;
    if (baseNumber <= 0) {
      return [20000, 50000, 100000, 200000, 500000, 1000000];
    }

    final suggestions = <double>{};

    // Nếu số nhỏ (< 1.000), gợi ý nhân cấp số ngàn / chục ngàn / trăm ngàn / triệu
    if (baseNumber < 1000) {
      suggestions.add(baseNumber * 1000); // 7 -> 7.000đ
      suggestions.add(baseNumber * 10000); // 7 -> 70.000đ
      suggestions.add(baseNumber * 100000); // 7 -> 700.000đ
      suggestions.add(baseNumber * 1000000); // 7 -> 7.000.000đ
    } else if (baseNumber < 100000) {
      // Ví dụ: người dùng gõ 1.500 hoặc 5000
      suggestions.add(baseNumber * 10);
      suggestions.add(baseNumber * 100);
      suggestions.add(baseNumber * 1000);
    } else if (baseNumber < 10000000) {
      // Đã có số tiền lớn, gợi ý làm tròn hoặc cộng thêm
      suggestions.add(baseNumber);
      suggestions.add(baseNumber * 10);
    } else {
      suggestions.add(baseNumber);
    }

    return suggestions.toList();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _calculateSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final isDefault = rawInput.replaceAll(RegExp(r'[^0-9]'), '').isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: activeColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                isDefault
                    ? context.tr('quick_suggestions_label')
                    : context.tr('matching_suggestions_label'),
                style: (context.textTheme.labelSmall ?? const TextStyle())
                    .copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final amount = suggestions[index];
              final label = CurrencyUtils.formatCurrency(amount);
              final isFrequent =
                  isDefault && (frequentAmounts?.contains(amount) ?? false);

              return AnimatedScaleButton(
                scaleDown: 0.92,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelectAmount(amount);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isFrequent
                        ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                        : (isDark
                              ? context.colors.surfaceContainerHighest
                              : context.inputBgColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFrequent
                          ? activeColor.withValues(alpha: isDark ? 0.6 : 0.45)
                          : context.colors.outline.withValues(
                              alpha: isDark ? 0.35 : 0.25,
                            ),
                      width: isFrequent ? 1.3 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFrequent) ...[
                        Icon(
                          Icons.history_rounded,
                          size: 13,
                          color: activeColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        label,
                        style:
                            (context.textTheme.labelMedium ?? const TextStyle())
                                .copyWith(
                                  fontSize: 12.5,
                                  fontWeight: isFrequent
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: isFrequent
                                      ? (isDark
                                            ? context.colors.onSurface
                                            : activeColor)
                                      : context.textPrimaryColor,
                                  letterSpacing: -0.2,
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
}
