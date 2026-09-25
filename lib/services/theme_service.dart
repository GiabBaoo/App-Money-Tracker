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
  double _textScaleFactor = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;

  String get textScaleDisplayName {
    if (_textScaleFactor <= 0.88) return 'Nhỏ (0.85x)';
    if (_textScaleFactor <= 1.05) return 'Tiêu chuẩn (1.0x)';
    if (_textScaleFactor <= 1.20) return 'Lớn (1.15x)';
    return 'Rất lớn (1.30x)';
  }

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
      // 1. Nạp tức thì từ local storage (0ms - không chặn khởi động app)
      final value = await _storage.read(key: 'themeMode');
      if (value == 'light') {
        _themeMode = ThemeMode.light;
      } else if (value == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      final scaleVal = await _storage.read(key: 'textScaleFactor');
      if (scaleVal != null) {
        final parsed = double.tryParse(scaleVal);
        if (parsed != null && parsed >= 0.7 && parsed <= 1.6) {
          _textScaleFactor = parsed;
        }
      }
      notifyListeners();

      // 2. Chạy đồng bộ ngầm từ Firestore (không await để app mở tức thì)
      _syncRemoteSettingsInBackground();
    } catch (e) {
      _themeMode = ThemeMode.system;
      _textScaleFactor = 1.0;
      notifyListeners();
    }
  }

  void _syncRemoteSettingsInBackground() {
    Future.microtask(() async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final settings = doc.data()?['settings'];
          if (settings != null) {
            bool changed = false;
            final remoteMode = settings['themeMode'];
            ThemeMode targetMode = _themeMode;
            if (remoteMode == 'light') {
              targetMode = ThemeMode.light;
            } else if (remoteMode == 'dark') {
              targetMode = ThemeMode.dark;
            } else if (remoteMode == 'system') {
              targetMode = ThemeMode.system;
            }
            if (targetMode != _themeMode) {
              _themeMode = targetMode;
              changed = true;
            }

            final remoteScale = settings['textScaleFactor'];
            if (remoteScale != null) {
              final parsed = double.tryParse(remoteScale.toString());
              if (parsed != null && parsed >= 0.7 && parsed <= 1.6 && parsed != _textScaleFactor) {
                _textScaleFactor = parsed;
                changed = true;
              }
            }

            if (changed) {
              notifyListeners();
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners(); // Phản hồi giao diện tức thì 0ms!

    _persistThemeMode(mode);
  }

  void _persistThemeMode(ThemeMode mode) async {
    String value = 'system';
    if (mode == ThemeMode.light) {
      value = 'light';
    } else if (mode == ThemeMode.dark) {
      value = 'dark';
    }
    
    try {
      await _storage.write(key: 'themeMode', value: value);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {
            'themeMode': value,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('ThemeService theme persist error: $e');
    }
  }

  Future<void> setTextScaleFactor(double factor) async {
    if (_textScaleFactor == factor) return;
    _textScaleFactor = factor;
    notifyListeners(); // Phản hồi giao diện tức thì 0ms!

    _persistTextScale(factor);
  }

  void _persistTextScale(double factor) async {
    try {
      await _storage.write(key: 'textScaleFactor', value: factor.toString());
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {
            'textScaleFactor': factor,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('ThemeService scale persist error: $e');
    }
  }

  // BIẾN MÀU HỆ THỐNG ĐỒNG NHẤT
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color onSurface(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color accent(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF438883);

  // Cấu trúc theme Sáng (Light Theme)
  ThemeData get lightTheme => ThemeData(
        primaryColor: const Color(0xFF438883),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF438883),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: const Color(0xFF0F172A),
          onSurfaceVariant: const Color(0xFF475569),
          outline: const Color(0xFFE2E8F0),
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Colors.white),
        dividerColor: const Color(0xFFE5E7EB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF475569),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        textTheme: const TextTheme(
          bodySmall: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.3),
          bodyMedium: TextStyle(fontSize: 14.5, color: Color(0xFF1E293B), height: 1.35),
          bodyLarge: TextStyle(fontSize: 16.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          titleMedium: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      );

  // Cấu trúc theme Tối (Dark Theme)
  ThemeData get darkTheme => ThemeData(
        primaryColor: const Color(0xFF0F2625), // Dark Moss Green cho Header
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3351),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
          onSurfaceVariant: const Color(0xFFCBD5E1),
          outline: const Color(0xFF334155),
        ),
        useMaterial3: true,
        bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xFF121212)),
        dividerColor: const Color(0xFF2A2A2A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E2827),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFFCBD5E1),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E2827),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        textTheme: const TextTheme(
          bodySmall: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.3),
          bodyMedium: TextStyle(fontSize: 14.5, color: Colors.white, height: 1.35),
          bodyLarge: TextStyle(fontSize: 16.5, color: Colors.white, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(fontSize: 17.0, fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
}

/// Helper tiện ích cung cấp màu semantic tương thích động với Chế độ Sáng / Tối
class AppThemeColors {
  static const Color primaryTeal = Color(0xFF438883);
  static const Color incomeGreen = Color(0xFF24A869);
  static const Color expenseCoral = Color(0xFFE17E5B);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cardBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;

  static Color secondaryBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9);

  static Color inputBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF282828) : const Color(0xFFF8FAFC);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF0F172A);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color border(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.1)
          : const Color(0xFFE2E8F0);

  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEDF2F7);
}
