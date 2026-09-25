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
    final user = FirebaseAuth.instance.currentUser;
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

          if (diffPercent > 10) {
            // Chi tiêu tăng cao
            await _addNotificationAndPush(
              NotificationModel(
                uid: uid,
                iconCode: Icons.trending_up_rounded.codePoint,
                title: '⚠️ Cảnh báo chi tiêu: Tăng ${diffPercent.abs().toStringAsFixed(0)}%',
                description: 'Chi tiêu tháng này (${CurrencyUtils.formatCurrency(thisMonthExpense)}) đang cao hơn ${diffPercent.abs().toStringAsFixed(0)}% so với cùng kỳ tháng trước (${CurrencyUtils.formatCurrency(prevMonthExpense)}). Bạn hãy kiểm tra lại các khoản chi lớn để tối ưu ngân sách!',
                isRead: false,
                type: 'spending_alert_high',
              ),
            );
            count++;
          } else if (diffPercent < -5) {
            // Tiết kiệm tốt
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
          } else {
            // Chi tiêu ổn định
            await _addNotificationAndPush(
              NotificationModel(
                uid: uid,
                iconCode: Icons.balance_rounded.codePoint,
                title: '📊 Báo cáo: Chi tiêu duy trì ổn định',
                description: 'Chi tiêu tháng này (${CurrencyUtils.formatCurrency(thisMonthExpense)}) ở mức cân bằng so với tháng trước (${CurrencyUtils.formatCurrency(prevMonthExpense)}). Bạn đang kiểm soát tốt kế hoạch thu chi.',
                isRead: false,
                type: 'spending_alert_stable',
              ),
            );
            count++;
          }
        } else if (thisMonthExpense > 0) {
          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.insights_rounded.codePoint,
              title: '📊 Báo cáo chi tiêu tháng này',
              description: 'Tổng chi tiêu tháng này của bạn hiện tại là ${CurrencyUtils.formatCurrency(thisMonthExpense)}. Hãy ghi chép đều đặn để hệ thống so sánh với kỳ tiếp theo!',
              isRead: false,
              type: 'spending_report_first',
            ),
          );
          count++;
        }
      }

      // ════════ PHÂN TÍCH 2: GỢI Ý CHI TIÊU KHOA HỌC VỚI SỐ TIỀN CÒN LẠI ════════
      if (smartAdviceEnabled) {
        final totalBalance = await _walletRepo.getTotalBalance();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = daysInMonth - now.day + 1;

        if (totalBalance > 200000) {
          // Trích 25% dự phòng tiết kiệm, chia 75% cho các ngày còn lại
          final safeDailyBudget = (totalBalance * 0.75) / daysLeft;

          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.lightbulb_outline_rounded.codePoint,
              title: '💡 Gợi ý chi tiêu cho $daysLeft ngày tới',
              description: 'Số dư khả dụng các ví là ${CurrencyUtils.formatCurrency(totalBalance)}. Bạn nên chi tối đa khoảng ${CurrencyUtils.formatCurrency(safeDailyBudget)}/ngày để vừa chi tiêu thoải mái vừa giữ được 25% quỹ tiết kiệm tích lũy!',
              isRead: false,
              type: 'smart_budget_suggestion',
            ),
          );
          count++;
        } else if (totalBalance <= 100000) {
          await _addNotificationAndPush(
            NotificationModel(
              uid: uid,
              iconCode: Icons.warning_amber_rounded.codePoint,
              title: '⚠️ Cảnh báo số dư ví cần chú ý',
              description: 'Tổng số dư các ví đang ở mức thấp (${CurrencyUtils.formatCurrency(totalBalance)}). Bạn nên hạn chế các khoản mua sắm chưa cấp bách trong $daysLeft ngày còn lại của tháng!',
              isRead: false,
              type: 'low_balance_alert',
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

        if (todayTx.isEmpty) {
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

        // Luôn duy trì lịch hẹn định kỳ 20:00 mỗi tối khi người dùng bật reminders
        await LocalNotificationService.instance.scheduleDailyReminder(
          id: 200,
          hour: 20,
          minute: 0,
          title: '📝 Nhắc nhở ghi chép chi tiêu',
          body: 'Đừng quên ghi lại các khoản phát sinh trong ngày để quản lý dòng tiền tốt nhất nhé!',
        );
      }

      // Lưu lại ngày đã phân tích
      await prefs.setString('notif_last_analysis_day_$uid', todayKey);
    } catch (e) {
      debugPrint('SmartNotificationService error: $e');
    }

    return count;
  }

  /// Kiểm tra hạn mức chi tiêu hàng ngày - Thông báo vui vẻ, thân thiện
  /// Được gọi ngay sau khi thêm một giao dịch chi tiêu mới
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
      // VƯỢT HẠN MỨC - Thông báo vui vẻ, không quá nghiêm trọng
      final excess = totalTodayExpense - dailyLimit;
      final funMessages = [
        'Ví tiền đang kêu cứu rồi nè! 😅 Hôm nay bạn đã tiêu ${CurrencyUtils.formatCurrency(totalTodayExpense)}, vượt hạn mức ${CurrencyUtils.formatCurrency(dailyLimit)} một chút (${CurrencyUtils.formatCurrency(excess)}). Không sao, mai mình tiết kiệm lại nhé! 💪',
        'Oops! Hôm nay bạn "xài hơi tay" rồi nè 🤭 Chi tiêu ${CurrencyUtils.formatCurrency(totalTodayExpense)} vượt qua mức ${CurrencyUtils.formatCurrency(dailyLimit)}. Cố gắng kiềm chế nha, ví tiền cảm ơn bạn! 😄',
        'Hôm nay chi tiêu hơi "phiêu" nha! 🎢 ${CurrencyUtils.formatCurrency(totalTodayExpense)} rồi đó, vượt hạn mức ${CurrencyUtils.formatCurrency(dailyLimit)}. Nhưng đôi khi cũng phải tự thưởng mình chứ nhỉ? 🎁',
      ];
      
      final randomMsg = funMessages[now.millisecond % funMessages.length];

      final noti = NotificationModel(
        uid: uid,
        iconCode: Icons.sentiment_satisfied_alt_rounded.codePoint,
        title: '🙈 Ối! Hôm nay chi tiêu hơi nhiều rồi nè',
        description: randomMsg,
        isRead: false,
        type: 'daily_limit_exceeded',
      );

      await _addNotificationAndPush(noti);
      return true;
    } else {
      // DƯỚI HOẶC BẰNG HẠN MỨC - Thông báo chúc mừng!
      final remaining = dailyLimit - totalTodayExpense;
      final percentage = ((totalTodayExpense / dailyLimit) * 100).round();
      
      String congratsMessage;
      String congratsTitle;
      
      if (percentage <= 50) {
        congratsTitle = '🌟 Tuyệt vời! Tiết kiệm siêu giỏi';
        congratsMessage = 'Bạn mới chi ${CurrencyUtils.formatCurrency(totalTodayExpense)} ($percentage% hạn mức). Còn ${CurrencyUtils.formatCurrency(remaining)} cho ngày hôm nay. Keep going! 🚀';
      } else if (percentage <= 80) {
        congratsTitle = '👏 Giỏi lắm! Vẫn trong tầm kiểm soát';
        congratsMessage = 'Chi tiêu hôm nay ${CurrencyUtils.formatCurrency(totalTodayExpense)} ($percentage% hạn mức). Vẫn còn ${CurrencyUtils.formatCurrency(remaining)} để sử dụng. Bạn đang quản lý tốt lắm! 💎';
      } else {
        congratsTitle = '⚡ Cẩn thận nha! Gần tới hạn mức rồi';
        congratsMessage = 'Hôm nay đã chi ${CurrencyUtils.formatCurrency(totalTodayExpense)} ($percentage% hạn mức ${CurrencyUtils.formatCurrency(dailyLimit)}). Còn ${CurrencyUtils.formatCurrency(remaining)} thôi. Cân nhắc trước khi chi thêm nhé! 🤔';
      }

      final noti = NotificationModel(
        uid: uid,
        iconCode: Icons.emoji_events_rounded.codePoint,
        title: congratsTitle,
        description: congratsMessage,
        isRead: false,
        type: 'daily_limit_within',
      );

      await _addNotificationAndPush(noti);
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
        title: '📅 Hạn mức tháng đã vượt rồi nè!',
        description: 'Tháng này bạn đã chi ${CurrencyUtils.formatCurrency(totalMonthExpense)}, vượt hạn mức ${CurrencyUtils.formatCurrency(monthlyLimit)} (thêm ${CurrencyUtils.formatCurrency(excess)}). Thử cân nhắc lại các khoản chi tiếp theo nhé! Bạn làm được mà 💪😊',
        isRead: false,
        type: 'monthly_limit_exceeded',
      );

      await _addNotificationAndPush(noti);
      return true;
    } else {
      final remaining = monthlyLimit - totalMonthExpense;
      final percentage = ((totalMonthExpense / monthlyLimit) * 100).round();
      final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
      
      if (percentage >= 80) {
        final noti = NotificationModel(
          uid: uid,
          iconCode: Icons.info_outline_rounded.codePoint,
          title: '📊 Cập nhật hạn mức tháng',
          description: 'Đã chi $percentage% hạn mức tháng (${CurrencyUtils.formatCurrency(totalMonthExpense)}/${CurrencyUtils.formatCurrency(monthlyLimit)}). Còn ${CurrencyUtils.formatCurrency(remaining)} cho $daysLeft ngày còn lại. Cố lên nha! 🌈',
          isRead: false,
          type: 'monthly_limit_warning',
        );
        await _addNotificationAndPush(noti);
      }
      
      return false;
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
}

