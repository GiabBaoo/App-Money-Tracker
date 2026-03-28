import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'modules/splash/splash_screen.dart';
<<<<<<< HEAD
import 'modules/auth/login_screen.dart';
import 'modules/auth/register_screen.dart';
import 'modules/auth/verify_email_screen.dart';
=======
>>>>>>> funcionsettinggit

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Thu Chi',
      theme: ThemeData(
        primaryColor: const Color(0xFF438883),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF438883)),
        useMaterial3: true,
      ),
      home: SplashScreen(),
<<<<<<< HEAD
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/verify_email': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return VerifyEmailScreen(email: email);
        },
      },
=======
>>>>>>> funcionsettinggit
    );
  }
}