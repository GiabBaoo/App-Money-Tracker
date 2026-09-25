import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Translate a key to current language
  String t(String key) {
    final langMap = _translations[key];
    if (langMap == null) return key;
    return langMap[_currentLanguage] ?? langMap['vi'] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // Navigation
    'nav_home': {'vi': 'Trang chủ', 'en': 'Home'},
    'nav_stats': {'vi': 'Thống kê', 'en': 'Statistics'},
    'nav_wallets': {'vi': 'Ví tiền', 'en': 'Wallets'},
    'nav_profile': {'vi': 'Cài đặt', 'en': 'Settings'},

    // Home Screen
    'greeting_morning': {'vi': 'Chào buổi sáng', 'en': 'Good morning'},
    'greeting_afternoon': {'vi': 'Chào buổi chiều', 'en': 'Good afternoon'},
    'greeting_evening': {'vi': 'Chào buổi tối', 'en': 'Good evening'},
    'total_balance': {'vi': 'Tổng số dư', 'en': 'Total Balance'},
    'income': {'vi': 'Thu nhập', 'en': 'Income'},
    'expense': {'vi': 'Chi phí', 'en': 'Expense'},
    'tx_history': {'vi': 'Lịch sử giao dịch', 'en': 'Transaction History'},
    'see_all': {'vi': 'Xem tất cả', 'en': 'See all'},
    'gallery': {'vi': 'Thư viện ảnh', 'en': 'Gallery'},
    'no_tx_month': {'vi': 'Chưa có giao dịch trong tháng này', 'en': 'No transactions this month'},

    // Wallet Screen
    'wallets_title': {'vi': 'Ví tiền', 'en': 'Wallets'},
    'total_net_worth': {'vi': 'Tổng tài sản', 'en': 'Total Net Worth'},
    'transfer_money': {'vi': 'Chuyển tiền giữa các ví', 'en': 'Transfer Between Wallets'},
    'add_wallet': {'vi': 'Thêm ví mới', 'en': 'Add New Wallet'},
    'create_wallet': {'vi': 'Tạo ví mới', 'en': 'Create New Wallet'},
    'edit_wallet': {'vi': 'Chỉnh sửa ví', 'en': 'Edit Wallet'},
    'wallet_name': {'vi': 'Tên ví', 'en': 'Wallet Name'},
    'initial_balance': {'vi': 'Số dư ban đầu', 'en': 'Initial Balance'},
    'current_balance': {'vi': 'Số dư hiện tại', 'en': 'Current Balance'},
    'wallet_category': {'vi': 'Phân loại ví', 'en': 'Wallet Category'},
    'save_wallet': {'vi': 'Lưu ví', 'en': 'Save Wallet'},
    'confirm_delete_wallet': {'vi': 'Bạn có chắc chắn muốn xóa ví này không?', 'en': 'Are you sure you want to delete this wallet?'},
    'empty_wallets': {'vi': 'Chưa có ví tiền nào. Hãy bấm nút + để tạo ví đầu tiên!', 'en': 'No wallets yet. Tap + to create your first wallet!'},
    'wallet_cash': {'vi': 'Tiền mặt', 'en': 'Cash'},
    'wallet_bank': {'vi': 'Tài khoản ngân hàng', 'en': 'Bank Account'},
    'wallet_e_wallet': {'vi': 'Ví điện tử', 'en': 'E-Wallet'},
    'wallet_savings': {'vi': 'Sổ tiết kiệm', 'en': 'Savings'},
    'wallet_investment': {'vi': 'Đầu tư', 'en': 'Investment'},
    'wallet_other': {'vi': 'Khác', 'en': 'Other'},

    // Settings Screen
    'settings_title': {'vi': 'Cài đặt', 'en': 'Settings'},
    'appearance_dark_mode': {'vi': 'Giao diện & Chế độ tối', 'en': 'Appearance & Dark Mode'},
    'language_setting': {'vi': 'Ngôn ngữ', 'en': 'Language'},
    'biometric_security': {'vi': 'Bảo mật vân tay', 'en': 'Biometric Security'},
    'privacy_policy': {'vi': 'Chính sách riêng tư', 'en': 'Privacy Policy'},
    'message_center': {'vi': 'Hòm thư tin nhắn', 'en': 'Message Center'},
    'account_info': {'vi': 'Thông tin tài khoản', 'en': 'Account Info'},
    'login_and_security': {'vi': 'Đăng nhập và bảo mật', 'en': 'Login & Security'},
    'data_and_privacy': {'vi': 'Dữ liệu và riêng tư', 'en': 'Data & Privacy'},
    'logout': {'vi': 'Đăng xuất', 'en': 'Log out'},
    'logout_confirm': {'vi': 'Bạn có chắc chắn muốn đăng xuất?', 'en': 'Are you sure you want to log out?'},

    // Appearance Screen
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

    // Language Screen
    'choose_language': {'vi': 'CHỌN NGÔN NGỮ', 'en': 'CHOOSE LANGUAGE'},
    'vietnamese': {'vi': 'Tiếng Việt', 'en': 'Vietnamese'},
    'english': {'vi': 'English', 'en': 'English'},

    // Profile Screen
    'profile_title': {'vi': 'Hồ sơ', 'en': 'Profile'},

    // Notification Screen
    'notification_title': {'vi': 'Thông báo', 'en': 'Notifications'},
    'clear_all': {'vi': 'Xóa tất cả', 'en': 'Clear all'},
    'analyze_now': {'vi': '⚡ Phân tích ngay', 'en': '⚡ Analyze now'},
    'no_notifications': {'vi': 'Chưa có thông báo nào', 'en': 'No notifications yet'},

    // Categories
    'cat_food': {'vi': 'Ăn uống', 'en': 'Food & Dining'},
    'cat_health': {'vi': 'Sức khỏe', 'en': 'Healthcare'},
    'cat_transport': {'vi': 'Di chuyển', 'en': 'Transportation'},
    'cat_house': {'vi': 'Tiền nhà', 'en': 'Rent & Housing'},
    'cat_electricity': {'vi': 'Tiền điện', 'en': 'Utilities & Bills'},
    'cat_education': {'vi': 'Học tập', 'en': 'Education'},
    'cat_sports': {'vi': 'Thể thao', 'en': 'Sports & Fitness'},
    'cat_shopping': {'vi': 'Mua sắm', 'en': 'Shopping'},
    'cat_entertainment': {'vi': 'Giải trí', 'en': 'Entertainment'},
    'cat_travel': {'vi': 'Du lịch', 'en': 'Travel'},
    'cat_gifts': {'vi': 'Quà tặng', 'en': 'Gifts'},
    'cat_other_expense': {'vi': 'Chi khác', 'en': 'Other Expense'},
    'cat_expense_groups': {'vi': 'Nhóm Chi Tiêu', 'en': 'Expense Groups'},
    'cat_salary': {'vi': 'Tiền lương', 'en': 'Salary'},
    'cat_bonus': {'vi': 'Tiền thưởng', 'en': 'Bonus'},
    'cat_business': {'vi': 'Kinh doanh', 'en': 'Business'},
    'cat_received_gifts': {'vi': 'Được cho/Tặng', 'en': 'Gifts Received'},
    'cat_sell_goods': {'vi': 'Bán đồ', 'en': 'Selling Items'},
    'cat_other_income': {'vi': 'Thu khác', 'en': 'Other Income'},
    'cat_investment': {'vi': 'Đầu tư', 'en': 'Investment'},
    'cat_interest': {'vi': 'Tiền lãi', 'en': 'Interest & Profit'},

    // Category Groups
    'group_essentials': {'vi': 'Thiết yếu', 'en': 'Essentials'},
    'group_growth': {'vi': 'Phát triển', 'en': 'Growth'},
    'group_lifestyle': {'vi': 'Hưởng thụ', 'en': 'Lifestyle'},
    'group_others': {'vi': 'Khác', 'en': 'Others'},

    // Category Screen
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

    // Add Transaction Screen
    'add_tx_title': {'vi': 'Thêm giao dịch', 'en': 'Add Transaction'},
    'edit_tx_title': {'vi': 'Chỉnh sửa giao dịch', 'en': 'Edit Transaction'},
    'amount': {'vi': 'Số tiền', 'en': 'Amount'},
    'category': {'vi': 'Danh mục', 'en': 'Category'},
    'wallet': {'vi': 'Ví tiền', 'en': 'Wallet'},
    'date': {'vi': 'Ngày tháng', 'en': 'Date'},
    'note': {'vi': 'Ghi chú', 'en': 'Note'},
    'note_hint': {'vi': 'Nhập ghi chú...', 'en': 'Enter note...'},
    'save_transaction': {'vi': 'Lưu giao dịch', 'en': 'Save Transaction'},
    'select_category_prompt': {'vi': 'Chọn danh mục', 'en': 'Select category'},
    'select_wallet_prompt': {'vi': 'Chọn ví thanh toán', 'en': 'Select wallet'},

    // Features: Calendar, Budget, AI
    'calendar_title': {'vi': 'Lịch theo dõi thu chi', 'en': 'Calendar Tracking'},
    'budget_title': {'vi': 'Ngân sách & Mục tiêu', 'en': 'Budget & Goals'},
    'ai_assistant_title': {'vi': 'Trợ lý AI Gemini', 'en': 'Gemini AI Assistant'},
    'financial_health': {'vi': 'Sức khỏe tài chính', 'en': 'Financial Health'},
    'savings_rate': {'vi': 'Tỷ lệ tiết kiệm', 'en': 'Savings Rate'},

    // Voice Input Screen
    'voice_input_title': {'vi': 'Ghi bằng giọng nói', 'en': 'Voice Input'},
    'voice_listening': {'vi': 'Đang lắng nghe bạn nói...', 'en': 'Listening to you...'},
    'voice_tap_to_speak': {'vi': 'Chạm vào mic để bắt đầu nói', 'en': 'Tap mic to start speaking'},
    'voice_suggestions_title': {'vi': 'CÂU NÓI MẪU NHANH', 'en': 'QUICK SUGGESTIONS'},
    'voice_hint_spending': {'vi': 'Ví dụ: "Ăn phở 45k", "Cà phê 30 ngàn"', 'en': 'E.g: "Coffee 30k", "Lunch 50k"'},
    'voice_hint_limit': {'vi': 'Hoặc đặt hạn mức: "Đặt hạn mức 200k"', 'en': 'Or set limit: "Set limit 200k"'},
    'voice_detected': {'vi': 'Đã nhận diện', 'en': 'Detected'},
    'voice_error_mic': {'vi': 'Không nhận diện được giọng nói. Vui lòng thử lại!', 'en': 'Could not recognize speech. Please try again!'},

    // Daily Spending Limit & Warnings
    'daily_limit_title': {'vi': 'Hạn mức chi tiêu mỗi ngày', 'en': 'Daily Spending Limit'},
    'daily_limit_desc': {'vi': 'Cảnh báo tức thì nếu tổng chi tiêu trong ngày vượt quá mức này', 'en': 'Instant alert if daily spending exceeds this amount'},
    'daily_limit_enabled': {'vi': 'Bật cảnh báo hạn mức', 'en': 'Enable Limit Alert'},
    'daily_limit_amount': {'vi': 'Hạn mức mỗi ngày', 'en': 'Daily Limit Amount'},
    'daily_limit_set_voice': {'vi': 'Nói hạn mức', 'en': 'Voice Limit'},
    'daily_limit_warning_title': {'vi': '⚠️ CẢNH BÁO CHI TIÊU VƯỢT HẠN MỨC', 'en': '⚠️ DAILY SPENDING LIMIT EXCEEDED'},
    'daily_limit_warning_body': {'vi': 'Hôm nay bạn đã chi tiêu {spent}, vượt hạn mức {limit}!', 'en': 'You have spent {spent} today, exceeding limit {limit}!'},
    'daily_limit_saved': {'vi': 'Đã cập nhật hạn mức chi tiêu mỗi ngày!', 'en': 'Daily spending limit updated!'},

    // Statistics Screen
    'stats_title': {'vi': 'Thống kê', 'en': 'Statistics'},
    'stats_spending_overview': {'vi': 'Tổng quan chi tiêu', 'en': 'Spending Overview'},
    'stats_filter_today': {'vi': 'Hôm nay', 'en': 'Today'},
    'stats_filter_week': {'vi': 'Tuần', 'en': 'Week'},
    'stats_filter_month': {'vi': 'Tháng', 'en': 'Month'},
    'stats_filter_year': {'vi': 'Năm', 'en': 'Year'},
    'stats_no_data': {'vi': 'Chưa có dữ liệu giao dịch trong khoảng thời gian này', 'en': 'No transaction data in this period'},

    // Profile & Account
    'update_profile_success': {'vi': 'Cập nhật thông tin tài khoản thành công!', 'en': 'Profile updated successfully!'},
    'edit_profile': {'vi': 'Chỉnh sửa thông tin', 'en': 'Edit Profile'},
    'full_name': {'vi': 'Họ và tên', 'en': 'Full Name'},
    'phone_number': {'vi': 'Số điện thoại', 'en': 'Phone Number'},
    'gender': {'vi': 'Giới tính', 'en': 'Gender'},
    'male': {'vi': 'Nam', 'en': 'Male'},
    'female': {'vi': 'Nữ', 'en': 'Female'},
    'other': {'vi': 'Khác', 'en': 'Other'},
    'date_of_birth': {'vi': 'Ngày sinh', 'en': 'Date of Birth'},
    'currency': {'vi': 'Đơn vị tiền tệ', 'en': 'Currency'},

    // Common
    'cancel': {'vi': 'Hủy', 'en': 'Cancel'},
    'save': {'vi': 'Lưu', 'en': 'Save'},
    'confirm': {'vi': 'Xác nhận', 'en': 'Confirm'},
    'delete': {'vi': 'Xóa', 'en': 'Delete'},
    'close': {'vi': 'Đóng', 'en': 'Close'},
    'success': {'vi': 'Thành công', 'en': 'Success'},
    'error': {'vi': 'Lỗi', 'en': 'Error'},
    'loading': {'vi': 'Đang tải...', 'en': 'Loading...'},
    'offline_mode': {'vi': 'Chế độ ngoại tuyến', 'en': 'Offline Mode'},

    // Additional Keys for full app coverage
    'all_wallets': {'vi': 'Tất cả ví', 'en': 'All Wallets'},
    'see_all_wallets': {'vi': '✕ Xem tất cả ví', 'en': '✕ View all wallets'},
    'wallet_list': {'vi': 'Danh sách ví tiền', 'en': 'Wallet List'},
    'synced_cloud': {'vi': 'Đã đồng bộ Cloud', 'en': 'Cloud Synced'},
    'local_offline': {'vi': 'Lưu trên máy (Offline)', 'en': 'Saved Locally (Offline)'},
    'sync_status': {'vi': 'Trạng thái đồng bộ', 'en': 'Sync Status'},
    'source_wallet': {'vi': 'Tiền lấy từ ví', 'en': 'Source Wallet'},
    'destination_wallet': {'vi': 'Tiền nhận vào ví', 'en': 'Destination Wallet'},
    'tx_details': {'vi': 'Chi tiết giao dịch', 'en': 'Transaction Details'},
    'edit': {'vi': 'Chỉnh sửa', 'en': 'Edit'},
    'category_breakdown': {'vi': 'Phân tích chi tiêu theo mục', 'en': 'Category Breakdown'},
    'spending_breakdown': {'vi': 'Danh sách chi tiêu', 'en': 'Expense Breakdown'},
    'income_breakdown': {'vi': 'Danh sách thu nhập', 'en': 'Income Breakdown'},
    'total_expense_label': {'vi': 'Tổng chi tiêu', 'en': 'Total Expense'},
    'total_income_label': {'vi': 'Tổng thu nhập', 'en': 'Total Income'},
    'no_tx_category': {'vi': 'Chưa có giao dịch nào trong danh mục này', 'en': 'No transactions in this category'},
    'personal_net_worth': {'vi': 'TỔNG TÀI SẢN CÁ NHÂN', 'en': 'TOTAL NET WORTH'},
    'account_and_security': {'vi': 'TÀI KHOẢN & BẢO MẬT', 'en': 'ACCOUNT & SECURITY'},
    'application_settings': {'vi': 'ỨNG DỤNG', 'en': 'APPLICATION'},
    'support_and_others': {'vi': 'HỖ TRỢ & KHÁC', 'en': 'SUPPORT & OTHERS'},
    'about_app': {'vi': 'Về ứng dụng', 'en': 'About App'},
    'press_again_to_exit': {'vi': 'Nhấn lần nữa để thoát ứng dụng', 'en': 'Press back again to exit'},
    'filter_all': {'vi': 'Tất cả', 'en': 'All'},
    'filter_income': {'vi': 'Thu nhập', 'en': 'Income'},
    'filter_expense': {'vi': 'Chi tiêu', 'en': 'Expense'},
  };

  /// Dịch tên danh mục linh hoạt
  String tCategory(String name) {
    if (_currentLanguage == 'vi') return name;
    const catMap = {
      'Ăn uống': 'Food & Dining',
      'Sức khỏe': 'Healthcare',
      'Di chuyển': 'Transportation',
      'Tiền nhà': 'Rent & Housing',
      'Tiền điện': 'Utilities & Bills',
      'Học tập': 'Education',
      'Thể thao': 'Sports & Fitness',
      'Mua sắm': 'Shopping',
      'Giải trí': 'Entertainment',
      'Du lịch': 'Travel',
      'Quà tặng': 'Gifts',
      'Chi khác': 'Other Expense',
      'Nhóm Chi Tiêu': 'Expense Groups',
      'Tiền lương': 'Salary',
      'Lương': 'Salary',
      'Tiền thưởng': 'Bonus',
      'Kinh doanh': 'Business',
      'Được cho/Tặng': 'Gifts Received',
      'Bán đồ': 'Selling Items',
      'Thu khác': 'Other Income',
      'Đầu tư': 'Investment',
      'Tiền lãi': 'Interest & Profit',
      // Groups
      'Thiết yếu': 'Essentials',
      'Phát triển': 'Growth',
      'Hưởng thụ': 'Lifestyle',
      'Khác': 'Others',
    };
    return catMap[name] ?? name;
  }
}

/// Extension for fast and convenient context.tr('key') access with real-time reactive listening
extension LocalizationExtension on BuildContext {
  String tr(String key) {
    try {
      final langService = Provider.of<LanguageService>(this);
      return langService.t(key);
    } catch (_) {
      return LanguageService.instance.t(key);
    }
  }

  String trCat(String categoryName) {
    try {
      final langService = Provider.of<LanguageService>(this);
      return langService.tCategory(categoryName);
    } catch (_) {
      return LanguageService.instance.tCategory(categoryName);
    }
  }
}
