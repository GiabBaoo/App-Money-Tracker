import '../../data/dtos/create_group_dto.dart';
import '../../data/dtos/update_group_dto.dart';
import '../../data/models/group_model.dart';
import '../../data/models/settlement_model.dart';
import '../repositories/i_group_repository.dart';
import '../repositories/i_settlement_repository.dart';
import 'debt_calculator.dart';

class GroupService {
  final IGroupRepository _repository;
  final DebtCalculator? _debtCalculator;
  final ISettlementRepository? _settlementRepository;

  GroupService(
    this._repository, [
    this._debtCalculator,
    this._settlementRepository,
  ]);

  Future<GroupModel> createGroup(CreateGroupDto dto, String adminId) async {
    if (dto.name.trim().isEmpty) {
      throw Exception('Tên nhóm không được để trống');
    }
    return await _repository.create(dto, adminId);
  }

  Future<GroupModel> getGroup(String id) async {
    return await _repository.getById(id);
  }

  Future<List<GroupModel>> getUserGroups(String userId) async {
    return await _repository.getByUserId(userId);
  }

  Stream<List<GroupModel>> watchUserGroups(String userId) {
    return _repository.watchByUserId(userId);
  }

  Future<void> updateGroup(String id, UpdateGroupDto dto, String userId) async {
    final group = await _repository.getById(id);
    if (group.ownerId != userId && group.adminId != userId) {
      throw Exception('Chỉ admin mới có thể cập nhật nhóm');
    }
    await _repository.update(id, dto);
  }

  Future<void> deleteGroup(String id, String userId) async {
    final group = await _repository.getById(id);
    if (group.ownerId != userId && group.adminId != userId) {
      throw Exception('Chỉ admin mới có thể xóa nhóm');
    }
    await _repository.delete(id);
  }

  Future<void> addMember(
    String groupId,
    String memberId,
    String requesterId,
  ) async {
    final group = await _repository.getById(groupId);
    if (group.ownerId != requesterId && group.adminId != requesterId) {
      throw Exception('Chỉ admin mới có thể thêm thành viên');
    }
    if (group.memberIds.contains(memberId)) {
      throw Exception('Thành viên đã có trong nhóm');
    }
    await _repository.addMember(groupId, memberId);
  }

  Future<void> removeMember(
    String groupId,
    String memberId,
    String requesterId,
  ) async {
    final group = await _repository.getById(groupId);

    // Nếu admin muốn xóa bản thân
    if (memberId == group.ownerId || memberId == group.adminId) {
      throw Exception('Không thể xóa chủ nhóm/admin khỏi nhóm');
    }

    // Phải là chính thành viên đó (tự rời) hoặc admin của nhóm (xóa thành viên)
    if (memberId != requesterId &&
        group.ownerId != requesterId &&
        group.adminId != requesterId) {
      throw Exception('Chỉ admin mới có thể xóa thành viên khác');
    }

    // Bất biến GRP-I3: Kiểm tra công nợ ròng trước khi rời nhóm
    final debtCalc = _debtCalculator;
    if (debtCalc != null) {
      final debts = await debtCalc.getGroupDebts(groupId);
      final userBalance = debtCalc.getUserBalance(debts, memberId);
      if (userBalance.abs() > 0.5) {
        if (userBalance < 0) {
          throw Exception(
            'Thành viên còn nợ nhóm ${_formatMoney(userBalance.abs())}đ. Cần thanh toán hết trước khi rời nhóm.',
          );
        } else {
          throw Exception(
            'Nhóm còn nợ thành viên ${_formatMoney(userBalance)}đ. Cần thu hồi nợ trước khi rời nhóm.',
          );
        }
      }
    }

    // Kiểm tra có quyết toán pending không
    final settleRepo = _settlementRepository;
    if (settleRepo != null) {
      final settlements = await settleRepo.getByGroupId(groupId);
      final hasPending = settlements.any(
        (s) =>
            !s.isDeleted &&
            s.status == SettlementStatus.pendingConfirmation &&
            (s.payerId == memberId || s.payeeId == memberId),
      );
      if (hasPending) {
        throw Exception(
          'Còn giao dịch quyết toán đang chờ xác nhận. Vui lòng hoàn tất trước khi rời nhóm.',
        );
      }
    }

    await _repository.removeMember(groupId, memberId);
  }

  String _formatMoney(double amount) {
    return amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  bool isAdmin(GroupModel group, String userId) {
    return group.ownerId == userId || group.adminId == userId;
  }

  bool isMember(GroupModel group, String userId) {
    return group.memberIds.contains(userId);
  }
}
