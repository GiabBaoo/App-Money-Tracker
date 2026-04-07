import 'package:uuid/uuid.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/expense_model.dart';
import '../repositories/i_debt_repository.dart';
import '../repositories/i_expense_repository.dart';

class DebtCalculator {
  final IExpenseRepository _expenseRepository;
  final IDebtRepository _debtRepository;

  DebtCalculator(this._expenseRepository, this._debtRepository);

  Future<void> recalculateDebts(String groupId) async {
    await _debtRepository.deleteByGroupId(groupId);

    final expenses = await _expenseRepository.getByGroupId(groupId);
    
    final balances = <String, double>{};
    
    for (var expense in expenses) {
      balances[expense.payerId] = (balances[expense.payerId] ?? 0) + expense.amount;
      
      for (var entry in expense.shares.entries) {
        final participantId = entry.key;
        final share = entry.value;
        balances[participantId] = (balances[participantId] ?? 0) - share;
      }
    }

    final debts = _optimizeDebts(balances);
    
    for (var debt in debts) {
      await _debtRepository.create(debt.copyWith(groupId: groupId));
    }
  }

  List<DebtModel> _optimizeDebts(Map<String, double> balances) {
    final debts = <DebtModel>[];
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    for (var entry in balances.entries) {
      if (entry.value > 0.01) {
        creditors[entry.key] = entry.value;
      } else if (entry.value < -0.01) {
        debtors[entry.key] = -entry.value;
      }
    }

    final creditorList = creditors.entries.toList();
    final debtorList = debtors.entries.toList();

    int i = 0, j = 0;
    while (i < creditorList.length && j < debtorList.length) {
      final creditorId = creditorList[i].key;
      final creditorAmount = creditorList[i].value;
      final debtorId = debtorList[j].key;
      final debtorAmount = debtorList[j].value;

      final settleAmount = creditorAmount < debtorAmount ? creditorAmount : debtorAmount;

      debts.add(DebtModel(
        id: const Uuid().v4(),
        groupId: '',
        debtorId: debtorId,
        creditorId: creditorId,
        amount: settleAmount,
        status: DebtStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      creditorList[i] = MapEntry(creditorId, creditorAmount - settleAmount);
      debtorList[j] = MapEntry(debtorId, debtorAmount - settleAmount);

      if (creditorList[i].value < 0.01) i++;
      if (debtorList[j].value < 0.01) j++;
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
