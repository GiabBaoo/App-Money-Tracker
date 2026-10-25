import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/features/group_expense/data/models/group_model.dart';
import 'package:money_tracker_app/features/group_expense/data/models/expense_model.dart';
import 'package:money_tracker_app/features/group_expense/data/models/settlement_model.dart';
import 'package:money_tracker_app/features/group_expense/data/models/group_member_model.dart';
import 'package:money_tracker_app/features/group_expense/data/models/expense_split_model.dart';
import 'package:money_tracker_app/features/group_expense/data/models/debt_model.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/create_group_dto.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/update_group_dto.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/create_expense_dto.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/create_settlement_dto.dart';
import 'package:money_tracker_app/features/group_expense/domain/repositories/i_group_repository.dart';
import 'package:money_tracker_app/features/group_expense/domain/repositories/i_expense_repository.dart';
import 'package:money_tracker_app/features/group_expense/domain/repositories/i_debt_repository.dart';
import 'package:money_tracker_app/features/group_expense/domain/repositories/i_settlement_repository.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/vnd_split_calculator.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/debt_calculator.dart';
import 'package:money_tracker_app/features/group_expense/domain/usecases/leave_group_use_case.dart';

// Mock implementations for UseCase testing
class FakeGroupRepository implements IGroupRepository {
  final Map<String, GroupModel> _groups = {};

  void setGroup(GroupModel group) => _groups[group.id] = group;

  @override
  Future<GroupModel> create(CreateGroupDto dto, String adminId) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async => _groups.remove(id);

  @override
  Future<GroupModel> getById(String id) async {
    final g = _groups[id];
    if (g == null) throw Exception('Group not found');
    return g;
  }

  @override
  Future<List<GroupModel>> getByUserId(String userId) async =>
      _groups.values.toList();

  @override
  Stream<List<GroupModel>> watchByUserId(String userId) =>
      Stream.value(_groups.values.toList());

  @override
  Future<void> update(String id, UpdateGroupDto dto) async {}

  @override
  Future<void> addMember(String groupId, String userId) async {}

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final g = _groups[groupId];
    if (g != null) {
      final updatedMembers = List<String>.from(g.memberIds)..remove(userId);
      _groups[groupId] = g.copyWith(memberIds: updatedMembers);
    }
  }
}

class FakeExpenseRepository implements IExpenseRepository {
  final List<ExpenseModel> expenses = [];

  @override
  Future<ExpenseModel> create(CreateExpenseDto dto, String createdBy) async {
    final exp = ExpenseModel(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      groupId: dto.groupId,
      name: dto.name,
      amount: dto.amount,
      payerId: dto.payerId,
      participantIds: dto.participantIds,
      splitMethod: dto.splitMethod,
      shares: dto.customShares ?? {},
      category: dto.category,
      date: dto.date,
      photoUrls: dto.photoUrls,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    expenses.add(exp);
    return exp;
  }

  @override
  Future<void> delete(String id) async =>
      expenses.removeWhere((e) => e.id == id);
  @override
  Future<ExpenseModel> getById(String id) async =>
      expenses.firstWhere((e) => e.id == id);
  @override
  Future<List<ExpenseModel>> getByGroupId(String groupId) async =>
      expenses.where((e) => e.groupId == groupId).toList();
  @override
  Stream<List<ExpenseModel>> watchByGroupId(String groupId) =>
      Stream.value(expenses.where((e) => e.groupId == groupId).toList());
  Future<void> update(ExpenseModel expense) async {}
}

class FakeDebtRepository implements IDebtRepository {
  final List<DebtModel> debts = [];
  @override
  Future<DebtModel> create(DebtModel debt) async {
    debts.add(debt);
    return debt;
  }

  @override
  Future<void> delete(String id) async => debts.removeWhere((d) => d.id == id);
  @override
  Future<void> deleteByGroupId(String groupId) async =>
      debts.removeWhere((d) => d.groupId == groupId);
  @override
  Future<List<DebtModel>> getByGroupId(String groupId) async =>
      debts.where((d) => d.groupId == groupId).toList();
  @override
  Stream<List<DebtModel>> watchByGroupId(String groupId) =>
      Stream.value(debts.where((d) => d.groupId == groupId).toList());
  @override
  Future<List<DebtModel>> getByUserId(String userId) async => debts
      .where((d) => d.debtorId == userId || d.creditorId == userId)
      .toList();
  @override
  Future<void> update(String id, DebtModel debt) async {}
}

class FakeSettlementRepository implements ISettlementRepository {
  final List<SettlementModel> settlements = [];
  @override
  Future<SettlementModel> create(CreateSettlementDto dto) async {
    final s = SettlementModel(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      groupId: dto.groupId,
      payerId: dto.payerId,
      payeeId: dto.payeeId,
      amount: dto.amount,
      status: SettlementStatus.pendingConfirmation,
      createdAt: DateTime.now(),
    );
    settlements.add(s);
    return s;
  }

