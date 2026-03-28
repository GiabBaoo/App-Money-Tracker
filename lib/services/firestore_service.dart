import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< HEAD
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
=======
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/device_session_model.dart';
>>>>>>> funcionsettinggit

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ======================== TRANSACTIONS ========================

  // Thêm giao dịch mới
  Future<void> addTransaction(TransactionModel transaction) async {
    if (_uid == null) return;
    await _db.collection('transactions').add(transaction.toFirestore());
  }

  // Stream danh sách giao dịch (realtime - sắp xếp theo ngày mới nhất)
  Stream<List<TransactionModel>> getTransactionsStream({int? limit}) {
    if (_uid == null) return Stream.value([]);

    Query query = _db
        .collection('transactions')
        .where('uid', isEqualTo: _uid)
        .orderBy('date', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList());
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

  // Xóa giao dịch
  Future<void> deleteTransaction(String transactionId) async {
    await _db.collection('transactions').doc(transactionId).delete();
  }

  // Cập nhật giao dịch
  Future<void> updateTransaction(
      String transactionId, Map<String, dynamic> data) async {
    await _db.collection('transactions').doc(transactionId).update(data);
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

    return _db
        .collection('notifications')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  // Đánh dấu thông báo đã đọc
  Future<void> markNotificationAsRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // ======================== USER PROFILE ========================

  // Cập nhật thông tin user
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (_uid == null) return;
<<<<<<< HEAD
    await _db.collection('users').doc(_uid).update(data);
=======
    await _db.collection('users').doc(_uid).set(data, SetOptions(merge: true));
>>>>>>> funcionsettinggit
  }

  // Stream thông tin user (realtime)
  Stream<UserModel?> getUserStream() {
    if (_uid == null) return Stream.value(null);
    return _db.collection('users').doc(_uid).snapshots().map(
        (doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
<<<<<<< HEAD
=======

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
    });
  }

  // ======================== DEVICE SESSIONS ========================

  Future<void> registerDeviceSession({
    required String deviceName,
    required String deviceType,
  }) async {
    if (_uid == null) return;
    try {
      // Dùng tên thiết bị làm Doc ID để cập nhật thay vì tạo mới mãi
      String sanitizedId = deviceName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      String docId = '${_uid}_$sanitizedId';
      
      // Mặc định là IP hiện hành
      String realLocation = 'IP hiện hành';
      
      // Thử lấy vị trí thật qua IP (miễn phí)
      try {
        final response = await http.get(Uri.parse('http://ip-api.com/json/')).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            final city = data['city'] ?? '';
            final country = data['country'] ?? '';
            realLocation = [city, country].where((s) => s.isNotEmpty).join(', ');
          }
        }
      } catch (e) {
        // Lọt lỗi network timeout thì vẫn dùng location cũ
        print('Lỗi lấy vị trí IP: $e');
      }
      
      await _db.collection('device_sessions').doc(docId).set({
        'uid': _uid,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'location': realLocation, // Vị trí thật (Hanoi, Vietnam)
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Ghi đè cập nhật lastActive
    } catch (e) {
      // Lỗi bỏ qua
      print('Lỗi đăng ký session: $e');
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
      // Sắp xếp mới nhất lên đầu
      sessions.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      return sessions;
    });
  }

  Future<void> removeDeviceSession(String sessionId) async {
    await _db.collection('device_sessions').doc(sessionId).delete();
  }
>>>>>>> funcionsettinggit
}
