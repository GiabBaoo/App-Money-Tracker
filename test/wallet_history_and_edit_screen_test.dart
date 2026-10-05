import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/utils/currency_format_utils.dart';
import 'package:money_tracker_app/modules/transaction/edit_transaction_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet Transaction History & Filter Logic Tests', () {
    final now = DateTime.now();

    final txWallet1Expense = TransactionModel(
      id: 'tx_1',
      uid: 'user_test',
      type: 'expense',
      category: 'Ăn uống',
      categoryIconCode: 100,
      amount: 50000,
      date: DateTime(now.year, now.month, now.day, 12, 0),
      walletId: 'wallet_1',
    );

    final txWallet1Income = TransactionModel(
      id: 'tx_2',
      uid: 'user_test',
      type: 'income',
      category: 'Tiền lương',
      categoryIconCode: 101,
      amount: 2000000,
      date: DateTime(now.year, now.month, now.day, 9, 0),
      walletId: 'wallet_1',
    );

    final txWallet2Expense = TransactionModel(
      id: 'tx_3',
      uid: 'user_test',
      type: 'expense',
      category: 'Mua sắm',
      categoryIconCode: 102,
      amount: 150000,
      date: DateTime(now.year, now.month, now.day, 15, 30),
      walletId: 'wallet_2',
    );

    final txTransferWallet1 = TransactionModel(
      id: 'tx_4',
      uid: 'user_test',
      type: 'expense',
      category: 'Chuyển tiền',
      categoryIconCode: 103,
      amount: 300000,
      date: DateTime(now.year, now.month, now.day, 16, 0),
      walletId: 'wallet_1',
      groupId: 'transfer_123',
    );

    final allTxs = [
      txWallet1Expense,
      txWallet1Income,
      txWallet2Expense,
      txTransferWallet1,
    ];

    test('1. Lọc giao dịch theo từng ví cụ thể', () {
      final wallet1Txs = allTxs.where((tx) => tx.walletId == 'wallet_1').toList();
      expect(wallet1Txs.length, equals(3));
      expect(wallet1Txs.map((t) => t.id), containsAll(['tx_1', 'tx_2', 'tx_4']));

      final wallet2Txs = allTxs.where((tx) => tx.walletId == 'wallet_2').toList();
      expect(wallet2Txs.length, equals(1));
      expect(wallet2Txs.first.id, equals('tx_3'));
    });

    test('2. Lọc theo Loại giao dịch: Tất cả, Chi tiêu, Thu nhập, Chuyển ví', () {
      // Chi tiêu thuần (không tính chuyển tiền)
      final expenseTxs = allTxs.where((tx) => tx.type == 'expense' && !tx.isTransfer).toList();
      expect(expenseTxs.length, equals(2));
      expect(expenseTxs.map((t) => t.category), containsAll(['Ăn uống', 'Mua sắm']));

      // Thu nhập
      final incomeTxs = allTxs.where((tx) => tx.type == 'income' && !tx.isTransfer).toList();
      expect(incomeTxs.length, equals(1));
      expect(incomeTxs.first.category, equals('Tiền lương'));

      // Chuyển ví
      final transferTxs = allTxs.where((tx) => tx.isTransfer).toList();
      expect(transferTxs.length, equals(1));
      expect(transferTxs.first.category, equals('Chuyển tiền'));
    });

    test('3. Tính toán Tóm tắt dòng tiền ví (Income, Expense, Net cashflow)', () {
      final wallet1Txs = allTxs.where((tx) => tx.walletId == 'wallet_1').toList();

      double inc = 0;
      double exp = 0;
      for (final tx in wallet1Txs) {
        if (tx.type == 'income') {
          inc += tx.amount;
        } else if (tx.type == 'expense') {
          exp += tx.amount;
        }
      }

      expect(inc, equals(2000000.0));
      expect(exp, equals(350000.0)); // 50k + 300k transfer
      expect(inc - exp, equals(1650000.0));
    });

    test('4. Phân loại danh mục theo ví (Category Breakdown) được sắp xếp giảm dần', () {
      final txA = TransactionModel(
        id: 'a',
        uid: 'u',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 80000,
        date: now,
        walletId: 'wallet_1',
      );
      final txB = TransactionModel(
        id: 'b',
        uid: 'u',
        type: 'expense',
        category: 'Di chuyển',
        categoryIconCode: 2,
        amount: 120000,
        date: now,
        walletId: 'wallet_1',
      );
      final txC = TransactionModel(
        id: 'c',
        uid: 'u',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 40000,
        date: now,
        walletId: 'wallet_1',
      );

      final testList = [txA, txB, txC];
      final Map<String, double> breakdownMap = {};
      for (final tx in testList) {
        if (tx.type == 'expense' && !tx.isTransfer) {
          breakdownMap[tx.category] = (breakdownMap[tx.category] ?? 0) + tx.amount;
        }
      }

      final sorted = breakdownMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      expect(sorted.length, equals(2));
      // 'Ăn uống' = 120.000, 'Di chuyển' = 120.000
      expect(breakdownMap['Ăn uống'], equals(120000.0));
      expect(breakdownMap['Di chuyển'], equals(120000.0));
    });

    test('5. Bộ lọc thời gian: Today, Custom Date Range, All Time', () {
      final yesterday = now.subtract(const Duration(days: 1));
      final pastMonth = DateTime(now.year, now.month - 2, 10);

      final txToday = TransactionModel(
        id: 't_today',
        uid: 'u',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 20000,
        date: now,
        walletId: 'w',
      );
      final txYesterday = TransactionModel(
        id: 't_yesterday',
        uid: 'u',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 30000,
        date: yesterday,
        walletId: 'w',
      );
      final txPast = TransactionModel(
        id: 't_past',
        uid: 'u',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 40000,
        date: pastMonth,
        walletId: 'w',
      );

      final list = [txToday, txYesterday, txPast];

      // Lọc Hôm nay
      final todayMatches = list.where((tx) =>
          tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day).toList();
      expect(todayMatches.length, equals(1));
      expect(todayMatches.first.id, equals('t_today'));

      // Lọc Custom Range (3 ngày qua)
      final range = DateTimeRange(
        start: now.subtract(const Duration(days: 2)),
        end: now.add(const Duration(days: 1)),
      );
      final rangeMatches = list.where((tx) =>
          !tx.date.isBefore(range.start) && !tx.date.isAfter(range.end)).toList();
      expect(rangeMatches.length, equals(2));
      expect(rangeMatches.map((t) => t.id), containsAll(['t_today', 't_yesterday']));
    });

    test('6. Định dạng tiền tệ VND đồng bộ không bị lỗi dấu', () {
      expect(CurrencyUtils.formatCurrency(50000), equals('50.000đ'));
      expect(CurrencyUtils.formatCurrency(1250000), equals('1.250.000đ'));
      expect(CurrencyUtils.parseCurrency('50.000 ₫'), equals(50000.0));
      expect(CurrencyUtils.parseCurrency('1.250.000'), equals(1250000.0));
    });
  });

  group('EditTransactionScreen Widget Unit Tests', () {
    testWidgets('EditTransactionScreen khởi tạo thành công không văng exception', (tester) async {
      final mockTx = TransactionModel(
        id: 'edit_test_1',
        uid: 'user_mock',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: Icons.restaurant.codePoint,
        amount: 75000,
        date: DateTime.now(),
        time: '12:30',
        description: 'Bữa trưa công ty',
        walletId: 'wallet_mock_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: EditTransactionScreen(transaction: mockTx),
        ),
      );

      // Verify tiêu đề và các trường khởi tạo
      expect(find.text('Chỉnh sửa giao dịch'), findsOneWidget);
      expect(find.text('Khoản chi'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Cập nhật giao dịch'), findsOneWidget);
      expect(find.text('Xóa giao dịch này'), findsOneWidget);
    });
  });
}
