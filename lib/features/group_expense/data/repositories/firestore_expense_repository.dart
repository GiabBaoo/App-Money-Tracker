import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../../domain/services/vnd_split_calculator.dart';
import '../dtos/create_expense_dto.dart';
import '../models/expense_model.dart';

class FirestoreExpenseRepository implements IExpenseRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'expenses';

  FirestoreExpenseRepository(this._firestore);

  @override
  Future<ExpenseModel> create(CreateExpenseDto dto, String createdBy) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final totalAmountVnd = dto.amount.round();
    final Map<String, int> intSplits;
    switch (dto.splitMethod) {
      case SplitMethod.equal:
        intSplits = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: totalAmountVnd,
          participantIds: dto.participantIds,
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.percentage:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu tỷ lệ phần trăm chia tiền');
        }
        intSplits = VndSplitCalculator.calculatePercentageSplit(
          totalAmountVnd: totalAmountVnd,
          percentages: dto.customShares!,
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.shares:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu số phần chia tiền');
        }
        intSplits = VndSplitCalculator.calculateSharesSplit(
          totalAmountVnd: totalAmountVnd,
          shares: dto.customShares!.map((k, v) => MapEntry(k, v.round())),
          payerId: dto.payerId,
        );
        break;
      case SplitMethod.exact:
      case SplitMethod.custom:
        if (dto.customShares == null || dto.customShares!.isEmpty) {
          throw Exception('Thiếu số tiền chia lẻ');
        }
        intSplits = VndSplitCalculator.calculateExactSplit(
          totalAmountVnd: totalAmountVnd,
          exactAmounts: dto.customShares!.map((k, v) => MapEntry(k, v.round())),
        );
        break;
      case SplitMethod.singlePayer:
        intSplits = {dto.payerId: totalAmountVnd};
        break;
    }
    final shares = intSplits.map((k, v) => MapEntry(k, v.toDouble()));

    final expense = ExpenseModel(
      id: id,
      groupId: dto.groupId,
      name: dto.name,
      amount: dto.amount,
      payerId: dto.payerId,
      participantIds: dto.participantIds,
      splitMethod: dto.splitMethod,
      shares: shares,
      category: dto.category,
      date: dto.date,
      notes: dto.notes,
      photoUrls: dto.photoUrls,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection(_collection).doc(id).set(expense.toJson());
    return expense;
  }

  @override
  Future<ExpenseModel> getById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw Exception('Expense not found');
    return ExpenseModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  @override
  Future<List<ExpenseModel>> getByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .get();

    // Sort on client side to avoid index requirement
    final expenses = snapshot.docs
        .map((doc) => ExpenseModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();

    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  @override
  Stream<List<ExpenseModel>> watchByGroupId(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          // Sort on client side to avoid index requirement
          final expenses = snapshot.docs
              .map((doc) => ExpenseModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList();

          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        });
  }

  @override
  Future<void> update(ExpenseModel expense) async {
    await _firestore
        .collection(_collection)
        .doc(expense.id)
        .update(expense.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
