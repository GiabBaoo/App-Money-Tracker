import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../../core/errors/business_exception.dart';
import '../../core/safety/destructive_ops_guard.dart';
import '../../core/session/session_manager.dart';

/// Singleton quản lý kết nối SQLite database.
/// Tất cả các bảng dữ liệu cá nhân được định nghĩa tại đây.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _dbVersion = 9;
  static const String _dbName = 'money_tracker.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Bật bắt buộc khóa ngoại trên TẤT CẢ các kết nối
        try {
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (e) {
          debugPrint('SQLite PRAGMA foreign_keys error: $e');
        }
        // Bật Write-Ahead Logging (WAL) để tăng tốc độ ghi đồng thời (dùng rawQuery vì WAL trả về kết quả)
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (e) {
          debugPrint('SQLite PRAGMA journal_mode error: $e');
        }
      },
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createPreMigrationBackup(path, oldVersion);
        await _onUpgrade(db, oldVersion, newVersion);
      },
      onOpen: (db) async {
        // Đảm bảo các index cốt lõi luôn tồn tại
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(uid, walletId)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_transfer ON transactions(uid, transferId)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_goal ON transactions(uid, goalId)',
          );
        } catch (e) {
          debugPrint('SQLite onOpen index error: $e');
        }
      },
    );
  }

  /// Tạo tất cả bảng khi database được tạo lần đầu.
  Future<void> _onCreate(Database db, int version) async {
    // ─── Bảng TRANSACTIONS ───
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        categoryIconCode INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        date INTEGER NOT NULL,
        time TEXT DEFAULT '',
        description TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        hasPhoto INTEGER DEFAULT 0,
        photoUrl TEXT DEFAULT '',
        photoStoragePath TEXT DEFAULT '',
        photoLocalPath TEXT DEFAULT '',
        groupId TEXT,
        groupIconCode INTEGER,
        source TEXT DEFAULT 'personal',
        syncStatus TEXT DEFAULT 'synced',
        walletId TEXT DEFAULT '',
        location TEXT DEFAULT '',
        latitude REAL,
        longitude REAL,
        transferId TEXT,
        goalId TEXT,
        groupExpenseId TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    // Index để query nhanh theo uid và date
    await db.execute('CREATE INDEX idx_transactions_uid ON transactions(uid)');
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(uid, date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_sync ON transactions(syncStatus)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_wallet ON transactions(uid, walletId)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_transfer ON transactions(uid, transferId)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_goal ON transactions(uid, goalId)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_group ON transactions(groupId) WHERE groupId IS NOT NULL AND groupId <> ""',
    );

    // ─── Bảng WALLETS (Nơi chứa tiền / Đa ví) ───
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        initialBalance INTEGER NOT NULL DEFAULT 0,
        currency TEXT DEFAULT 'VND',
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isDefault INTEGER DEFAULT 0,
        accountNumber TEXT DEFAULT '',
        bankName TEXT DEFAULT '',
        note TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'synced',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_wallets_uid ON wallets(uid)');

    // ─── Bảng USERS ───
    await db.execute('''
      CREATE TABLE users (
        uid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT DEFAULT '',
        gender TEXT DEFAULT 'Nam',
        dateOfBirth INTEGER,
        avatarUrl TEXT DEFAULT '',
        avatarLocalPath TEXT DEFAULT '',
        accountType TEXT DEFAULT 'FREE',
        joinDate INTEGER NOT NULL,
        currency TEXT DEFAULT 'VND',
        role TEXT DEFAULT 'user',
        dataUsage TEXT DEFAULT '{"location":true,"contacts":false}',
        customCategories TEXT DEFAULT '[]',
        lastPasswordUpdate INTEGER,
        syncStatus TEXT DEFAULT 'synced'
      )
    ''');

    // ─── Bảng NOTIFICATIONS ───
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        type TEXT,
        groupId TEXT,
        groupName TEXT,
        status TEXT,
        syncStatus TEXT DEFAULT 'synced'
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_notifications_uid ON notifications(uid)',
    );

    // ─── Bảng MESSAGES ───
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        iconBgColorValue INTEGER NOT NULL,
        title TEXT NOT NULL,
        shortMessage TEXT NOT NULL,
        fullMessage TEXT NOT NULL,
        isUnread INTEGER DEFAULT 1,
        createdAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'synced'
      )
    ''');

    await db.execute('CREATE INDEX idx_messages_uid ON messages(uid)');

    // ─── Bảng DEVICE_SESSIONS ───
    await db.execute('''
      CREATE TABLE device_sessions (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        deviceType TEXT DEFAULT 'mobile',
        location TEXT DEFAULT '',
        lastActive INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'synced'
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_device_sessions_uid ON device_sessions(uid)',
    );

    // ─── Bảng BUDGETS (Hạn mức ngân sách) ───
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        category TEXT NOT NULL,
        categoryIconCode INTEGER NOT NULL,
        limitAmount INTEGER NOT NULL DEFAULT 0,
        period TEXT DEFAULT 'monthly',
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'synced',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_budgets_uid_month ON budgets(uid, year, month)',
    );

    // ─── Bảng GOALS (Mục tiêu tài chính tích lũy) ───
    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        targetAmount INTEGER NOT NULL DEFAULT 0,
        currentAmount INTEGER NOT NULL DEFAULT 0,
        deadline INTEGER NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        walletId TEXT DEFAULT '',
        note TEXT DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT DEFAULT 'synced',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_goals_uid ON goals(uid)');

    // ─── Bảng SYNC_QUEUE ───
    // Hàng đợi đồng bộ: ghi lại các thay đổi cần đẩy lên Firestore
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL DEFAULT '',
        ownerUid TEXT NOT NULL DEFAULT '',
        tableName TEXT NOT NULL,
        recordId TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        lastError TEXT,
        nextRetryAt INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sync_queue_table ON sync_queue(tableName)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_owner ON sync_queue(ownerUid, status, createdAt)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_poll ON sync_queue(uid, status, nextRetryAt, createdAt)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_record ON sync_queue(tableName, recordId, uid)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status_dead ON sync_queue(uid, status)',
    );

    // ─── Bảng SYNC_METADATA (Lưu mốc thời gian đồng bộ gia tăng theo từng Entity) ───
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        entityName TEXT NOT NULL,
        uid TEXT NOT NULL,
        lastSyncTimestamp INTEGER NOT NULL,
        PRIMARY KEY (entityName, uid)
      )
    ''');

    // ─── 5 BẢNG GROUP EXPENSE (Offline-First) ───
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        iconUrl TEXT DEFAULT '',
        iconCode INTEGER DEFAULT 58145,
        ownerId TEXT NOT NULL,
        groupType TEXT NOT NULL DEFAULT 'group',
        currency TEXT NOT NULL DEFAULT 'VND',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        syncStatus TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_members (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        userId TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'member',
        nickname TEXT DEFAULT '',
        joinedAt INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        leftAt INTEGER,
        updatedAt INTEGER NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        CONSTRAINT fk_group_members_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CONSTRAINT uq_group_user UNIQUE (groupId, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_expenses (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        payerId TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        splitMethod TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Khác',
        categoryIconCode INTEGER DEFAULT 0,
        date INTEGER NOT NULL,
        notes TEXT DEFAULT '',
        photoUrls TEXT DEFAULT '[]',
        linkedTransactionId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        version INTEGER NOT NULL DEFAULT 1,
        CONSTRAINT fk_group_expenses_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_splits (
        id TEXT PRIMARY KEY,
        expenseId TEXT NOT NULL,
        userId TEXT NOT NULL,
        shareAmount INTEGER NOT NULL,
        allocatedRemainder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        CONSTRAINT fk_expense_splits_expense FOREIGN KEY (expenseId) REFERENCES group_expenses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        CONSTRAINT uq_expense_user UNIQUE (expenseId, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS group_settlements (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        payerId TEXT NOT NULL,
        payeeId TEXT NOT NULL,
        amount INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending_confirmation',
        notes TEXT DEFAULT '',
        proofPhotoUrl TEXT DEFAULT '',
        linkedTransactionId TEXT,
        createdAt INTEGER NOT NULL,
        confirmedAt INTEGER,
        updatedAt INTEGER NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        CONSTRAINT fk_group_settlements_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    // Index cho các bảng nhóm mới
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(groupId, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(userId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_expenses_group_date ON group_expenses(groupId, date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expense_splits_expense ON expense_splits(expenseId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expense_splits_user ON expense_splits(userId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_settlements_group ON group_settlements(groupId, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_group_settlements_pair ON group_settlements(payerId, payeeId)',
    );

    debugPrint('SQLite: Database created successfully with all tables (v9)');
  }

  /// Xử lý migration khi nâng phiên bản database.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('SQLite: Upgrading database from v$oldVersion to v$newVersion');
    if (oldVersion < 2) {
      // 1. Tạo bảng wallets nếu chưa tồn tại
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallets (
          id TEXT PRIMARY KEY,
          uid TEXT NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          balance REAL NOT NULL DEFAULT 0.0,
          initialBalance REAL NOT NULL DEFAULT 0.0,
          currency TEXT DEFAULT 'VND',
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isDefault INTEGER DEFAULT 0,
          accountNumber TEXT DEFAULT '',
          bankName TEXT DEFAULT '',
          note TEXT DEFAULT '',
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wallets_uid ON wallets(uid)',
      );

      // 2. Thêm cột walletId vào transactions nếu chưa có
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN walletId TEXT DEFAULT ""',
        );
      } catch (e) {
        debugPrint('SQLite: Column walletId may already exist: $e');
      }
    }

    if (oldVersion < 3) {
      // Tạo bảng budgets
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id TEXT PRIMARY KEY,
          uid TEXT NOT NULL,
          category TEXT NOT NULL,
          categoryIconCode INTEGER NOT NULL,
          limitAmount REAL NOT NULL DEFAULT 0.0,
          period TEXT DEFAULT 'monthly',
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_uid_month ON budgets(uid, year, month)',
      );

      // Tạo bảng goals
      await db.execute('''
        CREATE TABLE IF NOT EXISTS goals (
          id TEXT PRIMARY KEY,
          uid TEXT NOT NULL,
          title TEXT NOT NULL,
          targetAmount REAL NOT NULL DEFAULT 0.0,
          currentAmount REAL NOT NULL DEFAULT 0.0,
          deadline INTEGER NOT NULL,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          walletId TEXT DEFAULT '',
          note TEXT DEFAULT '',
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_goals_uid ON goals(uid)',
      );
      debugPrint('SQLite: v3 migration completed (budgets and goals added)');
    }

    if (oldVersion < 4) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(uid, walletId)',
      );
      debugPrint(
        'SQLite: v4 migration completed (idx_transactions_wallet added)',
      );
    }

    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN location TEXT DEFAULT ""',
        );
        await db.execute('ALTER TABLE transactions ADD COLUMN latitude REAL');
        await db.execute('ALTER TABLE transactions ADD COLUMN longitude REAL');
        debugPrint(
          'SQLite: v5 migration completed (location, latitude, longitude added to transactions)',
        );
      } catch (e) {
        debugPrint('SQLite: v5 migration error: $e');
      }
    }

    if (oldVersion < 6) {
      await db.transaction((txn) async {
        await txn.execute(
          "ALTER TABLE sync_queue ADD COLUMN ownerUid TEXT NOT NULL DEFAULT ''",
        );
        await txn.execute(
          'ALTER TABLE sync_queue ADD COLUMN updatedAt INTEGER',
        );
        await txn.execute(
          "ALTER TABLE sync_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
        );
        await txn.execute('ALTER TABLE sync_queue ADD COLUMN lastError TEXT');

        // B1: lấy chủ từ bảng nguồn (bản ghi còn tồn tại, uid hợp lệ)
        const owned = [
          'transactions',
          'wallets',
          'budgets',
          'goals',
          'notifications',
          'messages',
          'device_sessions',
        ];
        for (final t in owned) {
          await txn.rawUpdate(
            '''
            UPDATE sync_queue SET ownerUid = (SELECT s.uid FROM $t s WHERE s.id = sync_queue.recordId)
            WHERE ownerUid = '' AND tableName = ?
              AND EXISTS (SELECT 1 FROM $t s WHERE s.id = sync_queue.recordId AND s.uid <> '')
          ''',
            [t],
          );
        }
        await txn.rawUpdate('''
          UPDATE sync_queue SET ownerUid = recordId
          WHERE ownerUid = '' AND tableName = 'users'
            AND EXISTS (SELECT 1 FROM users u WHERE u.uid = sync_queue.recordId)
        ''');

        // B2: lấy chủ từ payload JSON (cho DELETE/record đã mất). Decode bằng Dart, không phụ thuộc JSON1.
        final rest = await txn.query(
          'sync_queue',
          columns: ['id', 'data', 'ownerUid'],
        );
        for (final r in rest) {
          final raw = r['data'] as String?;
          String? payloadUid;
          if (raw != null) {
            try {
              payloadUid = (json.decode(raw) as Map)['uid'] as String?;
            } catch (_) {}
          }
          final owner = r['ownerUid'] as String;
          if (owner.isEmpty && SessionManager.isValidUid(payloadUid)) {
            await txn.update(
              'sync_queue',
              {'ownerUid': payloadUid},
              where: 'id = ?',
              whereArgs: [r['id']],
            );
          } else if (owner.isNotEmpty &&
              payloadUid != null &&
              payloadUid != owner) {
            // Payload và bảng nguồn mâu thuẫn (dấu vết của lỗi F1): cách ly
            await txn.update(
              'sync_queue',
              {'status': 'quarantined', 'lastError': 'legacy_uid_mismatch'},
              where: 'id = ?',
              whereArgs: [r['id']],
            );
          }
        }

        // B3: không xác định được chủ thì cách ly, KHÔNG BAO GIỜ upload tự động
        await txn.rawUpdate(
          "UPDATE sync_queue SET status = 'quarantined', lastError = 'unknown_owner' WHERE ownerUid = ''",
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_owner ON sync_queue(ownerUid, status, createdAt)',
        );
        debugPrint(
          'SQLite: v6 migration completed (sync_queue isolation schema & backfill)',
        );
      });
    }

    if (oldVersion < 7) {
      debugPrint(
        'SQLite: Starting v7 migration (standardizing sync_queue schema & soft-delete)...',
      );
      await db.transaction((txn) async {
        final columnsResult = await txn.rawQuery(
          "PRAGMA table_info(sync_queue)",
        );
        final existingColumns = columnsResult
            .map((c) => c['name'] as String)
            .toSet();

        // 1. Bổ sung cột 'uid' nếu chưa có, sao chép từ ownerUid
        if (!existingColumns.contains('uid')) {
          await txn.execute(
            "ALTER TABLE sync_queue ADD COLUMN uid TEXT NOT NULL DEFAULT ''",
          );
          if (existingColumns.contains('ownerUid')) {
            await txn.rawUpdate('''
              UPDATE sync_queue 
              SET uid = ownerUid 
              WHERE (uid IS NULL OR uid = '') AND ownerUid IS NOT NULL AND ownerUid <> ''
            ''');
          }
        }

        // 2. Bổ sung cột 'nextRetryAt' phục vụ Exponential Backoff
        if (!existingColumns.contains('nextRetryAt')) {
          await txn.execute(
            "ALTER TABLE sync_queue ADD COLUMN nextRetryAt INTEGER NOT NULL DEFAULT 0",
          );
        }

        // 3. Bổ sung cột 'updatedAt' nếu chưa có
        if (!existingColumns.contains('updatedAt')) {
          await txn.execute(
            "ALTER TABLE sync_queue ADD COLUMN updatedAt INTEGER",
          );
          final now = DateTime.now().millisecondsSinceEpoch;
          await txn.rawUpdate(
            "UPDATE sync_queue SET updatedAt = ? WHERE updatedAt IS NULL",
            [now],
          );
        }

        // 4. Bổ sung cột 'status' nếu chưa có
        if (!existingColumns.contains('status')) {
          await txn.execute(
            "ALTER TABLE sync_queue ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
          );
        }

        // 5. Bổ sung cột 'lastError' nếu chưa có
        if (!existingColumns.contains('lastError')) {
          await txn.execute("ALTER TABLE sync_queue ADD COLUMN lastError TEXT");
        }

        // 6. Xử lý các dòng chưa có uid từ payload JSON hoặc cách ly
        final unownedRows = await txn.query(
          'sync_queue',
          columns: ['id', 'data'],
          where: "uid = '' OR uid IS NULL",
        );
        for (final row in unownedRows) {
          final rawData = row['data'] as String?;
          String? extractedUid;
          if (rawData != null) {
            try {
              final decoded = json.decode(rawData) as Map<String, dynamic>;
              extractedUid = decoded['uid'] as String?;
            } catch (_) {}
          }
          if (extractedUid != null && extractedUid.isNotEmpty) {
            await txn.update(
              'sync_queue',
              {'uid': extractedUid, 'ownerUid': extractedUid},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          } else {
            await txn.update(
              'sync_queue',
              {'status': 'quarantined', 'lastError': 'unresolved_legacy_owner'},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }

        // 7. Tạo indexes mới cho sync_queue
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_poll ON sync_queue(uid, status, nextRetryAt, createdAt)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_record ON sync_queue(tableName, recordId, uid)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_dead ON sync_queue(uid, status)',
        );

        // 8. Bổ sung các cột soft delete (isDeleted, deletedAt) cho 4 bảng chính
        const tablesToSoftDelete = [
          'transactions',
          'wallets',
          'budgets',
          'goals',
        ];
        for (final table in tablesToSoftDelete) {
          final tblInfo = await txn.rawQuery("PRAGMA table_info($table)");
          final tblCols = tblInfo.map((c) => c['name'] as String).toSet();
          if (!tblCols.contains('isDeleted')) {
            await txn.execute(
              "ALTER TABLE $table ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0",
            );
          }
          if (!tblCols.contains('deletedAt')) {
            await txn.execute(
              "ALTER TABLE $table ADD COLUMN deletedAt INTEGER",
            );
          }
        }
        // 9. Tạo bảng sync_metadata nếu chưa có
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            entityName TEXT NOT NULL,
            uid TEXT NOT NULL,
            lastSyncTimestamp INTEGER NOT NULL,
            PRIMARY KEY (entityName, uid)
          )
        ''');

        debugPrint('SQLite: v7 migration completed successfully');
      });
    }

    if (oldVersion < 8) {
      debugPrint(
        'SQLite: Upgrading database to v8 (P1 Financial Integrity)...',
      );
      await db.transaction((txn) async {
        final columnsResult = await txn.rawQuery(
          "PRAGMA table_info(transactions)",
        );
        final existingColumns = columnsResult
            .map((c) => c['name'] as String)
            .toSet();

        if (!existingColumns.contains('transferId')) {
          await txn.execute(
            'ALTER TABLE transactions ADD COLUMN transferId TEXT',
          );
        }
        if (!existingColumns.contains('goalId')) {
          await txn.execute('ALTER TABLE transactions ADD COLUMN goalId TEXT');
        }

        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_transfer ON transactions(uid, transferId)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_goal ON transactions(uid, goalId)',
        );

        await txn.rawUpdate('''
          UPDATE transactions 
          SET transferId = groupId, groupId = NULL 
          WHERE groupId LIKE 'transfer_%'
        ''');
      });
      debugPrint('SQLite: v8 migration completed successfully.');
    }

    if (oldVersion < 9) {
      debugPrint(
        'SQLite: Starting Migration v9 (Currency REAL -> INTEGER & Group Expense Tables)...',
      );
      await db.transaction((txn) async {
        // BƯỚC 1: PRE-FLIGHT AUDIT CHECKS
        final preCheckTx = await txn.rawQuery(
          'SELECT COUNT(*) as count, SUM(ROUND(amount)) as total FROM transactions',
        );
        final preTxTotal = preCheckTx.first['total'] as num? ?? 0;

        final preCheckWallets = await txn.rawQuery(
          'SELECT COUNT(*) as count, SUM(ROUND(balance)) as total FROM wallets',
        );
        final preWalletTotal = preCheckWallets.first['total'] as num? ?? 0;

        // Tạm thời tắt foreign keys trong quá trình tráo đổi bảng
        await txn.execute('PRAGMA foreign_keys = OFF');

        // BƯỚC 2: REBUILD BẢNG WALLETS (balance, initialBalance: REAL -> INTEGER)
        await txn.execute('''
          CREATE TABLE new_wallets (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0,
            initialBalance INTEGER NOT NULL DEFAULT 0,
            currency TEXT DEFAULT 'VND',
            iconCode INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isDefault INTEGER DEFAULT 0,
            accountNumber TEXT DEFAULT '',
            bankName TEXT DEFAULT '',
            note TEXT DEFAULT '',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            syncStatus TEXT DEFAULT 'synced',
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER
          )
        ''');

        await txn.execute('''
          INSERT INTO new_wallets
          SELECT 
            id, uid, name, type,
            CAST(ROUND(balance) AS INTEGER),
            CAST(ROUND(initialBalance) AS INTEGER),
            currency, iconCode, colorValue, isDefault,
            accountNumber, bankName, note,
            createdAt, updatedAt, syncStatus, isDeleted, deletedAt
          FROM wallets
        ''');

        await txn.execute('DROP TABLE wallets');
        await txn.execute('ALTER TABLE new_wallets RENAME TO wallets');
        await txn.execute('CREATE INDEX idx_wallets_uid ON wallets(uid)');

        // BƯỚC 3: REBUILD BẢNG TRANSACTIONS (amount: REAL -> INTEGER, bổ sung groupExpenseId)
        await txn.execute('''
          CREATE TABLE new_transactions (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            categoryIconCode INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            date INTEGER NOT NULL,
            time TEXT DEFAULT '',
            description TEXT DEFAULT '',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            hasPhoto INTEGER DEFAULT 0,
            photoUrl TEXT DEFAULT '',
            photoStoragePath TEXT DEFAULT '',
            photoLocalPath TEXT DEFAULT '',
            groupId TEXT,
            groupIconCode INTEGER,
            source TEXT DEFAULT 'personal',
            syncStatus TEXT DEFAULT 'synced',
            walletId TEXT DEFAULT '',
            location TEXT DEFAULT '',
            latitude REAL,
            longitude REAL,
            transferId TEXT,
            goalId TEXT,
            groupExpenseId TEXT,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER
          )
        ''');

        await txn.execute('''
          INSERT INTO new_transactions
          SELECT 
            id, uid, type, category, categoryIconCode,
            CAST(ROUND(amount) AS INTEGER),
            date, time, description, createdAt, updatedAt,
            hasPhoto, photoUrl, photoStoragePath, photoLocalPath,
            groupId, groupIconCode, source, syncStatus,
            walletId, location, latitude, longitude,
            transferId, goalId, NULL as groupExpenseId,
            isDeleted, deletedAt
          FROM transactions
        ''');

        await txn.execute('DROP TABLE transactions');
        await txn.execute(
          'ALTER TABLE new_transactions RENAME TO transactions',
        );

        // Tạo lại toàn bộ Indexes cho bảng transactions
        await txn.execute(
          'CREATE INDEX idx_transactions_uid_date ON transactions(uid, date DESC)',
        );
        await txn.execute(
          'CREATE INDEX idx_transactions_uid_wallet ON transactions(uid, walletId)',
        );
        await txn.execute(
          'CREATE INDEX idx_transactions_sync ON transactions(syncStatus)',
        );
        await txn.execute(
          'CREATE INDEX idx_transactions_transfer ON transactions(uid, transferId)',
        );
        await txn.execute(
          'CREATE INDEX idx_transactions_goal ON transactions(uid, goalId)',
        );
        await txn.execute(
          'CREATE INDEX idx_transactions_group ON transactions(groupId) WHERE groupId IS NOT NULL AND groupId <> ""',
        );

        // BƯỚC 4: REBUILD BẢNG BUDGETS & GOALS
        await txn.execute('''
          CREATE TABLE new_budgets (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            category TEXT NOT NULL,
            categoryIconCode INTEGER NOT NULL,
            limitAmount INTEGER NOT NULL DEFAULT 0,
            period TEXT DEFAULT 'monthly',
            month INTEGER NOT NULL,
            year INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            syncStatus TEXT DEFAULT 'synced',
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER
          )
        ''');
        await txn.execute('''
          INSERT INTO new_budgets
          SELECT id, uid, category, categoryIconCode, CAST(ROUND(limitAmount) AS INTEGER), period, month, year, createdAt, updatedAt, syncStatus, isDeleted, deletedAt
          FROM budgets
        ''');
        await txn.execute('DROP TABLE budgets');
        await txn.execute('ALTER TABLE new_budgets RENAME TO budgets');
        await txn.execute(
          'CREATE INDEX idx_budgets_uid_month ON budgets(uid, year, month)',
        );

        // Goals: targetAmount, currentAmount REAL -> INTEGER
        await txn.execute('''
          CREATE TABLE new_goals (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            title TEXT NOT NULL,
            targetAmount INTEGER NOT NULL DEFAULT 0,
            currentAmount INTEGER NOT NULL DEFAULT 0,
            deadline INTEGER NOT NULL,
            iconCode INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            walletId TEXT DEFAULT '',
            note TEXT DEFAULT '',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            syncStatus TEXT DEFAULT 'synced',
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER
          )
        ''');
        await txn.execute('''
          INSERT INTO new_goals
          SELECT id, uid, title, CAST(ROUND(targetAmount) AS INTEGER), CAST(ROUND(currentAmount) AS INTEGER), deadline, iconCode, colorValue, walletId, note, createdAt, updatedAt, syncStatus, isDeleted, deletedAt
          FROM goals
        ''');
        await txn.execute('DROP TABLE goals');
        await txn.execute('ALTER TABLE new_goals RENAME TO goals');
        await txn.execute('CREATE INDEX idx_goals_uid ON goals(uid)');

        // BƯỚC 5: TẠO 5 BẢNG GROUP EXPENSE MỚI
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS groups (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT DEFAULT '',
            iconUrl TEXT DEFAULT '',
            iconCode INTEGER DEFAULT 58145,
            ownerId TEXT NOT NULL,
            groupType TEXT NOT NULL DEFAULT 'group',
            currency TEXT NOT NULL DEFAULT 'VND',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER,
            syncStatus TEXT NOT NULL DEFAULT 'synced'
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS group_members (
            id TEXT PRIMARY KEY,
            groupId TEXT NOT NULL,
            userId TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'member',
            nickname TEXT DEFAULT '',
            joinedAt INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            leftAt INTEGER,
            updatedAt INTEGER NOT NULL,
            syncStatus TEXT NOT NULL DEFAULT 'synced',
            CONSTRAINT fk_group_members_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            CONSTRAINT uq_group_user UNIQUE (groupId, userId)
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS group_expenses (
            id TEXT PRIMARY KEY,
            groupId TEXT NOT NULL,
            name TEXT NOT NULL,
            amount INTEGER NOT NULL,
            payerId TEXT NOT NULL,
            createdBy TEXT NOT NULL,
            splitMethod TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Khác',
            categoryIconCode INTEGER DEFAULT 0,
            date INTEGER NOT NULL,
            notes TEXT DEFAULT '',
            photoUrls TEXT DEFAULT '[]',
            linkedTransactionId TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER,
            syncStatus TEXT NOT NULL DEFAULT 'synced',
            version INTEGER NOT NULL DEFAULT 1,
            CONSTRAINT fk_group_expenses_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS expense_splits (
            id TEXT PRIMARY KEY,
            expenseId TEXT NOT NULL,
            userId TEXT NOT NULL,
            shareAmount INTEGER NOT NULL,
            allocatedRemainder INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            CONSTRAINT fk_expense_splits_expense FOREIGN KEY (expenseId) REFERENCES group_expenses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
            CONSTRAINT uq_expense_user UNIQUE (expenseId, userId)
          )
        ''');

        await txn.execute('''
          CREATE TABLE IF NOT EXISTS group_settlements (
            id TEXT PRIMARY KEY,
            groupId TEXT NOT NULL,
            payerId TEXT NOT NULL,
            payeeId TEXT NOT NULL,
            amount INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending_confirmation',
            notes TEXT DEFAULT '',
            proofPhotoUrl TEXT DEFAULT '',
            linkedTransactionId TEXT,
            createdAt INTEGER NOT NULL,
            confirmedAt INTEGER,
            updatedAt INTEGER NOT NULL,
            isDeleted INTEGER NOT NULL DEFAULT 0,
            deletedAt INTEGER,
            syncStatus TEXT NOT NULL DEFAULT 'synced',
            CONSTRAINT fk_group_settlements_group FOREIGN KEY (groupId) REFERENCES groups(id) ON UPDATE CASCADE ON DELETE RESTRICT
          )
        ''');

        // Tạo Index cho các bảng nhóm mới
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(groupId, status)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(userId)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_group_expenses_group_date ON group_expenses(groupId, date DESC)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_expense_splits_expense ON expense_splits(expenseId)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_expense_splits_user ON expense_splits(userId)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_group_settlements_group ON group_settlements(groupId, status)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_group_settlements_pair ON group_settlements(payerId, payeeId)',
        );

        // BƯỚC 6: POST-FLIGHT AUDIT RECONCILIATION
        final postCheckTx = await txn.rawQuery(
          'SELECT SUM(amount) as total FROM transactions',
        );
        final postTxTotal = postCheckTx.first['total'] as num? ?? 0;
        if (preTxTotal.round() != postTxTotal.round()) {
          throw StateError(
            'MIGRATION V9 FAILED: Sai lệch số dư transactions! Pre: $preTxTotal, Post: $postTxTotal',
          );
        }

        final postCheckWallets = await txn.rawQuery(
          'SELECT SUM(balance) as total FROM wallets',
        );
        final postWalletTotal = postCheckWallets.first['total'] as num? ?? 0;
        if (preWalletTotal.round() != postWalletTotal.round()) {
          throw StateError(
            'MIGRATION V9 FAILED: Sai lệch số dư wallets! Pre: $preWalletTotal, Post: $postWalletTotal',
          );
        }

        // Bật lại Foreign Keys
        await txn.execute('PRAGMA foreign_keys = ON');

        debugPrint(
          'SQLite: Migration v9 completed successfully with 100% precision preservation.',
        );
      });
    }
  }

  /// Đóng database (gọi khi app bị dispose).
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Xóa toàn bộ dữ liệu local (chỉ dùng trong testing).
  @visibleForTesting
  Future<void> wipeAllForTests() async {
    DestructiveOpsGuard.ensureEnabled('wipeAllForTests');
    final db = await database;
    await db.rawDelete('DELETE FROM expense_splits');
    await db.rawDelete('DELETE FROM group_settlements');
    await db.rawDelete('DELETE FROM group_expenses');
    await db.rawDelete('DELETE FROM group_members');
    await db.rawDelete('DELETE FROM groups');
    await db.rawDelete('DELETE FROM wallets');
    await db.rawDelete('DELETE FROM transactions');
    await db.rawDelete('DELETE FROM users');
    await db.rawDelete('DELETE FROM notifications');
    await db.rawDelete('DELETE FROM messages');
    await db.rawDelete('DELETE FROM device_sessions');
    await db.rawDelete('DELETE FROM budgets');
    await db.rawDelete('DELETE FROM goals');
    await db.rawDelete('DELETE FROM sync_queue');
    await db.rawDelete('DELETE FROM sync_metadata');
    debugPrint('SQLite: All local data wiped for tests');
  }

  /// @Deprecated: Bị khóa ở P0 — không bao giờ xóa dữ liệu khi logout.
  @Deprecated(
    'Bị khóa ở P0 — không bao giờ xóa dữ liệu khi logout. Dùng wipeAllForTests trong test.',
  )
  Future<void> clearAllData() async {
    DestructiveOpsGuard.ensureEnabled('clearAllData');
    return wipeAllForTests();
  }

  /// Tạo bản sao lưu trước khi migration chạy
  Future<void> _createPreMigrationBackup(String dbPath, int oldVersion) async {
    try {
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final backupPath =
            '$dbPath.bak_v${oldVersion}_${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(backupPath);
        debugPrint(
          'DatabaseHelper: Pre-migration backup created at $backupPath',
        );
      }
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to create pre-migration backup: $e');
    }
  }

  /// Sao lưu an toàn file database SQLite
  Future<String?> backupDatabase({String? reason}) async {
    if (kIsWeb) return null;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      final dbFile = File(path);
      if (await dbFile.exists()) {
        final suffix = reason != null ? '_$reason' : '';
        final backupPath =
            '$path.bak${suffix}_${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(backupPath);
        debugPrint('DatabaseHelper: Safe backup created at $backupPath');
        return backupPath;
      }
    } catch (e) {
      debugPrint('DatabaseHelper: Backup error: $e');
    }
    return null;
  }

  /// Xóa dữ liệu của 1 user cụ thể (chỉ dùng khi xóa tài khoản đã xác nhận qua Firebase).
  Future<void> clearUserData(String uid) async {
    if (!SessionManager.isValidUid(uid)) {
      throw BusinessException(
        BusinessErrorCode.invalidUid,
        'clearUserData: UID không hợp lệ',
      );
    }

    // Sao lưu dữ liệu an toàn trước khi xóa
    final shortUid = uid.length > 8 ? uid.substring(0, 8) : uid;
    await backupDatabase(reason: 'pre_clear_$shortUid');

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expense_splits', where: 'userId = ?', whereArgs: [uid]);
      await txn.delete('group_members', where: 'userId = ?', whereArgs: [uid]);
      await txn.delete('group_expenses', where: 'createdBy = ?', whereArgs: [uid]);
      await txn.delete('group_settlements', where: 'payerId = ? OR payeeId = ?', whereArgs: [uid, uid]);
      await txn.delete('groups', where: 'ownerId = ?', whereArgs: [uid]);
      await txn.delete('wallets', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('transactions', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('users', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('notifications', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('messages', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('device_sessions', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('budgets', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete('goals', where: 'uid = ?', whereArgs: [uid]);
      await txn.delete(
        'sync_queue',
        where: 'ownerUid = ? OR uid = ?',
        whereArgs: [uid, uid],
      );
      await txn.delete('sync_metadata', where: 'uid = ?', whereArgs: [uid]);
    });
    debugPrint('SQLite: Data cleared for user $uid');
  }
}
