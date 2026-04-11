import 'package:flutter/services.dart';

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
    // Format tiền kiểu Việt: 1000000 -> 1.000.000đ
    String amountStr = amount.toStringAsFixed(0);
    
    // Thêm dấu chấm vào mỗi 3 chữ số từ phải sang
    final buffer = StringBuffer();
    int count = 0;
    
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(amountStr[i]);
      count++;
    }
    
    // Đảo lại chuỗi và thêm đ
    String reversed = buffer.toString().split('').reversed.join('');
    return '${reversed}đ';
  }

  static String formatAmountWithSign(double amount, bool isIncome) {
    String formatted = formatCurrency(amount);
    // Remove 'đ' symbol, add sign, then add 'đ' back
    String withoutSymbol = formatted.replaceAll('đ', '').trim();
    return isIncome ? "+${withoutSymbol}đ" : "-${withoutSymbol}đ";
  }

  static double parseCurrency(String text) {
    String cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanText) ?? 0;
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
