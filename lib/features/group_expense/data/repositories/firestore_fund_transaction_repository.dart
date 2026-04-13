import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/fund_transaction_model.dart';

class FirestoreFundTransactionRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'fund_transactions';

  FirestoreFundTransactionRepository(this._firestore);

  Future<FundTransactionModel> create({
    required String groupId,
    required String userId,
    required String userName,
    required double amount,
    required TransactionType type,
    String? notes,
    String? groupName,
    int? groupIconCode,
    String? category,
    int? categoryIconCode,
    bool isPersonalGroup = false,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final transaction = FundTransactionModel(
      id: id,
      groupId: groupId,
      userId: userId,
      userName: userName,
      amount: amount,
      type: type,
      createdAt: now,
      notes: notes,
    );

    // Lưu fund transaction
    await _firestore.collection(_collection).doc(id).set(transaction.toJson());
    
    // Tạo transaction trong collection 'transactions' để hiện trong thống kê cá nhân
    // GÓP QUỸ: Chỉ tạo khoản CHI cho cá nhân nếu là QUỸ CÁ NHÂN
    if (type == TransactionType.contribute && isPersonalGroup) {
      final transactionData = {
        'uid': userId,
        'type': 'expense',
        'category': category ?? 'Góp quỹ ${groupName ?? ""}',
        'categoryIconCode': categoryIconCode ?? groupIconCode ?? Icons.account_balance_wallet.codePoint,
        'amount': amount,
        'date': Timestamp.fromDate(now),
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'description': notes ?? 'Góp quỹ nhóm',
        'createdAt': Timestamp.fromDate(now),
        'groupId': groupId,
        'groupIconCode': groupIconCode,
        'source': 'fund',
      };
      
      await _firestore.collection('transactions').add(transactionData);
    } 
    // RÚT QUỸ: Chỉ tạo khoản THU cho cá nhân nếu là QUỸ CÁ NHÂN
    else if (type == TransactionType.withdraw && isPersonalGroup) {
      final transactionData = {
        'uid': userId,
        'type': 'income', // Rút về ví cá nhân là Khoản Thu
        'category': category ?? 'Rút từ quỹ ${groupName ?? ""}',
        'categoryIconCode': categoryIconCode ?? groupIconCode ?? Icons.account_balance_wallet.codePoint,
        'amount': amount,
        'date': Timestamp.fromDate(now),
        'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'description': notes ?? 'Rút từ quỹ cá nhân',
        'createdAt': Timestamp.fromDate(now),
        'groupId': groupId,
        'groupIconCode': groupIconCode,
        'source': 'fund',
      };
      
      await _firestore.collection('transactions').add(transactionData);
    }
    
    return transaction;
  }

  Future<void> delete(FundTransactionModel transaction) async {
    // 1. Xóa fund transaction
    await _firestore.collection(_collection).doc(transaction.id).delete();
    
    // 2. Tìm và xóa transaction cá nhân tương ứng (nếu có)
    // Tìm các giao dịch có cùng uid, groupId, amount và source là 'fund'
    final personalTxQuery = await _firestore.collection('transactions')
        .where('uid', isEqualTo: transaction.userId)
        .where('groupId', isEqualTo: transaction.groupId)
        .where('amount', isEqualTo: transaction.amount)
        .where('source', isEqualTo: 'fund')
        .get();
        
    for (var doc in personalTxQuery.docs) {
      final txDate = (doc.data()['createdAt'] as Timestamp).toDate();
      // Kiểm tra nếu thời gian tạo khớp (cho phép sai số 2 giây)
      if (txDate.difference(transaction.createdAt).inSeconds.abs() <= 2) {
        await doc.reference.delete();
      }
    }
  }

  Stream<List<FundTransactionModel>> watchByGroupId(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          final transactions = snapshot.docs
              .map((doc) => FundTransactionModel.fromJson(doc.data()))
              .toList();
          
          // Sort by date descending
          transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return transactions;
        });
  }

  // Stream balance để cập nhật real-time
  Stream<double> watchGroupBalance(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          double balance = 0;
          for (var doc in snapshot.docs) {
            final transaction = FundTransactionModel.fromJson(doc.data());
            if (transaction.type == TransactionType.contribute) {
              balance += transaction.amount;
            } else {
              balance -= transaction.amount;
            }
          }
          return balance;
        });
  }

  Future<double> getGroupBalance(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .get();

    double balance = 0;
    for (var doc in snapshot.docs) {
      final transaction = FundTransactionModel.fromJson(doc.data());
      if (transaction.type == TransactionType.contribute) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }
    return balance;
  }
}
