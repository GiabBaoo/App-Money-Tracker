import '../../data/dtos/create_expense_dto.dart';
import '../../data/models/expense_model.dart';

abstract class IExpenseRepository {
  Future<ExpenseModel> create(CreateExpenseDto dto, String createdBy);
  Future<ExpenseModel> getById(String id);
  Future<List<ExpenseModel>> getByGroupId(String groupId);
  Stream<List<ExpenseModel>> watchByGroupId(String groupId);
  Future<void> delete(String id);
}
