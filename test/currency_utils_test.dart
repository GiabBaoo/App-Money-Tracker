import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/currency_format_utils.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('Định dạng số tiền âm không bị lỗi -.455.964đ', () {
      final formatted = CurrencyUtils.formatCurrency(-455964);
      expect(formatted, equals('-455.964đ'));
    });

    test('Định dạng số tiền âm formatNumberOnly', () {
      final formatted = CurrencyUtils.formatNumberOnly(-455964);
      expect(formatted, equals('-455.964'));
    });

    test('Định dạng số tiền dương thông thường', () {
      final formatted = CurrencyUtils.formatCurrency(1500000);
      expect(formatted, equals('1.500.000đ'));
    });

    test('Định dạng số tiền 0đ', () {
      final formatted = CurrencyUtils.formatCurrency(0);
      expect(formatted, equals('0đ'));
    });

    test('Định dạng số tiền nhỏ hơn 1.000', () {
      final formatted = CurrencyUtils.formatCurrency(36);
      expect(formatted, equals('36đ'));
      final formattedNeg = CurrencyUtils.formatCurrency(-36);
      expect(formattedNeg, equals('-36đ'));
    });

    test('calculateReverseWalletBalances tính ngược số dư chuẩn xác từ số dư hiện tại của ví', () {
      final walletMomo = WalletModel(
        id: 'w_momo',
        uid: 'user1',
        name: 'Ví MoMo',
        type: 'e_wallet',
        iconCode: 0,
        colorValue: 0,
        balance: 500022.0, // Số dư hiện tại sau khi nhận 22đ
      );

      final walletCash = WalletModel(
        id: 'w_cash',
        uid: 'user1',
        name: 'Tiền mặt',
        type: 'cash',
        iconCode: 0,
        colorValue: 0,
        balance: 1000000.0,
      );

      // Giao dịch ví MoMo:
      // tx1 (cũ hơn): chi 50.000đ lúc 10:00
      // tx2 (mới nhất): nhận lãi 22đ lúc 12:00
      final tx1 = TransactionModel(
        id: 'tx_1',
        uid: 'user1',
        type: 'expense',
        category: 'Ăn trưa',
        categoryIconCode: 0,
        amount: 50000.0,
        date: DateTime(2026, 9, 25),
        time: '10:00',
        walletId: 'w_momo',
      );

      final tx2 = TransactionModel(
        id: 'tx_2',
        uid: 'user1',
        type: 'income',
        category: 'Tiền lãi',
        categoryIconCode: 0,
        amount: 22.0,
        date: DateTime(2026, 9, 25),
        time: '12:00',
        walletId: 'w_momo',
      );

      final txCash = TransactionModel(
        id: 'tx_cash_1',
        uid: 'user1',
        type: 'expense',
        category: 'Xăng xe',
        categoryIconCode: 0,
        amount: 100000.0,
        date: DateTime(2026, 9, 25),
        time: '11:00',
        walletId: 'w_cash',
      );

      final balances = CurrencyUtils.calculateReverseWalletBalances(
        allTransactions: [tx1, tx2, txCash],
        wallets: [walletMomo, walletCash],
      );

      // Giao dịch mới nhất MoMo (tx2) phải có số dư bằng số dư hiện tại của ví MoMo: 500.022đ
      expect(balances['tx_2'], equals(500022.0));

      // Giao dịch trước đó của MoMo (tx1) phải có số dư trước khi nhận 22đ: 500.022 - 22 = 500.000đ
      expect(balances['tx_1'], equals(500000.0));

      // Giao dịch ví tiền mặt (txCash) phải có số dư đúng bằng số dư hiện tại ví tiền mặt: 1.000.000đ
      expect(balances['tx_cash_1'], equals(1000000.0));
    });

    test('isTransfer nhận diện chính xác giao dịch chuyển tiền nội bộ giữa các ví', () {
      final transferOut = TransactionModel(
        id: 'tx_out',
        uid: 'user1',
        type: 'expense',
        category: 'Chuyển tiền',
        categoryIconCode: 0,
        amount: 200000.0,
        date: DateTime(2026, 9, 25),
        walletId: 'w_cash',
        groupId: 'transfer_123',
      );

      final transferIn = TransactionModel(
        id: 'tx_in',
        uid: 'user1',
        type: 'income',
        category: 'Nhận chuyển tiền',
        categoryIconCode: 0,
        amount: 200000.0,
        date: DateTime(2026, 9, 25),
        walletId: 'w_momo',
        groupId: 'transfer_123',
      );

      final normalExpense = TransactionModel(
        id: 'tx_exp',
        uid: 'user1',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 0,
        amount: 50000.0,
        date: DateTime(2026, 9, 25),
        walletId: 'w_cash',
      );

      expect(transferOut.isTransfer, isTrue);
      expect(transferIn.isTransfer, isTrue);
      expect(normalExpense.isTransfer, isFalse);
    });
  });
}
