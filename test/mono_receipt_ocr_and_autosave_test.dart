import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mono Receipt OCR & Auto-save Logic Tests', () {
    test('Receipt JSON parse extracts string amount and Vietnamese date correctly', () {
      final service = GeminiAiService();
      
      // Giả lập raw JSON mà Gemini Vision trả về từ ảnh hóa đơn tại Việt Nam
      const rawAiResponse = '''
```json
{
  "actionType": "recordTransaction",
  "reply": "Đã quét thành công hóa đơn từ WinMart: 125.000đ",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense",
      "category": "Ăn uống",
      "amount": "125.000",
      "description": "WinMart - Mua sữa và bánh mì",
      "date": "28/09/2026",
      "walletName": "Ví chính"
    }
  ]
}
```
''';

      final result = service.parseJsonFromAiTextForTesting(rawAiResponse);
      expect(result.isSuccess, isTrue);
      expect(result.transactions.length, equals(1));
      
      final tx = result.transactions.first;
      expect(tx.amount, equals(125000.0));
      expect(tx.description, contains('WinMart'));
      expect(tx.category, equals('Ăn uống'));
      expect(tx.date.day, equals(28));
      expect(tx.date.month, equals(9));
      expect(tx.date.year, equals(2026));
    });

    test('Receipt JSON parse with currency suffix (e.g. 45,000đ) resolves properly', () {
      final service = GeminiAiService();

      const rawAiResponse = '''
{
  "actionType": "recordTransaction",
  "reply": "Đã ghi nhận Highlands Coffee 45.000đ",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense",
      "category": "Ăn uống",
      "amount": "45,000đ",
      "description": "Highlands Coffee",
      "date": "2026-09-28",
      "walletName": ""
    }
  ]
}
''';

      final result = service.parseJsonFromAiTextForTesting(rawAiResponse);
      expect(result.isSuccess, isTrue);
      expect(result.transactions.length, equals(1));
      expect(result.transactions.first.amount, equals(45000.0));
      expect(result.needsAmount, isFalse);
    });

    test('Receipt JSON with slash dates and dashed dates parses accurately', () {
      final service = GeminiAiService();

      const rawResponseDash = '''
{
  "actionType": "recordTransaction",
  "reply": "Hóa đơn Circle K",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense",
      "category": "Ăn uống",
      "amount": 25000,
      "description": "Circle K",
      "date": "15-10-2026"
    }
  ]
}
''';

      final result = service.parseJsonFromAiTextForTesting(rawResponseDash);
      expect(result.isSuccess, isTrue);
      final tx = result.transactions.first;
      expect(tx.date.day, equals(15));
      expect(tx.date.month, equals(10));
      expect(tx.date.year, equals(2026));
    });
  });
}
