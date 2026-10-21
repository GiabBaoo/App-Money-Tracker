import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';

export '../core/theme/app_colors.dart';
export '../core/theme/app_theme.dart';

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
  ThemeData get lightTheme => AppTheme.lightTheme;

  // Cấu trúc theme Tối (Dark Theme)
  ThemeData get darkTheme => AppTheme.darkTheme;
}

