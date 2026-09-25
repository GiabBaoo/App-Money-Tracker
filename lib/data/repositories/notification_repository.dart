import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/notification_model.dart';

/// Repository quản lý thông báo — đọc/ghi từ SQLite.
/// SINGLETON: Đảm bảo badge chuông trên home_screen và notification_screen
/// đều lắng nghe cùng một stream — khi markAllAsRead(), badge tự mất.
class NotificationRepository {
  static final NotificationRepository _instance = NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _notificationsController = StreamController<List<NotificationModel>>.broadcast();

  String? _currentUid;

  void setUid(String uid) {
    _currentUid = uid;
  }

  // ════════ CRUD ════════

  Future<void> addNotification(NotificationModel notification) async {
    final db = await _dbHelper.database;
    final id = notification.id.isEmpty ? _uuid.v4() : notification.id;

    final noti = NotificationModel(
      id: id,
      uid: notification.uid,
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

    await db.insert('notifications', noti.toSqlite());
    await _enqueueSyncAction('notifications', id, 'INSERT', noti.toSqlite());

    _notifyChanged();
  }

  Future<void> markAsRead(String notificationId) async {
    final db = await _dbHelper.database;
    await db.update(
      'notifications',
      {'isRead': 1, 'syncStatus': 'pending'},
      where: 'id = ?',
      whereArgs: [notificationId],
    );

    await _enqueueSyncAction('notifications', notificationId, 'UPDATE', {'isRead': true});

    _notifyChanged();
  }

  Future<void> markAllAsRead() async {
    final db = await _dbHelper.database;
    final uid = _currentUid;
    if (uid == null) return;

    await db.update(
      'notifications',
      {'isRead': 1, 'syncStatus': 'pending'},
      where: 'uid = ? AND isRead = 0',
      whereArgs: [uid],
    );

    await _enqueueSyncAction('notifications', 'ALL', 'UPDATE_ALL_READ', {'uid': uid});
    _notifyChanged();
  }

  // ════════ QUERIES ════════

  Stream<List<NotificationModel>> getNotificationsStream() {
    _loadAndEmit();
    return _notificationsController.stream;
  }

  // ════════ SYNC HELPERS ════════

  Future<void> upsertFromFirestore(List<NotificationModel> notifications) async {
    final db = await _dbHelper.database;

    // Lấy tập hợp id các thông báo đã được đọc ở local để bảo toàn trạng thái offline-first
    final existingReadRows = await db.query(
      'notifications',
      columns: ['id'],
      where: 'isRead = 1',
    );
    final readIds = existingReadRows.map((r) => r['id'] as String).toSet();

    final batch = db.batch();
    for (final noti in notifications) {
      // Nếu ở local đã đọc, luôn bảo tồn isRead = true để tránh bị dữ liệu cũ trên Cloud ghi đè
      final bool effectivelyRead = noti.isRead || readIds.contains(noti.id);

      batch.insert(
        'notifications',
        NotificationModel(
          id: noti.id,
          uid: noti.uid,
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
    if (_currentUid == null) {
      _notificationsController.add([]);
      return;
    }
    final db = await _dbHelper.database;
    final results = await db.query(
      'notifications',
      where: 'uid = ?',
      whereArgs: [_currentUid],
      orderBy: 'createdAt DESC',
    );
    final list = results.map((row) => NotificationModel.fromSqlite(row)).toList();
    _notificationsController.add(list);
  }

  void _notifyChanged() {
    _loadAndEmit();
  }

  Future<void> _enqueueSyncAction(String table, String recordId, String action, Map<String, dynamic>? data) async {
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'tableName': table,
      'recordId': recordId,
      'action': action,
      'data': data != null ? json.encode(data) : null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });
  }

  void dispose() {
    _notificationsController.close();
  }
}
