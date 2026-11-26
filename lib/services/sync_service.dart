import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'app_widget_service.dart';

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
        AppLogger.warn(
          'Không thể decode JSON sync_queue data',
          tag: 'SyncService',
          error: e,
          stackTrace: st,
        );
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

/// Phân loại bản sao lưu đám mây
enum CloudBackupType { autoDaily, manual, preRestore }

extension CloudBackupTypeX on CloudBackupType {
  String get wireValue {
    switch (this) {
      case CloudBackupType.autoDaily:
        return 'auto_daily';
      case CloudBackupType.manual:
        return 'manual';
      case CloudBackupType.preRestore:
        return 'pre_restore';
    }
  }

  static CloudBackupType fromWire(
    String? value, {
    String? docId,
    String? label,
  }) {
    switch (value) {
      case 'auto_daily':
        return CloudBackupType.autoDaily;
      case 'pre_restore':
        return CloudBackupType.preRestore;
      case 'manual':
        return CloudBackupType.manual;
    }
    if (docId != null && docId.startsWith('daily_')) {
      return CloudBackupType.autoDaily;
    }
    final lower = (label ?? '').toLowerCase();
    if (lower.contains('cuối ngày') ||
        lower.contains('00:00') ||
        lower.contains('tự động') ||
        lower.contains('daily') ||
        lower.contains('auto')) {
      return CloudBackupType.autoDaily;
    }
    if (lower.contains('trước khi khôi phục') ||
        lower.contains('pre-restore') ||
        lower.contains('an toàn')) {
      return CloudBackupType.preRestore;
    }
    return CloudBackupType.manual;
  }
}

/// Tóm tắt một bản sao lưu đám mây trong `users/{uid}/backups/{backupId}`
class CloudBackupSummary {
  final String id;
  final DateTime backedUpAt;
  final int backedUpAtMs;
  final int walletCount;
  final int transactionCount;
  final int budgetCount;
  final int goalCount;
  final double totalBalance;
  final List<WalletModel> wallets;
  final String? label;
  final bool isLatestDoc;
  final CloudBackupType backupType;
  final String? dateKey;
  final bool hasTransactionsSnapshot;
  final int txChunkCount;
  final int schemaVersion;

  const CloudBackupSummary({
    required this.id,
    required this.backedUpAt,
    required this.backedUpAtMs,
    required this.walletCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.goalCount,
    required this.totalBalance,
    required this.wallets,
    this.label,
    this.isLatestDoc = false,
    this.backupType = CloudBackupType.manual,
    this.dateKey,
    this.hasTransactionsSnapshot = false,
    this.txChunkCount = 0,
    this.schemaVersion = 1,
  });

  bool get isAutoDaily => backupType == CloudBackupType.autoDaily;
  bool get isPreRestore => backupType == CloudBackupType.preRestore;

