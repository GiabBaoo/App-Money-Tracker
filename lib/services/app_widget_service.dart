import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../data/repositories/wallet_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../modules/transaction/add_transaction_screen.dart';
import '../modules/transaction/all_transactions_screen.dart';
import '../modules/ai_assistant/ai_assistant_screen.dart';
import '../modules/home/wallet_screen.dart';
import '../modules/home/statistics_screen.dart';
import '../modules/budget/budget_and_goals_screen.dart';
import 'widget_snapshot_builder.dart';
import 'widget_deep_link_parser.dart';

/// Dịch vụ quản lý và đồng bộ toàn diện dữ liệu cho hệ thống 5 Android App Widgets
class AppWidgetService {
  AppWidgetService._internal();
  static final AppWidgetService instance = AppWidgetService._internal();

  // 4 Cỡ Widget tinh gọn & Báo cáo
  static const String mediumWidgetProvider = 'MoneyTrackerWidgetProvider'; // 4x2 Vừa: Số dư & Chi 7 ngày
  static const String budgetWidgetProvider = 'BudgetWidgetProvider'; // 4x2 Vừa: Tiến độ Ngân sách
  static const String smallWidgetProvider = 'SmallWidgetProvider'; // 2x2 Nhỏ
  static const String largeWidgetProvider = 'LargeWidgetProvider'; // 4x4 Lớn

  static const List<String> allWidgetProviders = [
    mediumWidgetProvider,
    budgetWidgetProvider,
    smallWidgetProvider,
    largeWidgetProvider,
  ];

  GlobalKey<NavigatorState>? _navigatorKey;
  WidgetNavigationAction? _pendingAction;
  bool _isNavigationReady = false;

  /// Thiết lập navigatorKey để điều hướng khi bấm nút trên Widget
  void setNavigatorKey(GlobalKey<NavigatorState> navKey) {
    _navigatorKey = navKey;
    _isNavigationReady = true;
    _flushPendingAction();
  }

  /// Thông báo trạng thái người dùng đã vào Home (đã vượt qua auth/biometric)
  void setNavigationReady(bool ready) {
    _isNavigationReady = ready;
    if (ready) {
      _flushPendingAction();
    }
  }

