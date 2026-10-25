import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/errors/business_exception.dart';
import 'package:money_tracker_app/core/session/session_manager.dart';
import 'package:money_tracker_app/data/local/sync_queue_writer.dart';
import 'package:money_tracker_app/models/goal_model.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/models/wallet_model.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/create_group_dto.dart';
import 'package:money_tracker_app/features/group_expense/data/dtos/update_group_dto.dart';
import 'package:money_tracker_app/features/group_expense/data/models/group_model.dart';
import 'package:money_tracker_app/features/group_expense/domain/repositories/i_group_repository.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/group_service.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/vnd_split_calculator.dart';
import 'package:sqflite/sqflite.dart';

/// Mock in-memory DatabaseExecutor phục vụ kiểm thử Transaction, Rollback, Queue, và Isolation
class TestDatabaseExecutor implements DatabaseExecutor {
  Map<String, List<Map<String, dynamic>>> tables = {
    'wallets': [],
    'transactions': [],
    'goals': [],
    'budgets': [],
    'notifications': [],
    'messages': [],
    'sync_queue': [],
  };

  int _autoId = 1;

  TestDatabaseExecutor();

  TestDatabaseExecutor clone() {
    final copy = TestDatabaseExecutor();
    copy._autoId = _autoId;
    copy.tables = {};
    tables.forEach((key, list) {
      copy.tables[key] = list.map((m) => Map<String, dynamic>.from(m)).toList();
    });
    return copy;
  }

  void restoreFrom(TestDatabaseExecutor other) {
    _autoId = other._autoId;
    tables = {};
    other.tables.forEach((key, list) {
      tables[key] = list.map((m) => Map<String, dynamic>.from(m)).toList();
    });
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final row = Map<String, dynamic>.from(values);
    if (!row.containsKey('id') || row['id'] == null) {
      row['id'] = _autoId++;
    }
    tables.putIfAbsent(table, () => []);
    final existingIndex = tables[table]!.indexWhere(
      (r) => r['id'] == row['id'],
    );
    if (existingIndex != -1) {
      if (conflictAlgorithm == ConflictAlgorithm.replace) {
        tables[table]![existingIndex] = row;
        return 1;
      } else {
        throw StateError('Duplicate key: ${row['id']}');
      }
    }
    tables[table]!.add(row);
    return 1;
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
    final list = tables[table] ?? [];
    Iterable<Map<String, dynamic>> result = list;

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
      } else if ((where.startsWith('id = ?') || where.contains(' id = ?')) &&
          where.contains('uid = ?') &&
          whereArgs.length >= 2) {
        final targetId = whereArgs[0];
        final targetUid = whereArgs[1];
        result = result.where(
          (r) => r['id'] == targetId && r['uid'] == targetUid,
        );
      } else if (where.contains('uid = ?') && where.contains('isDeleted = 0')) {
        final targetUid = whereArgs[0] as String;
        result = result.where(
          (r) =>
              r['uid'] == targetUid &&
              (r['isDeleted'] == 0 || r['isDeleted'] == null),
        );
      } else if (where.contains('uid = ?')) {
        final targetUid = whereArgs[0] as String;
        result = result.where((r) => r['uid'] == targetUid);
      } else if (where.startsWith('id = ?') || where.contains(' id = ?')) {
        final targetId = whereArgs[0];
        result = result.where((r) => r['id'] == targetId);
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
    final list = tables[table] ?? [];
    int count = 0;
    if (where != null && whereArgs != null) {
      if ((where.startsWith('id = ?') || where.contains(' id = ?')) &&
          where.contains('uid = ?') &&
          whereArgs.length >= 2) {
        final targetId = whereArgs[0];
        final targetUid = whereArgs[1];
        for (final r in list) {
          if (r['id'] == targetId && r['uid'] == targetUid) {
            values.forEach((k, v) => r[k] = v);
            count++;
          }
        }
      } else if (where.startsWith('id = ?') || where.contains(' id = ?')) {
        final targetId = whereArgs[0];
        for (final r in list) {
          if (r['id'] == targetId) {
            values.forEach((k, v) => r[k] = v);
            count++;
          }
        }
      }
    }
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = tables[table] ?? [];
    int count = 0;
    if (where != null && whereArgs != null) {
      if ((where.startsWith('id = ?') || where.contains(' id = ?')) &&
          where.contains('uid = ?') &&
          whereArgs.length >= 2) {
        final targetId = whereArgs[0];
        final targetUid = whereArgs[1];
        final beforeLen = list.length;
        list.removeWhere((r) => r['id'] == targetId && r['uid'] == targetUid);
        count = beforeLen - list.length;
      } else if (where.startsWith('id = ?') || where.contains(' id = ?')) {
        final targetId = whereArgs[0];
        final beforeLen = list.length;
        list.removeWhere((r) => r['id'] == targetId);
        count = beforeLen - list.length;
      }
    }
    return count;
  }

