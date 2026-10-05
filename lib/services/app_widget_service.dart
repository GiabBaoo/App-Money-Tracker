import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../data/repositories/wallet_repository.dart';
import '../modules/transaction/add_transaction_screen.dart';
import '../utils/currency_format_utils.dart';

/// Dịch vụ quản lý và đồng bộ dữ liệu cho Android App Widget (Màn hình chính)
class AppWidgetService {
  AppWidgetService._internal();
  static final AppWidgetService instance = AppWidgetService._internal();

  static const String androidWidgetProvider = 'MoneyTrackerWidgetProvider';
  static const String totalBalanceKey = 'widget_total_balance';

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Thiết lập navigatorKey để có thể điều hướng khi người dùng nhấn nút trên Widget
  void setNavigatorKey(GlobalKey<NavigatorState> navKey) {
    _navigatorKey = navKey;
  }

  /// Khởi tạo và lắng nghe tương tác từ Widget
  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. Kiểm tra xem app có được khởi động từ một cú chạm trên Widget không
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _handleWidgetUri(initialUri);
      }

      // 2. Lắng nghe các sự kiện chạm vào Widget khi app đang chạy ngầm / foreground
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleWidgetUri(uri);
        }
      });

      // 3. Tự động đồng bộ số dư hiện tại ra Widget
      await updateWidgetBalance();
    } catch (e) {
      debugPrint('AppWidgetService init error: $e');
    }
  }

  /// Xử lý mở màn hình tương ứng dựa trên URI từ Widget
  void _handleWidgetUri(Uri uri) {
    debugPrint('AppWidgetService received Uri: $uri');
    if (uri.scheme == 'moneytracker' && (uri.host == 'add_transaction' || uri.path.contains('add_transaction'))) {
      _navigateToQuickAdd();
    }
  }

  void _navigateToQuickAdd() {
    final nav = _navigatorKey?.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => const AddTransactionScreen(),
        ),
      );
    }
  }

  /// Cập nhật số dư tổng các ví hiển thị trên Android Widget
  Future<void> updateWidgetBalance([double? customBalance]) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      double total = customBalance ?? 0.0;
      if (customBalance == null) {
        total = await WalletRepository().getTotalBalance();
      }

      final formattedBalance = CurrencyUtils.formatCurrency(total);

      // Lưu dữ liệu vào SharedPreferences chung của HomeWidget
      await HomeWidget.saveWidgetData<String>(totalBalanceKey, formattedBalance);

      // Bắn lệnh cập nhật RemoteViews cho Android Widget
      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );

      debugPrint('AppWidgetService: Đã cập nhật số dư Widget thành: $formattedBalance');
    } catch (e) {
      debugPrint('AppWidgetService updateWidgetBalance error: $e');
    }
  }
}
