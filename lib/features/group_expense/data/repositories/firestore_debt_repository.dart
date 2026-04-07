import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/i_debt_repository.dart';
import '../models/debt_model.dart';

class FirestoreDebtRepository implements IDebtRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'debts';

  FirestoreDebtRepository(this._firestore);

  @override
  Future<DebtModel> create(DebtModel debt) async {
    await _firestore.collection(_collection).doc(debt.id).set(debt.toJson());
    return debt;
  }

  @override
  Future<List<DebtModel>> getByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs.map((doc) => DebtModel.fromJson(doc.data())).toList();
  }

  @override
  Stream<List<DebtModel>> watchByGroupId(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DebtModel.fromJson(doc.data()))
            .toList());
  }

  @override
  Future<List<DebtModel>> getByUserId(String userId) async {
    final debtorSnapshot = await _firestore
        .collection(_collection)
        .where('debtorId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    final creditorSnapshot = await _firestore
        .collection(_collection)
        .where('creditorId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .get();

    return [
      ...debtorSnapshot.docs.map((doc) => DebtModel.fromJson(doc.data())),
      ...creditorSnapshot.docs.map((doc) => DebtModel.fromJson(doc.data())),
    ];
  }

  @override
  Future<void> update(String id, DebtModel debt) async {
    await _firestore.collection(_collection).doc(id).update(debt.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  @override
  Future<void> deleteByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
