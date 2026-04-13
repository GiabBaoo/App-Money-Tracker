import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final _storage = const FlutterSecureStorage();
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Helper to check dark mode with context for 'system' mode support
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // Backward compatibility getter (defaults to false for system)
  bool get isDarkModeLegacy => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    try {
      // Ưu tiên lấy từ Firestore nếu đã đăng nhập để đồng bộ thiết bị
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['settings']?['themeMode'] != null) {
          final remoteMode = doc.data()?['settings']?['themeMode'];
          if (remoteMode == 'light') {
            _themeMode = ThemeMode.light;
          } else if (remoteMode == 'dark') {
            _themeMode = ThemeMode.dark;
          } else {
            _themeMode = ThemeMode.system;
          }
          
          // Cập nhật lại local cache
          await _storage.write(key: 'themeMode', value: remoteMode);
          notifyListeners();
          return;
        }
      }

      // Nếu chưa đăng nhập hoặc chưa có dữ liệu remote, dùng local storage
      final value = await _storage.read(key: 'themeMode');
      if (value == 'light') {
        _themeMode = ThemeMode.light;
      } else if (value == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    } catch (e) {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String value = 'system';
    if (mode == ThemeMode.light) {
      value = 'light';
    } else if (mode == ThemeMode.dark) {
      value = 'dark';
    }
    
    try {
      await _storage.write(key: 'themeMode', value: value);
      
      // Đồng bộ lên Firestore để sử dụng trên điện thoại/thiết bị khác
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {
            'themeMode': value,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Ignore storage errors on web
    }
    notifyListeners();
  }

  // BIẾN MÀU HỆ THỐNG ĐỒNG NHẤT
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color onSurface(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color accent(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF438883);

  // Cấu trúc theme
  ThemeData get lightTheme => ThemeData(
        primaryColor: const Color(0xFF438883),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF438883),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
      );

  ThemeData get darkTheme => ThemeData(
        primaryColor: const Color(0xFF0F2625), // Dark Moss Green cho Header
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3351),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFB0B0B0),
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF121212)),
      );
}
