import '../../data/dtos/create_group_dto.dart';
import '../../data/dtos/update_group_dto.dart';
import '../../data/models/group_model.dart';
import '../repositories/i_group_repository.dart';

class GroupService {
  final IGroupRepository _repository;

  GroupService(this._repository);

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
    if (group.adminId != userId) {
      throw Exception('Chỉ admin mới có thể cập nhật nhóm');
    }
    await _repository.update(id, dto);
  }

  Future<void> deleteGroup(String id, String userId) async {
    final group = await _repository.getById(id);
    if (group.adminId != userId) {
      throw Exception('Chỉ admin mới có thể xóa nhóm');
    }
    await _repository.delete(id);
  }

  Future<void> addMember(String groupId, String memberId, String requesterId) async {
    final group = await _repository.getById(groupId);
    if (group.adminId != requesterId) {
      throw Exception('Chỉ admin mới có thể thêm thành viên');
    }
    if (group.memberIds.contains(memberId)) {
      throw Exception('Thành viên đã có trong nhóm');
    }
    await _repository.addMember(groupId, memberId);
  }

  Future<void> removeMember(String groupId, String memberId, String requesterId) async {
    final group = await _repository.getById(groupId);
    
    // Nếu admin muốn xóa bản thân
    if (memberId == group.adminId) {
      throw Exception('Không thể xóa admin khỏi nhóm');
    }
    
    // Cho phép thành viên tự rời nhóm
    if (memberId == requesterId) {
      await _repository.removeMember(groupId, memberId);
      return;
    }
    
    // Chỉ admin mới có thể xóa thành viên khác
    if (group.adminId != requesterId) {
      throw Exception('Chỉ admin mới có thể xóa thành viên khác');
    }
    
    await _repository.removeMember(groupId, memberId);
  }

  bool isAdmin(GroupModel group, String userId) {
    return group.adminId == userId;
  }

  bool isMember(GroupModel group, String userId) {
    return group.memberIds.contains(userId);
  }
}
