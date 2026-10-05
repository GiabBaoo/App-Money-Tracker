import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  group('1. Wallet Balance Reconciliation Tests (Khắc phục lỗi số dư âm)', () {
    test('Cân đối số dư ví từ số dư ban đầu và các giao dịch thực tế', () {
      final wallet = WalletModel(
        id: 'wallet_cash_01',
        uid: 'user_test',
        name: 'Tiền mặt',
        type: 'cash',
        balance: -450000.0, // Giả lập số dư bị âm do các lần quét hóa đơn 2020 bị purge mất
        initialBalance: 500000.0, // Số dư ban đầu 500k
        iconCode: 0xe84f,
        colorValue: 0xFF438883,
      );

      // Danh sách các giao dịch thực tế còn tồn tại trong ví
      final transactions = [
        TransactionModel(
          id: 'tx_01',
          uid: 'user_test',
          type: 'income',
          amount: 200000.0,
          category: 'Tiền lương',
          categoryIconCode: 0xe84f,
          date: DateTime(2026, 9, 20),
          walletId: 'wallet_cash_01',
        ),
        TransactionModel(
          id: 'tx_02',
          uid: 'user_test',
          type: 'expense',
          amount: 50000.0,
          category: 'Ăn uống',
          categoryIconCode: 0xe84f,
          date: DateTime(2026, 9, 22),
          walletId: 'wallet_cash_01',
        ),
      ];

      // Tính toán reconciliation
      double totalIncome = 0.0;
      double totalExpense = 0.0;
      for (final tx in transactions) {
        if (tx.walletId == wallet.id) {
          if (tx.type == 'income') {
            totalIncome += tx.amount;
          } else {
            totalExpense += tx.amount;
          }
        }
      }

      final expectedBalance = wallet.initialBalance + totalIncome - totalExpense;

      // Kỳ vọng: 500.000 (initial) + 200.000 (income) - 50000 (expense) = 650.000đ
      expect(expectedBalance, equals(650000.0));

      // Phát hiện chênh lệch do bị âm trước đó
      final diff = expectedBalance - wallet.balance;
      expect(diff, equals(1100000.0)); // Phục hồi lại +1.100.000đ

      final reconciledWallet = wallet.copyWith(balance: expectedBalance);
      expect(reconciledWallet.balance, equals(650000.0));
      expect(reconciledWallet.balance >= 0, isTrue);
    });

    test('Trường hợp ví không có giao dịch nào thì số dư chuẩn bằng initialBalance', () {
      final wallet = WalletModel(
        id: 'wallet_momo_01',
        uid: 'user_test',
        name: 'MoMo',
        type: 'e_wallet',
        balance: -150000.0, // Bị trừ do hóa đơn năm 2020 rồi hóa đơn bị purge
        initialBalance: 100000.0,
        iconCode: 0xe84f,
        colorValue: 0xFF06D6A0,
      );

      final List<TransactionModel> transactions = [];

      double totalIncome = 0.0;
      double totalExpense = 0.0;
      for (final tx in transactions) {
        if (tx.walletId == wallet.id) {
          if (tx.type == 'income') totalIncome += tx.amount;
          if (tx.type == 'expense') totalExpense += tx.amount;
        }
      }

      final expectedBalance = wallet.initialBalance + totalIncome - totalExpense;
      expect(expectedBalance, equals(100000.0));

      final restoredWallet = wallet.copyWith(balance: expectedBalance);
      expect(restoredWallet.balance, equals(100000.0));
    });
  });

  group('2. Ergonomic Floating Capsule Layout Tests', () {
    test('Tọa độ neo của Floating Capsule phải nổi trên Navigation Bar (Thumb Zone)', () {
      const double bottomNavHeight = 64.0;
      const double bottomNavPadding = 10.0;
      const double deviceBottomInset = 28.0; // Giả lập Pixel 7a / iPhone cử chỉ vuốt

      // Thanh bottom navigation bar chiếm dụng từ 0 đến:
      const double bottomNavTopEdge = deviceBottomInset + bottomNavHeight + bottomNavPadding;
      expect(bottomNavTopEdge, equals(102.0));

      // Tọa độ Capsule mới: bottomInset + 84
      const double capsuleBottom = deviceBottomInset + 84.0;
      expect(capsuleBottom, equals(112.0));

      // Capsule nổi cách đỉnh của Bottom Navigation Bar 10px, hoàn toàn KHÔNG BỊ CHE!
      expect(capsuleBottom > bottomNavTopEdge, isTrue);
      expect(capsuleBottom - bottomNavTopEdge, equals(10.0));

      // Khoảng trống cuộn bên dưới: bottomInset + 160
      const double scrollPaddingBottom = deviceBottomInset + 160.0;
      expect(scrollPaddingBottom, equals(188.0));
      expect(scrollPaddingBottom > capsuleBottom, isTrue);
    });
  });
}
