import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';

class SyncQueueWriter {
  const SyncQueueWriter._();

  static Future<void> enqueue(
    DatabaseExecutor exec, {
    required String ownerUid,
    required String table,
    required String recordId,
    required String
    action, // INSERT | UPDATE | DELETE | SOFT_DELETE | UPDATE_ALL_READ
    Map<String, Object?>? data,
  }) async {
    if (!SessionManager.isValidUid(ownerUid)) {
      throw BusinessException(
        BusinessErrorCode.invalidUid,
        'ownerUid không hợp lệ: "$ownerUid"',
      );
    }
    if (data != null && data.containsKey('uid') && data['uid'] != ownerUid) {
      throw const BusinessException(
        BusinessErrorCode.ownershipViolation,
        'payload.uid ≠ ownerUid',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    // Coalescing (Hợp nhất tác vụ) cho cùng một recordId đang ở status 'pending'
    if (action != 'UPDATE_ALL_READ') {
      final pendingRows = await exec.query(
        'sync_queue',
        where:
            'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status = ?',
        whereArgs: [table, recordId, ownerUid, ownerUid, 'pending'],
        limit: 1,
      );

      if (pendingRows.isNotEmpty) {
        final existing = pendingRows.first;
        final existingId = existing['id'];
        final existingAction = existing['action'] as String;

        if (existingAction == 'INSERT') {
          if (action == 'UPDATE') {
            // Hợp nhất payload mới vào bản ghi INSERT
            Map<String, dynamic> mergedData = {};
            final existingRaw = existing['data'] as String?;
            if (existingRaw != null) {
              try {
                mergedData = json.decode(existingRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
            if (data != null) {
              mergedData.addAll(data);
            }
            await exec.update(
              'sync_queue',
              {'data': json.encode(mergedData), 'updatedAt': now},
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          } else if (action == 'DELETE' || action == 'SOFT_DELETE') {
            // Bản ghi được tạo và xóa ngay lúc offline, chưa từng đẩy lên Cloud -> Triệt tiêu luôn!
            await exec.delete(
              'sync_queue',
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          }
        } else if (existingAction == 'UPDATE') {
          if (action == 'UPDATE') {
            // Cập nhật payload mới nhất
            await exec.update(
              'sync_queue',
              {
                'data': data == null ? null : json.encode(data),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          } else if (action == 'DELETE' || action == 'SOFT_DELETE') {
            // Chuyển action thành SOFT_DELETE hoặc DELETE
            await exec.update(
              'sync_queue',
              {
                'action': action,
                'data': data == null ? null : json.encode(data),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          }
        }
      }
    }

    await exec.insert('sync_queue', {
      'uid': ownerUid,
      'ownerUid': ownerUid,
      'tableName': table,
      'recordId': recordId,
      'action': action,
      'data': data == null ? null : json.encode(data),
      'createdAt': now,
      'updatedAt': now,
      'retryCount': 0,
      'nextRetryAt': 0,
      'status': 'pending',
    });
  }
}
