import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../models/message_model.dart';

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
      syncStatus: 'pending',
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
  }

  Future<void> deleteMessage(String messageId) async {
    final uid = session.requireUid();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await deleteOwned(txn, 'messages', messageId, uid);
      await SyncQueueWriter.enqueue(
        txn,
        ownerUid: uid,
        table: 'messages',
        recordId: messageId,
        action: 'DELETE',
      );
    });

    _notifyChanged();
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

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final msg in messages) {
      if (msg.uid != currentUid) continue; // Bỏ qua doc khác uid
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
      _messagesController.add([]);
      return;
    }
    final db = await _dbHelper.database;
    final results = await db.query(
      'messages',
      where: 'uid = ?',
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
