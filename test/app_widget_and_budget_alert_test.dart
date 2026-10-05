import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/budget_model.dart';
import 'package:money_tracker_app/services/app_widget_service.dart';
import 'package:money_tracker_app/utils/currency_format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppWidgetService & Budget Alert Threshold Tests', () {
    test('1. AppWidgetService: Định dạng tiền tệ cho Widget chính xác', () {
      expect(CurrencyUtils.formatCurrency(0), equals('0đ'));
      expect(CurrencyUtils.formatCurrency(1500000), equals('1.500.000đ'));
      expect(CurrencyUtils.formatCurrency(24500000), equals('24.500.000đ'));
    });

    test('2. AppWidgetService: Khởi tạo singleton an toàn và không ném exception', () async {
      final service = AppWidgetService.instance;
      expect(service, isNotNull);
      // Trên test runner không ném exception
      await service.updateWidgetBalance(500000);
    });

    test('3. Logic chống spam thông báo ngân sách (Anti-spam key format)', () {
      final budget = BudgetModel(
        id: 'budget_food_123',
        uid: 'user_test',
        category: 'Ăn uống',
        limitAmount: 3000000,
        month: 10,
        year: 2026,
        currentSpent: 2400000, // Đúng 80%
      );

      final key80 = 'budget_warned_80_${budget.id}_${budget.year}_${budget.month}';
      final key100 = 'budget_warned_100_${budget.id}_${budget.year}_${budget.month}';

      expect(key80, equals('budget_warned_80_budget_food_123_2026_10'));
      expect(key100, equals('budget_warned_100_budget_food_123_2026_10'));
      expect(budget.isNearLimit, isTrue);
      expect(budget.isOverBudget, isFalse);

      // Khi vượt quá 100%
      final overBudget = budget.copyWith(currentSpent: 3500000);
      expect(overBudget.isOverBudget, isTrue);
      expect(overBudget.isNearLimit, isFalse);
    });
  });
}
