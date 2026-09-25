import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/device_session_model.dart';
import '../models/wallet_model.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../utils/device_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid ?? AuthService().offlineUid;

  // ======================== TRANSACTIONS ========================

  // Thêm giao dịch mới
  Future<void> addTransaction(TransactionModel transaction) async {
    if (_uid == null) return;
    await _db.collection('transactions').add(transaction.toFirestore());
  }

  // Thêm giao dịch mới và trả về documentId
  // (dùng cho luồng upload ảnh: cần id để tạo path trong Firebase Storage)
  Future<String> addTransactionAndGetId(TransactionModel transaction) async {
    if (_uid == null) {
      throw StateError('User is not authenticated');
    }

    final docRef = await _db.collection('transactions').add(transaction.toFirestore());
    return docRef.id;
  }

  // Stream danh sách giao dịch (realtime - sắp xếp theo ngày mới nhất)
  Stream<List<TransactionModel>> getTransactionsStream({int? limit}) {
    if (_uid == null) return Stream.value([]);

    // Nếu không có mạng hoặc đang ở phiên offline, đọc trực tiếp từ SQLite
    if (!ConnectivityService().isOnline || AuthService().isOfflineSession) {
      return TransactionRepository().getTransactionsStream(limit: limit);
    }

    Query query = _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList())
        .handleError((error) {
          debugPrint('Firestore getTransactionsStream error: $error');
          return <TransactionModel>[];
        });
  }

  // Lấy tất cả giao dịch (một lần, không realtime)
  Future<List<TransactionModel>> getAllTransactions() async {
    if (_uid == null) return [];

    final snapshot = await _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList();
  }

  // Lấy giao dịch theo khoảng thời gian (dùng cho export báo cáo)
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_uid == null) return [];

    // Chuẩn hóa range theo ngày để truy vấn chính xác:
    // start: 00:00:00, end: 23:59:59
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    // Tránh phụ thuộc composite index: chỉ query theo uid rồi lọc range ở client.
    final snapshot = await _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .get();

    final txs = snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .where((tx) {
          final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
          return !txDate.isBefore(rangeStart) && !txDate.isAfter(DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day));
        })
        // Báo cáo chi tiêu: chỉ lấy expense
        .where((tx) => !tx.isIncome)
        .toList();

    txs.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    return txs;
  }

  // Xóa giao dịch
  Future<void> deleteTransaction(String transactionId) async {
    final docRef = _db.collection('transactions').doc(transactionId);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    // Nếu có ảnh, xóa luôn object trong Firebase Storage để tránh rác.
    final storagePath = data?['photoStoragePath'] as String?;
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(storagePath).delete();
      } catch (e) {
        // Xóa storage có thể fail vì rule/quyền hoặc ảnh đã bị xóa trước đó.
        // Ta vẫn xóa document để app không bị kẹt.
        // ignore: avoid_print
        debugPrint('Failed to delete storage object: $e');
      }
    }

    await docRef.delete();
  }

  // Cập nhật giao dịch
  Future<void> updateTransaction(TransactionModel transaction) async {
    await _db
        .collection('transactions')
        .doc(transaction.id)
        .update(transaction.toFirestore());
  }

  // Cập nhật ảnh cho giao dịch
  Future<void> updateTransactionPhoto({
    required String transactionId,
    required String photoUrl,
    required String photoStoragePath,
  }) async {
    await _db.collection('transactions').doc(transactionId).update({
      'hasPhoto': true,
      'photoUrl': photoUrl,
      'photoStoragePath': photoStoragePath,
    });
  }

  // Gallery: Stream các giao dịch có ảnh (realtime)
  Stream<List<TransactionModel>> getTransactionsWithPhotosStream() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .where((tx) => tx.hasPhoto)
            .toList());
  }

  // ======================== THỐNG KÊ (HOME) ========================

  // Stream tính tổng số dư, tổng thu, tổng chi (realtime)
  Stream<({double balance, double totalIncome, double totalExpense})>
      getBalanceStream() {
    if (_uid == null) {
      return Stream.value(
          (balance: 0.0, totalIncome: 0.0, totalExpense: 0.0));
    }

    return _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
      double totalIncome = 0;
      double totalExpense = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        if (data['type'] == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }

      return (
        balance: totalIncome - totalExpense,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    });
  }

  // ======================== NOTIFICATIONS ========================

  // Stream thông báo (realtime)
  Stream<List<NotificationModel>> getNotificationsStream() {
    if (_uid == null) return Stream.value([]);

    // Nếu không có mạng hoặc offline session, đọc từ SQLite
    if (!ConnectivityService().isOnline || AuthService().isOfflineSession) {
      return NotificationRepository().getNotificationsStream();
    }

    return _db
        .collection('notifications')
        .where('uid', isEqualTo: _uid)
        // Sắp xếp ở phía Client để tránh lỗi yêu cầu tạo Index trên Firebase
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      // Sắp xếp giảm dần theo thời gian (mới nhất lên đầu)
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((error) {
      debugPrint('Firestore getNotificationsStream error: $error');
      return <NotificationModel>[];
    });
  }

  // Đánh dấu thông báo đã đọc
  Future<void> markNotificationAsRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Đánh dấu tất cả thông báo đã đọc
  Future<void> markAllNotificationsAsRead() async {
    if (_uid == null) return;
    try {
      final unreadDocs = await _db
          .collection('notifications')
          .where('uid', isEqualTo: _uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadDocs.docs.isEmpty) return;

      final batch = _db.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Tự động tạo thông báo chào mừng thật nếu tài khoản mới tinh chưa có thông báo nào
  Future<void> autoGenerateInitialNotificationsIfNeeded() async {
    if (_uid == null) return;
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('uid', isEqualTo: _uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        final welcomeNoti = NotificationModel(
          uid: _uid!,
          iconCode: Icons.celebration_rounded.codePoint,
          title: 'Chào mừng bạn đến với Mono!',
          description: 'Cảm ơn bạn đã lựa chọn Mono để quản lý tài chính cá nhân. Hãy bắt đầu ghi lại khoản thu chi đầu tiên của bạn nhé!',
          isRead: false,
          type: 'welcome',
        );
        await addNotification(welcomeNoti);
      }
    } catch (e) {
      debugPrint('Error auto-generating welcome notification: $e');
    }
  }

  // Thêm thông báo mới cho người dùng
  Future<void> addNotification(NotificationModel notification) async {
    try {
      await _db.collection('notifications').add(notification.toFirestore());
    } catch (e) {
      debugPrint('Error adding notification: $e');
      rethrow;
    }
  }

  // Thêm thông báo cho người dùng khác (không phải người dùng hiện tại)
  Future<void> addNotificationForUser(String userId, NotificationModel notification) async {
    try {
      final notificationData = notification.toFirestore();
      notificationData['uid'] = userId;
      await _db.collection('notifications').add(notificationData);
    } catch (e) {
      debugPrint('Error adding notification for user: $e');
      rethrow;
    }
  }

  // ======================== USER PROFILE ========================

  // Cập nhật thông tin user
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set(data, SetOptions(merge: true));
  }

  // Stream thông tin user (realtime)
  Stream<UserModel?> getUserStream() {
    if (_uid == null) return Stream.value(null);
    if (!ConnectivityService().isOnline || AuthService().isOfflineSession) {
      return UserRepository().getUserStream();
    }
    return _db.collection('users').doc(_uid).snapshots().map(
        (doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // ======================== MESSAGES ========================

  Future<void> addMessage(MessageModel message) async {
    if (_uid == null) return;
    await _db.collection('messages').add(message.toFirestore());
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.collection('messages').doc(messageId).delete();
  }

  Stream<List<MessageModel>> getMessagesStream() {
    if (_uid == null) return Stream.value([]);

    return _db
        .collection('messages')
        .where('uid', isEqualTo: _uid)
        // Bỏ orderBy để tránh lỗi Composite Index của Firestore, sau đó sort ở client
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return messages;
    }).handleError((error) {
      debugPrint('Firestore getMessagesStream error: $error');
      return <MessageModel>[];
    });
  }

  // ======================== DEVICE SESSIONS ========================

  Future<void> registerDeviceSession({
    required String deviceName,
    required String deviceType,
  }) async {
    if (_uid == null) return;
    try {
      String sanitizedId = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      String docId = '${_uid}_$sanitizedId';
      
      String realLocation = 'Thiết bị hiện hành';
      
      try {
        final response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final city = data['city'] ?? '';
          final country = data['country_name'] ?? '';
          final loc = [city, country].where((s) => s.toString().isNotEmpty).join(', ');
          if (loc.isNotEmpty) realLocation = loc;
        }
      } catch (_) {}
      
      await _db.collection('device_sessions').doc(docId).set({
        'uid': _uid,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'location': realLocation,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Lỗi đăng ký session: $e');
    }
  }

  Future<void> ensureCurrentDeviceRegistered() async {
    try {
      final deviceInfo = await DeviceUtils.getDeviceInfo();
      await registerDeviceSession(
        deviceName: deviceInfo['name']!,
        deviceType: deviceInfo['type']!,
      );
    } catch (e) {
      debugPrint('ensureCurrentDeviceRegistered error: $e');
    }
  }

  Stream<List<DeviceSessionModel>> getDeviceSessionsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('device_sessions')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => DeviceSessionModel.fromFirestore(doc))
          .toList();
      sessions.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      return sessions;
    }).handleError((err) {
      debugPrint('FirestoreService getDeviceSessionsStream error: $err');
      return <DeviceSessionModel>[];
    });
  }

  Future<void> removeDeviceSession(String sessionId) async {
    await _db.collection('device_sessions').doc(sessionId).delete();
  }

  // Cập nhật tùy chọn sử dụng dữ liệu
  Future<void> updateDataUsagePreference(String key, bool value) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'dataUsage.$key': value,
    });
  }

  // ======================== WALLETS ========================

  Stream<List<WalletModel>> getWalletsStream() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('wallets')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => WalletModel.fromFirestore(doc)).toList();
      list.sort((a, b) {
        if (a.isDefault) return -1;
        if (b.isDefault) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    });
  }

  Future<void> addWallet(WalletModel wallet) async {
    if (_uid == null) return;
    await _db.collection('wallets').doc(wallet.id).set(wallet.toFirestore());
  }

  Future<void> updateWallet(WalletModel wallet) async {
    await _db.collection('wallets').doc(wallet.id).set(wallet.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteWallet(String walletId) async {
    await _db.collection('wallets').doc(walletId).delete();
  }
}
