import '../../services/language_service.dart';
import '../../core/theme/app_theme.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/receipt_storage_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/ai_config_service.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/voice_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/ai_action_handler.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../services/transaction_balance_service.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_format_utils.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/animated_scale_button.dart';
import '../../widgets/top_toast.dart';
import '../../widgets/mono_dialog.dart';
import '../../widgets/voice_waveform.dart';
import '../../services/smart_notification_service.dart';
import '../budget/budget_and_goals_screen.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/security_screen.dart';
import '../home/statistics_screen.dart';
import '../transaction/add_transaction_screen.dart';
import '../transaction/transaction_detail_screen.dart';
import '../transaction/all_transactions_screen.dart';
import 'widgets/mono_assistant_cards.dart';
import '../../services/bank_sms_parser_service.dart';
import '../../services/group_bill_split_service.dart';
import '../../services/financial_advisor_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialVoiceText;
  final String? initialAction;

  const AiAssistantScreen({
    super.key,
    this.initialVoiceText,
    this.initialAction,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final String? imagePath;
  final List<AiTransactionItem>? transactions;
  final bool isPendingSaving;
  final bool needsAmount;
  final SpendingReportResult? spendingReport;
  final FinancialAdviceResult? financialAdvice;
  final bool isSecurityRestricted;
  final String? navigationTarget;
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
  final List<TransactionModel>? savedTransactions;
  final TransferCardData? transferCardData;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.imagePath,
    this.transactions,
    this.isPendingSaving = false,
    this.needsAmount = false,
    this.spendingReport,
    this.financialAdvice,
    this.isSecurityRestricted = false,
    this.navigationTarget,
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
    this.savedTransactions,
    this.transferCardData,
    this.isError = false,
  }) : time = time ?? DateTime.now();
}

class TransferCardData {
  final WalletModel fromWallet;
  final WalletModel toWallet;
  final double amount;
  final double fee;
  final String note;

  TransferCardData({
    required this.fromWallet,
    required this.toWallet,
    required this.amount,
    this.fee = 0.0,
    this.note = '',
  });
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  bool get isVi => LanguageService.instance.isVietnamese;
  final GeminiAiService _aiService = GeminiAiService();
  final VoiceService _voiceService = VoiceService();
  final AiConfigService _aiConfigService = AiConfigService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Timer? _silenceTimer;
  Timer? _recordingTimer;
  Timer? _countdownTicker;
  DateTime _lastVoiceActivity = DateTime.now();
  final ScrollController _voiceSpeechScrollController = ScrollController();
  int _recordingSeconds = 0;
  bool _showScrollToBottom = false;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;
  String _lastSentText = '';
  DateTime? _lastSentTime;

  // Trạng thái đếm ngược tự động lưu rảnh tay (Hands-free Auto-save)
  Timer? _autoSaveTimer;
  int _autoSaveCountdown = 0;
  List<AiTransactionItem>? _autoSavePendingTxs;

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  double _soundLevel = 0.0;
  List<WalletModel> _wallets = [];

  List<String> get _quickSuggestions => _getQuickSuggestions(isVi);
  List<String> _getQuickSuggestions(bool isVi) => isVi
      ? [
          '📈 Xu hướng chi tiêu tuần này',
          '🏆 Điểm sức khỏe tài chính',
          '🔄 Chi phí cố định định kỳ',
          '📊 Mỗi ngày được tiêu bao nhiêu?',
          '🔮 Dự báo số dư cuối tháng',
          '☕ Phân tích tiêu vặt thủng ví',
          '👥 Chia 600k cho 4 người',
          '🎯 Tiết kiệm 20 triệu mua xe',
          '🔍 Hôm nay đã tiêu bao nhiêu?',
          '💡 Tip tiết kiệm cho tôi',
          '🍜 Ăn bún bò 35k ví MoMo',
          '💰 Số tiền còn lại nên làm gì?',
          '🌙 Chuyển giao diện tối',
        ]
      : [
          '📈 Spending trends this week',
          '🏆 Financial health score',
          '🔄 Recurring fixed costs',
          '📊 Daily safe to spend',
          '🔮 End-of-month balance forecast',
          '☕ Latte factor analysis',
          '👥 Split \$60 for 4 people',
          '🎯 Save \$2000 for motorcycle',
          '🔍 How much did I spend today?',
          '💡 Saving tips for me',
          '🍜 Lunch \$15 Cash',
          '💰 What to do with savings?',
          '🌙 Switch to dark mode',
        ];

