import 'package:flutter/material.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/transaction_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../modules/transaction/add_transaction_screen.dart';
import '../../modules/transaction/all_transactions_screen.dart';
import '../../modules/transaction/category_screen.dart';
import '../../modules/transaction/transaction_gallery_screen.dart';
import '../../modules/home/statistics_screen.dart';
import '../../modules/home/wallet_screen.dart';
import '../../modules/home/export_report_screen.dart';
import '../../modules/home/notification_screen.dart';
import '../../modules/calendar/calendar_tracking_screen.dart';
import '../../modules/budget/budget_and_goals_screen.dart';
import '../../modules/settings/ai_settings_screen.dart';
import '../../modules/settings/appearance_screen.dart';
import '../../modules/settings/language_screen.dart';
import '../../modules/settings/account_info_screen.dart';
import '../../modules/settings/about_app_screen.dart';
import '../../modules/settings/support_request_screen.dart';
import '../../features/group_expense/presentation/screens/group_list_screen.dart';
import 'theme_service.dart';
import 'language_service.dart';
import 'ai_financial_context_service.dart';

class SpendingReportResult {
  final String periodText;
  final double totalExpense;
  final double totalIncome;
  final int transactionCount;
  final Map<String, double> topCategories;
  final String summaryText;

  SpendingReportResult({
    required this.periodText,
    required this.totalExpense,
    required this.totalIncome,
    required this.transactionCount,
    required this.topCategories,
    required this.summaryText,
  });

  double get netBalance => totalIncome - totalExpense;
  double get savingsRate => totalIncome > 0 ? (((totalIncome - totalExpense) / totalIncome) * 100).clamp(0.0, 100.0) : 0.0;
  double get expenseRatio => totalIncome > 0 ? (totalExpense / totalIncome).clamp(0.0, 1.0) * 100 : (totalExpense > 0 ? 100.0 : 0.0);
  bool get isDeficit => totalExpense > totalIncome;
}

class FinancialAdviceResult {
  final String title;
  final String summaryText;
  final double totalBalance;
  final double needs50;
  final double wants30;
  final double savings20;
  final List<String> actionableTips;
  final String? targetNavigation;

  FinancialAdviceResult({
    required this.title,
    required this.summaryText,
    required this.totalBalance,
    required this.needs50,
    required this.wants30,
    required this.savings20,
    required this.actionableTips,
    this.targetNavigation,
  });
}

class AiActionHandler {
  static final AiActionHandler _instance = AiActionHandler._internal();
  factory AiActionHandler() => _instance;
  AiActionHandler._internal();

  /// Điều hướng trực tiếp đến bất kỳ màn hình nào trong ứng dụng theo lệnh của người dùng
  Future<void> navigateToScreen(BuildContext context, String target) async {
    Widget? screen;
    switch (target) {
      case 'addTransaction':
        screen = const AddTransactionScreen();
        break;
      case 'allTransactions':
        screen = const AllTransactionsScreen();
        break;
      case 'statistics':
        screen = const StatisticsScreen();
        break;
      case 'calendar':
        screen = const CalendarTrackingScreen();
        break;
      case 'category':
        screen = const CategoryScreen(isIncome: false);
        break;
      case 'wallets':
        screen = const WalletScreen();
        break;
      case 'groupExpense':
        screen = const GroupListScreen();
        break;
      case 'budget':
      case 'budgetLimit':
        screen = const BudgetAndGoalsScreen();
        break;
      case 'exportReport':
        screen = const ExportReportScreen();
        break;
      case 'receiptGallery':
        screen = const TransactionGalleryScreen();
        break;
      case 'notifications':
        screen = const NotificationScreen();
        break;
      case 'aiSettings':
        screen = const AiSettingsScreen();
        break;
      case 'appearance':
        screen = const AppearanceScreen();
        break;
      case 'language':
        screen = const LanguageScreen();
        break;
      case 'accountInfo':
        screen = const AccountInfoScreen();
        break;
      case 'aboutApp':
        screen = const AboutAppScreen();
        break;
      case 'support':
        screen = const SupportRequestScreen();
        break;
    }

    if (screen != null && context.mounted) {
      await Navigator.push(context, PageTransitions.slideRight(screen));
    }
  }

