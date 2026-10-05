import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/budget_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Budget & Financial Logic Unit Tests', () {
    test('1. BudgetModel: Tính toán remainingAmount chính xác', () {
      final budget = BudgetModel(
        id: 'b1',
        uid: 'user_1',
        category: 'Ăn uống',
        limitAmount: 5000000,
        month: 10,
        year: 2026,
        currentSpent: 2000000,
      );

      expect(budget.remainingAmount, equals(3000000.0));
      expect(budget.isOverBudget, isFalse);
      expect(budget.isNearLimit, isFalse);
      expect(budget.progressPercentage, closeTo(0.4, 0.001));
    });

    test('2. BudgetModel: Ngưỡng cảnh báo 80% (isNearLimit)', () {
      // 79% chưa đạt ngưỡng cảnh báo
      final b79 = BudgetModel(
        id: 'b2',
        uid: 'user_1',
        category: 'Ăn uống',
        limitAmount: 1000000,
        month: 10,
        year: 2026,
        currentSpent: 790000,
      );
      expect(b79.isNearLimit, isFalse);
      expect(b79.isOverBudget, isFalse);

      // Đúng 80% kích hoạt cảnh báo
      final b80 = BudgetModel(
        id: 'b3',
        uid: 'user_1',
        category: 'Ăn uống',
        limitAmount: 1000000,
        month: 10,
        year: 2026,
        currentSpent: 800000,
      );
      expect(b80.isNearLimit, isTrue);
      expect(b80.isOverBudget, isFalse);
      expect(b80.remainingAmount, equals(200000.0));

      // 95% vẫn nằm trong vùng cảnh báo gần chạm hạn mức
      final b95 = BudgetModel(
        id: 'b4',
        uid: 'user_1',
        category: 'Ăn uống',
        limitAmount: 1000000,
        month: 10,
        year: 2026,
        currentSpent: 950000,
      );
      expect(b95.isNearLimit, isTrue);
      expect(b95.isOverBudget, isFalse);
      expect(b95.remainingAmount, equals(50000.0));
    });

    test('3. BudgetModel: Vượt hạn mức 100% (isOverBudget)', () {
      final bOver = BudgetModel(
        id: 'b5',
        uid: 'user_1',
        category: 'Mua sắm',
        limitAmount: 2000000,
        month: 10,
        year: 2026,
        currentSpent: 2500000,
      );

      expect(bOver.isOverBudget, isTrue);
      expect(bOver.isNearLimit, isFalse); // Khi đã vượt ngân sách thì không còn là "sắp chạm" nữa
      expect(bOver.remainingAmount, equals(-500000.0));
      expect(bOver.progressPercentage, closeTo(1.25, 0.001));
    });

    test('4. Logic tổng hợp chi tiêu theo danh mục ngân sách', () {
      final txs = [
        // Ăn uống trong tháng 10/2026 (chi tiêu)
        TransactionModel(
          id: 't1',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 100,
          amount: 500000,
          date: DateTime(2026, 10, 2),
        ),
        TransactionModel(
          id: 't2',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 100,
          amount: 300000,
          date: DateTime(2026, 10, 4),
        ),
        // Mua sắm trong tháng 10/2026
        TransactionModel(
          id: 't3',
          uid: 'u1',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 101,
          amount: 1000000,
          date: DateTime(2026, 10, 5),
        ),
        // Thu nhập trong tháng 10/2026 (KHÔNG tính vào ngân sách chi tiêu)
        TransactionModel(
          id: 't4',
          uid: 'u1',
          type: 'income',
          category: 'Tiền lương',
          categoryIconCode: 102,
          amount: 20000000,
          date: DateTime(2026, 10, 1),
        ),
        // Chuyển tiền giữa các ví (KHÔNG tính vào ngân sách chi tiêu)
        TransactionModel(
          id: 't5',
          uid: 'u1',
          type: 'expense',
          category: 'Chuyển tiền',
          categoryIconCode: 103,
          amount: 2000000,
          date: DateTime(2026, 10, 3),
          groupId: 'transfer_999',
        ),
        // Giao dịch ở tháng khác (tháng 9/2026 - KHÔNG tính vào ngân sách tháng 10)
        TransactionModel(
          id: 't6',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 100,
          amount: 800000,
          date: DateTime(2026, 9, 28),
        ),
      ];

      // Lọc chi tiêu thuần trong tháng 10/2026
      final monthExpenseTxs = txs.where((tx) =>
          tx.type == 'expense' &&
          !tx.isTransfer &&
          tx.date.month == 10 &&
          tx.date.year == 2026).toList();

      expect(monthExpenseTxs.length, equals(3));

      // Tính tổng chi theo danh mục 'Ăn uống'
      final anUongSpent = monthExpenseTxs
          .where((tx) => tx.category.toLowerCase().trim() == 'ăn uống')
          .fold(0.0, (sum, tx) => sum + tx.amount);
      expect(anUongSpent, equals(800000.0));

      // Tính tổng chi cho ngân sách 'Tất cả'
      final totalSpent = monthExpenseTxs.fold(0.0, (sum, tx) => sum + tx.amount);
      expect(totalSpent, equals(1800000.0)); // 500k + 300k + 1000k
    });

    test('5. BudgetModel: Ngân sách có limit = 0 xử lý an toàn không bị chia cho 0', () {
      final zeroBudget = BudgetModel(
        id: 'b_zero',
        uid: 'user_1',
        category: 'Khác',
        limitAmount: 0,
        month: 10,
        year: 2026,
        currentSpent: 50000,
      );

      expect(zeroBudget.progressPercentage, equals(0.0));
      expect(zeroBudget.isOverBudget, isTrue);
      expect(zeroBudget.remainingAmount, equals(-50000.0));
    });
  });
}
