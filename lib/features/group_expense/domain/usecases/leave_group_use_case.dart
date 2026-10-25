import '../../../../core/errors/business_exception.dart';
import '../../data/models/settlement_model.dart';
import '../repositories/i_group_repository.dart';
import '../repositories/i_settlement_repository.dart';
import '../services/debt_calculator.dart';

class LeaveGroupUseCase {
  final IGroupRepository _groupRepository;
  final DebtCalculator _debtCalculator;
  final ISettlementRepository _settlementRepository;

  LeaveGroupUseCase({
    required IGroupRepository groupRepository,
    required DebtCalculator debtCalculator,
    required ISettlementRepository settlementRepository,
  }) : _groupRepository = groupRepository,
       _debtCalculator = debtCalculator,
       _settlementRepository = settlementRepository;

  Future<void> execute({
    required String groupId,
    required String userId,
    required String requesterId,
  }) async {
    final group = await _groupRepository.getById(groupId);
    if (userId == group.ownerId || userId == group.adminId) {
      throw const BusinessException(
        BusinessErrorCode.permissionDenied,
        'Không thể xóa hoặc rời nhóm khi đang là chủ nhóm',
      );
    }
    if (userId != requesterId &&
        requesterId != group.ownerId &&
        requesterId != group.adminId) {
      throw const BusinessException(
        BusinessErrorCode.permissionDenied,
        'Chỉ chủ nhóm mới có thể xóa thành viên khác',
      );
    }

    await _debtCalculator.recalculateDebts(groupId);
    final debts = await _debtCalculator.getGroupDebts(groupId);
    final userBalance = _debtCalculator.getUserBalance(debts, userId);
    if (userBalance.abs() > 0.5) {
      if (userBalance < 0) {
        throw const BusinessException(
          BusinessErrorCode.cannotLeaveWithDebt,
          'Thành viên còn nợ nhóm. Cần thanh toán hết trước khi rời nhóm.',
        );
      } else {
        throw const BusinessException(
          BusinessErrorCode.cannotLeaveWithCredit,
          'Nhóm còn nợ thành viên. Cần thu hồi nợ trước khi rời nhóm.',
        );
      }
    }

    final settlements = await _settlementRepository.getByGroupId(groupId);
    final hasPending = settlements.any(
      (s) =>
          !s.isDeleted &&
          s.status == SettlementStatus.pendingConfirmation &&
          (s.payerId == userId || s.payeeId == userId),
    );
    if (hasPending) {
      throw const BusinessException(
        BusinessErrorCode.pendingSettlementExists,
        'Còn giao dịch quyết toán đang chờ xác nhận. Vui lòng hoàn tất trước.',
      );
    }

    await _groupRepository.removeMember(groupId, userId);
  }
}
