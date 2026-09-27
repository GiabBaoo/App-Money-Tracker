import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/modules/wallet/wallet_history_screen.dart';
import 'package:money_tracker_app/modules/home/wallet_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mono Voice Parsing Tests (Tiền bún bò, Ví MoMo, Số tiền âm/dương)', () {
    final aiService = GeminiAiService();

    test('1. Nhận diện chính xác "-35.000đ tiền bún bò vào ví momo"', () async {
      // Offline fallback pipeline regex & smart categorization test
      final result = await aiService.parseNaturalLanguage('-35.000đ tiền bún bò vào ví momo');

      expect(result.actionType, equals(AiActionType.recordTransaction));
      expect(result.needsAmount, isFalse);
      expect(result.transactions.isNotEmpty, isTrue);

      final tx = result.transactions.first;
      // Amount must be 35000
      expect(tx.amount, equals(35000.0));
      // Type must be expense (chi tiêu) vì có dấu -
      expect(tx.type, equals('expense'));
      // Wallet must be MoMo
      expect(tx.walletName.toLowerCase(), contains('momo'));
      // Description must be "Tiền bún bò", NOT "Trừ tiền từ ví MoMo" or "Chi tiêu"
      expect(tx.description.toLowerCase(), contains('tiền bún bò'));
      // Category must be Ăn uống
      expect(tx.category, equals('Ăn uống'));
    });

    test('2. Nhận diện chính xác "+50.000đ tiền lương vào ví momo"', () async {
      final result = await aiService.parseNaturalLanguage('+50.000đ tiền lương vào ví momo');

      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.amount, equals(50000.0));
      expect(tx.type, equals('income'));
      expect(tx.walletName.toLowerCase(), contains('momo'));
      expect(tx.description.toLowerCase(), contains('tiền lương'));
      expect(tx.category, equals('Tiền lương'));
    });

    test('3. Fallback khi người dùng không đọc tên món ("-35k momo")', () async {
      final result = await aiService.parseNaturalLanguage('-35k momo');

      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.amount, equals(35000.0));
      expect(tx.type, equals('expense'));
      expect(tx.walletName.toLowerCase(), contains('momo'));
      // Khi không có tên món, mô tả mặc định rõ ràng
      expect(tx.description.toLowerCase(), contains('chi tiêu từ ví momo'));
    });

    test('4. Nhận diện câu nói chưa có số tiền ("mới đi ăn bún bò trả bằng ví momo")', () async {
      final result = await aiService.parseNaturalLanguage('mới đi ăn bún bò trả bằng ví momo');

      expect(result.needsAmount, isTrue);
      expect(result.transactions.isNotEmpty, isTrue);
      final tx = result.transactions.first;
      expect(tx.amount, equals(0.0));
      expect(tx.walletName.toLowerCase(), contains('momo'));
      expect(tx.description.toLowerCase(), contains('bún bò'));
    });
  });

  group('Wallet History Multi-Dimensional Filter Logic Tests', () {
    final now = DateTime.now();

    final txMomoExpense = TransactionModel(
      id: 'tx_momo_1',
      uid: 'user_test',
      type: 'expense',
      category: 'Ăn uống',
      categoryIconCode: 100,
      amount: 35000,
      description: 'Tiền bún bò',
      date: DateTime(now.year, now.month, now.day, 12, 0),
      walletId: 'wallet_momo',
    );

    final txMomoIncome = TransactionModel(
      id: 'tx_momo_2',
      uid: 'user_test',
      type: 'income',
      category: 'Tiền lương',
      categoryIconCode: 101,
      amount: 5000000,
      description: 'Lương tháng này',
      date: DateTime(now.year, now.month, now.day, 9, 0),
      walletId: 'wallet_momo',
    );

    final txCashExpense = TransactionModel(
      id: 'tx_cash_1',
      uid: 'user_test',
      type: 'expense',
      category: 'Mua sắm',
      categoryIconCode: 102,
      amount: 120000,
      description: 'Mua sách',
      date: DateTime(now.year, now.month, now.day, 15, 30),
      walletId: 'wallet_cash',
    );

    final txTransfer = TransactionModel(
      id: 'tx_transfer_1',
      uid: 'user_test',
      type: 'expense',
      category: 'Chuyển tiền',
      categoryIconCode: 103,
      amount: 200000,
      description: 'Chuyển sang ví tiền mặt',
      date: DateTime(now.year, now.month, now.day, 16, 0),
      walletId: 'wallet_momo',
      groupId: 'transfer_group',
    );

    final allTxs = [txMomoExpense, txMomoIncome, txCashExpense, txTransfer];

    test('1. Lọc theo ví cụ thể (walletId)', () {
      final momoTxs = allTxs.where((tx) => tx.walletId == 'wallet_momo').toList();
      expect(momoTxs.length, equals(3));
      expect(momoTxs.map((t) => t.id), containsAll(['tx_momo_1', 'tx_momo_2', 'tx_transfer_1']));

      final cashTxs = allTxs.where((tx) => tx.walletId == 'wallet_cash').toList();
      expect(cashTxs.length, equals(1));
      expect(cashTxs.first.id, equals('tx_cash_1'));
    });

    test('2. Tìm kiếm theo từ khóa ("bún bò", "sách", số tiền)', () {
      bool matchesQuery(TransactionModel tx, String q) {
        final query = q.toLowerCase();
        return tx.description.toLowerCase().contains(query) ||
            tx.category.toLowerCase().contains(query) ||
            tx.amount.toString().contains(query);
      }

      final searchBunBo = allTxs.where((tx) => matchesQuery(tx, 'bún bò')).toList();
      expect(searchBunBo.length, equals(1));
      expect(searchBunBo.first.description, equals('Tiền bún bò'));

      final searchAmount = allTxs.where((tx) => matchesQuery(tx, '35000')).toList();
      expect(searchAmount.length, equals(1));
      expect(searchAmount.first.id, equals('tx_momo_1'));
    });

    test('3. Tính toán dòng tiền (Income, Expense, Net) chính xác', () {
      final momoTxs = allTxs.where((tx) => tx.walletId == 'wallet_momo').toList();

      double inc = 0;
      double exp = 0;
      for (final tx in momoTxs) {
        if (tx.type == 'income') {
          inc += tx.amount;
        } else if (tx.type == 'expense') {
          exp += tx.amount;
        }
      }

      expect(inc, equals(5000000.0));
      expect(exp, equals(235000.0)); // 35000 + 200000
      expect(inc - exp, equals(4765000.0));
    });
  });

  group('Wallet Screen & Wallet History Widget Tests', () {
    testWidgets('WalletHistoryScreen builds with search and filter controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WalletHistoryScreen(initialWalletId: 'wallet_test'),
        ),
      );
      await tester.pump();

      // Check header and search field exist
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chi tiêu'), findsAtLeastNWidgets(1));
      expect(find.text('Thu nhập'), findsAtLeastNWidgets(1));
      expect(find.text('Bộ lọc'), findsOneWidget);
    });

    testWidgets('WalletScreen displays Net Worth hero card, recent transactions, and view all button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WalletScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check net worth title exists
      expect(find.text('Tổng tài sản'), findsOneWidget);
      // Check recent transactions title exists
      expect(find.text('Giao dịch gần đây'), findsOneWidget);
      // Check View All link exists
      expect(find.text('Xem tất cả'), findsOneWidget);
    });
  });
}
