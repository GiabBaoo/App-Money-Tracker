import '../../../../core/errors/business_exception.dart';
import '../../data/dtos/create_settlement_dto.dart';
import '../../data/models/settlement_model.dart';
import '../repositories/i_debt_repository.dart';
import '../repositories/i_settlement_repository.dart';
import '../services/debt_calculator.dart';

class SettleGroupDebtUseCase {
  final ISettlementRepository _settlementRepository;
  final IDebtRepository _debtRepository;
  final DebtCalculator _debtCalculator;

  SettleGroupDebtUseCase({
    required ISettlementRepository settlementRepository,
    required IDebtRepository debtRepository,
    required DebtCalculator debtCalculator,
  }) : _settlementRepository = settlementRepository,
       _debtRepository = debtRepository,
       _debtCalculator = debtCalculator;

  Future<SettlementModel> createSettlement(
    CreateSettlementDto dto,
    String requesterId,
  ) async {
    if (dto.payerId != requesterId) {
      throw const BusinessException(
        BusinessErrorCode.permissionDenied,
        'Chỉ người trả tiền mới có thể tạo yêu cầu thanh toán',
      );
    }
    if (dto.amount <= 0) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền thanh toán phải lớn hơn 0',
      );
    }

    final debts = await _debtRepository.getByGroupId(dto.groupId);
    final relevantDebt = debts
        .where((d) => d.debtorId == dto.payerId && d.creditorId == dto.payeeId)
        .firstOrNull;

    if (relevantDebt == null) {
      throw const BusinessException(
        BusinessErrorCode.notFound,
        'Không tìm thấy khoản nợ tương ứng giữa hai thành viên',
      );
    }

    if (dto.amount > relevantDebt.amount + 1.0) {
      throw const BusinessException(
        BusinessErrorCode.invalidAmount,
        'Số tiền thanh toán vượt quá số nợ',
      );
    }

    return await _settlementRepository.create(dto);
  }

  Future<void> confirmSettlement(String settlementId, String userId) async {
    final settlement = await _settlementRepository.getById(settlementId);
    if (settlement.payeeId != userId) {
      throw const BusinessException(
        BusinessErrorCode.permissionDenied,
        'Chỉ người nhận tiền mới có thể xác nhận thanh toán',
      );
    }
    if (settlement.status != SettlementStatus.pendingConfirmation) {
      throw const BusinessException(
        BusinessErrorCode.settlementAlreadyProcessed,
        'Giao dịch thanh toán đã được xử lý trước đó',
      );
    }
    await _settlementRepository.updateStatus(
      settlementId,
      SettlementStatus.confirmed,
    );
    await _debtCalculator.recalculateDebts(settlement.groupId);
  }

  Future<void> rejectSettlement(String settlementId, String userId) async {
    final settlement = await _settlementRepository.getById(settlementId);
    if (settlement.payeeId != userId) {
      throw const BusinessException(
        BusinessErrorCode.permissionDenied,
        'Chỉ người nhận tiền mới có thể từ chối thanh toán',
      );
    }
    if (settlement.status != SettlementStatus.pendingConfirmation) {
      throw const BusinessException(
        BusinessErrorCode.settlementAlreadyProcessed,
        'Giao dịch thanh toán đã được xử lý trước đó',
      );
    }
    await _settlementRepository.updateStatus(
      settlementId,
      SettlementStatus.rejected,
    );
  }
}
