import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../models/notification_model.dart';
import '../utils/currency_format_utils.dart';
import 'local_notification_service.dart';
import 'auth_service.dart';
import '../data/repositories/budget_repository.dart';

/// Dịch vụ phân tích tài chính thông minh & Tự động tạo thông báo thực tế
class SmartNotificationService {
  SmartNotificationService._internal();
  static final SmartNotificationService instance = SmartNotificationService._internal();

  final TransactionRepository _txRepo = TransactionRepository();
  final WalletRepository _walletRepo = WalletRepository();
  final NotificationRepository _notiRepo = NotificationRepository();

  Future<void> _addNotificationAndPush(NotificationModel noti, {bool pushStatusBar = false}) async {
    // Tránh spam tạo nhiều thông báo cùng loại trong cùng 1 ngày
    try {
      final db = await DatabaseHelper().database;
      final startOfDay = DateTime(noti.createdAt.year, noti.createdAt.month, noti.createdAt.day).millisecondsSinceEpoch;
      final existing = await db.query(
        'notifications',
        where: 'uid = ? AND type = ? AND createdAt >= ?',
        whereArgs: [noti.uid, noti.type, startOfDay],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        debugPrint('SmartNotificationService: Notification of type "${noti.type}" already exists today, skipping.');
        return;
      }
    } catch (_) {}

    await _notiRepo.addNotification(noti);
    // Chỉ bắn ra ngoài thanh trạng thái khi được chỉ định rõ (tránh làm phiền khi vừa mở app)
    if (pushStatusBar) {
      await LocalNotificationService.instance.showInstantNotification(
        id: noti.title.hashCode,
        title: noti.title,
        body: noti.description,
        payload: noti.type,
      );
    }
  }