  @override
  Future<void> delete(String id) async =>
      settlements.removeWhere((s) => s.id == id);
  @override
  Future<SettlementModel> getById(String id) async =>
      settlements.firstWhere((s) => s.id == id);
  @override
  Future<List<SettlementModel>> getByGroupId(String groupId) async =>
      settlements.where((s) => s.groupId == groupId).toList();
  @override
  Stream<List<SettlementModel>> watchByGroupId(String groupId) =>
      Stream.value(settlements.where((s) => s.groupId == groupId).toList());
  @override
  Future<void> updateStatus(String id, SettlementStatus status) async {
    final idx = settlements.indexWhere((s) => s.id == id);
    if (idx != -1) {
      settlements[idx] = settlements[idx].copyWith(status: status);
    }
  }
}

void main() {
  group('VndSplitCalculator - Invariant GRP-I1 Indivisibility Tests', () {
    test(
      'Equal split distributes remainder deterministically and sums to total',
      () {
        const total = 100000;
        final members = ['u1', 'u2', 'u3'];
        final splits = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: total,
          participantIds: members,
          payerId: 'u1',
        );

        expect(splits.length, 3);
        // Remainder = 100000 % 3 = 1. Payer 'u1' gets +1 VND.
        expect(splits['u1'], 33334);
        expect(splits['u2'], 33333);
        expect(splits['u3'], 33333);

        final sum = splits.values.reduce((a, b) => a + b);
        expect(sum, total);
      },
    );

    test('Equal split with larger remainder (100,000 / 6 members)', () {
      const total = 100000;
      final members = ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'];
      final splits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: total,
        participantIds: members,
        payerId: 'u1',
      );

      // Base share = 16,666. Remainder = 4.
      // u1 (payer) gets +1, then u2, u3, u4 get +1 (deterministic ascending user ID)
      expect(splits['u1'], 16667);
      expect(splits['u2'], 16667);
      expect(splits['u3'], 16667);
      expect(splits['u4'], 16667);
      expect(splits['u5'], 16666);
      expect(splits['u6'], 16666);

      final sum = splits.values.reduce((a, b) => a + b);
      expect(sum, total);
    });

    test(
      'Percentage split uses largest remainder method and guarantees exact sum',
      () {
        const total = 100000;
        final percentages = {'u1': 33.33, 'u2': 33.33, 'u3': 33.34};

        final splits = VndSplitCalculator.calculatePercentageSplit(
          totalAmountVnd: total,
          percentages: percentages,
          payerId: 'u1',
        );

        final sum = splits.values.reduce((a, b) => a + b);
        expect(sum, total);
      },
    );

    test('Shares split allocates proportionally and sums to exact total', () {
      const total = 100000;
      final shares = {'u1': 2, 'u2': 1, 'u3': 1};

      final splits = VndSplitCalculator.calculateSharesSplit(
        totalAmountVnd: total,
        shares: shares,
        payerId: 'u1',
      );

      expect(splits['u1'], 50000);
      expect(splits['u2'], 25000);
      expect(splits['u3'], 25000);
      final sum = splits.values.reduce((a, b) => a + b);
      expect(sum, total);
    });

    test('Exact split validates that sum matches total', () {
      const total = 50000;
      final exactSplits = {'u1': 20000, 'u2': 30000};
      final result = VndSplitCalculator.calculateExactSplit(
        totalAmountVnd: total,
        exactAmounts: exactSplits,
      );
      expect(result['u1'], 20000);
      expect(result['u2'], 30000);

      // Throws on mismatch
      expect(
        () => VndSplitCalculator.calculateExactSplit(
          totalAmountVnd: total,
          exactAmounts: {'u1': 20000, 'u2': 20000},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DebtCalculator - Invariant GRP-I2 Zero-Sum Net Balances Tests', () {
    late FakeExpenseRepository expenseRepo;
    late FakeDebtRepository debtRepo;
    late FakeSettlementRepository settlementRepo;
    late DebtCalculator debtCalc;

    setUp(() {
      expenseRepo = FakeExpenseRepository();
      debtRepo = FakeDebtRepository();
      settlementRepo = FakeSettlementRepository();
      debtCalc = DebtCalculator(expenseRepo, debtRepo, settlementRepo);
    });

    test('Net balance sums to 0 with single expense', () {
      final now = DateTime.now();
      // Expense: 120,000 paid by u1, split equally among u1, u2, u3 (40,000 each)
      final expense = ExpenseModel(
        id: 'e1',
        groupId: 'g1',
        name: 'Dinner',
        amount: 120000,
        payerId: 'u1',
        participantIds: ['u1', 'u2', 'u3'],
        splitMethod: SplitMethod.equal,
        shares: {'u1': 40000, 'u2': 40000, 'u3': 40000},
        category: 'Food',
        date: now,
        photoUrls: const [],
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      final balances = debtCalc.calculateNetBalances([expense], []);
      // u1 paid 120k, owes 40k -> net +80k
      // u2 paid 0, owes 40k -> net -40k
      // u3 paid 0, owes 40k -> net -40k
      expect(balances['u1'], 80000.0);
      expect(balances['u2'], -40000.0);
      expect(balances['u3'], -40000.0);

      final totalSum = balances.values.reduce((a, b) => a + b);
      expect(totalSum.abs() < 0.001, isTrue);
    });

    test(
      'Confirmed settlement properly reduces debt and preserves zero-sum',
      () {
        final now = DateTime.now();
        final expense = ExpenseModel(
          id: 'e1',
          groupId: 'g1',
          name: 'Dinner',
          amount: 120000,
          payerId: 'u1',
          participantIds: ['u1', 'u2', 'u3'],
          splitMethod: SplitMethod.equal,
          shares: {'u1': 40000, 'u2': 40000, 'u3': 40000},
          category: 'Food',
          date: now,
          photoUrls: const [],
          createdBy: 'u1',
          createdAt: now,
          updatedAt: now,
        );

        // u2 pays u1 40,000 (confirmed)
        final settlement = SettlementModel(
          id: 's1',
          groupId: 'g1',
          payerId: 'u2',
          payeeId: 'u1',
          amount: 40000,
          status: SettlementStatus.confirmed,
          createdAt: now,
        );

        final balances = debtCalc.calculateNetBalances([expense], [settlement]);
        // u2 paid debt -> net balance is now 0
        // u1 was owed 80k, got 40k -> net balance is now +40k
        // u3 still owes 40k -> net balance is -40k
        expect(balances['u2'], 0.0);
        expect(balances['u1'], 40000.0);
        expect(balances['u3'], -40000.0);

        final totalSum = balances.values.reduce((a, b) => a + b);
        expect(totalSum.abs() < 0.001, isTrue);
      },
    );

    test('Pending settlement does NOT alter net balances until confirmed', () {
      final now = DateTime.now();
      final expense = ExpenseModel(
        id: 'e1',
        groupId: 'g1',
        name: 'Dinner',
        amount: 120000,
        payerId: 'u1',
        participantIds: ['u1', 'u2', 'u3'],
        splitMethod: SplitMethod.equal,
        shares: {'u1': 40000, 'u2': 40000, 'u3': 40000},
        category: 'Food',
        date: now,
        photoUrls: const [],
        createdBy: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      final pendingSettlement = SettlementModel(
        id: 's1',
        groupId: 'g1',
        payerId: 'u2',
        payeeId: 'u1',
        amount: 40000,
        status: SettlementStatus.pendingConfirmation,
        createdAt: now,
      );

      final balances = debtCalc.calculateNetBalances(
        [expense],
        [pendingSettlement],
      );
      // Pending settlement ignored
      expect(balances['u2'], -40000.0);
      expect(balances['u1'], 80000.0);
    });
  });

  group('LeaveGroupUseCase - Invariant GRP-I3 Zero Debt on Exit Tests', () {
    late FakeGroupRepository groupRepo;
    late FakeExpenseRepository expenseRepo;
    late FakeDebtRepository debtRepo;
    late FakeSettlementRepository settlementRepo;
    late DebtCalculator debtCalc;
    late LeaveGroupUseCase leaveGroupUseCase;

    setUp(() {
      groupRepo = FakeGroupRepository();
      expenseRepo = FakeExpenseRepository();
      debtRepo = FakeDebtRepository();
      settlementRepo = FakeSettlementRepository();
      debtCalc = DebtCalculator(expenseRepo, debtRepo, settlementRepo);
      leaveGroupUseCase = LeaveGroupUseCase(
        groupRepository: groupRepo,
        debtCalculator: debtCalc,
        settlementRepository: settlementRepo,
      );

      final group = GroupModel(
        id: 'g1',
        name: 'Group 1',
        ownerId: 'u_admin',
        memberIds: ['u_admin', 'u_debtor', 'u_creditor', 'u_clean'],
        createdAt: DateTime.now(),
      );
      groupRepo.setGroup(group);
    });

    test(
      'Blocks member from leaving when member has negative balance',
      () async {
        final now = DateTime.now();
        // Debtor owes 50,000
        expenseRepo.expenses.add(
          ExpenseModel(
            id: 'e1',
            groupId: 'g1',
            name: 'Lunch',
            amount: 50000,
            payerId: 'u_admin',
            participantIds: ['u_debtor'],
            splitMethod: SplitMethod.equal,
            shares: {'u_debtor': 50000},
            category: 'Food',
            date: now,
            photoUrls: const [],
            createdBy: 'u_admin',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(
          () => leaveGroupUseCase.execute(
            groupId: 'g1',
            userId: 'u_debtor',
            requesterId: 'u_debtor',
          ),
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.cannotLeaveWithDebt,
            ),
          ),
        );
      },
    );

    test(
      'Blocks member from leaving when member has positive balance',
      () async {
        final now = DateTime.now();
        // Creditor is owed 50,000
        expenseRepo.expenses.add(
          ExpenseModel(
            id: 'e1',
            groupId: 'g1',
            name: 'Lunch',
            amount: 50000,
            payerId: 'u_creditor',
            participantIds: ['u_admin'],
            splitMethod: SplitMethod.equal,
            shares: {'u_admin': 50000},
            category: 'Food',
            date: now,
            photoUrls: const [],
            createdBy: 'u_creditor',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(
          () => leaveGroupUseCase.execute(
            groupId: 'g1',
            userId: 'u_creditor',
            requesterId: 'u_creditor',
          ),
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.cannotLeaveWithCredit,
            ),
          ),
        );
      },
    );

    test('Blocks member from leaving when pending settlement exists', () async {
      final now = DateTime.now();
      // Net balance is 0, but pending settlement exists
      settlementRepo.settlements.add(
        SettlementModel(
          id: 's1',
          groupId: 'g1',
          payerId: 'u_clean',
          payeeId: 'u_admin',
          amount: 20000,
          status: SettlementStatus.pendingConfirmation,
          createdAt: now,
        ),
      );

      expect(
        () => leaveGroupUseCase.execute(
          groupId: 'g1',
          userId: 'u_clean',
          requesterId: 'u_clean',
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.pendingSettlementExists,
          ),
        ),
      );
    });

    test(
      'Allows member with zero debt and no pending settlements to leave',
      () async {
        await leaveGroupUseCase.execute(
          groupId: 'g1',
          userId: 'u_clean',
          requesterId: 'u_clean',
        );

        final updatedGroup = await groupRepo.getById('g1');
        expect(updatedGroup.memberIds.contains('u_clean'), isFalse);
      },
    );
  });

  group('Group Models & DTOs Integrity Tests', () {
    test('GroupMemberModel SQLite serialization and conversion', () {
      final now = DateTime.now();
      final member = GroupMemberModel(
        id: 'gm1',
        groupId: 'g1',
        userId: 'u1',
        role: 'admin',
        status: 'active',
        joinedAt: now,
      );

      final map = member.toSqlite();
      expect(map['id'], 'gm1');
      expect(map['role'], 'admin');
      expect(map['status'], 'active');
      expect(map['joinedAt'], now.toUtc().millisecondsSinceEpoch);

      final reconstituted = GroupMemberModel.fromSqlite(map);
      expect(reconstituted.id, member.id);
      expect(reconstituted.role, 'admin');
      expect(reconstituted.status, 'active');
      expect(reconstituted.isAdmin, isTrue);
    });

    test('ExpenseSplitModel SQLite serialization with integer VND', () {
      final split = ExpenseSplitModel(
        id: 'es1',
        expenseId: 'e1',
        userId: 'u1',
        amountVnd: 50000,
      );

      final map = split.toSqlite();
      expect(map['shareAmount'], 50000);

      final reconstituted = ExpenseSplitModel.fromSqlite(map);
      expect(reconstituted.amountVnd, 50000);
      expect(reconstituted.shareAmount, 50000);
    });

    test('GroupModel backwards compatibility: adminId points to ownerId', () {
      final group = GroupModel(
        id: 'g1',
        name: 'Trip to Da Nang',
        ownerId: 'user_xyz',
        memberIds: ['user_xyz'],
        createdAt: DateTime.now(),
      );

      expect(group.ownerId, 'user_xyz');
      expect(group.adminId, 'user_xyz');
    });
  });
}
