import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/local/sync_queue_writer.dart';
import '../../domain/repositories/i_group_repository.dart';
import '../dtos/create_group_dto.dart';
import '../dtos/update_group_dto.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

class SqliteGroupRepository implements IGroupRepository {
  final DatabaseHelper _dbHelper;
  final _changeController = StreamController<void>.broadcast();

  SqliteGroupRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<GroupModel> create(CreateGroupDto dto, String adminId) async {
    final db = await _dbHelper.database;
    final id = const Uuid().v4();
    final now = DateTime.now();

    final allMemberIds = {adminId, ...dto.memberIds}.toList();

    final group = GroupModel(
      id: id,
      name: dto.name,
      description: dto.description,
      iconUrl: dto.iconUrl,
      iconCode: dto.iconCode,
      ownerId: adminId,
      memberIds: allMemberIds,
      groupType: dto.groupType,
      currency: 'VND',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('groups', group.toSqflite());

      for (final memberId in allMemberIds) {
        final memberModel = GroupMemberModel(
          id: const Uuid().v4(),
          groupId: id,
          userId: memberId,
          role: memberId == adminId ? 'owner' : 'member',
          joinedAt: now,
          status: 'active',
          updatedAt: now,
        );
        await txn.insert('group_members', memberModel.toSqflite());
      }

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: adminId,
        table: 'groups',
        recordId: id,
        action: 'INSERT',
        data: group.toJson(),
      );
    });

    _changeController.add(null);
    return group;
  }

  @override
  Future<GroupModel> getById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'groups',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Group not found');

    final memberRows = await db.query(
      'group_members',
      columns: ['userId'],
      where: 'groupId = ? AND status = "active"',
      whereArgs: [id],
    );
    final memberIds = memberRows.map((r) => r['userId'] as String).toList();

    return GroupModel.fromSqflite(rows.first, members: memberIds);
  }

  @override
  Future<List<GroupModel>> getByUserId(String userId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT g.* FROM groups g
      INNER JOIN group_members gm ON g.id = gm.groupId
      WHERE gm.userId = ? AND gm.status = 'active' AND g.isDeleted = 0
      ORDER BY g.updatedAt DESC
      ''',
      [userId],
    );

    final groups = <GroupModel>[];
    for (final row in rows) {
      final gId = row['id'] as String;
      final memberRows = await db.query(
        'group_members',
        columns: ['userId'],
        where: 'groupId = ? AND status = "active"',
        whereArgs: [gId],
      );
      final memberIds = memberRows.map((r) => r['userId'] as String).toList();
      groups.add(GroupModel.fromSqflite(row, members: memberIds));
    }

    return groups;
  }

  @override
  Stream<List<GroupModel>> watchByUserId(String userId) {
    late StreamController<List<GroupModel>> controller;

    void updateList() async {
      try {
        final list = await getByUserId(userId);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    StreamSubscription? sub;
    controller = StreamController<List<GroupModel>>.broadcast(
      onListen: () {
        updateList();
        sub = _changeController.stream.listen((_) => updateList());
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> update(String id, UpdateGroupDto dto) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final data = <String, dynamic>{
      if (dto.name != null) 'name': dto.name,
      if (dto.description != null) 'description': dto.description,
      if (dto.iconUrl != null) 'iconUrl': dto.iconUrl,
      if (dto.iconCode != null) 'iconCode': dto.iconCode,
      if (dto.groupType != null) 'groupType': dto.groupType,
      'updatedAt': now.toUtc().millisecondsSinceEpoch,
    };

    await db.transaction((txn) async {
      await txn.update('groups', data, where: 'id = ?', whereArgs: [id]);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: '',
        table: 'groups',
        recordId: id,
        action: 'UPDATE',
        data: data,
      );
    });

    _changeController.add(null);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'groups',
        {
          'isDeleted': 1,
          'deletedAt': now.toUtc().millisecondsSinceEpoch,
          'updatedAt': now.toUtc().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: '',
        table: 'groups',
        recordId: id,
        action: 'DELETE',
        data: {'id': id, 'isDeleted': 1},
      );
    });

    _changeController.add(null);
  }

  @override
  Future<void> addMember(String groupId, String userId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      final existing = await txn.query(
        'group_members',
        where: 'groupId = ? AND userId = ?',
        whereArgs: [groupId, userId],
      );

      if (existing.isNotEmpty) {
        await txn.update(
          'group_members',
          {
            'status': 'active',
            'leftAt': null,
            'updatedAt': now.toUtc().millisecondsSinceEpoch,
          },
          where: 'groupId = ? AND userId = ?',
          whereArgs: [groupId, userId],
        );
      } else {
        final member = GroupMemberModel(
          id: const Uuid().v4(),
          groupId: groupId,
          userId: userId,
          role: 'member',
          joinedAt: now,
          status: 'active',
          updatedAt: now,
        );
        await txn.insert('group_members', member.toSqflite());
      }

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: userId,
        table: 'group_members',
        recordId: '${groupId}_$userId',
        action: 'INSERT',
        data: {'groupId': groupId, 'userId': userId, 'status': 'active'},
      );
    });

    _changeController.add(null);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'group_members',
        {
          'status': 'left',
          'leftAt': now.toUtc().millisecondsSinceEpoch,
          'updatedAt': now.toUtc().millisecondsSinceEpoch,
        },
        where: 'groupId = ? AND userId = ?',
        whereArgs: [groupId, userId],
      );

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: userId,
        table: 'group_members',
        recordId: '${groupId}_$userId',
        action: 'UPDATE',
        data: {'groupId': groupId, 'userId': userId, 'status': 'left'},
      );
    });

    _changeController.add(null);
  }

  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'group_members',
      where: 'groupId = ? AND status = "active"',
      whereArgs: [groupId],
    );
    return rows.map((r) => GroupMemberModel.fromSqflite(r)).toList();
  }
}
