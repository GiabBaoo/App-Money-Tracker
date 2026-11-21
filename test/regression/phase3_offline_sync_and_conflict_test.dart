import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/data/local/owned_table_ops.dart';
import 'package:money_tracker_app/data/local/sync_queue_writer.dart';
import 'package:money_tracker_app/services/sync_service.dart';

class _TestOwnedOps with OwnedTableOps {}

void main() {
  group('Phase 3 Regression Tests: Offline-First Sync & Conflict Resolution', () {
    test('SYNC-01: ConflictResolver Last-Write-Wins: newer remote wins over older local', () {
      final localTime = DateTime.utc(2026, 10, 20, 10, 0, 0);
      final remoteTime = DateTime.utc(2026, 10, 20, 10, 0, 1);

      final shouldWin = ConflictResolver.shouldRemoteWin(
        localUpdatedAt: localTime,
        remoteUpdatedAt: remoteTime,
        localData: {'balance': 100000},
        remoteData: {'balance': 200000},
      );

      expect(shouldWin, isTrue);
    });

    test('SYNC-02: ConflictResolver Last-Write-Wins: newer local wins over older remote', () {
      final localTime = DateTime.utc(2026, 10, 20, 10, 5, 0);
      final remoteTime = DateTime.utc(2026, 10, 20, 10, 0, 0);

      final shouldWin = ConflictResolver.shouldRemoteWin(
        localUpdatedAt: localTime,
        remoteUpdatedAt: remoteTime,
        localData: {'balance': 100000},
        remoteData: {'balance': 200000},
      );

      expect(shouldWin, isFalse);
    });

    test('SYNC-03: ConflictResolver Tie-Breaker: equal timestamps resolved deterministically by SHA-256', () {
      final sameTime = DateTime.utc(2026, 10, 20, 10, 0, 0);

      final localData = {'id': 'w_1', 'name': 'Wallet A', 'balance': 50000};
      final remoteData = {'id': 'w_1', 'name': 'Wallet B', 'balance': 60000};

      final decision1 = ConflictResolver.shouldRemoteWin(
        localUpdatedAt: sameTime,
        remoteUpdatedAt: sameTime,
        localData: localData,
        remoteData: remoteData,
      );

      // Chạy lại phải cho kết quả giống hệt 100% (Deterministic)
      final decision2 = ConflictResolver.shouldRemoteWin(
        localUpdatedAt: sameTime,
        remoteUpdatedAt: sameTime,
        localData: localData,
        remoteData: remoteData,
      );

      expect(decision1, equals(decision2));
    });

    test('SYNC-04: ConflictResolver ignores volatile local fields (syncStatus, photoLocalPath)', () {
      final localData = {
        'id': 'tx_1',
        'amount': 50000,
        'syncStatus': 'pending',
        'photoLocalPath': '/data/user/photo.jpg',
      };

      final remoteData = {
        'id': 'tx_1',
        'amount': 50000,
        'syncStatus': 'synced',
      };

      // Khi đã loại trừ volatile fields, hai map trở nên giống hệt nhau
      final tieBreakerResult = ConflictResolver.resolveTieBreaker(localData, remoteData);
      expect(tieBreakerResult, isTrue);
    });

    test('SYNC-05: SyncQueueWriter table priority tiered architecture', () {
      // Tier 1: Master entities
      expect(SyncQueueWriter.defaultPriorityForTable('users'), 1);
      expect(SyncQueueWriter.defaultPriorityForTable('wallets'), 1);
      expect(SyncQueueWriter.defaultPriorityForTable('groups'), 1);

      // Tier 2: Config & Child entities
      expect(SyncQueueWriter.defaultPriorityForTable('budgets'), 2);
      expect(SyncQueueWriter.defaultPriorityForTable('goals'), 2);
      expect(SyncQueueWriter.defaultPriorityForTable('group_members'), 2);

      // Tier 3: Ledger & Log entities
      expect(SyncQueueWriter.defaultPriorityForTable('transactions'), 3);
      expect(SyncQueueWriter.defaultPriorityForTable('group_expenses'), 3);
      expect(SyncQueueWriter.defaultPriorityForTable('group_settlements'), 3);
      expect(SyncQueueWriter.defaultPriorityForTable('messages'), 3);
      expect(SyncQueueWriter.defaultPriorityForTable('notifications'), 3);
    });

    test('SYNC-06: SyncQueueWriter sanitizeValue sanitizes DateTime into integer UTC', () {
      final now = DateTime.utc(2026, 10, 28, 12, 0, 0);
      final sanitized = SyncQueueWriter.sanitizeValue(now);
      expect(sanitized, isA<int>());
      expect(sanitized, now.millisecondsSinceEpoch);

      final map = {
        'date': now,
        'amount': 100000,
        'nested': {'createdAt': now},
      };
      final sanitizedMap = SyncQueueWriter.sanitizeMap(map);
      expect(sanitizedMap!['date'], now.millisecondsSinceEpoch);
      expect((sanitizedMap['nested'] as Map)['createdAt'], now.millisecondsSinceEpoch);
      // Đảm bảo json.encode chạy mượt mà không lỗi
      expect(() => json.encode(sanitizedMap), returnsNormally);
    });

    test('SYNC-07: SyncQueueItem model serialization roundtrip', () {
      final item = SyncQueueItem(
        id: 1,
        uid: 'user_test_999',
        tableName: 'wallets',
        recordId: 'w_1',
        action: 'UPDATE',
        data: {'name': 'Ví chính', 'balance': 500000},
        status: 'pending',
        retryCount: 0,
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      final map = item.toSqlite();
      expect(map['tableName'], 'wallets');
      expect(map['action'], 'UPDATE');
      expect(map['data'], contains('500000'));

      final reconstructed = SyncQueueItem.fromSqlite(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.uid, 'user_test_999');
      expect(reconstructed.tableName, 'wallets');
      expect(reconstructed.data?['balance'], 500000);
      expect(reconstructed.status, 'pending');
    });

    test('SYNC-08: OwnedTableOps nextMonotonicTimestamp guarantees monotonic progression', () {
      final ops = _TestOwnedOps();
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Clock nhảy lùi về quá khứ (ví dụ người dùng chỉnh giờ điện thoại)
      final pastClock = nowMs - 100000;
      final monotonic1 = ops.nextMonotonicTimestamp(nowMs);
      expect(monotonic1, greaterThan(nowMs));

      final monotonic2 = ops.nextMonotonicTimestamp(pastClock);
      expect(monotonic2, greaterThan(pastClock));
    });
  });
}

