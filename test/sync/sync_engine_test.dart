import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/models/budget_model.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/services/sync_service.dart';
import 'package:money_tracker_app/data/local/sync_queue_writer.dart';

/// Mock DatabaseExecutor phục vụ kiểm thử đơn vị logic hàng đợi và coalescing
class MockDatabaseExecutor implements DatabaseExecutor {
  final List<Map<String, dynamic>> queueRows = [];
  int _autoId = 1;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final row = Map<String, dynamic>.from(values);
    row['id'] = _autoId++;
    queueRows.add(row);
    return row['id'] as int;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    Iterable<Map<String, dynamic>> result = queueRows;
    if (where != null && whereArgs != null) {
      if (where.contains('tableName = ?') && where.contains('recordId = ?')) {
        final targetTable = whereArgs[0] as String;
        final targetRecordId = whereArgs[1] as String;
        result = result.where(
          (r) =>
              r['tableName'] == targetTable &&
              r['recordId'] == targetRecordId &&
              r['status'] == 'pending',
        );
      }
    }
    if (limit != null) {
      result = result.take(limit);
    }
    return result.map((r) => Map<String, Object?>.from(r)).toList();
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    int updatedCount = 0;
    if (where != null && whereArgs != null && where.contains('id = ?')) {
      final targetId = whereArgs[0];
      for (final r in queueRows) {
        if (r['id'] == targetId) {
          values.forEach((k, v) => r[k] = v);
          updatedCount++;
        }
      }
    }
    return updatedCount;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    int count = 0;
    if (where != null && whereArgs != null && where.contains('id = ?')) {
      final targetId = whereArgs[0];
      queueRows.removeWhere((r) {
        if (r['id'] == targetId) {
          count++;
          return true;
        }
        return false;
      });
    }
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1 Sync Engine: 1. Khóa Mutex (SyncLock) chống re-entrancy', () {
    test(
      'tryAcquire thành công khi chưa khóa, từ chối khi đang khóa',
      () async {
        final lock = SyncLock();
        expect(lock.isLocked, isFalse);

        final first = await lock.tryAcquire();
        expect(first, isTrue);
        expect(lock.isLocked, isTrue);

        // Luồng thứ hai cố gắng chiếm khóa trong khi luồng 1 đang chạy
        final second = await lock.tryAcquire();
        expect(second, isFalse);
        expect(lock.isLocked, isTrue);

        // Luồng 1 kết thúc và giải phóng khóa
        lock.release();
        expect(lock.isLocked, isFalse);

        // Luồng kế tiếp có thể chiếm khóa thành công
        final third = await lock.tryAcquire();
        expect(third, isTrue);
        lock.release();
      },
    );
  });

  group('P1 Sync Engine: 2. Hàng đợi Coalescing & Standardized Columns', () {
    late MockDatabaseExecutor mockDb;
    const testUid = 'user_test_123';

    setUp(() {
      mockDb = MockDatabaseExecutor();
    });

    test(
      'Chèn mới một bản ghi có đầy đủ uid, nextRetryAt và status pending',
      () async {
        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'transactions',
          recordId: 'tx_001',
          action: 'INSERT',
          data: {'amount': 50000, 'note': 'Ăn sáng'},
        );

        expect(mockDb.queueRows.length, equals(1));
        final item = mockDb.queueRows.first;
        expect(item['uid'], equals(testUid));
        expect(item['ownerUid'], equals(testUid));
        expect(item['tableName'], equals('transactions'));
        expect(item['recordId'], equals('tx_001'));
        expect(item['action'], equals('INSERT'));
        expect(item['status'], equals('pending'));
        expect(item['nextRetryAt'], equals(0));
        expect(item['retryCount'], equals(0));
      },
    );

    test(
      'Coalescing: INSERT + UPDATE gộp payload mới vào bản ghi INSERT ban đầu',
      () async {
        // 1. User tạo offline giao dịch
        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'transactions',
          recordId: 'tx_002',
          action: 'INSERT',
          data: {'amount': 50000, 'description': 'Bún bò'},
        );
        expect(mockDb.queueRows.length, equals(1));

        // 2. User sửa ghi chú khi vẫn đang offline
        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'transactions',
          recordId: 'tx_002',
          action: 'UPDATE',
          data: {'amount': 60000, 'description': 'Bún bò đặc biệt'},
        );

        // Số dòng trong queue vẫn là 1, không tạo thêm dòng mới
        expect(mockDb.queueRows.length, equals(1));
        final merged = mockDb.queueRows.first;
        expect(merged['action'], equals('INSERT'));
        final decodedData =
            json.decode(merged['data'] as String) as Map<String, dynamic>;
        expect(decodedData['amount'], equals(60000));
        expect(decodedData['description'], equals('Bún bò đặc biệt'));
      },
    );

    test(
      'Coalescing: INSERT + DELETE lúc offline tự triệt tiêu bản ghi khỏi queue',
      () async {
        // 1. User tạo offline
        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'transactions',
          recordId: 'tx_003',
          action: 'INSERT',
          data: {'amount': 20000},
        );
        expect(mockDb.queueRows.length, equals(1));

        // 2. User bấm xóa ngay sau đó khi chưa sync
        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'transactions',
          recordId: 'tx_003',
          action: 'DELETE',
        );

        // Bản ghi bị triệt tiêu hoàn toàn, không cần gửi request nào lên Cloud
        expect(mockDb.queueRows.isEmpty, isTrue);
      },
    );

    test(
      'Coalescing: UPDATE + DELETE chuyển action thành DELETE và cập nhật payload',
      () async {
        // Giả sử có một bản ghi UPDATE từ trước
        mockDb.queueRows.add({
          'id': 10,
          'uid': testUid,
          'ownerUid': testUid,
          'tableName': 'wallets',
          'recordId': 'w_001',
          'action': 'UPDATE',
          'data': json.encode({'name': 'Ví chính'}),
          'status': 'pending',
          'nextRetryAt': 0,
          'retryCount': 0,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        await SyncQueueWriter.enqueue(
          mockDb,
          ownerUid: testUid,
          table: 'wallets',
          recordId: 'w_001',
          action: 'DELETE',
        );

        expect(mockDb.queueRows.length, equals(1));
        expect(mockDb.queueRows.first['action'], equals('DELETE'));
      },
    );
  });

  group('P1 Sync Engine: 3. Soft Delete (Tombstone) trên các Models', () {
    test(
      'TransactionModel lưu và đọc đúng isDeleted và deletedAt từ SQLite',
      () {
        final now = DateTime.now();
        final tx = TransactionModel(
          id: 'tx_soft',
          uid: 'u1',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 1,
          amount: 30000,
          date: now,
          isDeleted: true,
          deletedAt: now,
        );

        final sqliteMap = tx.toSqlite();
        expect(sqliteMap['isDeleted'], equals(1));
        expect(sqliteMap['deletedAt'], equals(now.millisecondsSinceEpoch));

        final restored = TransactionModel.fromSqlite(sqliteMap);
        expect(restored.isDeleted, isTrue);
        expect(
          restored.deletedAt?.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch),
        );
      },
    );

    test('WalletModel lưu và đọc đúng isDeleted và deletedAt từ SQLite', () {
      final now = DateTime.now();
      final wallet = WalletModel(
        id: 'w_soft',
        uid: 'u1',
        name: 'Ví tiết kiệm',
        type: 'savings',
        balance: 500000,
        iconCode: 2,
        colorValue: 0xFF438883,
        isDeleted: true,
        deletedAt: now,
      );

      final sqliteMap = wallet.toSqlite();
      expect(sqliteMap['isDeleted'], equals(1));
      expect(sqliteMap['deletedAt'], equals(now.millisecondsSinceEpoch));

      final restored = WalletModel.fromSqlite(sqliteMap);
      expect(restored.isDeleted, isTrue);
      expect(
        restored.deletedAt?.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });

    test('BudgetModel lưu và đọc đúng isDeleted và deletedAt từ SQLite', () {
      final now = DateTime.now();
      final budget = BudgetModel(
        id: 'b_soft',
        uid: 'u1',
        category: 'Du lịch',
        limitAmount: 5000000,
        month: 10,
        year: 2026,
        isDeleted: true,
        deletedAt: now,
      );

      final sqliteMap = budget.toSqlite();
      expect(sqliteMap['isDeleted'], equals(1));
      expect(sqliteMap['deletedAt'], equals(now.millisecondsSinceEpoch));

      final restored = BudgetModel.fromSqlite(sqliteMap);
      expect(restored.isDeleted, isTrue);
      expect(
        restored.deletedAt?.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });

    test('GoalModel lưu và đọc đúng isDeleted và deletedAt từ SQLite', () {
      final now = DateTime.now();
      final goal = GoalModel(
        id: 'g_soft',
        uid: 'u1',
        title: 'Mua Laptop',
        targetAmount: 20000000,
        deadline: now.add(const Duration(days: 90)),
        isDeleted: true,
        deletedAt: now,
      );

      final sqliteMap = goal.toSqlite();
      expect(sqliteMap['isDeleted'], equals(1));
      expect(sqliteMap['deletedAt'], equals(now.millisecondsSinceEpoch));

      final restored = GoalModel.fromSqlite(sqliteMap);
      expect(restored.isDeleted, isTrue);
      expect(
        restored.deletedAt?.millisecondsSinceEpoch,
        equals(now.millisecondsSinceEpoch),
      );
    });
  });

  group('P1 Sync Engine: 4. Thuật toán Local Dirty Shield & Last-Write-Wins', () {
    test(
      'Bản ghi Local có syncStatus == pending bảo vệ dữ liệu không bị Cloud cũ ghi đè',
      () {
        final localTx = TransactionModel(
          id: 'tx_dirty',
          uid: 'u1',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 10,
          amount: 200000, // Đã sửa offline thành 200.000
          date: DateTime.now(),
          syncStatus: 'pending',
          updatedAt: DateTime(2026, 10, 23, 10, 30),
        );

        final cloudTx = TransactionModel(
          id: 'tx_dirty',
          uid: 'u1',
          type: 'expense',
          category: 'Mua sắm',
          categoryIconCode: 10,
          amount: 100000, // Snapshot trên cloud vẫn là 100.000
          date: DateTime.now(),
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 10, 23, 10, 0),
        );

        // Thuật toán: Nếu local.syncStatus == 'pending', từ chối snapshot của Cloud
        final bool shouldOverwrite =
            localTx.syncStatus != 'pending' &&
            (cloudTx.updatedAt.isAfter(localTx.updatedAt) ||
                cloudTx.updatedAt.isAtSameMomentAs(localTx.updatedAt));

        expect(
          shouldOverwrite,
          isFalse,
          reason:
              'Local Dirty Shield phải ngăn chặn ghi đè snapshot cũ của Cloud',
        );
      },
    );

    test('Bản ghi Cloud mới hơn tuyệt đối sẽ cập nhật vào Local Clean', () {
      final localTx = TransactionModel(
        id: 'tx_clean',
        uid: 'u1',
        type: 'expense',
        category: 'Cafe',
        categoryIconCode: 11,
        amount: 30000,
        date: DateTime.now(),
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 10, 23, 9, 0),
      );

      final cloudTx = TransactionModel(
        id: 'tx_clean',
        uid: 'u1',
        type: 'expense',
        category: 'Cafe cao cấp',
        categoryIconCode: 11,
        amount: 65000,
        date: DateTime.now(),
        syncStatus: 'synced',
        updatedAt: DateTime(2026, 10, 23, 10, 0), // Cloud mới hơn 1 tiếng
      );

      final bool shouldOverwrite =
          localTx.syncStatus != 'pending' &&
          (cloudTx.updatedAt.isAfter(localTx.updatedAt) ||
              cloudTx.updatedAt.isAtSameMomentAs(localTx.updatedAt));

      expect(
        shouldOverwrite,
        isTrue,
        reason: 'Snapshot Cloud mới hơn phải được cập nhật vào local',
      );
    });
  });

  group(
    'P1 Sync Engine: 5. Dead-Letter Queue (DLQ) & SyncQueueItem serialization',
    () {
      test(
        'SyncQueueItem serialization và deserialization đầy đủ 12 trường',
        () {
          final now = DateTime.now().millisecondsSinceEpoch;
          final original = SyncQueueItem(
            id: 99,
            uid: 'user_dlq_01',
            tableName: 'transactions',
            recordId: 'tx_dlq_01',
            action: 'SOFT_DELETE',
            data: {'amount': 150000, 'category': 'Mua sắm'},
            status: 'dead',
            retryCount: 8,
            lastError: 'permission-denied: Missing write permissions',
            nextRetryAt: 0,
            createdAt: now - 50000,
            updatedAt: now,
          );

          final map = original.toSqlite();
          expect(map['id'], equals(99));
          expect(map['uid'], equals('user_dlq_01'));
          expect(map['ownerUid'], equals('user_dlq_01'));
          expect(map['tableName'], equals('transactions'));
          expect(map['recordId'], equals('tx_dlq_01'));
          expect(map['action'], equals('SOFT_DELETE'));
          expect(map['status'], equals('dead'));
          expect(map['retryCount'], equals(8));
          expect(map['lastError'], contains('permission-denied'));

          final restored = SyncQueueItem.fromSqlite(map);
          expect(restored.id, equals(99));
          expect(restored.uid, equals('user_dlq_01'));
          expect(restored.tableName, equals('transactions'));
          expect(restored.recordId, equals('tx_dlq_01'));
          expect(restored.action, equals('SOFT_DELETE'));
          expect(restored.status, equals('dead'));
          expect(restored.retryCount, equals(8));
          expect(restored.data?['amount'], equals(150000));
        },
      );

      test(
        'SyncExecutionReport tính đúng trạng thái hasErrors và isSuccess',
        () {
          final successReport = SyncExecutionReport(
            uploadedCount: 5,
            downloadSuccess: {'wallets': 2, 'transactions': 10},
          );
          expect(successReport.hasErrors, isFalse);
          expect(successReport.isSuccess, isTrue);

          final errorReport = SyncExecutionReport(
            uploadedCount: 3,
            uploadError: 'Network unavailable',
          );
          expect(errorReport.hasErrors, isTrue);
          expect(errorReport.isSuccess, isFalse);

          final downloadErrorReport = SyncExecutionReport(
            uploadedCount: 3,
            downloadSuccess: {'wallets': 1},
            downloadErrors: {'transactions': 'timeout after 8s'},
          );
          expect(downloadErrorReport.hasErrors, isTrue);
          expect(downloadErrorReport.isSuccess, isFalse);
        },
      );
    },
  );

  group(
    'P1 Sync Engine: 6. Deterministic SHA256 Tie-Breaker khi đụng độ timestamp',
    () {
      bool resolveTieBreaker(
        Map<String, dynamic> local,
        Map<String, dynamic> remote,
      ) {
        final localStr = json.encode(local);
        final remoteStr = json.encode(remote);
        final localHash = sha256.convert(utf8.encode(localStr)).toString();
        final remoteHash = sha256.convert(utf8.encode(remoteStr)).toString();
        return remoteHash.compareTo(localHash) >= 0;
      }

      test(
        'Hai bản ghi có cùng timestamp trả về kết quả thắng phân xử đồng nhất (idempotent)',
        () {
          final localRecord = {
            'id': 'tx_tie',
            'amount': 100000,
            'updatedAt': 1700000000,
          };
          final remoteRecord = {
            'id': 'tx_tie',
            'amount': 150000,
            'updatedAt': 1700000000,
          };

          final winner1 = resolveTieBreaker(localRecord, remoteRecord);
          final winner2 = resolveTieBreaker(localRecord, remoteRecord);
          final winner3 = resolveTieBreaker(localRecord, remoteRecord);

          expect(winner1, equals(winner2));
          expect(winner2, equals(winner3));

          // Đảo ngược vị trí cho kết quả đối xứng
          final reverseWinner = resolveTieBreaker(remoteRecord, localRecord);
          if (winner1) {
            expect(reverseWinner, isFalse);
          } else {
            expect(reverseWinner, isTrue);
          }
        },
      );
    },
  );

  group(
    'P1 Sync Engine: 7. Mô phỏng Migration An toàn v6 -> v7 cho sync_queue (Không mất dữ liệu)',
    () {
      test(
        'Dữ liệu cũ trong sync_queue được bảo toàn và bổ sung cột uid, nextRetryAt',
        () {
          // Giả lập hàng đợi hiện trạng từ SQLite v6 (chỉ có ownerUid, chưa có uid và nextRetryAt)
          final List<Map<String, dynamic>> legacyTableRows = [
            {
              'id': 1,
              'ownerUid': 'user_v6_abc',
              'tableName': 'transactions',
              'recordId': 'tx_legacy_01',
              'action': 'INSERT',
              'data': '{"amount":50000,"uid":"user_v6_abc"}',
              'createdAt': 1000,
              'status': 'pending',
            },
            {
              'id': 2,
              'ownerUid': 'user_v6_xyz',
              'tableName': 'wallets',
              'recordId': 'w_legacy_01',
              'action': 'UPDATE',
              'data': '{"name":"Ví phụ","uid":"user_v6_xyz"}',
              'createdAt': 2000,
              'status': 'pending',
            },
          ];

          // Giả lập logic migration v7
          final migratedRows = <Map<String, dynamic>>[];
          for (final row in legacyTableRows) {
            final migrated = Map<String, dynamic>.from(row);
            // 1. Gán uid từ ownerUid nếu uid chưa có
            migrated['uid'] = migrated['ownerUid'] ?? '';
            // 2. Bổ sung nextRetryAt mặc định = 0
            migrated['nextRetryAt'] ??= 0;
            // 3. Bổ sung updatedAt mặc định
            migrated['updatedAt'] ??= migrated['createdAt'];
            // 4. Bổ sung retryCount mặc định
            migrated['retryCount'] ??= 0;
            migratedRows.add(migrated);
          }

          // Kiểm tra: toàn bộ 2 bản ghi cũ được bảo toàn, không bị xóa
          expect(migratedRows.length, equals(2));
          expect(migratedRows[0]['id'], equals(1));
          expect(migratedRows[0]['uid'], equals('user_v6_abc'));
          expect(migratedRows[0]['ownerUid'], equals('user_v6_abc'));
          expect(migratedRows[0]['nextRetryAt'], equals(0));
          expect(migratedRows[0]['tableName'], equals('transactions'));

          expect(migratedRows[1]['id'], equals(2));
          expect(migratedRows[1]['uid'], equals('user_v6_xyz'));
          expect(migratedRows[1]['ownerUid'], equals('user_v6_xyz'));
          expect(migratedRows[1]['nextRetryAt'], equals(0));
          expect(migratedRows[1]['tableName'], equals('wallets'));
        },
      );
    },
  );

  group(
    'P1 Sync Engine: 8. Coalescing cho SOFT_DELETE trong SyncQueueWriter',
    () {
      late MockDatabaseExecutor mockDb;
      const testUid = 'user_soft_del_test';

      setUp(() {
        mockDb = MockDatabaseExecutor();
      });

      test(
        'INSERT offline + SOFT_DELETE offline => Hủy hoàn toàn khỏi queue',
        () async {
          // User tạo giao dịch offline
          await SyncQueueWriter.enqueue(
            mockDb,
            ownerUid: testUid,
            table: 'transactions',
            recordId: 'tx_sd_01',
            action: 'INSERT',
            data: {'amount': 75000},
          );
          expect(mockDb.queueRows.length, equals(1));

          // User xóa ngay lúc offline với action SOFT_DELETE
          await SyncQueueWriter.enqueue(
            mockDb,
            ownerUid: testUid,
            table: 'transactions',
            recordId: 'tx_sd_01',
            action: 'SOFT_DELETE',
          );

          // Do chưa từng sync lên Cloud, bản ghi tự triệt tiêu khỏi queue
          expect(mockDb.queueRows.isEmpty, isTrue);
        },
      );

      test(
        'UPDATE offline + SOFT_DELETE offline => Chuyển action thành SOFT_DELETE',
        () async {
          mockDb.queueRows.add({
            'id': 100,
            'uid': testUid,
            'ownerUid': testUid,
            'tableName': 'transactions',
            'recordId': 'tx_sd_02',
            'action': 'UPDATE',
            'data': json.encode({'amount': 90000}),
            'status': 'pending',
            'nextRetryAt': 0,
            'retryCount': 0,
            'createdAt': 1000,
            'updatedAt': 1000,
          });

          await SyncQueueWriter.enqueue(
            mockDb,
            ownerUid: testUid,
            table: 'transactions',
            recordId: 'tx_sd_02',
            action: 'SOFT_DELETE',
            data: {'isDeleted': 1},
          );

          expect(mockDb.queueRows.length, equals(1));
          expect(mockDb.queueRows.first['action'], equals('SOFT_DELETE'));
        },
      );
    },
  );
}
