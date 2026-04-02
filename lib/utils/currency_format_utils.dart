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
    
    // Format with thousands separator
    final formatter = NumberFormat.decimalPattern('vi_VN');
    String newText = '${formatter.format(value)}đ';

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length - 1), // Place cursor before 'đ'
    );
  }
}

class CurrencyUtils {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.decimalPattern('vi_VN');
    // Định dạng 50.000đ chuẩn theo yêu cầu
    return '${formatter.format(amount)}đ';
  }

  static double parseCurrency(String text) {
    String cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
