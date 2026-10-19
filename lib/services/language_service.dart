import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Global helper for convenience across all screens, dialogs and widgets
bool get isVi => LanguageService.instance.isVietnamese;

/// Scope kế thừa InheritedNotifier liên kết với LanguageService
/// Tự động đánh dấu dirty và rebuild mọi widget gọi `context.tr()` hoặc `context.trCat()`
class LanguageScope extends InheritedNotifier<LanguageService> {
  const LanguageScope({
    super.key,
    required LanguageService service,
    required super.child,
  }) : super(notifier: service);

  static LanguageService of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier 
        ?? LanguageService.instance;
  }
}

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static LanguageService get instance => _instance;

  final _storage = const FlutterSecureStorage();
  String _currentLanguage = 'vi'; // Default to Vietnamese

  String get currentLanguage => _currentLanguage;
  bool get isVietnamese => _currentLanguage == 'vi';

  // Available languages list
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'vi', 'name': 'Tiếng Việt', 'flag': '🇻🇳'},
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
  ];

  Future<void> init() async {
    try {
      // 1. Try remote Firestore preference first if logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final settings = doc.data()?['settings'];
          if (settings != null && settings['language'] != null) {
            final remoteLang = settings['language'].toString();
            if (remoteLang == 'vi' || remoteLang == 'en') {
              _currentLanguage = remoteLang;
              await _storage.write(key: 'app_language', value: remoteLang);
              notifyListeners();
              return;
            }
          }
        }
      }

      final local = await _storage.read(key: 'app_language');
      if (local != null && (local == 'vi' || local == 'en')) {
        _currentLanguage = local;
      } else {
        _currentLanguage = 'vi';
      }
    } catch (_) {
      _currentLanguage = 'vi';
    }
    notifyListeners();
  }

  /// Sets language with 0ms UI lag (instant memory update & notifyListeners)
  Future<void> setLanguage(String code) async {
    if (code != 'vi' && code != 'en') return;
    if (_currentLanguage == code) return;

    _currentLanguage = code;
    notifyListeners(); // INSTANT UI response!

    // Async persist in background
    _persistLanguage(code);
  }

  void _persistLanguage(String code) async {
    try {
      await _storage.write(key: 'app_language', value: code);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'settings': {'language': code},
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('LanguageService persist error: $e');
    }
  }

  /// Translate a key to current language with zero-tech-leak fallback
  String t(String key) {
    final langMap = _translations[key];
    if (langMap != null) {
      return langMap[_currentLanguage] ?? langMap['vi'] ?? key;
    }
    // Zero-Tech-Leak Fallback: If key is missing, avoid leaking raw snake_case programming code to UI
    if (key.contains('_')) {
      final clean = key
          .replaceAll('_label', '')
          .replaceAll('_hint', '')
          .replaceAll('_error', '')
          .replaceAll('_btn', '')
          .replaceAll('_title', '')
          .replaceAll('_desc', '');
      final subMap = _translations[clean];
      if (subMap != null) {
        return subMap[_currentLanguage] ?? subMap['vi'] ?? clean;
      }
    }
    return key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // ══════════════════════════════════════════════════
    // Navigation & App Dock
    // ══════════════════════════════════════════════════
    'nav_home': {'vi': 'Trang chủ', 'en': 'Home'},
    'nav_stats': {'vi': 'Thống kê', 'en': 'Statistics'},
    'nav_wallets': {'vi': 'Ví tiền', 'en': 'Wallets'},
    'nav_profile': {'vi': 'Cài đặt', 'en': 'Settings'},
    'add_transaction_tooltip': {'vi': 'Thêm giao dịch', 'en': 'Add transaction'},
    'press_again_to_exit': {'vi': 'Nhấn lần nữa để thoát ứng dụng', 'en': 'Press back again to exit'},

    // ══════════════════════════════════════════════════
    // Home Screen & Balance Card
    // ══════════════════════════════════════════════════
    'greeting_morning': {'vi': 'Chào buổi sáng', 'en': 'Good morning'},
    'greeting_afternoon': {'vi': 'Chào buổi chiều', 'en': 'Good afternoon'},
    'greeting_evening': {'vi': 'Chào buổi tối', 'en': 'Good evening'},
    'user_fallback': {'vi': 'Người dùng', 'en': 'User'},
    'total_balance': {'vi': 'Tổng số dư', 'en': 'Total Balance'},
    'income': {'vi': 'Thu nhập', 'en': 'Income'},
    'expense': {'vi': 'Chi phí', 'en': 'Expense'},
    'flow_income': {'vi': 'Thu', 'en': 'Income'},
    'flow_expense': {'vi': 'Chi', 'en': 'Expense'},
    'no_cash_flow': {'vi': 'Chưa có dòng tiền', 'en': 'No cash flow yet'},
    'tx_history': {'vi': 'Lịch sử giao dịch', 'en': 'Transaction History'},
    'see_all': {'vi': 'Xem tất cả', 'en': 'See all'},
    'gallery': {'vi': 'Thư viện ảnh', 'en': 'Gallery'},
    'no_tx_month': {'vi': 'Chưa có giao dịch trong tháng này', 'en': 'No transactions this month'},
    'quick_transfer': {'vi': 'Chuyển tiền', 'en': 'Transfer'},
    'quick_scan': {'vi': 'Quét hóa đơn', 'en': 'Scan AI'},
    'quick_budget': {'vi': 'Ngân sách', 'en': 'Budget'},
    'quick_mono': {'vi': 'Trợ lý Mono', 'en': 'Mono AI'},

    // ══════════════════════════════════════════════════
    // Wallet Screen & Modern Wallet Form
    // ══════════════════════════════════════════════════
    'wallets_title': {'vi': 'Ví tiền', 'en': 'Wallets'},
    'total_net_worth': {'vi': 'Tổng tài sản', 'en': 'Total Net Worth'},
    'personal_net_worth': {'vi': 'TỔNG TÀI SẢN CÁ NHÂN', 'en': 'TOTAL NET WORTH'},
    'asset_allocation': {'vi': 'Phân bổ tài sản', 'en': 'Asset Allocation'},
    'account_cards': {'vi': 'Thẻ tài khoản', 'en': 'Account Cards'},
    'accounts_count': {'vi': '{count} tài khoản', 'en': '{count} accounts'},
    'transfer_money': {'vi': 'Chuyển tiền giữa các ví', 'en': 'Transfer Between Wallets'},
    'add_wallet': {'vi': 'Thêm ví mới', 'en': 'Add New Wallet'},
    'create_wallet': {'vi': 'Tạo ví mới', 'en': 'Create New Wallet'},
    'edit_wallet': {'vi': 'Chỉnh sửa ví', 'en': 'Edit Wallet'},
    'wallet_name': {'vi': 'Tên ví', 'en': 'Wallet Name'},
    'wallet_name_label': {'vi': 'Tên chiếc ví', 'en': 'Wallet Name'},
    'wallet_name_hint': {'vi': 'Nhập tên ví (VD: Tiền mặt, Techcombank...)', 'en': 'Enter wallet name (e.g. Cash, Chase...)'},
    'initial_balance': {'vi': 'Số dư ban đầu', 'en': 'Initial Balance'},
    'initial_balance_label': {'vi': 'Số dư ban đầu', 'en': 'Initial Balance'},
    'current_balance': {'vi': 'Số dư hiện tại', 'en': 'Current Balance'},
    'current_balance_label': {'vi': 'Số dư hiện tại', 'en': 'Current Balance'},
    'wallet_category': {'vi': 'Phân loại ví', 'en': 'Wallet Category'},
    'wallet_type_label': {'vi': 'Loại ví tiền', 'en': 'Wallet Type'},
    'color_label': {'vi': 'Màu sắc nhận diện', 'en': 'Wallet Color'},
    'icon_label': {'vi': 'Biểu tượng đại diện', 'en': 'Wallet Icon'},
    'default_wallet': {'vi': 'Ví mặc định', 'en': 'Default Wallet'},
    'default_wallet_label': {'vi': 'Đặt làm ví mặc định', 'en': 'Set as Default Wallet'},
    'note_optional_label': {'vi': 'Ghi chú (tùy chọn)', 'en': 'Note (optional)'},
    'create_wallet_btn': {'vi': 'Tạo ví ngay', 'en': 'Create Wallet'},
    'save_changes': {'vi': 'Lưu thay đổi', 'en': 'Save Changes'},
    'enter_wallet_name_error': {'vi': 'Vui lòng nhập tên ví!', 'en': 'Please enter wallet name!'},
    'create_wallet_success': {'vi': 'Đã tạo ví mới thành công!', 'en': 'Wallet created successfully!'},
    'update_wallet_success': {'vi': 'Đã cập nhật thông tin ví!', 'en': 'Wallet updated successfully!'},
    'save_wallet': {'vi': 'Lưu ví', 'en': 'Save Wallet'},
    'confirm_delete_wallet': {'vi': 'Bạn có chắc chắn muốn xóa ví này không?', 'en': 'Are you sure you want to delete this wallet?'},
    'empty_wallets': {'vi': 'Chưa có ví tiền nào. Hãy bấm nút + để tạo ví đầu tiên!', 'en': 'No wallets yet. Tap + to create your first wallet!'},
    'wallet_cash': {'vi': 'Tiền mặt', 'en': 'Cash'},
    'wallet_bank': {'vi': 'Tài khoản ngân hàng', 'en': 'Bank Account'},
    'wallet_e_wallet': {'vi': 'Ví điện tử', 'en': 'E-Wallet'},
    'wallet_credit': {'vi': 'Thẻ tín dụng', 'en': 'Credit Card'},
    'wallet_savings': {'vi': 'Sổ tiết kiệm', 'en': 'Savings'},
    'wallet_investment': {'vi': 'Đầu tư', 'en': 'Investment'},
    'wallet_other': {'vi': 'Khác', 'en': 'Other'},
    'all_wallets': {'vi': 'Tất cả ví', 'en': 'All Wallets'},
    'see_all_wallets': {'vi': '✕ Xem tất cả ví', 'en': '✕ View all wallets'},
    'wallet_list': {'vi': 'Danh sách ví tiền', 'en': 'Wallet List'},
    'wallet_history': {'vi': 'Lịch sử ví', 'en': 'Wallet History'},
    'is_default': {'vi': 'Mặc định', 'en': 'Default'},

    // ══════════════════════════════════════════════════
    // Wallet Transfer & Actions
    // ══════════════════════════════════════════════════
    'transfer_title': {'vi': 'Chuyển tiền giữa các ví', 'en': 'Transfer Between Wallets'},
    'transfer_from': {'vi': 'Chuyển từ ví', 'en': 'From Wallet'},
    'transfer_to': {'vi': 'Nhận vào ví', 'en': 'To Wallet'},
    'transfer_amount_label': {'vi': 'Số tiền chuyển', 'en': 'Transfer Amount'},
    'transfer_fee_label': {'vi': 'Phí giao dịch (nếu có)', 'en': 'Transfer Fee (optional)'},
    'balance_prefix': {'vi': 'Số dư', 'en': 'Balance'},
    'transfer_min_wallets_error': {'vi': 'Bạn cần ít nhất 2 ví để thực hiện chuyển tiền!', 'en': 'You need at least 2 wallets to transfer money!'},
    'transfer_amount_error': {'vi': 'Vui lòng nhập số tiền chuyển hợp lệ!', 'en': 'Please enter a valid transfer amount!'},
    'insufficient_balance_error': {'vi': 'Số dư trong ví nguồn không đủ để thực hiện chuyển tiền!', 'en': 'Insufficient balance in source wallet!'},
    'same_wallet_error': {'vi': 'Ví nguồn và ví đích không được trùng nhau!', 'en': 'Source and destination wallet cannot be the same!'},
    'transfer_success': {'vi': 'Chuyển tiền giữa các ví thành công!', 'en': 'Transfer successful!'},
    'confirm_transfer': {'vi': 'Xác nhận chuyển tiền', 'en': 'Confirm Transfer'},
    'delete_wallet_title': {'vi': 'Xóa ví tiền', 'en': 'Delete Wallet'},
    'delete_wallet_confirm': {'vi': 'Bạn có chắc chắn muốn xóa ví "{name}" không?', 'en': 'Are you sure you want to delete wallet "{name}"?'},

    // ══════════════════════════════════════════════════
    // Add / Edit Transaction Screen
    // ══════════════════════════════════════════════════
    'add_tx_title': {'vi': 'Thêm Giao Dịch', 'en': 'Add Transaction'},
    'edit_tx_title': {'vi': 'Chỉnh sửa giao dịch', 'en': 'Edit Transaction'},
    'tx_expense': {'vi': 'Khoản Chi', 'en': 'Expense'},
    'tx_income': {'vi': 'Khoản Thu', 'en': 'Income'},
    'fund_action': {'vi': 'Góp / Rút Quỹ', 'en': 'Fund Deposit / Withdraw'},
    'amount': {'vi': 'Số tiền', 'en': 'Amount'},
    'category': {'vi': 'Danh mục', 'en': 'Category'},
    'wallet': {'vi': 'Ví tiền', 'en': 'Wallet'},
    'date': {'vi': 'Ngày tháng', 'en': 'Date'},
    'note': {'vi': 'Ghi chú', 'en': 'Note'},
    'note_hint': {'vi': 'Ghi chú nội dung giao dịch...', 'en': 'Transaction note...'},
    'save_transaction': {'vi': 'Lưu giao dịch', 'en': 'Save Transaction'},
    'select_category_prompt': {'vi': 'Chọn danh mục', 'en': 'Select category'},
    'select_wallet_prompt': {'vi': 'Chọn ví thanh toán', 'en': 'Select wallet'},
    'receipt_photo': {'vi': 'Ảnh hóa đơn / chứng từ', 'en': 'Receipt / Bill Photo'},
    'take_photo': {'vi': 'Chụp ảnh ngay', 'en': 'Take Photo'},
    'choose_from_gallery': {'vi': 'Chọn từ thư viện ảnh', 'en': 'Choose from Gallery'},
    'discard_tx_title': {'vi': 'Hủy giao dịch?', 'en': 'Discard transaction?'},
    'discard_tx_content': {'vi': 'Nội dung bạn đang nhập chưa được lưu. Bạn có chắc muốn thoát?', 'en': 'Unsaved changes will be lost. Are you sure you want to exit?'},
    'keep_editing': {'vi': 'Tiếp tục nhập', 'en': 'Keep Editing'},
    'discard': {'vi': 'Thoát', 'en': 'Discard'},
    'add_income_success': {'vi': 'Đã thêm khoản thu thành công! 💰', 'en': 'Income added successfully! 💰'},
    'add_expense_success': {'vi': 'Đã thêm khoản chi thành công! ✨', 'en': 'Expense added successfully! ✨'},
    'form_reset_toast': {'vi': 'Đã làm mới thông tin giao dịch', 'en': 'Form cleared'},
    'top_expense_categories': {'vi': 'Danh mục chi phổ biến', 'en': 'Top Expense Categories'},
    'quick_suggestions_label': {'vi': 'Gợi ý nhanh:', 'en': 'Quick suggestions:'},
    'matching_suggestions_label': {'vi': 'Gợi ý số tiền phù hợp:', 'en': 'Suggested amounts:'},
    'syncing_in_progress': {'vi': 'Đang đồng bộ...', 'en': 'Syncing...'},
    'not_synced_tap': {'vi': 'Chưa đồng bộ (Chạm để đồng bộ)', 'en': 'Not synced (Tap to sync)'},
    'frequent_amount_auto': {'vi': 'Tự điền từ thói quen', 'en': 'Auto-filled from habit'},
    'habit_autofilled': {'vi': 'Tự động điền theo thói quen', 'en': 'Auto-filled from habit'},
    'top_income_categories': {'vi': 'Danh mục thu phổ biến', 'en': 'Top Income Categories'},

    // ══════════════════════════════════════════════════
    // All Transactions Screen
    // ══════════════════════════════════════════════════
    'all_tx_title': {'vi': 'Tất cả giao dịch', 'en': 'All Transactions'},
    'transaction_history': {'vi': 'Lịch sử giao dịch', 'en': 'Transaction History'},
    'net_cashflow': {'vi': 'Dòng tiền', 'en': 'Cash Flow'},
    'view_all': {'vi': 'Xem tất cả', 'en': 'View All'},
    'edit': {'vi': 'Chỉnh sửa', 'en': 'Edit'},
    'delete': {'vi': 'Xóa', 'en': 'Delete'},
    'confirm_delete': {'vi': 'Xác nhận xóa', 'en': 'Confirm Delete'},
    'apply_filter': {'vi': 'Áp dụng bộ lọc', 'en': 'Apply Filter'},
    'filter_transactions': {'vi': 'Bộ lọc giao dịch', 'en': 'Transaction Filter'},
    'transaction_time_range': {'vi': 'Khoảng thời gian giao dịch', 'en': 'Transaction Time Range'},
    'specific_date_range': {'vi': 'Tùy chọn khoảng ngày cụ thể...', 'en': 'Select specific date range...'},
    'search_tx_hint': {'vi': 'Tìm kiếm theo danh mục, ghi chú...', 'en': 'Search by category, note...'},
    'preset_month_to_date': {'vi': 'Đầu tháng đến nay', 'en': 'Month to Date'},
    'preset_today': {'vi': 'Hôm nay', 'en': 'Today'},
    'preset_last_7_days': {'vi': '7 ngày qua', 'en': 'Last 7 Days'},
    'preset_last_30_days': {'vi': '30 ngày qua', 'en': 'Last 30 Days'},
    'preset_this_month': {'vi': 'Tháng này', 'en': 'This Month'},
    'preset_last_month': {'vi': 'Tháng trước', 'en': 'Last Month'},
    'preset_this_year': {'vi': 'Năm nay', 'en': 'This Year'},
    'custom_range': {'vi': 'Tùy chọn ngày', 'en': 'Custom Range'},
    'filter_all': {'vi': 'Tất cả', 'en': 'All'},
    'filter_income': {'vi': 'Thu nhập', 'en': 'Income'},
    'filter_expense': {'vi': 'Chi tiêu', 'en': 'Expense'},
    'filter_transfers': {'vi': 'Chuyển tiền', 'en': 'Transfers'},
    'no_matching_tx': {'vi': 'Không tìm thấy giao dịch nào phù hợp', 'en': 'No matching transactions found'},
    'clear_filter': {'vi': 'Xóa lọc', 'en': 'Clear Filter'},
    'clear_date_filter': {'vi': 'Bỏ lọc ngày', 'en': 'Clear Date Filter'},
    'reset_filter': {'vi': 'Đặt lại', 'en': 'Reset'},
    'transaction_type': {'vi': 'Loại giao dịch', 'en': 'Transaction Type'},
    'time_range': {'vi': 'Khoảng thời gian', 'en': 'Date Range'},
    'view_results': {'vi': 'Xem kết quả', 'en': 'View Results'},

    // ══════════════════════════════════════════════════
    // Transaction Details Screen
    // ══════════════════════════════════════════════════
    'tx_details': {'vi': 'Chi tiết giao dịch', 'en': 'Transaction Details'},
    'synced_cloud': {'vi': 'Đã đồng bộ Cloud', 'en': 'Cloud Synced'},
    'local_offline': {'vi': 'Lưu trên máy (Offline)', 'en': 'Saved Locally (Offline)'},
    'sync_status': {'vi': 'Trạng thái đồng bộ', 'en': 'Sync Status'},
    'source_wallet': {'vi': 'Tiền lấy từ ví', 'en': 'Source Wallet'},
    'destination_wallet': {'vi': 'Tiền nhận vào ví', 'en': 'Destination Wallet'},
    'delete_tx_confirm': {'vi': 'Bạn có chắc muốn xóa giao dịch này không?', 'en': 'Are you sure you want to delete this transaction?'},

    // ══════════════════════════════════════════════════
    // Statistics Screen
    // ══════════════════════════════════════════════════
    'stats_title': {'vi': 'Thống kê', 'en': 'Statistics'},
    'stats_spending_overview': {'vi': 'Tổng quan chi tiêu', 'en': 'Spending Overview'},
    'stats_filter_today': {'vi': 'Hôm nay', 'en': 'Today'},
    'stats_filter_week': {'vi': 'Tuần', 'en': 'Week'},
    'stats_filter_month': {'vi': 'Tháng', 'en': 'Month'},
    'stats_filter_year': {'vi': 'Năm', 'en': 'Year'},
    'stats_no_data': {'vi': 'Chưa có dữ liệu giao dịch trong khoảng thời gian này', 'en': 'No transaction data in this period'},
    'category_breakdown': {'vi': 'Phân tích chi tiêu theo mục', 'en': 'Category Breakdown'},
    'spending_breakdown': {'vi': 'Danh sách chi tiêu', 'en': 'Expense Breakdown'},
    'income_breakdown': {'vi': 'Danh sách thu nhập', 'en': 'Income Breakdown'},
    'total_expense_label': {'vi': 'Tổng chi tiêu', 'en': 'Total Expense'},
    'total_income_label': {'vi': 'Tổng thu nhập', 'en': 'Total Income'},
    'net_flow': {'vi': 'Dòng tiền ròng', 'en': 'Net Cash Flow'},
    'no_tx_category': {'vi': 'Chưa có giao dịch nào trong danh mục này', 'en': 'No transactions in this category'},
    'this_week': {'vi': 'Tuần này', 'en': 'This Week'},
    'last_week': {'vi': 'Tuần trước', 'en': 'Last Week'},
    'by_week': {'vi': 'Theo tuần', 'en': 'By Week'},
    'month': {'vi': 'Tháng', 'en': 'Month'},
    'year': {'vi': 'Năm', 'en': 'Year'},
    'week': {'vi': 'Tuần', 'en': 'Week'},
    'highest': {'vi': 'Cao nhất', 'en': 'Highest'},
    'lowest': {'vi': 'Thấp nhất', 'en': 'Lowest'},
    'chart_trend': {'vi': 'Xu hướng', 'en': 'Trend'},
    'chart_distribution': {'vi': 'Phân bổ', 'en': 'Distribution'},
    'chart_income_expense': {'vi': 'Thu / Chi', 'en': 'Income / Expense'},
    'no_distribution_data': {'vi': 'Chưa có dữ liệu phân bổ trong kỳ này', 'en': 'No distribution data in this period'},
    'no_compare_data': {'vi': 'Chưa có dữ liệu so sánh Thu - Chi', 'en': 'No comparison data in this period'},
    'net_income_gap': {'vi': 'Chênh lệch thu chi', 'en': 'Net Difference'},
    'no_transactions_period': {'vi': 'Chưa có dữ liệu giao dịch trong kỳ này', 'en': 'No transactions in this period'},
    'select_month_stat': {'vi': 'Chọn tháng thống kê', 'en': 'Select Month'},
    'select_year_stat': {'vi': 'Chọn năm thống kê', 'en': 'Select Year'},
    'select_week_stat': {'vi': 'Chọn tuần thống kê', 'en': 'Select Week'},
    'not_yet': {'vi': 'Chưa tới', 'en': 'Future'},
    'health_excellent': {'vi': 'Rất tốt', 'en': 'Excellent'},
    'health_good': {'vi': 'Tốt', 'en': 'Good'},
    'health_fair': {'vi': 'Vừa đủ', 'en': 'Fair'},
    'health_warning': {'vi': 'Báo động', 'en': 'Warning'},

    // ══════════════════════════════════════════════════
    // Settings Screen
    // ══════════════════════════════════════════════════
    'settings_title': {'vi': 'Cài đặt', 'en': 'Settings'},
    'account_and_security': {'vi': 'TÀI KHOẢN & BẢO MẬT', 'en': 'ACCOUNT & SECURITY'},
    'application_settings': {'vi': 'ỨNG DỤNG', 'en': 'APPLICATION'},
    'support_and_others': {'vi': 'HỖ TRỢ & KHÁC', 'en': 'SUPPORT & OTHERS'},
    'appearance_dark_mode': {'vi': 'Giao diện & Chế độ tối', 'en': 'Appearance & Dark Mode'},
    'language_setting': {'vi': 'Ngôn ngữ', 'en': 'Language'},
    'biometric_security': {'vi': 'Bảo mật vân tay', 'en': 'Biometric Security'},
    'privacy_policy': {'vi': 'Chính sách riêng tư', 'en': 'Privacy Policy'},
    'message_center': {'vi': 'Hòm thư tin nhắn', 'en': 'Message Center'},
    'account_info': {'vi': 'Thông tin tài khoản', 'en': 'Account Info'},
    'login_and_security': {'vi': 'Đăng nhập và bảo mật', 'en': 'Login & Security'},
    'data_and_privacy': {'vi': 'Dữ liệu và riêng tư', 'en': 'Data & Privacy'},
    'about_app': {'vi': 'Về ứng dụng', 'en': 'About App'},
    'logout': {'vi': 'Đăng xuất', 'en': 'Log out'},
    'logout_confirm': {'vi': 'Bạn có chắc chắn muốn đăng xuất?', 'en': 'Are you sure you want to log out?'},

    // ══════════════════════════════════════════════════
    // Appearance Screen
    // ══════════════════════════════════════════════════
    'appearance_header': {'vi': 'Giao diện & Chế độ tối', 'en': 'Appearance & Dark Mode'},
    'preview_section': {'vi': 'XEM TRƯỚC GIAO DIỆN', 'en': 'LIVE PREVIEW'},
    'preview_sub': {'vi': 'Xem trước màu sắc & cỡ chữ theo thời gian thực', 'en': 'Preview colors & text scaling in real time'},
    'theme_mode_section': {'vi': 'CHẾ ĐỘ MÀU SẮC', 'en': 'COLOR THEME'},
    'theme_mode_sub': {'vi': 'Chọn tông màu phù hợp với môi trường sử dụng', 'en': 'Choose tone suitable for your environment'},
    'theme_light': {'vi': 'Sáng', 'en': 'Light'},
    'theme_light_sub': {'vi': 'Trang nhã', 'en': 'Elegant'},
    'theme_dark': {'vi': 'Tối', 'en': 'Dark'},
    'theme_dark_sub': {'vi': 'Dịu mắt', 'en': 'Eye-care'},
    'theme_system': {'vi': 'Tự động', 'en': 'Auto'},
    'theme_system_sub': {'vi': 'Hệ thống', 'en': 'System'},
    'font_scale_section': {'vi': 'KÍCH THƯỚC CHỮ HIỂN THỊ', 'en': 'TEXT DISPLAY SIZE'},
    'font_scale_sub': {'vi': 'Điều chỉnh tỷ lệ văn bản toàn bộ ứng dụng', 'en': 'Scale text factor across the entire app'},

    // ══════════════════════════════════════════════════
    // Language Screen
    // ══════════════════════════════════════════════════
    'choose_language': {'vi': 'CHỌN NGÔN NGỮ', 'en': 'CHOOSE LANGUAGE'},
    'vietnamese': {'vi': 'Tiếng Việt', 'en': 'Vietnamese'},
    'english': {'vi': 'English', 'en': 'English'},

    // ══════════════════════════════════════════════════
    // Profile Screen
    // ══════════════════════════════════════════════════
    'profile_title': {'vi': 'Hồ sơ', 'en': 'Profile'},
    'edit_profile': {'vi': 'Chỉnh sửa thông tin', 'en': 'Edit Profile'},
    'update_profile_success': {'vi': 'Cập nhật thông tin tài khoản thành công!', 'en': 'Profile updated successfully!'},
    'full_name': {'vi': 'Họ và tên', 'en': 'Full Name'},
    'phone_number': {'vi': 'Số điện thoại', 'en': 'Phone Number'},
    'gender': {'vi': 'Giới tính', 'en': 'Gender'},
    'male': {'vi': 'Nam', 'en': 'Male'},
    'female': {'vi': 'Nữ', 'en': 'Female'},
    'other': {'vi': 'Khác', 'en': 'Other'},
    'date_of_birth': {'vi': 'Ngày sinh', 'en': 'Date of Birth'},
    'currency': {'vi': 'Đơn vị tiền tệ', 'en': 'Currency'},

    // ══════════════════════════════════════════════════
    // Notification Screen
    // ══════════════════════════════════════════════════
    'notification_title': {'vi': 'Thông báo', 'en': 'Notifications'},
    'clear_all': {'vi': 'Xóa tất cả', 'en': 'Clear all'},
    'analyze_now': {'vi': '⚡ Phân tích ngay', 'en': '⚡ Analyze now'},
    'no_notifications': {'vi': 'Chưa có thông báo nào', 'en': 'No notifications yet'},

    // ══════════════════════════════════════════════════
    // Category Screen
    // ══════════════════════════════════════════════════
    'category_title': {'vi': 'Phân loại danh mục', 'en': 'Categories'},
    'tab_expense': {'vi': 'Chi tiêu', 'en': 'Expense'},
    'tab_income': {'vi': 'Thu nhập', 'en': 'Income'},
    'add_new_category': {'vi': 'Thêm mới', 'en': 'Add New'},
    'btn_create_category': {'vi': '+ Tạo danh mục', 'en': '+ Create Category'},
    'create_category_title': {'vi': 'Tạo danh mục mới', 'en': 'Create New Category'},
    'edit_category_title': {'vi': 'Chỉnh sửa danh mục', 'en': 'Edit Category'},
    'select_group': {'vi': 'Chọn nhóm phân loại', 'en': 'Select Group'},
    'category_name_hint': {'vi': 'Tên danh mục...', 'en': 'Category name...'},
    'select_icon': {'vi': 'Chọn biểu tượng', 'en': 'Select Icon'},
    'select_color': {'vi': 'Chọn màu sắc', 'en': 'Select Color'},
    'save_category': {'vi': 'Lưu danh mục', 'en': 'Save Category'},
    'delete_category': {'vi': 'Xóa danh mục', 'en': 'Delete Category'},
    'confirm_delete_category': {'vi': 'Bạn có chắc muốn xóa danh mục này không?', 'en': 'Are you sure you want to delete this category?'},
    'empty_category_name': {'vi': 'Vui lòng nhập tên danh mục!', 'en': 'Please enter a category name!'},
    'custom_badge': {'vi': 'Tùy tạo', 'en': 'Custom'},

    // ══════════════════════════════════════════════════
    // Budget & Goals Screen
    // ══════════════════════════════════════════════════
    'budget_title': {'vi': 'Ngân sách & Mục tiêu', 'en': 'Budget & Goals'},
    'tab_budget': {'vi': 'Ngân sách', 'en': 'Budget'},
    'tab_goals': {'vi': 'Mục tiêu', 'en': 'Goals'},
    'add_budget': {'vi': 'Thêm ngân sách', 'en': 'Add Budget'},
    'edit_budget': {'vi': 'Sửa ngân sách', 'en': 'Edit Budget'},
    'budget_spent': {'vi': 'Đã chi', 'en': 'Spent'},
    'budget_remaining': {'vi': 'Còn lại', 'en': 'Remaining'},
    'budget_exceeded': {'vi': 'Vượt ngân sách', 'en': 'Overbudget'},
    'add_goal': {'vi': 'Thêm mục tiêu', 'en': 'Add Goal'},
    'edit_goal': {'vi': 'Sửa mục tiêu', 'en': 'Edit Goal'},
    'goal_name': {'vi': 'Tên mục tiêu', 'en': 'Goal Name'},
    'target_amount': {'vi': 'Số tiền mục tiêu', 'en': 'Target Amount'},
    'saved_amount': {'vi': 'Đã tích lũy', 'en': 'Accumulated'},
    'target_date': {'vi': 'Hạn hoàn thành', 'en': 'Target Date'},

    // ══════════════════════════════════════════════════
    // Group Expense Feature
    // ══════════════════════════════════════════════════
    'group_expense_title': {'vi': 'Chi tiêu nhóm', 'en': 'Group Expense'},
    'group_list': {'vi': 'Danh sách nhóm', 'en': 'Group List'},
    'create_group': {'vi': 'Tạo nhóm mới', 'en': 'Create Group'},
    'group_name': {'vi': 'Tên nhóm', 'en': 'Group Name'},
    'group_members': {'vi': 'Thành viên', 'en': 'Members'},
    'shared_fund': {'vi': 'Quỹ chung', 'en': 'Shared Fund'},
    'split_bill': {'vi': 'Chia tiền', 'en': 'Split Bill'},
    'settle_debt': {'vi': 'Thanh toán nợ', 'en': 'Settle Debt'},

    // ══════════════════════════════════════════════════
    // Voice Input Screen & Daily Limits
    // ══════════════════════════════════════════════════
    'voice_input_title': {'vi': 'Ghi bằng giọng nói', 'en': 'Voice Input'},
    'voice_listening': {'vi': 'Đang lắng nghe bạn nói...', 'en': 'Listening to you...'},
    'voice_listening_ai': {'vi': 'Đang lắng nghe... Bấm mic khi nói xong', 'en': 'Listening... Tap mic when done speaking'},
    'voice_tap_to_speak': {'vi': 'Chạm vào mic để bắt đầu nói', 'en': 'Tap mic to start speaking'},
    'voice_suggestions_title': {'vi': 'CÂU NÓI MẪU NHANH', 'en': 'QUICK SUGGESTIONS'},
    'voice_hint_spending': {'vi': 'Ví dụ: "Ăn phở 45k", "Cà phê 30 ngàn"', 'en': 'E.g: "Coffee 30k", "Lunch 50k"'},
    'voice_hint_limit': {'vi': 'Hoặc đặt hạn mức: "Đặt hạn mức 200k"', 'en': 'Or set limit: "Set limit 200k"'},
    'voice_detected': {'vi': 'Đã nhận diện', 'en': 'Detected'},
    'voice_error_mic': {'vi': 'Không nhận diện được giọng nói. Vui lòng thử lại!', 'en': 'Could not recognize speech. Please try again!'},
    'retry_speak': {'vi': 'Nói lại', 'en': 'Retry'},
    'check_and_confirm': {'vi': 'Kiểm tra & Xác nhận', 'en': 'Review & Confirm'},
    'voice_ai_converting': {'vi': '✨ Đang chuyển giọng nói thành văn bản qua AI...', 'en': '✨ Transcribing speech via AI...'},
    'ai_processing': {'vi': '✨ Trợ lý đang xử lý...', 'en': '✨ Assistant is processing...'},
    'voice_initializing': {'vi': 'Đang khởi tạo nhận diện giọng nói...', 'en': 'Initializing voice recognition...'},
    'voice_settings': {'vi': 'Cài đặt giọng nói', 'en': 'Voice Settings'},
    'chat_ai': {'vi': 'Chat AI', 'en': 'AI Chat'},
    'daily_limit_title': {'vi': 'Hạn mức chi tiêu mỗi ngày', 'en': 'Daily Spending Limit'},
    'daily_limit_desc': {'vi': 'Cảnh báo tức thì nếu tổng chi tiêu trong ngày vượt quá mức này', 'en': 'Instant alert if daily spending exceeds this amount'},
    'daily_limit_enabled': {'vi': 'Bật cảnh báo hạn mức', 'en': 'Enable Limit Alert'},
    'daily_limit_amount': {'vi': 'Hạn mức mỗi ngày', 'en': 'Daily Limit Amount'},
    'daily_limit_set_voice': {'vi': 'Nói hạn mức', 'en': 'Voice Limit'},
    'daily_limit_warning_title': {'vi': '⚠️ CẢNH BÁO CHI TIÊU VƯỢT HẠN MỨC', 'en': '⚠️ DAILY SPENDING LIMIT EXCEEDED'},
    'daily_limit_warning_body': {'vi': 'Hôm nay bạn đã chi tiêu {spent}, vượt hạn mức {limit}!', 'en': 'You have spent {spent} today, exceeding limit {limit}!'},
    'daily_limit_saved': {'vi': 'Đã cập nhật hạn mức chi tiêu mỗi ngày!', 'en': 'Daily spending limit updated!'},

    // ══════════════════════════════════════════════════
    // AI Assistant & Feedback
    // ══════════════════════════════════════════════════
    'ai_assistant_title': {'vi': 'Trợ lý AI Gemini', 'en': 'Gemini AI Assistant'},
    'financial_health': {'vi': 'Sức khỏe tài chính', 'en': 'Financial Health'},
    'savings_rate': {'vi': 'Tỷ lệ tiết kiệm', 'en': 'Savings Rate'},
    'lang_switched_en': {'vi': 'Đã chuyển ngôn ngữ ứng dụng sang Tiếng Anh!', 'en': 'App language switched to English!'},
    'lang_switched_vi': {'vi': 'Đã chuyển ngôn ngữ ứng dụng sang Tiếng Việt!', 'en': 'App language switched to Vietnamese!'},

    // ══════════════════════════════════════════════════
    // Common Action & Feedback
    // ══════════════════════════════════════════════════
    'cancel': {'vi': 'Hủy', 'en': 'Cancel'},
    'save': {'vi': 'Lưu', 'en': 'Save'},
    'confirm': {'vi': 'Xác nhận', 'en': 'Confirm'},
    'close': {'vi': 'Đóng', 'en': 'Close'},
    'success': {'vi': 'Thành công', 'en': 'Success'},
    'error': {'vi': 'Lỗi', 'en': 'Error'},
    'loading': {'vi': 'Đang tải...', 'en': 'Loading...'},
    'offline_mode': {'vi': 'Chế độ ngoại tuyến', 'en': 'Offline Mode'},
    'done': {'vi': 'Xong', 'en': 'Done'},
    'search': {'vi': 'Tìm kiếm', 'en': 'Search'},
    'back': {'vi': 'Quay lại', 'en': 'Back'},
    'ok': {'vi': 'Đồng ý', 'en': 'OK'},
  };

  /// Bản đồ dịch tên danh mục toàn diện (hỗ trợ cả 2 chiều VI <-> EN)
  static const Map<String, String> _viToEnCategory = {
    // EXPENSES
    'Ăn uống': 'Food & Dining',
    'Sức khỏe': 'Healthcare',
    'Di chuyển': 'Transportation',
    'Gửi xe': 'Parking',
    'Tiền gửi xe': 'Parking',
    'Đỗ xe': 'Parking',
    'Học tập': 'Education',
    'Giải trí': 'Entertainment',
    'Du lịch': 'Travel',
    'Mua sắm': 'Shopping',
    'Tiền nhà': 'Rent & Housing',
    'Tiền điện': 'Utilities & Bills',
    'Hóa đơn': 'Bills & Utilities',
    'Điện thoại': 'Phone & Mobile',
    'Thể thao': 'Sports & Fitness',
    'Tiết kiệm': 'Savings',
    'Bảo hiểm': 'Insurance',
    'Quà tặng': 'Gifts',
    'Làm đẹp': 'Beauty & Spa',
    'Thú cưng': 'Pets',
    'Con cái': 'Children & Family',
    'Từ thiện': 'Donations & Charity',
    'Sửa chữa': 'Maintenance & Repairs',
    'Đồ công nghệ': 'Tech & Electronics',
    'Trả nợ': 'Debt Repayment',
    'Chi khác': 'Other Expense',
    'Nhóm Chi Tiêu': 'Expense Groups',

    // INCOMES
    'Tiền lương': 'Salary',
    'Lương': 'Salary',
    'Tiền thưởng': 'Bonus',
    'Kinh doanh': 'Business',
    'Đầu tư': 'Investment',
    'Tiền lãi': 'Interest & Profit',
    'Được cho/Tặng': 'Gifts Received',
    'Bán đồ': 'Selling Items',
    'Tiền thuê nhà': 'Rental Income',
    'Thu nợ': 'Debt Collection',
    'Làm thêm': 'Freelance & Side Job',
    'Trợ cấp': 'Allowance',
    'Hoàn tiền': 'Refunds',
    'Thu khác': 'Other Income',

    // TRANSFERS
    'Chuyển tiền': 'Transfer',
    'Nhận chuyển tiền': 'Received Transfer',
    'Chuyển ví': 'Wallet Transfer',

    // GROUPS
    'Thiết yếu': 'Essentials',
    'Phát triển': 'Growth',
    'Hưởng thụ': 'Lifestyle',
    'Khác': 'Others',
  };

  static final Map<String, String> _enToViCategory = {
    for (final entry in _viToEnCategory.entries) entry.value: entry.key,
  };

  /// Dịch tên danh mục linh hoạt theo locale hiện tại
  String tCategory(String name) {
    if (name.isEmpty) return name;
    if (_currentLanguage == 'vi') {
      return _enToViCategory[name] ?? name;
    } else {
      return _viToEnCategory[name] ?? name;
    }
  }

  /// Bản đồ dịch tên ví thông dụng (hỗ trợ cả 2 chiều VI <-> EN)
  static const Map<String, String> _viToEnWallet = {
    'Tiền mặt': 'Cash',
    'Tài khoản ngân hàng': 'Bank Account',
    'Ngân hàng': 'Bank',
    'Thẻ tín dụng': 'Credit Card',
    'Ví điện tử': 'E-Wallet',
    'Sổ tiết kiệm': 'Savings',
    'Heo đất': 'Piggy Bank',
    'Tiết kiệm': 'Savings',
    'Đầu tư': 'Investment',
    'Ví chính': 'Main Wallet',
    'Ví phụ': 'Secondary Wallet',
  };

  static final Map<String, String> _enToViWallet = {
    for (final entry in _viToEnWallet.entries) entry.value: entry.key,
  };

  /// Dịch tên ví linh hoạt theo locale hiện tại
  String tWallet(String name) {
    if (name.isEmpty) return name;
    if (_currentLanguage == 'vi') {
      return _enToViWallet[name] ?? name;
    } else {
      return _viToEnWallet[name] ?? name;
    }
  }
}

/// Extension cho BuildContext để truy cập t(), tCategory(), tWallet() với cơ chế tự động đăng ký reactive rebuild
extension LocalizationExtension on BuildContext {
  String tr(String key) => LanguageScope.of(this).t(key);
  String trCat(String categoryName) => LanguageScope.of(this).tCategory(categoryName);
  String trWallet(String walletName) => LanguageScope.of(this).tWallet(walletName);
  LanguageService get language => LanguageScope.of(this);
}
