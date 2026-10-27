import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/session/session_manager.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/message_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../models/message_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';

/// Interface khóa bất đồng bộ
abstract class ISyncLock {
  Future<bool> tryAcquire();
  void release();
  bool get isLocked;
}

/// Khóa bất đồng bộ trong bộ nhớ (In-Memory Mutex) chống async re-entrancy
class InMemorySyncLock implements ISyncLock {
  bool _isLocked = false;
  @override
  bool get isLocked => _isLocked;

  @override
  Future<bool> tryAcquire() async {
    if (_isLocked) return false;
    _isLocked = true;
    return true;
  }

  @override
  void release() {
    _isLocked = false;
  }
}

/// Alias cho tương thích ngược
class SyncLock extends InMemorySyncLock {}

enum SyncStatus { pending, processing, synced, failed, dead, quarantined }

enum SyncAction { insert, update, delete, softDelete, updateAllRead }

class SyncQueueItem {
  final int? id;
  final String uid;
  final String tableName;
  final String recordId;
  final String action;
  final Map<String, dynamic>? data;
  final String status;
  final int retryCount;
  final String? lastError;
  final int nextRetryAt;
  final int createdAt;
  final int updatedAt;

  SyncQueueItem({
    this.id,
    required this.uid,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.data,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastError,
    this.nextRetryAt = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toSqlite() {
    return {
      if (id != null) 'id': id,
      'uid': uid,
      'ownerUid': uid,
      'tableName': tableName,
      'recordId': recordId,
      'action': action,
      'data': data != null ? json.encode(data) : null,
      'status': status,
      'retryCount': retryCount,
      'lastError': lastError,
      'nextRetryAt': nextRetryAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SyncQueueItem.fromSqlite(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedData;
    final rawData = map['data'] as String?;
    if (rawData != null) {
      try {
        parsedData = json.decode(rawData) as Map<String, dynamic>;
      } catch (_) {}
    }
    return SyncQueueItem(
      id: map['id'] as int?,
      uid: (map['uid'] as String?)?.isNotEmpty == true
          ? map['uid'] as String
          : (map['ownerUid'] as String? ?? ''),
      tableName: map['tableName'] as String? ?? '',
      recordId: map['recordId'] as String? ?? '',
      action: map['action'] as String? ?? 'INSERT',
      data: parsedData,
      status: map['status'] as String? ?? 'pending',
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
      nextRetryAt: map['nextRetryAt'] as int? ?? 0,
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }
}

class EntitySyncResult {
  final String entityName;
  final bool isSuccess;
  final int itemsProcessed;
  final String? errorMessage;

  const EntitySyncResult({
    required this.entityName,
    required this.isSuccess,
    this.itemsProcessed = 0,
    this.errorMessage,
  });
}

class SyncExecutionReport {
  final DateTime executedAt;
  int uploadedCount;
  String? uploadError;
  final Map<String, int> downloadSuccess;
  final Map<String, String> downloadErrors;

  SyncExecutionReport({
    DateTime? executedAt,
    this.uploadedCount = 0,
    this.uploadError,
    Map<String, int>? downloadSuccess,
    Map<String, String>? downloadErrors,
  }) : executedAt = executedAt ?? DateTime.now(),
       downloadSuccess = downloadSuccess ?? {},
       downloadErrors = downloadErrors ?? {};

  bool get hasErrors => uploadError != null || downloadErrors.isNotEmpty;
  bool get isSuccess => !hasErrors;
}

abstract class ISyncService {
  void init({
    required TransactionRepository transactionRepo,
    required UserRepository userRepo,
    required NotificationRepository notificationRepo,
    required MessageRepository messageRepo,
    WalletRepository? walletRepo,
    BudgetRepository? budgetRepo,
    GoalRepository? goalRepo,
  });

  Future<bool> syncAll();
  Future<SyncExecutionReport> syncAllDetailed();
  Future<bool> syncSingleTransaction(String txId);
  Future<int> getPendingSyncCount();
  Future<int> getDeadCount();
  Future<List<Map<String, dynamic>>> getDeadLetterItems();
  Future<List<SyncQueueItem>> getDeadLetterItemsDetailed();
  Future<bool> retryDeadLetterItem(int queueId);
  Future<int> retryAllDeadLetters();
  void startRealtimeListeners();
  void stopRealtimeListeners();
  Future<void> quiesce({Duration timeout = const Duration(seconds: 5)});
  void dispose();
}

/// Service đồng bộ 2 chiều giữa SQLite (local) và Firestore (cloud).
///
/// Chiến lược P1:
/// - Khóa kép: In-Memory Mutex + Atomic Claim trong SQLite
/// - Upload: Đọc sync_queue lọc theo ownerUid/uid → Exponential Backoff + Dead-Letter Queue
/// - Download: Bulkhead Pattern (cô lập lỗi theo từng entity) + Local Dirty Shield
/// - Xóa: Tombstone Soft Delete đồng bộ xuyên thiết bị
class SyncService implements ISyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncLock _syncLock = SyncLock();

  TransactionRepository? _transactionRepo;
  WalletRepository? _walletRepo;
  UserRepository? _userRepo;
  NotificationRepository? _notificationRepo;
  MessageRepository? _messageRepo;
  BudgetRepository? _budgetRepo;
  GoalRepository? _goalRepo;

  StreamSubscription<bool>? _connectivitySubscription;
  final List<StreamSubscription> _firestoreSubscriptions = [];

  bool _isSyncing = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  SyncExecutionReport? _lastReport;

  Future<void>? _currentRun;
  bool _accepting = true;
  static const int _maxRetry = 8;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  SyncExecutionReport? get lastReport => _lastReport;

  /// Quiesce: dừng và chờ các tác vụ đồng bộ đang chạy khi đổi phiên/đăng xuất
  @override
  Future<void> quiesce({Duration timeout = const Duration(seconds: 5)}) async {
    _accepting = false;
    final run = _currentRun;
    if (run != null) {
      try {
        await run.timeout(timeout);
      } catch (_) {
        // epoch đã đổi nên vòng upload tự dừng
      }
    }
    _accepting = true;
  }

  /// Lấy số lượng thay đổi đang chờ đồng bộ của phiên hiện tại trong sync_queue
  @override
  Future<int> getPendingSyncCount() async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return 0;
    try {
      final db = await _dbHelper.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as count FROM sync_queue WHERE (uid = ? OR ownerUid = ?) AND status = 'pending'",
        [ownerUid, ownerUid],
      );
      return (res.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Lấy số lượng thay đổi bị lỗi vĩnh viễn (dead-letter) của phiên hiện tại
  @override
  Future<int> getDeadCount() async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return 0;
    try {
      final db = await _dbHelper.database;
      final res = await db.rawQuery(
        "SELECT COUNT(*) as count FROM sync_queue WHERE (uid = ? OR ownerUid = ?) AND status = 'dead'",
        [ownerUid, ownerUid],
      );
      return (res.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Lấy danh sách các tác vụ đang nằm trong Dead-Letter Queue
  @override
  Future<List<Map<String, dynamic>>> getDeadLetterItems() async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return [];
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'sync_queue',
        where: "(uid = ? OR ownerUid = ?) AND status = 'dead'",
        whereArgs: [ownerUid, ownerUid],
        orderBy: 'createdAt DESC',
      );
    } catch (_) {
      return [];
    }
  }

  /// Lấy danh sách chi tiết các bản ghi trong Dead-Letter Queue dạng Model
  @override
  Future<List<SyncQueueItem>> getDeadLetterItemsDetailed() async {
    final rows = await getDeadLetterItems();
    return rows.map((r) => SyncQueueItem.fromSqlite(r)).toList();
  }

  /// Kích hoạt thử lại 1 bản ghi cụ thể trong Dead-Letter Queue
  @override
  Future<bool> retryDeadLetterItem(int queueId) async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return false;
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final count = await db.update(
        'sync_queue',
        {
          'status': 'pending',
          'retryCount': 0,
          'nextRetryAt': 0,
          'updatedAt': now,
        },
        where: "id = ? AND (uid = ? OR ownerUid = ?) AND status = 'dead'",
        whereArgs: [queueId, ownerUid, ownerUid],
      );
      if (count > 0) {
        unawaited(syncAll());
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Thử lại toàn bộ các tác vụ trong Dead-Letter Queue
  @override
  Future<int> retryAllDeadLetters() async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return 0;
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final count = await db.update(
        'sync_queue',
        {
          'status': 'pending',
          'retryCount': 0,
          'nextRetryAt': 0,
          'updatedAt': now,
        },
        where: "(uid = ? OR ownerUid = ?) AND status = 'dead'",
        whereArgs: [ownerUid, ownerUid],
      );
      if (count > 0) {
        unawaited(syncAll());
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Khởi tạo SyncService với các repository
  @override
  void init({
    required TransactionRepository transactionRepo,
    required UserRepository userRepo,
    required NotificationRepository notificationRepo,
    required MessageRepository messageRepo,
    WalletRepository? walletRepo,
    BudgetRepository? budgetRepo,
    GoalRepository? goalRepo,
  }) {
    _transactionRepo = transactionRepo;
    _userRepo = userRepo;
    _notificationRepo = notificationRepo;
    _messageRepo = messageRepo;
    _walletRepo = walletRepo ?? WalletRepository();
    _budgetRepo = budgetRepo ?? BudgetRepository();
    _goalRepo = goalRepo ?? GoalRepository();
    _isInitialized = true;

    // Lắng nghe khi mạng khôi phục → tự động re-auth và sync toàn bộ nếu hợp lệ
    _connectivitySubscription = _connectivity.onlineStream.listen((
      isOnline,
    ) async {
      if (isOnline &&
          _isInitialized &&
          _accepting &&
          SessionManager.instance.uidOrNull != null) {
        debugPrint(
          'SyncService: Network restored, checking silent re-auth & syncing...',
        );
        if (FirebaseAuth.instance.currentUser == null) {
          await AuthService().silentReauthenticateIfNeeded();
        }
        unawaited(syncAll());
      }
    });
  }

  /// Đồng bộ ngay lập tức (alias của syncAll)
  Future<bool> syncNow() => syncAll();

  /// Đồng bộ toàn bộ dữ liệu kèm báo cáo chi tiết
  @override
  Future<SyncExecutionReport> syncAllDetailed() async {
    final report = SyncExecutionReport();
    if (!_accepting) {
      report.uploadError = 'SyncService is not accepting requests (quiesced).';
      return report;
    }

    // 1. In-Memory Mutex: chặn các luồng gọi trùng đồng thời
    final acquired = await _syncLock.tryAcquire();
    if (!acquired) {
      debugPrint(
        'SyncService: Another sync cycle is currently running, skipping concurrent trigger.',
      );
      report.uploadError = 'Another sync cycle is currently running.';
      return report;
    }

    try {
      // I3: fail-closed, kiểm tra phiên hợp lệ trước khi sync
      final session = SessionManager.instance;
      final ownerUid = session.uidOrNull;
      if (ownerUid == null) {
        report.uploadError = 'No valid session UID.';
        return report;
      }

      final run = _syncAllInternal(ownerUid, report);
      _currentRun = run;
      await run;
      _lastReport = report;
      return report;
    } finally {
      _syncLock.release();
    }
  }

  /// Đồng bộ toàn bộ dữ liệu với Khóa Mutex chống re-entrancy (trả về bool cho tương thích ngược)
  @override
  Future<bool> syncAll() async {
    final report = await syncAllDetailed();
    return !report.hasErrors;
  }

  /// Giữ tương thích API cũ: tải dữ liệu ban đầu
  Future<void> initialDownload() async {
    await syncAll();
  }

  Future<bool> _syncAllInternal(
    String ownerUid, [
    SyncExecutionReport? report,
  ]) async {
    final rep = report ?? SyncExecutionReport();

    // Tự động khởi tạo repositories nếu chưa có
    if (!_isInitialized) {
      _transactionRepo ??= TransactionRepository();
      _walletRepo ??= WalletRepository();
      _userRepo ??= UserRepository();
      _notificationRepo ??= NotificationRepository();
      _messageRepo ??= MessageRepository();
      _budgetRepo ??= BudgetRepository();
      _goalRepo ??= GoalRepository();
      _isInitialized = true;
    }

    // Kiểm tra kết nối mạng thực tế
    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) {
        debugPrint('SyncService: Offline, skipping sync');
        rep.uploadError = 'Device is offline.';
        return false;
      }
    }

    // Tự động silent re-authenticate nếu currentUser đang null
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != ownerUid) {
      rep.uploadError = 'FirebaseAuth UID does not match Session UID.';
      return false; // I3: không upload khi FirebaseAuth UID lệch với SessionManager
    }

    _isSyncing = true;
    debugPrint('SyncService: Starting full sync for user $ownerUid...');

    try {
      // 1. Upload local changes → Firestore
      final uploadedCount = await _uploadPendingChanges();
      rep.uploadedCount = uploadedCount;

      // 2. Download from Firestore → SQLite (Bulkhead Pattern)
      await _downloadFromFirestore(rep);

      _lastSyncTime = DateTime.now();
      debugPrint('SyncService: Full sync completed ($uploadedCount uploaded)');
      return !rep.hasErrors;
    } catch (e) {
      debugPrint('SyncService: Sync error: $e');
      rep.uploadError = e.toString();
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Đồng bộ trực tiếp 1 giao dịch cụ thể từ SQLite lên Firestore
  @override
  Future<bool> syncSingleTransaction(String txId) async {
    final session = SessionManager.instance;
    final ownerUid = session.uidOrNull;
    if (ownerUid == null) {
      throw Exception('Chưa có phiên đăng nhập hợp lệ.');
    }

    // 1. Kiểm tra mạng thực tế
    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) {
        throw Exception(
          'Thiết bị đang không có kết nối Internet. Vui lòng kiểm tra WiFi hoặc 4G.',
        );
      }
    }

    // 2. Kiểm tra xác thực Firebase Auth
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != ownerUid) {
      throw Exception('Phiên Firebase Auth không khớp với phiên hiện tại.');
    }

    final db = await _dbHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'id = ? AND uid = ?',
      whereArgs: [txId, ownerUid],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception(
        'Không tìm thấy giao dịch thuộc tài khoản trong cơ sở dữ liệu',
      );
    }

    final tx = TransactionModel.fromSqlite(rows.first);
    if (tx.uid != ownerUid) {
      throw Exception(
        'Giao dịch không thuộc sở hữu của phiên đăng nhập hiện tại',
      );
    }

    final firestoreData = _convertToFirestoreFormat(
      tx.toSqlite(),
      'transactions',
    );
    firestoreData['uid'] = ownerUid;
    firestoreData.remove('id');

    try {
      await _firestore
          .collection('transactions')
          .doc(txId)
          .set(firestoreData, SetOptions(merge: true));
    } on FirebaseException catch (fe) {
      if (fe.code == 'permission-denied') {
        throw Exception('Firebase từ chối quyền truy cập (permission-denied).');
      }
      throw Exception('Lỗi Firebase (${fe.code}): ${fe.message}');
    }

    // Cập nhật trạng thái 'synced' trong SQLite
    await db.update(
      'transactions',
      {'syncStatus': 'synced'},
      where: 'id = ? AND uid = ?',
      whereArgs: [txId, ownerUid],
    );

    // Xóa khỏi sync_queue
    await db.delete(
      'sync_queue',
      where: 'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?)',
      whereArgs: ['transactions', txId, ownerUid, ownerUid],
    );

    _transactionRepo?.notifyTransactionsChanged();
    debugPrint('SyncService: Successfully synced single tx: $txId');
    return true;
  }

  // ════════ UPLOAD (Local → Cloud) ════════

  /// Tính toán thời gian chờ theo Exponential Backoff có Jitter
  static int _calculateBackoff(int retryCount) {
    const baseMs = 2000;
    const maxMs = 300000; // 5 phút
    final expMs = baseMs * (1 << (retryCount - 1).clamp(0, 10));
    final jitter = Random().nextInt(1000);
    return min(expMs + jitter, maxMs);
  }

  Future<int> _uploadPendingChanges() async {
    final session = SessionManager.instance;
    final authUser = FirebaseAuth.instance.currentUser;
    final ownerUid = session.uidOrNull;
    if (authUser == null || ownerUid == null || authUser.uid != ownerUid) {
      return 0; // I3: fail-closed, không upload khi hai nguồn UID lệch
    }

    final epoch = session.epoch;
    bool stillMine() =>
        session.isStillValid(epoch, ownerUid) &&
        FirebaseAuth.instance.currentUser?.uid == ownerUid;

    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Atomic Claim: đánh dấu các bản ghi sang 'processing' trong 1 transaction duy nhất
    final queue = await db.transaction((txn) async {
      final rows = await txn.query(
        'sync_queue',
        where:
            "(ownerUid = ? OR uid = ?) AND status = 'pending' AND nextRetryAt <= ?",
        whereArgs: [ownerUid, ownerUid, nowMs],
        orderBy: 'createdAt ASC, id ASC',
        limit: 100,
      );
      if (rows.isNotEmpty) {
        final ids = rows.map((r) => r['id']).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          "UPDATE sync_queue SET status = 'processing', updatedAt = ? WHERE id IN ($placeholders)",
          [nowMs, ...ids],
        );
      }
      return rows;
    });

    var count = 0;
    for (final item in queue) {
      if (!stillMine()) break; // phiên đổi giữa chừng: dừng ngay

      final qid = item['id'];
      final table = item['tableName'] as String;
      final recordId = item['recordId'] as String;
      final action = item['action'] as String;
      final raw = item['data'] as String?;
      final data = raw == null
          ? null
          : json.decode(raw) as Map<String, dynamic>;

      if (data != null) {
        final hasUidMismatch =
            data.containsKey('uid') && data['uid'] != ownerUid;
        final hasCreatedByMismatch =
            data.containsKey('createdBy') && data['createdBy'] != ownerUid;
        final hasOwnerIdMismatch =
            action == 'INSERT' &&
            data.containsKey('ownerId') &&
            data['ownerId'] != ownerUid;

        if (hasUidMismatch || hasCreatedByMismatch || hasOwnerIdMismatch) {
          await _markQueue(
            db,
            qid,
            ownerUid,
            status: 'quarantined',
            error: 'ownership_mismatch',
          );
          continue; // I7: KHÔNG sửa uid, cách ly dòng bất thường
        }
      }

      try {
        await _uploadSingleItem(
          table,
          recordId,
          action,
          data,
          ownerUid: ownerUid,
        );
        if (!stillMine()) break;

        await db.transaction((txn) async {
          if (action != 'DELETE' &&
              action != 'SOFT_DELETE' &&
              action != 'UPDATE_ALL_READ') {
            final keyCol = table == 'users' ? 'uid' : 'id';
            await txn.update(
              table,
              {'syncStatus': 'synced'},
              where: '$keyCol = ? AND uid = ?',
              whereArgs: [recordId, ownerUid],
            );
          }
          await txn.delete(
            'sync_queue',
            where: 'id = ? AND (ownerUid = ? OR uid = ?)',
            whereArgs: [qid, ownerUid, ownerUid],
          );
        });
        count++;
      } on FirebaseException catch (e) {
        final retry = (item['retryCount'] as int? ?? 0) + 1;
        final terminal = e.code == 'permission-denied' || retry >= _maxRetry;
        final nextRetry = terminal ? 0 : nowMs + _calculateBackoff(retry);
        await _markQueue(
          db,
          qid,
          ownerUid,
          status: terminal ? 'dead' : 'pending',
          retry: retry,
          nextRetryAt: nextRetry,
          error: '${e.code}: ${e.message}',
        );
      } catch (e) {
        final retry = (item['retryCount'] as int? ?? 0) + 1;
        final terminal = retry >= _maxRetry;
        final nextRetry = terminal ? 0 : nowMs + _calculateBackoff(retry);
        await _markQueue(
          db,
          qid,
          ownerUid,
          status: terminal ? 'dead' : 'pending',
          retry: retry,
          nextRetryAt: nextRetry,
          error: '$e',
        );
      }
    }

    if (count > 0) {
      _transactionRepo?.notifyTransactionsChanged();
    }
    return count;
  }