  /// Khởi tạo và lắng nghe tương tác từ Widget
  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. Kiểm tra xem app có được mở từ chạm trên Widget không
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _handleWidgetUri(initialUri);
      }

      // 2. Lắng nghe các sự kiện chạm vào Widget khi app đang chạy ngầm hoặc foreground
      HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleWidgetUri(uri);
        }
      });

      // 3. Đồng bộ dữ liệu hiện tại ra tất cả Widget
      await syncAll();
    } catch (e) {
      debugPrint('AppWidgetService init error: $e');
    }
  }

  /// Xử lý phân tích URI từ Widget
  void _handleWidgetUri(Uri uri) {
    debugPrint('AppWidgetService received Uri: $uri');
    final action = WidgetDeepLinkParser.parse(uri);
    _dispatchOrQueueAction(action);
  }

  void _dispatchOrQueueAction(WidgetNavigationAction action) {
    if (!_isNavigationReady || _navigatorKey?.currentState == null) {
      _pendingAction = action;
      return;
    }
    _navigateToAction(action);
  }

  void _flushPendingAction() {
    if (_pendingAction != null && _isNavigationReady && _navigatorKey?.currentState != null) {
      final action = _pendingAction!;
      _pendingAction = null;
      _navigateToAction(action);
    }
  }

  void _navigateToAction(WidgetNavigationAction action) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    switch (action.type) {
      case WidgetActionType.addExpense:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(initialIsIncome: false),
          ),
        );
        break;

      case WidgetActionType.addIncome:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(initialIsIncome: true),
          ),
        );
        break;

      case WidgetActionType.voiceAssistant:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AiAssistantScreen(initialAction: 'voice'),
          ),
        );
        break;

      case WidgetActionType.scanReceipt:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AiAssistantScreen(initialAction: 'scanReceipt'),
          ),
        );
        break;

      case WidgetActionType.openWallet:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const WalletScreen(),
          ),
        );
        break;

      case WidgetActionType.openBudget:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const BudgetAndGoalsScreen(initialTabIndex: 0),
          ),
        );
        break;

      case WidgetActionType.openGoal:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const BudgetAndGoalsScreen(initialTabIndex: 1),
          ),
        );
        break;

      case WidgetActionType.openTransactions:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AllTransactionsScreen(),
          ),
        );
        break;

      case WidgetActionType.openReport:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const StatisticsScreen(),
          ),
        );
        break;

      case WidgetActionType.openApp:
        // Đã mở app, không cần push thêm màn hình mới
        break;
    }
  }

  /// Đồng bộ toàn bộ dữ liệu (Số dư ví, Chi hôm nay, Ngân sách, Mục tiêu, Giao dịch)
  Future<void> syncAll() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final wallets = await WalletRepository().getWallets();
      final transactions = await TransactionRepository().getAllTransactions();
      final budgets = await BudgetRepository().getBudgetsWithSpent();
      final goals = await GoalRepository().getAllGoals();

      final snapshot = WidgetSnapshotBuilder.build(
        wallets: wallets,
        transactions: transactions,
        budgets: budgets,
        goals: goals,
        isLoggedIn: true,
      );

      final dataMap = snapshot.toMap();
      for (final entry in dataMap.entries) {
        if (entry.value is String) {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value as String);
        } else if (entry.value is double) {
          await HomeWidget.saveWidgetData<double>(entry.key, entry.value as double);
        } else if (entry.value is int) {
          await HomeWidget.saveWidgetData<int>(entry.key, entry.value as int);
        } else if (entry.value is bool) {
          await HomeWidget.saveWidgetData<bool>(entry.key, entry.value as bool);
        }
      }

      // Cập nhật tất cả các Widget Provider đã đăng ký
      for (final provider in allWidgetProviders) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
        );
      }

      debugPrint('AppWidgetService: Đồng bộ thành công 5 Widgets.');
    } catch (e) {
      debugPrint('AppWidgetService syncAll error: $e');
    }
  }

  /// Xoá dữ liệu hiển thị trên Widgets khi người dùng đăng xuất
  Future<void> clearOnLogout() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final emptySnapshot = WidgetSnapshotBuilder.buildEmpty(isLoggedIn: false);
      final dataMap = emptySnapshot.toMap();

      for (final entry in dataMap.entries) {
        if (entry.value is String) {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value as String);
        } else if (entry.value is double) {
          await HomeWidget.saveWidgetData<double>(entry.key, entry.value as double);
        } else if (entry.value is bool) {
          await HomeWidget.saveWidgetData<bool>(entry.key, entry.value as bool);
        }
      }

      for (final provider in allWidgetProviders) {
        await HomeWidget.updateWidget(
          name: provider,
          androidName: provider,
        );
      }

      debugPrint('AppWidgetService: Đã xóa dữ liệu nhạy cảm trên Widgets sau khi đăng xuất.');
    } catch (e) {
      debugPrint('AppWidgetService clearOnLogout error: $e');
    }
  }

  /// Cập nhật nhanh số dư tổng ví (Tương thích ngược)
  Future<void> updateWidgetBalance([double? customBalance]) async {
    await syncAll();
  }

  /// Yêu cầu hệ điều hành Android ghim trực tiếp Widget ra màn hình chính (Pin Widget)
  Future<bool> requestPinWidget(String androidProviderName) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      await HomeWidget.requestPinWidget(
        name: androidProviderName,
        androidName: androidProviderName,
      );
      return true;
    } catch (e) {
      debugPrint('requestPinWidget error: $e');
      return false;
    }
  }
}
