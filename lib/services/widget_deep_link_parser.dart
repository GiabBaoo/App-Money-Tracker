import 'package:flutter/foundation.dart';

enum WidgetActionType {
  addExpense,
  addIncome,
  voiceAssistant,
  scanReceipt,
  openWallet,
  openBudget,
  openGoal,
  openTransactions,
  openReport,
  openApp,
}

@immutable
class WidgetNavigationAction {
  final WidgetActionType type;
  final String? targetId;

  const WidgetNavigationAction({
    required this.type,
    this.targetId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetNavigationAction &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          targetId == other.targetId;

  @override
  int get hashCode => type.hashCode ^ targetId.hashCode;

  @override
  String toString() => 'WidgetNavigationAction(type: $type, targetId: $targetId)';
}

/// Bộ phân tích cú pháp Deep Link từ Android App Widget
class WidgetDeepLinkParser {
  const WidgetDeepLinkParser._();

  static WidgetNavigationAction parse(Uri uri) {
    if (uri.scheme != 'moneytracker') {
      return const WidgetNavigationAction(type: WidgetActionType.openApp);
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // 1. Tương thích link cũ: moneytracker://add_transaction
    if (host == 'add_transaction' || path.contains('add_transaction')) {
      final typeParam = uri.queryParameters['type']?.toLowerCase();
      if (typeParam == 'income') {
        return const WidgetNavigationAction(type: WidgetActionType.addIncome);
      }
      return const WidgetNavigationAction(type: WidgetActionType.addExpense);
    }

    // 2. Thêm mới giao dịch: moneytracker://add?type=expense|income
    if (host == 'add') {
      final typeParam = uri.queryParameters['type']?.toLowerCase();
      if (typeParam == 'income') {
        return const WidgetNavigationAction(type: WidgetActionType.addIncome);
      }
      return const WidgetNavigationAction(type: WidgetActionType.addExpense);
    }

    // 3. Trợ lý giọng nói: moneytracker://voice
    if (host == 'voice') {
      return const WidgetNavigationAction(type: WidgetActionType.voiceAssistant);
    }

    // 4. Quét hoá đơn OCR: moneytracker://scan hoặc moneytracker://scan_receipt
    if (host == 'scan' || host == 'scan_receipt') {
      return const WidgetNavigationAction(type: WidgetActionType.scanReceipt);
    }

    // 5. Màn hình Ví: moneytracker://wallet?id=xxx
    if (host == 'wallet') {
      return WidgetNavigationAction(
        type: WidgetActionType.openWallet,
        targetId: uri.queryParameters['id'],
      );
    }

    // 6. Màn hình Ngân sách: moneytracker://budget
    if (host == 'budget') {
      return const WidgetNavigationAction(type: WidgetActionType.openBudget);
    }

    // 7. Màn hình Mục tiêu: moneytracker://goal?id=xxx
    if (host == 'goal') {
      return WidgetNavigationAction(
        type: WidgetActionType.openGoal,
        targetId: uri.queryParameters['id'],
      );
    }

    // 8. Danh sách tất cả giao dịch: moneytracker://transactions
    if (host == 'transactions') {
      return const WidgetNavigationAction(type: WidgetActionType.openTransactions);
    }

    // 9. Màn hình Báo cáo thống kê: moneytracker://report hoặc moneytracker://statistics
    if (host == 'report' || host == 'statistics') {
      return const WidgetNavigationAction(type: WidgetActionType.openReport);
    }

    return const WidgetNavigationAction(type: WidgetActionType.openApp);
  }
}
