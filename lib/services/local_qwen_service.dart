import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_config_service.dart';
import 'gemini_ai_service.dart';
import 'ai_financial_context_service.dart';
import '../utils/category_utils.dart';

/// Dịch vụ Trí tuệ Nhân tạo Local chuyên biệt cho Mô hình Qwen 2.5 1.5B-Instruct
/// - Hỗ trợ suy luận cục bộ (Local On-Device / Local Host Bridge)
/// - Bảo mật dữ liệu tài chính 100%, không gửi dữ liệu ra máy chủ bên ngoài
/// - Fallback mượt mà sang Bộ máy Quy tắc Ngữ nghĩa Ngoại tuyến (Instant Heuristics) khi không có mạng
class LocalQwenService {
  static final LocalQwenService _instance = LocalQwenService._internal();
  factory LocalQwenService() => _instance;
  LocalQwenService._internal();

  final AiConfigService _configService = AiConfigService();
  http.Client? _customClient;
  http.Client get _client => _customClient ??= http.Client();

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

  /// Kiểm tra trạng thái kết nối tới Mô hình Local Qwen 2.5
  Future<Map<String, dynamic>> testConnection({String? customEndpoint, String? customModel}) async {
    await _configService.init();
    final endpoint = customEndpoint?.trim().isNotEmpty == true
        ? customEndpoint!.trim()
        : _configService.localEndpoint;
    final model = customModel?.trim().isNotEmpty == true
        ? customModel!.trim()
        : _configService.localModelName;

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$endpoint/api/generate');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': 'ping',
          'stream': false,
          'options': {
            'num_predict': 5,
            'temperature': 0.1,
          }
        }),
      ).timeout(const Duration(seconds: 4));

      stopwatch.stop();

      if (response.statusCode == 200) {
        return {
          'success': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'model': model,
          'message': 'Đã kết nối thành công với Qwen 2.5 ($model)!\nThời gian phản hồi: ${stopwatch.elapsedMilliseconds}ms ⚡',
        };
      } else {
        return {
          'success': false,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'model': model,
          'message': 'Máy chủ phản hồi mã lỗi HTTP ${response.statusCode}. Vui lòng kiểm tra lại endpoint.',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'model': model,
        'message': 'Không thể kết nối tới $endpoint. Trợ lý Mono sẽ kích hoạt Chế độ Tự động Ngoại tuyến (Offline Rule Engine) với 0ms độ trễ.',
      };
    }
  }

  /// Gửi trực tiếp tới Local Qwen Endpoint qua ChatML
  Future<AiParsedResult?> queryLocalQwen(
    String prompt, {
    List<Map<String, String>>? conversationHistory,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return null;

    await _configService.init();
    final model = _configService.localModelName;
    final endpoint = _configService.localEndpoint;

    try {
      final now = DateTime.now();
      final localIsoTime = now.toIso8601String().substring(0, 19);
      final financialContext = await AiFinancialContextService().buildFinancialContextPrompt();

      final systemPrompt = '''
Bạn là Trợ lý Mono - Trí tuệ Nhân tạo Quản lý Chi tiêu Cá nhân thông minh, thân thiện, bảo mật hoạt động ngay trên thiết bị.
THỜI GIAN THỰC TẾ HỆ THỐNG: $localIsoTime (Năm ${now.year}, Tháng ${now.month}, Ngày ${now.day}, Giờ ${now.hour}:${now.minute.toString().padLeft(2, '0')}).

$financialContext

NHIỆM VỤ CHÍNH:
1. Ghi chép thu/chi tự nhiên: Trích xuất chính xác "amount", "type" (expense hoặc income), "category", "description", "walletName", "date" (chuẩn ISO-8601 YYYY-MM-DDTHH:mm:ss). Đặt intent = "RECORD_TRANSACTION", actionType = "recordTransaction".
   - KHOẢN THU (type = "income"): Khi câu nói có từ khóa nạp tiền, cộng tiền, tiền lãi, lương, thưởng, được cho ("cộng 11đ tiền lãi vào ví momo", "lãi tiết kiệm", "nạp tiền", "+50k") -> type = "income". Với các câu tiền lãi, đặt category = "Tiền lãi", description = "Tiền lãi".
2. Chuyển tiền / Rút tiền giữa các ví ("Chuyển 500k từ ví Momo sang Techcombank", "Rút 2 triệu từ ATM về tiền mặt"):
   - Đặt intent = "TRANSFER_MONEY", actionType = "transferMoney".
   - Trả về đối tượng "transfer" gồm: "amount", "source_wallet", "target_wallet", "fee", "note".
   - Để "transactions": [].
3. Đàm thoại, chào hỏi, tâm sự & mẹo tiết kiệm: Trả lời tự nhiên, hóm hỉnh dưới 3 câu kèm emoji. Đặt intent = "GENERAL_CHAT", actionType = "generalChat", "transactions": [].
4. Điều khiển & Tra cứu ứng dụng:
   - Tra cứu chi tiêu theo mốc thời gian ("hôm nay đã tiêu gì", "mức chi tiêu 3 ngày qua"): actionType = "spendingQuery"
   - Đổi giao diện tối/sáng: actionType = "changeTheme"
   - Báo cáo tài chính tổng quan: actionType = "spendingReport"
   - Tư vấn tài chính, phân bổ lương 50/30/20: actionType = "financialAdvice"

BẮT BUỘC TRẢ VỀ DUY NHẤT 1 ĐỐI TƯỢNG JSON HỢP LỆ VỚI CẤU TRÚC SAU:
{
  "aiReply": "Lời phản hồi thân thiện, ngắn gọn của Mono",
  "intent": "RECORD_TRANSACTION | TRANSFER_MONEY | GENERAL_CHAT | FINANCIAL_ADVICE | SPENDING_REPORT | SPENDING_QUERY | CHANGE_THEME",
  "actionType": "recordTransaction | transferMoney | changeTheme | changeLanguage | spendingReport | spendingQuery | financialAdvice | generalChat",
  "themeMode": "dark | light | system",
  "language": "vi | en",
  "reportPeriod": "today | week | month | year",
  "needsAmount": false,
  "transfer": {
    "amount": 500000,
    "source_wallet": "MoMo",
    "target_wallet": "Techcombank",
    "fee": 0,
    "note": "Chuyển tiền sang Techcombank"
  },
  "transactions": [
    {
      "type": "income | expense",
      "category": "Ăn uống | Mua sắm | Di chuyển | Hóa đơn | Học tập | Sức khỏe | Giải trí | Tiết kiệm | Lương | Thưởng | Tiền lãi | Được cho/Tặng | Thu khác | Chi khác",
      "amount": 35000,
      "description": "ăn bún bò",
      "date": "$localIsoTime",
      "walletName": "MoMo"
    }
  ]
}
''';

      final List<Map<String, String>> messages = [];
      messages.add({'role': 'system', 'content': systemPrompt});

      // Thêm ngữ cảnh lịch sử trò chuyện đa vòng (Sliding Window 8-10 turns)
      final hist = conversationHistory ?? _conversationHistory;
      final recentTurns = hist.length > 8 ? hist.sublist(hist.length - 8) : hist;
      for (final m in recentTurns) {
        final r = m['role'] == 'user' ? 'user' : 'assistant';
        messages.add({'role': r, 'content': m['text'] ?? ''});
      }

      messages.add({'role': 'user', 'content': trimmed});

      final chatUri = Uri.parse('$endpoint/api/chat');
      final res = await _client.post(
        chatUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'stream': false,
          'format': 'json',
          'options': {
            'temperature': 0.2,
            'top_p': 0.8,
            'num_predict': 512,
          },
        }),
      ).timeout(const Duration(milliseconds: 1800));

      if (res.statusCode == 200) {
        final jsonRes = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final messageContent = jsonRes['message']?['content'] as String? ?? '';

        if (messageContent.isNotEmpty) {
          final parsed = _parseQwenJsonResponse(messageContent, trimmed);
          if (parsed != null && parsed.isSuccess) {
            addToHistory('user', trimmed);
            addToHistory('assistant', parsed.aiReply);
            return parsed;
          }
        }
      }
    } catch (e) {
      debugPrint('LocalQwenService: Endpoint unreachable ($e).');
    }
    return null;
  }

  /// Phân tích câu nói / câu lệnh tự nhiên bằng Qwen 2.5 1.5B (với Fallback Ngoại tuyến 0ms)
  Future<AiParsedResult> parseNaturalLanguage(
    String prompt, {
    List<Map<String, String>>? conversationHistory,
    AiTransactionItem? pendingTransaction,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return AiParsedResult.error('Vui lòng nhập nội dung.');
    }

    // 1. Thử gửi tới Local Qwen Endpoint nếu có thể kết nối
    final qwenRes = await queryLocalQwen(trimmed, conversationHistory: conversationHistory);
    if (qwenRes != null && qwenRes.isSuccess) {
      return qwenRes;
    }

    // 2. Chế độ Ngoại tuyến tức thì (Offline Instant Engine - 0ms):
    // Sử dụng bộ parser tiếng Việt chuyên sâu đã được kiểm chứng tuyệt đối
    return GeminiAiService().handleLocalOfflineFallback(trimmed, pendingTransaction: pendingTransaction);
  }

  /// Trích xuất và chuẩn hóa JSON từ output của Qwen 2.5
  AiParsedResult? _parseQwenJsonResponse(String rawOutput, String userPrompt) {
    try {
      String jsonStr = rawOutput.trim();
      // Bóc tách JSON nếu model bọc trong ```json
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final aiReply = (data['aiReply'] as String? ?? '').trim();
      final actionTypeStr = data['actionType'] as String? ?? 'recordTransaction';
      final themeMode = data['themeMode'] as String?;
      final language = data['language'] as String?;
      final reportPeriod = data['reportPeriod'] as String?;
      final needsAmount = data['needsAmount'] as bool? ?? false;

      TransferMoneyData? transferData;
      if (data['transfer'] is Map<String, dynamic>) {
        final tMap = data['transfer'] as Map<String, dynamic>;
        final amount = (tMap['amount'] as num?)?.toDouble() ?? 0.0;
        final fee = (tMap['fee'] as num?)?.toDouble() ?? 0.0;
        transferData = TransferMoneyData(
          amount: amount,
          sourceWalletName: (tMap['source_wallet'] ?? tMap['from_wallet'] ?? '').toString(),
          targetWalletName: (tMap['target_wallet'] ?? tMap['to_wallet'] ?? '').toString(),
          fee: fee,
          note: (tMap['note'] ?? '').toString(),
        );
      }

      AiActionType actionType = AiActionType.recordTransaction;
      if (actionTypeStr == 'transferMoney' || data['intent'] == 'TRANSFER_MONEY' || transferData != null) {
        actionType = AiActionType.transferMoney;
      } else if (actionTypeStr == 'changeTheme') {
        actionType = AiActionType.changeTheme;
      } else if (actionTypeStr == 'changeLanguage') {
        actionType = AiActionType.changeLanguage;
      } else if (actionTypeStr == 'spendingReport') {
        actionType = AiActionType.spendingReport;
      } else if (actionTypeStr == 'spendingQuery') {
        actionType = AiActionType.spendingQuery;
      } else if (actionTypeStr == 'financialAdvice') {
        actionType = AiActionType.financialAdvice;
      } else if (actionTypeStr == 'generalChat') {
        actionType = AiActionType.generalChat;
      }

      final rawTxs = data['transactions'] as List<dynamic>? ?? [];
      final List<AiTransactionItem> txList = [];

      for (final txMap in rawTxs) {
        if (txMap is Map<String, dynamic>) {
          final type = (txMap['type'] as String? ?? 'expense').toLowerCase();
          final category = txMap['category'] as String? ?? 'Chi khác';
          final amount = (txMap['amount'] as num?)?.toDouble() ?? 0.0;
          final description = txMap['description'] as String? ?? userPrompt;
          final walletName = txMap['walletName'] as String? ?? 'Tiền mặt';

          // Chuẩn hóa thời gian bằng bộ phân tích tiếng Việt
          DateTime finalDt = DateTime.now();
          if (txMap['date'] != null) {
            final parsedDt = DateTime.tryParse(txMap['date'].toString());
            if (parsedDt != null) {
              finalDt = parsedDt;
            }
          }

          // Áp dụng bảo vệ thời gian nếu thiếu giờ
          if (finalDt.hour == 0 && finalDt.minute == 0) {
            final now = DateTime.now();
            finalDt = DateTime(finalDt.year, finalDt.month, finalDt.day, now.hour, now.minute);
          }

          final iconCode = CategoryUtils.getCategoryIcon(category).codePoint;

          txList.add(AiTransactionItem(
            type: type == 'income' ? 'income' : 'expense',
            category: category,
            categoryIconCode: iconCode,
            amount: amount,
            description: description,
            date: finalDt,
            walletName: walletName,
          ));
        }
      }

      return AiParsedResult(
        aiReply: aiReply.isNotEmpty ? aiReply : 'Trợ lý Mono đã ghi nhận giao dịch của bạn! ✨',
        transactions: txList,
        actionType: actionType,
        themeMode: themeMode,
        language: language,
        reportPeriod: reportPeriod,
        needsAmount: needsAmount,
        transferData: transferData,
      );
    } catch (e) {
      debugPrint('LocalQwenService: Lỗi parse JSON output: $e');
      return null;
    }
  }
}
