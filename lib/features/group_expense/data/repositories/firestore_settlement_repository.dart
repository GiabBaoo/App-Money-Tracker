import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/i_settlement_repository.dart';
import '../dtos/create_settlement_dto.dart';
import '../models/settlement_model.dart';

class FirestoreSettlementRepository implements ISettlementRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'settlements';

  FirestoreSettlementRepository(this._firestore);

  @override
  Future<SettlementModel> create(CreateSettlementDto dto) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final settlement = SettlementModel(
      id: id,
      groupId: dto.groupId,
      payerId: dto.payerId,
      payeeId: dto.payeeId,
      amount: dto.amount,
      status: SettlementStatus.pendingConfirmation,
      notes: dto.notes,
      proofPhotoUrl: dto.proofPhotoUrl,
      createdAt: now,
    );

    await _firestore.collection(_collection).doc(id).set(settlement.toJson());
    return settlement;
  }

  @override
  Future<SettlementModel> getById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) throw Exception('Settlement not found');
    return SettlementModel.fromJson(doc.data()!);
  }

  @override
  Future<List<SettlementModel>> getByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .get();

    // Sort on client side to avoid index requirement
    final settlements = snapshot.docs
        .map((doc) => SettlementModel.fromJson(doc.data()))
        .toList();
    
    settlements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return settlements;
  }

  @override
  Stream<List<SettlementModel>> watchByGroupId(String groupId) {
    return _firestore
        .collection(_collection)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          // Sort on client side to avoid index requirement
          final settlements = snapshot.docs
              .map((doc) => SettlementModel.fromJson(doc.data()))
              .toList();
          
          settlements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return settlements;
        });
  }

  @override
  Future<void> updateStatus(String id, SettlementStatus status) async {
    final Map<String, dynamic> data = {
      'status': status.toString().split('.').last,
    };
    if (status == SettlementStatus.confirmed) {
      data['confirmedAt'] = Timestamp.fromDate(DateTime.now());
    }
    await _firestore.collection(_collection).doc(id).update(data);
  }

  @override
  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
