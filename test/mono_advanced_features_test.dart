import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/services/smart_category_service.dart';
import 'package:money_tracker_app/services/financial_advisor_service.dart';

void main() {
  group('Mono AI Assistant Advanced Features & Multi-turn Tests', () {
    late GeminiAiService aiService;
    late SmartCategoryService smartCategoryService;
    late FinancialAdvisorService advisorService;

    setUp(() {
      aiService = GeminiAiService();
      smartCategoryService = SmartCategoryService();
      advisorService = FinancialAdvisorService();
    });

    test('SmartCategoryService: Fast brand recognition for popular VN brands', () {
      final phuclong = smartCategoryService.predictCategoryFast('Trà sữa Phúc Long');
      expect(phuclong.category, equals('Ăn uống'));

      final grab = smartCategoryService.predictCategoryFast('Đi xe grab car');
      expect(grab.category, equals('Di chuyển'));

      final shopee = smartCategoryService.predictCategoryFast('Mua đồ shopee');
      expect(shopee.category, equals('Mua sắm'));

      final netflix = smartCategoryService.predictCategoryFast('Đăng ký netflix');
      expect(netflix.category, equals('Giải trí'));

      final pharmacy = smartCategoryService.predictCategoryFast('Mua thuốc pharmacity');
      expect(pharmacy.category, equals('Sức khỏe'));
    });

    test('Multi-turn Context: Merging pending transaction with supplemental amount and wallet', () async {
      // Step 1: User enters transaction without amount
      final step1 = await aiService.parseNaturalLanguage('Ăn bún bò Huế');
      expect(step1.needsAmount, isTrue);
      expect(step1.transactions.isNotEmpty, isTrue);
      final pending = step1.transactions.first;
      expect(pending.category, equals('Ăn uống'));

      // Step 2: User supplements amount and wallet: "40k ví MoMo"
      final step2 = await aiService.parseNaturalLanguage(
        '40k ví MoMo',
        pendingTransaction: pending,
      );
      expect(step2.transactions.isNotEmpty, isTrue);
      final finalTx = step2.transactions.first;
      expect(finalTx.amount, equals(40000.0));
      expect(finalTx.walletName, equals('MoMo'));
      expect(finalTx.category, equals('Ăn uống'));
    });

    test('Intent Routing: "Xu hướng chi tiêu tuần này" routes to spendingTrends', () async {
      final res = await aiService.parseNaturalLanguage('Xu hướng chi tiêu tuần này của tôi thế nào?');
      expect(res.actionType, equals(AiActionType.spendingTrends));
      expect(res.spendingTrendResult, isNotNull);
    });

    test('Intent Routing: "Điểm sức khỏe tài chính" routes to financialHealthScore', () async {
      final res = await aiService.parseNaturalLanguage('Chấm điểm sức khỏe tài chính của tôi');
      expect(res.actionType, equals(AiActionType.financialHealthScore));
      expect(res.financialHealthScoreResult, isNotNull);
      expect(res.financialHealthScoreResult!.overallScore, inInclusiveRange(0, 100));
    });

    test('Intent Routing: "Khoản chi định kỳ" routes to recurringTransactions', () async {
      final res = await aiService.parseNaturalLanguage('Xem các khoản chi phí cố định hàng tháng');
      expect(res.actionType, equals(AiActionType.recurringTransactions));
      expect(res.recurringDetectionResult, isNotNull);
    });

    test('FinancialAdvisorService: Direct calculation of health score, trends, and recurring', () async {
      final score = await advisorService.calculateFinancialHealthScore();
      expect(score.overallScore, inInclusiveRange(0, 100));
      expect(score.metrics.length, equals(5));

      final trend = await advisorService.analyzeSpendingTrends();
      expect(trend.periodName, isNotEmpty);
      expect(trend.currentCategoryBreakdown, isNotNull);

      final rec = await advisorService.detectRecurringTransactions();
      expect(rec.totalMonthlyFixedCost, greaterThanOrEqualTo(0.0));
      expect(rec.summary, isNotEmpty);
    });
  });
}
