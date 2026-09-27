import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';

void main() {
  group('Mono AI Assistant Bug Fixes Verification', () {
    late GeminiAiService aiService;

    setUp(() {
      aiService = GeminiAiService();
    });

    test('BUG-01: "đi du lịch Campuchia hết 5 triệu tiền vé" does NOT trigger bill split', () async {
      final res = await aiService.parseNaturalLanguage('đi du lịch Campuchia hết 5 triệu tiền vé');
      expect(res.actionType, isNot(equals(AiActionType.splitBill)));
    });

    test('BUG-01 (positive): "chia 600k cho 4 người" correctly triggers bill split', () async {
      final res = await aiService.parseNaturalLanguage('chia 600k cho 4 người: An, Bình, Cường, Dũng');
      expect(res.actionType, equals(AiActionType.splitBill));
      expect(res.splitBillResult, isNotNull);
      expect(res.splitBillResult!.memberCount, equals(4));
    });

    test('BUG-04: "cơm + canh 45k" is expense, not income', () async {
      final res = await aiService.parseNaturalLanguage('cơm + canh 45k');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.type, equals('expense'));
    });

    test('BUG-04 (positive): "+50k vào ví MoMo" is income', () async {
      final res = await aiService.parseNaturalLanguage('+50k vào ví MoMo');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.type, equals('income'));
      expect(res.transactions.first.walletName, equals('MoMo'));
    });

    test('BUG-05: parseVietnameseWordNumber handles "hai mươi tư nghìn" without false "đầu tư"', () {
      final twentyFourK = GeminiAiService.parseVietnameseWordNumber('hai mươi tư nghìn');
      expect(twentyFourK, equals(24000.0));

      final dauTu = GeminiAiService.parseVietnameseWordNumber('đầu tư cổ phiếu');
      expect(dauTu, equals(0.0));
    });

    test('BUG-06: "uống cafe Cộng 45k" is expense, not income', () async {
      final res = await aiService.parseNaturalLanguage('uống cafe Cộng 45k');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.type, equals('expense'));
    });

    test('BUG-07: "bỏ 50k vào ví" is not treated as income by default', () async {
      final res = await aiService.parseNaturalLanguage('bỏ 50k vào ví');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.type, equals('expense'));
    });

    test('BUG-09: "đi xe be 25k" is Di chuyển, "cơm bento 50k" is not Di chuyển', () async {
      final beRes = await aiService.parseNaturalLanguage('đi xe be 25k');
      expect(beRes.transactions.isNotEmpty, isTrue);
      expect(beRes.transactions.first.category, equals('Di chuyển'));

      final bentoRes = await aiService.parseNaturalLanguage('cơm bento 50k');
      expect(bentoRes.transactions.isNotEmpty, isTrue);
      expect(bentoRes.transactions.first.category, isNot(equals('Di chuyển')));
    });

    test('BUG-14: "Mono hỗ trợ tôi quản lý chi tiêu" does NOT open support ticket screen', () async {
      final res = await aiService.parseNaturalLanguage('Mono hỗ trợ tôi quản lý chi tiêu');
      expect(res.actionType, isNot(equals(AiActionType.navigateScreen)));
    });

    test('BUG-14 (positive): "Trung tâm hỗ trợ" opens support screen', () async {
      final res = await aiService.parseNaturalLanguage('Mở trung tâm hỗ trợ');
      expect(res.actionType, equals(AiActionType.navigateScreen));
      expect(res.navigationTarget, equals('support'));
    });

    test('BUG-15: Addressing "Mono ơi..." does NOT force wallet to MoMo', () async {
      final res = await aiService.parseNaturalLanguage('Mono ơi ăn trưa 35k tiền mặt');
      expect(res.transactions.isNotEmpty, isTrue);
      expect(res.transactions.first.walletName, equals('Tiền mặt'));
    });
  });
}
