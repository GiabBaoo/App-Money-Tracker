import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/services/group_bill_split_service.dart';
import 'package:money_tracker_app/services/bank_sms_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mono Latency & Responsiveness Benchmarks', () {
    test('1. Local-first Fast Intent (< 300ms benchmark)', () async {
      final stopwatch = Stopwatch()..start();

      // Test local algorithm execution (Group Bill Split & SMS Parser)
      final splitRes = GroupBillSplitService().parseAndSplit('Chia 600k cho 4 người');
      final elapsed = stopwatch.elapsedMilliseconds;

      expect(splitRes.perPersonAmount, 150000);
      expect(elapsed, lessThan(300), reason: 'Local calculations must respond in < 300ms like a real human');
    });

    test('2. Bank SMS Parser latency benchmark (< 50ms)', () {
      final sw = Stopwatch()..start();
      const sms = 'VCB 12/05/26 14:30 TK 0123456789 -500,000 VND Ref 987654. ND: Phuc Long Coffee. So du: 15,200,000 VND';
      final res = BankSmsParserService().parse(sms);
      final elapsed = sw.elapsedMilliseconds;

      expect(res, isNotNull);
      expect(res!.amount, 500000);
      expect(elapsed, lessThan(50), reason: 'Regex parsing must complete almost instantly');
    });

    test('3. Natural language instant transaction parsing (< 300ms)', () async {
      final aiService = GeminiAiService();
      final sw = Stopwatch()..start();
      final result = await aiService.parseNaturalLanguage('Ăn bún bò 35k ví MoMo');
      final elapsed = sw.elapsedMilliseconds;

      expect(result.isSuccess, true);
      expect(result.transactions.isNotEmpty, true);
      expect(result.transactions.first.amount, 35000);
      expect(elapsed, lessThan(300), reason: 'Fast intent fallback should respond in < 300ms');
    });
  });
}
