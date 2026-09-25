import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../../models/message_model.dart';

/// Repository quản lý tin nhắn hỗ trợ — đọc/ghi từ SQLite.
class MessageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  final _messagesController = StreamController<List<MessageModel>>.broadcast();

  String? _currentUid;

  void setUid(String uid) {
    _currentUid = uid;
  }

  // ════════ CRUD ════════

  Future<void> addMessage(MessageModel message) async {
    final db = await _dbHelper.database;
    final id = message.id.isEmpty ? _uuid.v4() : message.id;

    final msg = MessageModel(
      id: id,
      uid: message.uid,
      iconCode: message.iconCode,
      iconBgColorValue: message.iconBgColorValue,
      title: message.title,
      shortMessage: message.shortMessage,
      fullMessage: message.fullMessage,
      isUnread: message.isUnread,
      createdAt: message.createdAt,
      syncStatus: 'pending',
    );

    await db.insert('messages', msg.toSqlite());
    await _enqueueSyncAction('messages', id, 'INSERT', msg.toSqlite());
    _notifyChanged();
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await _dbHelper.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    await _enqueueSyncAction('messages', messageId, 'DELETE', null);
    _notifyChanged();
  }

  // ════════ QUERIES ════════

  Stream<List<MessageModel>> getMessagesStream() {
    _loadAndEmit();
    return _messagesController.stream;
  }

  // ════════ SYNC HELPERS ════════

  Future<void> upsertFromFirestore(List<MessageModel> messages) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final msg in messages) {
      batch.insert(
        'messages',
        MessageModel(
          id: msg.id,
          uid: msg.uid,
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
    if (_currentUid == null) {
      _messagesController.add([]);
      return;
    }
    final db = await _dbHelper.database;
    final results = await db.query(
      'messages',
      where: 'uid = ?',
      whereArgs: [_currentUid],
      orderBy: 'createdAt DESC',
    );
    final list = results.map((row) => MessageModel.fromSqlite(row)).toList();
    _messagesController.add(list);
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
    _messagesController.close();
  }
}
