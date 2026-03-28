import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

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
    await _db.collection('users').doc(_uid).update(data);
  }

  // Stream thông tin user (realtime)
  Stream<UserModel?> getUserStream() {
    if (_uid == null) return Stream.value(null);
    return _db.collection('users').doc(_uid).snapshots().map(
        (doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
}
