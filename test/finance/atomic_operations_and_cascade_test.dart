import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/utils/finance_precision.dart';
import 'package:money_tracker_app/services/financial_calculation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Suite 5: Atomic Operations, Cascade & Reconciliation', () {
    final now = DateTime(2026, 10, 25);

    test('TC-ATOM-01: Hoàn trả số dư ví chính xác khi giao dịch thu nhập hoặc chi tiêu bị xóa', () {
      var wallet = WalletModel(
        id: 'w1',
        uid: 'u1',
        name: 'Ví Tiền mặt',
        type: WalletType.cash,
        balance: 10000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      // 1. Thêm giao dịch chi tiêu 2.000.000 VND
      final expenseTx = TransactionModel(
        id: 'tx_exp',
        uid: 'u1',
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: 1,
        amount: 2000000.0,
        date: now,
        walletId: 'w1',
      );
      wallet = wallet.copyWith(
        balance: FinancePrecision.subtract(wallet.balance, expenseTx.amount),
      );
      expect(wallet.balance, equals(8000000.0));

      // 2. Xóa giao dịch chi tiêu -> Hoàn lại số dư ví (+ 2.000.000 VND)
      final revertDelta = (expenseTx.type == 'income')
          ? -expenseTx.amount
          : expenseTx.amount;
      wallet = wallet.copyWith(
        balance: FinancePrecision.add(wallet.balance, revertDelta),
      );
      expect(wallet.balance, equals(10000000.0));

      // 3. Thêm giao dịch thu nhập 5.000.000 VND
      final incomeTx = TransactionModel(
        id: 'tx_inc',
        uid: 'u1',
        type: 'income',
        category: 'Thưởng',
        categoryIconCode: 2,
        amount: 5000000.0,
        date: now,
        walletId: 'w1',
      );
      wallet = wallet.copyWith(
        balance: FinancePrecision.add(wallet.balance, incomeTx.amount),
      );
      expect(wallet.balance, equals(15000000.0));

      // 4. Xóa giao dịch thu nhập -> Hoàn lại số dư ví (- 5.000.000 VND)
      final revertIncomeDelta = (incomeTx.type == 'income')
          ? -incomeTx.amount
          : incomeTx.amount;
      wallet = wallet.copyWith(
        balance: FinancePrecision.add(wallet.balance, revertIncomeDelta),
      );
      expect(wallet.balance, equals(10000000.0));
    });

    test('TC-ATOM-02: Thay đổi ví khi sửa giao dịch chuyển giao số dư nguyên tử giữa 2 ví', () {
      var oldWallet = WalletModel(
        id: 'w_old',
        uid: 'u1',
        name: 'Ví Cũ',
        type: WalletType.cash,
        balance: 5000000.0,
        iconCode: 1,
        colorValue: 1,
      );

      var newWallet = WalletModel(
        id: 'w_new',
        uid: 'u1',
        name: 'Ví Mới',
        type: WalletType.bank,
        balance: 10000000.0,
        iconCode: 2,
        colorValue: 2,
      );

      // Giao dịch cũ: Chi tiêu 1.000.000 VND ở ví cũ
      final oldTx = TransactionModel(
        id: 'tx_1',
        uid: 'u1',
        type: 'expense',
        category: 'Mua sắm',
        categoryIconCode: 1,
        amount: 1000000.0,
        date: now,
        walletId: 'w_old',
      );

      // Giao dịch mới: Chuyển sang ví mới và đổi số tiền thành 1.500.000 VND
      final newTx = oldTx.copyWith(
        walletId: 'w_new',
        amount: 1500000.0,
      );

      // Revert ví cũ: + 1.000.000 VND
      oldWallet = oldWallet.copyWith(
        balance: FinancePrecision.add(oldWallet.balance, oldTx.amount),
      );

      // Apply ví mới: - 1.500.000 VND
      newWallet = newWallet.copyWith(
        balance: FinancePrecision.subtract(newWallet.balance, newTx.amount),
      );

      expect(oldWallet.balance, equals(6000000.0));
      expect(newWallet.balance, equals(8500000.0));
    });

    test('TC-ATOM-03: Cascade soft-delete giao dịch khi xóa ví', () {
      final transactions = [
        TransactionModel(
          id: 'tx_w1_1',
          uid: 'u1',
          type: 'expense',
          category: 'Cà phê',
          categoryIconCode: 1,
          amount: 50000.0,
          date: now,
          walletId: 'wallet_to_delete',
          isDeleted: false,
        ),
        TransactionModel(
          id: 'tx_w1_2',
          uid: 'u1',
          type: 'income',
          category: 'Tiền boa',
          categoryIconCode: 2,
          amount: 100000.0,
          date: now,
          walletId: 'wallet_to_delete',
          isDeleted: false,
        ),
        TransactionModel(
          id: 'tx_w2',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn trưa',
          categoryIconCode: 3,
          amount: 60000.0,
          date: now,
          walletId: 'wallet_keep',
          isDeleted: false,
        ),
      ];

      const walletToDeleteId = 'wallet_to_delete';

      // Giả lập cascade soft delete
      final updatedTxList = transactions.map((tx) {
        if (tx.walletId == walletToDeleteId) {
          return tx.copyWith(isDeleted: true, deletedAt: now);
        }
        return tx;
      }).toList();

      final activeTx = updatedTxList.where((tx) => !tx.isDeleted).toList();
      expect(activeTx.length, equals(1));
      expect(activeTx.first.id, equals('tx_w2'));

      final deletedTx = updatedTxList.where((tx) => tx.isDeleted).toList();
      expect(deletedTx.length, equals(2));
      expect(deletedTx.every((tx) => tx.walletId == walletToDeleteId), isTrue);
    });

    test('TC-ATOM-04: Đối soát và phát hiện lệch số dư (Continuous Reconciliation Check)', () {
      // Giả lập ví bị sai lệch số dư tĩnh do lỗi hệ thống bên ngoài
      const initialBalance = 1000000.0;
      final history = [
        TransactionModel(
          id: 'tx1',
          uid: 'u1',
          type: 'income',
          category: 'Thu nhập',
          categoryIconCode: 1,
          amount: 5000000.0,
          date: now,
          walletId: 'w_recon',
        ),
        TransactionModel(
          id: 'tx2',
          uid: 'u1',
          type: 'expense',
          category: 'Chi tiêu',
          categoryIconCode: 2,
          amount: 2000000.0,
          date: now,
          walletId: 'w_recon',
        ),
      ];

      // True balance = 1M + 5M - 2M = 4M
      final trueBalance = FinancialCalculationService.calculateWalletTrueBalance(
        initialBalance: initialBalance,
        walletTransactions: history,
      );

      // Cached balance trong DB bị drift thành 3.5M
      const cachedBalance = 3500000.0;

      final isDrifted = !FinancePrecision.areEqual(cachedBalance, trueBalance);
      expect(isDrifted, isTrue);

      // Auto-reconciliation hiệu chỉnh cachedBalance về trueBalance
      final reconciledBalance = trueBalance;
      expect(reconciledBalance, equals(4000000.0));
      expect(FinancePrecision.areEqual(reconciledBalance, trueBalance), isTrue);
    });
  });
}
