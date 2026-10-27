import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../data/local/database_helper.dart';
import '../../../../data/local/sync_queue_writer.dart';
import '../../domain/repositories/i_settlement_repository.dart';
import '../dtos/create_settlement_dto.dart';
import '../models/settlement_model.dart';

class SqliteSettlementRepository implements ISettlementRepository {
  final DatabaseHelper _dbHelper;
  final _changeController = StreamController<void>.broadcast();

  SqliteSettlementRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<SettlementModel> create(CreateSettlementDto dto) async {
    final db = await _dbHelper.database;
    final id = const Uuid().v4();
    final now = DateTime.now();

    final settlement = SettlementModel(
      id: id,
      groupId: dto.groupId,
      payerId: dto.payerId,
      payeeId: dto.payeeId,
      amount: dto.amount,
      status: SettlementStatus.pendingConfirmation,
      notes: dto.notes,
      proofPhotoUrl: dto.proofPhotoUrl,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('group_settlements', settlement.toSqflite());
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: dto.payerId,
        table: 'group_settlements',
        recordId: id,
        action: 'INSERT',
        data: settlement.toJson(),
      );
    });

    _changeController.add(null);
    return settlement;
  }

  @override
  Future<SettlementModel> getById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'group_settlements',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Settlement not found');
    return SettlementModel.fromSqflite(rows.first);
  }

  @override
  Future<List<SettlementModel>> getByGroupId(String groupId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'group_settlements',
      where: 'groupId = ? AND isDeleted = 0',
      whereArgs: [groupId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => SettlementModel.fromSqflite(r)).toList();
  }

  @override
  Stream<List<SettlementModel>> watchByGroupId(String groupId) {
    late StreamController<List<SettlementModel>> controller;

    void updateList() async {
      try {
        final list = await getByGroupId(groupId);
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
    controller = StreamController<List<SettlementModel>>.broadcast(
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
  Future<void> updateStatus(String id, SettlementStatus status) async {
    final settlement = await getById(id);
    final activeUid = SessionManager.instance.uidOrNull ?? settlement.payeeId;
    final db = await _dbHelper.database;
    final now = DateTime.now();

    String statusStr;
    switch (status) {
      case SettlementStatus.pendingConfirmation:
        statusStr = 'pending_confirmation';
        break;
      case SettlementStatus.confirmed:
        statusStr = 'confirmed';
        break;
      case SettlementStatus.rejected:
        statusStr = 'rejected';
        break;
    }

    final data = <String, dynamic>{
      'status': statusStr,
      'updatedAt': now.toUtc().millisecondsSinceEpoch,
      if (status == SettlementStatus.confirmed)
        'confirmedAt': now.toUtc().millisecondsSinceEpoch,
    };

    await db.transaction((txn) async {
      await txn.update(
        'group_settlements',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: activeUid,
        table: 'group_settlements',
        recordId: id,
        action: 'UPDATE',
        data: data,
      );
    });

    _changeController.add(null);
  }

  @override
  Future<void> delete(String id) async {
    final settlement = await getById(id);
    final activeUid = SessionManager.instance.uidOrNull ?? settlement.payerId;
    final db = await _dbHelper.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'group_settlements',
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
        ownerUid: activeUid,
        table: 'group_settlements',
        recordId: id,
        action: 'DELETE',
        data: {'id': id, 'isDeleted': 1},
      );
    });

    _changeController.add(null);
  }
}
