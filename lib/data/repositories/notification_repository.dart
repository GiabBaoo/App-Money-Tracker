import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../models/notification_model.dart';

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

    final noti = NotificationModel(
      id: id,
      uid: uid,
      iconCode: notification.iconCode,
      title: notification.title,
      description: notification.description,
      isRead: notification.isRead,
      createdAt: notification.createdAt,
      type: notification.type,
      groupId: notification.groupId,
      groupName: notification.groupName,
      status: notification.status,
      syncStatus: 'pending',
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
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await updateOwned(txn, 'notifications', notificationId, {
        'isRead': 1,
        'syncStatus': 'pending',
      }, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: notificationId,
        action: 'UPDATE',
        data: {'isRead': true, 'uid': uid},
      );
    });

    _notifyChanged();
  }

  Future<void> markAllAsRead() async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.update(
        'notifications',
        {'isRead': 1, 'syncStatus': 'pending'},
        where: 'uid = ? AND isRead = 0',
        whereArgs: [uid],
      );

      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: 'ALL',
        action: 'UPDATE_ALL_READ',
        data: {'uid': uid},
      );
    });

    _notifyChanged();
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

    final db = await _dbHelper.database;

    // Lấy tập hợp id các thông báo đã được đọc ở local để bảo toàn trạng thái offline-first
    final existingReadRows = await db.query(
      'notifications',
      columns: ['id'],
      where: 'uid = ? AND isRead = 1',
      whereArgs: [currentUid],
    );
    final readIds = existingReadRows.map((r) => r['id'] as String).toSet();

    final batch = db.batch();
    for (final noti in notifications) {
      if (noti.uid != currentUid) continue; // Bỏ qua doc khác uid

      final bool effectivelyRead = noti.isRead || readIds.contains(noti.id);

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
          type: noti.type,
          groupId: noti.groupId,
          groupName: noti.groupName,
          status: noti.status,
          syncStatus: 'synced',
        ).toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notifyChanged();
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
      where: 'uid = ?',
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
    await db.transaction((txn) async {
      await updateOwned(txn, 'notifications', notificationId, {
        'status': status,
        'syncStatus': 'pending',
      }, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'notifications',
        recordId: notificationId,
        action: 'UPDATE',
        data: {'status': status, 'uid': uid},
      );
    });
    _notifyChanged();
  }

  Future<NotificationModel?> getById(String notificationId) async {
    final uid = session.uidOrNull;
    if (uid == null) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'notifications',
      where: 'id = ? AND uid = ?',
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
