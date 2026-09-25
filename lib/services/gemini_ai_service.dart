import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_config_service.dart';
import 'ai_action_handler.dart';
import 'ai_financial_context_service.dart';
import 'connectivity_service.dart';
import 'bank_sms_parser_service.dart';
import 'group_bill_split_service.dart';
import 'financial_advisor_service.dart';
import '../utils/category_utils.dart';

enum AiActionType {
  recordTransaction,
  changeTheme,
  changeLanguage,
  spendingReport,
  navigateScreen,
  securityRestricted,
  generalChat,
  financialAdvice,
  savingTips,
  bankSmsImport,
  splitBill,
  safeToSpend,
  monthEndForecast,
  latteFactor,
  savingsRoadmap,
  spendingQuery,
}

class AiTransactionItem {
  final String type; // 'expense' hoặc 'income'
  final String category;
  final int categoryIconCode;
  final double amount;
  final String description;
  final DateTime date;
  final String walletName;
  final String? photoPath;

  AiTransactionItem({
    required this.type,
    required this.category,
    required this.categoryIconCode,
    required this.amount,
    required this.description,
    required this.date,
    this.walletName = '',
    this.photoPath,
  });

  AiTransactionItem copyWith({
    String? type,
    String? category,
    int? categoryIconCode,
    double? amount,
    String? description,
    DateTime? date,
    String? walletName,
    String? photoPath,
  }) {
    return AiTransactionItem(
      type: type ?? this.type,
      category: category ?? this.category,
      categoryIconCode: categoryIconCode ?? this.categoryIconCode,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      walletName: walletName ?? this.walletName,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'category': category,
    'amount': amount,
    'description': description,
    'date': date.toIso8601String(),
    'walletName': walletName,
    if (photoPath != null) 'photoPath': photoPath,
  };
}

class AiParsedResult {
  final String aiReply;
  final List<AiTransactionItem> transactions;
  final AiActionType actionType;
  final String? themeMode; // 'dark', 'light', 'system'
  final String? language; // 'vi', 'en'
  final String? reportPeriod; // 'today', 'week', 'month', 'year'
  final String? navigationTarget; // Target screen ID
  final bool needsAmount;
  final String? securityMessage;
  final FinancialAdviceResult? financialAdvice;
  final BankSmsParseResult? bankSmsResult;
  final GroupBillSplitResult? splitBillResult;
  final SafeDailySpendResult? safeDailyResult;
  final MonthEndForecastResult? forecastResult;
  final LatteFactorResult? latteFactorResult;
  final SavingsRoadmapResult? savingsRoadmapResult;
  final PersonalSpendingQueryResult? spendingQueryResult;
  final bool isSuccess;
  final String? errorMessage;