  /// Lấy tiêu đề thân thiện của màn hình
  String getScreenTitle(String target) {
    switch (target) {
      case 'addTransaction':
        return 'Thêm giao dịch mới';
      case 'allTransactions':
        return 'Tất cả giao dịch';
      case 'statistics':
        return 'Thống kê & Biểu đồ';
      case 'calendar':
        return 'Lịch theo dõi chi tiêu';
      case 'category':
        return 'Danh mục thu chi';
      case 'wallets':
        return 'Quản lý ví tiền';
      case 'groupExpense':
        return 'Chi tiêu nhóm';
      case 'budget':
      case 'budgetLimit':
        return 'Ngân sách & Mục tiêu';
      case 'exportReport':
        return 'Xuất báo cáo (Excel/PDF)';
      case 'receiptGallery':
        return 'Thư viện hóa đơn';
      case 'notifications':
        return 'Thông báo';
      case 'aiSettings':
        return 'Cài đặt Trợ lý Mono';
      case 'appearance':
        return 'Giao diện & Chủ đề';
      case 'language':
        return 'Ngôn ngữ ứng dụng';
      case 'accountInfo':
        return 'Thông tin tài khoản';
      case 'aboutApp':
        return 'Giới thiệu Mono';
      case 'support':
        return 'Trung tâm hỗ trợ';
      default:
        return 'Mở tính năng';
    }
  }

  /// Lấy icon đại diện của màn hình
  IconData getScreenIcon(String target) {
    switch (target) {
      case 'addTransaction':
        return Icons.add_circle_outline_rounded;
      case 'allTransactions':
        return Icons.receipt_long_rounded;
      case 'statistics':
        return Icons.bar_chart_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      case 'category':
        return Icons.category_rounded;
      case 'wallets':
        return Icons.account_balance_wallet_rounded;
      case 'groupExpense':
        return Icons.group_rounded;
      case 'budget':
      case 'budgetLimit':
        return Icons.savings_rounded;
      case 'exportReport':
        return Icons.file_download_outlined;
      case 'receiptGallery':
        return Icons.photo_library_rounded;
      case 'notifications':
        return Icons.notifications_outlined;
      case 'aiSettings':
        return Icons.smart_toy_outlined;
      case 'appearance':
        return Icons.palette_outlined;
      case 'language':
        return Icons.language_rounded;
      case 'accountInfo':
        return Icons.person_outline_rounded;
      case 'aboutApp':
        return Icons.info_outline_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      default:
        return Icons.open_in_new_rounded;
    }
  }

  /// Đổi Theme (Sáng / Tối)
  Future<bool> changeTheme(String modeStr) async {
    final themeService = ThemeService();
    final lower = modeStr.toLowerCase().trim();
    if (lower.contains('dark') || lower.contains('tối')) {
      await themeService.setThemeMode(ThemeMode.dark);
      return true;
    } else if (lower.contains('light') || lower.contains('sáng')) {
      await themeService.setThemeMode(ThemeMode.light);
      return true;
    } else {
      await themeService.setThemeMode(ThemeMode.system);
      return true;
    }
  }

  /// Đổi Ngôn ngữ (vi / en)
  Future<bool> changeLanguage(String langStr) async {
    final languageService = LanguageService();
    final lower = langStr.toLowerCase().trim();
    if (lower.contains('en') || lower.contains('tiếng anh') || lower.contains('english')) {
      await languageService.setLanguage('en');
      return true;
    } else {
      await languageService.setLanguage('vi');
      return true;
    }
  }

