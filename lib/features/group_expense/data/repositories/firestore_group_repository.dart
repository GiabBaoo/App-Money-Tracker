import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/i_group_repository.dart';
import '../dtos/create_group_dto.dart';
import '../dtos/update_group_dto.dart';
import '../models/group_model.dart';

class FirestoreGroupRepository implements IGroupRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'groups';

  FirestoreGroupRepository(this._firestore);

  @override
  Future<GroupModel> create(CreateGroupDto dto, String adminId) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    
    final group = GroupModel(
      id: id,
      name: dto.name,
      description: dto.description,
      iconUrl: dto.iconUrl,
      iconCode: dto.iconCode,
      adminId: adminId,
      memberIds: [adminId, ...dto.memberIds],
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection(_collection).doc(id).set(group.toJson());
    return group;
  }

  @override
  Future<GroupModel> getById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw Exception('Group not found');
    return GroupModel.fromJson(doc.data()!);
  }

  @override
  Future<List<GroupModel>> getByUserId(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('memberIds', arrayContains: userId)
        .get();

    // Filter and sort on client side to avoid index requirement
    final groups = snapshot.docs
        .map((doc) => GroupModel.fromJson(doc.data()))
        .where((group) => group.isDeleted == false)
        .toList();
    
    groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return groups;
  }

  @override
  Stream<List<GroupModel>> watchByUserId(String userId) {
    return _firestore
        .collection(_collection)
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          // Filter and sort on client side to avoid index requirement
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromJson(doc.data()))
              .where((group) => group.isDeleted == false)
              .toList();
          
          groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return groups;
        });
  }

  @override
  Future<void> update(String id, UpdateGroupDto dto) async {
    final data = dto.toJson();
    data['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _firestore.collection(_collection).doc(id).update(data);
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      'isDeleted': true,
      'deletedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> addMember(String groupId, String userId) async {
    await _firestore.collection(_collection).doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _firestore.collection(_collection).doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
