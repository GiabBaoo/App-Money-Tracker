import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../models/message_model.dart';
import '../../services/sync_trigger.dart';

/// Repository quản lý tin nhắn hỗ trợ — đọc/ghi từ SQLite.
class MessageRepository with OwnedTableOps {
  static final MessageRepository _instance = MessageRepository._internal();
  factory MessageRepository() => _instance;

  MessageRepository._internal() {
    session.changes.listen((_) {
      _loadAndEmit();
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _messagesController = StreamController<List<MessageModel>>.broadcast();

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  // ════════ CRUD ════════

  Future<void> addMessage(MessageModel message) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;
    final id = message.id.isEmpty ? _uuid.v4() : message.id;
    final now = DateTime.now();

    final msg = MessageModel(
      id: id,
      uid: uid,
      iconCode: message.iconCode,
      iconBgColorValue: message.iconBgColorValue,
      title: message.title,
      shortMessage: message.shortMessage,
      fullMessage: message.fullMessage,
      isUnread: message.isUnread,
      createdAt: message.createdAt,
      updatedAt: now,
      syncStatus: 'pending',
      isDeleted: false,
    );
    final row = stampOwner(msg.toSqlite(), uid);

    await db.transaction((txn) async {
      await txn.insert('messages', row);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'messages',
        recordId: id,
        action: 'INSERT',
        data: row,
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  Future<void> deleteMessage(String messageId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await softDeleteOwned(txn, 'messages', messageId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'messages',
        recordId: messageId,
        action: 'SOFT_DELETE',
      );
    });

    _notifyChanged();
    SyncTrigger.requestSync();
  }

  // ════════ QUERIES ════════

  Stream<List<MessageModel>> getMessagesStream() {
    _loadAndEmit();
    return _messagesController.stream;
  }

  // ════════ SYNC HELPERS ════════

  Future<void> upsertFromFirestore(List<MessageModel> messages) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || messages.isEmpty) return;

    final ownedMsgs = messages
        .where((m) => m.uid == currentUid && m.id.isNotEmpty)
        .toList();
    if (ownedMsgs.isEmpty) return;

    final db = await _dbHelper.database;
    var hasChanges = false;

    await db.transaction((txn) async {
      final queueRows = await txn.query(
        'sync_queue',
        columns: ['recordId'],
        where:
            'tableName = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
        whereArgs: ['messages', currentUid, currentUid, 'pending', 'processing'],
      );
      final pendingIds = <String>{
        for (final r in queueRows)
          if (r['recordId'] is String) r['recordId'] as String,
      };

      final existingById = <String, Map<String, Object?>>{};
      final ids = ownedMsgs.map((m) => m.id).toSet().toList();
      const chunkSize = 450;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          i + chunkSize > ids.length ? ids.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          'messages',
          where: 'uid = ? AND id IN ($placeholders)',
          whereArgs: [currentUid, ...chunk],
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id != null) existingById[id] = row;
        }
      }

      final batch = txn.batch();
      for (final msg in ownedMsgs) {
        if (pendingIds.contains(msg.id)) continue;

        final existingRow = existingById[msg.id];
        if (existingRow == null) {
          if (!msg.isDeleted) {
            batch.insert(
              'messages',
              MessageModel(
                id: msg.id,
                uid: currentUid,
                iconCode: msg.iconCode,
                iconBgColorValue: msg.iconBgColorValue,
                title: msg.title,
                shortMessage: msg.shortMessage,
                fullMessage: msg.fullMessage,
                isUnread: msg.isUnread,
                createdAt: msg.createdAt,
                updatedAt: msg.updatedAt,
                syncStatus: 'synced',
                isDeleted: false,
              ).toSqlite(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            hasChanges = true;
          }
        } else {
          final local = MessageModel.fromSqlite(existingRow);
          if (local.syncStatus == 'pending') continue;

          // Monotonic Delete Rule
          if (local.isDeleted && !msg.isDeleted) {
            final localDeletedMs = local.deletedAt?.millisecondsSinceEpoch ??
                (local.updatedAt ?? local.createdAt).millisecondsSinceEpoch;
            final remoteUpdatedMs =
                (msg.updatedAt ?? msg.createdAt).millisecondsSinceEpoch;
            if (remoteUpdatedMs <= localDeletedMs) {
              continue;
            }
          }

          if (msg.isDeleted) {
            final remoteDeletedMs = msg.deletedAt?.millisecondsSinceEpoch ??
                (msg.updatedAt ?? msg.createdAt).millisecondsSinceEpoch;
            batch.update(
              'messages',
              {
                'isDeleted': 1,
                'deletedAt': remoteDeletedMs,
                'updatedAt': remoteDeletedMs,
                'syncStatus': 'synced',
              },
              where: 'id = ? AND uid = ?',
              whereArgs: [msg.id, currentUid],
            );
          } else {
            batch.update(
              'messages',
              MessageModel(
                id: msg.id,
                uid: currentUid,
                iconCode: msg.iconCode,
                iconBgColorValue: msg.iconBgColorValue,
                title: msg.title,
                shortMessage: msg.shortMessage,
                fullMessage: msg.fullMessage,
                isUnread: msg.isUnread,
                createdAt: msg.createdAt,
                updatedAt: msg.updatedAt,
                syncStatus: 'synced',
                isDeleted: false,
              ).toSqlite(),
              where: 'id = ? AND uid = ?',
              whereArgs: [msg.id, currentUid],
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
      _messagesController.add([]);
      return;
    }
    final db = await _dbHelper.database;
    final results = await db.query(
      'messages',
      where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );
    final list = results.map((row) => MessageModel.fromSqlite(row)).toList();
    _messagesController.add(list);
  }

  void _notifyChanged() {
    _loadAndEmit();
  }

  void dispose() {
    _messagesController.close();
  }
}
