import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/i_expense_repository.dart';
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

    Map<String, double> shares;
    if (dto.splitMethod == SplitMethod.equal) {
      final shareAmount = dto.amount / dto.participantIds.length;
      shares = {for (var id in dto.participantIds) id: shareAmount};
    } else if (dto.splitMethod == SplitMethod.custom && dto.customShares != null) {
      shares = dto.customShares!;
    } else if (dto.splitMethod == SplitMethod.singlePayer) {
      shares = {dto.payerId: dto.amount};
    } else {
      throw Exception('Invalid split method or missing custom shares');
    }

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
    return ExpenseModel.fromJson(doc.data()!);
  }

  @override
  Future<List<ExpenseModel>> getByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .get();

    // Sort on client side to avoid index requirement
    final expenses = snapshot.docs
        .map((doc) => ExpenseModel.fromJson(doc.data()))
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
              .map((doc) => ExpenseModel.fromJson(doc.data()))
              .toList();
          
          expenses.sort((a, b) => b.date.compareTo(a.date));
          return expenses;
        });
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
