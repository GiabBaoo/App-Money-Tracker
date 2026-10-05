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
import 'smart_category_service.dart';
import '../utils/category_utils.dart';
import '../utils/currency_format_utils.dart';
import 'voice_service.dart';
import 'local_qwen_service.dart';
import '../data/repositories/wallet_repository.dart';

enum AiActionType {
  recordTransaction,
  transferMoney,
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
  spendingTrends,
  financialHealthScore,
  recurringTransactions,
}

class TransferMoneyData {
  final double amount;
  final String sourceWalletName;
  final String targetWalletName;
  final double fee;
  final String note;
  final String? sourceWalletId;
  final String? targetWalletId;

  TransferMoneyData({
    required this.amount,
    required this.sourceWalletName,
    required this.targetWalletName,
    this.fee = 0.0,
    this.note = '',
    this.sourceWalletId,
    this.targetWalletId,
  });

  TransferMoneyData copyWith({
    double? amount,
    String? sourceWalletName,
    String? targetWalletName,
    double? fee,
    String? note,
    String? sourceWalletId,
    String? targetWalletId,
  }) {
    return TransferMoneyData(
      amount: amount ?? this.amount,
      sourceWalletName: sourceWalletName ?? this.sourceWalletName,
      targetWalletName: targetWalletName ?? this.targetWalletName,
      fee: fee ?? this.fee,
      note: note ?? this.note,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      targetWalletId: targetWalletId ?? this.targetWalletId,
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'source_wallet': sourceWalletName,
    'target_wallet': targetWalletName,
    'fee': fee,
    'note': note,
    if (sourceWalletId != null) 'sourceWalletId': sourceWalletId,
    if (targetWalletId != null) 'targetWalletId': targetWalletId,
  };
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
  final SpendingTrendResult? spendingTrendResult;
  final FinancialHealthScoreResult? financialHealthScoreResult;
  final RecurringDetectionResult? recurringDetectionResult;
  final TransferMoneyData? transferData;
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
    this.spendingTrendResult,
    this.financialHealthScoreResult,
    this.recurringDetectionResult,
    this.transferData,
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

  static const String _primaryModel = 'gemini-3.6-flash';
  static const String _fallbackModel = 'gemini-flash-lite-latest';
  static String get primaryModel => _primaryModel;
  static String get fallbackModel => _fallbackModel;

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

  /// Kiểm tra kết nối tới Gemini API với cơ chế tự động chuyển model dự phòng
  Future<bool> testConnection({String? customApiKey}) async {
    final key = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _configService.apiKey;
    if (key.isEmpty) return false;

    final modelsToTry = [_primaryModel, _fallbackModel, 'gemini-3.8-flash'];

    for (final model in modelsToTry) {
      try {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
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
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          debugPrint('Gemini testConnection thành công với model: $model');
          return true;
        }

        debugPrint('Gemini testConnection thử $model thất bại (${response.statusCode}), chuyển model tiếp theo...');
      } catch (e) {
        debugPrint('Gemini testConnection exception với $model: $e');
      }
    }
    return false;
  }