  Future<void> _markQueue(
    Database db,
    Object? qid,
    String ownerUid, {
    required String status,
    int? retry,
    int? nextRetryAt,
    String? error,
  }) {
    final values = <String, Object?>{
      'status': status,
      'lastError': error,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (retry != null) {
      values['retryCount'] = retry;
    }
    if (nextRetryAt != null) {
      values['nextRetryAt'] = nextRetryAt;
    }
    return db.update(
      'sync_queue',
      values,
      where: 'id = ? AND (ownerUid = ? OR uid = ?)',
      whereArgs: [qid, ownerUid, ownerUid],
    );
  }

  Future<void> _uploadSingleItem(
    String table,
    String recordId,
    String action,
    Map<String, dynamic>? data, {
    required String ownerUid,
  }) async {
    final collection = _firestore.collection(table);

    switch (action) {
      case 'INSERT':
      case 'UPDATE':
        if (data != null) {
          final firestoreData = _convertToFirestoreFormat(data, table);
          assert(
            firestoreData['uid'] == null || firestoreData['uid'] == ownerUid,
            'firestoreData[uid] must equal ownerUid',
          );
          await collection
              .doc(recordId)
              .set(firestoreData, SetOptions(merge: true));
        }
        break;
      case 'UPDATE_ALL_READ':
        if (data != null && data['uid'] == ownerUid) {
          final unreadDocs = await collection
              .where('uid', isEqualTo: ownerUid)
              .where('isRead', isEqualTo: false)
              .get();
          if (unreadDocs.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in unreadDocs.docs) {
              batch.update(doc.reference, {'isRead': true});
            }
            await batch.commit();
            debugPrint(
              'SyncService: Marked ${unreadDocs.docs.length} notifications as read on Firestore',
            );
          }
        }
        break;
      case 'SOFT_DELETE':
      case 'DELETE':
        // Cập nhật soft delete lên Firestore để các thiết bị khác nhận diện được
        final deletePayload = <String, dynamic>{
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Chỉ gán uid nếu bảng đó thực sự là bảng dữ liệu cá nhân (có trường uid)
        const nonUidTables = {
          'groups',
          'group_expenses',
          'group_settlements',
          'expenses',
          'settlements',
          'group_members',
          'debts',
          'expense_splits',
          'fund_transactions',
        };
        if (!nonUidTables.contains(table)) {
          deletePayload['uid'] = ownerUid;
        }

        await collection
            .doc(recordId)
            .set(deletePayload, SetOptions(merge: true));
        break;
    }
  }

  /// Chuyển đổi dữ liệu SQLite format sang Firestore format
  Map<String, dynamic> _convertToFirestoreFormat(
    Map<String, dynamic> data,
    String table,
  ) {
    final result = Map<String, dynamic>.from(data);

    // Xóa các trường chỉ dùng cho SQLite
    result.remove('syncStatus');
    result.remove('photoLocalPath');
    result.remove('avatarLocalPath');

    // Chuyển int timestamps → Firestore Timestamp
    final timestampFields = [
      'date',
      'createdAt',
      'updatedAt',
      'deletedAt',
      'deadline',
      'joinDate',
      'lastActive',
      'dateOfBirth',
      'lastPasswordUpdate',
    ];
    for (final field in timestampFields) {
      if (result.containsKey(field) && result[field] is int) {
        result[field] = Timestamp.fromMillisecondsSinceEpoch(
          result[field] as int,
        );
      }
    }

    // Chuyển int booleans → bool
    final boolFields = [
      'hasPhoto',
      'isRead',
      'isUnread',
      'isDefault',
      'isDeleted',
    ];
    for (final field in boolFields) {
      if (result.containsKey(field) && result[field] is int) {
        result[field] = result[field] == 1;
      }
    }

    // Chuyển JSON strings → Map/List
    final jsonFields = ['dataUsage', 'customCategories'];
    for (final field in jsonFields) {
      if (result.containsKey(field) && result[field] is String) {
        try {
          result[field] = json.decode(result[field] as String);
        } catch (_) {}
      }
    }

    return result;
  }

  // ════════ DOWNLOAD (Cloud → Local) ════════
  // Bulkhead Pattern: Cô lập luồng download cho từng entity riêng biệt

  Future<void> _recordSyncTimestamp(
    Database db,
    String entityName,
    String uid,
    int timestamp,
  ) async {
    try {
      await db.insert('sync_metadata', {
        'entityName': entityName,
        'uid': uid,
        'lastSyncTimestamp': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<void> _downloadFromFirestore([SyncExecutionReport? report]) async {
    final session = SessionManager.instance;
    final authUser = FirebaseAuth.instance.currentUser;
    final ownerUid = session.uidOrNull;
    if (authUser == null || ownerUid == null || authUser.uid != ownerUid) {
      return;
    }

    final epoch = session.epoch;
    bool stillValid() => session.isStillValid(epoch, ownerUid);
    final db = await _dbHelper.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Wallets (tải đầu tiên vì transactions và goals phụ thuộc vào ví)
    if (stillValid()) {
      try {
        final walletSnapshot = await _firestore
            .collection('wallets')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && walletSnapshot.docs.isNotEmpty) {
          final wallets = walletSnapshot.docs
              .map((doc) => WalletModel.fromFirestore(doc))
              .toList();
          await _walletRepo?.upsertFromFirestore(wallets);
          report?.downloadSuccess['wallets'] = wallets.length;
          await _recordSyncTimestamp(db, 'wallets', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${wallets.length} wallets');
        } else {
          report?.downloadSuccess['wallets'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['wallets'] = e.toString();
        debugPrint('SyncService: Error downloading wallets: $e');
      }
    }

    // 2. Transactions
    if (stillValid()) {
      try {
        final txSnapshot = await _firestore
            .collection('transactions')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && txSnapshot.docs.isNotEmpty) {
          final transactions = txSnapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
          await _transactionRepo?.upsertFromFirestore(transactions);
          report?.downloadSuccess['transactions'] = transactions.length;
          await _recordSyncTimestamp(db, 'transactions', ownerUid, nowMs);
          debugPrint(
            'SyncService: Downloaded ${transactions.length} transactions',
          );
        } else {
          report?.downloadSuccess['transactions'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['transactions'] = e.toString();
        debugPrint('SyncService: Error downloading transactions: $e');
      }
    }

    // 3. Budgets
    if (stillValid()) {
      try {
        final budgetSnapshot = await _firestore
            .collection('budgets')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && budgetSnapshot.docs.isNotEmpty) {
          final budgets = budgetSnapshot.docs
              .map((doc) => BudgetModel.fromFirestore(doc))
              .toList();
          await _budgetRepo?.upsertFromFirestore(budgets);
          report?.downloadSuccess['budgets'] = budgets.length;
          await _recordSyncTimestamp(db, 'budgets', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${budgets.length} budgets');
        } else {
          report?.downloadSuccess['budgets'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['budgets'] = e.toString();
        debugPrint('SyncService: Error downloading budgets: $e');
      }
    }

    // 4. Goals
    if (stillValid()) {
      try {
        final goalSnapshot = await _firestore
            .collection('goals')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && goalSnapshot.docs.isNotEmpty) {
          final goals = goalSnapshot.docs
              .map((doc) => GoalModel.fromFirestore(doc))
              .toList();
          await _goalRepo?.upsertFromFirestore(goals);
          report?.downloadSuccess['goals'] = goals.length;
          await _recordSyncTimestamp(db, 'goals', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${goals.length} goals');
        } else {
          report?.downloadSuccess['goals'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['goals'] = e.toString();
        debugPrint('SyncService: Error downloading goals: $e');
      }
    }

    // 5. User profile
    if (stillValid()) {
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          await _userRepo?.upsertFromFirestore(user);
          report?.downloadSuccess['users'] = 1;
          await _recordSyncTimestamp(db, 'users', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded user profile');
        } else {
          report?.downloadSuccess['users'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['users'] = e.toString();
        debugPrint('SyncService: Error downloading user profile: $e');
      }
    }

    // 6. Notifications
    if (stillValid()) {
      try {
        final notiSnapshot = await _firestore
            .collection('notifications')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && notiSnapshot.docs.isNotEmpty) {
          final notifications = notiSnapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          await _notificationRepo?.upsertFromFirestore(notifications);
          report?.downloadSuccess['notifications'] = notifications.length;
          await _recordSyncTimestamp(db, 'notifications', ownerUid, nowMs);
          debugPrint(
            'SyncService: Downloaded ${notifications.length} notifications',
          );
        } else {
          report?.downloadSuccess['notifications'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['notifications'] = e.toString();
        debugPrint('SyncService: Error downloading notifications: $e');
      }
    }

    // 7. Messages
    if (stillValid()) {
      try {
        final msgSnapshot = await _firestore
            .collection('messages')
            .where('uid', isEqualTo: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && msgSnapshot.docs.isNotEmpty) {
          final messages = msgSnapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList();
          await _messageRepo?.upsertFromFirestore(messages);
          report?.downloadSuccess['messages'] = messages.length;
          await _recordSyncTimestamp(db, 'messages', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${messages.length} messages');
        } else {
          report?.downloadSuccess['messages'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['messages'] = e.toString();
        debugPrint('SyncService: Error downloading messages: $e');
      }
    }
  }

  // ════════ REALTIME LISTENERS ════════

  /// Bắt đầu lắng nghe realtime từ Firestore (chạy background)
  @override
  void startRealtimeListeners() {
    stopRealtimeListeners();

    final session = SessionManager.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ownerUid = session.uidOrNull;
    if (uid == null || ownerUid == null || uid != ownerUid) return;

    final epoch = session.epoch;
    bool stillValid() => session.isStillValid(epoch, ownerUid);

    // Lắng nghe thay đổi transactions
    _firestoreSubscriptions.add(
      _firestore
          .collection('transactions')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final transactions = snapshot.docs
                    .map((doc) => TransactionModel.fromFirestore(doc))
                    .toList();
                _transactionRepo?.upsertFromFirestore(transactions);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime transactions error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi wallets
    _firestoreSubscriptions.add(
      _firestore
          .collection('wallets')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final wallets = snapshot.docs
                    .map((doc) => WalletModel.fromFirestore(doc))
                    .toList();
                _walletRepo?.upsertFromFirestore(wallets);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime wallets error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi budgets
    _firestoreSubscriptions.add(
      _firestore
          .collection('budgets')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final budgets = snapshot.docs
                    .map((doc) => BudgetModel.fromFirestore(doc))
                    .toList();
                _budgetRepo?.upsertFromFirestore(budgets);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime budgets error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi goals
    _firestoreSubscriptions.add(
      _firestore
          .collection('goals')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final goals = snapshot.docs
                    .map((doc) => GoalModel.fromFirestore(doc))
                    .toList();
                _goalRepo?.upsertFromFirestore(goals);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime goals error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi user profile
    _firestoreSubscriptions.add(
      _firestore
          .collection('users')
          .doc(ownerUid)
          .snapshots()
          .listen(
            (doc) {
              if (!stillValid()) return;
              if (doc.exists) {
                final user = UserModel.fromFirestore(doc);
                _userRepo?.upsertFromFirestore(user);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime user error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi notifications
    _firestoreSubscriptions.add(
      _firestore
          .collection('notifications')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final notifications = snapshot.docs
                    .map((doc) => NotificationModel.fromFirestore(doc))
                    .toList();
                _notificationRepo?.upsertFromFirestore(notifications);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime notifications error: $e');
            },
          ),
    );

    debugPrint('SyncService: Realtime listeners started for $ownerUid');
  }

  /// Dừng lắng nghe realtime
  @override
  void stopRealtimeListeners() {
    for (final sub in _firestoreSubscriptions) {
      sub.cancel();
    }
    _firestoreSubscriptions.clear();
    debugPrint('SyncService: Realtime listeners stopped');
  }

  @override
  void dispose() {
    stopRealtimeListeners();
    _connectivitySubscription?.cancel();
  }
}
