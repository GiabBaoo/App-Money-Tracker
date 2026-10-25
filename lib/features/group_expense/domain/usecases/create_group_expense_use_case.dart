import '../../../../core/errors/business_exception.dart';
import '../../data/dtos/create_expense_dto.dart';
import '../../data/models/expense_model.dart';
import '../repositories/i_expense_repository.dart';
import '../repositories/i_group_repository.dart';
import '../services/debt_calculator.dart';

class CreateGroupExpenseUseCase {
  final IExpenseRepository _expenseRepository;
  final IGroupRepository _groupRepository;
  final DebtCalculator _debtCalculator;

  CreateGroupExpenseUseCase({
    required IExpenseRepository expenseRepository,
    required IGroupRepository groupRepository,
    required DebtCalculator debtCalculator,
  }) : _expenseRepository = expenseRepository,
       _groupRepository = groupRepository,
       _debtCalculator = debtCalculator;

  Future<ExpenseModel> execute({
    required CreateExpenseDto dto,
    required String createdBy,
  }) async {
    final group = await _groupRepository.getById(dto.groupId);
    if (!group.memberIds.contains(createdBy)) {
      throw BusinessException(
        BusinessErrorCode.invalidMember,
        'Người tạo không thuộc nhóm',
      );
    }
    if (!group.memberIds.contains(dto.payerId)) {
      throw BusinessException(
        BusinessErrorCode.invalidMember,
        'Người trả tiền không thuộc nhóm',
      );
    }
    for (final p in dto.participantIds) {
      if (!group.memberIds.contains(p)) {
        throw BusinessException(
          BusinessErrorCode.invalidMember,
          'Người tham gia không thuộc nhóm',
        );
      }
    }
    if (dto.amount <= 0) {
      throw BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền chi tiêu phải lớn hơn 0',
      );
    }

    final expense = await _expenseRepository.create(dto, createdBy);
    await _debtCalculator.recalculateDebts(dto.groupId);
    return expense;
  }
}
