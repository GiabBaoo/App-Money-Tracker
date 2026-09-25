import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'firebase_options.dart';
import 'modules/splash/splash_screen.dart';
import 'modules/auth/login_screen.dart';
import 'modules/auth/register_screen.dart';
import 'modules/auth/verify_email_screen.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'widgets/lifecycle_manager.dart';
import 'features/group_expense/presentation/screens/join_group_screen.dart';

// ═══ SQLite + Offline-First imports ═══
import 'data/local/database_helper.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/wallet_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/message_repository.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/local_notification_service.dart';
import 'services/midnight_sync_service.dart';
import 'services/auth_service.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══ 1. Khởi động song song các dịch vụ cục bộ tốc độ cao (0-100ms) ═══
  final themeService = ThemeService();
  final languageService = LanguageService();
  final connectivityService = ConnectivityService();
  final dbHelper = DatabaseHelper();

  final localInitFutures = Future.wait([
    initializeDateFormatting('vi', null).catchError((_) => null),
    initializeDateFormatting('vi_VN', null).catchError((_) => null),
    dbHelper.database,
    connectivityService.init(),
    themeService.init(),
    languageService.init(),
  ]);

  // ═══ 2. Khởi tạo Firebase ═══
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Đẩy Firebase AppCheck sang background microtask để không nghẽn luồng mở app
  Future.microtask(() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    } catch (e) {
      debugPrint('FirebaseAppCheck background error: $e');
    }
  });

  // Đợi các dịch vụ cục bộ hoàn tất song song
  await localInitFutures;

  // ═══ 3. Khởi tạo Repositories & Session ═══
  final transactionRepo = TransactionRepository();
  final walletRepo = WalletRepository();
  final userRepo = UserRepository();
  final notificationRepo = NotificationRepository();
  final messageRepo = MessageRepository();

  final authService = AuthService();
  final currentUser = FirebaseAuth.instance.currentUser;
  String? activeUid = currentUser?.uid;
  if (activeUid != null) {
    authService.setOnlineUid(activeUid);
  } else {
    activeUid = await authService.initOfflineSession();
  }

  if (activeUid != null) {
    transactionRepo.setUid(activeUid);
    walletRepo.setUid(activeUid);
    userRepo.setUid(activeUid);
    notificationRepo.setUid(activeUid);
    messageRepo.setUid(activeUid);

    // Tự động dọn dẹp các giao dịch từ tháng 6 trở về trước theo yêu cầu
    await transactionRepo.checkAndPurgeOldTransactions();
  }

  // ═══ 4. Khởi tạo Sync Service ═══
  final syncService = SyncService();
  syncService.init(
    transactionRepo: transactionRepo,
    walletRepo: walletRepo,
    userRepo: userRepo,
    notificationRepo: notificationRepo,
    messageRepo: messageRepo,
  );

  // Khởi động các dịch vụ chạy ngầm sau khi UI đã sẵn sàng
  Future.microtask(() async {
    try {
      await LocalNotificationService.instance.init();
      MidnightSyncService.instance.init();

      if (currentUser != null) {
        syncService.initialDownload();
        if (connectivityService.isOnline) {
          syncService.startRealtimeListeners();
        }
      }
    } catch (e) {
      debugPrint('Background services init error: $e');
    }
  });

  runApp(
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => themeService),
          provider.ChangeNotifierProvider(create: (_) => languageService),
          provider.Provider<TransactionRepository>.value(value: transactionRepo),
          provider.Provider<UserRepository>.value(value: userRepo),
          provider.Provider<NotificationRepository>.value(value: notificationRepo),
          provider.Provider<MessageRepository>.value(value: messageRepo),
          provider.Provider<ConnectivityService>.value(value: connectivityService),
          provider.Provider<SyncService>.value(value: syncService),
        ],
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _groupIdToJoin;

  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  void _checkInitialRoute() async {
    if (kIsWeb) {
      // Trên web, kiểm tra URL hash
      try {
        final uri = Uri.base;
        final hash = uri.fragment; // Sử dụng fragment thay vì hash
        debugPrint('DEBUG: Initial hash = $hash');
        
        if (hash.isNotEmpty) {
          if (hash.startsWith('/join/')) {
            _groupIdToJoin = hash.substring(6); // Remove '/join/'
            debugPrint('DEBUG: Found groupId to join = $_groupIdToJoin');
          }
        }
      } catch (e) {
        debugPrint('DEBUG ERROR checking initial route: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = provider.Provider.of<ThemeService>(context);
    final languageService = provider.Provider.of<LanguageService>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.navigatorKey,
      title: 'Mono',
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: themeService.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      themeAnimationCurve: Curves.easeInOut,
      locale: Locale(languageService.currentLanguage),
      home: _groupIdToJoin != null 
          ? JoinGroupScreen(groupId: _groupIdToJoin!)
          : const SplashScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(themeService.textScaleFactor.clamp(0.85, 1.25)),
          ),
          child: LifecycleManager(
            navigatorKey: widget.navigatorKey,
            child: child!,
          ),
        );
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/verify_email': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return VerifyEmailScreen(email: email);
        },
      },
      onGenerateRoute: (settings) {
        // Handle /join/:groupId route
        if (settings.name?.startsWith('/join/') == true) {
          final groupId = settings.name!.substring(6); // Remove '/join/'
          return MaterialPageRoute(
            builder: (context) => JoinGroupScreen(groupId: groupId),
          );
        }
        return null;
      },
    );
  }
}

