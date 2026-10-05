import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction Balance & Cashflow Unit Tests', () {
    test('1. Giao dịch Thu/Chi tác động số dư ví (Delta Calculation)', () {
      final initialWallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Tiền mặt',
        type: 'cash',
        iconCode: 100,
        colorValue: 0xFF438883,
        balance: 1000000,
      );

      // Chi tiêu 150.000đ: Số dư giảm 150.000đ
      final expenseTx = TransactionModel(
        id: 'tx_exp',
        uid: 'u1',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 150000,
        date: DateTime.now(),
        walletId: 'w1',
      );

      final deltaExpense = expenseTx.type == 'income' ? expenseTx.amount : -expenseTx.amount;
      final walletAfterExpense = initialWallet.copyWith(
        balance: initialWallet.balance + deltaExpense,
      );
      expect(walletAfterExpense.balance, equals(850000.0));

      // Thu nhập 500.000đ: Số dư tăng 500.000đ
      final incomeTx = TransactionModel(
        id: 'tx_inc',
        uid: 'u1',
        type: 'income',
        category: 'Thưởng',
        categoryIconCode: 101,
        amount: 500000,
        date: DateTime.now(),
        walletId: 'w1',
      );

      final deltaIncome = incomeTx.type == 'income' ? incomeTx.amount : -incomeTx.amount;
      final walletAfterIncome = walletAfterExpense.copyWith(
        balance: walletAfterExpense.balance + deltaIncome,
      );
      expect(walletAfterIncome.balance, equals(1350000.0));
    });

    test('2. Chỉnh sửa giao dịch: Tính toán cân đối số dư (Revert tác động cũ + Áp dụng tác động mới)', () {
      final wallet = WalletModel(
        id: 'w_bank',
        uid: 'u1',
        name: 'Ngân hàng',
        type: 'bank',
        iconCode: 101,
        colorValue: 0xFF438883,
        balance: 2000000,
      );

      // Kịch bản A: Sửa tăng số tiền chi từ 100.000đ lên 300.000đ
      final oldTxA = TransactionModel(
        id: 't_a',
        uid: 'u1',
        type: 'expense',
        category: 'Mua sắm',
        categoryIconCode: 100,
        amount: 100000,
        date: DateTime.now(),
        walletId: 'w_bank',
      );
      final newTxA = oldTxA.copyWith(amount: 300000);

      // Revert old + apply new
      final revertOldDeltaA = (oldTxA.type == 'income') ? -oldTxA.amount : oldTxA.amount;
      final applyNewDeltaA = (newTxA.type == 'income') ? newTxA.amount : -newTxA.amount;
      final netBalanceA = wallet.balance + revertOldDeltaA + applyNewDeltaA;
      // 2.000.000 + 100.000 - 300.000 = 1.800.000
      expect(netBalanceA, equals(1800000.0));

      // Kịch bản B: Chuyển loại giao dịch từ Chi (200k) sang Thu (200k)
      final oldTxB = TransactionModel(
        id: 't_b',
        uid: 'u1',
        type: 'expense',
        category: 'Khác',
        categoryIconCode: 100,
        amount: 200000,
        date: DateTime.now(),
        walletId: 'w_bank',
      );
      final newTxB = oldTxB.copyWith(type: 'income', category: 'Thu khác');

      final revertOldDeltaB = (oldTxB.type == 'income') ? -oldTxB.amount : oldTxB.amount;
      final applyNewDeltaB = (newTxB.type == 'income') ? newTxB.amount : -newTxB.amount;
      final netBalanceB = wallet.balance + revertOldDeltaB + applyNewDeltaB;
      // 2.000.000 + 200.000 (revert expense) + 200.000 (apply income) = 2.400.000
      expect(netBalanceB, equals(2400000.0));
    });

    test('3. Chuyển tiền giữa 2 ví (Transfer): Bảo toàn tổng tài sản (Zero-sum Net Worth)', () {
      final walletSource = WalletModel(
        id: 'w_src',
        uid: 'u1',
        name: 'Ví tiền mặt',
        type: 'cash',
        iconCode: 100,
        colorValue: 0xFF438883,
        balance: 1000000,
      );
      final walletDest = WalletModel(
        id: 'w_dst',
        uid: 'u1',
        name: 'Ví MoMo',
        type: 'e_wallet',
        iconCode: 102,
        colorValue: 0xFF438883,
        balance: 500000,
      );

      final totalNetWorthBefore = walletSource.balance + walletDest.balance;
      expect(totalNetWorthBefore, equals(1500000.0));

      // Chuyển 300.000đ từ Ví tiền mặt sang Ví MoMo
      const transferAmount = 300000.0;
      final updatedSource = walletSource.copyWith(balance: walletSource.balance - transferAmount);
      final updatedDest = walletDest.copyWith(balance: walletDest.balance + transferAmount);

      expect(updatedSource.balance, equals(700000.0));
      expect(updatedDest.balance, equals(800000.0));

      final totalNetWorthAfter = updatedSource.balance + updatedDest.balance;
      expect(totalNetWorthAfter, equals(totalNetWorthBefore)); // Tổng tài sản tuyệt đối bảo toàn

      // Khi hủy / xóa giao dịch chuyển tiền (Rollback):
      final rollbackSource = updatedSource.copyWith(balance: updatedSource.balance + transferAmount);
      final rollbackDest = updatedDest.copyWith(balance: updatedDest.balance - transferAmount);

      expect(rollbackSource.balance, equals(walletSource.balance));
      expect(rollbackDest.balance, equals(walletDest.balance));
      expect(rollbackSource.balance + rollbackDest.balance, equals(totalNetWorthBefore));
    });

    test('4. Chuyển ví khi sửa giao dịch: Hoàn ví cũ và trừ/cộng ví mới độc lập', () {
      final wallet1 = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví 1',
        type: 'cash',
        iconCode: 100,
        colorValue: 0xFF438883,
        balance: 1000000,
      );
      final wallet2 = WalletModel(
        id: 'w2',
        uid: 'u1',
        name: 'Ví 2',
        type: 'bank',
        iconCode: 101,
        colorValue: 0xFF438883,
        balance: 2000000,
      );

      // Giao dịch chi 100k trước đây ghi nhầm vào Ví 1, nay sửa chuyển sang Ví 2
      final oldTx = TransactionModel(
        id: 'tx_change_w',
        uid: 'u1',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 100,
        amount: 100000,
        date: DateTime.now(),
        walletId: 'w1',
      );
      final newTx = oldTx.copyWith(walletId: 'w2');

      // 1. Hoàn lại cho ví cũ (w1)
      final revertDelta = (oldTx.type == 'income') ? -oldTx.amount : oldTx.amount;
      final updatedW1 = wallet1.copyWith(balance: wallet1.balance + revertDelta);

      // 2. Trừ tiền ở ví mới (w2)
      final applyDelta = (newTx.type == 'income') ? newTx.amount : -newTx.amount;
      final updatedW2 = wallet2.copyWith(balance: wallet2.balance + applyDelta);

      expect(updatedW1.balance, equals(1100000.0)); // w1 được hoàn lại 100k
      expect(updatedW2.balance, equals(1900000.0)); // w2 bị trừ 100k
      expect(updatedW1.balance + updatedW2.balance, equals(wallet1.balance + wallet2.balance));
    });
  });
}