  /// Phân tích câu nói / văn bản tự nhiên thành tác vụ thông minh của Trợ lý Mono
  Future<AiParsedResult> parseNaturalLanguage(
    String prompt, {
    List<Map<String, String>>? conversationHistory,
    AiTransactionItem? pendingTransaction,
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
    final isSalaryOrPersonalBudgetQuery = lowerTrimmed.contains('lương') ||
        lowerTrimmed.contains('nhận lương') ||
        lowerTrimmed.contains('tiền lương') ||
        lowerTrimmed.contains('thu nhập') ||
        lowerTrimmed.contains('hợp lý') ||
        lowerTrimmed.contains('phân bổ') ||
        lowerTrimmed.contains('quản lý') ||
        lowerTrimmed.contains('50/30/20') ||
        lowerTrimmed.contains('tiền còn lại');

    final isSplitQuery = !isSalaryOrPersonalBudgetQuery &&
        (lowerTrimmed.contains('chia bill') ||
         lowerTrimmed.contains('chia tiền ăn') ||
         lowerTrimmed.contains('chia campuchia') ||
         ((lowerTrimmed.contains('chia') || lowerTrimmed.contains('share')) &&
          (lowerTrimmed.contains('người') || lowerTrimmed.contains('đều') || lowerTrimmed.contains('bill'))));
    if (isSplitQuery && lowerTrimmed != 'chi tiêu nhóm' && lowerTrimmed != 'chia tiền') {
      final splitRes = GroupBillSplitService().parseAndSplit(trimmed);
      return AiParsedResult(
        aiReply: splitRes.shareSummaryText,
        transactions: [],
        actionType: AiActionType.splitBill,
        splitBillResult: splitRes,
      );
    }

    // 4. TÍNH TOÁN NGỮ CẢNH TÀI CHÍNH & THẺ THỐNG KÊ CHUYÊN SÂU
    SafeDailySpendResult? attachedSafeDaily;
    MonthEndForecastResult? attachedForecast;
    LatteFactorResult? attachedLatteFactor;
    SavingsRoadmapResult? attachedRoadmap;
    PersonalSpendingQueryResult? attachedSpendingQuery;
    SpendingTrendResult? attachedSpendingTrend;
    FinancialHealthScoreResult? attachedHealthScore;
    RecurringDetectionResult? attachedRecurring;

    final sbExtraContext = StringBuffer();

    try {
      if (lowerTrimmed.contains('được tiêu bao nhiêu') ||
          lowerTrimmed.contains('mỗi ngày được tiêu') ||
          lowerTrimmed.contains('hạn mức ngày') ||
          lowerTrimmed.contains('tiêu an toàn')) {
        attachedSafeDaily = await FinancialAdvisorService().calculateSafeDailyBudget();
        sbExtraContext.writeln('• Phân tích hạn mức chi an toàn hôm nay: ${attachedSafeDaily.advice}');
      } else if (lowerTrimmed.contains('dự báo') ||
          lowerTrimmed.contains('dự đoán') ||
          lowerTrimmed.contains('cuối tháng') ||
          lowerTrimmed.contains('thâm hụt') ||
          lowerTrimmed.contains('cháy túi')) {
        attachedForecast = await FinancialAdvisorService().forecastMonthEndBalance();
        sbExtraContext.writeln('• Phân tích dự báo tài chính cuối tháng: ${attachedForecast.summary}');
      } else if (lowerTrimmed.contains('thủng ví') ||
          lowerTrimmed.contains('tiêu vặt') ||
          lowerTrimmed.contains('lặt vặt') ||
          lowerTrimmed.contains('latte factor')) {
        attachedLatteFactor = await FinancialAdvisorService().analyzeLatteFactor();
        sbExtraContext.writeln('• Phân tích thói quen tiêu vặt thủng ví: ${attachedLatteFactor.advice}');
      } else if (lowerTrimmed.contains('lộ trình tiết kiệm') ||
          lowerTrimmed.contains('tiết kiệm để mua') ||
          lowerTrimmed.contains('để dành mua')) {
        final amount = GroupBillSplitService().parseAndSplit(trimmed).totalAmount;
        String goalTitle = 'Mục tiêu tiết kiệm';
        final goalMatch = RegExp(r'(?:mua|tiết kiệm cho|để)\s+([^0-9.,]+)', caseSensitive: false).firstMatch(trimmed);
        if (goalMatch != null) {
          final raw = goalMatch.group(1)!.trim();
          if (raw.isNotEmpty && raw.length <= 30) {
            goalTitle = 'Mua ${raw[0].toUpperCase()}${raw.substring(1)}';
          }
        }
        attachedRoadmap = await FinancialAdvisorService().generateSavingsRoadmap(
          goalTitle: goalTitle,
          targetAmount: amount > 0 ? amount : 15000000,
        );
        sbExtraContext.writeln('• Phân tích lộ trình tiết kiệm: ${attachedRoadmap.planExplanation}');
      } else if (lowerTrimmed.contains('xu hướng chi tiêu') ||
          lowerTrimmed.contains('xu hướng tiêu') ||
          lowerTrimmed.contains('chi tiêu bất thường') ||
          lowerTrimmed.contains('so sánh chi tiêu')) {
        attachedSpendingTrend = await FinancialAdvisorService().analyzeSpendingTrends(
          period: lowerTrimmed.contains('tháng') ? 'month' : 'week',
        );
        sbExtraContext.writeln('• Phân tích xu hướng chi tiêu: ${attachedSpendingTrend.advice}');
      } else if (lowerTrimmed.contains('điểm tài chính') ||
          lowerTrimmed.contains('sức khỏe tài chính') ||
          lowerTrimmed.contains('điểm sức khỏe')) {
        attachedHealthScore = await FinancialAdvisorService().calculateFinancialHealthScore();
        sbExtraContext.writeln('• Phân tích điểm sức khỏe tài chính: ${attachedHealthScore.summaryAdvice}');
      } else if (lowerTrimmed.contains('khoản định kỳ') ||
          lowerTrimmed.contains('chi phí cố định') ||
          lowerTrimmed.contains('chi tiêu định kỳ')) {
        attachedRecurring = await FinancialAdvisorService().detectRecurringTransactions();
        sbExtraContext.writeln('• Phân tích các khoản chi phí cố định: ${attachedRecurring.summary}');
      } else if (lowerTrimmed.contains('mức chi tiêu') ||
          lowerTrimmed.contains('đã tiêu') ||
          lowerTrimmed.contains('tiêu hết') ||
          lowerTrimmed.contains('chi hết') ||
          lowerTrimmed.contains('tiêu những gì') ||
          lowerTrimmed.contains('đã chi') ||
          (lowerTrimmed.contains('chi tiêu') && (lowerTrimmed.contains('nhiều nhất') || lowerTrimmed.contains('như thế nào') || lowerTrimmed.contains('bao nhiêu') || lowerTrimmed.contains('việc nào'))) ||
          lowerTrimmed.contains('việc nào nhiều nhất') ||
          lowerTrimmed.contains('cho cái gì nhiều nhất') ||
          lowerTrimmed.contains('chi nhiều nhất') ||
          lowerTrimmed.contains('khoản chi lớn nhất')) {
        attachedSpendingQuery = await FinancialAdvisorService().queryPersonalSpending(trimmed);
        sbExtraContext.writeln('• Tra cứu dữ liệu chi tiêu thực tế từ sổ: ${attachedSpendingQuery.answerText}');
      }
      if (isSalaryOrPersonalBudgetQuery) {
        final salaryAdvice = await AiActionHandler().generateFinancialAdvice(specificQuery: trimmed);
        sbExtraContext.writeln('• Kế hoạch phân bổ tài chính & tiền lương (50/30/20): ${salaryAdvice.summaryText}');
      }
    } catch (e) {
      debugPrint('GeminiAiService: Lỗi trích xuất ngữ cảnh bổ sung: $e');
    }

    // 5. KIỂM TRA CHẾ ĐỘ ENGINE: ƯU TIÊN MÔ HÌNH LOCAL QWEN 2.5 1.5B (ON-DEVICE)
    await _configService.init();
    if (_configService.isLocalAi) {
      final qwenRes = await LocalQwenService().queryLocalQwen(
        trimmed,
        conversationHistory: conversationHistory,
      );

      if (qwenRes != null && qwenRes.isSuccess) {
        final enrichedRes = AiParsedResult(
          aiReply: qwenRes.aiReply,
          transactions: qwenRes.transactions,
          actionType: qwenRes.actionType,
          themeMode: qwenRes.themeMode,
          language: qwenRes.language,
          reportPeriod: qwenRes.reportPeriod,
          navigationTarget: qwenRes.navigationTarget,
          needsAmount: qwenRes.needsAmount,
          securityMessage: qwenRes.securityMessage,
          financialAdvice: qwenRes.financialAdvice,
          bankSmsResult: qwenRes.bankSmsResult,
          splitBillResult: qwenRes.splitBillResult,
          safeDailyResult: attachedSafeDaily ?? qwenRes.safeDailyResult,
          forecastResult: attachedForecast ?? qwenRes.forecastResult,
          latteFactorResult: attachedLatteFactor ?? qwenRes.latteFactorResult,
          savingsRoadmapResult: attachedRoadmap ?? qwenRes.savingsRoadmapResult,
          spendingQueryResult: attachedSpendingQuery ?? qwenRes.spendingQueryResult,
          spendingTrendResult: attachedSpendingTrend ?? qwenRes.spendingTrendResult,
          financialHealthScoreResult: attachedHealthScore ?? qwenRes.financialHealthScoreResult,
          recurringDetectionResult: attachedRecurring ?? qwenRes.recurringDetectionResult,
        );

        final dateRes = _applySmartDateTimeGuardrail(enrichedRes, trimmed);
        final finalOutput = _applySmartSemanticGuardrail(dateRes, trimmed);
        addToHistory('user', trimmed);
        addToHistory('model', finalOutput.aiReply);
        return finalOutput;
      }
      // Khi không có kết nối tới server Qwen, tiếp tục xuống bên dưới để chạy Instant Offline Engine
    }

    // ══════════════════════════════════════════════════════════════════════
    // A. KHI CHỌN CHẾ ĐỘ CLOUD GEMINI VÀ CÓ API KEY
    // ══════════════════════════════════════════════════════════════════════
    final apiKey = _configService.apiKey;
    final bool isConnOnline = ConnectivityService().isOnline;

    if (!_configService.isLocalAi && isConnOnline && apiKey.isNotEmpty) {

      // 2. Bơm bức tranh tài chính thời gian thực của người dùng vào Prompt
      final financialContext = await AiFinancialContextService().buildFinancialContextPrompt();
      final extraContextStr = sbExtraContext.isNotEmpty ? '\n\nTHÔNG TIN BỔ TRỢ HỆ THỐNG ĐÃ TÍNH TOÁN TỪ SỔ:\n$sbExtraContext' : '';
      final nowDt = DateTime.now();

      final systemInstruction = '''
Bạn là Trợ lý Mono - trợ lý tài chính thông minh, tận tâm và chu đáo của ứng dụng Quản lý Thu Chi Mono.
Thời gian hiện tại của hệ thống: ${nowDt.toIso8601String().substring(0, 19)} (Giờ Việt Nam UTC+7, ngày ${nowDt.day}/${nowDt.month}/${nowDt.year}, lúc ${nowDt.hour.toString().padLeft(2, '0')}:${nowDt.minute.toString().padLeft(2, '0')}).

$financialContext$extraContextStr

DANH MỤC CHI PHÍ HỢP LỆ:
"Ăn uống", "Sức khỏe", "Di chuyển", "Học tập", "Giải trí", "Du lịch", "Mua sắm", "Tiền nhà", "Tiền điện", "Điện thoại", "Thể thao", "Tiết kiệm", "Bảo hiểm", "Quà tặng", "Làm đẹp", "Thú cưng", "Con cái", "Từ thiện", "Sửa chữa", "Đồ công nghệ", "Trả nợ", "Chi khác".

DANH MỤC THU NHẬP HỢP LỆ:
"Tiền lương", "Lương", "Tiền thưởng", "Kinh doanh", "Đầu tư", "Tiền lãi", "Được cho/Tặng", "Bán đồ", "Tiền thuê nhà", "Thu nợ", "Làm thêm", "Trợ cấp", "Hoàn tiền", "Thu khác".

HƯỚNG DẪN TƯ DUY VÀ PHÂN BIỆT THU NHẬP / CHI PHÍ TRONG TIẾNG VIỆT:
1. THU NHẬP (type = "income"):
   - CẤU TRÚC AI ĐÓ CHO TIỀN: Khi câu có dạng "[Người/Tên/Đại từ] cho [số tiền]" (VD: "Phụng cho 15.000đ", "Mẹ cho 50k", "Bạn cho 100k", "Anh cho", "Chị cho", "Sếp cho", "Khách cho", "Bố cho", "Ai đó cho", "Crush cho 50k",...) -> BẮT BUỘC: type = "income", category = "Được cho/Tặng", description = "[Tên/Chủ thể] cho" (VD: "Phụng cho").
   - TIỀN CHẢY VÀO VÍ CỦA TÔI: Khi có hành động tiền được đưa "vào ví [tên ví]" (VD: "vào ví tiền mặt", "vào ví momo", "vào ví ngân hàng", "cho vào ví", "nạp vào ví", "cộng vào ví", "chuyển vào ví") -> type = "income", walletName = tên ví tương ứng.
   - CÁC DẤU HIỆU THU NHẬP KHÁC: "được nhận", "mới nhận", "vừa nhận", "được cộng", "cộng thêm", "tiền về", "lương", "thưởng", "lãi", "hoàn tiền", "được cho", "lì xì", "biếu", dấu "+" (VD: "+9880₫ vào ví MoMo") -> type = "income".
2. CHI PHÍ (type = "expense"):
   - Chỉ khi người dùng CHI TIỀN, MUA HÀNG, ĂN UỐNG, ĐEM TIỀN CHO NGƯỜI KHÁC:
     "ăn", "mua", "uống", "chi", "trả", "đi chợ", "nạp tiền game", dấu "-", "cho bạn mượn", "cho vay", "cho tiền người ăn xin", "ủng hộ cho...", "chi cho...".
3. VÍ TIỀN:
   - "tiền mặt", "ví tiền mặt" -> walletName = "Tiền mặt".
   - "momo", "ví momo", "mono" -> walletName = "MoMo".
   - "zalopay", "ví zalopay" -> walletName = "ZaloPay".
   - "ngân hàng", "vietcombank", "mb", "techcombank", "bidv"... -> walletName = "Ngân hàng".
4. MÔ TẢ (description):
   - Giữ nguyên nội dung/hoạt động thực tế (VD: "Phụng cho", "Mẹ cho", "Bún bò", "Cà phê sáng", "Đổ xăng").
5. ĐƠN VỊ TIỀN TỆ TIẾNG VIỆT:
   - Dấu chấm như "35.000", "15.000", "50.000" là dấu phân cách hàng nghìn. "15k" = 15000, "1.5tr" = 1500000.
6. THIẾU SỐ TIỀN:
   - Nếu người dùng nhắc hoạt động nhưng chưa nói số tiền: "amount": 0, "needs_amount": true, "reply": Hỏi lại số tiền tự nhiên.
7. XỬ LÝ NGÀY VÀ GIỜ (date):
   - Phân tích chính xác thời gian người dùng nói hoặc nhập vào:
     + "hôm nay", "bữa nay": Ngày hôm nay.
     + "sáng nay", "buổi sáng", "sáng": Ngày hôm nay lúc 08:00 (hoặc giờ cụ thể nếu người dùng có nói).
     + "trưa nay", "buổi trưa", "trưa": Ngày hôm nay lúc 12:00.
     + "chiều nay", "buổi chiều", "chiều": Ngày hôm nay lúc 15:30.
     + "tối nay", "buổi tối", "tối": Ngày hôm nay lúc 19:30.
     + "hôm qua", "bữa qua": Ngày hôm qua (trừ 1 ngày so với hôm nay). Nếu nói "tối qua" = hôm qua lúc 20:00, "sáng qua" = hôm qua lúc 08:00.
     + "hôm kia": Trừ đi 2 ngày so với hôm nay.
     + Nếu có giờ cụ thể (VD: "8h30", "14h", "20 giờ"): Giữ chính xác giờ đó.
     + Nếu người dùng KHÔNG nói ngày hoặc giờ: BẮT BUỘC dùng ngày và giờ hiện tại của hệ thống (${nowDt.toIso8601String().substring(0, 19)}), TUYỆT ĐỐI KHÔNG được trả về 00:00:00.
   - BẮT BUỘC định dạng trường "date" theo chuẩn ISO-8601 đầy đủ gồm ngày và giờ: "YYYY-MM-DDTHH:mm:ss" (VD: "${nowDt.toIso8601String().substring(0, 19)}").

VÍ DỤ MẪU BẮT BUỘC HỌC THEO:
• "Phụng cho 15.000đ vào ví tiền mặt" -> {"type": "income", "category": "Được cho/Tặng", "amount": 15000, "description": "Phụng cho", "walletName": "Tiền mặt"}
• "Mẹ cho 50k" -> {"type": "income", "category": "Được cho/Tặng", "amount": 50000, "description": "Mẹ cho", "walletName": ""}
• "Bạn cho 100k vào ví MoMo" -> {"type": "income", "category": "Được cho/Tặng", "amount": 100000, "description": "Bạn cho", "walletName": "MoMo"}
• "Lương 15 triệu" -> {"type": "income", "category": "Tiền lương", "amount": 15000000, "description": "Tiền lương", "walletName": ""}
• "Ăn bún bò 35k ví MoMo" -> {"type": "expense", "category": "Ăn uống", "amount": 35000, "description": "Bún bò", "walletName": "MoMo"}
• "Cho bạn mượn 200k" -> {"type": "expense", "category": "Chi khác", "amount": 200000, "description": "Cho bạn mượn", "walletName": ""}
• "Chuyển 500k từ ví MoMo sang Techcombank" -> {"actionType": "transferMoney", "transfer": {"amount": 500000, "source_wallet": "MoMo", "target_wallet": "Techcombank", "fee": 0, "note": "Chuyển sang Techcombank"}}
• "Rút 2 triệu từ ATM về tiền mặt" -> {"actionType": "transferMoney", "transfer": {"amount": 2000000, "source_wallet": "Ngân hàng", "target_wallet": "Tiền mặt", "fee": 0, "note": "Rút tiền ATM"}}

PHÂN LUỒNG Ý ĐỊNH (INTENT ROUTING):
1. XÃ GIAO / CHÀO HỎI / TÂM SỰ / MẸO TIẾT KIỆM (intent: "GENERAL_CHAT", actionType: "generalChat" hoặc "financialAdvice"):
   - Khi người dùng chào hỏi, khen ngợi, than thở, hỏi tips tiết kiệm tổng quan:
   - Phản hồi bằng giọng điệu thân thiện, ấm áp, hóm hỉnh DƯỚI 3 CÂU kèm emoji sinh động.
   - BẮT BUỘC để trường "transactions": [] rỗng, không tạo giao dịch ảo.
2. CHUYỂN TIỀN / RÚT TIỀN GIỮA CÁC VÍ (intent: "TRANSFER_MONEY", actionType: "transferMoney"):
   - Khi có hành động luân chuyển tiền giữa 2 ví ("chuyển ... từ ... sang ...", "rút tiền về ...", "nạp tiền vào ..."):
   - Trả lời xác nhận ngắn gọn (1-2 câu) kèm thông tin chuyển tiền trong trường "transfer". BẮT BUỘC "transactions": [].
3. GHI CHÉP THU CHI (intent: "RECORD_TRANSACTION", actionType: "recordTransaction"):
   - Tuân thủ quy chuẩn 3 khối, trích xuất "transactions".
4. ĐỐI THOẠI ĐA VÒNG (MULTI-TURN CONVERSATION):
   - Đọc kỹ các câu đối thoại liền trước. Khi người dùng nói câu tiếp nối (VD: 'Còn lại bao nhiêu?', 'Thế ví MoMo còn tiền không?', 'Ghi thêm 50k nữa', 'Ủa vừa rồi chuyển thành công chưa?'), hãy kết hợp ngữ cảnh câu trước và bảng tài chính thực tế để trả lời chuẩn xác, liền mạch như một người bạn thân thiết.

QUY CHUẨN ĐỊNH DẠNG CÂU TRẢ LỜI BẮT BUỘC (3-BLOCK FORMAT):
Mọi phản hồi trong trường "reply" PHẢI tuân thủ cấu trúc 3 phần rõ ràng, đẹp mắt:
• Khối 1 (Chào & Ghi nhận nhanh): 1 câu ngắn gọn, ấm áp kèm emoji (VD: "✨ Tuyệt vời! Mình đã ghi nhận yêu cầu của bạn.").
• Khối 2 (Số liệu cốt lõi & Phân tích):
  - Dùng gạch đầu dòng rõ ràng (• ) hoặc số thứ tự (1. 2. 3.).
  - BẮT BUỘC in đậm các thông tin quan trọng: số tiền (VD: **15.000 ₫**), danh mục (VD: **Được cho/Tặng** 🎁), ví tiền (VD: **Ví Tiền mặt**).
  - Với câu hỏi tư vấn: Phân tích số liệu cụ thể theo số dư thực tế ở trên, giải thích ngắn gọn, súc tích.
• Khối 3 (Lời khuyên & Gợi ý hành động tiếp theo):
  - Bắt đầu bằng "💡 **Mẹo tiết kiệm:** ..." hoặc "🎯 **Gợi ý tiếp theo:** ...".
  - Đưa ra 1 gợi ý hành động hữu ích hoặc câu lệnh tiếp theo cho người dùng.

BẮT BUỘC TRẢ VỀ CHỈ DUY NHẤT 1 ĐOẠN JSON HỢP LỆ THEO CẤU TRÚC:
{
  "intent": "RECORD_TRANSACTION" | "TRANSFER_MONEY" | "GENERAL_CHAT" | "FINANCIAL_ADVICE" | "NAVIGATE_SCREEN" | "SPENDING_REPORT",
  "actionType": "recordTransaction" | "transferMoney" | "financialAdvice" | "navigateScreen" | "changeTheme" | "changeLanguage" | "spendingReport" | "generalChat",
  "navigationTarget": "statistics" | "calendar" | "wallets" | "groupExpense" | "budget" | "category" | "exportReport" | "receiptGallery" | "notifications" | "aiSettings" | "appearance" | "language" | "accountInfo" | "aboutApp" | "support" | "allTransactions" | "addTransaction" | null,
  "themeMode": "dark" | "light" | null,
  "language": "vi" | "en" | null,
  "reportPeriod": "today" | "week" | "month" | "year" | null,
  "reply": "Nội dung phản hồi chi tiết, sâu sắc và thân thiện từ Trợ lý Mono...",
  "needs_amount": false,
  "transfer": {
    "amount": 0.0,
    "source_wallet": "Tên ví chuyển đi",
    "target_wallet": "Tên ví nhận vào",
    "fee": 0.0,
    "note": "Ghi chú chuyển khoản"
  },
  "transactions": [
    {
      "type": "expense" | "income",
      "category": "Tên danh mục phù hợp",
      "amount": Số_tiền (0 nếu chưa rõ),
      "description": "Mô tả ngắn gọn",
      "date": "YYYY-MM-DDTHH:mm:ss",
      "walletName": "Tên ví hoặc để rỗng"
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
          {'text': '{"intent": "GENERAL_CHAT", "actionType": "generalChat", "reply": "👋 Chào bạn! Mình là Trợ lý Mono, sẵn sàng đồng hành cùng bạn.\\n\\n• Ghi chép thu chi siêu tốc bằng tin nhắn hoặc giọng nói\\n• Phân tích số dư và báo cáo chi tiêu thông minh\\n\\n🎯 **Gợi ý tiếp theo:** Bạn có thể thử gửi cho mình một khoản chi hôm nay nhé!"}'}
        ]
      });

      // Giữ ngữ cảnh các lượt hội thoại gần nhất (Sliding window 8-10 lượt)
      final historyToUse = conversationHistory ?? _conversationHistory;
      if (historyToUse.isNotEmpty) {
        final recentTurns = historyToUse.length > 10
            ? historyToUse.sublist(historyToUse.length - 10)
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
          'temperature': 0.7,
          'maxOutputTokens': 2048,
          'responseMimeType': 'application/json',
          'thinkingConfig': {
            'thinkingBudget': 0,
          },
        }
      };

      // Nâng timeout lên 10.000ms (10 giây) để Gemini 3.6/3.8 Flash xử lý trọn vẹn và thông minh
      final result = await _sendRequest(bodyPayload, timeout: const Duration(seconds: 10));

      if (result.isSuccess) {
        // Đính kèm các thẻ dữ liệu chuyên sâu vào kết quả trả về cho UI
        final finalRes = AiParsedResult(
          aiReply: result.aiReply,
          transactions: result.transactions,
          actionType: result.actionType,
          themeMode: result.themeMode,
          language: result.language,
          reportPeriod: result.reportPeriod,
          navigationTarget: result.navigationTarget,
          needsAmount: result.needsAmount,
          securityMessage: result.securityMessage,
          financialAdvice: result.financialAdvice,
          bankSmsResult: result.bankSmsResult,
          splitBillResult: result.splitBillResult,
          safeDailyResult: attachedSafeDaily,
          forecastResult: attachedForecast,
          latteFactorResult: attachedLatteFactor,
          savingsRoadmapResult: attachedRoadmap,
          spendingQueryResult: attachedSpendingQuery,
          spendingTrendResult: attachedSpendingTrend,
          financialHealthScoreResult: attachedHealthScore,
          recurringDetectionResult: attachedRecurring,
          transferData: result.transferData,
        );
        final dateRes = _applySmartDateTimeGuardrail(finalRes, trimmed);
        final finalOutput = _applySmartSemanticGuardrail(dateRes, trimmed);
        addToHistory('user', trimmed);
        addToHistory('model', finalOutput.aiReply);
        return finalOutput;
      }
    }

    // ══════════════════════════════════════════════════════════════════════
    // B. KHI NGOẠI TUYẾN HOẶC KHI GEMINI GẶP SỰ CỐ MẠNG (OFFLINE FALLBACK)
    // ══════════════════════════════════════════════════════════════════════
    final offlineRes = await _handleOfflineFallback(
      trimmed,
      lowerTrimmed,
      pendingTransaction: pendingTransaction,
    );
    final offlineDateRes = _applySmartDateTimeGuardrail(offlineRes, trimmed);
    final offlineOutput = _applySmartSemanticGuardrail(offlineDateRes, trimmed);
    addToHistory('user', trimmed);
    addToHistory('model', offlineOutput.aiReply);
    return offlineOutput;
  }

  /// Hỗ trợ xử lý ngoại tuyến toàn diện cho Local AI Engine
  Future<AiParsedResult> handleLocalOfflineFallback(
    String trimmed, {
    AiTransactionItem? pendingTransaction,
  }) async {
    final offlineRes = await _handleOfflineFallback(
      trimmed,
      trimmed.toLowerCase(),
      pendingTransaction: pendingTransaction,
    );
    final offlineDateRes = _applySmartDateTimeGuardrail(offlineRes, trimmed);
    return _applySmartSemanticGuardrail(offlineDateRes, trimmed);
  }

  /// Xử lý chế độ Ngoại tuyến thông minh & Graceful Degradation (0ms Lag)
  Future<AiParsedResult> _handleOfflineFallback(
    String trimmed,
    String lowerTrimmed, {
    AiTransactionItem? pendingTransaction,
  }) async {
    // 1. Nhận diện lệnh nhanh cục bộ (Theme, Language, Điều khiển màn hình, Lời chào cơ bản)
    final localAction = _matchLocalIntent(trimmed);
    if (localAction != null) {
      return localAction;
    }

    // 2. Tra cứu chi tiêu cá nhân từ SQLite (Phân tích khoảng thời gian linh hoạt, top danh mục, khoản chi lớn nhất)
    final isSpendingQuery = lowerTrimmed.contains('mức chi tiêu') ||
        lowerTrimmed.contains('đã tiêu') ||
        lowerTrimmed.contains('tiêu hết') ||
        lowerTrimmed.contains('chi hết') ||
        lowerTrimmed.contains('tiêu những gì') ||
        lowerTrimmed.contains('đã chi') ||
        (lowerTrimmed.contains('chi tiêu') && (lowerTrimmed.contains('nhiều nhất') || lowerTrimmed.contains('như thế nào') || lowerTrimmed.contains('bao nhiêu') || lowerTrimmed.contains('việc nào'))) ||
        lowerTrimmed.contains('việc nào nhiều nhất') ||
        lowerTrimmed.contains('cho cái gì nhiều nhất') ||
        lowerTrimmed.contains('khoản chi lớn nhất') ||
        lowerTrimmed.contains('chi nhiều nhất');

    final hasTimeOrQueryContext = lowerTrimmed.contains('ngày') ||
        lowerTrimmed.contains('tuần') ||
        lowerTrimmed.contains('tháng') ||
        lowerTrimmed.contains('năm') ||
        lowerTrimmed.contains('hôm nay') ||
        lowerTrimmed.contains('hôm qua') ||
        lowerTrimmed.contains('gần đây') ||
        lowerTrimmed.contains('vừa qua') ||
        lowerTrimmed.contains('việc nào') ||
        lowerTrimmed.contains('cái gì');

    if (isSpendingQuery && hasTimeOrQueryContext) {
      final queryRes = await FinancialAdvisorService().queryPersonalSpending(trimmed);
      return AiParsedResult(
        aiReply: queryRes.answerText,
        transactions: [],
        actionType: AiActionType.spendingQuery,
        spendingQueryResult: queryRes,
      );
    }

    final bool hasExplicitTxAction = trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        RegExp(r'(?:^|\s)[\+\-]\s*\d+').hasMatch(trimmed) ||
        lowerTrimmed.contains('vào ví') ||
        lowerTrimmed.contains('từ ví') ||
        lowerTrimmed.contains('sang ví');

    // 3. Tư vấn tài chính / Phân bổ tiền lương theo 50/30/20 & Gợi ý mục tiêu
    final isSalaryOrPersonalBudgetQuery = !hasExplicitTxAction && (
        lowerTrimmed.contains('lương') ||
        lowerTrimmed.contains('nhận lương') ||
        lowerTrimmed.contains('tiền lương') ||
        lowerTrimmed.contains('thu nhập') ||
        lowerTrimmed.contains('chia tiền') ||
        lowerTrimmed.contains('chia lương') ||
        lowerTrimmed.contains('phân bổ') ||
        lowerTrimmed.contains('quản lý') ||
        lowerTrimmed.contains('50/30/20') ||
        lowerTrimmed.contains('50 30 20') ||
        lowerTrimmed.contains('tiền còn lại'));

    final isAdviceQuery = isSalaryOrPersonalBudgetQuery ||
        lowerTrimmed.contains('làm gì với số tiền') ||
        lowerTrimmed.contains('cách tiết kiệm') ||
        lowerTrimmed.contains('hướng dẫn tiết kiệm') ||
        lowerTrimmed.contains('tư vấn tài chính') ||
        lowerTrimmed.contains('quy tắc 50');

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

    // 4. Hạn mức chi an toàn mỗi ngày
    final isSafeSpendQuery = lowerTrimmed.contains('được tiêu bao nhiêu') ||
        lowerTrimmed.contains('mỗi ngày được tiêu') ||
        lowerTrimmed.contains('hạn mức ngày') ||
        lowerTrimmed.contains('tiêu an toàn') ||
        lowerTrimmed.contains('an toàn hôm nay');
    if (isSafeSpendQuery) {
      final safeRes = await FinancialAdvisorService().calculateSafeDailyBudget();
      return AiParsedResult(
        aiReply: safeRes.advice,
        transactions: [],
        actionType: AiActionType.safeToSpend,
        safeDailyResult: safeRes,
      );
    }

    // 5. Dự báo tài chính cuối tháng
    final isForecastQuery = lowerTrimmed.contains('dự báo') ||
        lowerTrimmed.contains('dự đoán') ||
        lowerTrimmed.contains('cuối tháng') ||
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

    // 6. Tiêu vặt gây thủng ví (Latte Factor)
    final isLatteFactorQuery = lowerTrimmed.contains('thủng ví') ||
        lowerTrimmed.contains('tiêu vặt') ||
        lowerTrimmed.contains('lặt vặt') ||
        lowerTrimmed.contains('latte factor');
    if (isLatteFactorQuery) {
      final latteRes = await FinancialAdvisorService().analyzeLatteFactor();
      return AiParsedResult(
        aiReply: latteRes.advice,
        transactions: [],
        actionType: AiActionType.latteFactor,
        latteFactorResult: latteRes,
      );
    }

    // 7. Lộ trình tiết kiệm theo mục tiêu
    final isRoadmapQuery = lowerTrimmed.contains('lộ trình tiết kiệm') ||
        lowerTrimmed.contains('tiết kiệm để mua') ||
        lowerTrimmed.contains('để dành mua');
    if (isRoadmapQuery) {
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

    // 8. Xu hướng chi tiêu & Biến động
    final isTrendQuery = lowerTrimmed.contains('xu hướng chi tiêu') ||
        lowerTrimmed.contains('xu hướng tiêu') ||
        lowerTrimmed.contains('chi tiêu bất thường') ||
        lowerTrimmed.contains('so sánh chi tiêu');
    if (isTrendQuery) {
      final trendRes = await FinancialAdvisorService().analyzeSpendingTrends(
        period: lowerTrimmed.contains('tháng') ? 'month' : 'week',
      );
      return AiParsedResult(
        aiReply: trendRes.advice,
        transactions: [],
        actionType: AiActionType.spendingTrends,
        spendingTrendResult: trendRes,
      );
    }

    // 9. Điểm sức khỏe tài chính
    final isHealthQuery = lowerTrimmed.contains('điểm tài chính') ||
        lowerTrimmed.contains('sức khỏe tài chính') ||
        lowerTrimmed.contains('điểm sức khỏe');
    if (isHealthQuery) {
      final healthRes = await FinancialAdvisorService().calculateFinancialHealthScore();
      return AiParsedResult(
        aiReply: healthRes.summaryAdvice,
        transactions: [],
        actionType: AiActionType.financialHealthScore,
        financialHealthScoreResult: healthRes,
      );
    }

    // 10. Khoản chi phí cố định định kỳ
    final isRecurringQuery = lowerTrimmed.contains('khoản định kỳ') ||
        lowerTrimmed.contains('chi phí cố định') ||
        lowerTrimmed.contains('chi tiêu định kỳ');
    if (isRecurringQuery) {
      final recRes = await FinancialAdvisorService().detectRecurringTransactions();
      return AiParsedResult(
        aiReply: recRes.summary,
        transactions: [],
        actionType: AiActionType.recurringTransactions,
        recurringDetectionResult: recRes,
      );
    }

    // 11. Báo cáo chi tiêu cục bộ
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

    // 12. Trích xuất giao dịch rõ ràng bằng Regex cục bộ (Fallback transaction extraction)
    final fastTx = _fallbackExtractTransaction(trimmed, pendingTransaction: pendingTransaction);
    if (fastTx != null && (fastTx.needsAmount || (fastTx.transactions.isNotEmpty && fastTx.transactions.first.amount > 0))) {
      return fastTx;
    }

    // 13. Phản hồi hướng dẫn chung khi ngoại tuyến
    return AiParsedResult(
      aiReply: '⚡ **Trợ lý Mono đang hoạt động Ngoại tuyến**:\n\n'
          'Bạn vẫn có thể sử dụng các tính năng thiết yếu:\n'
          '• **Ghi chép thu chi**: Nhập hoặc nói (VD: *"Ăn bún bò 35k ví MoMo"*, *"Lương 15 triệu"*)\n'
          '• **Xem báo cáo**: Tra cứu tức thì (VD: *"Báo cáo hôm nay"*, *"Tháng này tiêu bao nhiêu"*)\n'
          '• **Cài đặt & Điều khiển**: Mở màn hình (VD: *"Bật chế độ tối"*, *"Mở thống kê"*)\n'
          '• **Lời khuyên tài chính**: Tư vấn số dư (VD: *"Tip tiết kiệm"*, *"Số tiền còn lại nên làm gì"*)\n\n'
          '💡 **Gợi ý:** Hãy kết nối WiFi hoặc dữ liệu di động để kích hoạt đầy đủ trí tuệ của Mono nhé! 😊',
      transactions: [],
      actionType: AiActionType.generalChat,
      isSuccess: true,
    );
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

    // 3b. Nhận diện hành động Chuyển tiền / Rút tiền giữa các ví (Fast Local Intent)
    final transferMatch = RegExp(
      r'(?:chuyển|rút|nạp)\s+(?:khoản\s+)?(\d+(?:[\.,]\d+)?\s*(?:k|nghìn|ngàn|tr|triệu|củ|đ|đồng|vnd)?)\s+(?:từ\s+(?:ví\s+)?([a-zA-Z0-9\sà-ỹÀ-Ỹ]+?)\s+)?(?:sang|về|qua|vào)\s+(?:ví\s+)?([a-zA-Z0-9\sà-ỹÀ-Ỹ]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (transferMatch != null) {
      final rawAmount = transferMatch.group(1) ?? '0';
      final source = transferMatch.group(2)?.trim() ?? (lower.contains('rút') ? 'Ngân hàng' : 'Tiền mặt');
      final target = transferMatch.group(3)?.trim() ?? (lower.contains('rút') ? 'Tiền mặt' : 'Ngân hàng');
      final amount = CurrencyUtils.parseNaturalAmount(rawAmount);

      if (amount > 0) {
        final replyText = '✨ Mono đã ghi nhận yêu cầu chuyển **${CurrencyUtils.formatCurrency(amount)}** từ **$source** sang **$target**.\n\n'
            '🎯 Bạn vui lòng nhấn nút bên dưới để xác nhận chuyển tiền nhé!';
        return AiParsedResult(
          aiReply: replyText,
          transactions: [],
          actionType: AiActionType.transferMoney,
          transferData: TransferMoneyData(
            amount: amount,
            sourceWalletName: source,
            targetWalletName: target,
            note: 'Chuyển tiền qua Trợ lý Mono',
          ),
          isSuccess: true,
        );
      }
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
    // Chi tiêu nhóm (chỉ khi người dùng muốn mở tính năng hoặc quản lý nhóm, không phải câu hỏi chia tiền lương hay phân bổ tài chính)
    final isSalaryOrPersonalBudget = lower.contains('lương') ||
        lower.contains('nhận lương') ||
        lower.contains('tiền lương') ||
        lower.contains('thu nhập') ||
        lower.contains('chia lương') ||
        lower.contains('hợp lý') ||
        lower.contains('phân bổ') ||
        lower.contains('50/30/20') ||
        lower.contains('50 30 20') ||
        lower.contains('như thế nào');

    if (!isSalaryOrPersonalBudget && (
        lower.contains('chi tiêu nhóm') ||
        lower == 'chia tiền' ||
        lower.contains('mở chia tiền') ||
        lower.contains('quỹ nhóm') ||
        lower.contains('mở nhóm') ||
        lower == 'nhóm')) {
      return AiParsedResult(
        aiReply: 'Đang mở tính năng Chi tiêu nhóm cho bạn nhé! 👥',
        transactions: [],
        actionType: AiActionType.navigateScreen,
        navigationTarget: 'groupExpense',
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
    if (lower.contains('trung tâm hỗ trợ') ||
        lower.contains('gửi hỗ trợ') ||
        lower.contains('liên hệ hỗ trợ') ||
        lower.contains('chăm sóc khách hàng') ||
        lower.contains('hỗ trợ khách hàng') ||
        lower == 'support' ||
        lower == 'hỗ trợ' ||
        lower == 'trợ giúp') {
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

    // 5. TRÒ CHUYỆN ĐƠN GIẢN & CHIT-CHAT (0ms Fast Response - Chuẩn 3 Khối)
    // Bạn là ai / Giới thiệu / Giúp được gì (Ưu tiên kiểm tra trước lời chào để bắt trọn câu hỏi tính năng)
    if (lower.contains('bạn là ai') ||
        lower.contains('bạn tên gì') ||
        lower.contains('mono là ai') ||
        lower.contains('giới thiệu') ||
        lower.contains('giúp gì') ||
        lower.contains('giúp được gì') ||
        lower.contains('làm được gì') ||
        lower.contains('chức năng gì')) {
      return AiParsedResult(
        aiReply: '🤖 **Mình là Mono – Trợ lý tài chính cá nhân thông minh của bạn!**\n\n'
            'Mình luôn sẵn sàng đồng hành và hỗ trợ bạn quản lý chi tiêu thuận tiện nhất:\n'
            '• **🎙️ Ghi nhận giọng nói:** Nhập thu chi chỉ trong 1 giây mà không cần bấm phím.\n'
            '• **📊 Báo cáo & Phân tích:** Xem ngay tình hình thu chi hôm nay, tuần này hoặc tháng này.\n'
            '• **👛 Quản lý đa ví:** Theo dõi số dư MoMo, Tiền mặt, Ngân hàng tức thì.\n'
            '• **📷 Quét hóa đơn:** Tự động đọc biên lai và trích xuất số tiền chuẩn xác.\n'
            '• **💡 Tư vấn ngân sách:** Nhắc nhở hạn mức và gợi ý tiết kiệm thông minh.\n\n'
            '🎯 **Gợi ý tiếp theo:** Bạn hãy thử nói một khoản chi, ví dụ: *"Ăn bún bò 35k"* hoặc *"Mở báo cáo tháng"* nhé!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    // Lời chào thông thường
    final isGreeting = lower == 'chào' ||
        lower == 'alo' ||
        lower == 'hello' ||
        lower == 'hi' ||
        lower == 'hi mono' ||
        lower == 'chào mono' ||
        lower == 'chào bạn' ||
        lower == 'xin chào' ||
        lower.startsWith('xin chào') ||
        lower.startsWith('chào buổi');
    if (isGreeting) {
      return AiParsedResult(
        aiReply: '👋 **Chào bạn! Mình là Trợ lý Mono.**\n\n'
            'Rất vui được gặp bạn! Hôm nay tình hình tài chính của bạn thế nào rồi?\n'
            '• Mình luôn sẵn sàng hỗ trợ bạn ghi chép thu chi siêu tốc.\n'
            '• Phân tích báo cáo và tối ưu hóa ngân sách cá nhân.\n\n'
            '🎯 **Gợi ý tiếp theo:** Bạn có thể nói một khoản chi tiêu vừa phát sinh hôm nay để mình ghi vào sổ nhé!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    // Hỏi thăm
    if (lower.contains('bạn khỏe không') || lower.contains('khỏe không') || lower == 'thế nào rồi' || lower.contains('hôm nay thế nào')) {
      return AiParsedResult(
        aiReply: '✨ **Mono luôn khỏe mạnh và tràn đầy năng lượng** để phục vụ tài chính cho bạn!\n\n'
            '• Hệ thống ghi nhận thu chi và các tính năng trợ lý đang hoạt động rất tốt.\n'
            '• Sẵn sàng lắng nghe và tính toán mọi khoản tiền giúp bạn mọi lúc.\n\n'
            '💡 **Mẹo tiết kiệm:** Ghi chép ngay khi vừa phát sinh chi tiêu sẽ giúp bạn nắm bắt dòng tiền chính xác hơn 30% đấy!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    // Cảm ơn
    if (lower.contains('cảm ơn') || lower.contains('thank you') || lower.contains('thanks') || lower.contains('mono giỏi quá')) {
      return AiParsedResult(
        aiReply: '💖 **Không có chi nè! Được hỗ trợ bạn là niềm vui lớn của Mono.**\n\n'
            '• Chúc bạn luôn quản lý chi tiêu hiệu quả và ngày càng tích lũy được nhiều hơn.\n\n'
            '🎯 **Gợi ý tiếp theo:** Nếu cần kiểm tra ngân sách hay số dư các ví, bạn cứ nhắn mình bất cứ lúc nào nhé!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    // Lời khen
    if (lower.contains('bạn thông minh') || lower.contains('tuyệt vời') || lower.contains('dễ thương') || lower.contains('mono xịn')) {
      return AiParsedResult(
        aiReply: '🥰 **Cảm ơn lời khen của bạn rất nhiều nha!**\n\n'
            '• Mono sẽ luôn nỗ lực học hỏi và nâng cao độ chính xác để phục vụ bạn ngày càng chu đáo hơn.\n\n'
            '💡 **Mẹo:** Bạn có thể dùng tính năng quét hóa đơn ảnh hoặc giữ phím mic để nhập nhanh hơn nữa đấy!',
        transactions: [],
        actionType: AiActionType.generalChat,
      );
    }

    // Tạm biệt
    if (lower == 'tạm biệt' || lower == 'bye' || lower == 'bye bye' || lower.contains('hẹn gặp lại') || lower.contains('tạm biệt mono')) {
      return AiParsedResult(
        aiReply: '👋 **Tạm biệt bạn nhé! Chúc bạn một ngày thật vui vẻ và bình an.**\n\n'
            '• Sổ thu chi của bạn đã được cập nhật an toàn và đồng bộ đầy đủ.\n\n'
            '🎯 **Gợi ý:** Bất cứ khi nào có khoản thu chi mới, hãy ghé lại để mình ghi vào sổ giúp bạn nhé!',
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
      'không': 0, 'một': 1, 'mốt': 1, 'hai': 2, 'ba': 3, 'bốn': 4,
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
      } else if (t == 'tư' && i > 0 && (tokens[i - 1] == 'mươi' || tokens[i - 1] == 'mười')) {
        currentUnit = 4;
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
  AiParsedResult? _fallbackExtractTransaction(
    String text, {
    AiTransactionItem? pendingTransaction,
  }) {
    // Chuẩn hóa ký hiệu tiền tệ & biến thể STT
    final normalizedText = text
        .replaceAll('₫', 'đ')
        .replaceAll('và ví', 'vào ví')
        .replaceAll('và Ví', 'vào ví');
    final lower = normalizedText.toLowerCase();

    // Nếu là câu hỏi tra cứu chi tiêu, tư vấn phân bổ tài chính -> Tuyệt đối không bóc tách thành giao dịch
    final isQueryOrAdviceQuestion = lower.contains('mức chi tiêu') ||
        lower.contains('nhiều nhất') ||
        lower.contains('ít nhất') ||
        lower.contains('việc nào') ||
        lower.contains('như thế nào') ||
        lower.contains('thế nào') ||
        lower.contains('hợp lý') ||
        lower.contains('phân bổ') ||
        lower.contains('chia tiền') ||
        lower.contains('50/30/20') ||
        lower.contains('50 30 20') ||
        lower.contains('tiêu những gì') ||
        lower.contains('khoản chi lớn nhất');
    if (isQueryOrAdviceQuestion && !lower.contains('mua') && !lower.contains('uống') && !lower.contains('được cho')) {
      return null;
    }
    // Chú ý: Dấu cộng '+' đi kèm số (ví dụ Google STT tự format: "+9880₫ và Ví MoMo", "+50k") là THU NHẬP
    final bool hasPlusSign = RegExp(r'(?:^|\s)\+\s*\d+').hasMatch(normalizedText);
    final bool hasMinusSign = RegExp(r'(?:^|\s)-\s*\d+').hasMatch(normalizedText);

    // Kiểm tra cấu trúc ai đó cho tiền: "[Chủ thể] cho [số tiền]" (VD: "phụng cho 15k", "mẹ cho 50k", "bạn cho 100k")
    final bool isGiveOutExpense = lower.contains('cho vay') ||
        lower.contains('cho mượn') ||
        lower.contains('cho bạn mượn') ||
        lower.contains('cho tiền ăn xin') ||
        lower.contains('cho người nghèo') ||
        lower.contains('chi cho') ||
        lower.contains('mua quà cho') ||
        lower.contains('mua cho') ||
        lower.contains('trả tiền cho') ||
        lower.contains('gửi cho') ||
        lower.contains('chuyển cho');

    final bool hasGivenBySomeone = !isGiveOutExpense && (
        RegExp(r'(?:^|\s)(?:[a-zà-ỹA-ZÀ-Ỹ0-9_]+)\s+cho\s+(?:\d|[\.,\d]+|tiền|vào ví|vào)', caseSensitive: false).hasMatch(normalizedText) ||
        RegExp(r'(?:^|\s)cho\s+(?:\d|[\.,\d]+)\s*(?:k|nghìn|ngàn|tr|triệu|củ|đ|đồng|vnd)?\s+vào\s+ví', caseSensitive: false).hasMatch(normalizedText) ||
        lower.contains('được cho') ||
        lower.contains('cho tiền') ||
        lower.contains('ai cho') ||
        lower.contains('người ta cho') ||
        lower.contains('mẹ cho') ||
        lower.contains('bố cho') ||
        lower.contains('ba cho') ||
        lower.contains('bạn cho') ||
        lower.contains('anh cho') ||
        lower.contains('chị cho') ||
        lower.contains('em cho') ||
        lower.contains('sếp cho') ||
        lower.contains('khách cho') ||
        lower.contains('ông cho') ||
        lower.contains('bà cho') ||
        lower.contains('cô cho') ||
        lower.contains('chú cho') ||
        lower.contains('bác cho') ||
        lower.contains('người yêu cho') ||
        lower.contains('crush cho')
    );

    final bool hasCreditOrIncomeAction = RegExp(r'(?:^|\s)(?:cộng|nạp|thu|nhận)\s+(?:\d|[\.,\d]+)', caseSensitive: false).hasMatch(normalizedText) ||
        RegExp(r'(?:^|\s)cộng\s+.*?(?:vào|sang)\s+(?:ví)?', caseSensitive: false).hasMatch(normalizedText) ||
        lower.contains('tiền lãi') ||
        lower.contains('lãi suất') ||
        lower.contains('lãi tiết kiệm') ||
        lower.contains('tiền lời') ||
        lower.contains('sinh lời') ||
        lower.contains('khoản thu') ||
        lower.contains('khoảng thu');

    bool isIncome = hasPlusSign ||
        hasGivenBySomeone ||
        hasCreditOrIncomeAction ||
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
        lower.contains('tiền về') ||
        lower.contains('lương') ||
        lower.contains('thưởng') ||
        lower.contains('hoàn tiền') ||
        lower.contains('được cho') ||
        lower.contains('mẹ cho') ||
        lower.contains('bố cho') ||
        lower.contains('nạp vào ví') ||
        lower.contains('cộng vào ví') ||
        lower.contains('chuyển vào ví') ||
        lower.contains('nhận vào ví') ||
        lower.contains('tiền vào ví');

    if (hasMinusSign && !hasPlusSign) {
      isIncome = false;
    }

    final bool isExplicitExpense = lower.contains('mua') ||
        lower.contains('chi') ||
        lower.contains('tiêu') ||
        lower.contains('ăn') ||
        lower.contains('uống') ||
        lower.contains('đổ xăng') ||
        lower.contains('đi grab') ||
        lower.contains('đi chợ');

    if (isExplicitExpense && !hasGivenBySomeone && !hasPlusSign) {
      isIncome = false;
    }

    // Tìm ví
    String wallet = '';
    if (lower.contains('momo') || RegExp(r'\b(?:ví|qua|bằng)\s+mono\b').hasMatch(lower)) {
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
    } else if (lower.contains('thanh toán bằng ví') ||
        lower.contains('bằng ví') ||
        lower.contains('qua ví') ||
        lower.contains('từ ví')) {
      final wallets = WalletRepository().latestWallets;
      if (wallets.isNotEmpty) {
        final def = wallets.firstWhere((w) => w.isDefault, orElse: () => wallets.first);
        wallet = def.name;
      } else {
        wallet = 'Tiền mặt';
      }
    }

    double amount = 0;
    bool hasAmount = false;

    // 1. Phân cách hàng nghìn kiểu Việt Nam (VD: 15.000đ, 20.000, 100.000)
    final thousandsSepRegex = RegExp(r'(?:\+|-)?\s*(\d{1,3}(?:\.\d{3})+)\s*(?:đ|đồng|vnd|₫)?(?:\s|$|\b)', caseSensitive: false);
    final thousandsMatch = thousandsSepRegex.firstMatch(normalizedText);
    if (thousandsMatch != null) {
      final cleanStr = thousandsMatch.group(1)!.replaceAll('.', '');
      final val = double.tryParse(cleanStr);
      if (val != null && val > 0) {
        amount = val;
        hasAmount = true;
      }
    }

    // 2. Số thập phân đi kèm đơn vị scale (VD: 1.5tr, 2,5 triệu, 3.5k)
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

    // 3. Số hỗn hợp / chữ: "hai mươi nghìn", "năm trăm ngàn", "1 triệu rưỡi"
    if (!hasAmount) {
      final compoundVal = parseVietnameseWordNumber(normalizedText);
      if (compoundVal > 0) {
        amount = compoundVal;
        hasAmount = true;
      }
    }

    // 4. Số kèm đơn vị quy đổi (VD: 35k, 50 nghìn, 2 triệu, 1 củ rưỡi)
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
      final plainNumRegex = RegExp(r'(?:\+|-)?\s*(\d+)\s*(?:đ|đồng|vnd)?(?:\s|$|\b)', caseSensitive: false);
      final plainMatches = plainNumRegex.allMatches(normalizedText);
      for (final plainMatch in plainMatches) {
        final val = double.tryParse(plainMatch.group(1)!);
        if (val != null && val > 0) {
          final afterMatch = normalizedText.substring(plainMatch.end).trim().toLowerCase();
          final isUnitOrTime = afterMatch.startsWith('ngày') ||
              afterMatch.startsWith('ngay') ||
              afterMatch.startsWith('tháng') ||
              afterMatch.startsWith('thang') ||
              afterMatch.startsWith('năm') ||
              afterMatch.startsWith('nam') ||
              afterMatch.startsWith('tuần') ||
              afterMatch.startsWith('tuan') ||
              afterMatch.startsWith('giờ') ||
              afterMatch.startsWith('gio') ||
              afterMatch.startsWith('h') ||
              afterMatch.startsWith('phút') ||
              afterMatch.startsWith('phut') ||
              afterMatch.startsWith('người') ||
              afterMatch.startsWith('nguoi') ||
              afterMatch.startsWith('lần') ||
              afterMatch.startsWith('lan');
          if (!isUnitOrTime) {
            amount = val;
            hasAmount = true;
            break;
          }
        }
      }
    }

    // 1. Phân loại danh mục thông minh qua SmartCategoryService (từ điển thương hiệu & thói quen người dùng)
    final smartCatRes = SmartCategoryService().predictCategoryFast(text, isIncome: isIncome);
    String category = hasGivenBySomeone ? 'Được cho/Tặng' : smartCatRes.category;

    // 2. Làm sạch mô tả để trích xuất chính xác nội dung thực tế người dùng đọc
    String cleaned = text
        .replaceAll('₫', ' ')
        .replaceAll(RegExp(r'(?:\+|-)?\s*\d{1,3}(?:\.\d{3})+\s*(?:đ|đồng|vnd|₫)?(?:\s|$|\b)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'(?:\+|-)?\s*\d+(?:[\.,\d]+)?\s*(?:k|nghìn|ngàn|tr|triệu|củ|đ|vnd|đồng|₫)?(?:\s|$|\b)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:thanh toán\s+(?:bằng|qua|từ)?\s*(?:ví)?)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:thanh toán)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:trả\s+(?:tiền\s+)?(?:bằng|qua|từ)?\s*(?:ví)?)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:bằng|qua|từ|vào|và)?\s*(?:ví\s+)?(?:momo|tiền mặt|zalopay|ngân hàng|techcombank|vietcombank|mbbank|bidv|agribank|vpbank|tpbank|acb)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:vào ví|từ ví|qua ví|bằng ví|và ví|bằng tiền mặt|bằng thẻ|chuyển khoản)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:hết|giá|khoảng|tầm)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'^[+\-–—]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = cleaned
        .replaceAll(RegExp(r'^(?:tôi\s+)?(?:vừa\s+mới|mới|vừa|đã)?\s*(?:mua|ăn|uống|chi|tiêu|trả tiền|trả|cộng|nạp|thu|nhận)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(?:tôi\s+)?(?:vừa\s+mới|mới|vừa|đã)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:hôm nay|hôm qua|sáng nay|chiều nay|tối nay|trưa nay)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:thanh toán|trả tiền|trả|bằng|qua|từ|vào|ví)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\.,]$'), '')
        .trim();

    String description = '';
    // Nếu có cấu trúc người khác cho tiền (VD: "phụng cho", "mẹ cho")
    final matchGiven = RegExp(r'(?:^|\s)([a-zà-ỹA-ZÀ-Ỹ0-9_]+)\s+cho\b', caseSensitive: false).firstMatch(text);
    if (matchGiven != null) {
      final subject = matchGiven.group(1)!.trim();
      final lowerSub = subject.toLowerCase();
      if (lowerSub != 'chi' && lowerSub != 'trả' && lowerSub != 'mua' && lowerSub != 'không' && lowerSub != 'đừng' && lowerSub != 'tiền') {
        description = '${subject[0].toUpperCase()}${subject.substring(1)} cho';
      }
    }

    if (description.isEmpty) {
      if (cleaned.length >= 2) {
        description = '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
      } else {
        // Fallback khi người dùng không nói tên món (VD: "-35k momo", "+50k momo", "cộng 11đ vào ví momo")
        if (isIncome) {
          description = category.isNotEmpty && category != 'Thu khác'
              ? category
              : (wallet.isNotEmpty ? 'Cộng tiền vào ví $wallet' : 'Thu nhập');
        } else {
          description = wallet.isNotEmpty ? 'Chi tiêu từ ví $wallet' : 'Chi tiêu';
        }
      }
    }

    // 3. Multi-turn Context: Kế thừa và hợp nhất với giao dịch đang chờ (pendingTransaction)
    if (pendingTransaction != null) {
      if (wallet.isEmpty && pendingTransaction.walletName.isNotEmpty) {
        wallet = pendingTransaction.walletName;
      }
      if (!hasAmount && pendingTransaction.amount > 0) {
        amount = pendingTransaction.amount;
        hasAmount = true;
      }
      if (pendingTransaction.category.isNotEmpty && (smartCatRes.confidence < 0.6 || description.isEmpty || RegExp(r'^\d+$').hasMatch(description))) {
        category = pendingTransaction.category;
      }
      if (pendingTransaction.description.isNotEmpty && (description.length < 3 || RegExp(r'^\d+$').hasMatch(description))) {
        description = pendingTransaction.description;
      }
    }

    if (description.length > 50) {
      description = description.substring(0, 50);
    }

    final iconData = CategoryUtils.getCategoryIcon(category);

    final parsedDtInfo = VoiceService().parseVietnameseDateTime(text);
    final fallbackDate = parsedDtInfo['date'] as DateTime;

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
            date: fallbackDate,
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
        ? (hasGivenBySomeone
            ? 'Đã ghi nhận khoản thu $formattedStrđ cho "$description"${wallet.isNotEmpty ? ' vào ví $wallet' : ''} rồi nhé! 💰'
            : 'Đã ghi nhận cộng thêm $formattedStrđ${wallet.isNotEmpty ? ' vào ví $wallet' : ''} cho bạn nhé! 💰')
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
          date: fallbackDate,
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

    const promptText = '''
Bạn là Trợ lý Mono - chuyên gia quét và trích xuất dữ liệu hóa đơn/biên lai thanh toán bằng tiếng Việt cho ứng dụng Quản lý Thu Chi Mono.
Nhiệm vụ: Hãy phân tích kỹ hình ảnh hóa đơn/biên lai đính kèm và trích xuất chính xác:
1. "description": Tên cửa hàng, siêu thị, nhà hàng hoặc các món chính (Ví dụ: "WinMart - Mua thực phẩm", "Highlands Coffee", "Cây xăng Petrolimex").
2. "amount": Tổng số tiền thanh toán cuối cùng mà khách hàng thực trả (Grand Total sau khi đã trừ giảm giá/voucher/khuyến mãi và cộng thuế VAT nếu có). Bắt buộc là số nguyên hoặc thập phân dương, không có ký tự chữ.
3. "category": Phân loại danh mục chi tiêu chuẩn xác: "Ăn uống", "Mua sắm", "Di chuyển", "Sức khỏe", "Giải trí", "Tiền điện", "Tiền nước", "Chi khác".
4. "date": Ngày trên hóa đơn theo định dạng "YYYY-MM-DD" (hoặc hôm nay nếu không thấy).
5. "reply": Câu thông báo tiếng Việt vui vẻ, thân thiện xác nhận đã đọc thành công hóa đơn từ đơn vị nào với số tiền bao nhiêu.

BẮT BUỘC CHỈ TRẢ VỀ DUY NHẤT 1 KHỐI JSON:
{
  "actionType": "recordTransaction",
  "reply": "Đã quét hóa đơn từ [Tên nơi bán]: [Số tiền]đ",
  "needs_amount": false,
  "transactions": [
    {
      "type": "expense",
      "category": "Ăn uống",
      "amount": 45000,
      "description": "Highlands Coffee",
      "date": "2026-09-28",
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
        'responseMimeType': 'application/json',
        'maxOutputTokens': 512,
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
      final model = _configService.modelName.isNotEmpty ? _configService.modelName : _primaryModel;
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


  /// Thực thi request và parse kết quả JSON với cơ chế chuyển model dự phòng thông minh (Multi-Model Failover)
  Future<AiParsedResult> _sendRequest(
    Map<String, dynamic> bodyPayload, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final apiKey = _configService.apiKey;
    if (apiKey.isEmpty) {
      return AiParsedResult.error('Chưa cấu hình Google Gemini API Key.');
    }

    final initialModel = _configService.modelName.isNotEmpty ? _configService.modelName : _primaryModel;
    final candidateModels = <String>[
      initialModel,
      if (initialModel != _fallbackModel) _fallbackModel,
      if (initialModel != 'gemini-3.8-flash' && _fallbackModel != 'gemini-3.8-flash') 'gemini-3.8-flash',
    ];

    String? lastErrorMessage;

    for (final currentModel in candidateModels) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$apiKey');
          final response = await _client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyPayload),
          ).timeout(timeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final candidates = data['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) {
              lastErrorMessage = 'Không nhận được câu trả lời từ Trợ lý Mono.';
              break;
            }

            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts == null || parts.isEmpty) {
              lastErrorMessage = 'Nội dung phản hồi trống.';
              break;
            }

            final text = parts[0]['text'] as String? ?? '';
            return _parseJsonFromAiText(text);
          }

          // Khi gặp 503 (High demand / UNAVAILABLE) hoặc 404 / 429
          debugPrint('GeminiAiService: Model $currentModel phản hồi ${response.statusCode}, chuyển model dự phòng tiếp theo...');
          lastErrorMessage = 'Hệ thống AI hiện đang xử lý nhiều lượt truy vấn. Bạn vui lòng thử lại sau giây lát nhé! 🤖';
          // Chuyển sang model tiếp theo ngay lập tức, không để người dùng chờ
          break;
        } catch (e) {
          debugPrint('GeminiAiService: Model $currentModel exception: $e');
          if (e.toString().contains('TimeoutException')) {
            lastErrorMessage = 'Kết nối mạng đang chậm khiến yêu cầu phản hồi lâu hơn thường lệ. Bạn vui lòng thử gửi lại nhé! ⏳';
          } else if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
            lastErrorMessage = 'Không thể kết nối đến máy chủ AI. Bạn vui lòng kiểm tra lại kết nối WiFi hoặc dữ liệu di động nhé! 🌐';
          } else {
            lastErrorMessage = 'Trợ lý Mono đang tạm thời gián đoạn kết nối. Bạn hãy thử lại sau ít giây nhé! ✨';
          }
          if (attempt == 0 && e.toString().contains('SocketException')) {
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          break;
        }
      }
    }

    return AiParsedResult.error(lastErrorMessage ?? 'Trợ lý Mono hiện chưa thể xử lý yêu cầu lúc này. Bạn vui lòng thử lại nhé!');
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

      TransferMoneyData? transferData;
      if (jsonMap['transfer'] is Map<String, dynamic>) {
        final tMap = jsonMap['transfer'] as Map<String, dynamic>;
        double tAmount = 0.0;
        final rawTAmount = tMap['amount'];
        if (rawTAmount is num) {
          tAmount = rawTAmount.toDouble();
        } else if (rawTAmount != null) {
          tAmount = CurrencyUtils.parseNaturalAmount(rawTAmount.toString());
        }

        double tFee = 0.0;
        final rawTFee = tMap['fee'];
        if (rawTFee is num) {
          tFee = rawTFee.toDouble();
        } else if (rawTFee != null) {
          tFee = CurrencyUtils.parseNaturalAmount(rawTFee.toString());
        }

        transferData = TransferMoneyData(
          amount: tAmount,
          sourceWalletName: (tMap['source_wallet'] ?? tMap['from_wallet'] ?? '').toString(),
          targetWalletName: (tMap['target_wallet'] ?? tMap['to_wallet'] ?? '').toString(),
          fee: tFee,
          note: (tMap['note'] ?? '').toString(),
        );
      }

      AiActionType actionType = AiActionType.recordTransaction;
      final intentStr = (jsonMap['intent'] ?? '').toString().toUpperCase();
      if (actionTypeStr == 'transferMoney' || intentStr == 'TRANSFER_MONEY' || transferData != null) {
        actionType = AiActionType.transferMoney;
      } else if (actionTypeStr == 'changeTheme') {
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
          
          // Xử lý amount linh hoạt: hỗ trợ cả số thực lẫn chuỗi có dấu chấm/phẩy phân cách hàng nghìn ("125.000", "45,000đ")
          double amount = 0.0;
          final rawAmount = item['amount'];
          if (rawAmount is num) {
            amount = rawAmount.toDouble();
          } else if (rawAmount != null) {
            amount = CurrencyUtils.parseNaturalAmount(rawAmount.toString());
          }

          final description = (item['description'] ?? category).toString();

          // Xử lý date & time linh hoạt: hỗ trợ ISO 8601, dd/MM/yyyy, dd-MM-yyyy và trích xuất giờ phút
          DateTime date = DateTime.now();
          if (item['date'] != null) {
            final rawDate = item['date'].toString().trim();
            final parsedIso = DateTime.tryParse(rawDate);
            if (parsedIso != null) {
              date = parsedIso;
              // Nếu parsedIso chỉ chứa ngày (hour = 0, minute = 0) và chuỗi không có thông tin giờ (không chứa ':' hay 'T')
              if (parsedIso.hour == 0 && parsedIso.minute == 0 && !rawDate.contains(':')) {
                if (item['time'] != null) {
                  final tMatch = RegExp(r'(\d{1,2})[:h](\d{1,2})?').firstMatch(item['time'].toString());
                  if (tMatch != null) {
                    final h = int.parse(tMatch.group(1)!);
                    final m = tMatch.group(2) != null ? int.parse(tMatch.group(2)!) : 0;
                    date = DateTime(parsedIso.year, parsedIso.month, parsedIso.day, h, m);
                  } else {
                    date = DateTime(parsedIso.year, parsedIso.month, parsedIso.day, DateTime.now().hour, DateTime.now().minute);
                  }
                } else {
                  date = DateTime(parsedIso.year, parsedIso.month, parsedIso.day, DateTime.now().hour, DateTime.now().minute);
                }
              }
            } else {
              final match = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})').firstMatch(rawDate);
              if (match != null) {
                final d = int.tryParse(match.group(1)!) ?? 1;
                final m = int.tryParse(match.group(2)!) ?? 1;
                final y = int.tryParse(match.group(3)!) ?? DateTime.now().year;
                date = DateTime(y, m, d, DateTime.now().hour, DateTime.now().minute);
              }
            }
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
        transferData: transferData,
        isSuccess: true,
      );
    } catch (e) {
      debugPrint('AI returned natural response (not JSON format): $e');
      String cleanText = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Bóc tách nếu có "reply": "..."
      final replyRegex = RegExp(r'"reply"\s*:\s*"((?:[^"\\]|\\.)*)');
      final match = replyRegex.firstMatch(cleanText);
      if (match != null && match.group(1) != null) {
        cleanText = match.group(1)!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', ' ')
            .replaceAll(RegExp(r'"\s*,?\s*"?$'), '')
            .trim();
      } else {
        // Nếu chuỗi chứa cú pháp JSON thô bị rò rỉ mà không có nội dung rõ ràng
        if (cleanText.contains('"actionType"') || cleanText.contains('{') || cleanText.contains('"transactions"')) {
          cleanText = '👋 **Chào bạn! Mình là Trợ lý Mono.**\n\n'
              '• Mình có thể giúp bạn ghi chép thu chi siêu tốc bằng tin nhắn hoặc giọng nói.\n'
              '• Tra cứu báo cáo tài chính và gợi ý quản lý chi tiêu thông minh.\n\n'
              '🎯 **Gợi ý tiếp theo:** Bạn hãy thử nói hoặc nhập: *"Ăn bún bò 35k"* nhé!';
        }
      }

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

  /// Bảo đảm ngày và giờ cho giao dịch luôn khớp chính xác với ngôn ngữ tự nhiên tiếng Việt
  /// (Xử lý dứt điểm các trường hợp: "sáng nay", "hôm qua", "tối qua", "lúc 8h", "hôm kia",
  /// và tránh tuyệt đối việc AI trả về 00:00:00 cho giao dịch thực tế).
  AiParsedResult _applySmartDateTimeGuardrail(AiParsedResult result, String userText) {
    if (result.transactions.isEmpty) return result;

    final dtInfo = VoiceService().parseVietnameseDateTime(userText);
    final hasExplicitDate = dtInfo['hasExplicitDate'] == true;
    final hasExplicitTime = dtInfo['hasExplicitTime'] == true;
    final expectedDate = dtInfo['date'] as DateTime;
    final now = DateTime.now();

    bool hasChanged = false;
    final updatedList = <AiTransactionItem>[];

    for (var tx in result.transactions) {
      int y = tx.date.year;
      int m = tx.date.month;
      int d = tx.date.day;
      int h = tx.date.hour;
      int min = tx.date.minute;

      if (hasExplicitDate) {
        if (y != expectedDate.year || m != expectedDate.month || d != expectedDate.day) {
          y = expectedDate.year;
          m = expectedDate.month;
          d = expectedDate.day;
          hasChanged = true;
        }
      }

      if (hasExplicitTime) {
        if (h != expectedDate.hour || min != expectedDate.minute) {
          h = expectedDate.hour;
          min = expectedDate.minute;
          hasChanged = true;
        }
      } else {
        // Người dùng không nói giờ cụ thể, nhưng nếu giờ đang là 00:00 (do parser ISO date tạo ra)
        // và người dùng không hề nói "0h" hay "12h đêm", ta gán giờ hiện tại của hệ thống!
        if (h == 0 && min == 0 && !userText.contains('0h') && !userText.contains('12h đêm')) {
          h = now.hour;
          min = now.minute;
          hasChanged = true;
        }
      }

      if (hasChanged) {
        updatedList.add(tx.copyWith(
          date: DateTime(y, m, d, h, min),
        ));
      } else {
        updatedList.add(tx);
      }
    }

    if (!hasChanged) return result;

    return AiParsedResult(
      aiReply: result.aiReply,
      transactions: updatedList,
      actionType: result.actionType,
      themeMode: result.themeMode,
      language: result.language,
      reportPeriod: result.reportPeriod,
      navigationTarget: result.navigationTarget,
      needsAmount: result.needsAmount,
      securityMessage: result.securityMessage,
      financialAdvice: result.financialAdvice,
      bankSmsResult: result.bankSmsResult,
      splitBillResult: result.splitBillResult,
      safeDailyResult: result.safeDailyResult,
      forecastResult: result.forecastResult,
      latteFactorResult: result.latteFactorResult,
      savingsRoadmapResult: result.savingsRoadmapResult,
      spendingQueryResult: result.spendingQueryResult,
      spendingTrendResult: result.spendingTrendResult,
      financialHealthScoreResult: result.financialHealthScoreResult,
      recurringDetectionResult: result.recurringDetectionResult,
      transferData: result.transferData,
      isSuccess: result.isSuccess,
    );
  }

  /// Hiệu chỉnh và bảo vệ ngữ nghĩa thông minh (Semantic Intent Guardrail)
  /// Đảm bảo không bao giờ nhận diện sai giữa Thu nhập (income) và Chi phí (expense),
  /// đặc biệt là câu có cấu trúc người khác cho tiền (VD: "phụng cho 15.000đ vào ví tiền mặt")
  AiParsedResult _applySmartSemanticGuardrail(AiParsedResult result, String originalText) {
    if (result.transactions.isEmpty) return result;

    final lower = originalText.toLowerCase().trim();

    final bool isGiveOutExpense = lower.contains('cho vay') ||
        lower.contains('cho mượn') ||
        lower.contains('cho bạn mượn') ||
        lower.contains('cho tiền ăn xin') ||
        lower.contains('cho người nghèo') ||
        lower.contains('chi cho') ||
        lower.contains('mua quà cho') ||
        lower.contains('mua cho') ||
        lower.contains('trả tiền cho') ||
        lower.contains('gửi cho') ||
        lower.contains('chuyển cho');

    final bool hasGivenBySomeone = !isGiveOutExpense && (
        RegExp(r'(?:^|\s)(?:[a-zà-ỹA-ZÀ-Ỹ0-9_]+)\s+cho\s+(?:\d|[\.,\d]+|tiền|vào ví|vào)', caseSensitive: false).hasMatch(originalText) ||
        RegExp(r'(?:^|\s)cho\s+(?:\d|[\.,\d]+)\s*(?:k|nghìn|ngàn|tr|triệu|củ|đ|đồng|vnd)?\s+vào\s+ví', caseSensitive: false).hasMatch(originalText) ||
        lower.contains('được cho') ||
        lower.contains('cho tiền') ||
        lower.contains('ai cho') ||
        lower.contains('người ta cho') ||
        lower.contains('mẹ cho') ||
        lower.contains('bố cho') ||
        lower.contains('ba cho') ||
        lower.contains('bạn cho') ||
        lower.contains('anh cho') ||
        lower.contains('chị cho') ||
        lower.contains('em cho') ||
        lower.contains('sếp cho') ||
        lower.contains('khách cho') ||
        lower.contains('ông cho') ||
        lower.contains('bà cho') ||
        lower.contains('cô cho') ||
        lower.contains('chú cho') ||
        lower.contains('bác cho') ||
        lower.contains('người yêu cho') ||
        lower.contains('crush cho')
    );

    final bool hasCreditOrIncome = hasGivenBySomeone ||
        RegExp(r'(?:^|\s)(?:cộng|nạp|thu|nhận)\s+(?:\d|[\.,\d]+)', caseSensitive: false).hasMatch(originalText) ||
        RegExp(r'(?:^|\s)cộng\s+.*?(?:vào|sang)\s+(?:ví)?', caseSensitive: false).hasMatch(originalText) ||
        lower.contains('tiền lãi') ||
        lower.contains('lãi tiết kiệm') ||
        lower.contains('lãi suất') ||
        lower.contains('tiền lời') ||
        lower.contains('tiền thưởng') ||
        lower.contains('tiền lương') ||
        lower.contains('lãnh lương') ||
        lower.contains('hoàn tiền');

    if (!hasCreditOrIncome) {
      return result;
    }

    final bool isExplicitExpense = lower.contains('uống') ||
        lower.contains('ăn') ||
        lower.contains('mua') ||
        lower.contains('chi') ||
        lower.contains('tiêu') ||
        lower.contains('trả tiền') ||
        lower.contains('đổ xăng') ||
        lower.contains('đi grab') ||
        lower.contains('đi chợ') ||
        lower.contains('cafe') ||
        lower.contains('cà phê');

    final bool hasExplicitIncomeSignal = hasGivenBySomeone ||
        lower.contains('được cộng') ||
        lower.contains('cộng vào') ||
        lower.contains('cộng thêm') ||
        lower.contains('tiền lương') ||
        lower.contains('lãnh lương') ||
        lower.contains('tiền thưởng') ||
        lower.contains('tiền lãi') ||
        lower.contains('hoàn tiền');

    if (isExplicitExpense && !hasExplicitIncomeSignal) {
      return result;
    }

    String detectedWallet = '';
    if (lower.contains('tiền mặt')) {
      detectedWallet = 'Tiền mặt';
    } else if (lower.contains('momo') || lower.contains('mono')) {
      detectedWallet = 'MoMo';
    } else if (lower.contains('zalopay')) {
      detectedWallet = 'ZaloPay';
    } else if (lower.contains('ngân hàng') ||
        lower.contains('vietcombank') ||
        lower.contains('mbbank') ||
        lower.contains('techcombank') ||
        lower.contains('bidv')) {
      detectedWallet = 'Ngân hàng';
    }

    bool hasChanged = false;
    final updatedList = <AiTransactionItem>[];

    for (var tx in result.transactions) {
      final shouldBeIncome = tx.type == 'expense' || tx.category == 'Chi khác' || tx.category == 'Ăn uống';
      String targetCategory;
      if (hasGivenBySomeone) {
        targetCategory = 'Được cho/Tặng';
      } else if (lower.contains('lãi')) {
        targetCategory = 'Tiền lãi';
      } else if (lower.contains('lương')) {
        targetCategory = 'Tiền lương';
      } else if (lower.contains('thưởng')) {
        targetCategory = 'Tiền thưởng';
      } else {
        targetCategory = tx.category.isNotEmpty && tx.category != 'Chi khác' && tx.category != 'Ăn uống'
            ? tx.category
            : 'Thu khác';
      }

      final targetWallet = tx.walletName.isNotEmpty ? tx.walletName : detectedWallet;
      final iconData = CategoryUtils.getCategoryIcon(targetCategory);

      String desc = tx.description;
      if (desc.isEmpty || desc.toLowerCase().startsWith('cộng ') || desc.toLowerCase().contains('không xác định')) {
        desc = targetCategory;
      }

      if (shouldBeIncome || tx.category != targetCategory || (targetWallet.isNotEmpty && tx.walletName.isEmpty)) {
        hasChanged = true;
        updatedList.add(tx.copyWith(
          type: 'income',
          category: targetCategory,
          categoryIconCode: iconData.codePoint,
          description: desc,
          walletName: targetWallet,
        ));
      } else {
        updatedList.add(tx);
      }
    }

    if (!hasChanged) return result;

    final firstTx = updatedList.first;
    final formattedStr = CurrencyUtils.formatCurrency(firstTx.amount);
    final walletPart = firstTx.walletName.isNotEmpty ? ' vào ví **${firstTx.walletName}**' : '';

    final newReply = '✨ Mono đã ghi nhận khoản thu **$formattedStr** cho "${firstTx.description}"$walletPart vào sổ của bạn rồi nhé! 💰\n\n'
        '• Số tiền: **$formattedStr**\n'
        '• Danh mục: **${firstTx.category}**\n'
        '${firstTx.walletName.isNotEmpty ? '• Ví nhận: **${firstTx.walletName}**\n' : ''}\n'
        '🎯 Mono luôn sẵn sàng đồng hành quản lý tài chính cùng bạn!';

    return AiParsedResult(
      aiReply: newReply,
      transactions: updatedList,
      actionType: result.actionType,
      themeMode: result.themeMode,
      language: result.language,
      reportPeriod: result.reportPeriod,
      navigationTarget: result.navigationTarget,
      needsAmount: result.needsAmount,
      securityMessage: result.securityMessage,
      financialAdvice: result.financialAdvice,
      bankSmsResult: result.bankSmsResult,
      splitBillResult: result.splitBillResult,
      safeDailyResult: result.safeDailyResult,
      forecastResult: result.forecastResult,
      latteFactorResult: result.latteFactorResult,
      savingsRoadmapResult: result.savingsRoadmapResult,
      spendingQueryResult: result.spendingQueryResult,
      spendingTrendResult: result.spendingTrendResult,
      financialHealthScoreResult: result.financialHealthScoreResult,
      recurringDetectionResult: result.recurringDetectionResult,
      transferData: result.transferData,
      isSuccess: result.isSuccess,
      errorMessage: result.errorMessage,
    );
  }

  @visibleForTesting
  AiParsedResult parseJsonFromAiTextForTesting(String rawText) {
    return _parseJsonFromAiText(rawText);
  }
}
