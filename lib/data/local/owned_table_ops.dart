import 'package:sqflite/sqflite.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';

mixin OwnedTableOps {
  SessionManager get session => SessionManager.instance;

  /// Gắn uid phiên vào row khi INSERT; throw nếu row mang uid lạ.
  Map<String, Object?> stampOwner(Map<String, Object?> row, String uid) {
    final given = row['uid'];
    if (given is String && given.isNotEmpty && given != uid) {
      throw const BusinessException(
        BusinessErrorCode.ownershipViolation,
        'Bản ghi thuộc tài khoản khác',
      );
    }
    return {...row, 'uid': uid};
  }

  Future<Map<String, Object?>?> findOwned(
    DatabaseExecutor db,
    String table,
    String id,
    String uid,
  ) async {
    final rows = await db.query(
      table,
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateOwned(
    DatabaseExecutor db,
    String table,
    String id,
    Map<String, Object?> values,
    String uid,
  ) async {
    final v = Map<String, Object?>.from(values)
      ..remove('id')
      ..remove('uid'); // I1: không bao giờ ghi cột uid trong UPDATE
    final n = await db.update(
      table,
      v,
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
    if (n != 1) {
      throw BusinessException(
        BusinessErrorCode.notFound,
        '$table/$id không tồn tại',
      );
    }
  }

  Future<void> deleteOwned(
    DatabaseExecutor db,
    String table,
    String id,
    String uid,
  ) async {
    final n = await db.delete(
      table,
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
    if (n != 1) {
      throw BusinessException(
        BusinessErrorCode.notFound,
        '$table/$id không tồn tại',
      );
    }
  }

  /// Xóa mềm bản ghi (Soft Delete / Tombstone) bảo vệ tính toàn vẹn đồng bộ
  Future<void> softDeleteOwned(
    DatabaseExecutor db,
    String table,
    String id,
    String uid,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final n = await db.update(
      table,
      {
        'isDeleted': 1,
        'deletedAt': now,
        'updatedAt': now,
        'syncStatus': 'pending',
      },
      where: 'id = ? AND uid = ?',
      whereArgs: [id, uid],
    );
    if (n != 1) {
      throw BusinessException(
        BusinessErrorCode.notFound,
        '$table/$id không tồn tại',
      );
    }
  }
}
