import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/currency_format_utils.dart';
import '../../../widgets/animated_scale_button.dart';

/// Dải gợi ý số tiền thông minh theo thời gian thực (Smart Amount Auto-Suggestions)
/// - Khi người dùng gõ số cơ sở (vd: 7), tự động gợi ý: 7.000đ, 70.000đ, 700.000đ, 7.000.000đ
/// - Khi chưa gõ số nào, hiển thị các mốc chi tiêu phổ biến (20k, 50k, 100k, 200k, 500k)
/// - Chạm 1 lần điền số ngay tức thì, giảm 80% thao tác bấm
class AmountSuggestionBar extends StatelessWidget {
  final String rawInput;
  final ValueChanged<double> onSelectAmount;
  final Color activeColor;
  final bool isDark;

  const AmountSuggestionBar({
    super.key,
    required this.rawInput,
    required this.onSelectAmount,
    required this.activeColor,
    required this.isDark,
  });

  List<double> _calculateSuggestions() {
    final cleanDigits = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      // Mặc định khi chưa nhập: Các mệnh giá thông dụng hàng ngày
      return [20000, 50000, 100000, 200000, 500000, 1000000];
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
                isDefault ? 'Gợi ý nhanh:' : 'Gợi ý số tiền phù hợp:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
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

              return AnimatedScaleButton(
                scaleDown: 0.92,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelectAmount(amount);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF152625)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
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