  AiParsedResult({
    required this.aiReply,
    required this.transactions,
    this.actionType = AiActionType.recordTransaction,
    this.themeMode,
    this.language,
    this.reportPeriod,
    this.navigationTarget,
    this.needsAmount = false,
    this.securityMessage,
    this.financialAdvice,
    this.bankSmsResult,
    this.splitBillResult,
    this.safeDailyResult,
    this.forecastResult,
    this.latteFactorResult,
    this.savingsRoadmapResult,
    this.spendingQueryResult,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory AiParsedResult.error(String message) {
    return AiParsedResult(
      aiReply: message,
      transactions: [],
      isSuccess: false,
      errorMessage: message,
    );
  }
}

class GeminiAiService {
  static final GeminiAiService _instance = GeminiAiService._internal();
  factory GeminiAiService() => _instance;
  GeminiAiService._internal();

  final AiConfigService _configService = AiConfigService();
  http.Client? _customClient;
  http.Client get _client => _customClient ??= http.Client();

  static const String _primaryModel = 'gemini-2.0-flash';
  static const String _fallbackModel = 'gemini-1.5-flash';

  final List<Map<String, String>> _conversationHistory = [];
  List<Map<String, String>> get conversationHistory => List.unmodifiable(_conversationHistory);

  void addToHistory(String role, String text) {
    _conversationHistory.add({'role': role, 'text': text});
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  /// Kiểm tra kết nối tới Gemini API
  Future<bool> testConnection({String? customApiKey}) async {
    final key = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _configService.apiKey;
    if (key.isEmpty) return false;

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_primaryModel:generateContent?key=$key');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Ping'}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return true;

      // Thử fallback model nếu 404
      if (response.statusCode == 404) {
        final fallbackUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_fallbackModel:generateContent?key=$key');
        final fbRes = await _client.post(
          fallbackUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': 'Ping'}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 10));
        return fbRes.statusCode == 200;
      }
      return false;
    } catch (e) {
      debugPrint('Gemini testConnection error: $e');
      return false;
    }
  }

  /// Phân tích câu nói / văn bản tự nhiên thành tác vụ thông minh của Trợ lý Mono
  Future<AiParsedResult> parseNaturalLanguage(
    String prompt, {
    List<Map<String, String>>? conversationHistory,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return AiParsedResult.error('Vui lòng nhập nội dung.');
    }

    // 1. KIỂM TRA RANH GIỚI BẢO MẬT & QUYỀN RIÊNG TƯ
    final securityMsg = AiActionHandler().checkSecurityRestriction(trimmed);
    if (securityMsg != null) {
      return AiParsedResult(
        aiReply: securityMsg,
        transactions: [],
        actionType: AiActionType.securityRestricted,
        securityMessage: securityMsg,
      );
    }

    final lowerTrimmed = trimmed.toLowerCase();

    // 2. NHẬN DIỆN TIN NHẮN BIẾN ĐỘNG SỐ DƯ NGÂN HÀNG / VÍ ĐIỆN TỬ (SMS Parser)
    if (BankSmsParserService().isBankSmsOrNotification(trimmed)) {
      final parseRes = BankSmsParserService().parse(trimmed);
      if (parseRes != null) {
        return AiParsedResult(
          aiReply: 'Mono đã phát hiện tin nhắn biến động số dư từ **${parseRes.bankName}**. Bạn có muốn ghi nhận khoản này vào sổ không?',
          transactions: [],
          actionType: AiActionType.bankSmsImport,
          bankSmsResult: parseRes,
        );
      }
    }

    // 3. TÍNH TOÁN & CHIA TIỀN HÓA ĐƠN NHÓM THÔNG MINH (Group Bill Split)
    final isSplitQuery = (lowerTrimmed.contains('chia') || lowerTrimmed.contains('share') || lowerTrimmed.contains('campuchia')) &&
        (lowerTrimmed.contains('người') || lowerTrimmed.contains('cho') || lowerTrimmed.contains('đều') || lowerTrimmed.contains('bill') || lowerTrimmed.contains('tiền'));
    if (isSplitQuery && lowerTrimmed != 'chi tiêu nhóm' && lowerTrimmed != 'chia tiền') {
      final splitRes = GroupBillSplitService().parseAndSplit(trimmed);
      return AiParsedResult(
        aiReply: splitRes.shareSummaryText,
        transactions: [],
        actionType: AiActionType.splitBill,
        splitBillResult: splitRes,
      );
    }

    // 4. CẢNH BÁO NGÂN SÁCH: HẠN MỨC AN TOÀN ĐƯỢC TIÊU MỖI NGÀY (Safe to Spend)
    final isSafeSpendQuery = lowerTrimmed.contains('được tiêu bao nhiêu') ||
        lowerTrimmed.contains('mỗi ngày được tiêu') ||
        lowerTrimmed.contains('hạn mức ngày') ||
        lowerTrimmed.contains('tiêu an toàn') ||
        lowerTrimmed.contains('an toàn hôm nay') ||
        (lowerTrimmed.contains('hôm nay') && lowerTrimmed.contains('tiêu bao nhiêu') && !lowerTrimmed.contains('đã tiêu'));
    if (isSafeSpendQuery) {
      final safeRes = await FinancialAdvisorService().calculateSafeDailyBudget();
      return AiParsedResult(
        aiReply: safeRes.advice,
        transactions: [],
        actionType: AiActionType.safeToSpend,
        safeDailyResult: safeRes,
      );
    }

    // 5. DỰ BÁO TÀI CHÍNH CUỐI THÁNG & NGUY CƠ THÂM HỤT (Month-end Forecast)
    final isForecastQuery = lowerTrimmed.contains('dự báo') ||
        lowerTrimmed.contains('dự đoán') ||
        lowerTrimmed.contains('cuối tháng') ||
        lowerTrimmed.contains('âm tiền') ||
        lowerTrimmed.contains('thâm hụt') ||
        lowerTrimmed.contains('cháy túi');
    if (isForecastQuery) {
      final forecastRes = await FinancialAdvisorService().forecastMonthEndBalance();
      return AiParsedResult(
        aiReply: forecastRes.summary,
        transactions: [],
        actionType: AiActionType.monthEndForecast,
        forecastResult: forecastRes,
      );
    }

    // 6. TIÊU VẶT GÂY "THỦNG VÍ" (Latte Factor Analysis)
    final isLatteFactorQuery = lowerTrimmed.contains('thủng ví') ||
        lowerTrimmed.contains('tiêu vặt') ||
        lowerTrimmed.contains('lặt vặt') ||
        lowerTrimmed.contains('latte factor') ||
        lowerTrimmed.contains('tiêu lắt nhắt');
    if (isLatteFactorQuery) {
      final latteRes = await FinancialAdvisorService().analyzeLatteFactor();
      return AiParsedResult(
        aiReply: latteRes.advice,
        transactions: [],
        actionType: AiActionType.latteFactor,
        latteFactorResult: latteRes,
      );
    }

    // 7. LÊN LỘ TRÌNH TIẾT KIỆM THEO MỤC TIÊU CỤ THỂ (Savings Roadmap)
    final isRoadmapQuery = lowerTrimmed.contains('lộ trình tiết kiệm') ||
        lowerTrimmed.contains('tiết kiệm để mua') ||
        lowerTrimmed.contains('tiết kiệm mua') ||
        lowerTrimmed.contains('để dành mua') ||
        lowerTrimmed.contains('để dành tiền mua') ||
        lowerTrimmed.contains('mục tiêu mua') ||
        (lowerTrimmed.contains('tiết kiệm') && (lowerTrimmed.contains('triệu') || lowerTrimmed.contains('tr')));
    if (isRoadmapQuery && !lowerTrimmed.contains('tip') && !lowerTrimmed.contains('mẹo') && !lowerTrimmed.contains('cách')) {
      final amount = GroupBillSplitService().parseAndSplit(trimmed).totalAmount;
      String goalTitle = 'Mục tiêu tiết kiệm';
      final goalMatch = RegExp(r'(?:mua|tiết kiệm cho|để)\s+([^0-9.,]+)', caseSensitive: false).firstMatch(trimmed);
      if (goalMatch != null) {
        final raw = goalMatch.group(1)!.trim();
        if (raw.isNotEmpty && raw.length <= 30) {
          goalTitle = 'Mua ${raw[0].toUpperCase()}${raw.substring(1)}';
        }
      }
      final roadmapRes = await FinancialAdvisorService().generateSavingsRoadmap(
        goalTitle: goalTitle,
        targetAmount: amount > 0 ? amount : 15000000,
      );
      return AiParsedResult(
        aiReply: roadmapRes.planExplanation,
        transactions: [],
        actionType: AiActionType.savingsRoadmap,
        savingsRoadmapResult: roadmapRes,
      );
    }

    // 8. TRA CỨU CHI TIÊU CÁ NHÂN TRỰC TIẾP TỪ SQLITE (Personal Spending Query)
    final isSpendingQuery = (lowerTrimmed.contains('đã tiêu') || lowerTrimmed.contains('tiêu hết') || lowerTrimmed.contains('chi hết') || lowerTrimmed.contains('lớn nhất') || lowerTrimmed.contains('cao nhất')) &&
        (lowerTrimmed.contains('hôm nay') || lowerTrimmed.contains('hôm qua') || lowerTrimmed.contains('tuần') || lowerTrimmed.contains('tháng'));
    if (isSpendingQuery) {
      final queryRes = await FinancialAdvisorService().queryPersonalSpending(trimmed);
      return AiParsedResult(
        aiReply: queryRes.answerText,
        transactions: [],
        actionType: AiActionType.spendingQuery,
        spendingQueryResult: queryRes,
      );
    }

    // 9. NHẬN DIỆN LỆNH CỤC BỘ NHANH (Fast Intent Fallback - 0ms lag)
    final localAction = _matchLocalIntent(trimmed);
    if (localAction != null) {
      return localAction;
    }

    // 10. TRÍCH XUẤT NHANH GIAO DỊCH RÕ RÀNG (0ms Instant Latency)
    // Nếu người dùng nhập câu thu/chi rõ ràng (VD: "ăn bún bò 35k", "cà phê 30k ví momo", "được cộng 36đ ví mono")
    final fastTx = _fallbackExtractTransaction(trimmed);
    if (fastTx != null && (fastTx.needsAmount || (fastTx.transactions.isNotEmpty && fastTx.transactions.first.amount > 0))) {
      return fastTx;
    }

    // 11. KIỂM TRA NHANH YÊU CẦU TƯ VẤN TÀI CHÍNH / TIP TIẾT KIỆM KHI OFFLINE
    final isAdviceQuery = lowerTrimmed.contains('tiền còn lại') ||
        lowerTrimmed.contains('làm gì với số tiền') ||
        lowerTrimmed.contains('phân bổ tiền') ||
        lowerTrimmed.contains('tip tiết kiệm') ||
        lowerTrimmed.contains('mẹo tiết kiệm') ||
        lowerTrimmed.contains('cách tiết kiệm') ||
        lowerTrimmed.contains('hướng dẫn tiết kiệm');

    // 5. GỌI GEMINI AI NẾU CÓ CẤU HÌNH API KEY VÀ CÓ MẠNG INTERNET
    await _configService.init();
    final apiKey = _configService.apiKey;
    final bool isConnOnline = ConnectivityService().isOnline;

    if (!isConnOnline || apiKey.isEmpty) {
      if (isAdviceQuery) {
        final advice = await AiActionHandler().generateFinancialAdvice(specificQuery: trimmed);
        return AiParsedResult(
          aiReply: advice.summaryText,
          transactions: [],
          actionType: AiActionType.financialAdvice,
          financialAdvice: advice,
          navigationTarget: advice.targetNavigation,
        );
      }
      if (fastTx != null) {
        return fastTx;
      }
      // Câu hỏi về chi tiêu, tổng tiền, số dư khi ngoại tuyến
      if (lowerTrimmed.contains('báo cáo') ||
          lowerTrimmed.contains('tiêu bao nhiêu') ||
          lowerTrimmed.contains('hôm nay tiêu') ||
          lowerTrimmed.contains('tháng này tiêu') ||
          lowerTrimmed.contains('số dư') ||
          lowerTrimmed.contains('tổng chi')) {
        String period = 'today';
        if (lowerTrimmed.contains('tháng')) {
          period = 'month';
        } else if (lowerTrimmed.contains('tuần')) {
          period = 'week';
        } else if (lowerTrimmed.contains('năm')) {
          period = 'year';
        }
        final report = await AiActionHandler().generateSpendingReport(period);
        return AiParsedResult(
          aiReply: report.summaryText,
          transactions: [],
          actionType: AiActionType.spendingReport,
          reportPeriod: period,
        );
      }

      // Phản hồi thân thiện khi offline cho câu nói khác
      return AiParsedResult(
        aiReply: '⚡ **Trợ lý Mono đang hoạt động Ngoại tuyến**:\nBạn có thể:\n'
            '• Ghi chép thu chi (VD: *"Ăn bún bò 35k ví MoMo"*, *"Lương 15 triệu"*)\n'
            '• Xem báo cáo (VD: *"Báo cáo hôm nay"*, *"Tháng này tiêu bao nhiêu"*)\n'
            '• Đổi cài đặt (VD: *"Bật chế độ tối"*, *"Mở thống kê"*)\n'
            '• Lời khuyên (VD: *"Tip tiết kiệm"*, *"Số tiền còn lại nên làm gì"*)\n'
            'Kết nối Internet để mở rộng đầy đủ khả năng của Mono nhé! 😊',
        transactions: [],
        actionType: AiActionType.generalChat,
        isSuccess: true,
      );
    }

    // Bơm bức tranh tài chính thời gian thực của người dùng vào Prompt
    final financialContext = await AiFinancialContextService().buildFinancialContextPrompt();

    final systemInstruction = '''
Bạn là Trợ lý Mono - trợ lý tài chính thông minh, chu đáo và thân thiện cho ứng dụng Quản lý Thu Chi Mono.
Hôm nay là: ${DateTime.now().toString().split(' ')[0]} (Định dạng YYYY-MM-DD).

$financialContext

DANH MỤC CHI PHÍ HỢP LỆ:
"Ăn uống", "Sức khỏe", "Di chuyển", "Học tập", "Giải trí", "Du lịch", "Mua sắm", "Tiền nhà", "Tiền điện", "Điện thoại", "Thể thao", "Tiết kiệm", "Bảo hiểm", "Quà tặng", "Làm đẹp", "Thú cưng", "Con cái", "Từ thiện", "Sửa chữa", "Đồ công nghệ", "Trả nợ", "Chi khác".

DANH MỤC THU NHẬP HỢP LỆ:
"Tiền lương", "Lương", "Tiền thưởng", "Kinh doanh", "Đầu tư", "Tiền lãi", "Được cho/Tặng", "Bán đồ", "Tiền thuê nhà", "Thu nợ", "Làm thêm", "Trợ cấp", "Hoàn tiền", "Thu khác".

QUY TẮC NHẬN DIỆN QUAN TRỌNG:
1. THU NHẬP (income): Nếu câu có từ như "được nhận", "mới được nhận", "vừa được nhận", "nhận", "nhận được", "mới nhận", "được cộng", "mới được cộng", "vừa được cộng", "cộng thêm", "cộng vào", "cộng", "tiền về", "lương", "thưởng", "lãi", "hoàn tiền", "ai đó cho", "vào ví", hoặc CÓ DẤU CỘNG '+' như "+9880₫", "+50k", "+9880₫ và Ví MoMo"... BẮT BUỘC đặt type = "income" (Ví dụ: "+9880₫ và Ví MoMo" -> type = "income", category = "Thu khác" hoặc "Được cho/Tặng", walletName = "MoMo", amount = 9880; "mới được nhận 9 nghìn 8 trắm 8 mưới đồng vào ví momo" -> type = "income", category = "Thu khác", walletName = "MoMo", amount = 9880; "tài khoản momo mới được cộng 9880đ" -> type = "income", category = "Thu khác", walletName = "MoMo", amount = 9880).
2. QUY TẮC ĐẶC BIỆT VỀ VÍ TIỀN:
   - Khi câu có từ "tài khoản momo", "ví momo", "momo", "mono", "và ví momo", "vào ví momo" đi kèm hành động nhận tiền / cộng tiền / chi tiêu, ĐÂY LÀ TÊN VÍ (walletName = "MoMo"), TUYỆT ĐỐI KHÔNG được chuyển hướng sang màn hình "accountInfo" hay chat thông thường.
   - Tương tự "tài khoản ngân hàng", "ngân hàng" -> walletName = "Ngân hàng".
   - Chỉ khi người dùng nói rõ ràng mục đích xem hồ sơ cá nhân như "thông tin tài khoản", "hồ sơ của tôi", "xem profile" mới chuyển sang "accountInfo".
3. CHI PHÍ (expense): "ăn", "mua", "uống", "chi", "trả", "đi chợ", "nạp", hoặc có dấu trừ '-'... -> type = "expense".
4. ĐƠN VỊ TIỀN TỆ & DẤU PHÂN CÁCH HÀNG NGHÌN TIẾNG VIỆT:
   - Dấu chấm trong số tiền tiếng Việt như "9.880", "50.000", "1.500.000" là DẤU PHÂN CÁCH HÀNG NGHÌN, KHÔNG PHẢI SỐ THẬP PHÂN! "9.880đ" là 9880, KHÔNG PHẢI 9.88!
   - Ký hiệu "₫", "đ", "đồng", "vnd": giữ nguyên số (VD: "+9880₫" -> 9880, "9.880đ" -> 9880, "36đ" -> 36, "100 đồng" -> 100).
   - "k", "nghìn", "ngàn": nhân 1000 (VD: "35k" -> 35000, "100 nghìn" -> 100000).
   - "tr", "triệu", "củ": nhân 1000000 (VD: "1.5tr" -> 1500000, "2 triệu" -> 2000000).
5. KHI THIẾU SỐ TIỀN:
   - Nếu người dùng nhắc đến hoạt động và ví nhưng CHƯA NÓI SỐ TIỀN (Ví dụ: "mới đi ăn bún bò trả bằng ví momo"):
     + "amount": 0
     + "needs_amount": true
     + "reply": "Mình đã ghi nhận bạn ăn bún bò bằng ví MoMo. Bạn ăn hết bao nhiêu tiền để mình lưu vào sổ nhé?"
6. TƯ VẤN TÀI CHÍNH & PHÂN BỔ SỐ TIỀN CÒN LẠI (actionType = "financialAdvice"):
   - Khi người dùng hỏi: "Nên làm gì với số tiền còn lại?", "Gợi ý phân bổ số dư", "Có nên mua gì không?":
     + Hãy dựa vào số dư khả dụng thực tế ở trên để tư vấn chân thành, thông minh.
     + Đề xuất quy tắc 50/30/20 (50% Thiết yếu, 30% Linh hoạt, 20% Tiết kiệm/Quỹ khẩn cấp).
     + Khuyên trích tiền vào mục tiêu tiết kiệm mà người dùng đang có trong app.
     + reply: Trình bày súc tích, mạch lạc, dễ hiểu với các gạch đầu dòng rõ ràng và emoji sinh động.
7. TIP TIẾT KIỆM THÔNG MINH (actionType = "financialAdvice"):
   - Khi người dùng hỏi: "Tip tiết kiệm", "Mẹo tiết kiệm", "Làm sao để bớt tiêu xài?":
     + Nhìn vào danh mục người dùng chi tiêu nhiều nhất ở trên (ví dụ: Ăn uống hoặc Mua sắm) để đưa ra 2-3 tip thực tế (nấu ăn tại nhà, quy tắc chờ 48 giờ trước khi mua, đặt hạn mức danh mục).
8. BÁO CÁO CHI TIÊU (actionType = "spendingReport"):
   - Khi hỏi về tổng thu chi, so sánh chi tiêu, báo cáo: đặt actionType = "spendingReport", reportPeriod = "today" | "week" | "month" | "year", và reply phân tích chi tiết.
9. ĐIỀU KHIỂN TẤT CẢ CÁC TÍNH NĂNG ỨNG DỤNG (actionType = "navigateScreen"):
   - Thống kê: "statistics", Lịch: "calendar", Ví: "wallets", Nhóm: "groupExpense", Ngân sách & Mục tiêu: "budget", Danh mục: "category", Xuất báo cáo: "exportReport", Thư viện hóa đơn: "receiptGallery", Thông báo: "notifications", Cài đặt AI: "aiSettings", Giao diện: "appearance", Ngôn ngữ: "language", Tài khoản: "accountInfo", Giới thiệu: "aboutApp", Hỗ trợ: "support", Tất cả giao dịch: "allTransactions", Thêm giao dịch: "addTransaction".
   - Đổi theme: actionType = "changeTheme", themeMode = "dark" hoặc "light".
   - Đổi ngôn ngữ: actionType = "changeLanguage", language = "vi" hoặc "en".
10. TRÒ CHUYỆN ĐƠN GIẢN & CHIT-CHAT (actionType = "generalChat"):
    - Chào hỏi, hỏi thăm, khen ngợi, cảm ơn, tâm sự: Trả lời tự nhiên, ấm áp, lịch sự, thân thiện và súc tích bằng tiếng Việt.
11. BẢO MẬT & QUYỀN RIÊNG TƯ:
    - Các hành động nhạy cảm như đổi mật khẩu, xóa tài khoản, bật/tắt sinh trắc học vân tay, hay chuyển khoản tiền ngân hàng thực tế phải được từ chối an toàn và hướng dẫn người dùng tự thao tác thủ công.

BẮT BUỘC TRẢ VỀ CHỈ DUY NHẤT 1 ĐOẠN JSON HỢP LỆ THEO CẤU TRÚC:
{
  "actionType": "recordTransaction" | "financialAdvice" | "navigateScreen" | "changeTheme" | "changeLanguage" | "spendingReport" | "generalChat",
  "navigationTarget": "statistics" | "calendar" | "wallets" | "groupExpense" | "budget" | "category" | "exportReport" | "receiptGallery" | "notifications" | "aiSettings" | "appearance" | "language" | "accountInfo" | "aboutApp" | "support" | "allTransactions" | "addTransaction" | null,
  "themeMode": "dark" | "light" | null,
  "language": "vi" | "en" | null,
  "reportPeriod": "today" | "week" | "month" | "year" | null,
  "reply": "Câu trả lời thân thiện, phân tích rõ ràng từ Trợ lý Mono...",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense" | "income",
      "category": "Tên danh mục phù hợp",
      "amount": Số_tiền (0 nếu chưa rõ),
      "description": "Mô tả ngắn gọn",
      "date": "YYYY-MM-DD",
      "walletName": "Tên ví (MoMo, Tiền mặt...) hoặc rỗng nếu không nói"
    }
  ]
}
''';

    final List<Map<String, dynamic>> contents = [];

    // System instruction mở đầu
    contents.add({
      'role': 'user',
      'parts': [
        {'text': '$systemInstruction\n\nBắt đầu cuộc trò chuyện.'}
      ]
    });
    contents.add({
      'role': 'model',
      'parts': [
        {'text': '{"actionType": "generalChat", "reply": "Xin chào! Mình là Trợ lý Mono, sẵn sàng hỗ trợ bạn!"}'}
      ]
    });

    // Thêm các lượt hội thoại gần nhất (tối đa 6 lượt) để giữ ngữ cảnh
    final historyToUse = conversationHistory ?? _conversationHistory;
    if (historyToUse.isNotEmpty) {
      final recentTurns = historyToUse.length > 6
          ? historyToUse.sublist(historyToUse.length - 6)
          : historyToUse;
      for (var turn in recentTurns) {
        final role = turn['role'] == 'user' ? 'user' : 'model';
        final text = turn['text'] ?? '';
        if (text.isNotEmpty) {
          contents.add({
            'role': role,
            'parts': [{'text': text}]
          });
        }
      }
    }

    // Câu nói hiện tại của người dùng
    contents.add({
      'role': 'user',
      'parts': [
        {'text': trimmed}
      ]
    });

    final bodyPayload = {
      'contents': contents,
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 512,
      }
    };

    // Ngưỡng 300 - 700ms chuẩn vàng: Gemini 2.0 Flash qua HTTP Keep-Alive.
    // Ngưỡng > 2000ms: Tự động ngắt timeout tại 2200ms để không bị cảm giác đơ lag, fallback ngay về dữ liệu cục bộ.
    final result = await _sendRequest(bodyPayload, timeout: const Duration(milliseconds: 2200));

    // Nếu AI gặp timeout quá 2.2s, lỗi mạng, hoặc không trích xuất được giao dịch rõ ràng -> Graceful Degradation Fallback về SQLite cục bộ
    if (!result.isSuccess || (result.transactions.isEmpty && result.actionType == AiActionType.recordTransaction)) {
      final localTx = _fallbackExtractTransaction(trimmed);
      if (localTx != null) {
        return localTx;
      }
      if (isAdviceQuery) {
        final advice = await AiActionHandler().generateFinancialAdvice(specificQuery: trimmed);
        return AiParsedResult(
          aiReply: advice.summaryText,
          transactions: [],
          actionType: AiActionType.financialAdvice,
          financialAdvice: advice,
          navigationTarget: advice.targetNavigation,
        );
      }
      if (lowerTrimmed.contains('chi') || lowerTrimmed.contains('tiêu') || lowerTrimmed.contains('thu') || lowerTrimmed.contains('báo cáo') || lowerTrimmed.contains('bao nhiêu')) {
        final queryRes = await FinancialAdvisorService().queryPersonalSpending(trimmed);
        if (queryRes.answerText.isNotEmpty) {
          return AiParsedResult(
            aiReply: queryRes.answerText,
            transactions: [],
            actionType: AiActionType.spendingQuery,
            spendingQueryResult: queryRes,
          );
        }
        final report = await AiActionHandler().generateSpendingReport('today');
        return AiParsedResult(
          aiReply: report.summaryText,
          transactions: [],
          actionType: AiActionType.spendingReport,
        );
      }

      // Phản hồi thân thiện mượt mà ngay cả khi mạng chậm/timeout > 2.0s
      return AiParsedResult(
        aiReply: 'Mono đã ghi nhận yêu cầu của bạn! Hiện tại kết nối mạng đang phản hồi chậm, bạn có thể nhập lệnh chi tiêu trực tiếp (VD: "Ăn bún bò 35k ví MoMo") để Mono lưu tức thì nhé! ⚡',
        transactions: [],
        actionType: AiActionType.generalChat,
        isSuccess: true,
      );
    }
    return result;
  }

  /// Nhận diện lệnh nhanh cục bộ (Theme, Language, Spending Report, Navigation, Chit-Chat)
  AiParsedResult? _matchLocalIntent(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Chế độ tối / sáng
    if (lower.contains('chế độ tối') || lower.contains('giao diện tối') || lower.contains('dark mode') || lower.contains('bật nền đen') || lower == 'tối') {
      return AiParsedResult(
        aiReply: 'Đã chuyển sang giao diện tối cho bạn rồi nhé! 🌙',
        transactions: [],
        actionType: AiActionType.changeTheme,
        themeMode: 'dark',
      );
    }
    if (lower.contains('chế độ sáng') || lower.contains('giao diện sáng') || lower.contains('light mode') || lower.contains('bật nền sáng') || lower == 'sáng') {
      return AiParsedResult(
        aiReply: 'Đã chuyển sang giao diện sáng cho bạn rồi nhé! ☀️',
        transactions: [],
        actionType: AiActionType.changeTheme,
        themeMode: 'light',
      );
    }

    // 2. Ngôn ngữ
    if (lower.contains('tiếng anh') || lower.contains('english') || lower.contains('chuyển sang tiếng anh')) {
      return AiParsedResult(
        aiReply: 'App language has been switched to English! 🇺🇸',
        transactions: [],
        actionType: AiActionType.changeLanguage,
        language: 'en',
      );
    }
    if (lower.contains('tiếng việt') || lower.contains('vietnamese') || lower.contains('chuyển sang tiếng việt')) {
      return AiParsedResult(
        aiReply: 'Đã đổi ngôn ngữ ứng dụng sang Tiếng Việt! 🇻🇳',
        transactions: [],
        actionType: AiActionType.changeLanguage,
        language: 'vi',
      );
    }

    // 3. Báo cáo chi tiêu
    if (lower.contains('báo cáo') || lower.contains('tiêu bao nhiêu') || lower.contains('hôm nay tiêu') || lower.contains('tháng này tiêu')) {
      String period = 'today';
      if (lower.contains('tháng')) {
        period = 'month';
      } else if (lower.contains('tuần')) {
        period = 'week';
      } else if (lower.contains('năm')) {
        period = 'year';
      }
      return AiParsedResult(
        aiReply: 'Đang tổng hợp báo cáo chi tiêu cho bạn...',
        transactions: [],
        actionType: AiActionType.spendingReport,
        reportPeriod: period,
      );
    }

    // 4. ĐIỀU KHIỂN TẤT CẢ MÀN HÌNH & TÍNH NĂNG ỨNG DỤNG (0ms Fast Intent)
    // Thống kê & Biểu đồ
    if (lower.contains('mở thống kê') || lower.contains('xem thống kê') || lower.contains('biểu đồ') || lower == 'thống kê' || lower.contains('phân tích chi tiêu')) {
      return AiParsedResult(
        aiReply: 'Đang mở màn hình Thống kê chi tiêu cho bạn nhé! 📊',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'statistics',
      );
    }
    // Lịch theo dõi thu chi
    if (lower.contains('mở lịch') || lower.contains('xem lịch') || lower == 'lịch' || lower.contains('lịch thu chi') || lower.contains('chi tiêu theo ngày')) {
      return AiParsedResult(
        aiReply: 'Đang mở Lịch theo dõi thu chi cho bạn nhé! 📅',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'calendar',
      );
    }
    // Quản lý ví tiền
    if (lower.contains('mở ví') || lower.contains('quản lý ví') || lower.contains('danh sách ví') || lower.contains('xem ví') || lower == 'ví tiền') {
      return AiParsedResult(
        aiReply: 'Đang mở màn hình Quản lý ví tiền cho bạn! 👛',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'wallets',
      );
    }
    // Chi tiêu nhóm
    if (lower.contains('chi tiêu nhóm') || lower.contains('chia tiền') || lower.contains('quỹ nhóm') || lower.contains('mở nhóm') || lower == 'nhóm') {
      return AiParsedResult(
        aiReply: 'Đang mở tính năng Chi tiêu nhóm cho bạn nhé! 👥',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'groupExpense',
      );
    }
    // Tư vấn tài chính & Phân bổ 50/30/20 (0ms Fast Intent)
    if (lower.contains('tiền còn lại') ||
        lower.contains('làm gì với số tiền') ||
        lower.contains('phân bổ') ||
        lower.contains('50 30 20') ||
        lower.contains('50/30/20') ||
        lower.contains('tư vấn tài chính')) {
      return AiParsedResult(
        aiReply: 'Mono đã phân tích số dư hiện tại của bạn và đề xuất phân bổ thông minh theo quy tắc 50/30/20. Hãy xem thẻ tư vấn chi tiết bên dưới nhé! 💡',
        transactions: [],
        actionType: AiActionType.financialAdvice,
        navigationTarget: 'budget',
      );
    }

    // Mẹo tiết kiệm chi tiêu (Saving Tips) (0ms Fast Intent)
    if (lower.contains('tip tiết kiệm') ||
        lower.contains('mẹo tiết kiệm') ||
        lower.contains('mẹo cắt giảm') ||
        lower.contains('cách tiết kiệm') ||
        lower.contains('tiết kiệm hơn') ||
        lower.contains('bớt tiêu xài') ||
        lower.contains('làm sao để tiết kiệm') ||
        lower.contains('làm sao tiết kiệm') ||
        lower.contains('tiết kiệm hiệu quả') ||
        (lower.contains('tiết kiệm') && (lower.contains('hiệu quả') || lower.contains('làm sao') || lower.contains('mẹo') || lower.contains('tip')))) {
      return AiParsedResult(
        aiReply: 'Dưới đây là một số mẹo tiết kiệm chi tiêu thông minh dành riêng cho bạn: 💡\n'
            '• **Quy tắc 48 giờ**: Hãy chờ 48 tiếng trước các khoản mua sắm ngoài dự tính để tránh chi tiêu bốc đồng.\n'
            '• **Nấu ăn tại nhà**: Tự chuẩn bị bữa ăn 4-5 ngày/tuần có thể giúp bạn tiết kiệm tới 30-40% chi phí ăn uống.\n'
            '• **Hạn mức ngân sách**: Hãy đặt hạn mức chi tiêu cho danh mục bạn hay tiêu nhất ngay trong app.',
        transactions: [],
        actionType: AiActionType.savingTips,
        navigationTarget: 'budget',
      );
    }

    // Ngân sách & Hạn mức
    if (lower.contains('mở ngân sách') ||
        lower.contains('xem ngân sách') ||
        lower == 'ngân sách' ||
        lower == 'hạn mức' ||
        lower.contains('mục tiêu tiết kiệm') ||
        lower.contains('cài đặt ngân sách')) {
      return AiParsedResult(
        aiReply: 'Đang mở màn hình Ngân sách & Mục tiêu tài chính cho bạn! 🎯',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'budget',
      );
    }
    // Danh mục thu chi
    if (lower.contains('danh mục') || lower.contains('quản lý danh mục') || lower.contains('loại chi tiêu')) {
      return AiParsedResult(
        aiReply: 'Đang mở Danh mục thu chi cho bạn nhé! 🏷️',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'category',
      );
    }
    // Xuất báo cáo
    if (lower.contains('xuất báo cáo') || lower.contains('xuất excel') || lower.contains('tải excel') || lower.contains('xuất pdf') || lower.contains('tải báo cáo')) {
      return AiParsedResult(
        aiReply: 'Đang mở màn hình Xuất báo cáo (Excel/PDF) cho bạn! 📄',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'exportReport',
      );
    }
    // Thư viện hóa đơn
    if (lower.contains('hóa đơn') || lower.contains('biên lai') || lower.contains('kho ảnh hóa đơn') || lower.contains('thư viện hóa đơn')) {
      return AiParsedResult(
        aiReply: 'Đang mở Thư viện hóa đơn & biên lai cho bạn! 🧾',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'receiptGallery',
      );
    }
    // Thông báo
    if (lower.contains('thông báo') || lower.contains('tin nhắn thông báo') || lower.contains('hộp thư')) {
      return AiParsedResult(
        aiReply: 'Đang mở Thông báo của ứng dụng cho bạn! 🔔',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'notifications',
      );
    }
    // Cài đặt AI
    if (lower.contains('cài đặt ai') || lower.contains('cài đặt trợ lý') || lower.contains('tốc độ phản hồi') || lower.contains('cấu hình mono')) {
      return AiParsedResult(
        aiReply: 'Đang mở Cài đặt Trợ lý Mono cho bạn! 🤖',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'aiSettings',
      );
    }
    // Cài đặt giao diện
    if (lower.contains('cài đặt giao diện') || lower.contains('chủ đề ứng dụng') || lower.contains('màu sắc app')) {
      return AiParsedResult(
        aiReply: 'Đang mở Cài đặt Giao diện cho bạn! 🎨',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'appearance',
      );
    }
    // Cài đặt ngôn ngữ
    if (lower.contains('cài đặt ngôn ngữ') || lower.contains('chọn ngôn ngữ')) {
      return AiParsedResult(
        aiReply: 'Đang mở Cài đặt Ngôn ngữ cho bạn! 🌐',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'language',
      );
    }
    // Thông tin tài khoản
    if (lower.contains('thông tin tài khoản') || lower.contains('hồ sơ cá nhân') || lower.contains('trang cá nhân') || lower.contains('tài khoản của tôi')) {
      return AiParsedResult(
        aiReply: 'Đang mở Thông tin tài khoản cho bạn nhé! 👤',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'accountInfo',
      );
    }
    // Giới thiệu app
    if (lower.contains('về ứng dụng') || lower.contains('giới thiệu app') || lower.contains('thông tin ứng dụng') || lower.contains('phiên bản')) {
      return AiParsedResult(
        aiReply: 'Đang mở Giới thiệu ứng dụng Mono! ℹ️',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'aboutApp',
      );
    }
    // Hỗ trợ
    if (lower.contains('hỗ trợ') || lower.contains('trợ giúp') || lower.contains('support') || lower.contains('chăm sóc khách hàng')) {
      return AiParsedResult(
        aiReply: 'Đang mở Trung tâm Hỗ trợ & Trợ giúp cho bạn! 💬',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'support',
      );
    }
    // Tất cả giao dịch / Sổ thu chi
    if (lower.contains('tất cả giao dịch') || lower.contains('lịch sử giao dịch') || lower.contains('sổ giao dịch') || lower.contains('danh sách giao dịch') || lower.contains('lịch sử chi tiêu')) {
      return AiParsedResult(
        aiReply: 'Đang mở Lịch sử giao dịch cho bạn nhé! 📝',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'allTransactions',
      );
    }
    // Thêm giao dịch
    if (lower.contains('thêm giao dịch') || lower.contains('tạo giao dịch') || lower.contains('nhập giao dịch') || lower == 'nhập chi tiêu') {
      return AiParsedResult(
        aiReply: 'Đang mở màn hình Thêm giao dịch cho bạn! ➕',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'addTransaction',
      );
    }

    // 5. TRÒ CHUYỆN ĐƠN GIẢN & CHIT-CHAT (0ms Fast Response)
    // Lời chào
    if (lower == 'chào' || lower == 'alo' || lower == 'hello' || lower == 'hi' || lower == 'hi mono' || lower == 'chào mono' || lower == 'chào bạn' || lower.startsWith('chào buổi sáng') || lower.startsWith('chào buổi tối')) {
      return AiParsedResult(
        aiReply: 'Chào bạn! Mình là Trợ lý Mono 🤖. Hôm nay bạn thế nào? Mình luôn sẵn sàng hỗ trợ bạn ghi chép thu chi và quản lý chi tiêu nhé!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }
    // Hỏi thăm
    if (lower.contains('bạn khỏe không') || lower.contains('khỏe không') || lower == 'thế nào rồi' || lower.contains('hôm nay thế nào')) {
      return AiParsedResult(
        aiReply: 'Mình luôn khỏe mạnh và tràn đầy năng lượng để đồng hành cùng bạn! Hôm nay tình hình chi tiêu của bạn có khoản gì cần ghi nhận không? 😊',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }
    // Bạn là ai / Giới thiệu
    if (lower.contains('bạn là ai') || lower.contains('bạn tên gì') || lower.contains('mono là ai') || lower.contains('giới thiệu bản thân')) {
      return AiParsedResult(
        aiReply: 'Mình là Mono - Trợ lý tài chính cá nhân thông minh của bạn! 🤖\nMình có thể giúp bạn:\n• 🎙️ Ghi nhận thu/chi bằng giọng nói\n• 📱 Mở tất cả các màn hình trong app\n• 📊 Xem báo cáo tài chính nhanh\n• 📷 Quét biên lai tự động\n• 💬 Trò chuyện & đưa ra lời khuyên tiết kiệm!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }
    // Cảm ơn
    if (lower.contains('cảm ơn') || lower.contains('thank you') || lower.contains('thanks') || lower.contains('mono giỏi quá')) {
      return AiParsedResult(
        aiReply: 'Không có chi nè! Được hỗ trợ bạn là niềm vui của Mono. Chúc bạn một ngày tài chính dồi dào và nhiều may mắn nhé! ✨💖',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }
    // Lời khen
    if (lower.contains('bạn thông minh') || lower.contains('tuyệt vời') || lower.contains('dễ thương') || lower.contains('mono xịn')) {
      return AiParsedResult(
        aiReply: 'Cảm ơn lời khen của bạn rất nhiều nha! 🥰 Mono sẽ luôn nỗ lực học hỏi để phục vụ bạn ngày càng tốt hơn nữa!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }
    // Tạm biệt
    if (lower == 'tạm biệt' || lower == 'bye' || lower == 'bye bye' || lower.contains('hẹn gặp lại') || lower.contains('tạm biệt mono')) {
      return AiParsedResult(
        aiReply: 'Tạm biệt bạn nhé! Hẹn gặp lại bạn bất cứ khi nào bạn cần ghi chép thu chi. Chúc bạn một ngày thật vui vẻ và bình an! 👋✨',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    return null;
  }

  /// Giải mã số tiền đọc bằng chữ hoặc hỗn hợp số + chữ tiếng Việt (VD: "9 nghìn 8 trắm 8 mưới", "9 nghìn 8 trăm 80")
  static double parseVietnameseWordNumber(String text) {
    String normalized = text.toLowerCase()
        .replaceAll('trắm', 'trăm')
        .replaceAll('mưới', 'mươi')
        .replaceAll('ngàn', 'nghìn')
        .replaceAll('chục', 'mươi')
        .replaceAll('đồng', ' ')
        .replaceAll('vnd', ' ')
        .replaceAll('đ', ' ');

    final Map<String, int> wordDigits = {
      'không': 0, 'một': 1, 'mốt': 1, 'hai': 2, 'ba': 3, 'bốn': 4, 'tư': 4,
      'năm': 5, 'lăm': 5, 'nhăm': 5, 'sáu': 6, 'bảy': 7, 'tám': 8, 'chín': 9,
    };

    final tokens = normalized.split(RegExp(r'\s+'));

    double grandTotal = 0;
    double currentHundreds = 0;
    double currentTens = 0;
    double currentUnit = 0;
    bool hasAnyNumber = false;

    for (int i = 0; i < tokens.length; i++) {
      String t = tokens[i];
      if (t.isEmpty) continue;

      if (RegExp(r'^\d+(k|tr)$').hasMatch(t)) {
        hasAnyNumber = true;
        if (t.endsWith('k')) {
          final v = double.tryParse(t.replaceAll('k', '')) ?? 0;
          grandTotal += v * 1000;
        } else if (t.endsWith('tr')) {
          final v = double.tryParse(t.replaceAll('tr', '')) ?? 0;
          grandTotal += v * 1000000;
        }
        continue;
      }

      final numVal = int.tryParse(t);
      if (numVal != null) {
        hasAnyNumber = true;
        if (numVal >= 1000) {
          grandTotal += numVal;
        } else if (numVal >= 100) {
          currentHundreds += numVal;
        } else if (numVal >= 10) {
          currentTens += numVal;
        } else {
          currentUnit = numVal.toDouble();
        }
        continue;
      }

      if (wordDigits.containsKey(t)) {
        currentUnit = wordDigits[t]!.toDouble();
        hasAnyNumber = true;
      } else if (t == 'mười') {
        hasAnyNumber = true;
        currentTens = 10;
        currentUnit = 0;
      } else if (t == 'mươi') {
        hasAnyNumber = true;
        currentTens = (currentUnit == 0 ? 1 : currentUnit) * 10;
        currentUnit = 0;
      } else if (t == 'trăm') {
        hasAnyNumber = true;
        currentHundreds = (currentUnit == 0 ? 1 : currentUnit) * 100;
        currentUnit = 0;
      } else if (t == 'nghìn') {
        hasAnyNumber = true;
        final groupVal = currentHundreds + currentTens + currentUnit;
        grandTotal += (groupVal == 0 ? 1 : groupVal) * 1000;
        currentHundreds = 0;
        currentTens = 0;
        currentUnit = 0;
      } else if (t == 'triệu' || t == 'tr' || t == 'củ') {
        hasAnyNumber = true;
        final groupVal = currentHundreds + currentTens + currentUnit;
        grandTotal += (groupVal == 0 ? 1 : groupVal) * 1000000;
        currentHundreds = 0;
        currentTens = 0;
        currentUnit = 0;
      } else if (t == 'tỷ' || t == 'ti') {
        hasAnyNumber = true;
        final groupVal = currentHundreds + currentTens + currentUnit;
        grandTotal += (groupVal == 0 ? 1 : groupVal) * 1000000000;
        currentHundreds = 0;
        currentTens = 0;
        currentUnit = 0;
      } else if (t == 'rưỡi') {
        if (i > 0) {
          final prev = tokens[i - 1];
          if (prev == 'triệu' || prev == 'tr' || prev == 'củ') {
            grandTotal += 500000;
          } else if (prev == 'nghìn') {
            grandTotal += 500;
          } else if (prev == 'trăm') {
            currentTens += 50;
          }
        }
      }
    }

    grandTotal += (currentHundreds + currentTens + currentUnit);
    return (hasAnyNumber && grandTotal > 0) ? grandTotal : 0.0;
  }

  /// Trích xuất giao dịch dự phòng cục bộ khi offline hoặc khi câu nói có định dạng quen thuộc
  AiParsedResult? _fallbackExtractTransaction(String text) {
    // Chuẩn hóa ký hiệu tiền tệ & biến thể STT
    final normalizedText = text
        .replaceAll('₫', 'đ')
        .replaceAll('và ví', 'vào ví')
        .replaceAll('và Ví', 'vào ví');
    final lower = normalizedText.toLowerCase();

    // Nhận diện kiểu thu nhập hay chi phí
    // Chú ý: Dấu cộng '+' ở đầu hoặc đi kèm số (ví dụ Google STT tự format: "+9880₫ và Ví MoMo", "+50k") là THU NHẬP
    final bool hasPlusSign = lower.contains('+') || RegExp(r'\+\s*\d+').hasMatch(text);
    final bool hasMinusSign = lower.contains('-') || RegExp(r'-\s*\d+').hasMatch(text);

    bool isIncome = hasPlusSign ||
        lower.contains('được nhận') ||
        lower.contains('mới được nhận') ||
        lower.contains('vừa được nhận') ||
        lower.contains('nhận được') ||
        lower.contains('mới nhận') ||
        lower.contains('vừa nhận') ||
        lower.contains('nhận tiền') ||
        lower.contains('được cộng') ||
        lower.contains('mới được cộng') ||
        lower.contains('vừa được cộng') ||
        lower.contains('cộng thêm') ||
        lower.contains('cộng vào') ||
        lower.contains('cộng tiền') ||
        lower.contains('cộng') ||
        lower.contains('tiền về') ||
        lower.contains('lương') ||
        lower.contains('thưởng') ||
        lower.contains('hoàn tiền') ||
        lower.contains('được cho') ||
        lower.contains('mẹ cho') ||
        lower.contains('bố cho') ||
        lower.contains('vào ví');

    if (hasMinusSign && !hasPlusSign) {
      isIncome = false;
    }

    // Tìm ví
    String wallet = '';
    if (lower.contains('momo') || lower.contains('mono')) {
      wallet = 'MoMo';
    } else if (lower.contains('tiền mặt')) {
      wallet = 'Tiền mặt';
    } else if (lower.contains('zalopay')) {
      wallet = 'ZaloPay';
    } else if (lower.contains('ngân hàng') ||
        lower.contains('techcombank') ||
        lower.contains('vietcombank') ||
        lower.contains('mbbank') ||
        lower.contains('bidv') ||
        lower.contains('agribank') ||
        lower.contains('vpbank') ||
        lower.contains('tpbank') ||
        lower.contains('acb')) {
      wallet = 'Ngân hàng';
    }

    double amount = 0;
    bool hasAmount = false;

    // 1. Phân cách hàng nghìn kiểu Việt Nam: 9.880, 50.000, 1.500.000 (hỗ trợ cả +9.880, +50.000)
    final thousandsSepRegex = RegExp(r'(?:\+|-)?\s*(\d{1,3}(?:\.\d{3})+)\s*(đ|đồng|vnd)?\b', caseSensitive: false);
    final thousandsMatch = thousandsSepRegex.firstMatch(normalizedText);
    if (thousandsMatch != null) {
      final cleanStr = thousandsMatch.group(1)!.replaceAll('.', '');
      final val = double.tryParse(cleanStr);
      if (val != null && val > 0) {
        amount = val;
        hasAmount = true;
      }
    }

    // 2. Số thập phân đi kèm đơn vị scale: 1.5tr, 2.5k, 1,5 triệu (hỗ trợ cả +1.5tr)
    if (!hasAmount) {
      final scaleDecimalRegex = RegExp(r'(?:\+|-)?\s*(\d+[,\.]\d+)\s*(k|nghìn|ngàn|tr|triệu|củ)\b', caseSensitive: false);
      final scaleDecMatch = scaleDecimalRegex.firstMatch(normalizedText);
      if (scaleDecMatch != null) {
        final numStr = scaleDecMatch.group(1)!.replaceAll(',', '.');
        final unit = scaleDecMatch.group(2)!.toLowerCase();
        final val = double.tryParse(numStr);
        if (val != null && val > 0) {
          double scale = 1;
          if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') {
            scale = 1000;
          } else if (unit == 'tr' || unit == 'triệu' || unit == 'củ') {
            scale = 1000000;
          }
          amount = val * scale;
          hasAmount = true;
        }
      }
    }

    // 3. Số hỗn hợp / số chữ tiếng Việt: "9 nghìn 8 trắm 8 mưới", "9 nghìn 8 trăm 80", "chín nghìn tám trăm tám mươi"
    if (!hasAmount) {
      final compoundVal = parseVietnameseWordNumber(normalizedText);
      if (compoundVal > 0) {
        amount = compoundVal;
        hasAmount = true;
      }
    }

    // 4. Số kèm đơn vị quy đổi (k, nghìn, ngàn, tr, triệu, củ, ví dụ +50k, 35k)
    if (!hasAmount) {
      final scaleRegex = RegExp(r'(?:\+|-)?\s*(\d+(?:[\.,]\d+)?)\s*(k|nghìn|ngàn|tr|triệu|củ)\b', caseSensitive: false);
      final scaleMatch = scaleRegex.firstMatch(normalizedText);
      if (scaleMatch != null) {
        final numStr = scaleMatch.group(1)!.replaceAll(',', '.');
        final unit = scaleMatch.group(2)!.toLowerCase();
        final val = double.tryParse(numStr);
        if (val != null && val > 0) {
          double scale = 1;
          if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') {
            scale = 1000;
          } else if (unit == 'tr' || unit == 'triệu' || unit == 'củ') {
            scale = 1000000;
          }
          amount = val * scale;
          if (lower.contains('rưỡi')) {
            if (unit == 'tr' || unit == 'triệu' || unit == 'củ') {
              amount += 500000;
            } else if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') {
              amount += 500;
            }
          }
          hasAmount = true;
        }
      }
    }

    // 5. Số nguyên / số thông thường với đơn vị tiền tệ đ/đồng/vnd hoặc không có đơn vị (+9880đ, +9880)
    if (!hasAmount) {
      final plainNumRegex = RegExp(r'(?:\+|-)?\s*(\d+)\s*(đ|đồng|vnd)?\b', caseSensitive: false);
      final plainMatch = plainNumRegex.firstMatch(normalizedText);
      if (plainMatch != null) {
        final val = double.tryParse(plainMatch.group(1)!);
        if (val != null && val > 0) {
          amount = val;
          hasAmount = true;
        }
      }
    }

    // Xác định danh mục thông minh
    String category = isIncome ? 'Thu khác' : 'Ăn uống';
    if (isIncome) {
      if (lower.contains('hoàn tiền')) {
        category = 'Hoàn tiền';
      } else if (lower.contains('lương') || lower.contains('salary')) {
        category = 'Tiền lương';
      } else if (lower.contains('thưởng') || lower.contains('bonus')) {
        category = 'Tiền thưởng';
      } else if (lower.contains('lãi') || lower.contains('interest')) {
        category = 'Tiền lãi';
      } else if (lower.contains('bán đồ') || lower.contains('thanh lý')) {
        category = 'Bán đồ';
      } else if (hasPlusSign) {
        category = 'Thu khác';
      }
    } else {
      if (lower.contains('bún') || lower.contains('cà phê') || lower.contains('cafe') || lower.contains('ăn') ||
          lower.contains('phở') || lower.contains('cơm') || lower.contains('trà sữa') || lower.contains('phúc long') ||
          lower.contains('highlands') || lower.contains('kfc') || lower.contains('lotteria') || lower.contains('lẩu')) {
        category = 'Ăn uống';
      } else if (lower.contains('xăng') || lower.contains('xe') || lower.contains('grab') || lower.contains('xanh sm') ||
          lower.contains('be') || lower.contains('taxi') || lower.contains('gửi xe') || lower.contains('vé xe')) {
        category = 'Di chuyển';
      } else if (lower.contains('mua') || lower.contains('shopee') || lower.contains('lazada') || lower.contains('tiki') ||
          lower.contains('siêu thị') || lower.contains('winmart') || lower.contains('bách hóa xanh') || lower.contains('chợ')) {
        category = 'Mua sắm';
      } else if (lower.contains('thuốc') || lower.contains('khám') || lower.contains('bệnh viện') || lower.contains('pharmacity') || lower.contains('long châu')) {
        category = 'Sức khỏe';
      } else if (lower.contains('phim') || lower.contains('cgv') || lower.contains('netflix') || lower.contains('game') || lower.contains('karaoke')) {
        category = 'Giải trí';
      } else if (lower.contains('tiền phòng') || lower.contains('tiền trọ') || lower.contains('tiền nhà')) {
        category = 'Tiền nhà';
      } else if (lower.contains('tiền điện') || lower.contains('evn')) {
        category = 'Tiền điện';
      } else if (lower.contains('tiền mạng') || lower.contains('internet') || lower.contains('4g') || lower.contains('nạp điện thoại')) {
        category = 'Điện thoại';
      } else if (lower.contains('gym') || lower.contains('cầu lông') || lower.contains('đá bóng')) {
        category = 'Thể thao';
      } else if (lower.contains('cắt tóc') || lower.contains('spa') || lower.contains('mỹ phẩm')) {
        category = 'Làm đẹp';
      }
    }

    // Mô tả
    String description = text.trim();
    if (isIncome && (hasPlusSign || lower.contains('cộng') || lower.contains('nhận') || lower.contains('tiền về') || lower.contains('vào ví'))) {
      description = wallet.isNotEmpty ? 'Cộng tiền vào ví $wallet' : 'Cộng tiền vào ví';
    } else if (!isIncome && hasMinusSign) {
      description = wallet.isNotEmpty ? 'Trừ tiền từ ví $wallet' : 'Chi tiêu';
    }
    if (description.length > 50) {
      description = description.substring(0, 50);
    }

    final iconData = CategoryUtils.getCategoryIcon(category);

    if (!hasAmount) {
      // Trường hợp như: "mới đi ăn bún bò trả bằng ví momo"
      return AiParsedResult(
        aiReply: 'Mình đã ghi nhận bạn "$description"${wallet.isNotEmpty ? ' qua ví $wallet' : ''}. Bạn vui lòng cho mình biết số tiền để lưu vào sổ nhé! 👇',
        transactions: [
          AiTransactionItem(
            type: isIncome ? 'income' : 'expense',
            category: category,
            categoryIconCode: iconData.codePoint,
            amount: 0,
            description: description,
            date: DateTime.now(),
            walletName: wallet,
          )
        ],
        actionType: AiActionType.recordTransaction,
        needsAmount: true,
      );
    }

    final formattedStr = (amount % 1 == 0)
        ? amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')
        : amount.toString();

    final reply = isIncome
        ? 'Đã ghi nhận cộng thêm $formattedStrđ${wallet.isNotEmpty ? ' vào ví $wallet' : ''} cho bạn nhé! 💰'
        : 'Đã nhận diện: Chi tiêu $formattedStrđ cho "$description"${wallet.isNotEmpty ? ' qua ví $wallet' : ''}.';

    return AiParsedResult(
      aiReply: reply,
      transactions: [
        AiTransactionItem(
          type: isIncome ? 'income' : 'expense',
          category: category,
          categoryIconCode: iconData.codePoint,
          amount: amount,
          description: description,
          date: DateTime.now(),
          walletName: wallet,
        )
      ],
      actionType: AiActionType.recordTransaction,
      needsAmount: false,
    );
  }

  /// Nhận diện hóa đơn / biên lai từ hình ảnh (Multimodal Vision)
  Future<AiParsedResult> parseReceiptImage(Uint8List imageBytes, {String mimeType = 'image/jpeg'}) async {
    await _configService.init();
    final apiKey = _configService.apiKey;
    if (apiKey.isEmpty) {
      return AiParsedResult.error('Chưa có API Key Google AI Studio. Vui lòng cấu hình trong Cài đặt.');
    }

    final base64Image = base64Encode(imageBytes);

    final promptText = '''
Bạn là Trợ lý Mono - chuyên gia quét hóa đơn / biên lai thanh toán cho ứng dụng Quản lý Thu Chi Mono.
Hãy đọc kỹ hình ảnh hóa đơn/biên lai và trích xuất thông tin tài chính:
1. Tên cửa hàng / Đơn vị bán hàng.
2. Tổng số tiền thanh toán cuối cùng (Grand Total).
3. Ngày giờ thanh toán (nếu có).
4. Danh mục chi tiêu phù hợp nhất trong các danh mục: "Ăn uống", "Mua sắm", "Di chuyển", "Sức khỏe", "Giải trí", "Tiền điện", "Chi khác".

BẮT BUỘC TRẢ VỀ CHỈ DUY NHẤT 1 ĐOẠN JSON HỢP LỆ:
{
  "actionType": "recordTransaction",
  "reply": "Đã quét thành công hóa đơn từ [Tên cửa hàng]...",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense",
      "category": "Ăn uống / Mua sắm / ...",
      "amount": Tổng_tiền_thanh_toán_dưới_dạng_số,
      "description": "Tên cửa hàng hoặc danh sách món chính",
      "date": "YYYY-MM-DD",
      "walletName": ""
    }
  ]
}
''';

    final bodyPayload = {
      'contents': [
        {
          'parts': [
            {'text': promptText},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
      }
    };

    return _sendRequest(bodyPayload, timeout: const Duration(seconds: 15));
  }

  /// Gửi câu hỏi tư vấn tài chính thông minh
  Future<String> askFinancialAdvice(String userMessage, {String contextData = ''}) async {
    await _configService.init();
    final apiKey = _configService.apiKey;
    if (apiKey.isEmpty) {
      return 'Vui lòng cấu hình API Key Google AI Studio trong Cài đặt để sử dụng Trợ lý Mono.';
    }

    final prompt = '''
Bạn là Trợ lý tài chính thông minh của ứng dụng Mono.
Hãy đưa ra lời khuyên tài chính cá nhân súc tích, thực tế và tích cực dựa trên câu hỏi của người dùng.
Ngữ cảnh chi tiêu của người dùng:
$contextData

Người dùng hỏi: "$userMessage"
Trả lời ngắn gọn, có gạch đầu dòng rõ ràng:
''';

    final bodyPayload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
      }
    };

    try {
      final model = _configService.modelName.isNotEmpty ? _configService.modelName : _primaryModel;
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyPayload),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? 'Không có phản hồi từ Trợ lý Mono.';
          }
        }
      } else if (response.statusCode == 404 && model != _fallbackModel) {
        final fbUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_fallbackModel:generateContent?key=$apiKey');
        final fbResponse = await _client.post(
          fbUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(bodyPayload),
        ).timeout(const Duration(seconds: 25));
        if (fbResponse.statusCode == 200) {
          final data = jsonDecode(utf8.decode(fbResponse.bodyBytes));
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String? ?? 'Không có phản hồi từ Trợ lý Mono.';
            }
          }
        }
      }
      return 'Không thể kết nối đến Trợ lý Mono (Mã lỗi: ${response.statusCode}).';
    } catch (e) {
      return 'Lỗi khi gọi Trợ lý Mono: $e';
    }
  }

  /// Phiên âm giọng nói trực tiếp từ file âm thanh sang văn bản tiếng Việt bằng Gemini Multimodal Audio.
  /// Hỗ trợ cực tốt cho các thiết bị nội địa (Redmi/Xiaomi China ROM) không có Google Speech Services.
  Future<String?> transcribeAudio(Uint8List audioBytes, {String mimeType = 'audio/mp4'}) async {
    if (!ConnectivityService().isOnline) {
      debugPrint('GeminiAiService: Mất mạng, bỏ qua transcribeAudio');
      return null;
    }
    await _configService.init();
    final apiKey = _configService.apiKey;
    if (apiKey.isEmpty) {
      debugPrint('GeminiAiService: Không có API key cho transcribeAudio');
      return null;
    }

    final base64Audio = base64Encode(audioBytes);

    const promptText = '''
Bạn là chuyên gia chuyển âm thanh thành văn bản tiếng Việt cho ứng dụng quản lý tài chính Mono.
Nhiệm vụ: Hãy lắng nghe thật kỹ đoạn ghi âm giọng nói tiếng Việt và phiên âm chính xác từng từ mà người dùng đã nói.

Ngữ cảnh thường xuất hiện trong câu nói:
- Số tiền & đơn vị: "k", "nghìn", "ngàn", "triệu", "tr", "đồng", "đ", "lít", "củ", "xị", "chục", "lăm", "mười lăm", "hai mươi lăm" (Ví dụ: "Ăn bún bò 35k", "Đổ xăng 50 nghìn", "1 triệu rưỡi", "hai xị", "1 củ").
- Tên món ăn / chi tiêu: bún bò, phở, bánh mì, cà phê, trà sữa, cơm tấm, đổ xăng, gửi xe, tiền nhà, tiền điện, tiền nước, internet, siêu thị, đi chợ, mua sắm,...
- Tên ví / ngân hàng: MoMo, ZaloPay, Tiền mặt, Ngân hàng, MB, Vietcombank, Techcombank,...

Quy tắc bắt buộc:
1. CHỈ TRẢ VỀ DUY NHẤT nội dung văn bản tiếng Việt đã nói, giữ đúng ngữ điệu và dấu tiếng Việt.
2. Tuyệt đối KHÔNG thêm lời chào, không thêm giải thích, không dịch sang tiếng Anh, không thêm dấu ngoặc kép hay định dạng markdown.
3. Nếu âm thanh hoàn toàn im lặng hoặc chỉ có tiếng ồn không có tiếng người nói, hãy trả về chữ: [SILENCE]
''';

    final bodyPayload = {
      'contents': [
        {
          'parts': [
            {'text': promptText},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Audio,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
      }
    };

    try {
      String model = _configService.modelName.isNotEmpty ? _configService.modelName : _primaryModel;
      if (model.contains('3.6')) model = _primaryModel;
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyPayload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            String text = (parts[0]['text'] as String? ?? '').trim();
            if (text == '[SILENCE]' || text.isEmpty) return null;
            if (text.startsWith('"') && text.endsWith('"') && text.length > 2) {
              text = text.substring(1, text.length - 1).trim();
            }
            return text;
          }
        }
      } else if (response.statusCode == 404) {
        final fallbackUrl = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_fallbackModel:generateContent?key=$apiKey');
        final fbResponse = await _client.post(
          fallbackUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(bodyPayload),
        ).timeout(const Duration(seconds: 15));
        if (fbResponse.statusCode == 200) {
          final data = jsonDecode(utf8.decode(fbResponse.bodyBytes));
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              String text = (parts[0]['text'] as String? ?? '').trim();
              if (text == '[SILENCE]' || text.isEmpty) return null;
              if (text.startsWith('"') && text.endsWith('"') && text.length > 2) {
                text = text.substring(1, text.length - 1).trim();
              }
              return text;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('GeminiAiService: Lỗi transcribeAudio: $e');
    }
    return null;
  }


  /// Thực thi request và parse kết quả JSON
  Future<AiParsedResult> _sendRequest(
    Map<String, dynamic> bodyPayload, {
    Duration timeout = const Duration(milliseconds: 2200),
  }) async {
    final apiKey = _configService.apiKey;
    String model = _configService.modelName.isNotEmpty ? _configService.modelName : _primaryModel;
    if (model.contains('3.6')) model = _primaryModel;

    try {
      var url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      // Đặt timeout 2.2 giây (2200ms) để phản hồi siêu nhanh, phòng ngừa treo quá 2000ms gây cảm giác đơ/lỗi mạng
      var response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyPayload),
      ).timeout(timeout);

      // Thử fallback nếu model chính bị 404 hoặc 429 / 503
      if ((response.statusCode == 404 || response.statusCode == 429 || response.statusCode == 503) && model != _fallbackModel) {
        model = _fallbackModel;
        url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
        response = await _client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(bodyPayload),
        ).timeout(const Duration(milliseconds: 1800));
      }

      if (response.statusCode != 200) {
        final errBody = utf8.decode(response.bodyBytes);
        debugPrint('Gemini error response: $errBody');
        return AiParsedResult.error('Trợ lý Mono phản hồi lỗi (${response.statusCode}).');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return AiParsedResult.error('Không nhận được câu trả lời từ Trợ lý Mono.');
      }

      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return AiParsedResult.error('Nội dung phản hồi trống.');
      }

      final text = parts[0]['text'] as String? ?? '';
      return _parseJsonFromAiText(text);
    } catch (e) {
      debugPrint('GeminiAiService exception: $e');
      return AiParsedResult.error('Lỗi kết nối Trợ lý Mono: $e');
    }
  }