  /// Tạo báo cáo chi tiêu thời gian thực từ kho dữ liệu SQLite/Firestore
  Future<SpendingReportResult> generateSpendingReport(String period) async {
    final repo = TransactionRepository();
    final allTxs = await repo.getAllTransactions();
    final now = DateTime.now();

    List<TransactionModel> filtered = [];
    String periodText = 'hôm nay';

    final p = period.toLowerCase();
    if (p.contains('hôm nay') || p.contains('today')) {
      periodText = 'Hôm nay (${now.day}/${now.month})';
      filtered = allTxs.where((tx) =>
          tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day).toList();
    } else if (p.contains('hôm qua') || p.contains('yesterday')) {
      final yesterday = now.subtract(const Duration(days: 1));
      periodText = 'Hôm qua (${yesterday.day}/${yesterday.month})';
      filtered = allTxs.where((tx) =>
          tx.date.year == yesterday.year &&
          tx.date.month == yesterday.month &&
          tx.date.day == yesterday.day).toList();
    } else if (p.contains('tuần') || p.contains('week')) {
      periodText = 'Tuần này';
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final cleanStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      filtered = allTxs.where((tx) => !tx.date.isBefore(cleanStart)).toList();
    } else if (p.contains('năm') || p.contains('year')) {
      periodText = 'Năm ${now.year}';
      filtered = allTxs.where((tx) => tx.date.year == now.year).toList();
    } else {
      // Mặc định là tháng này
      periodText = 'Tháng ${now.month}/${now.year}';
      filtered = allTxs.where((tx) =>
          tx.date.year == now.year && tx.date.month == now.month).toList();
    }

    double expense = 0;
    double income = 0;
    final Map<String, double> categorySums = {};

    for (var tx in filtered) {
      if (tx.type == 'income') {
        income += tx.amount;
      } else {
        expense += tx.amount;
        categorySums[tx.category] = (categorySums[tx.category] ?? 0) + tx.amount;
      }
    }

    // Lấy top 3 danh mục chi tiêu nhiều nhất
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = Map.fromEntries(sortedCategories.take(3));

    final sb = StringBuffer();
    sb.writeln('📊 **Báo cáo chi tiêu $periodText:**');
    sb.writeln('• Tổng chi: **${CurrencyUtils.formatCurrency(expense)}**');
    sb.writeln('• Tổng thu: **${CurrencyUtils.formatCurrency(income)}**');
    if (expense > 0 && top3.isNotEmpty) {
      sb.writeln('• Khoản chi lớn nhất:');
      top3.forEach((cat, amt) {
        sb.writeln('   - $cat: ${CurrencyUtils.formatCurrency(amt)}');
      });
    }

    return SpendingReportResult(
      periodText: periodText,
      totalExpense: expense,
      totalIncome: income,
      transactionCount: filtered.length,
      topCategories: top3,
      summaryText: sb.toString().trim(),
    );
  }

  /// Kiểm tra các yêu cầu liên quan đến bảo mật / quyền riêng tư nhạy cảm
  /// Trợ lý Mono sẽ từ chối tự động thực hiện và hướng dẫn người dùng tự thao tác
  String? checkSecurityRestriction(String text) {
    final lower = text.toLowerCase();
    
    // Đổi mật khẩu
    if (lower.contains('đổi mật khẩu') || lower.contains('reset mật khẩu') || lower.contains('thay mật khẩu') || lower.contains('change password')) {
      return 'Vì lý do an toàn và bảo mật tài khoản, Trợ lý Mono không thể trực tiếp thay đổi mật khẩu của bạn. Bạn vui lòng bấm vào nút bên dưới để mở màn hình **Đổi mật khẩu** và xác thực an toàn.';
    }

    // Xóa tài khoản
    if (lower.contains('xóa tài khoản') || lower.contains('xóa nick') || lower.contains('hủy tài khoản') || lower.contains('delete account')) {
      return 'Yêu cầu xóa tài khoản ảnh hưởng trực tiếp tới toàn bộ dữ liệu tài chính của bạn. Trợ lý Mono không được phép tự ý thực hiện thao tác này. Vui lòng vào Cài đặt -> Tài khoản để xác nhận thủ công.';
    }

    // Sinh trắc học
    if (lower.contains('tắt vân tay') || lower.contains('bật vân tay') || lower.contains('face id') || lower.contains('sinh trắc học')) {
      return 'Cài đặt sinh trắc học (Vân tay / FaceID) yêu cầu quyền xác thực phần cứng trực tiếp từ bạn. Bạn có thể cấu hình nhanh trong mục **Đăng nhập sinh trắc học**.';
    }

    // Chuyển tiền / Giao dịch ngân hàng thực tế ra bên ngoài
    if (lower.contains('chuyển tiền cho') || lower.contains('bắn tiền') || lower.contains('rút tiền về ngân hàng')) {
      return 'Ứng dụng Mono là sổ theo dõi quản lý thu chi cá nhân, không có chức năng chuyển tiền ngân hàng thực tế. Trợ lý Mono có thể giúp bạn **ghi nhận lại giao dịch thu/chi** này vào sổ sách!';
    }

    return null;
  }

