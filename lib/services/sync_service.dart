import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';

import '../core/session/session_manager.dart';
import '../core/logging/app_logger.dart';
import '../core/utils/firestore_parse.dart';
import '../data/local/database_helper.dart';
import '../data/local/sync_queue_writer.dart';
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
import '../features/group_expense/data/models/group_model.dart';
import '../features/group_expense/data/models/expense_model.dart';
import '../features/group_expense/data/models/settlement_model.dart';
import '../features/group_expense/data/repositories/sqlite_group_repository.dart';
import '../features/group_expense/data/repositories/sqlite_expense_repository.dart';
import '../features/group_expense/data/repositories/sqlite_settlement_repository.dart';
import 'ledger_reconciliation_service.dart';
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
      } catch (e, st) {
        AppLogger.warn('Không thể decode JSON sync_queue data', tag: 'SyncService', error: e, stackTrace: st);
      }
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
    SqliteGroupRepository? groupRepo,
    SqliteExpenseRepository? expenseRepo,
    SqliteSettlementRepository? settlementRepo,
  });

  Future<bool> syncAll();
  Future<SyncExecutionReport> syncAllDetailed();
  Future<SyncExecutionReport> forceFullResync();
  Future<bool> createCloudBackupSnapshot();
  Future<bool> restoreLatestCloudBackup([String? uid]);
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
/// Chiến lược P1 & Giai đoạn 3:
/// - Khóa kép: In-Memory Mutex + Atomic Claim trong SQLite kèm Stale Lease Recovery
/// - Upload: Đọc sync_queue theo 3-tier Priority + Exponential Backoff + Dead-Letter Queue
/// - Download: Bulkhead Pattern + Local Dirty Shield + LWW + Tie-Breaker SHA-256
/// - Reconcile: Đối soát số dư tự động từ sổ cái transactions
/// - Xóa: Tombstone Soft Delete đồng bộ xuyên thiết bị
class SyncService implements ISyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal() {
    SessionManager.instance.changes.listen((snapshot) {
      final newUid = snapshot?.uid;
      if (newUid == null) {
        _lastSyncTime = null;
        _lastReport = null;
        _initialDownloadDone.clear();
        stopRealtimeListeners();
      } else if (newUid != _listenersUid) {
        _lastSyncTime = null;
        _lastReport = null;
        stopRealtimeListeners();
      }
    });
  }

  static const Set<String> _tablesWithoutUid = {
    'groups',
    'group_members',
    'group_expenses',
    'group_settlements',
  };

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
  SqliteGroupRepository? _groupRepo;
  SqliteExpenseRepository? _expenseRepo;
  SqliteSettlementRepository? _settlementRepo;

  StreamSubscription<bool>? _connectivitySubscription;
  final List<StreamSubscription> _firestoreSubscriptions = [];
  String? _listenersUid;
  final Map<String, bool> _initialDownloadDone = {};
  final StreamController<String> _initialDownloadCompletedController =
      StreamController<String>.broadcast();

  Stream<String> get initialDownloadCompleted =>
      _initialDownloadCompletedController.stream;

  @visibleForTesting
  int get activeListenerCount => _firestoreSubscriptions.length;

  @visibleForTesting
  String? get listenersUid => _listenersUid;

  bool _isSyncing = false;
  bool _isInitialized = false;
  bool _pendingResync = false;
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
    } catch (e, st) {
      AppLogger.warn('Lỗi retryAllDeadLetters', tag: 'SyncService', error: e, stackTrace: st);
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
    } catch (e, st) {
      AppLogger.warn('Lỗi retryAllDeadLetters', tag: 'SyncService', error: e, stackTrace: st);
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
    } catch (e, st) {
      AppLogger.error('Lỗi retryDeadLetterItem', tag: 'SyncService', error: e, stackTrace: st);
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
    } catch (e, st) {
      AppLogger.warn('Lỗi retryAllDeadLetters', tag: 'SyncService', error: e, stackTrace: st);
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
    SqliteGroupRepository? groupRepo,
    SqliteExpenseRepository? expenseRepo,
    SqliteSettlementRepository? settlementRepo,
  }) {
    _transactionRepo = transactionRepo;
    _userRepo = userRepo;
    _notificationRepo = notificationRepo;
    _messageRepo = messageRepo;
    _walletRepo = walletRepo ?? WalletRepository();
    _budgetRepo = budgetRepo ?? BudgetRepository();
    _goalRepo = goalRepo ?? GoalRepository();
    _groupRepo = groupRepo ?? SqliteGroupRepository();
    _expenseRepo = expenseRepo ?? SqliteExpenseRepository();
    _settlementRepo = settlementRepo ?? SqliteSettlementRepository();
    _isInitialized = true;

    // Lắng nghe khi mạng khôi phục → tự động re-auth và sync toàn bộ nếu hợp lệ
    _connectivitySubscription = _connectivity.onlineStream.listen((
      isOnline,
    ) async {
      final uid = SessionManager.instance.uidOrNull;
      if (isOnline && _isInitialized && _accepting && uid != null) {
        debugPrint(
          'SyncService: Network restored, checking silent re-auth & syncing...',
        );
        if (FirebaseAuth.instance.currentUser == null) {
          await AuthService().silentReauthenticateIfNeeded();
        }
        if (_initialDownloadDone[uid] != true) {
          unawaited(initialDownload(uid));
        } else {
          unawaited(syncAll());
        }
      }
    });
  }

  /// Buộc tải lại toàn bộ dữ liệu từ cloud, bỏ qua mốc sync_metadata cũ
  @override
  Future<SyncExecutionReport> forceFullResync() async {
    final session = SessionManager.instance;
    final ownerUid = session.uidOrNull;
    if (ownerUid != null) {
      try {
        final db = await _dbHelper.database;
        await db.delete('sync_metadata', where: 'uid = ?', whereArgs: [ownerUid]);
      } catch (e, st) {
        AppLogger.warn('Không thể decode JSON sync_queue data', tag: 'SyncService', error: e, stackTrace: st);
      }
    }
    return syncAllDetailed();
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

    // 1. In-Memory Mutex: chặn các luồng gọi trùng đồng thời nhưng đánh dấu chạy bù sau khi xong
    final acquired = await _syncLock.tryAcquire();
    if (!acquired) {
      _pendingResync = true;
      debugPrint(
        'SyncService: Another sync cycle is currently running, queued follow-up sync.',
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
      _currentRun = null;
      _syncLock.release();
      if (_pendingResync &&
          _accepting &&
          SessionManager.instance.uidOrNull != null) {
        _pendingResync = false;
        unawaited(syncAll());
      }
    }
  }

  /// Chỉ đẩy hàng đợi upload đang chờ (dùng trước khi đăng xuất để không mất ví/giao dịch)
  Future<int> flushPendingUploads({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!_accepting) return 0;
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return 0;

    final activeRun = _currentRun;
    if (activeRun != null && _syncLock.isLocked) {
      try {
        await activeRun.timeout(timeout);
      } catch (_) {}
    }

    final acquired = await _syncLock.tryAcquire();
    if (!acquired) return 0;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await AuthService().silentReauthenticateIfNeeded();
      }
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null || authUser.uid != ownerUid) return 0;
      return await _uploadPendingChanges().timeout(timeout);
    } catch (e) {
      debugPrint('SyncService: flushPendingUploads error: $e');
      return 0;
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

  /// Tải dữ liệu ban đầu khi mở app hoặc đăng nhập mới (chống chạy trùng theo UID).
  /// Tự động ưu tiên khôi phục bản sao lưu mới nhất trên Firebase (`users/{uid}/backups/latest`) trước.
  Future<void> initialDownload([String? uid]) async {
    final targetUid = uid ?? SessionManager.instance.uidOrNull;
    if (targetUid == null) return;
    if (_initialDownloadDone[targetUid] == true) return;

    // Nếu đang có chu kỳ sync chạy song song, đợi hoàn tất thay vì bỏ qua
    final activeRun = _currentRun;
    if (activeRun != null && _syncLock.isLocked) {
      try {
        await activeRun.timeout(const Duration(seconds: 10));
      } catch (_) {}
      if (_initialDownloadDone[targetUid] == true) return;
      if (SessionManager.instance.uidOrNull != targetUid) return;
    }

    // 1. Ưu tiên lấy bản sao lưu mới nhất trên Firebase (nếu có) để đồng bộ chuẩn 100% ví tiền & số dư
    try {
      await restoreLatestCloudBackup(targetUid);
    } catch (e) {
      debugPrint('SyncService: restoreLatestCloudBackup error: $e');
    }

    // 2. Chạy chu kỳ sync tiêu chuẩn để cập nhật các giao dịch/nhóm phát sinh sau bản sao lưu
    final report = await syncAllDetailed();
    final downloadFailed =
        report.downloadErrors.containsKey('wallets') ||
        report.downloadErrors.containsKey('transactions') ||
        !report.downloadSuccess.containsKey('wallets') ||
        report.uploadError == 'Device is offline.' ||
        report.uploadError == 'FirebaseAuth UID does not match Session UID.' ||
        report.uploadError == 'Another sync cycle is currently running.' ||
        report.uploadError == 'No valid session UID.' ||
        report.uploadError == 'SyncService is not accepting requests (quiesced).';

    if (!downloadFailed && SessionManager.instance.uidOrNull == targetUid) {
      _initialDownloadDone[targetUid] = true;
      final localWallets = await _walletRepo?.getWallets() ?? const [];
      if (localWallets.isEmpty) {
        await _walletRepo?.ensureDefaultWalletExists(
          targetUid,
          firestoreConfirmed: true,
        );
      }
      if (!_initialDownloadCompletedController.isClosed) {
        _initialDownloadCompletedController.add(targetUid);
      }
    }
  }

  /// Tạo một bản sao lưu toàn diện (Cloud Backup Snapshot) từ thiết bị hiện tại lên Firebase
  /// Được gọi khi người dùng bấm nút "Đồng bộ ngay bây giờ" trong trang Dữ liệu và riêng tư.
  /// Đảm bảo ghi đè sạch sẽ toàn bộ ví tiền, số dư, giao dịch, ngân sách và mục tiêu của thiết bị này lên Firebase.
  @override
  Future<bool> createCloudBackupSnapshot() async {
    if (!_accepting) return false;
    final session = SessionManager.instance;
    final ownerUid = session.uidOrNull;
    if (ownerUid == null) return false;

    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) return false;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != ownerUid) return false;

    // Nếu đang có sync chạy nền, chờ nó kết thúc
    final activeRun = _currentRun;
    if (activeRun != null && _syncLock.isLocked) {
      try {
        await activeRun.timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    final acquired = await _syncLock.tryAcquire();
    if (!acquired) return false;

    _isSyncing = true;
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // 1. Đẩy hết các thay đổi đang chờ trong sync_queue lên trước
      await _uploadPendingChanges();

      // 2. Lấy toàn bộ ví đang có trên máy hiện tại (local source of truth)
      final localWalletRows = await db.query(
        'wallets',
        where: 'uid = ?',
        whereArgs: [ownerUid],
      );
      final activeLocalWallets = <Map<String, dynamic>>[];
      final localWalletIds = <String>{};

      for (final row in localWalletRows) {
        final wId = row['id'] as String? ?? '';
        if (wId.isEmpty) continue;
        localWalletIds.add(wId);
        final isDel = (row['isDeleted'] as int? ?? 0) == 1;

        final updatedRow = Map<String, dynamic>.from(row);
        updatedRow['uid'] = ownerUid;
        updatedRow['updatedAt'] = nowMs;

        final fsData = _convertToFirestoreFormat(updatedRow, 'wallets');
        fsData['uid'] = ownerUid;
        await _firestore
            .collection('wallets')
            .doc(wId)
            .set(fsData, SetOptions(merge: true));

        await db.update(
          'wallets',
          {'syncStatus': 'synced', 'updatedAt': nowMs},
          where: 'id = ? AND uid = ?',
          whereArgs: [wId, ownerUid],
        );

        if (!isDel) {
          activeLocalWallets.add(updatedRow);
        }
      }

      // 3. Đánh dấu xóa mềm (isDeleted: true) các ví dư thừa trên Firestore không còn tồn tại hoặc đã xóa trên máy này
      try {
        final remoteWalletsSnap = await _firestore
            .collection('wallets')
            .where('uid', isEqualTo: ownerUid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));

        final activeLocalIds = activeLocalWallets
            .map((w) => w['id'] as String)
            .toSet();
        for (final doc in remoteWalletsSnap.docs) {
          if (!activeLocalIds.contains(doc.id)) {
            await doc.reference.set({
              'uid': ownerUid,
              'isDeleted': true,
              'isDefault': false,
              'deletedAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
              'updatedAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
            }, SetOptions(merge: true));
          }
        }
      } catch (e) {
        debugPrint('SyncService: Clean remote extra wallets error: $e');
      }

      // 4. Đồng bộ toàn bộ giao dịch, ngân sách, mục tiêu cục bộ lên Firestore
      final localTxRows = await db.query(
        'transactions',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [ownerUid],
      );
      final localBudgetRows = await db.query(
        'budgets',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [ownerUid],
      );
      final localGoalRows = await db.query(
        'goals',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [ownerUid],
      );

      // Ghi snapshot bản sao lưu mới nhất vào users/{uid}/backups/latest
      // để khi đăng nhập trên bất kỳ thiết bị nào cũng khôi phục tức thì 100%
      final sanitizedWallets = activeLocalWallets
          .map(
            (w) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(w))!,
          )
          .toList();
      final sanitizedBudgets = localBudgetRows
          .map(
            (b) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(b))!,
          )
          .toList();
      final sanitizedGoals = localGoalRows
          .map(
            (g) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(g))!,
          )
          .toList();

      await _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .doc('latest')
          .set({
            'uid': ownerUid,
            'backedUpAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
            'backedUpAtMs': nowMs,
            'walletCount': sanitizedWallets.length,
            'transactionCount': localTxRows.length,
            'wallets': sanitizedWallets,
            'budgets': sanitizedBudgets,
            'goals': sanitizedGoals,
          });

      // Xóa các mục wallets cũ còn sót trong sync_queue vì đã được đồng bộ đầy đủ
      await db.delete(
        'sync_queue',
        where: "tableName = 'wallets' AND (ownerUid = ? OR uid = ?)",
        whereArgs: [ownerUid, ownerUid],
      );

      // 5. Tải bổ sung các dữ liệu khác nếu có
      final rep = SyncExecutionReport();
      await _downloadFromFirestore(rep);

      _lastSyncTime = DateTime.now();
      _walletRepo?.notifyChanged();
      _transactionRepo?.notifyTransactionsChanged();
      _budgetRepo?.notifyChanged();
      _goalRepo?.notifyChanged();
      return true;
    } catch (e, st) {
      AppLogger.error(
        'Lỗi createCloudBackupSnapshot',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      _isSyncing = false;
      _syncLock.release();
    }
  }

  /// Tự động lấy và khôi phục bản sao lưu mới nhất (`users/{uid}/backups/latest` và `wallets` trên Firebase)
  /// ngay khi đăng nhập để đảm bảo thiết bị mới (như Redmi K70E) hiển thị khớp 100% ví tiền và số tiền với máy đã sao lưu (Pixel 7a).
  @override
  Future<bool> restoreLatestCloudBackup([String? uid]) async {
    final targetUid = uid ?? SessionManager.instance.uidOrNull;
    if (targetUid == null) return false;

    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) return false;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != targetUid) return false;

    try {
      final db = await _dbHelper.database;

      // 1. Kiểm tra bản sao lưu mới nhất tại users/{uid}/backups/latest
      DocumentSnapshot<Map<String, dynamic>>? backupDoc;
      try {
        backupDoc = await _firestore
            .collection('users')
            .doc(targetUid)
            .collection('backups')
            .doc('latest')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        backupDoc = await _firestore
            .collection('users')
            .doc(targetUid)
            .collection('backups')
            .doc('latest')
            .get()
            .timeout(const Duration(seconds: 8));
      }

      List<WalletModel> authoritativeWallets = [];

      if (backupDoc.exists && backupDoc.data() != null) {
        final data = backupDoc.data()!;
        final rawWallets = data['wallets'] as List<dynamic>?;
        if (rawWallets != null && rawWallets.isNotEmpty) {
          for (final item in rawWallets) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              map['uid'] = targetUid;
              map['syncStatus'] = 'synced';
              authoritativeWallets.add(WalletModel.fromSqlite(map));
            }
          }
        }
      }

      // 2. Nếu chưa từng bấm tạo snapshot `backups/latest`, lấy danh sách ví trực tiếp từ collection `wallets` trên server
      if (authoritativeWallets.isEmpty) {
        QuerySnapshot<Map<String, dynamic>> walletSnap;
        try {
          walletSnap = await _firestore
              .collection('wallets')
              .where('uid', isEqualTo: targetUid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          walletSnap = await _firestore
              .collection('wallets')
              .where('uid', isEqualTo: targetUid)
              .get()
              .timeout(const Duration(seconds: 8));
        }
        final parsed = FirestoreParse.parseList(
          walletSnap.docs,
          WalletModel.fromFirestore,
          tag: 'SyncService.restoreBackup',
        ).where((w) => !w.isDeleted && w.uid == targetUid).toList();

        // Lọc bỏ ví mặc định 0đ tự sinh (wlt_default_*) nếu đã có ví thật khác
        final defaultWid = 'wlt_default_$targetUid';
        final hasRealWallets = parsed.any((w) => w.id != defaultWid);
        if (hasRealWallets) {
          authoritativeWallets = parsed
              .where(
                (w) =>
                    w.id != defaultWid ||
                    w.balance != 0 ||
                    w.initialBalance != 0,
              )
              .toList();
        } else {
          authoritativeWallets = parsed;
        }
      }

      if (authoritativeWallets.isEmpty) return false;

      // 3. Áp dụng bản sao lưu chuẩn vào SQLite của thiết bị đăng nhập (xóa sạch ví rác/sai lệch cục bộ)
      final rawBudgets = backupDoc.exists && backupDoc.data() != null
          ? (backupDoc.data()!['budgets'] as List<dynamic>?)
          : null;
      final rawGoals = backupDoc.exists && backupDoc.data() != null
          ? (backupDoc.data()!['goals'] as List<dynamic>?)
          : null;

      await db.transaction((txn) async {
        // Xóa các tác vụ sync_queue cũ của wallets trên máy đang đăng nhập để tránh đẩy ngược ví sai lên cloud
        await txn.delete(
          'sync_queue',
          where: "tableName = 'wallets' AND (ownerUid = ? OR uid = ?)",
          whereArgs: [targetUid, targetUid],
        );

        // Xóa các ví cục bộ không nằm trong bản sao lưu mới nhất
        final validIds = authoritativeWallets.map((w) => w.id).toSet();
        final existingRows = await txn.query(
          'wallets',
          columns: ['id'],
          where: 'uid = ?',
          whereArgs: [targetUid],
        );
        for (final r in existingRows) {
          final lid = r['id'] as String? ?? '';
          if (lid.isNotEmpty && !validIds.contains(lid)) {
            await txn.delete(
              'wallets',
              where: 'id = ? AND uid = ?',
              whereArgs: [lid, targetUid],
            );
          }
        }

        // Ghi đè toàn bộ ví chuẩn từ bản sao lưu
        for (final w in authoritativeWallets) {
          final row = w.copyWith(syncStatus: 'synced', isDeleted: false).toSqlite();
          row['uid'] = targetUid;
          await txn.insert(
            'wallets',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Khôi phục ngân sách từ bản sao lưu nếu có
        if (rawBudgets != null && rawBudgets.isNotEmpty) {
          for (final item in rawBudgets) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              map['uid'] = targetUid;
              map['syncStatus'] = 'synced';
              final bRow = BudgetModel.fromSqlite(map).toSqlite();
              await txn.insert(
                'budgets',
                bRow,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }

        // Khôi phục mục tiêu từ bản sao lưu nếu có
        if (rawGoals != null && rawGoals.isNotEmpty) {
          for (final item in rawGoals) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              map['uid'] = targetUid;
              map['syncStatus'] = 'synced';
              final gRow = GoalModel.fromSqlite(map).toSqlite();
              await txn.insert(
                'goals',
                gRow,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      });

      _walletRepo?.notifyChanged();
      if (rawBudgets != null && rawBudgets.isNotEmpty) {
        _budgetRepo?.notifyChanged();
      }
      if (rawGoals != null && rawGoals.isNotEmpty) {
        _goalRepo?.notifyChanged();
      }
      debugPrint(
        'SyncService: Restored ${authoritativeWallets.length} wallets from latest cloud backup for $targetUid',
      );
      return true;
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi restoreLatestCloudBackup',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
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
      _groupRepo ??= SqliteGroupRepository();
      _expenseRepo ??= SqliteExpenseRepository();
      _settlementRepo ??= SqliteSettlementRepository();
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

  /// Khôi phục các item bị kẹt ở trạng thái 'processing' do app crash hoặc timeout trước đó
  Future<void> _recoverStaleProcessingItems(Database db, String ownerUid) async {
    const leaseTimeoutMs = 120000; // 2 phút lease timeout
    final staleThreshold = DateTime.now().millisecondsSinceEpoch - leaseTimeoutMs;
    try {
      await db.rawUpdate(
        "UPDATE sync_queue SET status = 'pending' WHERE (ownerUid = ? OR uid = ?) AND status = 'processing' AND updatedAt < ?",
        [ownerUid, ownerUid, staleThreshold],
      );
    } catch (_) {}
  }

  /// Tự động phát hiện và phục hồi các ví / giao dịch cục bộ đang ở trạng thái 'pending'
  /// nhưng bị mồ côi khỏi sync_queue (hoặc bị kẹt ở 'dead' / 'quarantined' / thiếu trường)
  /// TRƯỚC KHI tiến hành upload lên Firestore.
  Future<void> _repairOrphanDirtyRecords(Database db, String ownerUid) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction((txn) async {
        // 1. Gán lại ownerUid/uid cho các dòng sync_queue cũ bị rỗng nếu bản ghi thuộc ownerUid
        for (final table in const ['wallets', 'transactions', 'budgets', 'goals']) {
          await txn.rawUpdate(
            '''
            UPDATE sync_queue
            SET ownerUid = ?, uid = ?
            WHERE (ownerUid = '' OR uid = '') AND tableName = ?
              AND EXISTS (SELECT 1 FROM $table s WHERE s.id = sync_queue.recordId AND s.uid = ?)
            ''',
            [ownerUid, ownerUid, table, ownerUid],
          );
        }

        // 2. Mở khóa các bản ghi wallets/transactions bị dead/quarantined của user hiện tại
        await txn.rawUpdate(
          "UPDATE sync_queue SET status = 'pending', retryCount = 0, nextRetryAt = 0, updatedAt = ? "
          "WHERE (ownerUid = ? OR uid = ?) AND status IN ('dead', 'quarantined') "
          "AND tableName IN ('wallets', 'transactions', 'budgets', 'goals')",
          [nowMs, ownerUid, ownerUid],
        );

        // 3. Đảm bảo mọi ví cục bộ có syncStatus == 'pending' đều có bản ghi INSERT đầy đủ trong sync_queue
        final dirtyWallets = await txn.query(
          'wallets',
          where: "uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND syncStatus = 'pending'",
          whereArgs: [ownerUid],
        );
        for (final wRow in dirtyWallets) {
          final wId = wRow['id'] as String? ?? '';
          if (wId.isEmpty) continue;

          final existingQueue = await txn.query(
            'sync_queue',
            where:
                "tableName = 'wallets' AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN ('pending', 'processing')",
            whereArgs: [wId, ownerUid, ownerUid],
            limit: 1,
          );

          bool hasCompletePayload = false;
          if (existingQueue.isNotEmpty) {
            final raw = existingQueue.first['data'] as String?;
            if (raw != null) {
              try {
                final parsed = json.decode(raw) as Map<String, dynamic>;
                hasCompletePayload =
                    (parsed['name'] as String?)?.trim().isNotEmpty == true &&
                    parsed.containsKey('balance') &&
                    parsed.containsKey('initialBalance');
              } catch (_) {}
            }
          }

          if (!hasCompletePayload) {
            final payload = Map<String, Object?>.from(wRow);
            payload['uid'] = ownerUid;
            payload['syncStatus'] = 'pending';

            await txn.delete(
              'sync_queue',
              where:
                  "tableName = 'wallets' AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status = 'pending'",
              whereArgs: [wId, ownerUid, ownerUid],
            );
            await txn.insert('sync_queue', {
              'uid': ownerUid,
              'ownerUid': ownerUid,
              'tableName': 'wallets',
              'recordId': wId,
              'action': 'INSERT',
              'data': json.encode(payload),
              'createdAt': nowMs,
              'updatedAt': nowMs,
              'retryCount': 0,
              'nextRetryAt': 0,
              'status': 'pending',
              'priority': 1,
            });
          }
        }
      });
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi _repairOrphanDirtyRecords',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
    }
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

    // 0. Khôi phục stale processing items & sửa chữa các ví/giao dịch pending mồ côi trước khi claim
    await _recoverStaleProcessingItems(db, ownerUid);
    await _repairOrphanDirtyRecords(db, ownerUid);

    var count = 0;
    const maxBatches = 10;
    for (var batchIdx = 0; batchIdx < maxBatches; batchIdx++) {
      if (!stillMine()) break;
      final batchNowMs = DateTime.now().millisecondsSinceEpoch;

      // Atomic Claim: đánh dấu các bản ghi sang 'processing' theo thứ tự ưu tiên (Priority 1 -> 2 -> 3)
      final queue = await db.transaction((txn) async {
        final rows = await txn.query(
          'sync_queue',
          where:
              "(ownerUid = ? OR uid = ?) AND status = 'pending' AND nextRetryAt <= ?",
          whereArgs: [ownerUid, ownerUid, batchNowMs],
          orderBy: 'priority ASC, createdAt ASC, id ASC',
          limit: 100,
        );
        if (rows.isNotEmpty) {
          final ids = rows.map((r) => r['id']).toList();
          final placeholders = List.filled(ids.length, '?').join(',');
          await txn.rawUpdate(
            "UPDATE sync_queue SET status = 'processing', updatedAt = ? WHERE id IN ($placeholders)",
            [batchNowMs, ...ids],
          );
        }
        return rows;
      });

      if (queue.isEmpty) break;

      var batchSucceeded = 0;
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
              if (_tablesWithoutUid.contains(table)) {
                await txn.update(
                  table,
                  {'syncStatus': 'synced'},
                  where: '$keyCol = ?',
                  whereArgs: [recordId],
                );
              } else {
                await txn.update(
                  table,
                  {'syncStatus': 'synced'},
                  where: '$keyCol = ? AND uid = ?',
                  whereArgs: [recordId, ownerUid],
                );
              }
            }
            await txn.delete(
              'sync_queue',
              where: 'id = ? AND (ownerUid = ? OR uid = ?)',
              whereArgs: [qid, ownerUid, ownerUid],
            );
          });
          count++;
          batchSucceeded++;
        } on FirebaseException catch (e) {
          final retry = (item['retryCount'] as int? ?? 0) + 1;
          final isAuthError = e.code == 'unauthenticated';
          final terminal = e.code == 'permission-denied' ||
              e.code == 'not-found' ||
              e.code == 'invalid-argument' ||
              retry >= _maxRetry;

          if (isAuthError) {
            unawaited(AuthService().silentReauthenticateIfNeeded());
            await _markQueue(
              db,
              qid,
              ownerUid,
              status: 'pending',
              retry: retry,
              nextRetryAt: batchNowMs + 3000,
              error: '${e.code}: ${e.message}',
            );
          } else {
            final nextRetry = terminal ? 0 : batchNowMs + _calculateBackoff(retry);
            await _markQueue(
              db,
              qid,
              ownerUid,
              status: terminal ? 'dead' : 'pending',
              retry: retry,
              nextRetryAt: nextRetry,
              error: '${e.code}: ${e.message}',
            );
          }
        } catch (e) {
          final retry = (item['retryCount'] as int? ?? 0) + 1;
          final terminal = retry >= _maxRetry;
          final nextRetry = terminal ? 0 : batchNowMs + _calculateBackoff(retry);
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

      if (queue.length < 100 || batchSucceeded == 0) break;
    }

    if (count > 0) {
      _walletRepo?.notifyChanged();
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

  String _resolveCollectionName(String table) {
    switch (table) {
      case 'group_expenses':
        return 'expenses';
      case 'group_settlements':
        return 'settlements';
      default:
        return table;
    }
  }

  Future<void> _uploadSingleItem(
    String table,
    String recordId,
    String action,
    Map<String, dynamic>? data, {
    required String ownerUid,
  }) async {
    // 1. Đồng bộ thành viên nhóm trực tiếp vào document nhóm
    if (table == 'group_members') {
      final groupId = data?['groupId'] as String? ??
          (recordId.contains('_') ? recordId.split('_').first : '');
      final memberUid = data?['userId'] as String? ??
          (recordId.contains('_') ? recordId.split('_').last : ownerUid);
      if (groupId.isNotEmpty && memberUid.isNotEmpty) {
        final groupDoc = _firestore.collection('groups').doc(groupId);
        if (action == 'INSERT' || (action == 'UPDATE' && data?['status'] == 'active')) {
          await groupDoc.set({
            'memberIds': FieldValue.arrayUnion([memberUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (action == 'DELETE' || action == 'SOFT_DELETE' || (action == 'UPDATE' && data?['status'] == 'left')) {
          await groupDoc.set({
            'memberIds': FieldValue.arrayRemove([memberUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      return;
    }

    final collectionName = _resolveCollectionName(table);
    final collection = _firestore.collection(collectionName);

    switch (action) {
      case 'INSERT':
      case 'UPDATE':
        if (data != null) {
          final firestoreData = _convertToFirestoreFormat(data, table);
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
          if (!nonUidTables.contains(table) && firestoreData['uid'] == null) {
            firestoreData['uid'] = ownerUid;
          }
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
          'deletedAt': data?['deletedAt'] != null
              ? (data!['deletedAt'] is int
                  ? Timestamp.fromMillisecondsSinceEpoch(data['deletedAt'] as int)
                  : FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
          'updatedAt': data?['updatedAt'] != null
              ? (data!['updatedAt'] is int
                  ? Timestamp.fromMillisecondsSinceEpoch(data['updatedAt'] as int)
                  : FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
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
      'confirmedAt',
      'joinedAt',
      'leftAt',
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
        } catch (e, st) {
        AppLogger.warn('Không thể decode JSON sync_queue data', tag: 'SyncService', error: e, stackTrace: st);
      }
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

  /// Tự động phát hiện và đẩy lại các ví cục bộ bị thiếu hoặc bị lệch/hỏng trên Firestore (chống mất ví khi đổi máy)
  Future<void> _backfillMissingLocalWallets(
    Database db,
    String ownerUid,
    Map<String, WalletModel> remoteWalletsById,
  ) async {
    try {
      final localRows = await db.query(
        'wallets',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [ownerUid],
      );
      if (localRows.isEmpty) return;

      final hasNonEmptyRemoteWallet = remoteWalletsById.values.any(
        (w) => !w.isDeleted && (w.balance != 0 || w.initialBalance != 0),
      );

      var enqueued = 0;
      await db.transaction((txn) async {
        for (final row in localRows) {
          final id = row['id'] as String? ?? '';
          if (id.isEmpty) continue;

          final syncStatus = row['syncStatus'] as String? ?? 'synced';
          // Không đẩy ví tạm local_only nếu trên server đã có ví thật khác
          if (syncStatus == 'local_only' && hasNonEmptyRemoteWallet) {
            continue;
          }

          final bal = (row['balance'] as num?)?.toDouble() ?? 0.0;
          final initBal = (row['initialBalance'] as num?)?.toDouble() ?? 0.0;
          final localWallet = WalletModel.fromSqlite(row);

          // Bỏ qua ví mặc định 0đ rỗng nếu trên server đã có ví thật khác
          if (id == 'wlt_default_$ownerUid' &&
              bal == 0 &&
              initBal == 0 &&
              remoteWalletsById.values.any((w) => !w.isDeleted)) {
            continue;
          }

          final remote = remoteWalletsById[id];
          // Backfill khi:
          // 1. Ví cục bộ chưa từng tồn tại trên Firestore (remote == null)
          // 2. Hoặc doc trên Firestore bị rỗng tên do bản ghi bán phần cũ
          // 3. Hoặc ví cục bộ đang ở trạng thái 'pending'
          // 4. Hoặc ví cục bộ có dữ liệu khác với remote VÀ có updatedAt mới hơn remote (hoặc remote đang 0đ mà local có số dư thực)
          bool isLocalNewerOrRicher = false;
          if (remote != null && !remote.isDeleted) {
            final hasDataDiff =
                (localWallet.balance - remote.balance).abs() > 0.001 ||
                (localWallet.initialBalance - remote.initialBalance).abs() >
                    0.001 ||
                localWallet.name.trim() != remote.name.trim() ||
                localWallet.type != remote.type ||
                localWallet.iconCode != remote.iconCode ||
                localWallet.colorValue != remote.colorValue ||
                localWallet.isDefault != remote.isDefault;

            if (hasDataDiff) {
              if (localWallet.updatedAt.isAfter(remote.updatedAt)) {
                isLocalNewerOrRicher = true;
              } else if (remote.balance == 0 &&
                  remote.initialBalance == 0 &&
                  (localWallet.balance != 0 ||
                      localWallet.initialBalance != 0)) {
                isLocalNewerOrRicher = true;
              }
            }
          }

          final needsBackfill =
              remote == null ||
              (!remote.isDeleted && remote.name.trim().isEmpty) ||
              syncStatus == 'pending' ||
              isLocalNewerOrRicher;

          if (!needsBackfill) continue;

          final pending = await txn.query(
            'sync_queue',
            columns: ['id'],
            where:
                'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
            whereArgs: ['wallets', id, ownerUid, ownerUid, 'pending', 'processing'],
            limit: 1,
          );
          if (pending.isNotEmpty) continue;

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final effectiveUpdatedAt = remote != null &&
                  remote.updatedAt.millisecondsSinceEpoch >= nowMs
              ? remote.updatedAt.millisecondsSinceEpoch + 1
              : nowMs;
          final payload = Map<String, Object?>.from(row);
          payload['uid'] = ownerUid;
          payload['updatedAt'] = effectiveUpdatedAt;
          payload['syncStatus'] = 'pending';

          await txn.update(
            'wallets',
            {'syncStatus': 'pending', 'updatedAt': effectiveUpdatedAt},
            where: 'id = ? AND uid = ?',
            whereArgs: [id, ownerUid],
          );
          await txn.insert('sync_queue', {
            'uid': ownerUid,
            'ownerUid': ownerUid,
            'tableName': 'wallets',
            'recordId': id,
            'action': 'INSERT',
            'data': json.encode(payload),
            'createdAt': nowMs,
            'updatedAt': nowMs,
            'retryCount': 0,
            'nextRetryAt': 0,
            'status': 'pending',
            'priority': 1,
          });
          enqueued++;
        }
      });

      if (enqueued > 0) {
        _pendingResync = true;
        AppLogger.info(
          'Backfill: đã đưa $enqueued ví cục bộ bị thiếu/lệch lên Firestore vào sync_queue',
          tag: 'SyncService',
        );
      }
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi _backfillMissingLocalWallets',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Tự động phát hiện và đẩy lại các giao dịch cục bộ bị thiếu hoặc lệch trên Firestore
  Future<void> _backfillMissingLocalTransactions(
    Database db,
    String ownerUid,
    Map<String, TransactionModel> remoteTxsById,
  ) async {
    try {
      final localRows = await db.query(
        'transactions',
        where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
        whereArgs: [ownerUid],
      );
      if (localRows.isEmpty) return;

      var enqueued = 0;
      await db.transaction((txn) async {
        for (final row in localRows) {
          final id = row['id'] as String? ?? '';
          if (id.isEmpty) continue;

          final remote = remoteTxsById[id];
          final needsBackfill = remote == null;

          if (!needsBackfill) continue;

          final pending = await txn.query(
            'sync_queue',
            columns: ['id'],
            where:
                'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
            whereArgs: ['transactions', id, ownerUid, ownerUid, 'pending', 'processing'],
            limit: 1,
          );
          if (pending.isNotEmpty) continue;

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final payload = Map<String, Object?>.from(row);
          payload['uid'] = ownerUid;
          payload['syncStatus'] = 'pending';

          await txn.update(
            'transactions',
            {'syncStatus': 'pending'},
            where: 'id = ? AND uid = ?',
            whereArgs: [id, ownerUid],
          );
          await txn.insert('sync_queue', {
            'uid': ownerUid,
            'ownerUid': ownerUid,
            'tableName': 'transactions',
            'recordId': id,
            'action': 'INSERT',
            'data': json.encode(payload),
            'createdAt': nowMs,
            'updatedAt': nowMs,
            'retryCount': 0,
            'nextRetryAt': 0,
            'status': 'pending',
            'priority': 3,
          });
          enqueued++;
        }
      });

      if (enqueued > 0) {
        _pendingResync = true;
        AppLogger.info(
          'Backfill: đã đưa $enqueued giao dịch cục bộ bị thiếu/lệch lên Firestore vào sync_queue',
          tag: 'SyncService',
        );
      }
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi _backfillMissingLocalTransactions',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
    }
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

    bool walletsDownloadOk = false;
    bool transactionsDownloadOk = false;

    // 1. Wallets (ưu tiên tải từ server, fallback về default source nếu mạng chập chờn nhưng có dữ liệu)
    if (stillValid()) {
      try {
        QuerySnapshot<Map<String, dynamic>> walletSnapshot;
        try {
          walletSnapshot = await _firestore
              .collection('wallets')
              .where('uid', isEqualTo: ownerUid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          walletSnapshot = await _firestore
              .collection('wallets')
              .where('uid', isEqualTo: ownerUid)
              .get()
              .timeout(const Duration(seconds: 8));
        }

        final remoteWallets = FirestoreParse.parseList(
          walletSnapshot.docs,
          WalletModel.fromFirestore,
          tag: 'SyncService.wallets',
        );

        if (stillValid() && remoteWallets.isNotEmpty) {
          await _walletRepo?.upsertFromFirestore(remoteWallets);
          report?.downloadSuccess['wallets'] = remoteWallets.length;
          await _recordSyncTimestamp(db, 'wallets', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${remoteWallets.length} wallets');
          walletsDownloadOk = true;
        } else if (!walletSnapshot.metadata.isFromCache) {
          report?.downloadSuccess['wallets'] = 0;
          walletsDownloadOk = true;
        } else {
          report?.downloadErrors['wallets'] =
              'Wallets snapshot served from cache.';
        }

        // Self-healing backfill: nếu máy hiện tại có ví cục bộ chưa từng lên Firestore
        // hoặc trên Firestore bị thiếu/0đ, tự động đưa lại vào sync_queue để đẩy lên cloud.
        if (stillValid() && !walletSnapshot.metadata.isFromCache) {
          final remoteById = {for (final w in remoteWallets) w.id: w};
          await _backfillMissingLocalWallets(db, ownerUid, remoteById);
        }
      } catch (e) {
        report?.downloadErrors['wallets'] = e.toString();
        debugPrint('SyncService: Error downloading wallets: $e');
      }
    }

    // 2. Transactions (ưu tiên tải từ server, fallback về default source nếu mạng chập chờn)
    if (stillValid()) {
      try {
        QuerySnapshot<Map<String, dynamic>> txSnapshot;
        try {
          txSnapshot = await _firestore
              .collection('transactions')
              .where('uid', isEqualTo: ownerUid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          txSnapshot = await _firestore
              .collection('transactions')
              .where('uid', isEqualTo: ownerUid)
              .get()
              .timeout(const Duration(seconds: 8));
        }

        final transactions = FirestoreParse.parseList(
          txSnapshot.docs,
          TransactionModel.fromFirestore,
          tag: 'SyncService.transactions',
        );

        if (stillValid() && transactions.isNotEmpty) {
          await _transactionRepo?.upsertFromFirestore(transactions);
          report?.downloadSuccess['transactions'] = transactions.length;
          await _recordSyncTimestamp(db, 'transactions', ownerUid, nowMs);
          debugPrint(
            'SyncService: Downloaded ${transactions.length} transactions',
          );
          transactionsDownloadOk = true;
        } else if (!txSnapshot.metadata.isFromCache) {
          report?.downloadSuccess['transactions'] = 0;
          transactionsDownloadOk = true;
        } else {
          report?.downloadErrors['transactions'] =
              'Transactions snapshot served from cache.';
        }

        // Self-healing backfill: tự động đẩy các giao dịch cục bộ bị thiếu trên Firestore
        if (stillValid() && !txSnapshot.metadata.isFromCache) {
          final remoteTxsById = {for (final t in transactions) t.id: t};
          await _backfillMissingLocalTransactions(db, ownerUid, remoteTxsById);
        }
      } catch (e) {
        report?.downloadErrors['transactions'] = e.toString();
        debugPrint('SyncService: Error downloading transactions: $e');
      }
    }

    // Đối soát và tái tạo ví bị thiếu ngay sau khi tải xong Wallets + Transactions
    // để giao diện Home / Ví hiển thị đầy đủ ví & số dư lập tức mà không phải chờ các bảng phụ
    if (stillValid() && (walletsDownloadOk || transactionsDownloadOk)) {
      try {
        await LedgerReconciliationService().reconcileAll(ownerUid);
      } catch (e) {
        debugPrint('SyncService: Early ledger reconciliation error: $e');
      }
    }

    // Nếu quá trình backfill/healing vừa thêm ví hoặc giao dịch vào sync_queue, đẩy lên Firestore ngay
    if (stillValid() && _pendingResync) {
      _pendingResync = false;
      try {
        final backfilledCount = await _uploadPendingChanges();
        if (report != null) {
          report.uploadedCount += backfilledCount;
        }
      } catch (e) {
        debugPrint('SyncService: Immediate backfill upload error: $e');
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
          final budgets = FirestoreParse.parseList(
            budgetSnapshot.docs,
            BudgetModel.fromFirestore,
            tag: 'SyncService.budgets',
          );
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
          final goals = FirestoreParse.parseList(
            goalSnapshot.docs,
            GoalModel.fromFirestore,
            tag: 'SyncService.goals',
          );
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
          final notifications = FirestoreParse.parseList(
            notiSnapshot.docs,
            NotificationModel.fromFirestore,
            tag: 'SyncService.notifications',
          );
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
          final messages = FirestoreParse.parseList(
            msgSnapshot.docs,
            MessageModel.fromFirestore,
            tag: 'SyncService.messages',
          );
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

    // 8. Groups (Quỹ nhóm mà user là thành viên)
    final userGroupIds = <String>[];
    if (stillValid()) {
      try {
        final groupSnapshot = await _firestore
            .collection('groups')
            .where('memberIds', arrayContains: ownerUid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (stillValid() && groupSnapshot.docs.isNotEmpty) {
          final groups = FirestoreParse.parseList(
            groupSnapshot.docs,
            (doc) {
              final d = Map<String, dynamic>.from(
                doc.data() as Map<String, dynamic>? ?? {},
              );
              d['id'] = doc.id;
              return GroupModel.fromJson(d);
            },
            tag: 'SyncService.groups',
          );
          await _groupRepo?.upsertFromFirestore(groups);
          userGroupIds.addAll(
            groups.where((g) => !g.isDeleted).map((g) => g.id),
          );
          report?.downloadSuccess['groups'] = groups.length;
          await _recordSyncTimestamp(db, 'groups', ownerUid, nowMs);
          debugPrint('SyncService: Downloaded ${groups.length} groups');
        } else {
          report?.downloadSuccess['groups'] = 0;
        }
      } catch (e) {
        report?.downloadErrors['groups'] = e.toString();
        debugPrint('SyncService: Error downloading groups: $e');
      }
    }

    // 9. Group Expenses & Settlements (Theo từng nhóm đã tham gia, chia chunk 10)
    if (stillValid() && userGroupIds.isNotEmpty) {
      const chunkSize = 10;
      for (var i = 0; i < userGroupIds.length; i += chunkSize) {
        if (!stillValid()) break;
        final chunk = userGroupIds.sublist(
          i,
          min(i + chunkSize, userGroupIds.length),
        );

        try {
          // Expenses
          final expenseSnapshot = await _firestore
              .collection('expenses')
              .where('groupId', whereIn: chunk)
              .get()
              .timeout(const Duration(seconds: 8));
          if (stillValid() && expenseSnapshot.docs.isNotEmpty) {
            final expenses = FirestoreParse.parseList(
              expenseSnapshot.docs,
              (doc) {
                final d = Map<String, dynamic>.from(
                  doc.data() as Map<String, dynamic>? ?? {},
                );
                d['id'] = doc.id;
                return ExpenseModel.fromJson(d);
              },
              tag: 'SyncService.group_expenses',
            );
            await _expenseRepo?.upsertFromFirestore(expenses);
            report?.downloadSuccess['group_expenses'] =
                (report.downloadSuccess['group_expenses'] ?? 0) +
                expenses.length;
          }

          // Settlements
          final settlementSnapshot = await _firestore
              .collection('settlements')
              .where('groupId', whereIn: chunk)
              .get()
              .timeout(const Duration(seconds: 8));
          if (stillValid() && settlementSnapshot.docs.isNotEmpty) {
            final settlements = FirestoreParse.parseList(
              settlementSnapshot.docs,
              (doc) {
                final d = Map<String, dynamic>.from(
                  doc.data() as Map<String, dynamic>? ?? {},
                );
                d['id'] = doc.id;
                return SettlementModel.fromJson(d);
              },
              tag: 'SyncService.group_settlements',
            );
            await _settlementRepo?.upsertFromFirestore(settlements);
            report?.downloadSuccess['group_settlements'] =
                (report.downloadSuccess['group_settlements'] ?? 0) +
                settlements.length;
          }
        } catch (e) {
          report?.downloadErrors['group_expenses_chunk_$i'] = e.toString();
          debugPrint(
            'SyncService: Error downloading group expenses/settlements chunk $i: $e',
          );
        }
      }
      await _recordSyncTimestamp(db, 'group_expenses', ownerUid, nowMs);
      await _recordSyncTimestamp(db, 'group_settlements', ownerUid, nowMs);
    }

    // 10. Ledger Reconciliation: Chỉ đối soát khi CẢ wallets và transactions tải thành công
    if (stillValid() && walletsDownloadOk && transactionsDownloadOk) {
      try {
        await LedgerReconciliationService().reconcileAll(ownerUid);
        debugPrint('SyncService: Ledger reconciliation completed for $ownerUid');
      } catch (e) {
        debugPrint('SyncService: Ledger reconciliation error: $e');
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

    _listenersUid = ownerUid;
    final epoch = session.epoch;
    bool stillValid() => session.isStillValid(epoch, ownerUid);

    // Lắng nghe thay đổi transactions
    _firestoreSubscriptions.add(
      _firestore
          .collection('transactions')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final transactions = FirestoreParse.parseList(
                  snapshot.docs,
                  TransactionModel.fromFirestore,
                  tag: 'SyncService.rt.transactions',
                );
                await _transactionRepo?.upsertFromFirestore(transactions);
                if (stillValid()) {
                  await LedgerReconciliationService().reconcileAll(ownerUid);
                }
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
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final wallets = FirestoreParse.parseList(
                  snapshot.docs,
                  WalletModel.fromFirestore,
                  tag: 'SyncService.rt.wallets',
                );
                await _walletRepo?.upsertFromFirestore(wallets);
                if (stillValid()) {
                  await LedgerReconciliationService().reconcileAll(ownerUid);
                }
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime wallets error: $e');
            },
          ),
    );

    // Lắng nghe thay đổi groups
    _firestoreSubscriptions.add(
      _firestore
          .collection('groups')
          .where('memberIds', arrayContains: ownerUid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final groups = FirestoreParse.parseList(
                  snapshot.docs,
                  (doc) {
                    final d = Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>? ?? {},
                    );
                    d['id'] = doc.id;
                    return GroupModel.fromJson(d);
                  },
                  tag: 'SyncService.rt.groups',
                );
                _groupRepo?.upsertFromFirestore(groups);
              }
            },
            onError: (e) {
              debugPrint('SyncService: Realtime groups error: $e');
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
                final budgets = FirestoreParse.parseList(
                  snapshot.docs,
                  BudgetModel.fromFirestore,
                  tag: 'SyncService.rt.budgets',
                );
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
                final goals = FirestoreParse.parseList(
                  snapshot.docs,
                  GoalModel.fromFirestore,
                  tag: 'SyncService.rt.goals',
                );
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
                final notifications = FirestoreParse.parseList(
                  snapshot.docs,
                  NotificationModel.fromFirestore,
                  tag: 'SyncService.rt.notifications',
                );
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
    _listenersUid = null;
    debugPrint('SyncService: Realtime listeners stopped');
  }

  @override
  void dispose() {
    stopRealtimeListeners();
    _connectivitySubscription?.cancel();
  }
}
