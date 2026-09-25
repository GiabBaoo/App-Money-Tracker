import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/local/database_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/message_repository.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../models/message_model.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';

/// Service đồng bộ 2 chiều giữa SQLite (local) và Firestore (cloud).
///
/// Chiến lược:
/// - Upload: Đọc sync_queue → đẩy lên Firestore
/// - Download: Lắng nghe Firestore → cập nhật SQLite
/// - Xung đột: Last Write Wins (dựa trên updatedAt)
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ConnectivityService _connectivity = ConnectivityService();

  TransactionRepository? _transactionRepo;
  WalletRepository? _walletRepo;
  UserRepository? _userRepo;
  NotificationRepository? _notificationRepo;
  MessageRepository? _messageRepo;

  StreamSubscription<bool>? _connectivitySubscription;
  final List<StreamSubscription> _firestoreSubscriptions = [];

  bool _isSyncing = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Lấy số lượng thay đổi đang chờ đồng bộ trong sync_queue
  Future<int> getPendingSyncCount() async {
    try {
      final db = await _dbHelper.database;
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
      return (res.first['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Khởi tạo SyncService với các repository
  void init({
    required TransactionRepository transactionRepo,
    required UserRepository userRepo,
    required NotificationRepository notificationRepo,
    required MessageRepository messageRepo,
    WalletRepository? walletRepo,
  }) {
    _transactionRepo = transactionRepo;
    _userRepo = userRepo;
    _notificationRepo = notificationRepo;
    _messageRepo = messageRepo;
    _walletRepo = walletRepo ?? WalletRepository();
    _isInitialized = true;

    // Lắng nghe khi mạng khôi phục → tự động re-auth và sync toàn bộ
    _connectivitySubscription = _connectivity.onlineStream.listen((isOnline) async {
      if (isOnline && _isInitialized) {
        debugPrint('SyncService: Network restored, checking silent re-auth & syncing...');
        if (FirebaseAuth.instance.currentUser == null) {
          await AuthService().silentReauthenticateIfNeeded();
        }
        syncAll();
      }
    });
  }

  /// Đồng bộ ngay lập tức (alias của syncAll)
  Future<bool> syncNow() => syncAll();

  /// Đồng bộ toàn bộ dữ liệu (gọi khi mở app + khi mạng khôi phục)
  Future<bool> syncAll() async {
    if (_isSyncing) return false;

    // Tự động khởi tạo repositories nếu chưa có
    if (!_isInitialized) {
      _transactionRepo ??= TransactionRepository();
      _walletRepo ??= WalletRepository();
      _userRepo ??= UserRepository();
      _notificationRepo ??= NotificationRepository();
      _messageRepo ??= MessageRepository();
      _isInitialized = true;
    }

    // Kiểm tra kết nối mạng thực tế
    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) {
        debugPrint('SyncService: Offline, skipping sync');
        return false;
      }
    }

    // Tự động silent re-authenticate nếu currentUser đang null
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }

    _isSyncing = true;
    debugPrint('SyncService: Starting full sync...');

    try {
      // 1. Upload local changes → Firestore
      final uploadedCount = await _uploadPendingChanges();

      // 2. Download from Firestore → SQLite
      await _downloadFromFirestore();

      _lastSyncTime = DateTime.now();
      debugPrint('SyncService: Full sync completed ($uploadedCount uploaded)');
      return true;
    } catch (e) {
      debugPrint('SyncService: Sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Đồng bộ trực tiếp 1 giao dịch cụ thể từ SQLite lên Firestore
  Future<bool> syncSingleTransaction(String txId) async {
    // 1. Kiểm tra mạng thực tế
    if (!_connectivity.isOnline) {
      final hasNet = await _connectivity.checkRealInternet();
      if (!hasNet) {
        throw Exception('Thiết bị đang không có kết nối Internet. Vui lòng kiểm tra WiFi hoặc 4G.');
      }
    }

    // 2. Kiểm tra xác thực Firebase Auth (thử silent re-auth trước)
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService().silentReauthenticateIfNeeded();
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('Chưa có phiên xác thực với Firebase. Vui lòng kiểm tra kết nối mạng để hệ thống tự động cấp quyền đồng bộ.');
    }

    final db = await _dbHelper.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [txId], limit: 1);
    if (rows.isEmpty) {
      throw Exception('Không tìm thấy giao dịch trong cơ sở dữ liệu');
    }

    final tx = TransactionModel.fromSqlite(rows.first);
    final firestoreData = _convertToFirestoreFormat(tx.toSqlite(), 'transactions');

    // Đảm bảo UID của giao dịch khớp với tài khoản Firebase đang đăng nhập để thỏa mãn Security Rules
    if (firestoreData['uid'] == null || firestoreData['uid'].toString().isEmpty || firestoreData['uid'] != authUser.uid) {
      firestoreData['uid'] = authUser.uid;
      await db.update('transactions', {'uid': authUser.uid}, where: 'id = ?', whereArgs: [txId]);
    }
    firestoreData.remove('id');

    try {
      // Đẩy trực tiếp lên Firestore
      await _firestore.collection('transactions').doc(txId).set(firestoreData, SetOptions(merge: true));
    } on FirebaseException catch (fe) {
      if (fe.code == 'permission-denied') {
        throw Exception('Firebase từ chối quyền truy cập (permission-denied). Vui lòng kiểm tra Firestore Security Rules trên Firebase Console hoặc đăng nhập lại tài khoản.');
      }
      throw Exception('Lỗi Firebase (${fe.code}): ${fe.message}');
    }

    // Cập nhật trạng thái 'synced' trong SQLite
    await db.update('transactions', {'syncStatus': 'synced'}, where: 'id = ?', whereArgs: [txId]);

    // Xóa khỏi sync_queue nếu có
    await db.delete('sync_queue', where: 'tableName = ? AND recordId = ?', whereArgs: ['transactions', txId]);

    // Thông báo cho các listeners
    _transactionRepo?.notifyTransactionsChanged();

    debugPrint('SyncService: Successfully synced single tx: $txId');
    return true;
  }

  /// Tải dữ liệu ban đầu từ Firestore về SQLite (chỉ chạy lần đầu)
  Future<void> initialDownload() async {
    if (!_connectivity.isOnline) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    debugPrint('SyncService: Initial download for user $uid');

    try {
      // Kiểm tra xem SQLite đã có dữ liệu chưa
      final db = await _dbHelper.database;
      final existingTx = await db.query('transactions', where: 'uid = ?', whereArgs: [uid], limit: 1);

      if (existingTx.isEmpty) {
        // SQLite trống → tải toàn bộ từ Firestore
        await _downloadFromFirestore();
        debugPrint('SyncService: Initial download completed');
      } else {
        debugPrint('SyncService: SQLite already has data, skipping initial download');
      }
    } catch (e) {
      debugPrint('SyncService: Initial download error: $e');
    }
  }

  // ════════ UPLOAD (Local → Cloud) ════════

  Future<int> _uploadPendingChanges() async {
    final db = await _dbHelper.database;
    final queue = await db.query('sync_queue', orderBy: 'createdAt ASC');
    int count = 0;

    if (queue.isNotEmpty) {
      debugPrint('SyncService: Uploading ${queue.length} pending changes...');
      for (final item in queue) {
        try {
          final tableName = item['tableName'] as String;
          final recordId = item['recordId'] as String;
          final action = item['action'] as String;
          final dataStr = item['data'] as String?;
          final data = dataStr != null ? json.decode(dataStr) as Map<String, dynamic> : null;

          await _uploadSingleItem(tableName, recordId, action, data);

          // Cập nhật trạng thái 'synced' vào bảng SQLite nguồn nếu không phải DELETE
          if (action != 'DELETE') {
            try {
              await db.update(
                tableName,
                {'syncStatus': 'synced'},
                where: 'id = ?',
                whereArgs: [recordId],
              );
            } catch (_) {}
          }

          // Xóa khỏi queue sau khi thành công
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
          count++;
        } catch (e) {
          debugPrint('SyncService: Failed to upload item ${item['id']}: $e');
          // Tăng retry count
          final retryCount = (item['retryCount'] as int? ?? 0) + 1;
          if (retryCount > 5) {
            // Bỏ qua sau 5 lần thử
            await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
          } else {
            await db.update('sync_queue', {'retryCount': retryCount}, where: 'id = ?', whereArgs: [item['id']]);
          }
        }
      }
    } else {
      debugPrint('SyncService: No pending changes in queue, checking unsynced rows...');
    }

    // Luôn quét thêm các giao dịch và ví còn sót syncStatus != 'synced' trong SQLite (chỉ khi có authUser)
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      try {
        final pendingTxRows = await db.query(
          'transactions',
          where: 'syncStatus != ?',
          whereArgs: ['synced'],
          limit: 100,
        );
        for (final row in pendingTxRows) {
          final txId = row['id'] as String;
          try {
            final tx = TransactionModel.fromSqlite(row);
            final firestoreData = _convertToFirestoreFormat(tx.toSqlite(), 'transactions');
            if (firestoreData['uid'] == null || firestoreData['uid'].toString().isEmpty || firestoreData['uid'] != authUser.uid) {
              firestoreData['uid'] = authUser.uid;
              await db.update('transactions', {'uid': authUser.uid}, where: 'id = ?', whereArgs: [txId]);
            }
            firestoreData.remove('id');
            await _firestore.collection('transactions').doc(txId).set(firestoreData, SetOptions(merge: true));
            await db.update('transactions', {'syncStatus': 'synced'}, where: 'id = ?', whereArgs: [txId]);
            count++;
          } catch (e) {
            debugPrint('SyncService: sweep upload error for tx $txId: $e');
          }
        }

        // Quét vét các ví chưa đồng bộ lên Firestore
        final pendingWalletRows = await db.query(
          'wallets',
          where: 'syncStatus != ?',
          whereArgs: ['synced'],
          limit: 100,
        );
        for (final row in pendingWalletRows) {
          final walletId = row['id'] as String;
          try {
            final wallet = WalletModel.fromSqlite(row);
            final firestoreData = _convertToFirestoreFormat(wallet.toSqlite(), 'wallets');
            if (firestoreData['uid'] == null || firestoreData['uid'].toString().isEmpty || firestoreData['uid'] != authUser.uid) {
              firestoreData['uid'] = authUser.uid;
              await db.update('wallets', {'uid': authUser.uid}, where: 'id = ?', whereArgs: [walletId]);
            }
            firestoreData.remove('id');
            await _firestore.collection('wallets').doc(walletId).set(firestoreData, SetOptions(merge: true));
            await db.update('wallets', {'syncStatus': 'synced'}, where: 'id = ?', whereArgs: [walletId]);
            count++;
          } catch (e) {
            debugPrint('SyncService: sweep upload error for wallet $walletId: $e');
          }
        }
      } catch (_) {}
    }

    if (count > 0) {
      _transactionRepo?.notifyTransactionsChanged();
    }
    return count;
  }

  Future<void> _uploadSingleItem(String table, String recordId, String action, Map<String, dynamic>? data) async {
    final collection = _firestore.collection(table);

    switch (action) {
      case 'INSERT':
      case 'UPDATE':
        if (data != null) {
          // Chuyển đổi timestamp fields cho Firestore, dùng set merge: true để chống lỗi NOT_FOUND
          final firestoreData = _convertToFirestoreFormat(data, table);
          await collection.doc(recordId).set(firestoreData, SetOptions(merge: true));
        }
        break;
      case 'UPDATE_ALL_READ':
        if (data != null && data['uid'] != null) {
          final targetUid = data['uid'] as String;
          final unreadDocs = await collection
              .where('uid', isEqualTo: targetUid)
              .where('isRead', isEqualTo: false)
              .get();
          if (unreadDocs.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in unreadDocs.docs) {
              batch.update(doc.reference, {'isRead': true});
            }
            await batch.commit();
            debugPrint('SyncService: Marked ${unreadDocs.docs.length} notifications as read on Firestore');
          }
        }
        break;
      case 'DELETE':
        await collection.doc(recordId).delete();
        break;
    }
  }

  /// Chuyển đổi dữ liệu SQLite format sang Firestore format
  Map<String, dynamic> _convertToFirestoreFormat(Map<String, dynamic> data, String table) {
    final result = Map<String, dynamic>.from(data);

    // Xóa các trường chỉ dùng cho SQLite
    result.remove('syncStatus');
    result.remove('photoLocalPath');
    result.remove('avatarLocalPath');

    // Chuyển int timestamps → Firestore Timestamp
    final timestampFields = ['date', 'createdAt', 'updatedAt', 'joinDate', 'lastActive', 'dateOfBirth', 'lastPasswordUpdate'];
    for (final field in timestampFields) {
      if (result.containsKey(field) && result[field] is int) {
        result[field] = Timestamp.fromMillisecondsSinceEpoch(result[field] as int);
      }
    }

    // Chuyển int booleans → bool
    final boolFields = ['hasPhoto', 'isRead', 'isUnread', 'isDefault'];
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

  Future<void> _downloadFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Download transactions
      final txSnapshot = await _firestore
          .collection('transactions')
          .where('uid', isEqualTo: uid)
          .get();
      if (txSnapshot.docs.isNotEmpty) {
        final transactions = txSnapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList();
        await _transactionRepo?.upsertFromFirestore(transactions);
        debugPrint('SyncService: Downloaded ${transactions.length} transactions');
      }

      // Download wallets
      final walletSnapshot = await _firestore
          .collection('wallets')
          .where('uid', isEqualTo: uid)
          .get();
      if (walletSnapshot.docs.isNotEmpty) {
        final wallets = walletSnapshot.docs
            .map((doc) => WalletModel.fromFirestore(doc))
            .toList();
        await _walletRepo?.upsertFromFirestore(wallets);
        debugPrint('SyncService: Downloaded ${wallets.length} wallets');
      }

      // Download user profile
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final user = UserModel.fromFirestore(userDoc);
        await _userRepo?.upsertFromFirestore(user);
        debugPrint('SyncService: Downloaded user profile');
      }

      // Download notifications
      final notiSnapshot = await _firestore
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .get();
      if (notiSnapshot.docs.isNotEmpty) {
        final notifications = notiSnapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();
        await _notificationRepo?.upsertFromFirestore(notifications);
        debugPrint('SyncService: Downloaded ${notifications.length} notifications');
      }

      // Download messages
      final msgSnapshot = await _firestore
          .collection('messages')
          .where('uid', isEqualTo: uid)
          .get();
      if (msgSnapshot.docs.isNotEmpty) {
        final messages = msgSnapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
        await _messageRepo?.upsertFromFirestore(messages);
        debugPrint('SyncService: Downloaded ${messages.length} messages');
      }
    } catch (e) {
      debugPrint('SyncService: Download error: $e');
    }
  }

  // ════════ REALTIME LISTENERS ════════

  /// Bắt đầu lắng nghe realtime từ Firestore (chạy background)
  void startRealtimeListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Lắng nghe thay đổi transactions
    _firestoreSubscriptions.add(
      _firestore
          .collection('transactions')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docChanges.isNotEmpty) {
          final transactions = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList();
          _transactionRepo?.upsertFromFirestore(transactions);
        }
      }, onError: (e) {
        debugPrint('SyncService: Realtime transactions error: $e');
      }),
    );

    // Lắng nghe thay đổi wallets
    _firestoreSubscriptions.add(
      _firestore
          .collection('wallets')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docChanges.isNotEmpty) {
          final wallets = snapshot.docs
              .map((doc) => WalletModel.fromFirestore(doc))
              .toList();
          _walletRepo?.upsertFromFirestore(wallets);
        }
      }, onError: (e) {
        debugPrint('SyncService: Realtime wallets error: $e');
      }),
    );

    // Lắng nghe thay đổi user profile
    _firestoreSubscriptions.add(
      _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          final user = UserModel.fromFirestore(doc);
          _userRepo?.upsertFromFirestore(user);
        }
      }, onError: (e) {
        debugPrint('SyncService: Realtime user error: $e');
      }),
    );

    // Lắng nghe thay đổi notifications
    _firestoreSubscriptions.add(
      _firestore
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docChanges.isNotEmpty) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          _notificationRepo?.upsertFromFirestore(notifications);
        }
      }, onError: (e) {
        debugPrint('SyncService: Realtime notifications error: $e');
      }),
    );

    debugPrint('SyncService: Realtime listeners started');
  }

  /// Dừng lắng nghe realtime
  void stopRealtimeListeners() {
    for (final sub in _firestoreSubscriptions) {
      sub.cancel();
    }
    _firestoreSubscriptions.clear();
    debugPrint('SyncService: Realtime listeners stopped');
  }

  void dispose() {
    stopRealtimeListeners();
    _connectivitySubscription?.cancel();
  }
}
