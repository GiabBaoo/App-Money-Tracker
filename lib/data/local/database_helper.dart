import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

/// Singleton quản lý kết nối SQLite database.
/// Tất cả các bảng dữ liệu cá nhân được định nghĩa tại đây.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const int _dbVersion = 4;
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
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Đảm bảo index walletId luôn tồn tại kể cả khi app chưa trigger onUpgrade
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(uid, walletId)',
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
        amount REAL NOT NULL,
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
        walletId TEXT DEFAULT ''
      )
    ''');

    // Index để query nhanh theo uid và date
    await db.execute(
      'CREATE INDEX idx_transactions_uid ON transactions(uid)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(uid, date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_sync ON transactions(syncStatus)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_wallet ON transactions(uid, walletId)',
    );

    // ─── Bảng WALLETS (Nơi chứa tiền / Đa ví) ───
    await db.execute('''
      CREATE TABLE wallets (
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
      'CREATE INDEX idx_wallets_uid ON wallets(uid)',
    );

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

    await db.execute(
      'CREATE INDEX idx_messages_uid ON messages(uid)',
    );

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
      'CREATE INDEX idx_budgets_uid_month ON budgets(uid, year, month)',
    );

    // ─── Bảng GOALS (Mục tiêu tài chính tích lũy) ───
    await db.execute('''
      CREATE TABLE goals (
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
      'CREATE INDEX idx_goals_uid ON goals(uid)',
    );

    // ─── Bảng SYNC_QUEUE ───
    // Hàng đợi đồng bộ: ghi lại các thay đổi cần đẩy lên Firestore
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT NOT NULL,
        recordId TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        createdAt INTEGER NOT NULL,
        retryCount INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sync_queue_table ON sync_queue(tableName)',
    );

    debugPrint('SQLite: Database created successfully with all tables (v3)');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_wallets_uid ON wallets(uid)');

      // 2. Thêm cột walletId vào transactions nếu chưa có
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN walletId TEXT DEFAULT ""');
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_uid_month ON budgets(uid, year, month)');

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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_goals_uid ON goals(uid)');
      debugPrint('SQLite: v3 migration completed (budgets and goals added)');
    }

    if (oldVersion < 4) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions(uid, walletId)',
      );
      debugPrint('SQLite: v4 migration completed (idx_transactions_wallet added)');
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

  /// Xóa toàn bộ dữ liệu local (dùng khi đăng xuất).
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('wallets');
    await db.delete('transactions');
    await db.delete('users');
    await db.delete('notifications');
    await db.delete('messages');
    await db.delete('device_sessions');
    await db.delete('budgets');
    await db.delete('goals');
    await db.delete('sync_queue');
    debugPrint('SQLite: All local data cleared');
  }

  /// Xóa dữ liệu của 1 user cụ thể (dùng khi xóa tài khoản).
  Future<void> clearUserData(String uid) async {
    final db = await database;
    await db.delete('wallets', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('transactions', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('users', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('notifications', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('messages', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('device_sessions', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('budgets', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('goals', where: 'uid = ?', whereArgs: [uid]);
    await db.delete('sync_queue');
    debugPrint('SQLite: Data cleared for user $uid');
  }
}
