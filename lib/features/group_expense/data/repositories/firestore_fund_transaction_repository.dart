import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/firestore_parse.dart';
import '../../../../data/repositories/transaction_repository.dart';
import '../../../../models/transaction_model.dart';
import '../../../../services/transaction_balance_service.dart';
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

    // Tạo transaction trong sổ cái cá nhân nếu là QUỸ CÁ NHÂN
    if (isPersonalGroup &&
        (type == TransactionType.contribute ||
            type == TransactionType.withdraw)) {
      final isContribute = type == TransactionType.contribute;
      final txId = 'ftx_$id';
      final txType = isContribute ? 'expense' : 'income';
      final txCategory =
          category ??
          (isContribute
              ? 'Góp quỹ ${groupName ?? ""}'
              : 'Rút từ quỹ ${groupName ?? ""}');
      final txIconCode =
          categoryIconCode ??
          groupIconCode ??
          Icons.account_balance_wallet.codePoint;
      final txTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final txDesc =
          notes ?? (isContribute ? 'Góp quỹ nhóm' : 'Rút từ quỹ cá nhân');

      if (SessionManager.instance.uidOrNull == userId) {
        final personalTx = TransactionModel(
          id: txId,
          uid: userId,
          type: txType,
          category: txCategory,
          categoryIconCode: txIconCode,
          amount: amount,
          date: DateTime(now.year, now.month, now.day),
          time: txTime,
          description: txDesc,
          createdAt: now,
          updatedAt: now.toUtc(),
          groupId: groupId,
          groupIconCode: groupIconCode,
          source: 'fund',
        );
        await TransactionBalanceService().addTransactionAtomic(personalTx);
      } else {
        await _firestore.collection('transactions').doc(txId).set({
          'id': txId,
          'uid': userId,
          'type': txType,
          'category': txCategory,
          'categoryIconCode': txIconCode,
          'amount': amount,
          'date': Timestamp.fromDate(now),
          'time': txTime,
          'description': txDesc,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now.toUtc()),
          'isDeleted': false,
          'groupId': groupId,
          'groupIconCode': groupIconCode,
          'source': 'fund',
        });
      }
    }

    return transaction;
  }

  Future<void> delete(FundTransactionModel transaction) async {
    // 1. Xóa fund transaction
    await _firestore.collection(_collection).doc(transaction.id).delete();

    // 2. Chỉ xóa transaction cá nhân nếu người đang đăng nhập là chính chủ giao dịch
    // (admin xóa fund_transaction không được đụng transactions cá nhân người khác)
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != transaction.userId) return;

    final deterministicId = 'ftx_${transaction.id}';
    if (SessionManager.instance.uidOrNull == currentUid) {
      try {
        await TransactionRepository().deleteTransaction(deterministicId);
      } catch (_) {}
    }

    // Xóa mềm (Tombstone) trên Firestore để không bị máy khác backfill hồi sinh
    final nowTs = Timestamp.fromDate(DateTime.now().toUtc());
    final detDoc = await _firestore
        .collection('transactions')
        .doc(deterministicId)
        .get();
    if (detDoc.exists) {
      await detDoc.reference.set({
        'isDeleted': true,
        'deletedAt': nowTs,
        'updatedAt': nowTs,
      }, SetOptions(merge: true));
      return;
    }

    final personalTxQuery = await _firestore
        .collection('transactions')
        .where('uid', isEqualTo: transaction.userId)
        .where('groupId', isEqualTo: transaction.groupId)
        .where('amount', isEqualTo: transaction.amount)
        .where('source', isEqualTo: 'fund')
        .get();

    for (var doc in personalTxQuery.docs) {
      final txDate = FirestoreParse.parseDate(doc.data()['createdAt']);
      if (txDate != null &&
          txDate.difference(transaction.createdAt).inSeconds.abs() <= 2) {
        await doc.reference.set({
          'isDeleted': true,
          'deletedAt': nowTs,
          'updatedAt': nowTs,
        }, SetOptions(merge: true));
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
              .map(
                (doc) => FundTransactionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }),
              )
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
            final transaction = FundTransactionModel.fromJson({
              ...doc.data(),
              'id': doc.id,
            });
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
      final transaction = FundTransactionModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
      if (transaction.type == TransactionType.contribute) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }
    return balance;
  }
}
