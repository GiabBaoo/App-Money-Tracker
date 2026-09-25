import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service quản lý trạng thái kết nối mạng.
/// Cung cấp `Stream<bool>` để UI và SyncService biết khi nào online/offline.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _isOnlineController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false; // Mặc định offline, cập nhật sau khi kiểm tra thực tế
  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _isOnlineController.stream;

  /// Khởi tạo — gọi 1 lần trong main()
  Future<void> init() async {
    // Kiểm tra trạng thái ban đầu
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      debugPrint('Connectivity init error: $e');
    }

    // Kiểm tra mạng thực tế ngay khi khởi động
    checkRealInternet();

    // Lắng nghe thay đổi
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      debugPrint('Connectivity: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      _isOnlineController.add(_isOnline);
    }

    // Nếu vừa đổi trạng thái sang online, xác minh internet thực tế
    if (_isOnline) {
      checkRealInternet();
    }
  }

  /// Kiểm tra kết nối mạng thực tế (thử kiểm tra interface + ping nhẹ)
  Future<bool> checkRealInternet() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        if (!_isOnline) {
          _isOnline = true;
          _isOnlineController.add(true);
        }
      }
    } catch (_) {}

    // Thử truy vấn socket DNS hoặc HTTP nhanh
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        if (!_isOnline) {
          _isOnline = true;
          _isOnlineController.add(true);
        }
        return true;
      }
    } catch (_) {
      try {
        final res = await http.head(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode >= 200 && res.statusCode < 400) {
          if (!_isOnline) {
            _isOnline = true;
            _isOnlineController.add(true);
          }
          return true;
        }
      } catch (_) {}
    }

    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _isOnlineController.close();
  }
}