  /// Tách và trích xuất JSON từ chuỗi text của AI
  AiParsedResult _parseJsonFromAiText(String rawText) {
    try {
      String jsonStr = rawText.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      // Trích xuất khối JSON nằm giữa cặp ngoặc { ... } nếu AI có thêm văn bản trước/sau
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1).trim();
      }

      // Tự động làm sạch các lỗi JSON phổ biến do LLM sinh ra (trailing commas)
      jsonStr = jsonStr.replaceAll(RegExp(r',\s*}'), '}').replaceAll(RegExp(r',\s*]'), ']');

      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final reply = jsonMap['reply'] as String? ?? 'Đã nhận diện yêu cầu của bạn';
      final actionTypeStr = (jsonMap['actionType'] ?? 'recordTransaction').toString();
      final themeMode = jsonMap['themeMode'] as String?;
      final language = jsonMap['language'] as String?;
      final reportPeriod = jsonMap['reportPeriod'] as String?;
      final navigationTarget = jsonMap['navigationTarget'] as String?;
      final needsAmount = jsonMap['needs_amount'] == true;
      final txList = jsonMap['transactions'] as List? ?? [];

      AiActionType actionType = AiActionType.recordTransaction;
      if (actionTypeStr == 'changeTheme') {
        actionType = AiActionType.changeTheme;
      } else if (actionTypeStr == 'changeLanguage') {
        actionType = AiActionType.changeLanguage;
      } else if (actionTypeStr == 'spendingReport') {
        actionType = AiActionType.spendingReport;
      } else if (actionTypeStr == 'navigateScreen') {
        actionType = AiActionType.navigateScreen;
      } else if (actionTypeStr == 'financialAdvice' || actionTypeStr == 'savingTips') {
        actionType = AiActionType.financialAdvice;
      } else if (actionTypeStr == 'generalChat') {
        actionType = AiActionType.generalChat;
      }

