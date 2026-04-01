import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final _storage = const FlutterSecureStorage();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    final value = await _storage.read(key: 'isDarkMode');
    _isDarkMode = value == 'true';
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _storage.write(key: 'isDarkMode', value: _isDarkMode.toString());
    notifyListeners();
  }

  // Cấu trúc theme
  ThemeData get lightTheme => ThemeData(
        primaryColor: const Color(0xFF438883),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF438883),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
      );

  ThemeData get darkTheme => ThemeData(
        primaryColor: const Color(0xFF0F2625),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2625),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: const Color(0xFFE0E0E0),
          onSurfaceVariant: const Color(0xFFB0B0B0),
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF121212)),
      );
}
