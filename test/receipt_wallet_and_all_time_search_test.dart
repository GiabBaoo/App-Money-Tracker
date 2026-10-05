import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';
import 'package:money_tracker_app/utils/currency_format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hóa Đơn Mai Long Mart - All-Time Search & Wallet Filter Tests', () {
    final now = DateTime.now();

    // Giao dịch từ hóa đơn Mai Long Mart ngày 08-03-2020
    final txMaiLongMart2020 = TransactionModel(
      id: 'tx_mai_long_mart_2020',
      uid: 'user_test',
      type: 'expense',
      category: 'Ăn uống',
      categoryIconCode: 100,
      amount: 150000,
      date: DateTime(2020, 3, 8, 15, 51, 7),
      time: '15:51',
      description: 'Mỳ hảo hảo chua cay 75g (30/thùng)',
      walletId: 'wallet_momo',
    );

    // Giao dịch hiện tại trong tháng này
    final txCurrentMonth = TransactionModel(
      id: 'tx_current_month',
      uid: 'user_test',
      type: 'expense',
      category: 'Ăn uống',
      categoryIconCode: 100,
      amount: 45000,
      date: DateTime(now.year, now.month, 1, 8, 30),
      time: '08:30',
      description: 'Bún bò Huế',
      walletId: 'wallet_cash',
    );

    final walletCash = WalletModel(
      id: 'wallet_cash',
      uid: 'user_test',
      name: 'Tiền mặt',
      type: 'cash',
      iconCode: 100,
      colorValue: 0xFF438883,
      balance: 500000,
    );

    final walletMomo = WalletModel(
      id: 'wallet_momo',
      uid: 'user_test',
      name: 'Ví MoMo',
      type: 'e_wallet',
      iconCode: 100,
      colorValue: 0xFF438883,
      balance: 1000000,
    );

    final allTxs = [txMaiLongMart2020, txCurrentMonth];
    final wallets = [walletCash, walletMomo];

    test('1. Khi chưa tìm kiếm: Bộ lọc month_to_date ẩn giao dịch năm 2020', () {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final filtered = allTxs.where((tx) {
        final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
        return !txDate.isBefore(start) && !txDate.isAfter(end);
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'tx_current_month');
      expect(filtered.any((tx) => tx.id == 'tx_mai_long_mart_2020'), isFalse);
    });

    test('2. Khi tìm kiếm từ khóa "hảo hảo": Tự động tìm kiếm Toàn thời gian và thấy giao dịch năm 2020', () {
      const searchQuery = 'hảo hảo';

      // Logic All-Time Search: Khi có searchQuery, bỏ qua bộ lọc month_to_date
      final filtered = allTxs.where((tx) {
        final desc = tx.description.toLowerCase();
        final cat = tx.category.toLowerCase();
        final amt = tx.amount.toString();
        final formattedAmt = CurrencyUtils.formatCurrency(tx.amount).toLowerCase();

        return desc.contains(searchQuery) ||
            cat.contains(searchQuery) ||
            amt.contains(searchQuery) ||
            formattedAmt.contains(searchQuery);
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'tx_mai_long_mart_2020');
      expect(filtered.first.amount, 150000);
      expect(filtered.first.description, contains('Mỳ hảo hảo'));
    });

    test('3. Tìm kiếm theo định dạng tiền tệ "150.000" tìm thấy giao dịch', () {
      const searchQuery = '150.000';

      final filtered = allTxs.where((tx) {
        final desc = tx.description.toLowerCase();
        final cat = tx.category.toLowerCase();
        final amt = tx.amount.toString();
        final formattedAmt = CurrencyUtils.formatCurrency(tx.amount).toLowerCase();

        return desc.contains(searchQuery) ||
            cat.contains(searchQuery) ||
            amt.contains(searchQuery) ||
            formattedAmt.contains(searchQuery);
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'tx_mai_long_mart_2020');
    });

    test('4. Tìm kiếm theo tên ví "momo" tìm thấy giao dịch thuộc ví MoMo', () {
      const searchQuery = 'momo';

      final filtered = allTxs.where((tx) {
        final desc = tx.description.toLowerCase();
        final cat = tx.category.toLowerCase();
        final amt = tx.amount.toString();
        final formattedAmt = CurrencyUtils.formatCurrency(tx.amount).toLowerCase();
        final walletMatches = wallets.where((w) => w.id == tx.walletId);
        final walletName = walletMatches.isNotEmpty ? walletMatches.first.name.toLowerCase() : '';

        return desc.contains(searchQuery) ||
            cat.contains(searchQuery) ||
            amt.contains(searchQuery) ||
            formattedAmt.contains(searchQuery) ||
            (walletName.isNotEmpty && walletName.contains(searchQuery));
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'tx_mai_long_mart_2020');
      expect(filtered.first.walletId, 'wallet_momo');
    });
  });

  group('AI Assistant Receipt Item & Date/Wallet Selection Tests', () {
    test('1. Hóa đơn năm 2020 được nhận diện là ngày cũ', () {
      final receiptItem = AiTransactionItem(
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 150000,
        description: 'Mỳ hảo hảo chua cay',
        date: DateTime(2020, 3, 8, 15, 51),
        walletName: '',
      );

      final now = DateTime.now();
      final isOldDate = now.difference(receiptItem.date).inDays.abs() > 30 ||
          receiptItem.date.year != now.year;

      expect(isOldDate, isTrue);
      expect(receiptItem.date.year, 2020);
    });

    test('2. Cập nhật ví từ rỗng sang Ví MoMo', () {
      final receiptItem = AiTransactionItem(
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 150000,
        description: 'Mỳ hảo hảo chua cay',
        date: DateTime(2020, 3, 8, 15, 51),
        walletName: '',
      );

      final updatedItem = receiptItem.copyWith(walletName: 'Ví MoMo');
      expect(updatedItem.walletName, 'Ví MoMo');
      expect(updatedItem.amount, 150000);
      expect(updatedItem.description, 'Mỳ hảo hảo chua cay');
    });

    test('3. Chuyển ngày từ 08/03/2020 sang Hôm nay', () {
      final receiptItem = AiTransactionItem(
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 150000,
        description: 'Mỳ hảo hảo chua cay',
        date: DateTime(2020, 3, 8, 15, 51),
        walletName: 'Ví MoMo',
      );

      final today = DateTime.now();
      final updatedItem = receiptItem.copyWith(date: today);

      expect(updatedItem.date.year, today.year);
      expect(updatedItem.date.month, today.month);
      expect(updatedItem.date.day, today.day);

      // Khi chuyển sang hôm nay, nó không còn là old date nữa
      final isOldDate = DateTime.now().difference(updatedItem.date).inDays.abs() > 30 ||
          updatedItem.date.year != DateTime.now().year;
      expect(isOldDate, isFalse);
    });

    test('4. Phân giải targetWalletId chính xác khi người dùng chọn Ví MoMo', () {
      final wallets = [
        WalletModel(id: 'wallet_cash', uid: 'u1', name: 'Tiền mặt', type: 'cash', iconCode: 100, colorValue: 0xFF438883, balance: 500000),
        WalletModel(id: 'wallet_momo', uid: 'u1', name: 'Ví MoMo', type: 'e_wallet', iconCode: 100, colorValue: 0xFF438883, balance: 1000000),
      ];

      final defaultWalletId = wallets.isNotEmpty ? wallets.first.id : '';
      final item = AiTransactionItem(
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 150000,
        description: 'Mỳ hảo hảo',
        date: DateTime.now(),
        walletName: 'Ví MoMo',
      );

      String targetWalletId = defaultWalletId;
      if (item.walletName.isNotEmpty && wallets.isNotEmpty) {
        final matched = wallets.where(
          (w) => w.name.toLowerCase().contains(item.walletName.toLowerCase()),
        );
        if (matched.isNotEmpty) {
          targetWalletId = matched.first.id;
        }
      }

      // Đảm bảo không bị gán nhầm vào Tiền mặt mà gán chính xác vào Ví MoMo
      expect(targetWalletId, 'wallet_momo');
      expect(targetWalletId, isNot('wallet_cash'));
    });
  });
}