  String displayTitle({required bool isVi}) {
    switch (backupType) {
      case CloudBackupType.autoDaily:
        String dateStr;
        final parts = (dateKey ?? '').split('-');
        if (parts.length == 3) {
          dateStr = '${parts[2]}/${parts[1]}/${parts[0]}';
        } else {
          final d = backedUpAt.day.toString().padLeft(2, '0');
          final m = backedUpAt.month.toString().padLeft(2, '0');
          dateStr = '$d/$m/${backedUpAt.year}';
        }
        return isVi
            ? 'Sao lưu tự động • $dateStr'
            : 'Daily Auto Backup • $dateStr';
      case CloudBackupType.preRestore:
        return isVi
            ? 'Sao lưu trước khi khôi phục'
            : 'Pre-Restore Safety Backup';
      case CloudBackupType.manual:
        final raw = label?.trim();
        if (raw == null ||
            raw.isEmpty ||
            raw == 'Sao lưu thủ công' ||
            raw == 'Manual Backup' ||
            raw.contains('00:00')) {
          return isVi ? 'Sao lưu thủ công' : 'Manual Backup';
        }
        return raw;
    }
  }
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
  Future<bool> createCloudBackupSnapshot({
    String? label,
    String? backupId,
    CloudBackupType backupType = CloudBackupType.manual,
    String? dateKey,
    bool updateLatestPointer = true,
  });
  Future<bool> hasCloudBackup(String backupId);
  Future<bool> restoreLatestCloudBackup([String? uid]);
  Future<List<CloudBackupSummary>> listCloudBackups();
  Future<bool> restoreCloudBackupById(
    String backupId, {
    bool createSafetyBackup = true,
  });
  Future<bool> deleteCloudBackup(String backupId);
  Future<bool> syncSingleTransaction(String txId);
  Future<int> getPendingSyncCount();
  Future<int> getDeadCount();
  Future<List<Map<String, dynamic>>> getDeadLetterItems();
  Future<List<SyncQueueItem>> getDeadLetterItemsDetailed();
  Future<bool> retryDeadLetterItem(int queueId);
  Future<int> retryAllDeadLetters();
  void startRealtimeListeners();
  void ensureRealtimeListenersActive();
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
      } else if (newUid != _listenersUid ||
          snapshot?.epoch != _listenersEpoch) {
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

  static const int _expectedListenerCount = 7;

  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<User?>? _authStateSubscription;
  final List<StreamSubscription> _firestoreSubscriptions = [];
  String? _listenersUid;
  int? _listenersEpoch;
  Timer? _rtReconcileDebounce;
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
  bool _isRestoring = false;
  bool _isInitialized = false;
  bool _pendingResync = false;
  DateTime? _lastSyncTime;
  SyncExecutionReport? _lastReport;

  static const int _inlineBackupTxLimit = 350;
  static const int _backupTxChunkSize = 350;

  Future<void>? _currentRun;
  bool _accepting = true;
  static const int _maxRetry = 8;

  bool get isSyncing => _isSyncing;
  bool get isRestoring => _isRestoring;
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
      AppLogger.warn(
        'Lỗi retryAllDeadLetters',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
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
      AppLogger.warn(
        'Lỗi retryAllDeadLetters',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
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
      AppLogger.error(
        'Lỗi retryDeadLetterItem',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
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
      AppLogger.warn(
        'Lỗi retryAllDeadLetters',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
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

    // Lắng nghe khi mạng khôi phục → tự động re-auth, bật listener và sync toàn bộ nếu hợp lệ
    _connectivitySubscription?.cancel();
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
        ensureRealtimeListenersActive();
        if (_initialDownloadDone[uid] != true) {
          unawaited(initialDownload(uid));
        } else {
          unawaited(syncAll());
        }
      }
    });

    // Lắng nghe trạng thái FirebaseAuth để tự động kích hoạt Sync Engine ngay khi user hợp lệ
    _authStateSubscription?.cancel();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) {
      if (user != null && _isInitialized && _accepting) {
        if (SessionManager.instance.uidOrNull == null) {
          SessionManager.instance.activate(user.uid);
        }
        if (user.uid == SessionManager.instance.uidOrNull) {
          ensureRealtimeListenersActive();
          if (_initialDownloadDone[user.uid] != true) {
            unawaited(initialDownload(user.uid));
          } else {
            unawaited(syncAll());
          }
        }
      }
    });
  }

  /// Buộc tải lại toàn bộ dữ liệu từ cloud, bỏ qua mốc Delta Sync & sync_metadata cũ
  @override
  Future<SyncExecutionReport> forceFullResync() async {
    final session = SessionManager.instance;
    final ownerUid = session.uidOrNull;
    if (ownerUid != null) {
      await _clearDeltaSyncTimestamps(ownerUid);
      try {
        final db = await _dbHelper.database;
        await db.delete(
          'sync_metadata',
          where: 'uid = ?',
          whereArgs: [ownerUid],
        );
      } catch (e, st) {
        AppLogger.warn(
          'Không thể xóa sync_metadata khi forceFullResync',
          tag: 'SyncService',
          error: e,
          stackTrace: st,
        );
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
      if (_pendingResync &&
          _accepting &&
          SessionManager.instance.uidOrNull != null) {
        _pendingResync = false;
        unawaited(syncAll());
      }
    }
  }

  /// Đồng bộ toàn bộ dữ liệu với Khóa Mutex chống re-entrancy (trả về bool cho tương thích ngược)
  @override
  Future<bool> syncAll() async {
    final report = await syncAllDetailed();
    return !report.hasErrors;
  }

  /// Tải dữ liệu ban đầu khi mở app hoặc đăng nhập mới (chống chạy trùng theo UID).
  /// - Thiết bị đã từng sync (có mốc Delta Sync hoặc có ví synced cục bộ): chạy ngay Delta Sync + Realtime Listener (không tốn 2 round-trip restoreLatestCloudBackup).
  /// - Thiết bị mới / rỗng: khôi phục snapshot mới nhất từ Firebase trước, sau đó chạy full sync.
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

    ensureRealtimeListenersActive();

    // Kiểm tra thiết bị đã có trạng thái đồng bộ trước đó hay chưa
    var hasLocalSyncedState =
        await _getLastSyncTimestamp(targetUid, 'transactions') > 0;
    if (!hasLocalSyncedState) {
      try {
        final db = await _dbHelper.database;
        final walletRows = await db.query(
          'wallets',
          columns: ['id', 'balance', 'initialBalance', 'syncStatus'],
          where:
              "uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND syncStatus != 'local_only'",
          whereArgs: [targetUid],
        );
        hasLocalSyncedState = walletRows.any((r) {
          final id = r['id'] as String? ?? '';
          final bal = (r['balance'] as num?)?.toDouble() ?? 0.0;
          final initBal = (r['initialBalance'] as num?)?.toDouble() ?? 0.0;
          return id != 'wlt_default_$targetUid' || bal != 0 || initBal != 0;
        });
      } catch (_) {}
    }

    // 1. Chỉ tải restoreLatestCloudBackup cho thiết bị mới/rỗng để không làm trễ lần mở app hôm sau
    if (!hasLocalSyncedState) {
      try {
        await restoreLatestCloudBackup(targetUid);
      } catch (e) {
        debugPrint('SyncService: restoreLatestCloudBackup error: $e');
      }
    }

    // 2. Chạy chu kỳ sync (Delta Sync nếu đã có lastSyncTimestamp, hoặc Full Sync nếu mới)
    final report = await syncAllDetailed();
    final downloadFailed =
        report.downloadErrors.containsKey('wallets') ||
        report.downloadErrors.containsKey('transactions') ||
        !report.downloadSuccess.containsKey('wallets') ||
        report.uploadError == 'Device is offline.' ||
        report.uploadError == 'FirebaseAuth UID does not match Session UID.' ||
        report.uploadError == 'Another sync cycle is currently running.' ||
        report.uploadError == 'No valid session UID.' ||
        report.uploadError ==
            'SyncService is not accepting requests (quiesced).';

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

  /// Kiểm tra một bản sao lưu cụ thể đã tồn tại trên Firestore chưa (hỗ trợ idempotency cho sao lưu cuối ngày)
  @override
  Future<bool> hasCloudBackup(String backupId) async {
    if (backupId.trim().isEmpty) return false;
    final ownerUid = SessionManager.instance.uidOrNull;
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
    try {
      final doc = await _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .doc(backupId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Tạo một bản sao lưu toàn diện (Cloud Backup Snapshot) từ thiết bị hiện tại lên Firebase
  /// Bao gồm toàn bộ ví tiền, số dư, giao dịch (inline hoặc chia chunk `tx_chunks`), ngân sách và mục tiêu.
  /// Hỗ trợ `backupId` cố định (ví dụ `daily_YYYY-MM-DD` cho sao lưu cuối ngày) để chống trùng lặp đa thiết bị.
  @override
  Future<bool> createCloudBackupSnapshot({
    String? label,
    String? backupId,
    CloudBackupType backupType = CloudBackupType.manual,
    String? dateKey,
    bool updateLatestPointer = true,
  }) async {
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
      final ok = await _createCloudBackupSnapshotLocked(
        ownerUid: ownerUid,
        label: label,
        backupId: backupId,
        backupType: backupType,
        dateKey: dateKey,
        updateLatestPointer: updateLatestPointer,
        downloadAfterBackup: true,
      );
      return ok;
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
      if (_pendingResync &&
          _accepting &&
          SessionManager.instance.uidOrNull != null) {
        _pendingResync = false;
        unawaited(syncAll());
      }
    }
  }

  /// Core logic tạo bản sao lưu (yêu cầu caller đã giữ `_syncLock`)
  Future<bool> _createCloudBackupSnapshotLocked({
    required String ownerUid,
    String? label,
    String? backupId,
    CloudBackupType backupType = CloudBackupType.manual,
    String? dateKey,
    bool updateLatestPointer = true,
    bool downloadAfterBackup = false,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final resolvedDateKey =
        dateKey ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Đồng bộ 2 chiều đầy đủ trước khi chụp snapshot để không bao giờ ghi đè dữ liệu máy khác
    await _uploadPendingChanges();
    await _downloadFromFirestore();
    await LedgerReconciliationService().reconcileAll(ownerUid);

    // Chụp mốc maxQueueId trước khi đọc dữ liệu cục bộ để bảo vệ giao dịch mới phát sinh trong lúc upload
    final maxQueueRes = await db.rawQuery(
      'SELECT COALESCE(MAX(id), 0) as maxId FROM sync_queue WHERE ownerUid = ? OR uid = ?',
      [ownerUid, ownerUid],
    );
    final maxQueueIdBeforeUpload = (maxQueueRes.first['maxId'] as int?) ?? 0;

    // 2. Lấy toàn bộ ví đang có trên máy hiện tại (giữ nguyên updatedAt gốc)
    final localWalletRows = await db.query(
      'wallets',
      where: 'uid = ?',
      whereArgs: [ownerUid],
    );
    final activeLocalWallets = <Map<String, dynamic>>[];

    for (final row in localWalletRows) {
      final wId = row['id'] as String? ?? '';
      if (wId.isEmpty) continue;
      final isDel = (row['isDeleted'] as int? ?? 0) == 1;
      final rowUpdatedAt = (row['updatedAt'] as int?) ?? nowMs;

      final updatedRow = Map<String, dynamic>.from(row);
      updatedRow['uid'] = ownerUid;
      updatedRow['updatedAt'] = rowUpdatedAt;

      final fsData = _convertToFirestoreFormat(updatedRow, 'wallets');
      fsData['uid'] = ownerUid;
      await _firestore
          .collection('wallets')
          .doc(wId)
          .set(fsData, SetOptions(merge: true));

      await db.update(
        'wallets',
        {'syncStatus': 'synced'},
        where: 'id = ? AND uid = ? AND (updatedAt IS NULL OR updatedAt <= ?)',
        whereArgs: [wId, ownerUid, rowUpdatedAt],
      );

      if (!isDel) {
        activeLocalWallets.add(updatedRow);
      }
    }

    // 3. Chỉ dọn ví dư thừa khi sao lưu thủ công / pre_restore; TUYỆT ĐỐI không xóa trong autoDaily
    if (backupType != CloudBackupType.autoDaily) {
      try {
        final remoteWalletsSnap = await _firestore
            .collection('wallets')
            .where('uid', isEqualTo: ownerUid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));

        final activeLocalIds = activeLocalWallets
            .map((w) => w['id'] as String)
            .toSet();
        await _softDeleteExtraRemoteDocs(
          docs: remoteWalletsSnap.docs,
          keepIds: activeLocalIds,
          ownerUid: ownerUid,
          nowMs: nowMs,
          extraFields: const {'isDefault': false},
        );
      } catch (e) {
        debugPrint('SyncService: Clean remote extra wallets error: $e');
      }
    }

    // 4. Đồng bộ ĐẦY ĐỦ toàn bộ giao dịch, ngân sách, mục tiêu cục bộ lên Firestore
    final allLocalTxRows = await db.query(
      'transactions',
      where: 'uid = ?',
      whereArgs: [ownerUid],
    );
    final allLocalBudgetRows = await db.query(
      'budgets',
      where: 'uid = ?',
      whereArgs: [ownerUid],
    );
    final allLocalGoalRows = await db.query(
      'goals',
      where: 'uid = ?',
      whereArgs: [ownerUid],
    );

    await _batchUploadCollectionRows(
      collectionName: 'transactions',
      rows: allLocalTxRows,
      ownerUid: ownerUid,
    );
    await _batchUploadCollectionRows(
      collectionName: 'budgets',
      rows: allLocalBudgetRows,
      ownerUid: ownerUid,
    );
    await _batchUploadCollectionRows(
      collectionName: 'goals',
      rows: allLocalGoalRows,
      ownerUid: ownerUid,
    );

    // Chỉ đánh dấu synced cho các bản ghi đã thực sự nằm trong snapshot và chỉ xóa sync_queue <= maxQueueIdBeforeUpload
    await db.transaction((txn) async {
      final tablesAndRows = <String, List<Map<String, dynamic>>>{
        'transactions': allLocalTxRows,
        'budgets': allLocalBudgetRows,
        'goals': allLocalGoalRows,
      };
      for (final entry in tablesAndRows.entries) {
        for (final row in entry.value) {
          final id = row['id'] as String?;
          if (id == null || id.isEmpty) continue;
          final rowUpdatedAt = (row['updatedAt'] as int?) ?? nowMs;
          await txn.update(
            entry.key,
            {'syncStatus': 'synced'},
            where:
                'id = ? AND uid = ? AND (updatedAt IS NULL OR updatedAt <= ?)',
            whereArgs: [id, ownerUid, rowUpdatedAt],
          );
        }
      }
      await txn.delete(
        'sync_queue',
        where:
            "id <= ? AND tableName IN ('wallets', 'transactions', 'budgets', 'goals') AND (ownerUid = ? OR uid = ?)",
        whereArgs: [maxQueueIdBeforeUpload, ownerUid, ownerUid],
      );
    });

    final localTxRows = allLocalTxRows
        .where((r) => (r['isDeleted'] as int? ?? 0) == 0)
        .toList();
    final localBudgetRows = allLocalBudgetRows
        .where((r) => (r['isDeleted'] as int? ?? 0) == 0)
        .toList();
    final localGoalRows = allLocalGoalRows
        .where((r) => (r['isDeleted'] as int? ?? 0) == 0)
        .toList();

    final sanitizedWallets = activeLocalWallets
        .map((w) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(w))!)
        .toList();
    final sanitizedTxs = localTxRows.map((t) {
      final m = SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(t))!;
      m.remove('photoLocalPath'); // Đường dẫn local không dùng trên máy khác
      return m;
    }).toList();
    final sanitizedBudgets = localBudgetRows
        .map((b) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(b))!)
        .toList();
    final sanitizedGoals = localGoalRows
        .map((g) => SyncQueueWriter.sanitizeMap(Map<String, dynamic>.from(g))!)
        .toList();

    final totalBalance = activeLocalWallets.fold<double>(
      0.0,
      (total, w) => total + ((w['balance'] as num?)?.toDouble() ?? 0.0),
    );
    final resolvedBackupId =
        (backupId != null && backupId.trim().isNotEmpty && backupId != 'latest')
        ? backupId.trim()
        : 'backup_$nowMs';

    final backupsCol = _firestore
        .collection('users')
        .doc(ownerUid)
        .collection('backups');
    final backupDocRef = backupsCol.doc(resolvedBackupId);

    // Xử lý lưu transactions an toàn không vượt giới hạn 1 MiB của Firestore document
    int txChunkCount = 0;
    List<Map<String, dynamic>>? inlineTransactions;
    if (sanitizedTxs.length <= _inlineBackupTxLimit) {
      inlineTransactions = sanitizedTxs;
      // Nếu ghi đè doc cũ (vd daily_YYYY-MM-DD) từng có tx_chunks thì dọn sạch
      await _deleteBackupTxChunks(backupDocRef);
    } else {
      await _deleteBackupTxChunks(backupDocRef);
      txChunkCount = (sanitizedTxs.length / _backupTxChunkSize).ceil();
      for (int idx = 0; idx < txChunkCount; idx++) {
        final start = idx * _backupTxChunkSize;
        final end = min(start + _backupTxChunkSize, sanitizedTxs.length);
        final chunkItems = sanitizedTxs.sublist(start, end);
        await backupDocRef
            .collection('tx_chunks')
            .doc('chunk_$idx')
            .set({
              'index': idx,
              'count': chunkItems.length,
              'items': chunkItems,
            })
            .timeout(const Duration(seconds: 12));
      }
    }

    final dateParts = resolvedDateKey.split('-');
    final displayDate = dateParts.length == 3
        ? '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}'
        : resolvedDateKey;
    final defaultLabel = backupType == CloudBackupType.autoDaily
        ? 'Sao lưu tự động • $displayDate'
        : (backupType == CloudBackupType.preRestore
              ? 'Sao lưu trước khi khôi phục'
              : 'Sao lưu thủ công');

    final backupPayload = <String, dynamic>{
      'id': resolvedBackupId,
      'uid': ownerUid,
      'label': (label != null && label.trim().isNotEmpty)
          ? label.trim()
          : defaultLabel,
      'backupType': backupType.wireValue,
      'dateKey': resolvedDateKey,
      'schemaVersion': 2,
      'backedUpAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
      'backedUpAtMs': nowMs,
      'walletCount': sanitizedWallets.length,
      'transactionCount': sanitizedTxs.length,
      'budgetCount': sanitizedBudgets.length,
      'goalCount': sanitizedGoals.length,
      'totalBalance': totalBalance,
      'hasTransactionsSnapshot': true,
      'txChunkCount': txChunkCount,
      'wallets': sanitizedWallets,
      'budgets': sanitizedBudgets,
      'goals': sanitizedGoals,
      'transactions': ?inlineTransactions,
    };

    // Lưu bản sao lưu có lịch sử (versioned / daily)
    await backupDocRef.set(backupPayload).timeout(const Duration(seconds: 12));

    // Cập nhật con trỏ `latest` (không nhúng inline transactions để nhẹ & nhanh khi login máy mới)
    if (updateLatestPointer) {
      final latestPayload = Map<String, dynamic>.from(backupPayload)
        ..remove('transactions')
        ..['sourceBackupId'] = resolvedBackupId;
      await backupsCol
          .doc('latest')
          .set(latestPayload)
          .timeout(const Duration(seconds: 12));
    }

    // Dọn dẹp bản sao lưu cũ: giữ tối đa 30 bản cuối ngày + 10 bản thủ công/an toàn
    unawaited(_pruneOldCloudBackups(ownerUid, keepDaily: 30, keepOther: 10));

    if (downloadAfterBackup) {
      final rep = SyncExecutionReport();
      await _downloadFromFirestore(rep);
    }

    _lastSyncTime = DateTime.now();
    await _walletRepo?.getWallets();
    await _transactionRepo?.getAllTransactions();
    _walletRepo?.notifyChanged();
    _transactionRepo?.notifyTransactionsChanged();
    _budgetRepo?.notifyChanged();
    _goalRepo?.notifyChanged();
    return true;
  }

  /// Xóa subcollection `tx_chunks` của một backup doc (nếu có)
  Future<void> _deleteBackupTxChunks(
    DocumentReference<Map<String, dynamic>> backupDocRef,
  ) async {
    try {
      final chunksSnap = await backupDocRef
          .collection('tx_chunks')
          .get()
          .timeout(const Duration(seconds: 6));
      if (chunksSnap.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final c in chunksSnap.docs) {
        batch.delete(c.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('SyncService: _deleteBackupTxChunks error: $e');
    }
  }

  /// Dọn dẹp các bản sao lưu quá cũ (tách riêng quota cho `auto_daily` và `manual`/`pre_restore`, không xóa `latest`)
  Future<void> _pruneOldCloudBackups(
    String ownerUid, {
    int keepDaily = 30,
    int keepOther = 10,
  }) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .get()
          .timeout(const Duration(seconds: 8));

      int parseMs(QueryDocumentSnapshot<Map<String, dynamic>> d) {
        return FirestoreParse.parseInt(d.data()['backedUpAtMs']) ??
            FirestoreParse.parseDate(
              d.data()['backedUpAt'],
            )?.millisecondsSinceEpoch ??
            0;
      }

      final dailyDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final otherDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final d in snap.docs) {
        if (d.id == 'latest') continue;
        final bType = CloudBackupTypeX.fromWire(
          d.data()['backupType']?.toString(),
          docId: d.id,
          label: d.data()['label']?.toString(),
        );
        if (bType == CloudBackupType.autoDaily) {
          dailyDocs.add(d);
        } else {
          otherDocs.add(d);
        }
      }

      dailyDocs.sort((a, b) => parseMs(b).compareTo(parseMs(a)));
      otherDocs.sort((a, b) => parseMs(b).compareTo(parseMs(a)));

      final toDelete = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        if (dailyDocs.length > keepDaily) ...dailyDocs.skip(keepDaily),
        if (otherDocs.length > keepOther) ...otherDocs.skip(keepOther),
      ];

      for (final oldDoc in toDelete) {
        await _deleteBackupTxChunks(oldDoc.reference);
        await oldDoc.reference.delete();
      }
    } catch (e) {
      debugPrint('SyncService: _pruneOldCloudBackups error: $e');
    }
  }

  /// Lấy danh sách tất cả các bản sao lưu đám mây của người dùng (mới nhất lên đầu)
  @override
  Future<List<CloudBackupSummary>> listCloudBackups() async {
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return const [];

    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) return const [];
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.uid != ownerUid) return const [];

    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('users')
            .doc(ownerUid)
            .collection('backups')
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        snap = await _firestore
            .collection('users')
            .doc(ownerUid)
            .collection('backups')
            .get()
            .timeout(const Duration(seconds: 8));
      }

      final allParsed = <CloudBackupSummary>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final rawWallets = data['wallets'] as List<dynamic>? ?? const [];
        final wallets = <WalletModel>[];
        for (final item in rawWallets) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['uid'] = ownerUid;
            map['syncStatus'] = 'synced';
            wallets.add(WalletModel.fromSqlite(map));
          }
        }
        final backedUpAtMs =
            FirestoreParse.parseInt(data['backedUpAtMs']) ??
            FirestoreParse.parseDate(
              data['backedUpAt'],
            )?.millisecondsSinceEpoch ??
            0;
        final totalBal = data['totalBalance'] != null
            ? FirestoreParse.parseDouble(data['totalBalance'])
            : wallets.fold<double>(0.0, (total, w) => total + w.balance);
        final rawBudgets = data['budgets'] as List<dynamic>? ?? const [];
        final rawGoals = data['goals'] as List<dynamic>? ?? const [];
        final label = data['label']?.toString();
        final backupType = CloudBackupTypeX.fromWire(
          data['backupType']?.toString(),
          docId: doc.id,
          label: label,
        );
        final txChunkCount = FirestoreParse.parseInt(data['txChunkCount']) ?? 0;
        final hasTxSnapshot =
            data['hasTransactionsSnapshot'] == true ||
            data['transactions'] is List ||
            txChunkCount > 0;

        allParsed.add(
          CloudBackupSummary(
            id: doc.id,
            backedUpAt: DateTime.fromMillisecondsSinceEpoch(backedUpAtMs),
            backedUpAtMs: backedUpAtMs,
            walletCount:
                FirestoreParse.parseInt(data['walletCount']) ?? wallets.length,
            transactionCount:
                FirestoreParse.parseInt(data['transactionCount']) ?? 0,
            budgetCount:
                FirestoreParse.parseInt(data['budgetCount']) ??
                rawBudgets.length,
            goalCount:
                FirestoreParse.parseInt(data['goalCount']) ?? rawGoals.length,
            totalBalance: totalBal,
            wallets: wallets,
            label: label,
            isLatestDoc: doc.id == 'latest',
            backupType: backupType,
            dateKey: data['dateKey']?.toString(),
            hasTransactionsSnapshot: hasTxSnapshot,
            txChunkCount: txChunkCount,
            schemaVersion: FirestoreParse.parseInt(data['schemaVersion']) ?? 1,
          ),
        );
      }

      // Ẩn con trỏ `latest` nếu đã có ít nhất 1 bản sao lưu có phiên bản/theo ngày
      final hasVersioned = allParsed.any((b) => !b.isLatestDoc);
      final filtered =
          allParsed.where((b) => !hasVersioned || !b.isLatestDoc).toList()
            ..sort((a, b) => b.backedUpAtMs.compareTo(a.backedUpAtMs));

      return filtered;
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi listCloudBackups',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  /// Khôi phục chính xác một bản sao lưu đã chọn (`users/{uid}/backups/{backupId}`)
  /// 1. Tự động tạo bản sao lưu an toàn trước khi khôi phục (nếu `createSafetyBackup == true`)
  /// 2. Khôi phục nguyên tử toàn bộ ví, giao dịch (nếu có trong snapshot), ngân sách, mục tiêu vào SQLite
  /// 3. Đồng bộ ngược toàn bộ dữ liệu đã khôi phục lên Firestore + cập nhật `backups/latest`
  ///    để mọi thiết bị đều khớp 100% theo bản backup vừa chọn.
  @override
  Future<bool> restoreCloudBackupById(
    String backupId, {
    bool createSafetyBackup = true,
  }) async {
    if (!_accepting || backupId.trim().isEmpty) return false;
    final ownerUid = SessionManager.instance.uidOrNull;
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

    final activeRun = _currentRun;
    if (activeRun != null && _syncLock.isLocked) {
      try {
        await activeRun.timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    final acquired = await _syncLock.tryAcquire();
    if (!acquired) return false;

    _isSyncing = true;
    _isRestoring = true;
    try {
      final backupRef = _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .doc(backupId);

      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await backupRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        doc = await backupRef.get().timeout(const Duration(seconds: 8));
      }

      if (!doc.exists || doc.data() == null) return false;
      final data = doc.data()!;

      final rawWallets = data['wallets'] as List<dynamic>? ?? const [];
      final restoredWallets = <WalletModel>[];
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final nowDt = DateTime.fromMillisecondsSinceEpoch(nowMs);

      for (final item in rawWallets) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          map['uid'] = ownerUid;
          map['syncStatus'] = 'synced';
          map['isDeleted'] = 0;
          final parsed = WalletModel.fromSqlite(map);
          if (parsed.id.isNotEmpty) {
            restoredWallets.add(
              parsed.copyWith(
                uid: ownerUid,
                updatedAt: nowDt,
                syncStatus: 'synced',
                isDeleted: false,
              ),
            );
          }
        }
      }

      if (restoredWallets.isEmpty) return false;

      // Đảm bảo có đúng 1 ví mặc định
      if (!restoredWallets.any((w) => w.isDefault)) {
        restoredWallets[0] = restoredWallets[0].copyWith(isDefault: true);
      }

      // Đọc transactions từ snapshot (nếu bản backup schema v2 có lưu giao dịch)
      final txChunkCount = FirestoreParse.parseInt(data['txChunkCount']) ?? 0;
      final hasTxSnapshot =
          data['hasTransactionsSnapshot'] == true ||
          data['transactions'] is List ||
          txChunkCount > 0;
      final restoredTxRows = <Map<String, dynamic>>[];

      if (hasTxSnapshot) {
        final rawTxs = <dynamic>[];
        if (txChunkCount > 0) {
          final chunksSnap = await backupRef
              .collection('tx_chunks')
              .orderBy('index')
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 12));
          for (final cDoc in chunksSnap.docs) {
            final items = cDoc.data()['items'] as List<dynamic>? ?? const [];
            rawTxs.addAll(items);
          }
        } else if (data['transactions'] is List) {
          rawTxs.addAll(data['transactions'] as List<dynamic>);
        }

        for (final item in rawTxs) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['uid'] = ownerUid;
            map['syncStatus'] = 'synced';
            map['isDeleted'] = 0;
            map['updatedAt'] = nowMs;
            final parsed = TransactionModel.fromSqlite(map);
            if (parsed.id.isNotEmpty) {
              final row = parsed
                  .copyWith(
                    uid: ownerUid,
                    updatedAt: nowDt,
                    syncStatus: 'synced',
                    isDeleted: false,
                  )
                  .toSqlite();
              row['uid'] = ownerUid;
              restoredTxRows.add(row);
            }
          }
        }
      }

      final rawBudgets = data['budgets'] as List<dynamic>?;
      final restoredBudgetRows = <Map<String, dynamic>>[];
      if (rawBudgets != null) {
        for (final item in rawBudgets) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['uid'] = ownerUid;
            map['syncStatus'] = 'synced';
            map['isDeleted'] = 0;
            map['updatedAt'] = nowMs;
            final bRow = BudgetModel.fromSqlite(map).toSqlite();
            bRow['uid'] = ownerUid;
            if ((bRow['id'] as String? ?? '').isNotEmpty) {
              restoredBudgetRows.add(bRow);
            }
          }
        }
      }

      final rawGoals = data['goals'] as List<dynamic>?;
      final restoredGoalRows = <Map<String, dynamic>>[];
      if (rawGoals != null) {
        for (final item in rawGoals) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['uid'] = ownerUid;
            map['syncStatus'] = 'synced';
            map['isDeleted'] = 0;
            map['updatedAt'] = nowMs;
            final gRow = GoalModel.fromSqlite(map).toSqlite();
            gRow['uid'] = ownerUid;
            if ((gRow['id'] as String? ?? '').isNotEmpty) {
              restoredGoalRows.add(gRow);
            }
          }
        }
      }

      final db = await _dbHelper.database;

      // 0. Tự động tạo bản sao lưu an toàn trước khi ghi đè (chống khôi phục nhầm mất dữ liệu hiện tại)
      if (createSafetyBackup && backupId != 'latest') {
        try {
          final existingWallets = await db.query(
            'wallets',
            columns: ['id'],
            where: 'uid = ? AND (isDeleted IS NULL OR isDeleted = 0)',
            whereArgs: [ownerUid],
            limit: 1,
          );
          if (existingWallets.isNotEmpty) {
            await _createCloudBackupSnapshotLocked(
              ownerUid: ownerUid,
              label: 'Sao lưu an toàn trước khi khôi phục',
              backupType: CloudBackupType.preRestore,
              updateLatestPointer: false,
              downloadAfterBackup: false,
            );
          }
        } catch (e) {
          debugPrint(
            'SyncService: Pre-restore safety backup failed (continuing): $e',
          );
        }
      }

      // 1. Áp dụng nguyên tử vào SQLite cục bộ & xóa hàng chờ cũ của các bảng được khôi phục
      await db.transaction((txn) async {
        await txn.delete(
          'sync_queue',
          where: "tableName = 'wallets' AND (ownerUid = ? OR uid = ?)",
          whereArgs: [ownerUid, ownerUid],
        );
        await txn.delete('wallets', where: 'uid = ?', whereArgs: [ownerUid]);
        for (final w in restoredWallets) {
          final row = w.toSqlite();
          row['uid'] = ownerUid;
          await txn.insert(
            'wallets',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (hasTxSnapshot) {
          await txn.delete(
            'sync_queue',
            where: "tableName = 'transactions' AND (ownerUid = ? OR uid = ?)",
            whereArgs: [ownerUid, ownerUid],
          );
          await txn.delete(
            'transactions',
            where: 'uid = ?',
            whereArgs: [ownerUid],
          );
          for (final tRow in restoredTxRows) {
            await txn.insert(
              'transactions',
              tRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        if (rawBudgets != null) {
          await txn.delete(
            'sync_queue',
            where: "tableName = 'budgets' AND (ownerUid = ? OR uid = ?)",
            whereArgs: [ownerUid, ownerUid],
          );
          await txn.delete('budgets', where: 'uid = ?', whereArgs: [ownerUid]);
          for (final bRow in restoredBudgetRows) {
            await txn.insert(
              'budgets',
              bRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        if (rawGoals != null) {
          await txn.delete(
            'sync_queue',
            where: "tableName = 'goals' AND (ownerUid = ? OR uid = ?)",
            whereArgs: [ownerUid, ownerUid],
          );
          await txn.delete('goals', where: 'uid = ?', whereArgs: [ownerUid]);
          for (final gRow in restoredGoalRows) {
            await txn.insert(
              'goals',
              gRow,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      // 2. Đồng bộ trạng thái vừa khôi phục lên Firestore cho TẤT CẢ các bảng đã khôi phục
      final restoredWalletRows = restoredWallets.map((w) {
        final r = w.toSqlite();
        r['uid'] = ownerUid;
        return r;
      }).toList();
      await _batchUploadCollectionRows(
        collectionName: 'wallets',
        rows: restoredWalletRows,
        ownerUid: ownerUid,
      );
      await _softDeleteExtraRemoteCollection(
        collectionName: 'wallets',
        keepIds: restoredWallets.map((w) => w.id).toSet(),
        ownerUid: ownerUid,
        nowMs: nowMs,
        extraFields: const {'isDefault': false},
      );

      if (hasTxSnapshot) {
        await _batchUploadCollectionRows(
          collectionName: 'transactions',
          rows: restoredTxRows,
          ownerUid: ownerUid,
        );
        await _softDeleteExtraRemoteCollection(
          collectionName: 'transactions',
          keepIds: restoredTxRows.map((r) => r['id'] as String).toSet(),
          ownerUid: ownerUid,
          nowMs: nowMs,
        );
      }

      if (rawBudgets != null) {
        await _batchUploadCollectionRows(
          collectionName: 'budgets',
          rows: restoredBudgetRows,
          ownerUid: ownerUid,
        );
        await _softDeleteExtraRemoteCollection(
          collectionName: 'budgets',
          keepIds: restoredBudgetRows.map((r) => r['id'] as String).toSet(),
          ownerUid: ownerUid,
          nowMs: nowMs,
        );
      }

      if (rawGoals != null) {
        await _batchUploadCollectionRows(
          collectionName: 'goals',
          rows: restoredGoalRows,
          ownerUid: ownerUid,
        );
        await _softDeleteExtraRemoteCollection(
          collectionName: 'goals',
          keepIds: restoredGoalRows.map((r) => r['id'] as String).toSet(),
          ownerUid: ownerUid,
          nowMs: nowMs,
        );
      }

      // 3. Cập nhật con trỏ `users/{uid}/backups/latest` khớp với bản vừa khôi phục
      final sanitizedWallets = restoredWallets
          .map((w) => SyncQueueWriter.sanitizeMap(w.toSqlite())!)
          .toList();
      final totalBalance = restoredWallets.fold<double>(
        0.0,
        (total, w) => total + w.balance,
      );
      final latestData = Map<String, dynamic>.from(data)
        ..remove('transactions')
        ..['uid'] = ownerUid
        ..['sourceBackupId'] = backupId
        ..['backedUpAt'] = Timestamp.fromMillisecondsSinceEpoch(nowMs)
        ..['backedUpAtMs'] = nowMs
        ..['walletCount'] = sanitizedWallets.length
        ..['totalBalance'] = totalBalance
        ..['wallets'] = sanitizedWallets;
      await _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .doc('latest')
          .set(latestData)
          .timeout(const Duration(seconds: 10));

      // 4. Làm mới cache & thông báo toàn bộ UI + App Widget
      _lastSyncTime = DateTime.now();
      await _walletRepo?.getWallets();
      await _transactionRepo?.getAllTransactions();
      _walletRepo?.notifyChanged();
      _transactionRepo?.notifyTransactionsChanged();
      _budgetRepo?.notifyChanged();
      _goalRepo?.notifyChanged();
      unawaited(AppWidgetService.instance.updateWidgetBalance());

      return true;
    } catch (e, st) {
      AppLogger.error(
        'Lỗi restoreCloudBackupById($backupId)',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
      return false;
    } finally {
      _isRestoring = false;
      _isSyncing = false;
      _syncLock.release();
      if (_pendingResync &&
          _accepting &&
          SessionManager.instance.uidOrNull != null) {
        _pendingResync = false;
        unawaited(syncAll());
      }
    }
  }

  /// Soft-delete các doc dư thừa trên Firestore không nằm trong `keepIds` theo từng WriteBatch (tối đa 400 ops/batch)
  Future<void> _softDeleteExtraRemoteCollection({
    required String collectionName,
    required Set<String> keepIds,
    required String ownerUid,
    required int nowMs,
    Map<String, dynamic> extraFields = const {},
  }) async {
    try {
      final snap = await _firestore
          .collection(collectionName)
          .where('uid', isEqualTo: ownerUid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      await _softDeleteExtraRemoteDocs(
        docs: snap.docs,
        keepIds: keepIds,
        ownerUid: ownerUid,
        nowMs: nowMs,
        extraFields: extraFields,
      );
    } catch (e) {
      debugPrint(
        'SyncService: _softDeleteExtraRemoteCollection($collectionName) error: $e',
      );
    }
  }

  Future<void> _softDeleteExtraRemoteDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Set<String> keepIds,
    required String ownerUid,
    required int nowMs,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final extras = docs
        .where((d) => !keepIds.contains(d.id) && d.data()['isDeleted'] != true)
        .toList();
    if (extras.isEmpty) return;

    const maxBatchOps = 400;
    for (var i = 0; i < extras.length; i += maxBatchOps) {
      final end = min(i + maxBatchOps, extras.length);
      final batch = _firestore.batch();
      for (var j = i; j < end; j++) {
        batch.set(extras[j].reference, {
          'uid': ownerUid,
          'isDeleted': true,
          'deletedAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(nowMs),
          ...extraFields,
        }, SetOptions(merge: true));
      }
      await batch.commit().timeout(const Duration(seconds: 15));
    }
  }

  /// Xóa một bản sao lưu cũ trong `users/{uid}/backups/{backupId}` (không xóa `latest`)
  @override
  Future<bool> deleteCloudBackup(String backupId) async {
    if (backupId.trim().isEmpty || backupId == 'latest') return false;
    final ownerUid = SessionManager.instance.uidOrNull;
    if (ownerUid == null) return false;
    if (FirebaseAuth.instance.currentUser?.uid != ownerUid) return false;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(ownerUid)
          .collection('backups')
          .doc(backupId);
      await _deleteBackupTxChunks(docRef);
      await docRef.delete().timeout(const Duration(seconds: 8));
      return true;
    } catch (e, st) {
      AppLogger.warn(
        'Lỗi deleteCloudBackup($backupId)',
        tag: 'SyncService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Đẩy hàng loạt bản ghi SQLite của 1 bảng lên Firestore theo từng WriteBatch (tối đa 400 ops/batch)
  Future<void> _batchUploadCollectionRows({
    required String collectionName,
    required List<Map<String, Object?>> rows,
    required String ownerUid,
  }) async {
    if (rows.isEmpty) return;
    const maxBatchOps = 400;
    for (var i = 0; i < rows.length; i += maxBatchOps) {
      final end = min(i + maxBatchOps, rows.length);
      final batch = _firestore.batch();
      var opsInBatch = 0;
      for (var j = i; j < end; j++) {
        final row = Map<String, dynamic>.from(rows[j]);
        final recordId = row['id'] as String? ?? '';
        if (recordId.isEmpty) continue;
        row['uid'] = ownerUid;
        final fsData = _convertToFirestoreFormat(row, collectionName);
        fsData['uid'] = ownerUid;
        fsData.remove('id');
        batch.set(
          _firestore.collection(collectionName).doc(recordId),
          fsData,
          SetOptions(merge: true),
        );
        opsInBatch++;
      }
      if (opsInBatch > 0) {
        await batch.commit().timeout(const Duration(seconds: 15));
      }
    }
  }

  /// Tự động lấy và khôi phục bản sao lưu mới nhất (`users/{uid}/backups/latest` và `wallets` trên Firebase)
  /// AN TOÀN:
  /// 1. KHÔNG BAO GIỜ ghi đè ví cục bộ hoặc xóa `sync_queue` nếu máy hiện tại đang có thay đổi chưa đồng bộ.
  /// 2. Luôn so sánh giữa `backups/latest` và collection `wallets` trực tiếp trên Firestore để lấy bản MỚI NHẤT
  ///    (tránh bản sao lưu thủ công cũ ghi đè lại số dư đã trừ/cộng sau các giao dịch gần đây).
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

      // Bảo vệ tuyệt đối: nếu máy hiện tại có giao dịch/ví đang chờ đẩy lên Cloud,
      // bỏ qua bước ghi đè snapshot để luồng syncAll() đẩy thay đổi cục bộ lên trước.
      final pendingLocalQueue = await db.query(
        'sync_queue',
        columns: ['id'],
        where:
            "tableName IN ('wallets', 'transactions') AND (ownerUid = ? OR uid = ?) AND status IN ('pending', 'processing')",
        whereArgs: [targetUid, targetUid],
        limit: 1,
      );
      final pendingLocalWallets = await db.query(
        'wallets',
        columns: ['id'],
        where: "uid = ? AND syncStatus = 'pending'",
        whereArgs: [targetUid],
        limit: 1,
      );
      if (pendingLocalQueue.isNotEmpty || pendingLocalWallets.isNotEmpty) {
        debugPrint(
          'SyncService: Local pending wallet/tx changes detected, skipping backup overwrite for $targetUid',
        );
        return false;
      }

      // Kiểm tra máy hiện tại đã có ví thực hay là thiết bị mới/rỗng
      final existingActiveLocalWallets = await db.query(
        'wallets',
        where:
            "uid = ? AND (isDeleted IS NULL OR isDeleted = 0) AND syncStatus != 'local_only'",
        whereArgs: [targetUid],
      );
      final hasLocalSyncedWallets = existingActiveLocalWallets.any((r) {
        final id = r['id'] as String? ?? '';
        final bal = (r['balance'] as num?)?.toDouble() ?? 0.0;
        final initBal = (r['initialBalance'] as num?)?.toDouble() ?? 0.0;
        return id != 'wlt_default_$targetUid' || bal != 0 || initBal != 0;
      });

      // 1. Đọc bản sao lưu thủ công `users/{uid}/backups/latest` (nếu có)
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
        try {
          backupDoc = await _firestore
              .collection('users')
              .doc(targetUid)
              .collection('backups')
              .doc('latest')
              .get()
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
      }

      final backupWalletsById = <String, WalletModel>{};
      if (backupDoc != null && backupDoc.exists && backupDoc.data() != null) {
        final data = backupDoc.data()!;
        final rawWallets = data['wallets'] as List<dynamic>?;
        if (rawWallets != null && rawWallets.isNotEmpty) {
          for (final item in rawWallets) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              map['uid'] = targetUid;
              map['syncStatus'] = 'synced';
              final w = WalletModel.fromSqlite(map);
              if (w.id.isNotEmpty) {
                backupWalletsById[w.id] = w;
              }
            }
          }
        }
      }

      // 2. Luôn đọc thêm collection `wallets` trực tiếp trên Firestore (luôn cập nhật theo mỗi giao dịch)
      final liveWalletsById = <String, WalletModel>{};
      try {
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
        ).where((w) => w.uid == targetUid);
        for (final w in parsed) {
          liveWalletsById[w.id] = w;
        }
      } catch (e) {
        debugPrint('SyncService: restoreBackup live wallets fetch error: $e');
      }

      // 3. Hợp nhất theo từng ví: bản nào có updatedAt mới hơn thì thắng
      // (tránh snapshot `backups/latest` cũ đè mất các giao dịch mới trên `wallets`)
      final mergedById = <String, WalletModel>{...backupWalletsById};
      for (final entry in liveWalletsById.entries) {
        final id = entry.key;
        final liveW = entry.value;
        final backupW = mergedById[id];
        if (backupW == null || !backupW.updatedAt.isAfter(liveW.updatedAt)) {
          mergedById[id] = liveW;
        }
      }

      var authoritativeWallets = mergedById.values
          .where((w) => !w.isDeleted && w.uid == targetUid)
          .toList();

      // Lọc bỏ ví mặc định 0đ tự sinh (wlt_default_*) nếu đã có ví thật khác
      final defaultWid = 'wlt_default_$targetUid';
      final hasRealWallets = authoritativeWallets.any(
        (w) => w.id != defaultWid,
      );
      if (hasRealWallets) {
        authoritativeWallets = authoritativeWallets
            .where(
              (w) =>
                  w.id != defaultWid || w.balance != 0 || w.initialBalance != 0,
            )
            .toList();
      }

      if (authoritativeWallets.isEmpty) return false;

      // Nếu máy hiện tại đã có ví synced cục bộ, hợp nhất an toàn qua upsertFromFirestore (LWW + Dirty Shield)
      // thay vì xóa trắng và ghi đè mù quáng.
      if (hasLocalSyncedWallets) {
        await _walletRepo?.upsertFromFirestore(authoritativeWallets);
        debugPrint(
          'SyncService: Merged ${authoritativeWallets.length} cloud wallets via LWW for $targetUid',
        );
        return true;
      }

      // Thiết bị mới / chưa có ví thật: khôi phục toàn bộ từ bản hợp nhất mới nhất
      final rawBudgets =
          backupDoc != null && backupDoc.exists && backupDoc.data() != null
          ? (backupDoc.data()!['budgets'] as List<dynamic>?)
          : null;
      final rawGoals =
          backupDoc != null && backupDoc.exists && backupDoc.data() != null
          ? (backupDoc.data()!['goals'] as List<dynamic>?)
          : null;

      await db.transaction((txn) async {
        // Kiểm tra lại trong transaction đề phòng user vừa thao tác trong lúc chờ mạng
        final racePending = await txn.query(
          'sync_queue',
          columns: ['id'],
          where:
              "tableName IN ('wallets', 'transactions') AND (ownerUid = ? OR uid = ?) AND status IN ('pending', 'processing')",
          whereArgs: [targetUid, targetUid],
          limit: 1,
        );
        if (racePending.isNotEmpty) return;

        // Xóa các ví cục bộ tạm/không nằm trong bản sao lưu mới nhất
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

        // Ghi đè toàn bộ ví chuẩn từ bản sao lưu mới nhất
        for (final w in authoritativeWallets) {
          final row = w
              .copyWith(syncStatus: 'synced', isDeleted: false)
              .toSqlite();
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
        'SyncService: Restored ${authoritativeWallets.length} wallets from latest cloud state for $targetUid',
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
  Future<void> _recoverStaleProcessingItems(
    Database db,
    String ownerUid,
  ) async {
    const leaseTimeoutMs = 120000; // 2 phút lease timeout
    final staleThreshold =
        DateTime.now().millisecondsSinceEpoch - leaseTimeoutMs;
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
        for (final table in const [
          'wallets',
          'transactions',
          'budgets',
          'goals',
        ]) {
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

        // 3. Đảm bảo mọi bản ghi có syncStatus == 'pending' trên 4 bảng tài chính đều có item đầy đủ trong sync_queue
        const tablePriorities = <String, int>{
          'wallets': 1,
          'budgets': 2,
          'goals': 2,
          'transactions': 3,
        };
        for (final entry in tablePriorities.entries) {
          final table = entry.key;
          final priority = entry.value;
          final dirtyRows = await txn.query(
            table,
            where: "uid = ? AND syncStatus = 'pending'",
            whereArgs: [ownerUid],
          );
          for (final row in dirtyRows) {
            final recordId = row['id'] as String? ?? '';
            if (recordId.isEmpty) continue;
            final isDel = (row['isDeleted'] as int? ?? 0) == 1;

            final existingQueue = await txn.query(
              'sync_queue',
              where:
                  "tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN ('pending', 'processing')",
              whereArgs: [table, recordId, ownerUid, ownerUid],
              limit: 1,
            );

            bool hasCompletePayload = false;
            if (existingQueue.isNotEmpty) {
              final raw = existingQueue.first['data'] as String?;
              if (raw != null) {
                try {
                  final parsed = json.decode(raw) as Map<String, dynamic>;
                  if (table == 'wallets') {
                    hasCompletePayload =
                        (parsed['name'] as String?)?.trim().isNotEmpty ==
                            true &&
                        parsed.containsKey('balance') &&
                        parsed.containsKey('initialBalance');
                  } else if (table == 'transactions') {
                    hasCompletePayload =
                        parsed.containsKey('amount') &&
                        parsed.containsKey('walletId') &&
                        parsed.containsKey('type');
                  } else {
                    hasCompletePayload = parsed.containsKey('id');
                  }
                } catch (_) {}
              }
            }

            if (!hasCompletePayload) {
              final payload = Map<String, Object?>.from(row);
              payload['uid'] = ownerUid;
              payload['syncStatus'] = 'pending';

              await txn.delete(
                'sync_queue',
                where:
                    "tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status = 'pending'",
                whereArgs: [table, recordId, ownerUid, ownerUid],
              );
              await txn.insert('sync_queue', {
                'uid': ownerUid,
                'ownerUid': ownerUid,
                'tableName': table,
                'recordId': recordId,
                'action': isDel ? 'SOFT_DELETE' : 'INSERT',
                'data': json.encode(payload),
                'createdAt': nowMs,
                'updatedAt': nowMs,
                'retryCount': 0,
                'nextRetryAt': 0,
                'status': 'pending',
                'priority': priority,
              });
            }
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
            await txn.delete(
              'sync_queue',
              where: 'id = ? AND (ownerUid = ? OR uid = ?)',
              whereArgs: [qid, ownerUid, ownerUid],
            );
            if (action != 'DELETE' &&
                action != 'SOFT_DELETE' &&
                action != 'UPDATE_ALL_READ') {
              // Chỉ đánh dấu 'synced' khi không còn thay đổi mới hơn đang nằm trong sync_queue cho cùng bản ghi
              final remaining = await txn.query(
                'sync_queue',
                columns: ['id'],
                where:
                    "tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN ('pending', 'processing')",
                whereArgs: [table, recordId, ownerUid, ownerUid],
                limit: 1,
              );
              if (remaining.isEmpty) {
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
            }
          });
          count++;
          batchSucceeded++;
        } on FirebaseException catch (e) {
          final retry = (item['retryCount'] as int? ?? 0) + 1;
          final isAuthError = e.code == 'unauthenticated';
          final terminal =
              e.code == 'permission-denied' ||
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
            final nextRetry = terminal
                ? 0
                : batchNowMs + _calculateBackoff(retry);
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
          final nextRetry = terminal
              ? 0
              : batchNowMs + _calculateBackoff(retry);
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
      final groupId =
          data?['groupId'] as String? ??
          (recordId.contains('_') ? recordId.split('_').first : '');
      final memberUid =
          data?['userId'] as String? ??
          (recordId.contains('_') ? recordId.split('_').last : ownerUid);
      if (groupId.isNotEmpty && memberUid.isNotEmpty) {
        final groupDoc = _firestore.collection('groups').doc(groupId);
        if (action == 'INSERT' ||
            (action == 'UPDATE' && data?['status'] == 'active')) {
          await groupDoc.set({
            'memberIds': FieldValue.arrayUnion([memberUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (action == 'DELETE' ||
            action == 'SOFT_DELETE' ||
            (action == 'UPDATE' && data?['status'] == 'left')) {
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
                    ? Timestamp.fromMillisecondsSinceEpoch(
                        data['deletedAt'] as int,
                      )
                    : FieldValue.serverTimestamp())
              : FieldValue.serverTimestamp(),
          'updatedAt': data?['updatedAt'] != null
              ? (data!['updatedAt'] is int
                    ? Timestamp.fromMillisecondsSinceEpoch(
                        data['updatedAt'] as int,
                      )
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
          AppLogger.warn(
            'Không thể decode JSON sync_queue data',
            tag: 'SyncService',
            error: e,
            stackTrace: st,
          );
        }
      }
    }

    return result;
  }

  // ════════ DOWNLOAD (Cloud → Local) ════════
  // Bulkhead Pattern + Delta Sync (SharedPreferences theo userId) + Song song hóa (Future.wait)

  static const int _deltaSkewBufferMs = 5000;
  static const List<String> _deltaEntities = [
    'wallets',
    'transactions',
    'budgets',
    'goals',
    'notifications',
    'messages',
    'groups',
    'group_expenses',
    'group_settlements',
    'users',
  ];

  static String _deltaPrefKey(String uid, String entityName) =>
      'delta_sync_ts_${uid}_$entityName';

  static String _userLastSyncPrefKey(String uid) => 'last_sync_ts_$uid';

  Future<int> _getLastSyncTimestamp(String uid, String entityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_deltaPrefKey(uid, entityName)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _setLastSyncTimestamp(
    Database? db,
    String uid,
    String entityName,
    int timestampMs,
  ) async {
    if (timestampMs <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _deltaPrefKey(uid, entityName);
      final prev = prefs.getInt(key) ?? 0;
      final next = timestampMs > prev ? timestampMs : prev;
      await prefs.setInt(key, next);

      final userKey = _userLastSyncPrefKey(uid);
      final prevUserTs = prefs.getInt(userKey) ?? 0;
      if (next > prevUserTs) {
        await prefs.setInt(userKey, next);
      }
    } catch (_) {}

    if (db != null) {
      await _recordSyncTimestamp(db, entityName, uid, timestampMs);
    }
  }

  Future<void> _clearDeltaSyncTimestamps(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entity in _deltaEntities) {
        await prefs.remove(_deltaPrefKey(uid, entity));
      }
      await prefs.remove(_userLastSyncPrefKey(uid));
    } catch (_) {}
  }

  static int _computeNextSyncCursor(
    Iterable<DateTime?> docUpdatedAts,
    int fallbackNowMs,
  ) {
    var maxMs = fallbackNowMs;
    for (final dt in docUpdatedAts) {
      if (dt != null && dt.millisecondsSinceEpoch > maxMs) {
        maxMs = dt.millisecondsSinceEpoch;
      }
    }
    return maxMs;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _executeDeltaQuery({
    required Query<Map<String, dynamic>> baseQuery,
    required int lastSyncMs,
    required String entityName,
    bool preferServer = false,
  }) async {
    final effectiveQuery = lastSyncMs > 0
        ? baseQuery.where(
            'updatedAt',
            isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(
              max(0, lastSyncMs - _deltaSkewBufferMs),
            ),
          )
        : baseQuery;

    Future<QuerySnapshot<Map<String, dynamic>>> run(
      Query<Map<String, dynamic>> q,
    ) async {
      if (preferServer) {
        try {
          return await q
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 8));
        } on FirebaseException catch (fe) {
          if (fe.code == 'failed-precondition') rethrow;
        } catch (_) {}
      }
      return await q.get().timeout(const Duration(seconds: 8));
    }

    try {
      return await run(effectiveQuery);
    } on FirebaseException catch (fe) {
      if (fe.code == 'failed-precondition' && lastSyncMs > 0) {
        AppLogger.warn(
          'Thiếu Composite Index trên Firestore cho $entityName (updatedAt > cursor), fallback về query gốc.',
          tag: 'SyncService',
          error: fe,
        );
        return await run(baseQuery);
      }
      rethrow;
    }
  }

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
            whereArgs: [
              'wallets',
              id,
              ownerUid,
              ownerUid,
              'pending',
              'processing',
            ],
            limit: 1,
          );
          if (pending.isNotEmpty) continue;

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final effectiveUpdatedAt =
              remote != null && remote.updatedAt.millisecondsSinceEpoch >= nowMs
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

      final metaRows = await db.query(
        'sync_metadata',
        columns: ['lastSyncTimestamp'],
        where: 'uid = ? AND entityName = ?',
        whereArgs: [ownerUid, 'transactions'],
        limit: 1,
      );
      final lastTxSyncTs = metaRows.isNotEmpty
          ? (metaRows.first['lastSyncTimestamp'] as int?) ?? 0
          : 0;

      var enqueued = 0;
      await db.transaction((txn) async {
        for (final row in localRows) {
          final id = row['id'] as String? ?? '';
          if (id.isEmpty) continue;

          final remote = remoteTxsById[id];
          if (remote != null) continue;

          final syncStatus = row['syncStatus'] as String? ?? 'synced';
          final createdAt = (row['createdAt'] as int?) ?? 0;
          final isNewlyCreatedLocal =
              syncStatus == 'pending' ||
              lastTxSyncTs == 0 ||
              createdAt > lastTxSyncTs;
          if (!isNewlyCreatedLocal) {
            continue; // Không hồi sinh giao dịch cũ đã bị xóa cứng trên server
          }

          final pending = await txn.query(
            'sync_queue',
            columns: ['id'],
            where:
                'tableName = ? AND recordId = ? AND (ownerUid = ? OR uid = ?) AND status IN (?, ?)',
            whereArgs: [
              'transactions',
              id,
              ownerUid,
              ownerUid,
              'pending',
              'processing',
            ],
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
    final userGroupIds = <String>{};

    // Đọc song song các mốc lastSyncTimestamp theo từng userId trong SharedPreferences
    final tsResults = await Future.wait([
      _getLastSyncTimestamp(ownerUid, 'wallets'),
      _getLastSyncTimestamp(ownerUid, 'transactions'),
      _getLastSyncTimestamp(ownerUid, 'budgets'),
      _getLastSyncTimestamp(ownerUid, 'goals'),
      _getLastSyncTimestamp(ownerUid, 'notifications'),
      _getLastSyncTimestamp(ownerUid, 'messages'),
      _getLastSyncTimestamp(ownerUid, 'groups'),
      _getLastSyncTimestamp(ownerUid, 'group_expenses'),
      _getLastSyncTimestamp(ownerUid, 'group_settlements'),
    ]);
    final lastWalletsTs = tsResults[0];
    final lastTxTs = tsResults[1];
    final lastBudgetsTs = tsResults[2];
    final lastGoalsTs = tsResults[3];
    final lastNotiTs = tsResults[4];
    final lastMsgTs = tsResults[5];
    final lastGroupsTs = tsResults[6];
    final lastExpensesTs = tsResults[7];
    final lastSettlementsTs = tsResults[8];

    // Giai đoạn 1: Tải song song (Future.wait) tất cả các bảng độc lập bằng Delta Sync
    await Future.wait([
      // 1. Wallets
      () async {
        if (!stillValid()) return;
        try {
          final walletSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('wallets')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastWalletsTs,
            entityName: 'wallets',
            preferServer: true,
          );

          final remoteWallets = FirestoreParse.parseList(
            walletSnapshot.docs,
            WalletModel.fromFirestore,
            tag: 'SyncService.wallets',
          );

          if (stillValid() && remoteWallets.isNotEmpty) {
            await _walletRepo?.upsertFromFirestore(remoteWallets);
            report?.downloadSuccess['wallets'] = remoteWallets.length;
            final cursor = _computeNextSyncCursor(
              remoteWallets.map((w) => w.updatedAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'wallets', cursor);
            walletsDownloadOk = true;
          } else if (!walletSnapshot.metadata.isFromCache) {
            report?.downloadSuccess['wallets'] = 0;
            await _setLastSyncTimestamp(db, ownerUid, 'wallets', nowMs);
            walletsDownloadOk = true;
          } else {
            report?.downloadErrors['wallets'] =
                'Wallets snapshot served from cache.';
          }

          // Self-healing backfill chỉ chạy khi full sync (lastWalletsTs == 0)
          if (stillValid() &&
              lastWalletsTs == 0 &&
              !walletSnapshot.metadata.isFromCache) {
            final remoteById = {for (final w in remoteWallets) w.id: w};
            await _backfillMissingLocalWallets(db, ownerUid, remoteById);
          }
        } catch (e) {
          report?.downloadErrors['wallets'] = e.toString();
          debugPrint('SyncService: Error downloading wallets: $e');
        }
      }(),

      // 2. Transactions
      () async {
        if (!stillValid()) return;
        try {
          final txSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('transactions')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastTxTs,
            entityName: 'transactions',
            preferServer: true,
          );

          final transactions = FirestoreParse.parseList(
            txSnapshot.docs,
            TransactionModel.fromFirestore,
            tag: 'SyncService.transactions',
          );

          if (stillValid() && transactions.isNotEmpty) {
            await _transactionRepo?.upsertFromFirestore(transactions);
            report?.downloadSuccess['transactions'] = transactions.length;
            final cursor = _computeNextSyncCursor(
              transactions.map((t) => t.updatedAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'transactions', cursor);
            transactionsDownloadOk = true;
          } else if (!txSnapshot.metadata.isFromCache) {
            report?.downloadSuccess['transactions'] = 0;
            await _setLastSyncTimestamp(db, ownerUid, 'transactions', nowMs);
            transactionsDownloadOk = true;
          } else {
            report?.downloadErrors['transactions'] =
                'Transactions snapshot served from cache.';
          }

          // Self-healing backfill chỉ chạy khi full sync (lastTxTs == 0)
          if (stillValid() &&
              lastTxTs == 0 &&
              !txSnapshot.metadata.isFromCache) {
            final remoteTxsById = {for (final t in transactions) t.id: t};
            await _backfillMissingLocalTransactions(
              db,
              ownerUid,
              remoteTxsById,
            );
          }
        } catch (e) {
          report?.downloadErrors['transactions'] = e.toString();
          debugPrint('SyncService: Error downloading transactions: $e');
        }
      }(),

      // 3. Budgets
      () async {
        if (!stillValid()) return;
        try {
          final budgetSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('budgets')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastBudgetsTs,
            entityName: 'budgets',
          );
          if (stillValid() && budgetSnapshot.docs.isNotEmpty) {
            final budgets = FirestoreParse.parseList(
              budgetSnapshot.docs,
              BudgetModel.fromFirestore,
              tag: 'SyncService.budgets',
            );
            await _budgetRepo?.upsertFromFirestore(budgets);
            report?.downloadSuccess['budgets'] = budgets.length;
            final cursor = _computeNextSyncCursor(
              budgets.map((b) => b.updatedAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'budgets', cursor);
          } else {
            report?.downloadSuccess['budgets'] = 0;
            if (!budgetSnapshot.metadata.isFromCache) {
              await _setLastSyncTimestamp(db, ownerUid, 'budgets', nowMs);
            }
          }
        } catch (e) {
          report?.downloadErrors['budgets'] = e.toString();
          debugPrint('SyncService: Error downloading budgets: $e');
        }
      }(),

      // 4. Goals
      () async {
        if (!stillValid()) return;
        try {
          final goalSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('goals')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastGoalsTs,
            entityName: 'goals',
          );
          if (stillValid() && goalSnapshot.docs.isNotEmpty) {
            final goals = FirestoreParse.parseList(
              goalSnapshot.docs,
              GoalModel.fromFirestore,
              tag: 'SyncService.goals',
            );
            await _goalRepo?.upsertFromFirestore(goals);
            report?.downloadSuccess['goals'] = goals.length;
            final cursor = _computeNextSyncCursor(
              goals.map((g) => g.updatedAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'goals', cursor);
          } else {
            report?.downloadSuccess['goals'] = 0;
            if (!goalSnapshot.metadata.isFromCache) {
              await _setLastSyncTimestamp(db, ownerUid, 'goals', nowMs);
            }
          }
        } catch (e) {
          report?.downloadErrors['goals'] = e.toString();
          debugPrint('SyncService: Error downloading goals: $e');
        }
      }(),

      // 5. User profile
      () async {
        if (!stillValid()) return;
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
            await _setLastSyncTimestamp(db, ownerUid, 'users', nowMs);
          } else {
            report?.downloadSuccess['users'] = 0;
          }
        } catch (e) {
          report?.downloadErrors['users'] = e.toString();
          debugPrint('SyncService: Error downloading user profile: $e');
        }
      }(),

      // 6. Notifications
      () async {
        if (!stillValid()) return;
        try {
          final notiSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('notifications')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastNotiTs,
            entityName: 'notifications',
          );
          if (stillValid() && notiSnapshot.docs.isNotEmpty) {
            final notifications = FirestoreParse.parseList(
              notiSnapshot.docs,
              NotificationModel.fromFirestore,
              tag: 'SyncService.notifications',
            );
            await _notificationRepo?.upsertFromFirestore(notifications);
            report?.downloadSuccess['notifications'] = notifications.length;
            final cursor = _computeNextSyncCursor(
              notifications.map((n) => n.updatedAt ?? n.createdAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'notifications', cursor);
          } else {
            report?.downloadSuccess['notifications'] = 0;
            if (!notiSnapshot.metadata.isFromCache) {
              await _setLastSyncTimestamp(
                db,
                ownerUid,
                'notifications',
                nowMs,
              );
            }
          }
        } catch (e) {
          report?.downloadErrors['notifications'] = e.toString();
          debugPrint('SyncService: Error downloading notifications: $e');
        }
      }(),

      // 7. Messages
      () async {
        if (!stillValid()) return;
        try {
          final msgSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('messages')
                .where('uid', isEqualTo: ownerUid),
            lastSyncMs: lastMsgTs,
            entityName: 'messages',
          );
          if (stillValid() && msgSnapshot.docs.isNotEmpty) {
            final messages = FirestoreParse.parseList(
              msgSnapshot.docs,
              MessageModel.fromFirestore,
              tag: 'SyncService.messages',
            );
            await _messageRepo?.upsertFromFirestore(messages);
            report?.downloadSuccess['messages'] = messages.length;
            final cursor = _computeNextSyncCursor(
              messages.map((m) => m.updatedAt ?? m.createdAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'messages', cursor);
          } else {
            report?.downloadSuccess['messages'] = 0;
            if (!msgSnapshot.metadata.isFromCache) {
              await _setLastSyncTimestamp(db, ownerUid, 'messages', nowMs);
            }
          }
        } catch (e) {
          report?.downloadErrors['messages'] = e.toString();
          debugPrint('SyncService: Error downloading messages: $e');
        }
      }(),

      // 8. Groups (Quỹ nhóm mà user là thành viên)
      () async {
        if (!stillValid()) return;
        try {
          final groupSnapshot = await _executeDeltaQuery(
            baseQuery: _firestore
                .collection('groups')
                .where('memberIds', arrayContains: ownerUid),
            lastSyncMs: lastGroupsTs,
            entityName: 'groups',
          );
          if (stillValid() && groupSnapshot.docs.isNotEmpty) {
            final groups = FirestoreParse.parseList(groupSnapshot.docs, (doc) {
              final d = Map<String, dynamic>.from(
                doc.data() as Map<String, dynamic>? ?? {},
              );
              d['id'] = doc.id;
              return GroupModel.fromJson(d);
            }, tag: 'SyncService.groups');
            await _groupRepo?.upsertFromFirestore(groups);
            userGroupIds.addAll(
              groups.where((g) => !g.isDeleted).map((g) => g.id),
            );
            report?.downloadSuccess['groups'] = groups.length;
            final cursor = _computeNextSyncCursor(
              groups.map((g) => g.updatedAt),
              nowMs,
            );
            await _setLastSyncTimestamp(db, ownerUid, 'groups', cursor);
          } else {
            report?.downloadSuccess['groups'] = 0;
            if (!groupSnapshot.metadata.isFromCache) {
              await _setLastSyncTimestamp(db, ownerUid, 'groups', nowMs);
            }
          }

          // Nếu là Delta Sync, lấy thêm danh sách nhóm đang hoạt động từ SQLite cục bộ để sync expenses/settlements mới
          if (lastGroupsTs > 0 || userGroupIds.isEmpty) {
            final localGroups = await db.query(
              'groups',
              columns: ['id'],
              where: 'isDeleted = 0',
            );
            for (final r in localGroups) {
              final gid = r['id'] as String?;
              if (gid != null && gid.isNotEmpty) userGroupIds.add(gid);
            }
          }
        } catch (e) {
          report?.downloadErrors['groups'] = e.toString();
          debugPrint('SyncService: Error downloading groups: $e');
        }
      }(),
    ]);

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

    // Giai đoạn 2: Group Expenses & Settlements (chạy song song các chunk 10 nhóm bằng Future.wait)
    if (stillValid() && userGroupIds.isNotEmpty) {
      final groupIdList = userGroupIds.toList();
      const chunkSize = 10;
      final chunkFutures = <Future<void>>[];
      var maxExpenseCursor = nowMs;
      var maxSettlementCursor = nowMs;

      for (var i = 0; i < groupIdList.length; i += chunkSize) {
        final chunkIndex = i;
        final chunk = groupIdList.sublist(
          i,
          min(i + chunkSize, groupIdList.length),
        );
        chunkFutures.add(() async {
          if (!stillValid()) return;
          try {
            await Future.wait([
              () async {
                final expenseSnapshot = await _executeDeltaQuery(
                  baseQuery: _firestore
                      .collection('expenses')
                      .where('groupId', whereIn: chunk),
                  lastSyncMs: lastExpensesTs,
                  entityName: 'expenses',
                );
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
                  maxExpenseCursor = max(
                    maxExpenseCursor,
                    _computeNextSyncCursor(
                      expenses.map((e) => e.updatedAt),
                      nowMs,
                    ),
                  );
                }
              }(),
              () async {
                final settlementSnapshot = await _executeDeltaQuery(
                  baseQuery: _firestore
                      .collection('settlements')
                      .where('groupId', whereIn: chunk),
                  lastSyncMs: lastSettlementsTs,
                  entityName: 'settlements',
                );
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
                  maxSettlementCursor = max(
                    maxSettlementCursor,
                    _computeNextSyncCursor(
                      settlements.map((s) => s.updatedAt),
                      nowMs,
                    ),
                  );
                }
              }(),
            ]);
          } catch (e) {
            report?.downloadErrors['group_expenses_chunk_$chunkIndex'] = e
                .toString();
            debugPrint(
              'SyncService: Error downloading group expenses/settlements chunk $chunkIndex: $e',
            );
          }
        }());
      }

      await Future.wait(chunkFutures);
      await Future.wait([
        _setLastSyncTimestamp(db, ownerUid, 'group_expenses', maxExpenseCursor),
        _setLastSyncTimestamp(
          db,
          ownerUid,
          'group_settlements',
          maxSettlementCursor,
        ),
      ]);
    }

    // 10. Ledger Reconciliation: Chỉ đối soát khi wallets hoặc transactions vừa tải thành công
    if (stillValid() && (walletsDownloadOk || transactionsDownloadOk)) {
      try {
        await LedgerReconciliationService().reconcileAll(ownerUid);
        debugPrint(
          'SyncService: Ledger reconciliation completed for $ownerUid',
        );
      } catch (e) {
        debugPrint('SyncService: Ledger reconciliation error: $e');
      }
    }
  }

  // ════════ REALTIME LISTENERS ════════

  /// Đảm bảo realtime listeners đang hoạt động cho phiên & epoch hiện tại.
  @override
  void ensureRealtimeListenersActive() {
    final session = SessionManager.instance;
    final ownerUid = session.uidOrNull;
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (!_accepting ||
        ownerUid == null ||
        authUid == null ||
        authUid != ownerUid) {
      return;
    }
    if (_firestoreSubscriptions.length >= _expectedListenerCount &&
        _listenersUid == ownerUid &&
        _listenersEpoch == session.epoch) {
      return;
    }
    startRealtimeListeners();
  }

  void _scheduleRealtimeReconcile(String ownerUid, bool Function() stillValid) {
    _rtReconcileDebounce?.cancel();
    _rtReconcileDebounce = Timer(const Duration(milliseconds: 150), () async {
      if (!stillValid() || _isRestoring) return;
      await LedgerReconciliationService().reconcileAll(ownerUid);
    });
  }

  Future<void> _softDeleteRemovedFromRealtime(
    String table,
    String ownerUid,
    List<String> removedIds, {
    bool hasUidColumn = true,
    VoidCallback? onChanged,
  }) async {
    if (removedIds.isEmpty) return;
    try {
      final db = await _dbHelper.database;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final placeholders = List.filled(removedIds.length, '?').join(',');
      final where = hasUidColumn
          ? 'id IN ($placeholders) AND uid = ? AND syncStatus = ? AND (isDeleted IS NULL OR isDeleted = 0)'
          : 'id IN ($placeholders) AND syncStatus = ? AND (isDeleted IS NULL OR isDeleted = 0)';
      final args = hasUidColumn
          ? [...removedIds, ownerUid, 'synced']
          : [...removedIds, 'synced'];
      final updated = await db.update(
        table,
        {
          'isDeleted': 1,
          'deletedAt': nowMs,
          'updatedAt': nowMs,
          'syncStatus': 'synced',
        },
        where: where,
        whereArgs: args,
      );
      if (updated > 0) {
        onChanged?.call();
      }
    } catch (e) {
      debugPrint('SyncService: Realtime softDelete ($table) error: $e');
    }
  }

  List<DocumentSnapshot<Map<String, dynamic>>> _changedDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docChanges
        .where(
          (c) =>
              c.type == DocumentChangeType.added ||
              c.type == DocumentChangeType.modified,
        )
        .map((c) => c.doc)
        .toList();
  }

  List<String> _removedDocIds(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docChanges
        .where((c) => c.type == DocumentChangeType.removed)
        .map((c) => c.doc.id)
        .toList();
  }

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
    _listenersEpoch = epoch;
    bool stillValid() => session.isStillValid(epoch, ownerUid);

    // Lắng nghe thay đổi transactions
    _firestoreSubscriptions.add(
      _firestore
          .collection('transactions')
          .where('uid', isEqualTo: ownerUid)
          .snapshots()
          .listen(
            (snapshot) async {
              if (!stillValid() || _isRestoring) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final transactions = FirestoreParse.parseList(
                    changedDocs,
                    TransactionModel.fromFirestore,
                    tag: 'SyncService.rt.transactions',
                  );
                  await _transactionRepo?.upsertFromFirestore(transactions);
                  if (!snapshot.metadata.isFromCache && transactions.isNotEmpty) {
                    final cursor = _computeNextSyncCursor(
                      transactions.map((t) => t.updatedAt),
                      DateTime.now().millisecondsSinceEpoch,
                    );
                    unawaited(
                      _setLastSyncTimestamp(
                        null,
                        ownerUid,
                        'transactions',
                        cursor,
                      ),
                    );
                  }
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'transactions',
                    ownerUid,
                    removedIds,
                    onChanged: () =>
                        _transactionRepo?.notifyTransactionsChanged(),
                  );
                }
                if (stillValid() && !_isRestoring) {
                  _scheduleRealtimeReconcile(ownerUid, stillValid);
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
              if (!stillValid() || _isRestoring) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final wallets = FirestoreParse.parseList(
                    changedDocs,
                    WalletModel.fromFirestore,
                    tag: 'SyncService.rt.wallets',
                  );
                  await _walletRepo?.upsertFromFirestore(wallets);
                  if (!snapshot.metadata.isFromCache && wallets.isNotEmpty) {
                    final cursor = _computeNextSyncCursor(
                      wallets.map((w) => w.updatedAt),
                      DateTime.now().millisecondsSinceEpoch,
                    );
                    unawaited(
                      _setLastSyncTimestamp(null, ownerUid, 'wallets', cursor),
                    );
                  }
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'wallets',
                    ownerUid,
                    removedIds,
                    onChanged: () => _walletRepo?.notifyChanged(),
                  );
                }
                if (stillValid() && !_isRestoring) {
                  _scheduleRealtimeReconcile(ownerUid, stillValid);
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
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final groups = FirestoreParse.parseList(changedDocs, (doc) {
                    final d = Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>? ?? {},
                    );
                    d['id'] = doc.id;
                    return GroupModel.fromJson(d);
                  }, tag: 'SyncService.rt.groups');
                  await _groupRepo?.upsertFromFirestore(groups);
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'groups',
                    ownerUid,
                    removedIds,
                    hasUidColumn: false,
                  );
                }
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
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final budgets = FirestoreParse.parseList(
                    changedDocs,
                    BudgetModel.fromFirestore,
                    tag: 'SyncService.rt.budgets',
                  );
                  await _budgetRepo?.upsertFromFirestore(budgets);
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'budgets',
                    ownerUid,
                    removedIds,
                    onChanged: () => _budgetRepo?.notifyChanged(),
                  );
                }
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
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final goals = FirestoreParse.parseList(
                    changedDocs,
                    GoalModel.fromFirestore,
                    tag: 'SyncService.rt.goals',
                  );
                  await _goalRepo?.upsertFromFirestore(goals);
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'goals',
                    ownerUid,
                    removedIds,
                    onChanged: () => _goalRepo?.notifyChanged(),
                  );
                }
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
            (snapshot) async {
              if (!stillValid()) return;
              if (snapshot.docChanges.isNotEmpty) {
                final changedDocs = _changedDocs(snapshot);
                final removedIds = _removedDocIds(snapshot);
                if (changedDocs.isNotEmpty) {
                  final notifications = FirestoreParse.parseList(
                    changedDocs,
                    NotificationModel.fromFirestore,
                    tag: 'SyncService.rt.notifications',
                  );
                  await _notificationRepo?.upsertFromFirestore(notifications);
                }
                if (removedIds.isNotEmpty) {
                  await _softDeleteRemovedFromRealtime(
                    'notifications',
                    ownerUid,
                    removedIds,
                  );
                }
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
    _rtReconcileDebounce?.cancel();
    _rtReconcileDebounce = null;
    for (final sub in _firestoreSubscriptions) {
      sub.cancel();
    }
    _firestoreSubscriptions.clear();
    _listenersUid = null;
    _listenersEpoch = null;
    debugPrint('SyncService: Realtime listeners stopped');
  }

  @override
  void dispose() {
    stopRealtimeListeners();
    _connectivitySubscription?.cancel();
    _authStateSubscription?.cancel();
  }
}