  @override
  void initState() {
    super.initState();
    _loadWallets();
    _isOnline = _connectivityService.isOnline;
    _connectivitySub = _connectivityService.onlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final show =
            (_scrollController.position.maxScrollExtent -
                _scrollController.offset) >
            300;
        if (show != _showScrollToBottom) {
          setState(() => _showScrollToBottom = show);
        }
      }
    });
    final isVi = LanguageService.instance.isVietnamese;
    _messages.add(
      _ChatMessage(
        text: isVi
            ? 'Xin chào! Tôi là Trợ lý Mono 🤖.\nToàn bộ dữ liệu thu chi & số dư của bạn được bảo mật tuyệt đối 100% trên thiết bị!\n\nBạn có thể:\n• Nhập/nói tự nhiên (VD: "Ăn bún bò 35k ví MoMo", "Hôm nay được cộng thêm 36đ")\n• Điều khiển app & báo cáo: "Bật chế độ tối", "Báo cáo chi tiêu tháng này"\n• Chụp hóa đơn/biên lai để bóc tách tự động!'
            : 'Hello! I am Mono Assistant 🤖.\nAll your income, expense and balance data is 100% securely kept on your device!\n\nYou can:\n• Type or speak naturally (e.g. "Lunch \$15 Cash", "Salary \$3000")\n• App commands & reports: "Turn on dark mode", "Monthly spending report"\n• Scan receipts for automatic parsing!',
        isUser: false,
      ),
    );

    if (widget.initialVoiceText != null &&
        widget.initialVoiceText!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialVoiceText!);
      });
    } else if (widget.initialAction == 'voice') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleVoiceInput();
      });
    } else if (widget.initialAction == 'scanReceipt') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePickImage(ImageSource.camera);
      });
    }
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await WalletRepository().getWallets();
      if (mounted) setState(() => _wallets = wallets);
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _silenceTimer?.cancel();
    _recordingTimer?.cancel();
    _countdownTicker?.cancel();
    _autoSaveTimer?.cancel();
    _voiceSpeechScrollController.dispose();
    _voiceService.cancelListening();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Bắt đầu đếm ngược tự động lưu rảnh tay 3 giây (Hands-free Auto-save)
  void _startAutoSaveCountdown(List<AiTransactionItem> txs) {
    _autoSaveTimer?.cancel();
    _autoSavePendingTxs = txs;
    setState(() {
      _autoSaveCountdown = 3;
    });

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_autoSaveCountdown <= 1) {
        timer.cancel();
        setState(() {
          _autoSaveCountdown = 0;
        });
        if (_autoSavePendingTxs != null && _autoSavePendingTxs!.isNotEmpty) {
          _saveAllTransactions(_autoSavePendingTxs!);
          _autoSavePendingTxs = null;
        }
      } else {
        setState(() {
          _autoSaveCountdown--;
        });
      }
    });
  }

  /// Hủy bỏ đếm ngược tự động lưu rảnh tay
  void _cancelAutoSave() {
    _autoSaveTimer?.cancel();
    setState(() {
      _autoSaveCountdown = 0;
      _autoSavePendingTxs = null;
    });
  }

  /// Dán tin nhắn biến động số dư hoặc nội dung từ Clipboard
  Future<void> _handlePasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (mounted) {
          final isVi = LanguageService.instance.isVietnamese;
          TopToast.show(
            context,
            isVi ? 'Bộ nhớ tạm (Clipboard) trống!' : 'Clipboard is empty!',
          );
        }
        return;
      }
      _inputController.text = text;
      _handleSendMessage(text);
    } catch (e) {
      if (mounted) {
        final isVi = LanguageService.instance.isVietnamese;
        TopToast.show(
          context,
          isVi ? 'Không thể đọc bộ nhớ tạm: $e' : 'Cannot read clipboard: $e',
          isError: true,
        );
      }
    }
  }

  WalletModel? _fuzzyMatchWallet(String query, List<WalletModel> wallets) {
    if (query.trim().isEmpty || wallets.isEmpty) return null;
    final lowerRaw = query.toLowerCase().trim();
    final cleanQuery = lowerRaw
        .replaceAll(RegExp(r'\b(ví|tài khoản|tk|ngân hàng|sổ)\b'), '')
        .trim();

    // 1. So khớp chính xác tên hoặc tên ngân hàng
    for (final w in wallets) {
      if (w.name.toLowerCase() == cleanQuery ||
          w.bankName.toLowerCase() == cleanQuery ||
          w.name.toLowerCase() == lowerRaw ||
          w.bankName.toLowerCase() == lowerRaw) {
        return w;
      }
    }

    // 2. So khớp chứa chuỗi (contains)
    for (final w in wallets) {
      final wName = w.name.toLowerCase();
      final bName = w.bankName.toLowerCase();
      if ((cleanQuery.isNotEmpty &&
              (wName.contains(cleanQuery) || cleanQuery.contains(wName))) ||
          (bName.isNotEmpty &&
              (cleanQuery.isNotEmpty && bName.contains(cleanQuery)))) {
        return w;
      }
    }

    // 3. Phân biệt rõ ràng ATM / Ngân hàng vs Tiền mặt:
    // "atm", "ngân hàng", "bank" -> ưu tiên ví loại Bank hoặc ví có tên ngân hàng
    if (cleanQuery.contains('atm') ||
        cleanQuery.contains('bank') ||
        lowerRaw.contains('ngân hàng')) {
      for (final w in wallets) {
        if (w.type == WalletType.bank ||
            w.name.toLowerCase().contains('ngân hàng') ||
            w.name.toLowerCase().contains('bank')) {
          return w;
        }
      }
    }

    // "tiền mặt", "cash", "mặt" -> ưu tiên ví loại Cash
    if (cleanQuery.contains('tiền mặt') ||
        cleanQuery == 'mặt' ||
        cleanQuery.contains('cash')) {
      for (final w in wallets) {
        if (w.type == WalletType.cash ||
            w.name.toLowerCase().contains('tiền mặt') ||
            w.name.toLowerCase().contains('cash')) {
          return w;
        }
      }
    }

    // 4. Các ví điện tử & ngân hàng phổ biến tại Việt Nam
    if (cleanQuery.contains('momo') || cleanQuery.contains('mono')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('momo') ||
            w.name.toLowerCase().contains('mono'))
          return w;
      }
    }
    if (cleanQuery.contains('zalo')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('zalo')) return w;
      }
    }
    if (cleanQuery.contains('tech') || cleanQuery.contains('tcb')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('tech') ||
            w.bankName.toLowerCase().contains('tech'))
          return w;
      }
    }
    if (cleanQuery.contains('vcb') || cleanQuery.contains('vietcom')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('vietcom') ||
            w.bankName.toLowerCase().contains('vietcom'))
          return w;
      }
    }
    if (cleanQuery.contains('mb') || cleanQuery.contains('mbbank')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('mb') ||
            w.bankName.toLowerCase().contains('mb'))
          return w;
      }
    }
    if (cleanQuery.contains('bidv')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('bidv') ||
            w.bankName.toLowerCase().contains('bidv'))
          return w;
      }
    }
    if (cleanQuery.contains('acb')) {
      for (final w in wallets) {
        if (w.name.toLowerCase().contains('acb') ||
            w.bankName.toLowerCase().contains('acb'))
          return w;
      }
    }

    return null;
  }

  Future<void> _handleSendMessage(String text) async {
    _cancelAutoSave();
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    final now = DateTime.now();
    if (_lastSentText == query &&
        _lastSentTime != null &&
        now.difference(_lastSentTime!).inMilliseconds < 1500) {
      debugPrint(
        'AI Assistant: Bỏ qua tin nhắn trùng lặp gửi quá nhanh: "$query"',
      );
      return;
    }
    _lastSentText = query;
    _lastSentTime = now;

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final textMessages = _messages
        .where((m) => m.text.isNotEmpty && m.imagePath == null)
        .toList();
    final slidingWindow = textMessages.length > 10
        ? textMessages.sublist(textMessages.length - 10)
        : textMessages;

    final history = slidingWindow
        .map((m) => {'role': m.isUser ? 'user' : 'model', 'text': m.text})
        .toList();

    // Multi-turn context: Tìm giao dịch đang chờ hoàn thiện (needsAmount hoặc pending) từ tin nhắn AI gần nhất
    AiTransactionItem? pendingTx;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (!m.isUser &&
          m.transactions != null &&
          m.transactions!.isNotEmpty &&
          (m.needsAmount || m.isPendingSaving)) {
        pendingTx = m.transactions!.first;
        break;
      }
    }

    final result = await _aiService.parseNaturalLanguage(
      query,
      conversationHistory: history,
      pendingTransaction: pendingTx,
    );

    // Xử lý các tác vụ điều khiển ứng dụng
    SpendingReportResult? reportResult;
    FinancialAdviceResult? adviceResult = result.financialAdvice;

    if (result.actionType == AiActionType.changeTheme &&
        result.themeMode != null) {
      await AiActionHandler().changeTheme(result.themeMode!);
    } else if (result.actionType == AiActionType.changeLanguage &&
        result.language != null) {
      await AiActionHandler().changeLanguage(result.language!);
    } else if (result.actionType == AiActionType.spendingReport) {
      reportResult = await AiActionHandler().generateSpendingReport(
        result.reportPeriod ?? 'today',
      );
    } else if (result.actionType == AiActionType.financialAdvice) {
      adviceResult ??= await AiActionHandler().generateFinancialAdvice(
        specificQuery: query,
      );
    } else if (result.actionType == AiActionType.navigateScreen &&
        result.navigationTarget != null) {
      if (mounted) {
        AiActionHandler().navigateToScreen(context, result.navigationTarget!);
      }
    }

    PersonalSpendingQueryResult? spendingQueryResult =
        result.spendingQueryResult;
    if (result.actionType == AiActionType.spendingQuery) {
      spendingQueryResult ??= await FinancialAdvisorService()
          .queryPersonalSpending(query);
    }

    // Xử lý hành động Chuyển / Rút tiền giữa các ví (Transfer / Withdraw)
    TransferCardData? transferCardData;
    if (result.actionType == AiActionType.transferMoney ||
        result.transferData != null) {
      final tData = result.transferData;
      if (tData != null && tData.amount > 0) {
        final walletsList = _wallets.isNotEmpty
            ? _wallets
            : WalletRepository().latestWallets;
        WalletModel? fromW = _fuzzyMatchWallet(
          tData.sourceWalletName,
          walletsList,
        );
        WalletModel? toW = _fuzzyMatchWallet(
          tData.targetWalletName,
          walletsList,
        );

        if (fromW == null && walletsList.isNotEmpty) {
          try {
            fromW = walletsList.firstWhere((w) => w.isDefault);
          } catch (_) {
            fromW = walletsList.first;
          }
        }
        if (toW == null && walletsList.length > 1) {
          try {
            toW = walletsList.firstWhere((w) => w.id != fromW?.id);
          } catch (_) {
            toW = walletsList.last;
          }
        }

        // Đảm bảo không trùng ví nếu người dùng có ít nhất 2 ví
        if (fromW != null &&
            toW != null &&
            fromW.id == toW.id &&
            walletsList.length > 1) {
          try {
            toW = walletsList.firstWhere((w) => w.id != fromW?.id);
          } catch (_) {}
        }

        if (fromW != null && toW != null && fromW.id != toW.id) {
          transferCardData = TransferCardData(
            fromWallet: fromW,
            toWallet: toW,
            amount: tData.amount,
            fee: tData.fee,
            note: tData.note,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.isSuccess) {
        final hasTxs = result.transactions.isNotEmpty;
        final displayReply =
            (reportResult != null &&
                (result.aiReply.isEmpty ||
                    result.aiReply.contains('Đang tổng hợp')))
            ? reportResult.summaryText
            : (spendingQueryResult != null &&
                  (result.aiReply.isEmpty ||
                      result.aiReply.contains('Đang tra cứu') ||
                      result.aiReply.contains('Đang hoạt động Ngoại tuyến')))
            ? spendingQueryResult.answerText
            : (adviceResult != null &&
                  (result.aiReply.isEmpty ||
                      result.aiReply.contains('Đang hoạt động Ngoại tuyến')))
            ? adviceResult.summaryText
            : result.aiReply;
        await _addAiMessageWithTypingEffect(
          fullText: displayReply,
          transactions: hasTxs ? result.transactions : null,
          isPendingSaving: hasTxs && !result.needsAmount,
          needsAmount: result.needsAmount,
          spendingReport: reportResult,
          financialAdvice: adviceResult,
          isSecurityRestricted:
              result.actionType == AiActionType.securityRestricted,
          navigationTarget: result.actionType == AiActionType.navigateScreen
              ? result.navigationTarget
              : null,
          bankSmsResult: result.bankSmsResult,
          splitBillResult: result.splitBillResult,
          safeDailyResult: result.safeDailyResult,
          forecastResult: result.forecastResult,
          latteFactorResult: result.latteFactorResult,
          savingsRoadmapResult: result.savingsRoadmapResult,
          spendingQueryResult:
              spendingQueryResult ?? result.spendingQueryResult,
          spendingTrendResult: result.spendingTrendResult,
          financialHealthScoreResult: result.financialHealthScoreResult,
          recurringDetectionResult: result.recurringDetectionResult,
          transferCardData: transferCardData,
        );

        // Nếu người dùng nhập/nói ra khoản tiền hoàn chỉnh -> kích hoạt đếm ngược tự động lưu rảnh tay 3s!
        if (hasTxs &&
            !result.needsAmount &&
            result.transactions.first.amount > 0) {
          _startAutoSaveCountdown(result.transactions);
        }
      } else {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  result.errorMessage ??
                  (LanguageService.instance.isVietnamese
                      ? 'Trợ lý Mono hiện chưa thể xử lý yêu cầu lúc này. Bạn vui lòng thử lại nhé! ✨'
                      : 'Mono Assistant cannot process your request right now. Please try again! ✨'),
              isUser: false,
              isError: true,
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  /// Gửi lại yêu cầu gần nhất của người dùng khi gặp lỗi
  void _retryLastUserMessage() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser && _messages[i].text.trim().isNotEmpty) {
        _handleSendMessage(_messages[i].text);
        return;
      }
    }
  }

  /// Thêm tin nhắn của AI với hiệu ứng chữ gõ mượt mà (Typing Animation)
  Future<void> _addAiMessageWithTypingEffect({
    required String fullText,
    List<AiTransactionItem>? transactions,
    bool isPendingSaving = false,
    bool needsAmount = false,
    SpendingReportResult? spendingReport,
    FinancialAdviceResult? financialAdvice,
    bool isSecurityRestricted = false,
    String? navigationTarget,
    BankSmsParseResult? bankSmsResult,
    GroupBillSplitResult? splitBillResult,
    SafeDailySpendResult? safeDailyResult,
    MonthEndForecastResult? forecastResult,
    LatteFactorResult? latteFactorResult,
    SavingsRoadmapResult? savingsRoadmapResult,
    PersonalSpendingQueryResult? spendingQueryResult,
    SpendingTrendResult? spendingTrendResult,
    FinancialHealthScoreResult? financialHealthScoreResult,
    RecurringDetectionResult? recurringDetectionResult,
    TransferCardData? transferCardData,
  }) async {
    // Nếu tin nhắn có thẻ giao dịch, thẻ tính năng hoặc ngắn (<= 60 ký tự), hiển thị ngay không cần animation dài
    final hasRichCard =
        transactions != null ||
        transferCardData != null ||
        spendingReport != null ||
        financialAdvice != null ||
        bankSmsResult != null ||
        splitBillResult != null ||
        safeDailyResult != null ||
        forecastResult != null ||
        latteFactorResult != null ||
        savingsRoadmapResult != null ||
        spendingQueryResult != null ||
        spendingTrendResult != null ||
        financialHealthScoreResult != null ||
        recurringDetectionResult != null;

    if (fullText.length <= 60 || hasRichCard) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: fullText,
              isUser: false,
              transactions: transactions,
              isPendingSaving: isPendingSaving,
              needsAmount: needsAmount,
              spendingReport: spendingReport,
              financialAdvice: financialAdvice,
              isSecurityRestricted: isSecurityRestricted,
              navigationTarget: navigationTarget,
              bankSmsResult: bankSmsResult,
              splitBillResult: splitBillResult,
              safeDailyResult: safeDailyResult,
              forecastResult: forecastResult,
              latteFactorResult: latteFactorResult,
              savingsRoadmapResult: savingsRoadmapResult,
              spendingQueryResult: spendingQueryResult,
              spendingTrendResult: spendingTrendResult,
              financialHealthScoreResult: financialHealthScoreResult,
              recurringDetectionResult: recurringDetectionResult,
              transferCardData: transferCardData,
            ),
          );
        });
        _scrollToBottom();
      }
      return;
    }

    // Với các phản hồi văn bản dài: Hiệu ứng gõ chữ mượt mà 60fps
    final sanitizedFull = fullText
        .replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '')
        .replaceAll('```', '')
        .trim();

    final msgIndex = _messages.length;
    _messages.add(
      _ChatMessage(
        text: '',
        isUser: false,
        transactions: transactions,
        isPendingSaving: isPendingSaving,
        needsAmount: needsAmount,
        spendingReport: spendingReport,
        financialAdvice: financialAdvice,
        isSecurityRestricted: isSecurityRestricted,
        navigationTarget: navigationTarget,
        bankSmsResult: bankSmsResult,
        splitBillResult: splitBillResult,
        safeDailyResult: safeDailyResult,
        forecastResult: forecastResult,
        latteFactorResult: latteFactorResult,
        savingsRoadmapResult: savingsRoadmapResult,
        spendingQueryResult: spendingQueryResult,
        spendingTrendResult: spendingTrendResult,
        financialHealthScoreResult: financialHealthScoreResult,
        recurringDetectionResult: recurringDetectionResult,
        transferCardData: transferCardData,
      ),
    );
    if (mounted) setState(() {});
    _scrollToBottom();

    int i = 0;
    while (i < sanitizedFull.length) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 18));
      int next = (i + 4 < sanitizedFull.length) ? i + 4 : sanitizedFull.length;
      // Tránh ngắt giữa chừng cặp dấu sao **
      if (next < sanitizedFull.length &&
          (sanitizedFull[next] == '*' || sanitizedFull[next - 1] == '*')) {
        while (next < sanitizedFull.length && sanitizedFull[next] == '*') {
          next++;
        }
      }
      i = next;
      final currentPart = sanitizedFull.substring(0, i);
      if (mounted && msgIndex < _messages.length) {
        setState(() {
          _messages[msgIndex] = _ChatMessage(
            text: currentPart,
            isUser: false,
            transactions: transactions,
            isPendingSaving: isPendingSaving,
            needsAmount: needsAmount,
            spendingReport: spendingReport,
            financialAdvice: financialAdvice,
            isSecurityRestricted: isSecurityRestricted,
            navigationTarget: navigationTarget,
            bankSmsResult: bankSmsResult,
            splitBillResult: splitBillResult,
            safeDailyResult: safeDailyResult,
            forecastResult: forecastResult,
            latteFactorResult: latteFactorResult,
            savingsRoadmapResult: savingsRoadmapResult,
            spendingQueryResult: spendingQueryResult,
            spendingTrendResult: spendingTrendResult,
            financialHealthScoreResult: financialHealthScoreResult,
            recurringDetectionResult: recurringDetectionResult,
            transferCardData: transferCardData,
          );
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    if (!_isOnline) {
      final isVi = LanguageService.instance.isVietnamese;
      TopToast.show(
        context,
        isVi
            ? 'Cần kết nối mạng để quét ảnh hóa đơn!'
            : 'Internet connection required to scan receipts!',
        isError: true,
      );
      return;
    }
    try {
      final XFile? file = await BiometricService.instance
          .runWithPickerSuspended(() async {
            return await _picker.pickImage(
              source: source,
              imageQuality: 75,
              maxWidth: 1024,
              maxHeight: 1024,
            );
          });
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _messages.add(
          _ChatMessage(
            imagePath: file.path,
            text: LanguageService.instance.isVietnamese
                ? '📷 Hóa đơn đính kèm'
                : '📷 Receipt attached',
            isUser: true,
          ),
        );
        _isLoading = true;
      });
      _scrollToBottom();

      String mimeType = 'image/jpeg';
      final lowerPath = file.path.toLowerCase();
      if (lowerPath.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (lowerPath.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (lowerPath.endsWith('.heic')) {
        mimeType = 'image/heic';
      }

      final result = await _aiService.parseReceiptImage(
        bytes,
        mimeType: mimeType,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.isSuccess) {
            final defaultWalletName = _wallets.isNotEmpty
                ? _wallets.first.name
                : 'Tiền mặt';
            // Tự động gắn photoPath của hóa đơn vừa chụp và gán ví ban đầu nếu rỗng
            final txWithPhotos = result.transactions
                .map(
                  (tx) => tx.copyWith(
                    photoPath: file.path,
                    walletName: tx.walletName.isNotEmpty
                        ? tx.walletName
                        : defaultWalletName,
                  ),
                )
                .toList();

            final firstTx = txWithPhotos.isNotEmpty ? txWithPhotos.first : null;
            String promptText = result.aiReply;
            if (firstTx != null) {
              final store = firstTx.description.isNotEmpty
                  ? firstTx.description
                  : 'hóa đơn';
              final amt = CurrencyUtils.formatCurrency(firstTx.amount);
              final isVi = LanguageService.instance.isVietnamese;
              promptText = isVi
                  ? 'Đã quét hóa đơn từ $store: $amt.\nBạn vui lòng xác nhận ví thanh toán và ngày ghi nhận bên dưới nhé!'
                  : 'Scanned receipt from $store: $amt.\nPlease confirm payment wallet and date below!';
            }

            _messages.add(
              _ChatMessage(
                text: promptText,
                isUser: false,
                transactions: txWithPhotos,
                isPendingSaving: txWithPhotos.isNotEmpty,
              ),
            );

            // KHÔNG kích hoạt đếm ngược tự động lưu rảnh tay đối với hóa đơn ảnh
            // để người dùng chủ động chọn ví và xác nhận ngày trước khi lưu!
          } else {
            _messages.add(
              _ChatMessage(
                text:
                    result.errorMessage ??
                    (LanguageService.instance.isVietnamese
                        ? 'Không thể đọc được hóa đơn này. Bạn có thể chụp lại rõ hơn không?'
                        : 'Could not read this receipt. Could you take a clearer photo?'),
                isUser: false,
              ),
            );
          }
        });
        _scrollToBottom();

        // Tự động mở giao diện hỏi ý kiến người dùng về Ngày ghi nhận và Ví thanh toán
        if (result.isSuccess &&
            _messages.isNotEmpty &&
            _messages.last.transactions != null &&
            _messages.last.transactions!.isNotEmpty) {
          final pendingMsg = _messages.last;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showConfirmSaveReceiptSheet(pendingMsg);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopToast.show(context, '${context.tr('error')}: $e');
      }
    }
  }

  bool _isFinishingVoice = false;

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingSeconds = 0;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    TopToast.show(
      context,
      LanguageService.instance.isVietnamese
          ? 'Đã sao chép nội dung tin nhắn!'
          : 'Message copied to clipboard!',
    );
  }

  void _confirmClearChat() async {
    final isVi = LanguageScope.of(context).isVietnamese;
    final confirm = await MonoDialog.confirm(
      context,
      title: isVi ? 'Làm mới cuộc trò chuyện?' : 'Reset conversation?',
      message: isVi
          ? 'Tất cả tin nhắn trong phiên chat này sẽ được xóa để bắt đầu phiên mới.'
          : 'All messages in this chat session will be cleared to start anew.',
      cancelText: context.tr('cancel'),
      confirmText: isVi ? 'Xóa ngay' : 'Clear Now',
      isDestructive: true,
      icon: Icons.delete_sweep_rounded,
    );

    if (confirm == true && mounted) {
      _aiService.clearHistory();
      setState(() {
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text: isVi
                ? 'Xin chào! Tôi là Trợ lý Mono 🤖.\nToàn bộ dữ liệu thu chi & số dư của bạn được bảo mật tuyệt đối 100% trên thiết bị!\n\nBạn có thể:\n• Nhập/nói tự nhiên (VD: "Ăn bún bò 35k ví MoMo", "Hôm nay được cộng thêm 36đ")\n• Điều khiển app & báo cáo: "Bật chế độ tối", "Báo cáo chi tiêu tháng này"\n• Chụp hóa đơn/biên lai để bóc tách tự động!'
                : 'Hello! I am Mono Assistant 🤖.\nAll your income, expense and balance data is 100% securely kept on your device!\n\nYou can:\n• Type or speak naturally (e.g. "Lunch \$15 Cash", "Salary \$3000")\n• App commands & reports: "Turn on dark mode", "Monthly spending report"\n• Scan receipts for automatic parsing!',
            isUser: false,
          ),
        );
      });
      TopToast.show(
        context,
        isVi
            ? 'Đã làm mới cuộc trò chuyện!'
            : 'Conversation reset successfully!',
      );
    }
  }

  void _startContinuousCountdownTicker(int durationMs) {
    _countdownTicker?.cancel();
    _lastVoiceActivity = DateTime.now();

    // Chạy ngầm kiểm tra khoảng lặng mỗi 100ms, không re-render setState gây giật lag
    _countdownTicker = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || !_isListening) {
        timer.cancel();
        return;
      }

      final currentText = _inputController.text.trim();
      if (currentText.isEmpty) return;

      // Khi đã có văn bản nhận diện: đo lường thời gian trôi qua từ lần phát hiện giọng nói cuối cùng
      final elapsedSinceSpeech = DateTime.now()
          .difference(_lastVoiceActivity)
          .inMilliseconds;

      // TỰ ĐỘNG GỬI NGAY khi im lặng đủ thời gian durationMs (1.0s, 1.5s, 2.0s, etc.)
      if (elapsedSinceSpeech >= durationMs) {
        timer.cancel();
        debugPrint(
          'AI Assistant: Đã im lặng ${elapsedSinceSpeech}ms >= ${durationMs}ms -> Tự động gửi!',
        );
        _finishVoiceRecordingAndSend();
      }
    });
  }

  void _cancelCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
  }

  void _finishVoiceRecordingAndSend() async {
    _silenceTimer?.cancel();
    _countdownTicker?.cancel();
    _countdownTicker = null;
    _stopRecordingTimer();

    if (_isFinishingVoice) return;
    _isFinishingVoice = true;

    final capturedText = _inputController.text.trim();
    _inputController
        .clear(); // Xóa ngay lập tức để không bị sót lại trong ô chat
    final isAiMode = _voiceService.isAiVoiceMode;

    if (mounted) {
      setState(() {
        _isListening = false;
        if (isAiMode && capturedText.isEmpty) {
          _isLoading = true;
        }
      });
    }

    HapticFeedback.mediumImpact();

    if (capturedText.isNotEmpty) {
      // Trong chế độ STT trực tiếp: Có ngay text tiếng Việt, gửi NGAY LẬP TỨC không chờ unbind
      _voiceService.stopListening(); // Dừng mic ngầm non-blocking
      _handleSendMessage(capturedText);
    } else {
      // Trong chế độ Gemini AI Audio Recording: Chờ transcribe audio
      final transcribed = await _voiceService.stopListening();
      final textToSend = (transcribed ?? '').trim();
      _inputController.clear();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (textToSend.isNotEmpty) {
        _handleSendMessage(textToSend);
      }
    }

    // Giữ cờ hoàn tất 1000ms để dọn sạch hoàn toàn các packet STT trễ từ hệ điều hành
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _inputController.clear();
        _isFinishingVoice = false;
      }
    });
  }

  void _cancelVoiceRecording() async {
    _silenceTimer?.cancel();
    _cancelCountdownTicker();
    _stopRecordingTimer();
    _isFinishingVoice = true;
    if (mounted) {
      setState(() => _isListening = false);
    }
    _inputController.clear();
    await _voiceService.cancelListening();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _isFinishingVoice = false;
    });
  }

  void _showVoiceTroubleshootSheet({required bool isMicDenied}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_off_rounded,
                color: context.colors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isMicDenied
                  ? (LanguageScope.of(context).isVietnamese
                        ? 'Cần cấp quyền Microphone'
                        : 'Microphone Permission Required')
                  : (LanguageScope.of(context).isVietnamese
                        ? 'Thiết lập Giọng nói trên thiết bị'
                        : 'Device Voice Settings'),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isMicDenied
                  ? (LanguageScope.of(context).isVietnamese
                        ? 'Ứng dụng cần quyền ghi âm micro để nhận lệnh bằng giọng nói. Vui lòng bấm bên dưới để cấp quyền trong Cài đặt.'
                        : 'Microphone permission is required to process voice commands. Please tap below to grant permission in Settings.')
                  : (LanguageScope.of(context).isVietnamese
                        ? 'Để nhận diện giọng nói mượt mà và chính xác nhất, vui lòng đảm bảo Google được chọn làm Dịch vụ nhận dạng giọng nói mặc định trên thiết bị.'
                        : 'To ensure accurate speech recognition, please ensure default voice recognition service is configured on your device.'),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(context.tr('close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (isMicDenied) {
                        await openAppSettings();
                      } else {
                        await _voiceService.openVoiceInputSettings();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isMicDenied
                          ? (LanguageScope.of(context).isVietnamese
                                ? 'Cấp quyền Micro'
                                : 'Grant Permission')
                          : (LanguageScope.of(context).isVietnamese
                                ? 'Mở Cài đặt'
                                : 'Open Settings'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    _cancelAutoSave();
    if (_isListening) {
      _finishVoiceRecordingAndSend();
      return;
    }

    final ready = await _voiceService.init();
    if (!ready) {
      final micGranted = await Permission.microphone.isGranted;
      if (!mounted) return;
      _showVoiceTroubleshootSheet(isMicDenied: !micGranted);
      return;
    }

    _inputController.clear();
    setState(() => _isListening = true);
    _startRecordingTimer();
    HapticFeedback.mediumImpact();

    final rawSilenceMs = _aiConfigService.voiceSilenceDurationMs;
    final silenceMs = rawSilenceMs < 2500 ? 2500 : rawSilenceMs;
    _lastVoiceActivity = DateTime.now();

    // Khởi động bộ đếm thời gian im lặng liên tục theo đúng tốc độ phản hồi đã set
    _startContinuousCountdownTicker(silenceMs);

    await _voiceService.startListening(
      pauseFor: Duration(milliseconds: silenceMs),
      onResult: (text) {
        // Chỉ nhận diện text nếu mic đang bật và CHƯA kích hoạt hoàn tất gửi
        if (mounted && _isListening && !_isFinishingVoice) {
          setState(() {
            _inputController.text = text;
            _lastVoiceActivity =
                DateTime.now(); // Cập nhật thời điểm nói gần nhất
          });
          // Tự động cuộn đến từ tiếng Việt mới nhất trong khung hiển thị
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_voiceSpeechScrollController.hasClients) {
              _voiceSpeechScrollController.animateTo(
                _voiceSpeechScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      onDone: () {
        if (mounted && _isListening && !_isFinishingVoice) {
          debugPrint(
            'AI Assistant: onDone received -> Tự động hoàn tất & gửi ngay',
          );
          _finishVoiceRecordingAndSend();
        }
      },
    );
  }

  Future<void> _saveAllTransactions(List<AiTransactionItem> items) async {
    _cancelAutoSave();
    final uid =
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService().currentUid ??
        '';
    final defaultWalletId = _wallets.isNotEmpty ? _wallets.first.id : '';

    final List<TransactionModel> savedTxs = [];
    int count = 0;
    for (var item in items) {
      String targetWalletId = defaultWalletId;
      if (item.walletName.isNotEmpty && _wallets.isNotEmpty) {
        final matched = _wallets.where(
          (w) => w.name.toLowerCase().contains(item.walletName.toLowerCase()),
        );
        if (matched.isNotEmpty) {
          targetWalletId = matched.first.id;
        }
      }

      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      String localPhotoPath = '';
      String photoUrl = '';
      String photoStoragePath = '';
      bool hasPhoto = false;

      // Lưu trữ hóa đơn vĩnh viễn và tạo Base64 fallback đồng bộ Firestore
      if (item.photoPath != null && item.photoPath!.isNotEmpty) {
        final photoFile = File(item.photoPath!);
        if (photoFile.existsSync()) {
          try {
            final receiptRes = await ReceiptStorageService()
                .processAndUploadReceipt(
                  uid: uid,
                  transactionId: txId,
                  pickedFile: photoFile,
                );
            localPhotoPath = receiptRes.photoLocalPath;
            photoUrl = receiptRes.photoUrl;
            photoStoragePath = receiptRes.photoStoragePath;
            hasPhoto = true;
          } catch (e) {
            debugPrint('AI Assistant: Lỗi lưu ảnh hóa đơn: $e');
            localPhotoPath = item.photoPath!;
            hasPhoto = true;
          }
        }
      }

      final tx = TransactionModel(
        id: txId,
        uid: uid,
        type: item.type,
        category: item.category,
        categoryIconCode: item.categoryIconCode,
        amount: item.amount,
        date: item.date,
        time:
            '${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}',
        description: item.description,
        walletId: targetWalletId,
        hasPhoto: hasPhoto,
        photoLocalPath: localPhotoPath,
        photoUrl: photoUrl,
        photoStoragePath: photoStoragePath,
      );

      // Lưu giao dịch và cân đối số dư ví trong 1 transaction nguyên tử
      await TransactionBalanceService().addTransactionAtomic(tx);
      savedTxs.add(tx);
      count++;
    }

    // Đã thêm giao dịch hôm nay -> hủy thông báo nhắc nhở 20:00 tối nay
    SmartNotificationService.instance.syncDailyReminderState();

    if (mounted) {
      HapticFeedback.heavyImpact();
      final isVi = LanguageService.instance.isVietnamese;
      TopToast.show(
        context,
        isVi
            ? '🎉 Đã lưu thành công $count giao dịch vào sổ thu chi!'
            : '🎉 Successfully saved $count transactions!',
      );

      final usedWalletId = savedTxs.isNotEmpty ? savedTxs.first.walletId : '';
      final usedWalletMatches = _wallets.where((w) => w.id == usedWalletId);
      final usedWalletName = usedWalletMatches.isNotEmpty
          ? usedWalletMatches.first.name
          : (_wallets.isNotEmpty ? _wallets.first.name : 'Tiền mặt');
      final dateRecorded = savedTxs.isNotEmpty
          ? CurrencyUtils.formatDate(savedTxs.first.date)
          : '';

      setState(() {
        // Tắt trạng thái pending trên các bong bóng chat chứa giao dịch vừa lưu
        for (int i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.isPendingSaving && m.transactions != null) {
            final hasMatch = m.transactions!.any((t) => items.contains(t));
            if (hasMatch) {
              _messages[i] = _ChatMessage(
                text: m.text,
                isUser: m.isUser,
                time: m.time,
                imagePath: m.imagePath,
                transactions: m.transactions,
                isPendingSaving: false,
                needsAmount: m.needsAmount,
              );
            }
          }
        }

        _messages.add(
          _ChatMessage(
            text: LanguageService.instance.isVietnamese
                ? '✅ Đã lưu thành công $count giao dịch vào sổ thu chi của bạn.\n• Ví trừ tiền: $usedWalletName\n• Ngày ghi nhận: $dateRecorded'
                : '✅ Successfully saved $count transactions.\n• Deduct wallet: $usedWalletName\n• Date: $dateRecorded',
            isUser: false,
            savedTransactions: savedTxs,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _updateTransactionWallet(
    _ChatMessage msg,
    AiTransactionItem tx,
    String newWalletName,
  ) {
    _cancelAutoSave();
    setState(() {
      final list = msg.transactions;
      if (list != null) {
        final idx = list.indexOf(tx);
        if (idx != -1) {
          list[idx] = tx.copyWith(walletName: newWalletName);
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  void _updateTransactionDate(
    _ChatMessage msg,
    AiTransactionItem tx,
    DateTime newDate,
  ) {
    _cancelAutoSave();
    setState(() {
      final list = msg.transactions;
      if (list != null) {
        final idx = list.indexOf(tx);
        if (idx != -1) {
          list[idx] = tx.copyWith(date: newDate);
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _pickCustomDate(_ChatMessage msg, AiTransactionItem tx) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: tx.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _updateTransactionDate(
        msg,
        tx,
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          tx.date.hour,
          tx.date.minute,
        ),
      );
    }
  }

  Future<void> _pickCustomTime(_ChatMessage msg, AiTransactionItem tx) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: tx.date.hour, minute: tx.date.minute),
    );
    if (picked != null) {
      _updateTransactionDate(
        msg,
        tx,
        DateTime(
          tx.date.year,
          tx.date.month,
          tx.date.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  void _showWalletPickerSheet(_ChatMessage msg, AiTransactionItem tx) {
    _cancelAutoSave();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              tx.type == 'income'
                  ? (LanguageScope.of(context).isVietnamese
                        ? 'Chọn ví nhận tiền'
                        : 'Select deposit wallet')
                  : (LanguageScope.of(context).isVietnamese
                        ? 'Chọn ví trừ tiền'
                        : 'Select deduct wallet'),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._wallets.map((w) {
              final isSelected =
                  tx.walletName.toLowerCase() == w.name.toLowerCase();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(w.colorValue).withValues(alpha: 0.15),
                  child: Icon(
                    IconData(w.iconCode, fontFamily: 'MaterialIcons'),
                    color: Color(w.colorValue),
                  ),
                ),
                title: Text(
                  w.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${LanguageScope.of(context).isVietnamese ? 'Số dư' : 'Balance'}: ${CurrencyUtils.formatCurrency(w.balance)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.primary,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateTransactionWallet(msg, tx, w.name);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // === BOTTOM SHEET HỎI Ý NGƯỜI DÙNG VỀ NGÀY GHI NHẬN & VÍ TRỪ TIỀN (HÓA ĐƠN ẢNH) ===
  void _showConfirmSaveReceiptSheet(_ChatMessage msg) {
    if (msg.transactions == null || msg.transactions!.isEmpty) return;
    _cancelAutoSave();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstTx = msg.transactions!.first;
    DateTime selectedDate = firstTx.date;
    final now = DateTime.now();
    final originalReceiptDate = firstTx.date;
    String selectedWalletName = firstTx.walletName.isNotEmpty
        ? firstTx.walletName
        : (_wallets.isNotEmpty ? _wallets.first.name : 'Tiền mặt');

    // Chế độ chọn ngày: 'today', 'receipt', 'custom'
    String dateChoice =
        (selectedDate.year == now.year &&
            selectedDate.month == now.month &&
            selectedDate.day == now.day)
        ? 'today'
        : 'receipt';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: context.colors.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: context.colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageScope.of(context).isVietnamese
                                    ? 'Xác nhận ghi nhận hóa đơn'
                                    : 'Confirm Receipt Transactions',
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${firstTx.description.isNotEmpty ? firstTx.description : firstTx.category} • ${CurrencyUtils.formatCurrency(firstTx.amount)}',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // 1. CHỌN NGÀY GHI NHẬN (BẮT BUỘC HỎI Ý BẠN)
                    Row(
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 16,
                          color: context.colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          LanguageScope.of(context).isVietnamese
                              ? '1. Bạn muốn ghi nhận vào ngày nào?'
                              : '1. Which date to record?',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Option A: Hôm nay (Khuyên dùng)
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() {
                          dateChoice = 'today';
                          selectedDate = DateTime.now();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: dateChoice == 'today'
                              ? context.colors.primary.withValues(alpha: 0.12)
                              : context.colors.surfaceContainerHighest
                                    .withValues(alpha: isDark ? 0.3 : 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateChoice == 'today'
                                ? context.colors.primary
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              dateChoice == 'today'
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: dateChoice == 'today'
                                  ? context.colors.primary
                                  : context.colors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        LanguageScope.of(context).isVietnamese
                                            ? '⚡ Hôm nay'
                                            : '⚡ Today',
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.incomeBg,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          LanguageScope.of(context).isVietnamese
                                              ? 'Khuyên dùng'
                                              : 'Recommended',
                                          style: TextStyle(
                                            color: context.income,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    CurrencyUtils.formatDate(now),
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                          color:
                                              context.colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option B: Ngày in trên hóa đơn
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() {
                          dateChoice = 'receipt';
                          selectedDate = originalReceiptDate;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: dateChoice == 'receipt'
                              ? context.colors.primary.withValues(alpha: 0.12)
                              : context.colors.surfaceContainerHighest
                                    .withValues(alpha: isDark ? 0.3 : 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateChoice == 'receipt'
                                ? context.colors.primary
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              dateChoice == 'receipt'
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: dateChoice == 'receipt'
                                  ? context.colors.primary
                                  : context.colors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageScope.of(context).isVietnamese
                                        ? '🧾 Ngày in trên hóa đơn'
                                        : '🧾 Date on receipt',
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    CurrencyUtils.formatDate(
                                      originalReceiptDate,
                                    ),
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                          color:
                                              context.colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option C: Chọn ngày khác trên lịch
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            dateChoice = 'custom';
                            selectedDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: dateChoice == 'custom'
                              ? context.colors.primary.withValues(alpha: 0.12)
                              : context.colors.surfaceContainerHighest
                                    .withValues(alpha: isDark ? 0.3 : 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateChoice == 'custom'
                                ? context.colors.primary
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              dateChoice == 'custom'
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: dateChoice == 'custom'
                                  ? context.colors.primary
                                  : context.colors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageScope.of(context).isVietnamese
                                        ? '🗓️ Chọn ngày khác trên lịch...'
                                        : '🗓️ Pick another date...',
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (dateChoice == 'custom')
                                    Text(
                                      '${LanguageScope.of(context).isVietnamese ? 'Đã chọn' : 'Selected'}: ${CurrencyUtils.formatDate(selectedDate)}',
                                      style: context.textTheme.labelSmall
                                          ?.copyWith(
                                            color: context.colors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. CHỌN VÍ THANH TOÁN
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                          color: context.colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          LanguageScope.of(context).isVietnamese
                              ? '2. Trừ vào ví nào?'
                              : '2. Deduct from which wallet?',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _wallets.map((w) {
                        final isSel =
                            selectedWalletName.toLowerCase() ==
                            w.name.toLowerCase();
                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() => selectedWalletName = w.name);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? context.colors.primary
                                  : context.colors.surfaceContainerHighest
                                        .withValues(alpha: isDark ? 0.3 : 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel
                                    ? context.colors.primary
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSel
                                      ? Icons.check_circle_rounded
                                      : Icons.account_balance_wallet_outlined,
                                  size: 14,
                                  color: isSel
                                      ? Colors.white
                                      : context.colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  w.name,
                                  style: context.textTheme.labelMedium
                                      ?.copyWith(
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSel
                                            ? Colors.white
                                            : context.colors.onSurface,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // NÚT XÁC NHẬN LƯU VÀO SỔ
                    AnimatedScaleButton(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          final updated = msg.transactions!
                              .map(
                                (t) => t.copyWith(
                                  date: selectedDate,
                                  walletName: selectedWalletName,
                                ),
                              )
                              .toList();
                          msg.transactions!.clear();
                          msg.transactions!.addAll(updated);
                        });
                        _saveAllTransactions(msg.transactions!);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colors.primary,
                              context.colors.primary.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.primary.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LanguageScope.of(context).isVietnamese
                                  ? 'Xác nhận lưu vào sổ thu chi'
                                  : 'Confirm Save Transactions',
                              style: context.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPrefilledAddTransaction(
    AiTransactionItem tx, {
    _ChatMessage? parentMsg,
  }) async {
    // 1. Hủy ngay lập tức đếm ngược tự động lưu rảnh tay để không bị lưu ngầm khi người dùng bấm Sửa
    _cancelAutoSave();

    final result = await Navigator.push<bool>(
      context,
      PageTransitions.slideUp(
        AddTransactionScreen(
          initialDate: tx.date,
          initialData: {
            'type': tx.type,
            'category': tx.category,
            'iconCode': tx.categoryIconCode,
            'description': tx.description,
            'amount': tx.amount > 0 ? tx.amount : null,
            'walletName': tx.walletName,
            'photoPath': tx.photoPath,
            'hour': tx.date.hour,
            'minute': tx.date.minute,
          },
        ),
      ),
    );

    // 2. Nếu người dùng đã lưu thành công trên màn hình sửa/thêm, cập nhật trạng thái bong bóng chat không còn pending
    if (result == true && parentMsg != null && mounted) {
      setState(() {
        final idx = _messages.indexOf(parentMsg);
        if (idx != -1) {
          _messages[idx] = _ChatMessage(
            text: parentMsg.text,
            isUser: parentMsg.isUser,
            time: parentMsg.time,
            imagePath: parentMsg.imagePath,
            transactions: parentMsg.transactions,
            isPendingSaving: false,
            needsAmount: false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF8FAFB),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark
            ? AppColors.primaryTealDark
            : AppColors.primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.amberAccent,
                    size: 18,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _isOnline ? AppColors.incomeEmerald : Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.primaryTealDark
                            : AppColors.primaryTeal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Trợ lý Mono' : 'Mono Assistant',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                  ),
                ),
                Text(
                  _aiConfigService.isLocalAi
                      ? (isVi ? 'Local AI • Sẵn sàng ⚡' : 'Local AI • Ready ⚡')
                      : (_isOnline
                            ? (isVi
                                  ? 'Trực tuyến • Sẵn sàng'
                                  : 'Online • Ready')
                            : (isVi
                                  ? 'Ngoại tuyến thông minh ⚡'
                                  : 'Smart Offline ⚡')),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          AnimatedScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              _confirmClearChat();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                PageTransitions.slideRight(const AiSettingsScreen()),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Banner chế độ ngoại tuyến thông minh siêu mỏng (Ultra-slim 22px)
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  height: 22,
                  color: _aiConfigService.isLocalAi
                      ? const Color(0xFF0F766E).withValues(alpha: 0.95)
                      : const Color(0xFFD97706).withValues(alpha: 0.95),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _aiConfigService.isLocalAi
                              ? Icons.shield_rounded
                              : Icons.offline_bolt_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _aiConfigService.isLocalAi
                              ? (isVi
                                    ? '⚡ Local AI (On-Device): Hoạt động ngoại tuyến 100%'
                                    : '⚡ Local AI (On-Device): 100% Offline')
                              : (isVi
                                    ? '⚡ Ngoại tuyến: Sẵn sàng ghi thu chi & xem báo cáo'
                                    : '⚡ Offline: Ready to log transactions & view reports'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Danh sách tin nhắn chat
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _buildLoadingBubble(isDark, primaryColor);
                    }
                    final msg = _messages[index];
                    return _buildMessageItem(msg, isDark, primaryColor);
                  },
                ),
              ),

              // Chips gợi ý thao tác nhanh (hiển thị khi ít hơn hoặc bằng 5 tin nhắn)
              if (_messages.length <= 5)
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _quickSuggestions.length,
                    separatorBuilder: (context, idx) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final suggestion = _quickSuggestions[index];
                      final cleanQuery = suggestion.replaceFirst(
                        RegExp(r'^[^\s]+\s+'),
                        '',
                      );
                      return InkWell(
                        onTap: () => _handleSendMessage(cleanQuery),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? context.colors.surface
                                : context.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primaryTealVibrant.withValues(
                                      alpha: 0.35,
                                    )
                                  : context.colors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.3 : 0.03,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              suggestion,
                              style: context.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.primaryTealVibrant
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Thanh nhập lệnh chat dạng floating dock
              _buildInputBar(isDark, primaryColor),
            ],
          ),

          // Nút cuộn xuống dưới cùng nổi (Scroll-to-bottom FAB)
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 86,
              child: AnimatedScaleButton(
                onTap: _scrollToBottom,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 19,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildFormattedMessageText(String text, bool isUser, bool isDark) {
    if (isUser) {
      return Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          height: 1.45,
        ),
      );
    }

    // 1. Loại bỏ triệt để các code fences lập trình thô nếu có
    String cleanText = text
        .replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '')
        .replaceAll('```', '')
        .trim();

    // 2. Nếu lọt chuỗi JSON có "reply", tự động bóc tách nội dung thuần túy
    final replyRegex = RegExp(r'"reply"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"');
    final match = replyRegex.firstMatch(cleanText);
    if (match != null && match.group(1) != null) {
      cleanText = match
          .group(1)!
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n');
    }

    final lines = cleanText.split('\n');
    final defaultColor = context.colors.onSurface;
    final boldColor = isDark
        ? AppColors.primaryTealVibrant
        : context.colors.primary;
    final accentTeal = isDark
        ? AppColors.primaryTealVibrant
        : context.colors.primary;
    final quoteBg = isDark
        ? AppColors.surfaceElevatedDark
        : context.colors.primary.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) {
          return const SizedBox(height: 6);
        }

        // Kẻ ngang phân cách (--- hoặc ***)
        if (trimmedLine == '---' ||
            trimmedLine == '***' ||
            trimmedLine == '___') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              color: isDark
                  ? context.colors.outline.withValues(alpha: 0.3)
                  : context.colors.outlineVariant,
            ),
          );
        }

        // 1. Khối Trích dẫn / Callout (> nội dung)
        if (trimmedLine.startsWith('> ')) {
          final content = trimmedLine.substring(2).trim();
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: quoteBg,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(left: BorderSide(color: accentTeal, width: 3.5)),
            ),
            child: Text.rich(
              TextSpan(
                children: _buildInlineSpans(
                  content,
                  defaultColor,
                  boldColor,
                  accentTeal,
                ),
              ),
              style: const TextStyle(
                fontSize: 13.8,
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        // 2. Mẹo & Gợi ý hành động tiếp theo (💡 hoặc 🎯)
        String tipLine = trimmedLine;
        if (tipLine.startsWith('• ') ||
            tipLine.startsWith('- ') ||
            tipLine.startsWith('* ')) {
          final afterBullet = tipLine.substring(2).trim();
          if (afterBullet.startsWith('💡') || afterBullet.startsWith('🎯')) {
            tipLine = afterBullet;
          }
        }

        if (tipLine.startsWith('💡') || tipLine.startsWith('🎯')) {
          final isTip = tipLine.startsWith('💡');
          final iconEmoji = isTip ? '💡' : '🎯';
          final firstSpace = tipLine.indexOf(' ');
          final content = firstSpace != -1
              ? tipLine.substring(firstSpace + 1).trim()
              : tipLine;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isTip
                  ? context.warningBg
                  : context.colors.primary.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTip
                    ? context.warning.withValues(alpha: isDark ? 0.4 : 0.3)
                    : context.colors.primary.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(iconEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _buildInlineSpans(
                        content,
                        defaultColor,
                        boldColor,
                        accentTeal,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13.8, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }

        // 3. Tiêu đề mục (### hoặc ## hoặc #)
        if (trimmedLine.startsWith('#')) {
          final cleanHeader = trimmedLine.replaceAll(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _buildInlineSpans(
                  cleanHeader,
                  boldColor,
                  boldColor,
                  accentTeal,
                ),
              ),
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: boldColor,
                height: 1.35,
              ),
            ),
          );
        }

        // 4. Danh sách đánh số thứ tự (1. , 2. , 3. ...)
        final numMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmedLine);
        if (numMatch != null) {
          final numStr = numMatch.group(1)!;
          final content = numMatch.group(2)!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(
                      alpha: isDark ? 0.25 : 0.15,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: context.colors.primary.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    numStr,
                    style: context.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _buildInlineSpans(
                        content,
                        defaultColor,
                        boldColor,
                        accentTeal,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14.2, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }

        // 5. Danh sách gạch đầu dòng (• , - , * )
        final isBullet =
            trimmedLine.startsWith('• ') ||
            trimmedLine.startsWith('- ') ||
            trimmedLine.startsWith('* ');

        if (isBullet) {
          final content = trimmedLine.substring(2).trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _buildInlineSpans(
                        content,
                        defaultColor,
                        boldColor,
                        accentTeal,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14.2, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }

        // 6. Dòng văn bản thông thường
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              children: _buildInlineSpans(
                trimmedLine,
                defaultColor,
                boldColor,
                accentTeal,
              ),
            ),
            style: const TextStyle(fontSize: 14.5, height: 1.45),
          ),
        );
      }).toList(),
    );
  }

  /// Tách và phân tích **in đậm**, *in nghiêng* với phong cách chuẩn FinTech, làm sạch dấu backtick và escape
  List<InlineSpan> _buildInlineSpans(
    String text,
    Color defaultColor,
    Color boldColor,
    Color accentColor,
  ) {
    final cleaned = text
        .replaceAll('`', '')
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');

    final List<InlineSpan> spans = [];
    final parts = cleaned.split('**');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      if (i % 2 == 1) {
        // In đậm: Đặt màu nhấn rõ nét
        spans.add(
          TextSpan(
            text: part.replaceAll('*', ''),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: boldColor,
              letterSpacing: 0.1,
            ),
          ),
        );
      } else {
        // Phân tích chữ *nghiêng* trong đoạn văn bản thường
        final regex = RegExp(r'\*([^*]+)\*');
        int lastIndex = 0;
        for (final match in regex.allMatches(part)) {
          if (match.start > lastIndex) {
            spans.add(
              TextSpan(
                text: part
                    .substring(lastIndex, match.start)
                    .replaceAll('*', ''),
                style: TextStyle(color: defaultColor),
              ),
            );
          }
          spans.add(
            TextSpan(
              text: match.group(1),
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: defaultColor.withValues(alpha: 0.92),
              ),
            ),
          );
          lastIndex = match.end;
        }
        if (lastIndex < part.length) {
          spans.add(
            TextSpan(
              text: part.substring(lastIndex).replaceAll('*', ''),
              style: TextStyle(color: defaultColor),
            ),
          );
        }
      }
    }
    return spans;
  }

  Widget _buildMessageItem(_ChatMessage msg, bool isDark, Color primaryColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * 12),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: msg.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: msg.isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!msg.isUser)
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.primary,
                          context.colors.primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: msg.isUser
                          ? LinearGradient(
                              colors: isDark
                                  ? [
                                      AppColors.primaryTeal,
                                      const Color(0xFF1E6F68),
                                    ]
                                  : [
                                      context.colors.primary,
                                      context.colors.primary.withValues(
                                        alpha: 0.85,
                                      ),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: msg.isUser
                          ? null
                          : (isDark ? context.colors.surface : context.cardBg),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                      border: !msg.isUser
                          ? Border.all(
                              color: msg.isError
                                  ? context.warning
                                  : (isDark
                                        ? context.colors.outline.withValues(
                                            alpha: 0.25,
                                          )
                                        : context.colors.outlineVariant),
                              width: msg.isError ? 1.4 : 1.0,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: msg.isUser
                              ? (isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : context.colors.primary.withValues(
                                        alpha: 0.28,
                                      ))
                              : Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Mono AI badge và nút Copy
                        if (!msg.isUser) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (msg.isError
                                              ? context.warning
                                              : context.colors.primary)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      msg.isError
                                          ? Icons.info_outline_rounded
                                          : Icons.bolt_rounded,
                                      color: msg.isError
                                          ? context.warning
                                          : context.colors.primary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Mono AI',
                                      style: context.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: msg.isError
                                                ? context.warning
                                                : context.colors.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _copyToClipboard(msg.text),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 13,
                                        color: context.colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isVi ? 'Sao chép' : 'Copy',
                                        style: context.textTheme.labelSmall
                                            ?.copyWith(
                                              fontSize: 10.5,
                                              color: context
                                                  .colors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Ảnh đính kèm (nếu có)
                        if (msg.imagePath != null &&
                            File(msg.imagePath!).existsSync()) ...[
                          GestureDetector(
                            onTap: () {
                              ReceiptStorageService.showFullScreenViewer(
                                context,
                                photoLocalPath: msg.imagePath!,
                                photoUrl: '',
                                title: isVi
                                    ? 'Hóa đơn gửi trợ lý Mono'
                                    : 'Receipt sent to Mono',
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                      maxWidth: 220,
                                    ),
                                    child: Image.file(
                                      File(msg.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  if (_isLoading &&
                                      _messages.isNotEmpty &&
                                      _messages.last == msg)
                                    const _LaserScannerOverlay(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Nội dung tin nhắn với định dạng Rich Text / Markdown
                        _buildFormattedMessageText(
                          msg.text,
                          msg.isUser,
                          isDark,
                        ),
                        if (msg.isError) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _retryLastUserMessage,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.colors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 14,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isVi ? 'Thử lại ngay' : 'Retry Now',
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: context.colors.primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Dấu thời gian tin nhắn
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            _formatTime(msg.time),
                            style: context.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: msg.isUser
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : (isDark
                                        ? AppColors.textMutedDark
                                        : context.colors.onSurfaceVariant
                                              .withValues(alpha: 0.7)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Card Báo cáo chi tiêu thông minh
            if (msg.spendingReport != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _buildSpendingReportCard(
                  msg.spendingReport!,
                  isDark,
                  primaryColor,
                ),
              ),
            ],

            // Card Đề xuất phân bổ tài chính & Tip tiết kiệm
            if (msg.financialAdvice != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _buildFinancialAdviceCard(
                  msg.financialAdvice!,
                  isDark,
                  primaryColor,
                ),
              ),
            ],

            // Cảnh báo bảo mật / quyền riêng tư
            if (msg.isSecurityRestricted) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _buildSecurityRestrictedCard(isDark),
              ),
            ],

            // Nút điều khiển / mở màn hình tính năng ứng dụng
            if (msg.navigationTarget != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _buildNavigationActionCard(
                  msg.navigationTarget!,
                  isDark,
                  primaryColor,
                ),
              ),
            ],

            // Thẻ biến động số dư ngân hàng / SMS
            if (msg.bankSmsResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: BankSmsTransactionCard(
                  parseResult: msg.bankSmsResult!,
                  onSaved: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],

            // Thẻ xác nhận chuyển tiền giữa các ví (Transfer / Withdraw)
            if (msg.transferCardData != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: TransferConfirmCard(
                  fromWallet: msg.transferCardData!.fromWallet,
                  toWallet: msg.transferCardData!.toWallet,
                  amount: msg.transferCardData!.amount,
                  fee: msg.transferCardData!.fee,
                  note: msg.transferCardData!.note,
                  onCompleted: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],

            // Thẻ chia tiền hóa đơn nhóm
            if (msg.splitBillResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: GroupSplitBillCard(splitResult: msg.splitBillResult!),
              ),
            ],

            // Thẻ hạn mức an toàn tiêu mỗi ngày
            if (msg.safeDailyResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: SafeDailySpendCard(result: msg.safeDailyResult!),
              ),
            ],

            // Thẻ phân tích tiêu vặt thủng ví (Latte Factor)
            if (msg.latteFactorResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: LatteFactorCard(result: msg.latteFactorResult!),
              ),
            ],

            // Thẻ lộ trình tiết kiệm theo mục tiêu
            if (msg.savingsRoadmapResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: SavingsRoadmapCard(roadmap: msg.savingsRoadmapResult!),
              ),
            ],

            // Thẻ xu hướng chi tiêu & cảnh báo bất thường
            if (msg.spendingTrendResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: SpendingTrendCard(trendResult: msg.spendingTrendResult!),
              ),
            ],

            // Thẻ điểm sức khỏe tài chính toàn diện
            if (msg.financialHealthScoreResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: FinancialHealthScoreCard(
                  result: msg.financialHealthScoreResult!,
                ),
              ),
            ],

            // Thẻ chi phí cố định định kỳ
            if (msg.recurringDetectionResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: RecurringTransactionsCard(
                  result: msg.recurringDetectionResult!,
                ),
              ),
            ],

            // Thẻ tra cứu chi tiêu & việc nào chi nhiều nhất
            if (msg.spendingQueryResult != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: PersonalSpendingQueryCard(
                  result: msg.spendingQueryResult!,
                ),
              ),
            ],

            // Card xem trước giao dịch AI trích xuất được
            if (msg.transactions != null && msg.transactions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...msg.transactions!.map(
                      (tx) => _buildTransactionPreviewCard(
                        tx,
                        isDark,
                        primaryColor,
                        needsAmount: msg.needsAmount,
                        parentMsg: msg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (msg.needsAmount) ...[
                      AnimatedScaleButton(
                        onTap: () => _openPrefilledAddTransaction(
                          msg.transactions!.first,
                          parentMsg: msg,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF438883,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVi
                                    ? 'Mở form điền sẵn để nhập số tiền'
                                    : 'Open form to enter amount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (msg.isPendingSaving) ...[
                      // Dải nút chọn ví nhanh 1 chạm (Quick Wallet Action Chips)
                      if (_wallets.isNotEmpty) ...[
                        Text(
                          msg.transactions!.first.type == 'income'
                              ? (isVi ? 'Ví nhận tiền:' : 'Deposit wallet:')
                              : (isVi ? 'Ví trừ tiền:' : 'Deduct wallet:'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _wallets.map((wallet) {
                            final currentTx = msg.transactions!.first;
                            final isSelected =
                                currentTx.walletName.toLowerCase() ==
                                wallet.name.toLowerCase();
                            return AnimatedScaleButton(
                              onTap: () {
                                for (var item in msg.transactions!) {
                                  _updateTransactionWallet(
                                    msg,
                                    item,
                                    wallet.name,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                            ? AppColors.primaryTeal
                                            : const Color(0xFF438883))
                                      : (isDark
                                            ? AppColors.surfaceElevatedDark
                                            : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark
                                              ? AppColors.primaryTealVibrant
                                              : const Color(0xFF438883))
                                        : (isDark
                                              ? context.colors.outline
                                                    .withValues(alpha: 0.25)
                                              : Colors.transparent),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .account_balance_wallet_outlined,
                                      size: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                                ? AppColors.textPrimaryDark
                                                : Colors.black87),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.trWallet(wallet.name),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                  ? AppColors.textPrimaryDark
                                                  : Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedScaleButton(
                              onTap: () {
                                if (msg.imagePath != null &&
                                    msg.transactions != null &&
                                    msg.transactions!.isNotEmpty) {
                                  _showConfirmSaveReceiptSheet(msg);
                                } else {
                                  _saveAllTransactions(msg.transactions!);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi
                                          ? 'Lưu vào sổ thu chi'
                                          : 'Save to transactions',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedScaleButton(
                            onTap: () => _openPrefilledAddTransaction(
                              msg.transactions!.first,
                              parentMsg: msg,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceElevatedDark
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? context.colors.outline.withValues(
                                          alpha: 0.25,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : Colors.black87,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.tr('edit'),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : Colors.black87,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Nút xem chi tiết giao dịch tức thì sau khi lưu thành công
            if (msg.savedTransactions != null &&
                msg.savedTransactions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedScaleButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransitions.slideRight(
                              TransactionDetailScreen(
                                transaction: msg.savedTransactions!.first,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF438883,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.visibility_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi
                                    ? 'Xem giao dịch vừa lưu'
                                    : 'View saved transaction',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedScaleButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransitions.slideRight(
                            const AllTransactionsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? context.colors.outline.withValues(alpha: 0.25)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : Colors.black87,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('all_transactions'),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionPreviewCard(
    AiTransactionItem tx,
    bool isDark,
    Color primaryColor, {
    bool needsAmount = false,
    _ChatMessage? parentMsg,
  }) {
    final isExpense = tx.type == 'expense';
    final amountColor = needsAmount
        ? context.warning
        : (isExpense ? context.expense : context.income);
    final isPending = parentMsg?.isPendingSaving == true;
    final now = DateTime.now();
    final isOldDate =
        now.difference(tx.date).inDays.abs() > 30 || tx.date.year != now.year;
    final isToday =
        tx.date.year == now.year &&
        tx.date.month == now.month &&
        tx.date.day == now.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: amountColor.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: amountColor.withValues(alpha: 0.12),
                child: Icon(
                  IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'),
                  color: amountColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isNotEmpty ? tx.description : tx.category,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          tx.category,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        if (tx.photoPath != null &&
                            tx.photoPath!.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : Colors.grey,
                            ),
                          ),
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 13,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isVi ? 'Có hóa đơn' : 'Receipt',
                            style: context.textTheme.labelSmall?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                needsAmount
                    ? (isVi ? 'Chưa có số tiền' : 'No amount')
                    : '${isExpense ? '-' : '+'}${CurrencyUtils.formatCurrency(tx.amount)}',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark
                ? context.colors.outline.withValues(alpha: 0.25)
                : context.colors.outlineVariant,
          ),
          const SizedBox(height: 8),
          // Hàng hiển thị & tương tác chọn Ví, Ngày và Giờ
          Row(
            children: [
              // Bộ chọn ví tương tác
              InkWell(
                onTap: isPending && parentMsg != null
                    ? () => _showWalletPickerSheet(parentMsg, tx)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceElevatedDark
                        : context.colors.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withValues(
                        alpha: isPending ? 0.35 : 0.15,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 13,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tx.walletName.isNotEmpty
                            ? context.trWallet(tx.walletName)
                            : (isVi ? 'Chọn ví' : 'Select wallet'),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Bộ chọn ngày tương tác
              InkWell(
                onTap: isPending && parentMsg != null
                    ? () => _pickCustomDate(parentMsg, tx)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceElevatedDark
                        : context.colors.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? context.colors.outline.withValues(alpha: 0.25)
                          : context.colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        CurrencyUtils.formatDate(tx.date),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Bộ chọn giờ tương tác (NEW)
              InkWell(
                onTap: isPending && parentMsg != null
                    ? () => _pickCustomTime(parentMsg, tx)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceElevatedDark
                        : context.colors.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? context.colors.outline.withValues(alpha: 0.25)
                          : context.colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Cảnh báo nếu ngày hóa đơn cũ và gợi ý 1 chạm chuyển sang Hôm nay
          if (isPending && parentMsg != null && isOldDate) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: context.warning,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isVi
                              ? 'Hóa đơn ghi ngày ${CurrencyUtils.formatDate(tx.date)} (năm cũ)'
                              : 'Receipt dated ${CurrencyUtils.formatDate(tx.date)} (past year)',
                          style: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedScaleButton(
                          onTap: () => _updateTransactionDate(
                            parentMsg,
                            tx,
                            DateTime.now(),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? context.warning
                                  : (isDark
                                        ? context.colors.surface
                                        : context.cardBg),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isVi ? '⚡ Ghi vào Hôm nay' : '⚡ Record as Today',
                              style: context.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.white : context.warning,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedScaleButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: !isToday
                                  ? context.warning
                                  : context.cardBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: context.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isVi
                                  ? '📅 Giữ ngày hóa đơn'
                                  : '📅 Keep Receipt Date',
                              style: context.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: !isToday
                                    ? Colors.white
                                    : context.warning,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingReportCard(
    SpendingReportResult report,
    bool isDark,
    Color primaryColor,
  ) {
    final net = report.netBalance;
    final isSurplus = net >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVi
                      ? 'Báo cáo: ${report.periodText}'
                      : 'Report: ${report.periodText}',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSurplus ? context.income : context.expense)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSurplus
                      ? (isVi ? 'Thặng dư' : 'Surplus')
                      : (isVi ? 'Thâm hụt' : 'Deficit'),
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSurplus ? context.income : context.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReportStat(
                isVi ? 'Tổng thu' : 'Total Income',
                report.totalIncome,
                context.income,
              ),
              _buildReportStat(
                isVi ? 'Tổng chi' : 'Total Expense',
                report.totalExpense,
                context.expense,
              ),
              _buildReportStat(
                isSurplus
                    ? (isVi ? 'Còn dư' : 'Surplus')
                    : (isVi ? 'Thâm hụt' : 'Deficit'),
                net.abs(),
                isSurplus ? context.income : context.expense,
              ),
            ],
          ),
          if (report.totalIncome > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (report.totalExpense / report.totalIncome).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 6,
                      backgroundColor: isDark
                          ? AppColors.borderDark
                          : context.colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        report.totalExpense > report.totalIncome
                            ? context.expense
                            : primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${((report.totalExpense / report.totalIncome) * 100).toStringAsFixed(0)}% chi',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          AnimatedScaleButton(
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.slideRight(const StatisticsScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isVi ? 'Xem biểu đồ chi tiết ➔' : 'View detailed charts ➔',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialAdviceCard(
    FinancialAdviceResult advice,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? context.colors.surface : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.income.withValues(alpha: isDark ? 0.45 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.income.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tips_and_updates_rounded,
                  color: context.income,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (advice.totalBalance > 0) ...[
            const SizedBox(height: 12),
            // Thanh phân bổ 50/30/20
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(flex: 50, child: Container(color: context.info)),
                    Expanded(
                      flex: 30,
                      child: Container(color: context.warning),
                    ),
                    Expanded(flex: 20, child: Container(color: context.income)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAllocationPill(
                  isVi ? '50% Thiết yếu' : '50% Needs',
                  advice.needs50,
                  context.info,
                  isDark,
                ),
                _buildAllocationPill(
                  isVi ? '30% Linh hoạt' : '30% Wants',
                  advice.wants30,
                  context.warning,
                  isDark,
                ),
                _buildAllocationPill(
                  isVi ? '20% Tiết kiệm' : '20% Savings',
                  advice.savings20,
                  context.income,
                  isDark,
                ),
              ],
            ),
          ],
          if (advice.actionableTips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isVi ? 'Gợi ý hành động từ Mono:' : 'Action advice from Mono:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...advice.actionableTips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: context.income,
                        size: 14,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tip.replaceAll('**', ''),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          AnimatedScaleButton(
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.slideRight(const BudgetAndGoalsScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: context.income.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  isVi
                      ? 'Quản lý Ngân Sách & Mục Tiêu ➔'
                      : 'Manage Budgets & Goals ➔',
                  style: TextStyle(
                    color: context.income,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationPill(
    String label,
    double amount,
    Color color,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textMutedDark
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReportStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRestrictedCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: context.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVi ? 'Bảo mật & Quyền riêng tư' : 'Security & Privacy',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isVi
                      ? 'Vui lòng tự thao tác để bảo vệ thông tin cá nhân'
                      : 'Please navigate manually to protect personal info',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                PageTransitions.slideRight(const SecurityScreen()),
              );
            },
            child: Text(
              isVi ? 'Đi tới' : 'Go',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationActionCard(
    String target,
    bool isDark,
    Color primaryColor,
  ) {
    final title = AiActionHandler().getScreenTitle(target);
    final icon = AiActionHandler().getScreenIcon(target);

    return AnimatedScaleButton(
      onTap: () => AiActionHandler().navigateToScreen(context, target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 10),
            Text(
              isVi ? 'Mở $title' : 'Open $title',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark, Color primaryColor) {
    final isScanning = _messages.isNotEmpty && _messages.last.imagePath != null;
    return _MonoThinkingBubble(
      isDark: isDark,
      primaryColor: primaryColor,
      isScanningReceipt: isScanning,
    );
  }

  Widget _buildInputActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: AnimatedScaleButton(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceElevatedDark
                : context.colors.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? context.colors.outline.withValues(alpha: 0.25)
                  : context.colors.outlineVariant,
              width: 0.8,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.primaryTealVibrant : primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, Color primaryColor) {
    if (_isListening) {
      final hasText = _inputController.text.trim().isNotEmpty;

      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? context.colors.surface : context.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sóng âm thanh thời gian thực
              VoiceWaveform(isListening: true, currentLevel: _soundLevel),
              const SizedBox(height: 8),

              // Khung chữ tiếng Việt chạy theo thời gian thực (Live Vietnamese Speech Streamer)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52, maxHeight: 96),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inputBgDark
                      : context.colors.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasText
                        ? (isDark ? AppColors.primaryTealVibrant : primaryColor)
                              .withValues(alpha: 0.5)
                        : (isDark
                              ? context.colors.outline.withValues(alpha: 0.25)
                              : context.colors.outlineVariant),
                    width: hasText ? 1.4 : 1.0,
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _voiceSpeechScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: hasText
                      ? Text.rich(
                          TextSpan(
                            text: _inputController.text,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.onSurface,
                              height: 1.4,
                            ),
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _BlinkingCursor(color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.mic_none_rounded,
                              size: 17,
                              color: isDark
                                  ? AppColors.textMutedDark
                                  : Colors.black38,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isVi
                                    ? 'Đang nghe tiếng Việt... (VD: "Ăn bún bò 35k ví MoMo")'
                                    : 'Listening... (e.g. "Lunch \$15 Cash")',
                                style: context.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            _BlinkingCursor(
                              color: isDark
                                  ? AppColors.primaryTealVibrant
                                  : Colors.black38,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // Trạng thái giọng nói tối giản, tinh tế (Minimalist Voice Indicator - Không thanh progress bar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: hasText ? primaryColor : Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasText
                          ? (isVi
                                ? 'Đang lắng nghe... Dừng nói hoặc nhấn "Gửi ngay"'
                                : 'Listening... Stop speaking or tap "Send Now"')
                          : (isVi
                                ? 'Hãy nói yêu cầu của bạn bằng tiếng Việt...'
                                : 'Speak your request...'),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Nút điều khiển công thái học (Hủy & Gửi ngay)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _cancelVoiceRecording,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.expense,
                      ),
                      label: Text(
                        context.tr('cancel'),
                        style: TextStyle(
                          color: context.expense,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: context.expense.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: AnimatedScaleButton(
                      onTap: _finishVoiceRecordingAndSend,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVi ? 'Gửi ngay' : 'Send Now',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Chế độ nhập văn bản thông thường: Floating pill input bar
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner đếm ngược tự động lưu rảnh tay (Hands-free auto-save)
          if (_autoSaveCountdown > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.income,
                    context.income.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.income.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Rảnh tay: Tự động lưu sau $_autoSaveCountdown giây...'
                          : 'Hands-free: Auto-saving in $_autoSaveCountdown s...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_autoSavePendingTxs != null) {
                        final txs = _autoSavePendingTxs!;
                        _cancelAutoSave();
                        _saveAllTransactions(txs);
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isVi ? 'Lưu ngay' : 'Save now',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _cancelAutoSave,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceElevatedDark
                  : context.inputBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? context.colors.outline.withValues(alpha: 0.28)
                    : context.colors.outlineVariant,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Nhóm nút tiện ích đính kèm tròn đều, neo đáy chuẩn xác
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputActionButton(
                        icon: Icons.camera_alt_outlined,
                        tooltip: isVi
                            ? 'Chụp ảnh hóa đơn'
                            : 'Scan receipt photo',
                        onTap: () => _handlePickImage(ImageSource.camera),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _buildInputActionButton(
                        icon: Icons.image_outlined,
                        tooltip: isVi
                            ? 'Chọn ảnh hóa đơn từ thư viện'
                            : 'Choose receipt from gallery',
                        onTap: () => _handlePickImage(ImageSource.gallery),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _buildInputActionButton(
                        icon: Icons.content_paste_rounded,
                        tooltip: isVi
                            ? 'Dán SMS / Biến động số dư'
                            : 'Paste SMS / Bank alert',
                        onTap: _handlePasteFromClipboard,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Ô nhập nội dung co giãn linh hoạt
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: _handleSendMessage,
                      maxLines: 4,
                      minLines: 1,
                      cursorColor: isDark
                          ? AppColors.primaryTealVibrant
                          : primaryColor,
                      textAlignVertical: TextAlignVertical.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: isVi
                            ? 'Hỏi Mono hoặc nhập lệnh...'
                            : 'Ask Mono or enter command...',
                        hintStyle: context.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textMutedDark
                              : context.colors.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Nút tròn Send / Mic (Căn đáy đồng trục 38x38)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _inputController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return AnimatedScaleButton(
                      onTap: () {
                        if (hasText) {
                          _handleSendMessage(_inputController.text);
                        } else {
                          _toggleVoiceInput();
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    AppColors.primaryTeal,
                                    const Color(0xFF2E7E78),
                                  ]
                                : [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.85),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isDark
                                          ? AppColors.primaryTeal
                                          : primaryColor)
                                      .withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            hasText
                                ? Icons.arrow_upward_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget hiệu ứng 3 chấm nảy nhịp nhàng (Bouncing Dots Animation)
class _BouncingDots extends StatefulWidget {
  final Color color;
  const _BouncingDots({required this.color});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final bounce = (progress < 0.5)
                ? progress * 2
                : (1.0 - progress) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              transform: Matrix4.translationValues(0, -bounce * 4, 0),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.6 + bounce * 0.4),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.2,
        height: 16,
        margin: const EdgeInsets.only(left: 3, bottom: 2),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Widget Thinking State với hiệu ứng sóng âm mini nhịp nhàng và text thông minh
/// Giúp người dùng cảm thấy ứng dụng đang phản hồi sống động, không sốt ruột ở mọi ngưỡng thời gian
class _MonoThinkingBubble extends StatefulWidget {
  final bool isDark;
  final Color primaryColor;
  final bool isScanningReceipt;

  const _MonoThinkingBubble({
    required this.isDark,
    required this.primaryColor,
    this.isScanningReceipt = false,
  });

  @override
  State<_MonoThinkingBubble> createState() => _MonoThinkingBubbleState();
}

class _MonoThinkingBubbleState extends State<_MonoThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _textTimer1;
  Timer? _textTimer2;
  String _thinkingText = LanguageService.instance.isVietnamese
      ? 'Mono đang tính toán...'
      : 'Mono is calculating...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    final isVi = LanguageService.instance.isVietnamese;
    if (widget.isScanningReceipt) {
      _thinkingText = isVi
          ? '🔍 Đang tối ưu hóa hình ảnh hóa đơn...'
          : '🔍 Optimizing receipt image...';
      _textTimer1 = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _thinkingText = isVi
                ? '⚡ Đang nhận diện chữ & số tiền (OCR Vision)...'
                : '⚡ Recognizing text & amount (OCR Vision)...';
          });
        }
      });
      _textTimer2 = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() {
            _thinkingText = isVi
                ? '✨ Đang phân loại danh mục & đối chiếu ví...'
                : '✨ Categorizing & matching wallet...';
          });
        }
      });
    } else {
      _thinkingText = isVi
          ? 'Mono đang phân tích yêu cầu...'
          : 'Mono is analyzing request...';
      _textTimer1 = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _thinkingText = isVi
                ? 'Mono đang xử lý dữ liệu tài chính...'
                : 'Mono is processing financial data...';
          });
        }
      });
      _textTimer2 = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _thinkingText = isVi
                ? 'Đang hoàn tất câu trả lời tối ưu...'
                : 'Finalizing best response...';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _textTimer1?.cancel();
    _textTimer2?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 2),
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF438883), Color(0xFF2F7E79)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? context.colors.surface : context.cardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: widget.isDark
                    ? context.colors.outline.withValues(alpha: 0.25)
                    : context.colors.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.25 : 0.04,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini Waveform động 4 thanh sóng âm nhịp nhàng
                _ThinkingMiniWaveform(
                  controller: _animController,
                  color: widget.primaryColor,
                ),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _thinkingText,
                    key: ValueKey<String>(_thinkingText),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: widget.isDark
                          ? AppColors.textPrimaryDark
                          : context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sóng âm thanh mini 4 thanh nhấp nhô nhịp nhàng
class _ThinkingMiniWaveform extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _ThinkingMiniWaveform({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final val = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (index) {
            final offset = index * 0.25;
            final phase = ((val + offset) % 1.0);
            final heightFactor =
                0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: 6 + 10 * heightFactor,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5 + 0.5 * heightFactor),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Widget hiệu ứng chùm tia laser quang học quét lên xuống trên ảnh hóa đơn
class _LaserScannerOverlay extends StatefulWidget {
  const _LaserScannerOverlay();

  @override
  State<_LaserScannerOverlay> createState() => _LaserScannerOverlayState();
}

class _LaserScannerOverlayState extends State<_LaserScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _scannerController,
        builder: (context, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Lớp phủ tối nhẹ công nghệ
                Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                ),
                // Badge đang quét OCR
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.document_scanner_rounded,
                          size: 12,
                          color: Color(0xFF2DD4BF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          LanguageService.instance.isVietnamese
                              ? 'Quét OCR...'
                              : 'Scanning OCR...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tia laser chuyển động
                Align(
                  alignment: Alignment(
                    0,
                    (_scannerController.value * 2.0) - 1.0,
                  ),
                  child: Container(
                    height: 2.5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                          const Color(0xFF2DD4BF),
                          const Color(0xFF5EEAD4),
                          const Color(0xFF2DD4BF),
                          const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
