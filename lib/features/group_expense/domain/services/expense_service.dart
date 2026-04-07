import '../../data/dtos/create_expense_dto.dart';
import '../../data/models/expense_model.dart';
import '../repositories/i_expense_repository.dart';
import '../repositories/i_group_repository.dart';
import 'debt_calculator.dart';

class ExpenseService {
  final IExpenseRepository _expenseRepository;
  final IGroupRepository _groupRepository;
  final DebtCalculator _debtCalculator;

  ExpenseService(
    this._expenseRepository,
    this._groupRepository,
    this._debtCalculator,
  );

  Future<ExpenseModel> createExpense(CreateExpenseDto dto, String createdBy) async {
    final group = await _groupRepository.getById(dto.groupId);
    
    if (!group.memberIds.contains(createdBy)) {
      throw Exception('Bạn không phải thành viên của nhóm này');
    }

    if (!group.memberIds.contains(dto.payerId)) {
      throw Exception('Người trả tiền phải là thành viên của nhóm');
    }

    for (var participantId in dto.participantIds) {
      if (!group.memberIds.contains(participantId)) {
        throw Exception('Tất cả người tham gia phải là thành viên của nhóm');
      }
    }

    if (dto.amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0');
    }

    if (dto.splitMethod == SplitMethod.custom && dto.customShares != null) {
      final totalShares = dto.customShares!.values.reduce((a, b) => a + b);
      if ((totalShares - dto.amount).abs() > 0.01) {
        throw Exception('Tổng chia không khớp với số tiền');
      }
    }

    final expense = await _expenseRepository.create(dto, createdBy);
    
    await _debtCalculator.recalculateDebts(dto.groupId);
    
    return expense;
  }

  Future<List<ExpenseModel>> getGroupExpenses(String groupId) async {
    return await _expenseRepository.getByGroupId(groupId);
  }

  Stream<List<ExpenseModel>> watchGroupExpenses(String groupId) {
    return _expenseRepository.watchByGroupId(groupId);
  }

  Future<void> deleteExpense(String expenseId, String userId) async {
    final expense = await _expenseRepository.getById(expenseId);
    final group = await _groupRepository.getById(expense.groupId);
    
    if (expense.createdBy != userId && group.adminId != userId) {
      throw Exception('Chỉ người tạo hoặc admin mới có thể xóa chi tiêu');
    }

    await _expenseRepository.delete(expenseId);
    await _debtCalculator.recalculateDebts(expense.groupId);
  }

  Map<String, double> calculateEqualSplit(double amount, List<String> participantIds) {
    final shareAmount = amount / participantIds.length;
    return {for (var id in participantIds) id: shareAmount};
  }
}
