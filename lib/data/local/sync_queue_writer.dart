import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/business_exception.dart';
import '../../core/session/session_manager.dart';

class SyncQueueWriter {
  const SyncQueueWriter._();

  /// Đệ quy làm sạch dữ liệu để tương thích 100% với json.encode()
  /// Chuyển đổi Timestamp (Firestore) và DateTime thành int millisecondsSinceEpoch UTC.
  static dynamic sanitizeValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.toUtc().millisecondsSinceEpoch;
    }
    if (value is Map) {
      final sanitizedMap = <String, dynamic>{};
      value.forEach((k, v) {
        sanitizedMap[k.toString()] = sanitizeValue(v);
      });
      return sanitizedMap;
    }
    if (value is List) {
      return value.map((item) => sanitizeValue(item)).toList();
    }
    return value;
  }

  static Map<String, dynamic>? sanitizeMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    return sanitizeValue(data) as Map<String, dynamic>?;
  }

  /// Xác định độ ưu tiên upload theo tầng phụ thuộc thực thể
  /// Tier 1: Thực thể gốc (users, wallets, groups) -> priority = 1
  /// Tier 2: Thực thể cấu hình & thành phần (group_members, budgets, goals) -> priority = 2
  /// Tier 3: Thực thể sổ cái & nhật ký (transactions, group_expenses, expense_splits, group_settlements, notifications, messages) -> priority = 3
  static int defaultPriorityForTable(String table) {
    switch (table) {
      case 'users':
      case 'wallets':
      case 'groups':
        return 1;
      case 'group_members':
      case 'budgets':
      case 'goals':
        return 2;
      case 'transactions':
      case 'group_expenses':
      case 'expense_splits':
      case 'group_settlements':
      case 'notifications':
      case 'messages':
        return 3;
      default:
        return 2;
    }
  }

  static Future<void> enqueue(
    DatabaseExecutor exec, {
    required String ownerUid,
    required String table,
    required String recordId,
    required String
    action, // INSERT | UPDATE | DELETE | SOFT_DELETE | UPDATE_ALL_READ
    Map<String, Object?>? data,
    int? priority,
    String? idempotencyKey,
  }) async {
    if (!SessionManager.isValidUid(ownerUid)) {
      throw BusinessException(
        BusinessErrorCode.invalidUid,
        'ownerUid không hợp lệ: "$ownerUid"',
      );
    }
    if (data != null) {
      if (data.containsKey('uid') && data['uid'] != ownerUid) {
        throw const BusinessException(
          BusinessErrorCode.ownershipViolation,
          'payload.uid ≠ ownerUid',
        );
      }
      if (data.containsKey('createdBy') && data['createdBy'] != ownerUid) {
        throw const BusinessException(
          BusinessErrorCode.ownershipViolation,
          'payload.createdBy ≠ ownerUid',
        );
      }
      if (action == 'INSERT' &&
          data.containsKey('ownerId') &&
          data['ownerId'] != ownerUid) {
        throw const BusinessException(
          BusinessErrorCode.ownershipViolation,
          'payload.ownerId ≠ ownerUid',
        );
      }
    }

    final sanitizedData = sanitizeMap(
      data != null ? Map<String, dynamic>.from(data) : null,
    );
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final effectivePriority = priority ?? defaultPriorityForTable(table);

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
            // Hợp nhất payload mới vào bản ghi INSERT đang chờ
            Map<String, dynamic> mergedData = {};
            final existingRaw = existing['data'] as String?;
            if (existingRaw != null) {
              try {
                mergedData = json.decode(existingRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
            if (sanitizedData != null) {
              mergedData.addAll(sanitizedData);
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
            // Hợp nhất payload mới vào payload cũ (không làm mất các trường đã cập nhật trước đó)
            Map<String, dynamic> mergedData = {};
            final existingRaw = existing['data'] as String?;
            if (existingRaw != null) {
              try {
                mergedData = json.decode(existingRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
            if (sanitizedData != null) {
              mergedData.addAll(sanitizedData);
            }
            await exec.update(
              'sync_queue',
              {
                'data': json.encode(mergedData),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          } else if (action == 'DELETE') {
            // Chuyển action thành DELETE và cập nhật payload nếu có
            await exec.update(
              'sync_queue',
              {
                'action': 'DELETE',
                if (sanitizedData != null) 'data': json.encode(sanitizedData),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          } else if (action == 'SOFT_DELETE') {
            // Chuyển action thành SOFT_DELETE và gắn tombstone
            Map<String, dynamic> mergedData = {};
            final existingRaw = existing['data'] as String?;
            if (existingRaw != null) {
              try {
                mergedData = json.decode(existingRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
            mergedData['isDeleted'] = 1;
            mergedData['deletedAt'] = now;
            mergedData['updatedAt'] = now;
            if (sanitizedData != null) {
              mergedData.addAll(sanitizedData);
            }
            await exec.update(
              'sync_queue',
              {
                'action': 'SOFT_DELETE',
                'data': json.encode(mergedData),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
            return;
          }
        } else if (existingAction == 'SOFT_DELETE' || existingAction == 'DELETE') {
          if (action == 'UPDATE' || action == 'INSERT') {
            // Khôi phục bản ghi (Undo delete)
            Map<String, dynamic> mergedData = {};
            final existingRaw = existing['data'] as String?;
            if (existingRaw != null) {
              try {
                mergedData = json.decode(existingRaw) as Map<String, dynamic>;
              } catch (_) {}
            }
            mergedData['isDeleted'] = 0;
            mergedData.remove('deletedAt');
            mergedData['updatedAt'] = now;
            if (sanitizedData != null) {
              mergedData.addAll(sanitizedData);
            }
            await exec.update(
              'sync_queue',
              {
                'action': 'UPDATE',
                'data': json.encode(mergedData),
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
      'data': sanitizedData == null ? null : json.encode(sanitizedData),
      'createdAt': now,
      'updatedAt': now,
      'retryCount': 0,
      'nextRetryAt': 0,
      'status': 'pending',
      'priority': effectivePriority,
      'idempotencyKey': idempotencyKey,
    });
  }
}
