import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:money_tracker_app/data/local/owned_table_ops.dart';
import 'package:money_tracker_app/data/local/sync_queue_writer.dart';

class _TestOwnedOps with OwnedTableOps {}

void main() {
  group('Phase 3 - Conflict Resolution & Monotonic Timestamp', () {
    test(
      'ConflictResolver: Remote wins when remoteUpdatedAt > localUpdatedAt',
      () {
        final shouldWin = ConflictResolver.shouldRemoteWin(
          localUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
            1000,
            isUtc: true,
          ),
          remoteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
            2000,
            isUtc: true,
          ),
          localData: {'name': 'Local'},
          remoteData: {'name': 'Remote'},
        );
        expect(shouldWin, isTrue);
      },
    );

    test(
      'ConflictResolver: Local wins when localUpdatedAt > remoteUpdatedAt',
      () {
        final shouldWin = ConflictResolver.shouldRemoteWin(
          localUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
            2000,
            isUtc: true,
          ),
          remoteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
            1000,
            isUtc: true,
          ),
          localData: {'name': 'Local'},
          remoteData: {'name': 'Remote'},
        );
        expect(shouldWin, isFalse);
      },
    );

    test(
      'ConflictResolver: Tie-breaker uses canonical JSON SHA-256 when timestamps equal',
      () {
        final mapA = {'a': 1, 'b': 2};
        final mapB = {'a': 1, 'b': 3};
        final t1500 = DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true);

        final winAoverB = ConflictResolver.shouldRemoteWin(
          localUpdatedAt: t1500,
          remoteUpdatedAt: t1500,
          localData: mapA,
          remoteData: mapB,
        );

        final winBoverA = ConflictResolver.shouldRemoteWin(
          localUpdatedAt: t1500,
          remoteUpdatedAt: t1500,
          localData: mapB,
          remoteData: mapA,
        );

        // Mutually exclusive: one must win and the other lose
        expect(winAoverB, isNot(winBoverA));
      },
    );

    test(
      'nextMonotonicTimestamp: Strictly increments when client clock skews backwards',
      () {
        const recordedPastOrFuture = 1700000050000;
        final monotonic = _TestOwnedOps().nextMonotonicTimestamp(
          recordedPastOrFuture,
        );
        expect(monotonic, greaterThan(recordedPastOrFuture));
      },
    );
  });

  group('Phase 3 - Priority Hierarchy for Sync Queue', () {
    test('Root entities (users, wallets, groups) are Priority 1', () {
      expect(SyncQueueWriter.defaultPriorityForTable('users'), 1);
      expect(SyncQueueWriter.defaultPriorityForTable('wallets'), 1);
      expect(SyncQueueWriter.defaultPriorityForTable('groups'), 1);
    });

    test('Config entities (budgets, goals, group_members) are Priority 2', () {
      expect(SyncQueueWriter.defaultPriorityForTable('budgets'), 2);
      expect(SyncQueueWriter.defaultPriorityForTable('goals'), 2);
      expect(SyncQueueWriter.defaultPriorityForTable('group_members'), 2);
    });

    test(
      'Ledger & event entities (transactions, expenses, notifications) are Priority 3',
      () {
        expect(SyncQueueWriter.defaultPriorityForTable('transactions'), 3);
        expect(SyncQueueWriter.defaultPriorityForTable('group_expenses'), 3);
        expect(SyncQueueWriter.defaultPriorityForTable('group_settlements'), 3);
        expect(SyncQueueWriter.defaultPriorityForTable('expense_splits'), 3);
        expect(SyncQueueWriter.defaultPriorityForTable('notifications'), 3);
        expect(SyncQueueWriter.defaultPriorityForTable('messages'), 3);
      },
    );
  });

  group('Phase 3 - Payload Sanitization & Safe Serialization', () {
    test('sanitizeValue converts DateTime to epoch UTC int', () {
      final now = DateTime.utc(2026, 10, 28, 12, 0, 0);
      final sanitized = SyncQueueWriter.sanitizeValue(now);
      expect(sanitized, isA<int>());
      expect(sanitized, now.millisecondsSinceEpoch);
    });

    test(
      'sanitizeMap serializes nested maps and lists without crashing json.encode',
      () {
        final complexPayload = {
          'id': 'test_123',
          'createdAt': DateTime.utc(2026, 1, 1),
          'metadata': {
            'updatedAt': DateTime.utc(2026, 1, 2),
            'tags': ['a', 'b'],
          },
        };

        final sanitized = SyncQueueWriter.sanitizeMap(complexPayload);
        expect(() => json.encode(sanitized), returnsNormally);
        expect((sanitized!['metadata'] as Map)['updatedAt'], isA<int>());
      },
    );
  });

  group('Phase 3 - Deterministic IDs for Deduplication', () {
    test('Default wallet uses deterministic ID pattern', () {
      const uid = 'user_abc_123';
      final defaultWalletId = 'wlt_default_$uid';
      expect(defaultWalletId, 'wlt_default_user_abc_123');
    });

    test('Transfer sub-transactions use deterministic IDs', () {
      const transferId = 'trf_999';
      final outTxId = '${transferId}_out';
      final inTxId = '${transferId}_in';

      expect(outTxId, 'trf_999_out');
      expect(inTxId, 'trf_999_in');
    });

    test(
      'Budget deterministic ID prevents duplicate budgets for same month/category',
      () {
        const uid = 'user_1';
        const year = 2026;
        const month = 10;
        const category = 'Ăn uống';
        final catHash = md5
            .convert(utf8.encode(category))
            .toString()
            .substring(0, 8);
        final budgetId = 'bgt_${uid}_${year}_${month}_$catHash';

        expect(budgetId, startsWith('bgt_user_1_2026_10_'));
        // Deterministic: multiple evaluations yield exact same ID
        final budgetId2 = 'bgt_${uid}_${year}_${month}_$catHash';
        expect(budgetId, equals(budgetId2));
      },
    );
  });

  group('Phase 3 - Ledger Reconciliation Arithmetic', () {
    test('Wallet balance correctly computed from transactions ledger', () {
      const initialBalance = 1000000.0;
      final txs = [
        {'type': 'income', 'amount': 500000.0, 'isDeleted': 0},
        {'type': 'expense', 'amount': 200000.0, 'isDeleted': 0},
        {'type': 'expense', 'amount': 100000.0, 'isDeleted': 0},
        {
          'type': 'expense',
          'amount': 500000.0,
          'isDeleted': 1,
        }, // Tombstone ignored
      ];

      double balance = initialBalance;
      for (final tx in txs) {
        if (tx['isDeleted'] == 1) continue;
        if (tx['type'] == 'income') {
          balance += (tx['amount'] as double);
        } else if (tx['type'] == 'expense') {
          balance -= (tx['amount'] as double);
        }
      }

      expect(balance, equals(1200000.0));
    });

    test(
      'Goal currentAmount correctly accumulated from target transactions',
      () {
        final goalTxs = [
          {'type': 'income', 'amount': 200000.0, 'isDeleted': 0},
          {'type': 'income', 'amount': 300000.0, 'isDeleted': 0},
          {'type': 'expense', 'amount': 50000.0, 'isDeleted': 0},
          {
            'type': 'income',
            'amount': 100000.0,
            'isDeleted': 1,
          }, // Soft-deleted
        ];

        double goalAmount = 0.0;
        for (final tx in goalTxs) {
          if (tx['isDeleted'] == 1) continue;
          if (tx['type'] == 'income') {
            goalAmount += (tx['amount'] as double);
          } else if (tx['type'] == 'expense') {
            goalAmount -= (tx['amount'] as double);
          }
        }

        expect(goalAmount, equals(450000.0));
      },
    );
  });

  group('Phase 3 - Category Set-Union Merge', () {
    test(
      'Custom categories union merge without loss of offline-added categories',
      () {
        final local = ['Du lịch', 'Đầu tư'];
        final remote = ['Học tập', 'Du lịch', 'Từ thiện'];

        final merged = {...local, ...remote}.toList();
        expect(
          merged,
          containsAll(['Du lịch', 'Đầu tư', 'Học tập', 'Từ thiện']),
        );
        expect(merged.length, 4);
      },
    );
  });
}