      final List<AiTransactionItem> items = [];
      for (var item in txList) {
        if (item is Map<String, dynamic>) {
          final type = (item['type'] ?? 'expense').toString().toLowerCase();
          final category = (item['category'] ?? (type == 'income' ? 'Thu khác' : 'Chi khác')).toString();
          final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
          final description = (item['description'] ?? category).toString();

          DateTime date = DateTime.now();
          if (item['date'] != null) {
            try {
              date = DateTime.parse(item['date'].toString());
            } catch (_) {}
          }

          final walletName = (item['walletName'] ?? '').toString();
          final iconData = CategoryUtils.getCategoryIcon(category);

          items.add(AiTransactionItem(
            type: type == 'income' ? 'income' : 'expense',
            category: category,
            categoryIconCode: iconData.codePoint,
            amount: amount,
            description: description,
            date: date,
            walletName: walletName,
          ));
        }
      }

      return AiParsedResult(
        aiReply: reply,
        transactions: items,
        actionType: actionType,
        themeMode: themeMode,
        language: language,
        reportPeriod: reportPeriod,
        navigationTarget: navigationTarget,
        needsAmount: needsAmount || (items.isNotEmpty && items.any((tx) => tx.amount <= 0)),
        isSuccess: true,
      );
    } catch (e) {
      debugPrint('AI returned natural response (not JSON format): $e');
      final cleanText = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final isAdvice = cleanText.toLowerCase().contains('tiết kiệm') ||
          cleanText.toLowerCase().contains('phân bổ') ||
          cleanText.toLowerCase().contains('số dư') ||
          cleanText.toLowerCase().contains('50/30/20') ||
          cleanText.toLowerCase().contains('ngân sách');

      return AiParsedResult(
        aiReply: cleanText.isNotEmpty ? cleanText : 'Mono đã nhận diện yêu cầu của bạn rồi nhé! 😊',
        transactions: [],
        actionType: isAdvice ? AiActionType.financialAdvice : AiActionType.generalChat,
        isSuccess: true,
      );
    }
  }
}
