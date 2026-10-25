import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local/database_helper.dart';
import '../local/owned_table_ops.dart';
import '../local/sync_queue_writer.dart';
import '../../core/errors/business_exception.dart';
import '../../models/user_model.dart';

/// Repository quản lý thông tin người dùng — đọc/ghi từ SQLite (Singleton).
class UserRepository with OwnedTableOps {
  static final UserRepository _instance = UserRepository._internal();
  factory UserRepository() => _instance;

  UserRepository._internal() {
    session.changes.listen((_) {
      _cachedUser = null;
      _notifyUserChanged();
      if (session.uidOrNull != null) {
        getUser();
      }
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();

  final _changeStream = StreamController<void>.broadcast();

  static UserModel? _cachedUser;
  UserModel? get currentUser => _cachedUser;

  String? get currentUid => session.uidOrNull;

  @Deprecated('UID lấy từ SessionManager; không còn tác dụng')
  void setUid(String uid) {
    assert(
      uid == session.uidOrNull,
      'setUid($uid) lệch phiên ${session.uidOrNull}',
    );
  }

  // ════════ USER CRUD ════════

  /// Lưu/cập nhật thông tin user vào SQLite
  Future<void> saveUser(UserModel user) async {
    final uid = session.requireUid();
    if (user.uid != uid) {
      throw const BusinessException(
        BusinessErrorCode.ownershipViolation,
        'user.uid khác phiên hiện tại',
      );
    }
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
    final uid = session.requireUid();
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

    await db.update('users', sqliteData, where: 'uid = ?', whereArgs: [uid]);

    // Enqueue sync
    await SyncQueueWriter.enqueue(
      db,
      ownerUid: uid,
      table: 'users',
      recordId: uid,
      action: 'UPDATE',
      data: data,
    );

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
    final uid = session.uidOrNull;
    if (uid == null) return null; // fail-closed READ: xóa fallback limit: 1

    final db = await _dbHelper.database;
    final results = await db.query('users', where: 'uid = ?', whereArgs: [uid]);
    if (results.isNotEmpty) {
      final user = UserModel.fromSqlite(results.first);
      _cachedUser = user;
      return user;
    }

    // Tự động kéo từ Firestore nếu SQLite chưa có bản ghi (ví dụ: máy mới, sau khi đăng nhập)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final user = UserModel.fromFirestore(doc);
        if (user.uid == uid) {
          await saveUser(user);
          return user;
        }
      }
    } catch (_) {}

    // Fallback an toàn từ FirebaseAuth đúng uid phiên
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid == uid) {
      final fallbackName =
          authUser.displayName != null &&
              authUser.displayName!.trim().isNotEmpty
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

  /// Tra cứu thông tin một người dùng theo UID (tìm SQLite trước, fallback Firestore)
  Future<UserModel?> getUserById(String targetUid) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [targetUid],
    );
    if (results.isNotEmpty) {
      return UserModel.fromSqlite(results.first);
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (_) {}
    return null;
  }

  /// Tìm kiếm user theo số điện thoại (tìm SQLite trước, fallback Firestore phone_index/users)
  Future<UserModel?> findUserByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'phone = ?',
      whereArgs: [cleanPhone],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return UserModel.fromSqlite(results.first);
    }

    try {
      final phoneDoc = await FirebaseFirestore.instance
          .collection('phone_index')
          .doc(cleanPhone)
          .get();
      if (phoneDoc.exists) {
        final uid = phoneDoc.data()?['uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          return await getUserById(uid);
        }
      }
    } catch (_) {}

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(snapshot.docs.first);
      }
    } catch (_) {}

    return null;
  }

  /// Cập nhật tùy chọn sử dụng dữ liệu
  Future<void> updateDataUsagePreference(String key, bool value) async {
    final uid = session.requireUid();
    final user = await getUser();
    if (user == null) return;

    final updatedUsage = Map<String, dynamic>.from(user.dataUsage);
    updatedUsage[key] = value;

    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'dataUsage': json.encode(updatedUsage), 'syncStatus': 'pending'},
      where: 'uid = ?',
      whereArgs: [uid],
    );

    await SyncQueueWriter.enqueue(
      db,
      ownerUid: uid,
      table: 'users',
      recordId: uid,
      action: 'UPDATE',
      data: {'dataUsage.$key': value},
    );

    _notifyUserChanged();
  }

  // ════════ SYNC HELPERS ════════

  /// Upsert user từ Firestore (dùng khi sync download)
  Future<void> upsertFromFirestore(UserModel user) async {
    final currentUid = session.uidOrNull;
    if (currentUid == null || user.uid != currentUid) return;

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
    final currentUid = session.uidOrNull;
    if (currentUid == null || uid != currentUid) return;

    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'syncStatus': 'synced'},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  // ════════ INTERNAL ════════

  void _notifyUserChanged() {
    _changeStream.add(null);
  }

  void dispose() {
    _changeStream.close();
  }
}
