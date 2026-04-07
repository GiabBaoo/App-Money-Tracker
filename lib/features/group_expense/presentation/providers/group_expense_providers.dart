import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/firestore_debt_repository.dart';
import '../../data/repositories/firestore_expense_repository.dart';
import '../../data/repositories/firestore_group_repository.dart';
import '../../data/repositories/firestore_settlement_repository.dart';
import '../../domain/repositories/i_debt_repository.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../../domain/repositories/i_group_repository.dart';
import '../../domain/repositories/i_settlement_repository.dart';
import '../../domain/services/debt_calculator.dart';
import '../../domain/services/expense_service.dart';
import '../../domain/services/group_service.dart';
import '../../domain/services/settlement_service.dart';
import '../../data/models/group_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/settlement_model.dart';
import '../../data/models/fund_transaction_model.dart';
import '../../data/repositories/firestore_fund_transaction_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
});

// Provider để lấy tên người dùng hiện tại
final currentUserNameProvider = FutureProvider<String>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 'Người dùng';
  
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['name'] as String? ?? 'Người dùng';
    }
  } catch (e) {
    print('Error getting user name: $e');
  }
  
  return 'Người dùng';
});

final groupRepositoryProvider = Provider<IGroupRepository>((ref) {
  return FirestoreGroupRepository(ref.watch(firestoreProvider));
});

final expenseRepositoryProvider = Provider<IExpenseRepository>((ref) {
  return FirestoreExpenseRepository(ref.watch(firestoreProvider));
});

final debtRepositoryProvider = Provider<IDebtRepository>((ref) {
  return FirestoreDebtRepository(ref.watch(firestoreProvider));
});

final settlementRepositoryProvider = Provider<ISettlementRepository>((ref) {
  return FirestoreSettlementRepository(ref.watch(firestoreProvider));
});

final fundTransactionRepositoryProvider = Provider<FirestoreFundTransactionRepository>((ref) {
  return FirestoreFundTransactionRepository(ref.watch(firestoreProvider));
});

final debtCalculatorProvider = Provider<DebtCalculator>((ref) {
  return DebtCalculator(
    ref.watch(expenseRepositoryProvider),
    ref.watch(debtRepositoryProvider),
  );
});

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.watch(groupRepositoryProvider));
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(
    ref.watch(expenseRepositoryProvider),
    ref.watch(groupRepositoryProvider),
    ref.watch(debtCalculatorProvider),
  );
});

final settlementServiceProvider = Provider<SettlementService>((ref) {
  return SettlementService(
    ref.watch(settlementRepositoryProvider),
    ref.watch(debtRepositoryProvider),
    ref.watch(debtCalculatorProvider),
  );
});

final userGroupsStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return ref.watch(groupRepositoryProvider).watchByUserId(userId);
});

final groupExpensesStreamProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, groupId) {
  return ref.watch(expenseRepositoryProvider).watchByGroupId(groupId);
});

final groupDebtsStreamProvider = StreamProvider.family<List<DebtModel>, String>((ref, groupId) {
  return ref.watch(debtRepositoryProvider).watchByGroupId(groupId);
});

final groupSettlementsStreamProvider = StreamProvider.family<List<SettlementModel>, String>((ref, groupId) {
  return ref.watch(settlementRepositoryProvider).watchByGroupId(groupId);
});

// Single group stream provider
final groupStreamProvider = StreamProvider.family<GroupModel, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).watchByUserId(
    ref.watch(currentUserIdProvider) ?? ''
  ).map((groups) => groups.firstWhere((g) => g.id == groupId));
});

// Group debts provider (calculated)
final groupDebtsProvider = FutureProvider.family<List<DebtModel>, String>((ref, groupId) async {
  return ref.watch(debtCalculatorProvider).getGroupDebts(groupId);
});

// Fund transactions stream provider
final groupFundTransactionsProvider = StreamProvider.family<List<FundTransactionModel>, String>((ref, groupId) {
  return ref.watch(fundTransactionRepositoryProvider).watchByGroupId(groupId);
});

// Group balance provider (Stream để cập nhật real-time)
final groupBalanceProvider = StreamProvider.family<double, String>((ref, groupId) {
  return ref.watch(fundTransactionRepositoryProvider).watchGroupBalance(groupId);
});
