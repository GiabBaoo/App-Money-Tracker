import 'package:uuid/uuid.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/settlement_model.dart';
import '../repositories/i_debt_repository.dart';
import '../repositories/i_expense_repository.dart';
import '../repositories/i_settlement_repository.dart';

class DebtCalculator {
  final IExpenseRepository _expenseRepository;
  final IDebtRepository _debtRepository;
  final ISettlementRepository? _settlementRepository;

  DebtCalculator(
    this._expenseRepository,
    this._debtRepository, [
    this._settlementRepository,
  ]);

  /// Tính toán lại toàn bộ công nợ nhóm, tích hợp CẢ KHOẢN CHI VÀ KHOẢN QUYẾT TOÁN ĐÃ XÁC NHẬN.
  /// Tuân thủ Bất biến GRP-I2: Bảo Toàn Công Nợ Ròng (Zero-Sum Debt Conservation).
  Future<void> recalculateDebts(String groupId) async {
    await _debtRepository.deleteByGroupId(groupId);

    final expenses = await _expenseRepository.getByGroupId(groupId);
    final repo = _settlementRepository;
    final settlements = repo != null
        ? await repo.getByGroupId(groupId)
        : <SettlementModel>[];

    final netBalances = calculateNetBalances(expenses, settlements);
    final debts = optimizeDebtsFromBalances(netBalances, groupId: groupId);

    for (var debt in debts) {
      await _debtRepository.create(debt);
    }
  }

  /// Tính toán công nợ ròng (NetBalance) cho từng thành viên:
  /// NetBalance_u = PaidAsPayer_u - ShareAsParticipant_u + SettlementPaid_u - SettlementReceived_u
  Map<String, int> calculateNetBalances(
    List<ExpenseModel> expenses,
    List<SettlementModel> settlements,
  ) {
    final balances = <String, int>{};

    // 1. Cộng trừ từ các khoản chi tiêu nhóm (loại trừ đã xóa mềm)
    for (var expense in expenses) {
      if (expense.isDeleted) continue;

      final amount = expense.amountVnd;
      balances[expense.payerId] = (balances[expense.payerId] ?? 0) + amount;

      for (var entry in expense.shares.entries) {
        final participantId = entry.key;
        final share = entry.value.round();
        balances[participantId] = (balances[participantId] ?? 0) - share;
      }
    }

    // 2. Giảm trừ từ các khoản quyết toán đã xác nhận (confirmed settlements)
    for (var settlement in settlements) {
      if (settlement.isDeleted) continue;
      if (settlement.status != SettlementStatus.confirmed) continue;

      final amount = settlement.amountVnd;
      // Payer đã trả tiền nợ -> Net balance của Payer tăng (nợ giảm bớt)
      balances[settlement.payerId] =
          (balances[settlement.payerId] ?? 0) + amount;
      // Payee đã nhận tiền -> Net balance của Payee giảm (đã thu hồi bớt)
      balances[settlement.payeeId] =
          (balances[settlement.payeeId] ?? 0) - amount;
    }

    return balances;
  }

  /// Thuật toán tối giản công nợ tham lam (Greedy Debt Simplification)
  List<DebtModel> optimizeDebtsFromBalances(
    Map<String, int> balances, {
    String groupId = '',
  }) {
    final debts = <DebtModel>[];
    final creditors = <String, int>{};
    final debtors = <String, int>{};

    for (var entry in balances.entries) {
      if (entry.value > 0) {
        creditors[entry.key] = entry.value;
      } else if (entry.value < 0) {
        debtors[entry.key] = -entry.value;
      }
    }

    // Sắp xếp giảm dần theo số tiền
    final creditorList = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtorList = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int i = 0, j = 0;
    final now = DateTime.now();

    while (i < creditorList.length && j < debtorList.length) {
      final creditorId = creditorList[i].key;
      final creditorAmount = creditorList[i].value;
      final debtorId = debtorList[j].key;
      final debtorAmount = debtorList[j].value;

      final settleAmount = creditorAmount < debtorAmount
          ? creditorAmount
          : debtorAmount;

      if (settleAmount > 0) {
        debts.add(
          DebtModel(
            id: const Uuid().v4(),
            groupId: groupId,
            debtorId: debtorId,
            creditorId: creditorId,
            amount: settleAmount.toDouble(),
            status: DebtStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      creditorList[i] = MapEntry(creditorId, creditorAmount - settleAmount);
      debtorList[j] = MapEntry(debtorId, debtorAmount - settleAmount);

      if (creditorList[i].value <= 0) i++;
      if (debtorList[j].value <= 0) j++;
    }

    return debts;
  }

  Future<List<DebtModel>> getGroupDebts(String groupId) async {
    return await _debtRepository.getByGroupId(groupId);
  }

  Stream<List<DebtModel>> watchGroupDebts(String groupId) {
    return _debtRepository.watchByGroupId(groupId);
  }

  Future<List<DebtModel>> getUserDebts(String userId) async {
    return await _debtRepository.getByUserId(userId);
  }

  double getUserBalance(List<DebtModel> debts, String userId) {
    double balance = 0;
    for (var debt in debts) {
      if (debt.creditorId == userId) {
        balance += debt.amount;
      } else if (debt.debtorId == userId) {
        balance -= debt.amount;
      }
    }
    return balance;
  }
}
