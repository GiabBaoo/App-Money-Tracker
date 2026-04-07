import '../../data/models/debt_model.dart';

abstract class IDebtRepository {
  Future<DebtModel> create(DebtModel debt);
  Future<List<DebtModel>> getByGroupId(String groupId);
  Stream<List<DebtModel>> watchByGroupId(String groupId);
  Future<List<DebtModel>> getByUserId(String userId);
  Future<void> update(String id, DebtModel debt);
  Future<void> delete(String id);
  Future<void> deleteByGroupId(String groupId);
}
