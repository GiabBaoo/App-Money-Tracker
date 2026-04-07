import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/settlement_model.dart';

abstract class ISettlementRepository {
  Future<SettlementModel> create(CreateSettlementDto dto);
  Future<SettlementModel> getById(String id);
  Future<List<SettlementModel>> getByGroupId(String groupId);
  Stream<List<SettlementModel>> watchByGroupId(String groupId);
  Future<void> updateStatus(String id, SettlementStatus status);
  Future<void> delete(String id);
}
