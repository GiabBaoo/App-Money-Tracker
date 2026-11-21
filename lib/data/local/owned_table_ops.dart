import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';

/// Helper giải quyết xung đột chuẩn hóa giữa Local và Remote
class ConflictResolver {
  const ConflictResolver._();

  /// Quyết định xem bản ghi Remote có nên ghi đè bản ghi Local hay không
  /// 1. Nếu remote.updatedAt > local.updatedAt -> Remote thắng
  /// 2. Nếu local.updatedAt > remote.updatedAt -> Local thắng
  /// 3. Nếu remote.updatedAt == local.updatedAt -> So sánh chuỗi băm Canonical JSON SHA-256
  static bool shouldRemoteWin({
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
  }) {
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) return true;
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) return false;
    return resolveTieBreaker(localData, remoteData);
  }

  /// Deterministic SHA-256 Tie-Breaker: bảo đảm mọi thiết bị phân xử giống hệt nhau
  static bool resolveTieBreaker(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final cleanLocal = _canonicalizeMap(local);
    final cleanRemote = _canonicalizeMap(remote);
    final localHash = sha256.convert(utf8.encode(cleanLocal)).toString();
    final remoteHash = sha256.convert(utf8.encode(cleanRemote)).toString();
    return remoteHash.compareTo(localHash) >= 0;
  }

  static String _canonicalizeMap(Map<String, dynamic> map) {
    final copy = Map<String, dynamic>.from(map);
    copy.remove('syncStatus');
    copy.remove('photoLocalPath');
    copy.remove('avatarLocalPath');
    final sortedKeys = copy.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final k in sortedKeys) {
      sortedMap[k] = copy[k];
    }
    return json.encode(sortedMap);
  }
}

mixin OwnedTableOps {
  SessionManager get session => SessionManager.instance;

  /// Đảm bảo timestamp cập nhật luôn tịnh tiến về phía trước ngay cả khi đồng hồ hệ thống bị chỉnh lùi
  int nextMonotonicTimestamp(int? previousUpdatedAtMs) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (previousUpdatedAtMs != null && nowMs <= previousUpdatedAtMs) {
      return previousUpdatedAtMs + 1;
    }
    return nowMs;
  }

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
    final existing = await findOwned(db, table, id, uid);
    final previousUpdated = existing != null ? (existing['updatedAt'] as int?) : null;
    final now = nextMonotonicTimestamp(previousUpdated);

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