  /// Đề xuất phân bổ tài chính thông minh (quy tắc 50/30/20, gợi ý ngân sách & mục tiêu)
  Future<FinancialAdviceResult> generateFinancialAdvice({String? specificQuery}) async {
    final snapshot = await AiFinancialContextService().getFinancialSnapshot();
    final balance = snapshot.totalBalance > 0 ? snapshot.totalBalance : 0.0;

    final needs50 = balance * 0.50;
    final wants30 = balance * 0.30;
    final savings20 = balance * 0.20;

    final List<String> tips = [];
    String targetNav = 'budget';

    if (snapshot.topCategories.isNotEmpty) {
      final topEntry = snapshot.topCategories.entries.first;
      tips.add('Danh mục chi nhiều nhất là **${topEntry.key}** (${CurrencyUtils.formatCurrency(topEntry.value)}). Bạn có thể đặt hạn mức chi tiêu để cắt giảm 10-15%.');
    }

    if (snapshot.goals.isNotEmpty) {
      final firstGoal = snapshot.goals.first;
      tips.add('Bạn có mục tiêu "**${firstGoal.title}**" (đã đạt ${CurrencyUtils.formatCurrency(firstGoal.currentAmount)} / ${CurrencyUtils.formatCurrency(firstGoal.targetAmount)}). Hãy trích phần tiết kiệm 20% (${CurrencyUtils.formatCurrency(savings20)}) để nhanh chóng hoàn thành mục tiêu!');
      targetNav = 'budget';
    } else {
      tips.add('Bạn chưa đặt mục tiêu tiết kiệm nào. Hãy tạo quỹ dự phòng khẩn cấp bằng 3-6 tháng chi tiêu để an tâm tài chính.');
      targetNav = 'budget';
    }

    tips.add('Áp dụng quy tắc "Chờ 48 giờ" trước các khoản mua sắm ngẫu hứng trên 500k để tránh lãng phí.');

    final summary = StringBuffer();
    summary.writeln('💡 **Đề xuất phân bổ tài chính theo quy tắc 50/30/20:**');
    if (balance > 0) {
      summary.writeln('Với số dư khả dụng **${CurrencyUtils.formatCurrency(balance)}**, Mono đề xuất bạn phân bổ như sau:');
      summary.writeln('• **50% Thiết yếu**: ${CurrencyUtils.formatCurrency(needs50)} (Tiền nhà, ăn uống, hóa đơn sinh hoạt)');
      summary.writeln('• **30% Linh hoạt**: ${CurrencyUtils.formatCurrency(wants30)} (Giải trí, mua sắm, giao lưu bạn bè)');
      summary.writeln('• **20% Tiết kiệm & Dự phòng**: ${CurrencyUtils.formatCurrency(savings20)} (Mục tiêu tiết kiệm, quỹ khẩn cấp)');
    } else {
      summary.writeln('Hiện tại số dư của bạn chưa có thặng dư lớn. Hãy ưu tiên ghi chép đầy đủ các khoản chi nhỏ lẻ và tập trung cắt giảm các chi phí không cần thiết!');
    }

    return FinancialAdviceResult(
      title: 'Đề xuất phân bổ & Mẹo tiết kiệm',
      summaryText: summary.toString().trim(),
      totalBalance: balance,
      needs50: needs50,
      wants30: wants30,
      savings20: savings20,
      actionableTips: tips,
      targetNavigation: targetNav,
    );
  }
}
