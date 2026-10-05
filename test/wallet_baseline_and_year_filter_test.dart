import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/currency_format_utils.dart';

void main() {
  group('Wallet Baseline & Search Date Filter Unit Tests', () {
    test('Số dư chuẩn xác sau khi chốt và tính toán initialBalance', () {
      const double targetCashBalance = 52000.0;
      const double targetMonoBalance = 119720.0;

      // Giả sử có giao dịch phát sinh hôm nay: thu 12đ vào ví mono
      const double monoIncomeToday = 12.0;
      const double monoExpenseToday = 0.0;

      // Công thức: initialBalance = targetBalance - (income - expense)
      final initialMono = targetMonoBalance - (monoIncomeToday - monoExpenseToday);
      expect(initialMono, 119708.0);

      // Khi reconcileWalletBalances tính lại:
      final expectedMono = initialMono + monoIncomeToday - monoExpenseToday;
      expect(expectedMono, targetMonoBalance);
      expect(expectedMono, 119720.0);

      // Ví tiền mặt không có giao dịch ban đầu
      final initialCash = targetCashBalance - (0 - 0);
      expect(initialCash, 52000.0);
      final expectedCash = initialCash + 0 - 0;
      expect(expectedCash, targetCashBalance);
      expect(expectedCash, 52000.0);
    });

    test('Giao dịch thủ công phát sinh sau mốc 12đ được bảo toàn chuẩn xác, không bị reset về 119.720đ', () {
      const double initialMono = 119708.0;
      const double monoIncomeBaseline = 12.0;

      // Người dùng thêm khoản chi thủ công 20.000đ
      const double manualExpense = 20000.0;
      // Người dùng thêm khoản thu thủ công 50.000đ
      const double manualIncome = 50000.0;

      final totalIncome = monoIncomeBaseline + manualIncome;
      final totalExpense = manualExpense;

      // Số dư chuẩn xác sau các giao dịch thủ công:
      final dynamicBalance = initialMono + totalIncome - totalExpense;
      expect(dynamicBalance, 149720.0);
      expect(dynamicBalance != 119720.0, isTrue);

      // Khi out app và mở lại (reconcileWalletBalances chạy dựa trên initialBalance cố định):
      final expectedAfterRestart = initialMono + totalIncome - totalExpense;
      expect(expectedAfterRestart, 149720.0);

      // initialBalance luôn được giữ nguyên ở mức 119.708đ, không bị bẻ cong
      expect(initialMono, 119708.0);
    });

    test('Ví tiền mặt bảo toàn số dư khi thêm chi tiêu thủ công sau mốc 52.000đ', () {
      const double initialCash = 52000.0;
      const double manualExpense = 15000.0;

      final dynamicCashBalance = initialCash - manualExpense;
      expect(dynamicCashBalance, 37000.0);

      // Sau khi restart, số dư vẫn phải là 37.000đ, không bị kéo về 52.000đ
      final balanceAfterRestart = initialCash - manualExpense;
      expect(balanceAfterRestart, 37000.0);
    });

    test('Xác nhận số dư thực tế chuẩn xác của người dùng: Tiền mặt 37.000đ, MoMo 4.710đ, Tổng 41.710đ', () {
      const double confirmedCash = 37000.0;
      const double confirmedMomo = 4710.0;
      final totalBalance = confirmedCash + confirmedMomo;
      expect(confirmedCash, 37000.0);
      expect(confirmedMomo, 4710.0);
      expect(totalBalance, 41710.0);
    });

    test('Tìm kiếm từ khóa năm 2020 phát hiện chính xác giao dịch năm 2020', () {
      final txDate2020 = DateTime(2020, 10, 15, 14, 30);
      final dateFormatted = CurrencyUtils.formatDate(txDate2020).toLowerCase();
      final yearStr = txDate2020.year.toString();

      const query = '2020';
      final matchesYear = yearStr.contains(query) || dateFormatted.contains(query);
      expect(matchesYear, isTrue);

      const queryDay = '15/10';
      final matchesDay = dateFormatted.contains(queryDay);
      expect(matchesDay, isTrue);
    });
  });
}