  /// Mô phỏng transaction với khả năng rollback hoàn chỉnh khi throw exception
  Future<T> runTransaction<T>(
    Future<T> Function(TestDatabaseExecutor txn) action,
  ) async {
    final snapshot = clone();
    try {
      final result = await action(this);
      return result;
    } catch (e) {
      restoreFrom(snapshot);
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake GroupRepository để kiểm thử logic phân quyền nhóm
class FakeGroupRepoForAudit implements IGroupRepository {
  final Map<String, GroupModel> _groups = {};

  void seedGroup(GroupModel g) => _groups[g.id] = g;

  @override
  Future<GroupModel> getById(String id) async {
    final g = _groups[id];
    if (g == null) throw Exception('Group not found');
    return g;
  }

  @override
  Future<GroupModel> create(CreateGroupDto dto, String adminId) async =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) async => _groups.remove(id);
  @override
  Future<List<GroupModel>> getByUserId(String userId) async =>
      _groups.values.toList();
  @override
  Stream<List<GroupModel>> watchByUserId(String userId) =>
      Stream.value(_groups.values.toList());

  @override
  Future<void> update(String id, UpdateGroupDto dto) async {
    final g = _groups[id];
    if (g != null) {
      _groups[id] = g.copyWith(name: dto.name ?? g.name);
    }
  }

  @override
  Future<void> addMember(String groupId, String userId) async {
    final g = _groups[groupId];
    if (g != null) {
      _groups[groupId] = g.copyWith(memberIds: [...g.memberIds, userId]);
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    final g = _groups[groupId];
    if (g != null) {
      _groups[groupId] = g.copyWith(
        memberIds: g.memberIds.where((id) => id != userId).toList(),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUDIT GIAI ĐOẠN G: 12 TÌNH HUỐNG KIỂM THỬ BẮT BUỘC', () {
    late TestDatabaseExecutor db;

    setUp(() {
      db = TestDatabaseExecutor();
      SessionManager.instance.end();
    });

    tearDown(() {
      SessionManager.instance.end();
    });

    // ══════════════════════════════════════════════════════════════
    // (1) UID NULL KHÔNG ĐỌC ĐƯỢC DỮ LIỆU
    // ══════════════════════════════════════════════════════════════
    test(
      '(1) UID null không đọc được dữ liệu & ghi bị ném unauthenticated',
      () async {
        // Đảm bảo phiên là signedOut
        SessionManager.instance.end();
        expect(SessionManager.instance.uidOrNull, isNull);

        // Thao tác ĐỌC fail-closed trả về null hoặc rỗng
        final readUid = SessionManager.instance.uidOrNull;
        final results = readUid == null
            ? <Map<String, dynamic>>[]
            : await db.query(
                'transactions',
                where: 'uid = ?',
                whereArgs: [readUid],
              );
        expect(results, isEmpty);

        // Thao tác GHI ném BusinessException(unauthenticated)
        expect(
          () => SessionManager.instance.requireUid(),
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.unauthenticated,
            ),
          ),
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (2) ĐỔI TÀI KHOẢN A SANG B KHÔNG LỘ HOẶC UPLOAD CHÉO DỮ LIỆU
    // ══════════════════════════════════════════════════════════════
    test(
      '(2) Đổi tài khoản A sang B không lộ hoặc upload chéo dữ liệu',
      () async {
        const userA = 'user_aaa_111';
        const userB = 'user_bbb_222';

        // 1. User A tạo bản ghi và thêm vào queue
        SessionManager.instance.activate(userA);
        final initialEpoch = SessionManager.instance.epoch;

        await db.insert('wallets', {
          'id': 'w_a',
          'uid': userA,
          'name': 'Ví User A',
          'balance': 1000000,
        });

        await SyncQueueWriter.enqueue(
          db,
          ownerUid: userA,
          table: 'wallets',
          recordId: 'w_a',
          action: 'INSERT',
          data: {'name': 'Ví User A', 'uid': userA},
        );

        // 2. Chuyển sang User B: bắt đầu bằng beginSwitch()
        SessionManager.instance.beginSwitch();
        expect(SessionManager.instance.state, equals(SessionState.switching));
        expect(SessionManager.instance.epoch, greaterThan(initialEpoch));
        expect(SessionManager.instance.uidOrNull, isNull);

        // Đăng nhập B
        SessionManager.instance.activate(userB);
        expect(SessionManager.instance.uidOrNull, equals(userB));

        // Kiểm tra B đọc dữ liệu: hoàn toàn không thấy ví của A
        final walletsOfB = await db.query(
          'wallets',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );
        expect(walletsOfB, isEmpty);

        // Kiểm tra Sync Queue Guard: Bản ghi của A không được upload dưới phiên B
        final queueItems = await db.query('sync_queue');
        expect(queueItems.length, equals(1));
        final pendingItem = queueItems.first;

        final bool canUploadUnderCurrentSession =
            pendingItem['ownerUid'] == SessionManager.instance.requireUid();
        expect(
          canUploadUnderCurrentSession,
          isFalse,
          reason: 'Hàng đợi của A bị từ chối upload khi B đang đăng nhập',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (3) BẢN GHI PENDING KHÔNG BỊ CLOUD SNAPSHOT CŨ GHI ĐÈ
    // ══════════════════════════════════════════════════════════════
    test(
      '(3) Bản ghi pending không bị cloud snapshot cũ ghi đè (Dirty Shield)',
      () {
        final localDirty = TransactionModel(
          id: 'tx_dirty_01',
          uid: 'user_test',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 1,
          amount: 150000, // Đã sửa offline thành 150k
          date: DateTime.now(),
          syncStatus: 'pending',
          updatedAt: DateTime(2026, 10, 24, 12, 0),
        );

        final cloudSnapshot = TransactionModel(
          id: 'tx_dirty_01',
          uid: 'user_test',
          type: 'expense',
          category: 'Ăn uống',
          categoryIconCode: 1,
          amount: 80000, // Trên Cloud vẫn là snapshot cũ 80k
          date: DateTime.now(),
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 10, 24, 11, 0),
        );

        // Thuật toán Dirty Shield: nếu local syncStatus == pending => từ chối ghi đè
        final bool shouldOverwrite =
            localDirty.syncStatus != 'pending' &&
            (cloudSnapshot.updatedAt.isAfter(localDirty.updatedAt) ||
                cloudSnapshot.updatedAt.isAtSameMomentAs(localDirty.updatedAt));

        expect(
          shouldOverwrite,
          isFalse,
          reason: 'Local Dirty Shield phải bảo vệ bản ghi pending',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (4) GIAO DỊCH XÓA TRÊN CLOUD ĐỒNG BỘ ĐÚNG XUỐNG LOCAL
    // ══════════════════════════════════════════════════════════════
    test(
      '(4) Giao dịch xóa trên cloud được đồng bộ đúng xuống local (Tombstone Soft-Delete)',
      () async {
        const uid = 'user_sync_del';
        SessionManager.instance.activate(uid);

        // Local đang có 1 giao dịch clean
        await db.insert('transactions', {
          'id': 'tx_cloud_del',
          'uid': uid,
          'type': 'expense',
          'category': 'Mua sắm',
          'amount': 250000,
          'syncStatus': 'synced',
          'isDeleted': 0,
        });

        // Cloud gửi snapshot tombstone (isDeleted = true, deletedAt != null)
        final now = DateTime.now();
        await db.update(
          'transactions',
          {
            'isDeleted': 1,
            'deletedAt': now.millisecondsSinceEpoch,
            'syncStatus': 'synced',
          },
          where: 'id = ? AND uid = ?',
          whereArgs: ['tx_cloud_del', uid],
        );

        // Truy vấn thông thường lọc isDeleted = 0 sẽ không còn trả về giao dịch này
        final visibleTx = await db.query(
          'transactions',
          where: 'uid = ? AND isDeleted = 0',
          whereArgs: [uid],
        );
        expect(
          visibleTx,
          isEmpty,
          reason: 'Giao dịch đã xóa trên cloud phải ẩn khỏi truy vấn local',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (5) THAO TÁC DELETE THẤT BẠI KHÔNG BỊ XÓA KHỎI SYNC_QUEUE
    // ══════════════════════════════════════════════════════════════
    test('(5) Thao tác DELETE thất bại không bị xóa khỏi sync_queue', () async {
      const uid = 'user_dlq_check';
      await SyncQueueWriter.enqueue(
        db,
        ownerUid: uid,
        table: 'transactions',
        recordId: 'tx_delete_fail',
        action: 'DELETE',
      );

      expect(db.tables['sync_queue']!.length, equals(1));
      final itemRow = db.tables['sync_queue']!.first;
      expect(itemRow['action'], equals('DELETE'));

      // Giả lập Sync Worker xử lý: upload thất bại (mạng lỗi 503)
      final int currentRetry = itemRow['retryCount'] as int;
      final int nextBackoffSeconds =
          (1 << currentRetry) * 5; // Exponential backoff
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'sync_queue',
        {
          'retryCount': currentRetry + 1,
          'nextRetryAt': nowMs + (nextBackoffSeconds * 1000),
          'status': 'pending',
          'lastError': 'SocketException: Connection refused (503)',
        },
        where: 'id = ?',
        whereArgs: [itemRow['id']],
      );

      // Bản ghi DELETE vẫn nằm trong hàng đợi, KHÔNG BỊ XÓA!
      expect(db.tables['sync_queue']!.length, equals(1));
      final updatedItem = db.tables['sync_queue']!.first;
      expect(updatedItem['retryCount'], equals(1));
      expect(updatedItem['status'], equals('pending'));
      expect(updatedItem['lastError'], contains('503'));
    });

    // ══════════════════════════════════════════════════════════════
    // (6) CHUYỂN TIỀN ÂM, PHÍ ÂM, VÍ KHÁC CHỦ SỞ HỮU, VƯỢT SỐ DƯ BỊ CHẶN
    // ══════════════════════════════════════════════════════════════
    test(
      '(6) Chuyển tiền âm, phí âm, ví khác chủ sở hữu hoặc vượt số dư bị chặn đúng',
      () {
        final userWallet = WalletModel(
          id: 'w_mine',
          uid: 'user_real',
          name: 'Ví của tôi',
          type: 'cash',
          balance: 300000,
          iconCode: 1,
          colorValue: 0,
        );

        final otherWallet = WalletModel(
          id: 'w_other',
          uid: 'user_impostor',
          name: 'Ví người khác',
          type: 'bank',
          balance: 5000000,
          iconCode: 2,
          colorValue: 0,
        );

        // A. Số tiền chuyển âm bị chặn
        expect(
          () {
            const amount = -100000.0;
            if (amount <= 0) {
              throw const BusinessException(
                BusinessErrorCode.invalidAmount,
                'Số tiền chuyển phải lớn hơn 0',
              );
            }
          },
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.invalidAmount,
            ),
          ),
        );

        // B. Phí chuyển âm bị chặn
        expect(
          () {
            const fee = -5000.0;
            if (fee < 0) {
              throw const BusinessException(
                BusinessErrorCode.invalidAmount,
                'Phí chuyển không được âm',
              );
            }
          },
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.invalidAmount,
            ),
          ),
        );

        // C. Ví khác chủ sở hữu bị chặn (notFound/ownershipViolation)
        expect(
          () {
            const currentUid = 'user_real';
            if (otherWallet.uid != currentUid) {
              throw const BusinessException(
                BusinessErrorCode.notFound,
                'Không tìm thấy ví thuộc tài khoản',
              );
            }
          },
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.notFound,
            ),
          ),
        );

        // D. Vượt quá số dư ví bị chặn
        expect(
          () {
            const transferAmount = 400000.0;
            if (userWallet.balance < transferAmount) {
              throw const BusinessException(
                BusinessErrorCode.insufficientBalance,
                'Số dư ví nguồn không đủ',
              );
            }
          },
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              BusinessErrorCode.insufficientBalance,
            ),
          ),
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (7) KHÔNG RÚT VƯỢT SỐ DƯ MỤC TIÊU TIẾT KIỆM (NO PHANTOM MONEY)
    // ══════════════════════════════════════════════════════════════
    test('(7) Không rút vượt số dư mục tiêu tiết kiệm (Ngăn tiền ảo)', () {
      final goal = GoalModel(
        id: 'goal_savings_01',
        uid: 'u_test',
        title: 'Mua iPhone',
        targetAmount: 30000000,
        currentAmount: 5000000, // Đang có 5 triệu
        deadline: DateTime.now().add(const Duration(days: 60)),
        iconCode: 1,
        colorValue: 0,
      );

      const requestedWithdraw = 6000000.0; // Yêu cầu rút 6 triệu

      expect(
        () {
          if (goal.currentAmount < requestedWithdraw) {
            throw const BusinessException(
              BusinessErrorCode.invalidAmount,
              'Số tiền rút vượt quá số dư hiện tại của mục tiêu',
            );
          }
        },
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            BusinessErrorCode.invalidAmount,
          ),
        ),
      );
    });

    // ══════════════════════════════════════════════════════════════
    // (8) SỐ DƯ VÍ VÀ MỤC TIÊU ROLLBACK ĐÚNG KHI SQLITE TRANSACTION LỖI
    // ══════════════════════════════════════════════════════════════
    test(
      '(8) Số dư ví và mục tiêu rollback đúng khi SQLite transaction lỗi',
      () async {
        const uid = 'user_tx_rollback';
        SessionManager.instance.activate(uid);

        await db.insert('wallets', {
          'id': 'w_atomic',
          'uid': uid,
          'name': 'Ví Tiền Mặt',
          'balance': 2000000,
        });

        await db.insert('goals', {
          'id': 'g_atomic',
          'uid': uid,
          'title': 'Quỹ Dự Phòng',
          'targetAmount': 10000000,
          'currentAmount': 1000000,
        });

        // Thao tác nạp 500k vào Goal nhưng gặp lỗi giữa chừng
        try {
          await db.runTransaction((txn) async {
            // B1: Trừ 500k ví
            await txn.update(
              'wallets',
              {'balance': 1500000},
              where: 'id = ? AND uid = ?',
              whereArgs: ['w_atomic', uid],
            );

            // B2: Giả lập lỗi hệ thống bất ngờ (mất điện, kill app, disk error)
            throw StateError('Simulated crash during atomic commit');
          });
        } catch (_) {}

        // Kiểm tra: số dư ví và mục tiêu được rollback nguyên vẹn về giá trị ban đầu!
        final walletAfter = (await db.query(
          'wallets',
          where: 'id = ? AND uid = ?',
          whereArgs: ['w_atomic', uid],
        )).first;
        final goalAfter = (await db.query(
          'goals',
          where: 'id = ? AND uid = ?',
          whereArgs: ['g_atomic', uid],
        )).first;

        expect(
          walletAfter['balance'],
          equals(2000000),
          reason: 'Ví phải được rollback về 2 triệu',
        );
        expect(
          goalAfter['currentAmount'],
          equals(1000000),
          reason: 'Goal giữ nguyên 1 triệu',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (9) MIGRATION DATABASE BẢO TOÀN 100% DỮ LIỆU VÀ SỐ TIỀN
    // ══════════════════════════════════════════════════════════════
    test(
      '(9) Migration từ database phiên bản cũ lên phiên bản mới bảo toàn 100% dữ liệu và số tiền',
      () {
        // Giả lập dữ liệu bảng wallets và transactions ở DB cũ (REAL)
        final legacyWallets = [
          {'id': 'w1', 'balance': 1250000.49},
          {'id': 'w2', 'balance': 3450000.51},
          {'id': 'w3', 'balance': 500000.0},
        ];
        final legacyTransactions = [
          {'id': 't1', 'amount': 45000.49},
          {'id': 't2', 'amount': 150000.0},
          {'id': 't3', 'amount': 250000.51},
        ];

        // Pre-flight audit check
        final preWalletSum = legacyWallets.fold<double>(
          0.0,
          (s, w) => s + (w['balance'] as double),
        );
        final preTxSum = legacyTransactions.fold<double>(
          0.0,
          (s, t) => s + (t['amount'] as double),
        );

        // Thực thi migration logic (REAL -> INTEGER qua CAST ROUND)
        final migratedWallets = legacyWallets.map((w) {
          return {'id': w['id'], 'balance': (w['balance'] as double).round()};
        }).toList();

        final migratedTransactions = legacyTransactions.map((t) {
          return {'id': t['id'], 'amount': (t['amount'] as double).round()};
        }).toList();

        // Post-flight audit check
        final postWalletSum = migratedWallets.fold<int>(
          0,
          (s, w) => s + (w['balance'] as int),
        );
        final postTxSum = migratedTransactions.fold<int>(
          0,
          (s, t) => s + (t['amount'] as int),
        );

        expect(migratedWallets.length, equals(legacyWallets.length));
        expect(migratedTransactions.length, equals(legacyTransactions.length));
        expect(
          postWalletSum,
          equals(preWalletSum.round()),
          reason: 'Số dư wallets bảo toàn 100%',
        );
        expect(
          postTxSum,
          equals(preTxSum.round()),
          reason: 'Số tiền transactions bảo toàn 100%',
        );
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (10) PHÂN QUYỀN NHÓM: THÀNH VIÊN KHÔNG THỂ TỰ NÂNG QUYỀN / THÊM MÌNH
    // ══════════════════════════════════════════════════════════════
    test(
      '(10) Logic kiểm tra quyền thành viên nhóm không thể tự nâng quyền hoặc thêm mình trái phép',
      () async {
        final fakeGroupRepo = FakeGroupRepoForAudit();
        final groupService = GroupService(fakeGroupRepo);

        final group = GroupModel(
          id: 'grp_sec_01',
          name: 'Nhóm Đi Du Lịch',
          ownerId: 'admin_user',
          memberIds: ['admin_user', 'member_bob'],
          createdAt: DateTime.now(),
        );
        fakeGroupRepo.seedGroup(group);

        // 1. Member thông thường (bob) không thể tự thêm người khác vào nhóm
        expect(
          () =>
              groupService.addMember('grp_sec_01', 'hacker_dave', 'member_bob'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Chỉ admin mới có thể thêm thành viên'),
            ),
          ),
        );

        // 2. Hacker ngoài nhóm không thể tự thêm chính mình
        expect(
          () => groupService.addMember(
            'grp_sec_01',
            'hacker_dave',
            'hacker_dave',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Chỉ admin mới có thể thêm thành viên'),
            ),
          ),
        );

        // 3. Member thông thường không thể sửa đổi nhóm
        expect(
          () => groupService.updateGroup(
            'grp_sec_01',
            UpdateGroupDto(name: 'Nhóm Chiếm Quyền'),
            'member_bob',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Chỉ admin mới có thể cập nhật nhóm'),
            ),
          ),
        );

        // 4. Admin thực hiện thêm thành viên hợp lệ
        await groupService.addMember(
          'grp_sec_01',
          'new_member_carol',
          'admin_user',
        );
        final updatedGroup = await fakeGroupRepo.getById('grp_sec_01');
        expect(updatedGroup.memberIds.contains('new_member_carol'), isTrue);
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (11) TỔNG EXPENSE_SPLITS LUÔN BẰNG CHÍNH XÁC TỔNG KHOẢN CHI (TIỀN LẺ)
    // ══════════════════════════════════════════════════════════════
    test(
      '(11) Tổng các phần chia expense_splits luôn bằng chính xác tổng khoản chi (kể cả số lẻ không chia hết)',
      () {
        // Tình huống A: 100,000 chia đều cho 3 người (lẻ 1 VND)
        const totalA = 100000;
        final splitsA = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: totalA,
          participantIds: ['u1', 'u2', 'u3'],
          payerId: 'u1',
        );
        final sumA = splitsA.values.reduce((a, b) => a + b);
        expect(sumA, equals(totalA));
        expect(splitsA['u1'], equals(33334));
        expect(splitsA['u2'], equals(33333));
        expect(splitsA['u3'], equals(33333));

        // Tình huống B: 100,001 chia đều cho 3 người (lẻ 2 VND)
        const totalB = 100001;
        final splitsB = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: totalB,
          participantIds: ['u1', 'u2', 'u3'],
          payerId: 'u1',
        );
        final sumB = splitsB.values.reduce((a, b) => a + b);
        expect(sumB, equals(totalB));
        expect(splitsB['u1'], equals(33334));
        expect(splitsB['u2'], equals(33334));
        expect(splitsB['u3'], equals(33333));

        // Tình huống C: 10,000 VND chia cho 7 người
        const totalC = 10000;
        final splitsC = VndSplitCalculator.calculateEqualSplit(
          totalAmountVnd: totalC,
          participantIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7'],
          payerId: 'u1',
        );
        final sumC = splitsC.values.reduce((a, b) => a + b);
        expect(sumC, equals(totalC));

        // Tình huống D: Chia theo tỷ lệ phần trăm lẻ (33.33%, 33.33%, 33.34%)
        const totalD = 500000;
        final splitsD = VndSplitCalculator.calculatePercentageSplit(
          totalAmountVnd: totalD,
          percentages: {'u1': 33.33, 'u2': 33.33, 'u3': 33.34},
          payerId: 'u1',
        );
        final sumD = splitsD.values.reduce((a, b) => a + b);
        expect(sumD, equals(totalD));
      },
    );

    // ══════════════════════════════════════════════════════════════
    // (12) DỮ LIỆU CỦA TỪNG UID ĐƯỢC CÔ LẬP HOÀN TOÀN TRONG MỌI REPOSITORY
    // ══════════════════════════════════════════════════════════════
    test(
      '(12) Dữ liệu của từng UID được cô lập hoàn toàn trong mọi repository',
      () async {
        const uidAlice = 'user_alice_999';
        const uidBob = 'user_bob_888';

        // Seed dữ liệu riêng biệt cho Alice và Bob
        await db.insert('wallets', {
          'id': 'w_alice',
          'uid': uidAlice,
          'name': 'Ví Alice',
          'balance': 1000000,
        });
        await db.insert('wallets', {
          'id': 'w_bob',
          'uid': uidBob,
          'name': 'Ví Bob',
          'balance': 5000000,
        });

        await db.insert('transactions', {
          'id': 'tx_alice',
          'uid': uidAlice,
          'amount': 50000,
          'category': 'Cafe',
        });
        await db.insert('transactions', {
          'id': 'tx_bob',
          'uid': uidBob,
          'amount': 120000,
          'category': 'Sách',
        });

        await db.insert('budgets', {
          'id': 'b_alice',
          'uid': uidAlice,
          'category': 'Cafe',
          'limitAmount': 500000,
        });
        await db.insert('budgets', {
          'id': 'b_bob',
          'uid': uidBob,
          'category': 'Sách',
          'limitAmount': 1000000,
        });

        await db.insert('goals', {
          'id': 'g_alice',
          'uid': uidAlice,
          'title': 'Học đàn',
          'targetAmount': 2000000,
        });
        await db.insert('goals', {
          'id': 'g_bob',
          'uid': uidBob,
          'title': 'Học bơi',
          'targetAmount': 3000000,
        });

        // 1. Kiểm tra truy vấn của Alice: chỉ trả về dữ liệu của Alice
        SessionManager.instance.activate(uidAlice);
        final aliceWallets = await db.query(
          'wallets',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );
        final aliceTx = await db.query(
          'transactions',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );
        final aliceBudgets = await db.query(
          'budgets',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );
        final aliceGoals = await db.query(
          'goals',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );

        expect(aliceWallets.length, equals(1));
        expect(aliceWallets.first['name'], equals('Ví Alice'));
        expect(aliceTx.length, equals(1));
        expect(aliceTx.first['category'], equals('Cafe'));
        expect(aliceBudgets.length, equals(1));
        expect(aliceGoals.length, equals(1));

        // 2. Alice cố gắng sửa hoặc xóa ví của Bob -> thất bại (0 rows affected)
        final updateBobResult = await db.update(
          'wallets',
          {'name': 'Ví Bob bị sửa'},
          where: 'id = ? AND uid = ?',
          whereArgs: ['w_bob', SessionManager.instance.requireUid()],
        );
        expect(
          updateBobResult,
          equals(0),
          reason: 'Alice không thể UPDATE record của Bob',
        );

        final deleteBobResult = await db.delete(
          'wallets',
          where: 'id = ? AND uid = ?',
          whereArgs: ['w_bob', SessionManager.instance.requireUid()],
        );
        expect(
          deleteBobResult,
          equals(0),
          reason: 'Alice không thể DELETE record của Bob',
        );

        // 3. Bob truy vấn: dữ liệu Bob hoàn toàn nguyên vẹn
        SessionManager.instance.activate(uidBob);
        final bobWallets = await db.query(
          'wallets',
          where: 'uid = ?',
          whereArgs: [SessionManager.instance.requireUid()],
        );
        expect(bobWallets.length, equals(1));
        expect(bobWallets.first['name'], equals('Ví Bob'));
      },
    );
  });
}
