import 'package:flutter/material.dart';
import 'modules/home/home_screen.dart';
// Đảm bảo bạn import đúng đường dẫn đến file splash_screen của bạn nhé
import 'modules/splash/splash_screen.dart';

void main() {
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
      // ĐỔI DÒNG NÀY: Gọi SplashScreen chạy đầu tiên
      home: SplashScreen(),
    );
  }
}
