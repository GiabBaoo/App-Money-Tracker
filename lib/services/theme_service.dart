import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/logging/app_logger.dart';
import '../core/theme/app_theme.dart';

export '../core/theme/app_colors.dart';
export '../core/theme/app_theme.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final _secureStorage = const FlutterSecureStorage();
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
      // 1. Nạp tức thì từ SharedPreferences (0ms - không chặn khởi động app)
      final prefs = await SharedPreferences.getInstance();
      var value = prefs.getString('themeMode');
      var scaleVal = prefs.getDouble('textScaleFactor');

      // 2. Migration từ FlutterSecureStorage nếu SharedPreferences chưa có dữ liệu
      if (value == null) {
        try {
          final oldSec = await _secureStorage.read(key: 'themeMode');
          if (oldSec != null) {
            value = oldSec;
            await prefs.setString('themeMode', oldSec);
          }
        } catch (e, st) {
          AppLogger.warn('Lỗi đọc fallback SecureStorage themeMode', tag: 'ThemeService', error: e, stackTrace: st);
        }
      }

      if (scaleVal == null) {
        try {
          final oldScaleStr = await _secureStorage.read(key: 'textScaleFactor');
          if (oldScaleStr != null) {
            final parsed = double.tryParse(oldScaleStr);
            if (parsed != null) {
              scaleVal = parsed;
              await prefs.setDouble('textScaleFactor', parsed);
            }
          }
        } catch (e, st) {
          AppLogger.warn('Lỗi đọc fallback SecureStorage textScaleFactor', tag: 'ThemeService', error: e, stackTrace: st);
        }
      }

      if (value == 'light') {
        _themeMode = ThemeMode.light;
      } else if (value == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      if (scaleVal != null && scaleVal >= 0.7 && scaleVal <= 1.6) {
        _textScaleFactor = scaleVal;
      }

      notifyListeners();

      // 3. Chạy đồng bộ ngầm từ Firestore (không await để app mở tức thì)
      unawaited(_syncRemoteSettingsInBackground());
    } catch (e, st) {
      AppLogger.warn('Lỗi khởi tạo ThemeService, sử dụng cấu hình mặc định', tag: 'ThemeService', error: e, stackTrace: st);
      _themeMode = ThemeMode.system;
      _textScaleFactor = 1.0;
      notifyListeners();
    }
  }

  Future<void> _syncRemoteSettingsInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return;

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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('themeMode', remoteMode.toString());
        }

        final remoteScale = settings['textScaleFactor'];
        if (remoteScale != null) {
          final parsed = double.tryParse(remoteScale.toString());
          if (parsed != null &&
              parsed >= 0.7 &&
              parsed <= 1.6 &&
              parsed != _textScaleFactor) {
            _textScaleFactor = parsed;
            changed = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('textScaleFactor', parsed);
          }
        }

        if (changed) {
          notifyListeners();
        }
      }
    } catch (e, st) {
      AppLogger.warn('Không thể đồng bộ theme từ Firestore trong nền', tag: 'ThemeService', error: e, stackTrace: st);
    }
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', value);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {'themeMode': value},
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      AppLogger.error('Lỗi lưu cài đặt themeMode', tag: 'ThemeService', error: e, stackTrace: st);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('textScaleFactor', factor);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {'textScaleFactor': factor},
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      AppLogger.error('Lỗi lưu cài đặt textScaleFactor', tag: 'ThemeService', error: e, stackTrace: st);
    }
  }

  // BIẾN MÀU HỆ THỐNG ĐỒNG NHẤT
  static Color primary(BuildContext context) => Theme.of(context).primaryColor;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF00E5FF)
          : const Color(0xFF438883);

  // Cấu trúc theme Sáng (Light Theme)
  ThemeData get lightTheme => AppTheme.lightTheme;

  // Cấu trúc theme Tối (Dark Theme)
  ThemeData get darkTheme => AppTheme.darkTheme;
}
