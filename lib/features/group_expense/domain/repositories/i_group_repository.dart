import '../../data/dtos/create_group_dto.dart';
import '../../data/dtos/update_group_dto.dart';
import '../../data/models/group_model.dart';

abstract class IGroupRepository {
  Future<GroupModel> create(CreateGroupDto dto, String adminId);
  Future<GroupModel> getById(String id);
  Future<List<GroupModel>> getByUserId(String userId);
  Stream<List<GroupModel>> watchByUserId(String userId);
  Future<void> update(String id, UpdateGroupDto dto);
  Future<void> delete(String id);
  Future<void> addMember(String groupId, String userId);
  Future<void> removeMember(String groupId, String userId);
}