  /// Phân tích dữ liệu chi tiêu & Tạo các thông báo thông minh thật
  /// [forceRefresh]: nếu là true (ví dụ người dùng bấm nút Phân tích ngay), bỏ qua kiểm tra ngày hôm nay
  Future<int> generateSmartFinancialNotifications({bool forceRefresh = false}) async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null) return 0;

    _txRepo.setUid(uid);
    _walletRepo.setUid(uid);
    _notiRepo.setUid(uid);

    final prefs = await SharedPreferences.getInstance();

    // 1. Kiểm tra cấu hình thông báo mà người dùng đã bật/tắt
    final remindersEnabled = prefs.getBool('notif_reminders') ?? true;
    final spendingReportEnabled = prefs.getBool('notif_spending_report') ?? true;
    final smartAdviceEnabled = prefs.getBool('notif_smart_advice') ?? true;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final lastAnalysisDay = prefs.getString('notif_last_analysis_day_$uid');

    // Nếu không phải forceRefresh và hôm nay đã phân tích rồi thì không tạo trùng lặp
    if (!forceRefresh && lastAnalysisDay == todayKey) {
      return 0;
    }

    int count = 0;

    try {
      final allTx = await _txRepo.getAllTransactions();

      // ════════ PHÂN TÍCH 1: BÁO CÁO CHI TIÊU KỲ NÀY VS KỲ TRƯỚC ════════
      if (spendingReportEnabled) {
        final thisMonthTx = allTx.where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month).toList();

        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonthTx = allTx.where((t) =>
            t.type == 'expense' &&
            t.date.year == prevYear &&
            t.date.month == prevMonth).toList();

        final thisMonthExpense = thisMonthTx.fold<double>(0.0, (sum, t) => sum + t.amount);
        final prevMonthExpense = prevMonthTx.fold<double>(0.0, (sum, t) => sum + t.amount);

        if (prevMonthExpense > 0) {
          final diffPercent = ((thisMonthExpense - prevMonthExpense) / prevMonthExpense) * 100;

          if (diffPercent > 15) {
            // Chi tiêu tăng cao đáng kể (>15%) -> Cảnh báo quan trọng
            await _addNotificationAndPush(
              NotificationModel(
                uid: uid,
                iconCode: Icons.trending_up_rounded.codePoint,
                title: '⚠️ Cảnh báo chi tiêu: Tăng ${diffPercent.abs().toStringAsFixed(0)}%',
                description: 'Chi tiêu tháng này (${CurrencyUtils.formatCurrency(thisMonthExpense)}) đang cao hơn ${diffPercent.abs().toStringAsFixed(0)}% so với cùng kỳ tháng trước (${CurrencyUtils.formatCurrency(prevMonthExpense)}). Bạn hãy kiểm tra lại các khoản chi lớn để tối ưu ngân sách!',
                isRead: false,
                type: 'spending_alert_high',
              ),
              pushStatusBar: true,
            );
            count++;
          } else if (diffPercent < -10) {
            // Tiết kiệm tốt (>10%) -> Động viên tích cực
            await _addNotificationAndPush(
              NotificationModel(
                uid: uid,
                iconCode: Icons.savings_rounded.codePoint,
                title: '🎉 Tiết kiệm xuất sắc: Giảm ${diffPercent.abs().toStringAsFixed(0)}%',
                description: 'Tuyệt vời! Bạn đang chi tiêu ít hơn ${diffPercent.abs().toStringAsFixed(0)}% so với tháng trước (${CurrencyUtils.formatCurrency(thisMonthExpense)} so với ${CurrencyUtils.formatCurrency(prevMonthExpense)}). Thói quen tài chính của bạn đang rất tích cực!',
                isRead: false,
                type: 'spending_alert_saved',
              ),
            );
            count++;
          }
          // Đã loại bỏ thông báo rác "Chi tiêu duy trì ổn định" (không cần thiết gây loãng thông báo)
        }
      }

      // ════════ PHÂN TÍCH 2: GỢI Ý CHI TIÊU KHOA HỌC VỚI SỐ TIỀN CÒN LẠI ════════
      if (smartAdviceEnabled) {
        final totalBalance = await _walletRepo.getTotalBalance();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = daysInMonth - now.day + 1;

        if (totalBalance <= 100000 && totalBalance > 0) {
          // CẢNH BÁO NGUY CẤP: Số dư ví quá thấp
          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.warning_amber_rounded.codePoint,
              title: '⚠️ Cảnh báo số dư ví cần chú ý',
              description: 'Tổng số dư các ví đang ở mức thấp (${CurrencyUtils.formatCurrency(totalBalance)}). Bạn nên hạn chế các khoản mua sắm chưa cấp bách trong $daysLeft ngày còn lại của tháng!',
              isRead: false,
              type: 'low_balance_alert',
            ),
            pushStatusBar: true,
          );
          count++;
        } else if (totalBalance > 500000 && now.day <= 10) {
          // Gợi ý ngân sách đầu tháng cho người dùng có số dư ổn định
          final safeDailyBudget = (totalBalance * 0.75) / daysLeft;
          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.lightbulb_outline_rounded.codePoint,
              title: '💡 Gợi ý chi tiêu cho $daysLeft ngày tới',
              description: 'Số dư khả dụng các ví là ${CurrencyUtils.formatCurrency(totalBalance)}. Bạn nên chi tối đa khoảng ${CurrencyUtils.formatCurrency(safeDailyBudget)}/ngày để vừa chi tiêu thoải mái vừa giữ được quỹ dự phòng tích lũy!',
              isRead: false,
              type: 'smart_budget_suggestion',
            ),
          );
          count++;
        }
      }

      // ════════ PHÂN TÍCH 3: NHẮC NHỞ GHI CHÉP HÔM NAY ════════
      if (remindersEnabled) {
        final todayTx = allTx.where((t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day).toList();

        // Chỉ gửi nhắc nhở nếu sau 18:00 mà hôm nay chưa ghi chép khoản nào
        if (todayTx.isEmpty && now.hour >= 18) {
          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.edit_note_rounded.codePoint,
              title: '📝 Nhắc nhở ghi chép chi tiêu',
              description: 'Hôm nay bạn chưa ghi lại khoản chi tiêu nào. Đừng quên ghi chép đầy đủ các khoản phát sinh trong ngày để quản lý dòng tiền tốt nhất nhé!',
              isRead: false,
              type: 'daily_reminder',
            ),
          );
          count++;
        }

        // Luôn duy trì lịch hẹn định kỳ 20:30 mỗi tối khi người dùng bật reminders
        await LocalNotificationService.instance.scheduleDailyReminder(
          id: 200,
          hour: 20,
          minute: 30,
          title: '📝 Nhắc nhở ghi chép chi tiêu',
          body: 'Đừng quên ghi lại các khoản phát sinh trong ngày để quản lý dòng tiền tốt nhất nhé!',
        );
      }

      // ════════ PHÂN TÍCH 4: NHẮC NHỞ ĐỒNG BỘ DỮ LIỆU NGOẠI TUYẾN QUÁ HẠN ════════
      await checkOfflineSyncReminder();

      // Lưu lại ngày đã phân tích
      await prefs.setString('notif_last_analysis_day_$uid', todayKey);
    } catch (e) {
      debugPrint('SmartNotificationService error: $e');
    }

    return count;
  }

  /// Kiểm tra hạn mức chi tiêu hàng ngày
  /// CHỈ thông báo khi vượt hạn mức hoặc khi chạm ngưỡng nguy cơ (>=80%)
  /// Loại bỏ hoàn toàn các thông báo khen ngợi spam khi chi tiêu nhỏ
  Future<bool> checkDailySpendingLimit({required double newExpenseAmount}) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final isLimitEnabled = prefs.getBool('daily_limit_enabled') ?? false;
    if (!isLimitEnabled) return false;

    final dailyLimit = prefs.getDouble('daily_spending_limit') ?? 0.0;
    if (dailyLimit <= 0) return false;

    _txRepo.setUid(uid);
    _notiRepo.setUid(uid);

    final now = DateTime.now();
    final allTx = await _txRepo.getAllTransactions();
    final todayExpenses = allTx.where((t) =>
        t.type == 'expense' &&
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day).toList();

    final totalTodayExpense = todayExpenses.fold<double>(0.0, (sum, t) => sum + t.amount);

    if (totalTodayExpense > dailyLimit) {
      // VƯỢT HẠN MỨC - Cảnh báo quan trọng ngay lập tức
      final excess = totalTodayExpense - dailyLimit;
      final funMessages = [
        'Hôm nay bạn đã tiêu ${CurrencyUtils.formatCurrency(totalTodayExpense)}, vượt hạn mức ${CurrencyUtils.formatCurrency(dailyLimit)} (${CurrencyUtils.formatCurrency(excess)}). Hãy cân nhắc dừng chi tiêu trong hôm nay nhé! 💪',
        'Chi tiêu ${CurrencyUtils.formatCurrency(totalTodayExpense)} đã vượt mức quy định ${CurrencyUtils.formatCurrency(dailyLimit)}. Cố gắng kiểm soát để không làm thâm hụt ngân sách tháng! 😄',
      ];
      
      final randomMsg = funMessages[now.millisecond % funMessages.length];

      final noti = NotificationModel(
        uid: uid,
        iconCode: Icons.warning_rounded.codePoint,
        title: '🚨 Cảnh báo: Đã vượt hạn mức chi tiêu ngày!',
        description: randomMsg,
        isRead: false,
        type: 'daily_limit_exceeded',
      );

      await _addNotificationAndPush(noti, pushStatusBar: true);
      return true;
    } else {
      // DƯỚI HẠN MỨC: CHỈ cảnh báo khi đạt từ 80% trở lên (nguy cơ chạm trần)
      final remaining = dailyLimit - totalTodayExpense;
      final percentage = ((totalTodayExpense / dailyLimit) * 100).round();
      
      if (percentage >= 80) {
        final noti = NotificationModel(
          uid: uid,
          iconCode: Icons.running_with_errors_rounded.codePoint,
          title: '⚡ Cẩn thận! Đã chi $percentage% hạn mức ngày',
          description: 'Hôm nay bạn đã chi ${CurrencyUtils.formatCurrency(totalTodayExpense)}/${CurrencyUtils.formatCurrency(dailyLimit)}. Chỉ còn ${CurrencyUtils.formatCurrency(remaining)} cho hôm nay, hãy cân nhắc trước khi chi thêm! 🤔',
          isRead: false,
          type: 'daily_limit_warning',
        );

        await _addNotificationAndPush(noti, pushStatusBar: true);
        return false;
      }
      
      // percentage < 80%: Không tạo thông báo để tránh làm phiền/spam người dùng!
      return false;
    }
  }

  /// Kiểm tra hạn mức chi tiêu hàng THÁNG
  Future<bool> checkMonthlySpendingLimit({required double newExpenseAmount}) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final isMonthlyLimitEnabled = prefs.getBool('monthly_limit_enabled') ?? false;
    if (!isMonthlyLimitEnabled) return false;

    final monthlyLimit = prefs.getDouble('monthly_spending_limit') ?? 0.0;
    if (monthlyLimit <= 0) return false;

    _txRepo.setUid(uid);
    _notiRepo.setUid(uid);

    final now = DateTime.now();
    final allTx = await _txRepo.getAllTransactions();
    final thisMonthExpenses = allTx.where((t) =>
        t.type == 'expense' &&
        t.date.year == now.year &&
        t.date.month == now.month).toList();

    final totalMonthExpense = thisMonthExpenses.fold<double>(0.0, (sum, t) => sum + t.amount);

    if (totalMonthExpense > monthlyLimit) {
      final excess = totalMonthExpense - monthlyLimit;
      
      final noti = NotificationModel(
        uid: uid,
        iconCode: Icons.calendar_month_rounded.codePoint,
        title: '🚨 Cảnh báo: Vượt hạn mức chi tiêu tháng!',
        description: 'Tháng này bạn đã chi ${CurrencyUtils.formatCurrency(totalMonthExpense)}, vượt hạn mức ${CurrencyUtils.formatCurrency(monthlyLimit)} (vượt ${CurrencyUtils.formatCurrency(excess)}). Hãy tối giản các khoản chi từ giờ đến cuối tháng nhé! 💪',
        isRead: false,
        type: 'monthly_limit_exceeded',
      );

      await _addNotificationAndPush(noti, pushStatusBar: true);
      return true;
    } else {
      final remaining = monthlyLimit - totalMonthExpense;
      final percentage = ((totalMonthExpense / monthlyLimit) * 100).round();
      final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
      
      if (percentage >= 80) {
        final noti = NotificationModel(
          uid: uid,
          iconCode: Icons.report_problem_rounded.codePoint,
          title: '📊 Cảnh báo: Đã chi $percentage% hạn mức tháng',
          description: 'Bạn đã sử dụng ${CurrencyUtils.formatCurrency(totalMonthExpense)}/${CurrencyUtils.formatCurrency(monthlyLimit)}. Còn lại ${CurrencyUtils.formatCurrency(remaining)} cho $daysLeft ngày tiếp theo. Cân nhắc thắt chặt chi tiêu!',
          isRead: false,
          type: 'monthly_limit_warning',
        );
        await _addNotificationAndPush(noti, pushStatusBar: true);
      }
      
      return false;
    }
  }

  /// Cảnh báo giao dịch chi tiêu lớn đột biến (Spending Spike Alert)
  /// Kích hoạt khi giao dịch mới >= 2.000.000đ hoặc chiếm >= 30% tổng chi tháng
  Future<bool> checkSpendingSpike({
    required double amount,
    required String category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null || amount <= 0) return false;

    try {
      _txRepo.setUid(uid);
      _notiRepo.setUid(uid);

      final now = DateTime.now();
      final allTx = await _txRepo.getAllTransactions();
      final thisMonthExpenses = allTx.where((t) =>
          t.type == 'expense' &&
          t.date.year == now.year &&
          t.date.month == now.month).toList();

      final totalMonthExpense = thisMonthExpenses.fold<double>(0.0, (sum, t) => sum + t.amount);

      final isHighAbsolute = amount >= 2000000; // >= 2.000.000đ
      final isHighRatio = totalMonthExpense > 0 && (amount / totalMonthExpense) >= 0.3; // >= 30% tổng chi

      if (isHighAbsolute || isHighRatio) {
        final noti = NotificationModel(
          uid: uid,
          iconCode: Icons.bolt_rounded.codePoint,
          title: '⚡ Cảnh báo: Khoản chi lớn đột biến',
          description: 'Bạn vừa ghi nhận khoản chi ${CurrencyUtils.formatCurrency(amount)} cho danh mục "$category". Khoản chi này chiếm tỷ trọng lớn trong ngân sách, hãy lưu ý cân đối các khoản chi tiếp theo!',
          isRead: false,
          type: 'spending_spike_alert',
        );

        await _addNotificationAndPush(noti, pushStatusBar: true);
        return true;
      }
    } catch (e) {
      debugPrint('checkSpendingSpike error: $e');
    }
    return false;
  }

  /// Nhắc nhở đồng bộ dữ liệu ngoại tuyến nếu có giao dịch offline chưa sync > 2 ngày
  Future<void> checkOfflineSyncReminder() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null) return;

    try {
      final db = await DatabaseHelper().database;
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;

      final unsynced = await db.query(
        'transactions',
        where: 'uid = ? AND syncStatus = ? AND createdAt <= ?',
        whereArgs: [uid, 'pending', twoDaysAgo],
        limit: 5,
      );

      if (unsynced.isNotEmpty) {
        final noti = NotificationModel(
          uid: uid,
          iconCode: Icons.cloud_off_rounded.codePoint,
          title: '☁️ Nhắc nhở sao lưu dữ liệu ngoại tuyến',
          description: 'Bạn có ${unsynced.length} giao dịch lưu trên máy chưa được đồng bộ lên đám mây hơn 2 ngày. Hãy kết nối mạng Internet để bảo vệ dữ liệu tài chính của bạn an toàn!',
          isRead: false,
          type: 'offline_sync_reminder',
        );

        await _addNotificationAndPush(noti);
      }
    } catch (e) {
      debugPrint('checkOfflineSyncReminder error: $e');
    }
  }

  /// Bắn thông báo đẩy ra ngoài màn hình chính khi vừa thêm một giao dịch mới
  Future<void> notifyTransactionCreated({
    required String type,
    required String category,
    required double amount,
    String? note,
  }) async {
    final isIncome = type == 'income';
    final title = isIncome
        ? '💰 Thu nhập mới: +${CurrencyUtils.formatCurrency(amount)}'
        : '💸 Ghi nhận chi tiêu: -${CurrencyUtils.formatCurrency(amount)}';
    final body = isIncome
        ? 'Đã ghi nhận khoản thu cho "$category"${note != null && note.isNotEmpty ? ' ($note)' : ''}.'
        : 'Đã chi ${CurrencyUtils.formatCurrency(amount)} cho "$category"${note != null && note.isNotEmpty ? ' ($note)' : ''}.';

    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().offlineUid;
    if (uid != null) {
      final noti = NotificationModel(
        uid: uid,
        iconCode: isIncome ? Icons.arrow_downward_rounded.codePoint : Icons.arrow_upward_rounded.codePoint,
        title: title,
        description: body,
        isRead: false,
        type: 'transaction_created',
      );
      await _notiRepo.addNotification(noti);
    }
  }

  /// Tự động đồng bộ trạng thái nhắc nhở 20:00:
  /// Luôn duy trì lịch hẹn 20:00 lặp hàng ngày chừng nào người dùng bật thông báo nhắc nhở
  Future<void> syncDailyReminderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersEnabled = prefs.getBool('notif_reminders') ?? true;

      if (!remindersEnabled) {
        debugPrint('SmartNotificationService: Reminders disabled. Cancelling 20h reminder.');
        await LocalNotificationService.instance.cancelNotification(200);
        return;
      }

      // Luôn duy trì lịch hẹn định kỳ 20:00 mỗi tối (lặp hàng ngày)
      await LocalNotificationService.instance.scheduleDailyReminder(
        id: 200,
        hour: 20,
        minute: 0,
        title: '📝 Nhắc nhở ghi chép chi tiêu',
        body: 'Đừng quên kiểm tra và ghi lại các khoản thu chi phát sinh trong ngày để nắm rõ dòng tiền nhé!',
      );
      debugPrint('SmartNotificationService: 20h daily reminder maintained successfully.');
    } catch (e) {
      debugPrint('Error in syncDailyReminderState: $e');
    }
  }

  /// Kích hoạt toàn bộ các lịch thông báo ngoài màn hình theo cài đặt của người dùng
  Future<void> scheduleAllBackgroundNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersEnabled = prefs.getBool('notif_reminders') ?? true;
      final spendingReportEnabled = prefs.getBool('notif_spending_report') ?? true;
      final smartAdviceEnabled = prefs.getBool('notif_smart_advice') ?? true;

      if (remindersEnabled) {
        await syncDailyReminderState();
      } else {
        await LocalNotificationService.instance.cancelNotification(200);
      }

      if (smartAdviceEnabled) {
        await LocalNotificationService.instance.scheduleDailyAdvice(
          id: 201,
          hour: 11,
          minute: 30,
          title: '💡 Gợi ý tài chính thông minh',
          body: 'Hãy kiểm tra số dư an toàn và cân đối chi tiêu hợp lý cho bữa trưa hôm nay nhé!',
        );
      } else {
        await LocalNotificationService.instance.cancelNotification(201);
      }

      if (spendingReportEnabled) {
        await LocalNotificationService.instance.scheduleWeeklyReport(
          id: 202,
          dayOfWeek: DateTime.sunday,
          hour: 20,
          minute: 30,
          title: '📊 Tổng kết chi tiêu tuần này',
          body: 'Xem lại bức tranh tài chính tuần qua của bạn và sẵn sàng cho kế hoạch tuần mới!',
        );
      } else {
        await LocalNotificationService.instance.cancelNotification(202);
      }
    } catch (e) {
      debugPrint('Error in scheduleAllBackgroundNotifications: $e');
    }
  }

  /// Kiểm tra các ngân sách danh mục (và tổng ngân sách) khi có giao dịch chi tiêu mới
  /// Tự động cảnh báo khi đạt >=80% và vượt 100% ngân sách.
  /// Lưu cờ đã cảnh báo trong SharedPreferences theo dạng:
  /// `budget_warned_80_${budgetId}_${year}_${month}`
  /// `budget_warned_100_${budgetId}_${year}_${month}`
  /// để đảm bảo mỗi ngưỡng chỉ báo 1 lần duy nhất trong kỳ ngân sách, tránh làm phiền!
  Future<void> checkCategoryBudgetThresholds({
    required String category,
    required double expenseAmount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? AuthService().offlineUid;
    if (uid == null || expenseAmount <= 0) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetAlertsEnabled = prefs.getBool('notif_budget_alerts') ?? true;
      if (!budgetAlertsEnabled) return;

      final now = DateTime.now();
      final budgetRepo = BudgetRepository();
      budgetRepo.setUid(uid);
      final budgets = await budgetRepo.getBudgetsWithSpent(month: now.month, year: now.year);
      if (budgets.isEmpty) return;

      // Tìm ngân sách phù hợp: Ngân sách đúng danh mục HOẶC ngân sách 'Tất cả'
      final relevantBudgets = budgets.where((b) =>
          b.category.toLowerCase().trim() == category.toLowerCase().trim() ||
          b.category == 'Tất cả' ||
          b.category.isEmpty).toList();

      for (final b in relevantBudgets) {
        if (b.limitAmount <= 0) continue;

        final key80 = 'budget_warned_80_${b.id}_${now.year}_${now.month}';
        final key100 = 'budget_warned_100_${b.id}_${now.year}_${now.month}';
        final alreadyWarned80 = prefs.getBool(key80) ?? false;
        final alreadyWarned100 = prefs.getBool(key100) ?? false;

        final percentage = (b.currentSpent / b.limitAmount) * 100;
        final isCategoryAll = b.category == 'Tất cả' || b.category.isEmpty;
        final name = isCategoryAll ? 'Tổng ngân sách' : 'Ngân sách "${b.category}"';

        if (b.currentSpent > b.limitAmount) {
          if (!alreadyWarned100) {
            final excess = b.currentSpent - b.limitAmount;
            final noti = NotificationModel(
              uid: uid,
              iconCode: Icons.warning_rounded.codePoint,
              title: '🚨 $name đã vượt 100%!',
              description: 'Bạn đã chi ${CurrencyUtils.formatCurrency(b.currentSpent)}/${CurrencyUtils.formatCurrency(b.limitAmount)} (vượt ${CurrencyUtils.formatCurrency(excess)}). Hãy kiểm soát chi tiêu cho danh mục này!',
              isRead: false,
              type: 'budget_limit_exceeded',
            );
            await _addNotificationAndPush(noti, pushStatusBar: true);
            await prefs.setBool(key100, true);
            await prefs.setBool(key80, true); // Đã vượt 100% thì tự đánh dấu đã qua 80%
          }
        } else if (percentage >= 80.0) {
          if (!alreadyWarned80) {
            final remaining = b.remainingAmount;
            final noti = NotificationModel(
              uid: uid,
              iconCode: Icons.notification_important_rounded.codePoint,
              title: '⚠️ $name đã chạm ${percentage.round()}% hạn mức!',
              description: 'Đã chi ${CurrencyUtils.formatCurrency(b.currentSpent)}/${CurrencyUtils.formatCurrency(b.limitAmount)}. Chỉ còn lại ${CurrencyUtils.formatCurrency(remaining)} cho tháng này!',
              isRead: false,
              type: 'budget_limit_warning',
            );
            await _addNotificationAndPush(noti, pushStatusBar: true);
            await prefs.setBool(key80, true);
          }
        }
      }
    } catch (e) {
      debugPrint('checkCategoryBudgetThresholds error: $e');
    }
  }
}

