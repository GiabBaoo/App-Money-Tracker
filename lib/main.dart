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
import 'widgets/lifecycle_manager.dart';
import 'features/group_expense/presentation/screens/join_group_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize App Check to resolve the 'No AppCheckProvider installed' error
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );

    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway - app can still run without Firebase on web
  }
  
  final themeService = ThemeService();
  await themeService.init();

  runApp(
    ProviderScope(
      child: provider.ChangeNotifierProvider(
        create: (_) => themeService,
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.navigatorKey,
      title: 'App Thu Chi',
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: themeService.themeMode,
      home: _groupIdToJoin != null 
          ? JoinGroupScreen(groupId: _groupIdToJoin!)
          : const SplashScreen(),
      builder: (context, child) => LifecycleManager(
        navigatorKey: widget.navigatorKey,
        child: child!,
      ),
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
