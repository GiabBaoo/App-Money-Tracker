import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local/database_helper.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

/// Repository quản lý thông tin người dùng — đọc/ghi từ SQLite (Singleton).
class UserRepository {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;
  UserRepository._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  final _changeStream = StreamController<void>.broadcast();
  String? _explicitUid;

  static UserModel? _cachedUser;
  UserModel? get currentUser => _cachedUser;

  String? get _currentUid => _explicitUid ?? AuthService().currentUid;

  void setUid(String uid) {
    if (_explicitUid != uid) {
      _explicitUid = uid;
      _cachedUser = null;
      _notifyUserChanged();
      getUser(); // Tự động nạp user cho UID mới
    }
  }

  // ════════ USER CRUD ════════

  /// Lưu/cập nhật thông tin user vào SQLite
  Future<void> saveUser(UserModel user) async {
    _cachedUser = user;
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      user.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyUserChanged();
  }

  /// Cập nhật một số trường thông tin user
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (_currentUid == null) return;
    final db = await _dbHelper.database;

    // Chuyển đổi các trường đặc biệt cho SQLite
    final sqliteData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Map) {
        sqliteData[key] = json.encode(value);
      } else if (value is List) {
        sqliteData[key] = json.encode(value);
      } else if (value is DateTime) {
        sqliteData[key] = value.millisecondsSinceEpoch;
      } else {
        sqliteData[key] = value;
      }
    });
    sqliteData['syncStatus'] = 'pending';

    await db.update('users', sqliteData, where: 'uid = ?', whereArgs: [_currentUid]);

    // Enqueue sync
    await _enqueueSyncAction('users', _currentUid!, 'UPDATE', data);

    await getUser(); // Cập nhật lại _cachedUser
    _notifyUserChanged();
  }

  /// Cập nhật nhanh ảnh đại diện và phát tín hiệu cho toàn bộ UI tức thời
  Future<void> updateAvatar(String newUrl, {String? localPath}) async {
    final data = <String, dynamic>{
      'avatarUrl': newUrl,
      'avatarLocalPath': localPath ?? '',
    };
    await updateUserProfile(data);
  }

  /// Stream thông tin user
  Stream<UserModel?> getUserStream() async* {
    if (_cachedUser != null) {
      yield _cachedUser;
    }
    yield await getUser();
    yield* _changeStream.stream.asyncMap((_) => getUser());
  }

  /// Lấy thông tin user một lần
  Future<UserModel?> getUser() async {
    final uid = _currentUid;
    if (uid == null) return null;
    final db = await _dbHelper.database;
    final results = await db.query('users', where: 'uid = ?', whereArgs: [uid]);
    if (results.isNotEmpty) {
      final user = UserModel.fromSqlite(results.first);
      _cachedUser = user;
      return user;
    }

    // Tự động kéo từ Firestore nếu SQLite chưa có bản ghi (ví dụ: máy mới, sau khi đăng nhập)
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        await saveUser(user);
        return user;
      }
    } catch (_) {}

    // Fallback an toàn từ FirebaseAuth
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid == uid) {
      final fallbackName = authUser.displayName != null && authUser.displayName!.trim().isNotEmpty
          ? authUser.displayName!
          : (authUser.email?.split('@').first ?? 'Người dùng');
      final fallbackUser = UserModel(
        uid: authUser.uid,
        name: fallbackName,
        email: authUser.email ?? '',
        avatarUrl: authUser.photoURL ?? '',
      );
      await saveUser(fallbackUser);
      return fallbackUser;
    }

    return null;
  }

  /// Cập nhật tùy chọn sử dụng dữ liệu
  Future<void> updateDataUsagePreference(String key, bool value) async {
    if (_currentUid == null) return;
    final user = await getUser();
    if (user == null) return;

    final updatedUsage = Map<String, dynamic>.from(user.dataUsage);
    updatedUsage[key] = value;

    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'dataUsage': json.encode(updatedUsage),
        'syncStatus': 'pending',
      },
      where: 'uid = ?',
      whereArgs: [_currentUid],
    );

    await _enqueueSyncAction('users', _currentUid!, 'UPDATE', {'dataUsage.$key': value});

    _notifyUserChanged();
  }

  // ════════ SYNC HELPERS ════════

  /// Upsert user từ Firestore (dùng khi sync download)
  Future<void> upsertFromFirestore(UserModel user) async {
    _cachedUser = user;
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      user.toSqlite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyUserChanged();
  }

  /// Đánh dấu đã sync
  Future<void> markAsSynced(String uid) async {
    final db = await _dbHelper.database;
    await db.update('users', {'syncStatus': 'synced'}, where: 'uid = ?', whereArgs: [uid]);
  }

  // ════════ INTERNAL ════════

  void _notifyUserChanged() {
    _changeStream.add(null);
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
    _changeStream.close();
  }
}
