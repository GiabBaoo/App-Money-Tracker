import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/settlement_model.dart';
import '../repositories/i_debt_repository.dart';
import '../repositories/i_settlement_repository.dart';
import 'debt_calculator.dart';

class SettlementService {
  final ISettlementRepository _settlementRepository;
  final IDebtRepository _debtRepository;
  final DebtCalculator _debtCalculator;

  SettlementService(
    this._settlementRepository,
    this._debtRepository,
    this._debtCalculator,
  );

  Future<SettlementModel> createSettlement(CreateSettlementDto dto, String requesterId) async {
    if (dto.payerId != requesterId) {
      throw Exception('Chỉ người trả tiền mới có thể tạo thanh toán');
    }

    if (dto.amount <= 0) {
      throw Exception('Số tiền phải lớn hơn 0');
    }

    final debts = await _debtRepository.getByGroupId(dto.groupId);
    final relevantDebt = debts.where((d) => 
      d.debtorId == dto.payerId && d.creditorId == dto.payeeId
    ).firstOrNull;

    if (relevantDebt == null) {
      throw Exception('Không tìm thấy khoản nợ tương ứng');
    }

    if (dto.amount > relevantDebt.amount) {
      throw Exception('Số tiền thanh toán vượt quá số nợ');
    }

    return await _settlementRepository.create(dto);
  }

  Future<void> confirmSettlement(String settlementId, String userId) async {
    final settlement = await _settlementRepository.getById(settlementId);
    
    if (settlement.payeeId != userId) {
      throw Exception('Chỉ người nhận tiền mới có thể xác nhận');
    }

    if (settlement.status != SettlementStatus.pendingConfirmation) {
      throw Exception('Thanh toán đã được xử lý');
    }

    await _settlementRepository.updateStatus(settlementId, SettlementStatus.confirmed);
    
    await _debtCalculator.recalculateDebts(settlement.groupId);
  }

  Future<void> rejectSettlement(String settlementId, String userId) async {
    final settlement = await _settlementRepository.getById(settlementId);
    
    if (settlement.payeeId != userId) {
      throw Exception('Chỉ người nhận tiền mới có thể từ chối');
    }

    if (settlement.status != SettlementStatus.pendingConfirmation) {
      throw Exception('Thanh toán đã được xử lý');
    }

    await _settlementRepository.updateStatus(settlementId, SettlementStatus.rejected);
  }

  Future<List<SettlementModel>> getGroupSettlements(String groupId) async {
    return await _settlementRepository.getByGroupId(groupId);
  }

  Stream<List<SettlementModel>> watchGroupSettlements(String groupId) {
    return _settlementRepository.watchByGroupId(groupId);
  }

  Future<void> deleteSettlement(String settlementId, String userId) async {
    final settlement = await _settlementRepository.getById(settlementId);
    
    if (settlement.payerId != userId) {
      throw Exception('Chỉ người tạo mới có thể xóa thanh toán');
    }

    if (settlement.status == SettlementStatus.confirmed) {
      throw Exception('Không thể xóa thanh toán đã xác nhận');
    }

    await _settlementRepository.delete(settlementId);
  }
}
