import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Remove all non-numeric characters
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanText.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    double value = double.parse(cleanText);
    String newText = CurrencyUtils.formatCurrency(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1), // Place cursor before 'đ'
    );
  }
}
class CurrencyUtils {
  static String formatCurrency(double amount) {
    // Sử dụng NumberFormat.currency để đảm bảo định dạng chuẩn vi_VN
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0, // Tiền Việt thường không dùng số thập phân
    );
    return formatter.format(amount);
  }

  static String formatAmountWithSign(double amount, bool isIncome) {
    String formatted = formatCurrency(amount);
    return isIncome ? "+$formatted" : "-$formatted";
  }

  static double parseCurrency(String text) {
    String cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
