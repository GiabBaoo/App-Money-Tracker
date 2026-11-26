import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../models/notification_model.dart';
import '../../services/sync_trigger.dart';

/// Repository quản lý thông báo — đọc/ghi từ SQLite.
/// SINGLETON: Đảm bảo badge chuông trên home_screen và notification_screen
/// đều lắng nghe cùng một stream — khi markAllAsRead(), badge tự mất.
class NotificationRepository with OwnedTableOps {
  static final NotificationRepository _instance =
      NotificationRepository._internal();
  factory NotificationRepository() => _instance;

  NotificationRepository._internal() {
    session.changes.listen((_) {
      _loadAndEmit();
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _notificationsController =
      StreamController<List<NotificationModel>>.broadcast();

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  // ════════ CRUD ════════

  Future<void> addNotification(NotificationModel notification) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = notification.id.isEmpty ? _uuid.v4() : notification.id;
    final now = DateTime.now();

    final noti = NotificationModel(
      id: id,
      uid: uid,
      iconCode: notification.iconCode,
      title: notification.title,
      description: notification.description,
      isRead: notification.isRead,
      createdAt: notification.createdAt,
      updatedAt: now,
      type: notification.type,
      groupId: notification.groupId,
      groupName: notification.groupName,
      status: notification.status,
      syncStatus: 'pending',
      isDeleted: false,
    );
    final row = stampOwner(noti.toSqlite(), uid);

    await db.transaction((txn) async {
      await txn.insert('notifications', row);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await updateOwned(txn, 'notifications', notificationId, {
        'isRead': 1,
        'updatedAt': now,
        'syncStatus': 'pending',
      }, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: notificationId,
        action: 'UPDATE',
        data: {'isRead': true, 'uid': uid, 'updatedAt': now},
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  Future<void> markAllAsRead() async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'notifications',
        {'isRead': 1, 'updatedAt': now, 'syncStatus': 'pending'},
        where: 'uid = ? AND isRead = 0 AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [uid],
      );

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: 'ALL',
        action: 'UPDATE_ALL_READ',
        data: {'uid': uid, 'updatedAt': now},
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  Future<void> deleteNotification(String notificationId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'notifications', notificationId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: notificationId,
        action: 'SOFT_DELETE',
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  // ════════ QUERIES ════════

  Stream<List<NotificationModel>> getNotificationsStream() {
    _loadAndEmit();
    return _notificationsController.stream;
  }

  // ════════ SYNC HELPERS ════════

  Future<void> upsertFromFirestore(
    List<NotificationModel> notifications,
  ) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || notifications.isEmpty) return;

    final ownedNotis = notifications
        .where((n) => n.uid == currentUid && n.id.isNotEmpty)
        .toList();
    if (ownedNotis.isEmpty) return;

    final db = await _dbHelper.database;
    var hasChanges = false;

    // Lấy tập hợp id các thông báo đã được đọc ở local để bảo toàn trạng thái offline-first
    final existingReadRows = await db.query(
      'notifications',
      columns: ['id'],
      where: 'uid = ? AND isRead = 1',
      whereArgs: [currentUid],
    );
    final readIds = existingReadRows.map((r) => r['id'] as String).toSet();

    await db.transaction((txn) async {
      final queueRows = await txn.query(
        'sync_queue',
        columns: ['recordId'],
        where:
            'tableName = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
        whereArgs: [
          'notifications',
          currentUid,
          currentUid,
          'pending',
          'processing',
        ],
      );
      final pendingIds = <String>{
        for (final r in queueRows)
          if (r['recordId'] is String) r['recordId'] as String,
      };

      final existingById = <String, Map<String, Object?>>{};
      final ids = ownedNotis.map((n) => n.id).toSet().toList();
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          i + chunkSize > ids.length ? ids.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          'notifications',
          where: 'uid = ? AND id IN ($placeholders)',
          whereArgs: [currentUid, ...chunk],
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id != null) existingById[id] = row;
        }
      }

      final batch = txn.batch();
      for (final noti in ownedNotis) {
        if (pendingIds.contains(noti.id)) continue;

        final existingRow = existingById[noti.id];
        final bool effectivelyRead = noti.isRead || readIds.contains(noti.id);

        if (existingRow == null) {
          if (!noti.isDeleted) {
            batch.insert(
              'notifications',
              NotificationModel(
                id: noti.id,
                uid: currentUid,
                iconCode: noti.iconCode,
                title: noti.title,
                description: noti.description,
                isRead: effectivelyRead,
                createdAt: noti.createdAt,
                updatedAt: noti.updatedAt,
                type: noti.type,
                groupId: noti.groupId,
                groupName: noti.groupName,
                status: noti.status,
                syncStatus: 'synced',
                isDeleted: false,
              ).toSqlite(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            hasChanges = true;
          }
        } else {
          final local = NotificationModel.fromSqlite(existingRow);
          if (local.syncStatus == 'pending') continue;

          // Monotonic Delete Rule
          if (local.isDeleted && !noti.isDeleted) {
            final localDeletedMs = local.deletedAt?.millisecondsSinceEpoch ??
                (local.updatedAt ?? local.createdAt).millisecondsSinceEpoch;
            final remoteUpdatedMs =
                (noti.updatedAt ?? noti.createdAt).millisecondsSinceEpoch;
            if (remoteUpdatedMs <= localDeletedMs) {
              continue;
            }
          }

          if (noti.isDeleted) {
            final remoteDeletedMs = noti.deletedAt?.millisecondsSinceEpoch ??
                (noti.updatedAt ?? noti.createdAt).millisecondsSinceEpoch;
            batch.update(
              'notifications',
              {
                'isDeleted': 1,
                'deletedAt': remoteDeletedMs,
                'updatedAt': remoteDeletedMs,
                'syncStatus': 'synced',
              },
              where: 'id = ? AND uid = ?',
              whereArgs: [noti.id, currentUid],
            );
          } else {
            batch.update(
              'notifications',
              NotificationModel(
                id: noti.id,
                uid: currentUid,
                iconCode: noti.iconCode,
                title: noti.title,
                description: noti.description,
                isRead: effectivelyRead,
                createdAt: noti.createdAt,
                updatedAt: noti.updatedAt,
                type: noti.type,
                groupId: noti.groupId,
                groupName: noti.groupName,
                status: noti.status,
                syncStatus: 'synced',
                isDeleted: false,
              ).toSqlite(),
              where: 'id = ? AND uid = ?',
              whereArgs: [noti.id, currentUid],
            );
          }
          hasChanges = true;
        }
      }

      if (hasChanges) {
        await batch.commit(noResult: true);
      }
    });

    if (hasChanges) {
      await _loadAndEmit();
    }
  }

  // ════════ INTERNAL ════════

  Future<void> _loadAndEmit() async {
    final uid = session.uidOrNull;
    if (uid == null) {
      _notificationsController.add([]);
      return;
    }
    final db = await _dbHelper.database;
    final results = await db.query(
      'notifications',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );
    final list = results
        .map((row) => NotificationModel.fromSqlite(row))
        .toList();
    _notificationsController.add(list);
  }

  void _notifyChanged() {
    _loadAndEmit();
  }

  Future<void> updateStatus(String notificationId, String status) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await updateOwned(txn, 'notifications', notificationId, {
        'status': status,
        'updatedAt': now,
        'syncStatus': 'pending',
      }, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: notificationId,
        action: 'UPDATE',
        data: {'status': status, 'uid': uid, 'updatedAt': now},
      );
    });
    _notifyChanged();
    SyncTrigger.requestSync();
  }

  Future<NotificationModel?> getById(String notificationId) async {
    final uid = session.uidOrNull;
    if (uid == null) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'notifications',
      where: 'id = ? AND uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [notificationId, uid],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return NotificationModel.fromSqlite(rows.first);
    }
    return null;
  }

  void dispose() {
    _notificationsController.close();
  }
}
