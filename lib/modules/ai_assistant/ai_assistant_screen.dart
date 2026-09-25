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
import '../../widgets/voice_waveform.dart';
import '../../services/smart_notification_service.dart';
import '../budget/budget_and_goals_screen.dart';
import '../settings/ai_settings_screen.dart';
import '../settings/security_screen.dart';
import '../home/statistics_screen.dart';
import '../transaction/add_transaction_screen.dart';
import 'widgets/mono_assistant_cards.dart';
import '../../services/bank_sms_parser_service.dart';
import '../../services/group_bill_split_service.dart';
import '../../services/financial_advisor_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialVoiceText;

  const AiAssistantScreen({super.key, this.initialVoiceText});

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
  }) : time = time ?? DateTime.now();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> with TickerProviderStateMixin {
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

  final List<String> _quickSuggestions = [
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
        final show = (_scrollController.position.maxScrollExtent - _scrollController.offset) > 300;
        if (show != _showScrollToBottom) {
          setState(() => _showScrollToBottom = show);
        }
      }
    });
    _messages.add(_ChatMessage(
      text: 'Xin chào! Tôi là Trợ lý Mono 🤖\nBạn có thể:\n• Nhập/nói tự nhiên (VD: "Ăn bún bò 35k ví MoMo", "Hôm nay được cộng thêm 36đ")\n• Điều khiển app: "Bật chế độ tối", "Báo cáo chi tiêu tháng này"\n• Chụp hóa đơn/biên lai để quét tự động!',
      isUser: false,
    ));

    if (widget.initialVoiceText != null && widget.initialVoiceText!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialVoiceText!);
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
          TopToast.show(context, 'Bộ nhớ tạm (Clipboard) trống!');
        }
        return;
      }
      _inputController.text = text;
      _handleSendMessage(text);
    } catch (e) {
      if (mounted) {
        TopToast.show(context, 'Không thể đọc bộ nhớ tạm: $e', isError: true);
      }
    }
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    final now = DateTime.now();
    if (_lastSentText == query && _lastSentTime != null && now.difference(_lastSentTime!).inMilliseconds < 1500) {
      debugPrint('AI Assistant: Bỏ qua tin nhắn trùng lặp gửi quá nhanh: "$query"');
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

    final history = _messages
        .where((m) => m.text.isNotEmpty && m.imagePath == null)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'text': m.text,
            })
        .toList();

    final result = await _aiService.parseNaturalLanguage(query, conversationHistory: history);

    // Xử lý các tác vụ điều khiển ứng dụng
    SpendingReportResult? reportResult;
    FinancialAdviceResult? adviceResult = result.financialAdvice;

    if (result.actionType == AiActionType.changeTheme && result.themeMode != null) {
      await AiActionHandler().changeTheme(result.themeMode!);
    } else if (result.actionType == AiActionType.changeLanguage && result.language != null) {
      await AiActionHandler().changeLanguage(result.language!);
    } else if (result.actionType == AiActionType.spendingReport) {
      reportResult = await AiActionHandler().generateSpendingReport(result.reportPeriod ?? 'today');
    } else if (result.actionType == AiActionType.financialAdvice) {
      adviceResult ??= await AiActionHandler().generateFinancialAdvice(specificQuery: query);
    } else if (result.actionType == AiActionType.navigateScreen && result.navigationTarget != null) {
      if (mounted) {
        AiActionHandler().navigateToScreen(context, result.navigationTarget!);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result.isSuccess) {
        final hasTxs = result.transactions.isNotEmpty;
        await _addAiMessageWithTypingEffect(
          fullText: result.aiReply,
          transactions: hasTxs ? result.transactions : null,
          isPendingSaving: hasTxs && !result.needsAmount,
          needsAmount: result.needsAmount,
          spendingReport: reportResult,
          financialAdvice: adviceResult,
          isSecurityRestricted: result.actionType == AiActionType.securityRestricted,
          navigationTarget: result.actionType == AiActionType.navigateScreen ? result.navigationTarget : null,
          bankSmsResult: result.bankSmsResult,
          splitBillResult: result.splitBillResult,
          safeDailyResult: result.safeDailyResult,
          forecastResult: result.forecastResult,
          latteFactorResult: result.latteFactorResult,
          savingsRoadmapResult: result.savingsRoadmapResult,
          spendingQueryResult: result.spendingQueryResult,
        );

        // Nếu người dùng nhập/nói ra khoản tiền hoàn chỉnh -> kích hoạt đếm ngược tự động lưu rảnh tay 3s!
        if (hasTxs && !result.needsAmount && result.transactions.first.amount > 0) {
          _startAutoSaveCountdown(result.transactions);
        }
      } else {
        setState(() {
          _messages.add(_ChatMessage(
            text: result.errorMessage ?? 'Không thể xử lý yêu cầu. Vui lòng thử lại.',
            isUser: false,
          ));
        });
        _scrollToBottom();
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
  }) async {
    // Nếu tin nhắn có thẻ giao dịch, thẻ tính năng hoặc ngắn (<= 60 ký tự), hiển thị ngay không cần animation dài
    final hasRichCard = transactions != null ||
        spendingReport != null ||
        financialAdvice != null ||
        bankSmsResult != null ||
        splitBillResult != null ||
        safeDailyResult != null ||
        latteFactorResult != null ||
        savingsRoadmapResult != null;

    if (fullText.length <= 60 || hasRichCard) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
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
          ));
        });
        _scrollToBottom();
      }
      return;
    }

    // Với các phản hồi văn bản dài: Hiệu ứng gõ chữ mượt mà 60fps
    final msgIndex = _messages.length;
    _messages.add(_ChatMessage(
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
    ));
    if (mounted) setState(() {});
    _scrollToBottom();

    const chunkSize = 4;
    for (int i = 0; i < fullText.length; i += chunkSize) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 16));
      final end = (i + chunkSize < fullText.length) ? i + chunkSize : fullText.length;
      final currentPart = fullText.substring(0, end);
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
          );
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    if (!_isOnline) {
      TopToast.show(context, 'Cần kết nối mạng để quét ảnh hóa đơn!', isError: true);
      return;
    }
    try {
      final XFile? file = await BiometricService.instance.runWithPickerSuspended(() async {
        return await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      });
      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _messages.add(_ChatMessage(
          imagePath: file.path,
          text: '📷 Hóa đơn đính kèm',
          isUser: true,
        ));
        _isLoading = true;
      });
      _scrollToBottom();

      final result = await _aiService.parseReceiptImage(bytes);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.isSuccess) {
            // Tự động gắn photoPath của hóa đơn vừa chụp vào các giao dịch trích xuất
            final txWithPhotos = result.transactions
                .map((tx) => tx.copyWith(photoPath: file.path))
                .toList();

            _messages.add(_ChatMessage(
              text: result.aiReply,
              isUser: false,
              transactions: txWithPhotos,
              isPendingSaving: txWithPhotos.isNotEmpty,
            ));
          } else {
            _messages.add(_ChatMessage(
              text: result.errorMessage ?? 'Không thể đọc được hóa đơn này. Bạn có thể chụp lại rõ hơn không?',
              isUser: false,
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TopToast.show(context, 'Lỗi chọn ảnh: $e');
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
    TopToast.show(context, 'Đã sao chép nội dung tin nhắn!');
  }

  void _confirmClearChat() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2928) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Làm mới cuộc trò chuyện?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tất cả tin nhắn trong phiên chat này sẽ được xóa để bắt đầu phiên mới.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(_ChatMessage(
                  text: 'Xin chào! Tôi là Trợ lý Mono 🤖\nBạn có thể:\n• Nhập/nói tự nhiên (VD: "Ăn bún bò 35k ví MoMo", "Hôm nay được cộng thêm 36đ")\n• Điều khiển app: "Bật chế độ tối", "Báo cáo chi tiêu tháng này"\n• Chụp hóa đơn/biên lai để quét tự động!',
                  isUser: false,
                ));
              });
              TopToast.show(context, 'Đã làm mới cuộc trò chuyện!');
            },
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );
  }

  void _startContinuousCountdownTicker(int durationMs) {
    _countdownTicker?.cancel();
    _lastVoiceActivity = DateTime.now();

    // Chạy ngầm kiểm tra khoảng lặng mỗi 100ms, không re-render setState gây giật lag
    _countdownTicker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isListening) {
        timer.cancel();
        return;
      }

      final currentText = _inputController.text.trim();
      if (currentText.isEmpty) return;

      // Khi đã có văn bản nhận diện: đo lường thời gian trôi qua từ lần phát hiện giọng nói cuối cùng
      final elapsedSinceSpeech = DateTime.now().difference(_lastVoiceActivity).inMilliseconds;

      // TỰ ĐỘNG GỬI NGAY khi im lặng đủ thời gian durationMs (1.0s, 1.5s, 2.0s, etc.)
      if (elapsedSinceSpeech >= durationMs) {
        timer.cancel();
        debugPrint('AI Assistant: Đã im lặng ${elapsedSinceSpeech}ms >= ${durationMs}ms -> Tự động gửi!');
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
    _inputController.clear(); // Xóa ngay lập tức để không bị sót lại trong ô chat
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2827) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF438883).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_off_rounded, color: Color(0xFF438883), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              isMicDenied ? 'Cần cấp quyền Microphone' : 'Thiết lập Giọng nói trên thiết bị',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isMicDenied
                  ? 'Ứng dụng cần quyền ghi âm micro để nhận lệnh bằng giọng nói. Vui lòng bấm bên dưới để cấp quyền trong Cài đặt.'
                  : 'Để nhận diện tiếng Việt mượt mà và chính xác nhất, vui lòng đảm bảo Google được chọn làm Dịch vụ nhận dạng giọng nói mặc định trên thiết bị.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white70 : Colors.black87,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Đóng'),
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
                      backgroundColor: const Color(0xFF438883),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isMicDenied ? 'Cấp quyền Micro' : 'Mở Cài đặt'),
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
    if (!_isOnline && !_voiceService.supportsVietnamese) {
      TopToast.show(context, 'Giọng nói AI đám mây cần kết nối Internet!', isError: true);
      return;
    }
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
    final silenceMs = rawSilenceMs < 1500 ? 2000 : rawSilenceMs;
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
            _lastVoiceActivity = DateTime.now(); // Cập nhật thời điểm nói gần nhất
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
          debugPrint('AI Assistant: onDone received -> Tự động hoàn tất & gửi ngay');
          _finishVoiceRecordingAndSend();
        }
      },
    );
  }

  Future<void> _saveAllTransactions(List<AiTransactionItem> items) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().currentUid ?? '';
    final defaultWalletId = _wallets.isNotEmpty ? _wallets.first.id : '';

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
            final receiptRes = await ReceiptStorageService().processAndUploadReceipt(
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
        time: '${item.date.hour.toString().padLeft(2, '0')}:${item.date.minute.toString().padLeft(2, '0')}',
        description: item.description,
        walletId: targetWalletId,
        hasPhoto: hasPhoto,
        photoLocalPath: localPhotoPath,
        photoUrl: photoUrl,
        photoStoragePath: photoStoragePath,
      );

      // Lưu giao dịch và cân đối số dư ví trong 1 transaction nguyên tử
      await TransactionBalanceService().addTransactionAtomic(tx);
      count++;
    }

    // Đã thêm giao dịch hôm nay -> hủy thông báo nhắc nhở 20:00 tối nay
    SmartNotificationService.instance.syncDailyReminderState();

    if (mounted) {
      HapticFeedback.heavyImpact();
      TopToast.show(context, '🎉 Đã lưu thành công $count giao dịch vào sổ thu chi!');
      setState(() {
        _messages.add(_ChatMessage(
          text: '✅ Đã lưu thành công $count giao dịch vào sổ thu chi của bạn.',
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  void _openPrefilledAddTransaction(AiTransactionItem tx) {
    Navigator.push(
      context,
      PageTransitions.slideUp(AddTransactionScreen(
        initialData: {
          'type': tx.type,
          'category': tx.category,
          'iconCode': tx.categoryIconCode,
          'description': tx.description,
          'amount': tx.amount > 0 ? tx.amount : null,
          'walletName': tx.walletName,
          'photoPath': tx.photoPath,
        },
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1716) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _isOnline ? const Color(0xFF10B981) : Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F2625) : const Color(0xFF438883),
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
                const Text(
                  'Trợ lý Mono',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5),
                ),
                Text(
                  _isOnline ? 'Trực tuyến • Sẵn sàng' : 'Ngoại tuyến thông minh ⚡',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Xóa hội thoại',
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white, size: 22),
            onPressed: _confirmClearChat,
          ),
          IconButton(
            tooltip: 'Cài đặt AI & Giọng nói',
            icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Banner chế độ ngoại tuyến thông minh
              if (!_isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.95),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chế độ Ngoại tuyến: Vẫn hỗ trợ ghi chép thu chi, xem báo cáo & điều khiển app!',
                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
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
                    separatorBuilder: (context, idx) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final suggestion = _quickSuggestions[index];
                      final cleanQuery = suggestion.replaceFirst(RegExp(r'^[^\s]+\s+'), '');
                      return InkWell(
                        onTap: () => _handleSendMessage(cleanQuery),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2625) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFF438883).withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : const Color(0xFF2F7E79),
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
                    color: isDark ? const Color(0xFF1E2827) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF438883).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    size: 19,
                    color: Color(0xFF438883),
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
        style: const TextStyle(
          fontSize: 14.5,
          color: Colors.white,
          height: 1.45,
        ),
      );
    }

    final lines = text.split('\n');
    final defaultColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final boldColor = isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) {
          return const SizedBox(height: 6);
        }

        final isBullet = trimmedLine.startsWith('• ') ||
            trimmedLine.startsWith('- ') ||
            trimmedLine.startsWith('* ');

        String content = isBullet ? trimmedLine.substring(2).trim() : trimmedLine;

        // Parse **bold** into TextSpans
        final List<InlineSpan> spans = [];
        final parts = content.split('**');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isEmpty) continue;
          if (i % 2 == 1) {
            // In đậm
            spans.add(TextSpan(
              text: parts[i],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: boldColor,
              ),
            ));
          } else {
            // Văn bản thông thường
            spans.add(TextSpan(
              text: parts[i],
              style: TextStyle(
                color: defaultColor,
              ),
            ));
          }
        }

        if (isBullet) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: spans),
                    style: const TextStyle(fontSize: 14.2, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text.rich(
            TextSpan(children: spans),
            style: const TextStyle(fontSize: 14.5, height: 1.45),
          ),
        );
      }).toList(),
    );
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
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!msg.isUser)
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF438883), Color(0xFF2F7E79)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF438883).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: msg.isUser
                          ? const LinearGradient(
                              colors: [Color(0xFF438883), Color(0xFF2F7E79)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: msg.isUser
                          ? null
                          : (isDark ? const Color(0xFF1E2827) : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                      ),
                      border: !msg.isUser
                          ? Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade200,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: msg.isUser
                              ? const Color(0xFF438883).withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF438883).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, color: Color(0xFF438883), size: 12),
                                    SizedBox(width: 3),
                                    Text(
                                      'Mono AI',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF438883),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _copyToClipboard(msg.text),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 13,
                                        color: isDark ? Colors.white60 : Colors.black45,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Sao chép',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.white60 : Colors.black45,
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
                        if (msg.imagePath != null && File(msg.imagePath!).existsSync()) ...[
                          GestureDetector(
                            onTap: () {
                              ReceiptStorageService.showFullScreenViewer(
                                context,
                                photoLocalPath: msg.imagePath!,
                                photoUrl: '',
                                title: 'Hóa đơn gửi trợ lý Mono',
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
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
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Nội dung tin nhắn với định dạng Rich Text / Markdown
                        _buildFormattedMessageText(msg.text, msg.isUser, isDark),
                        const SizedBox(height: 4),
                        // Dấu thời gian tin nhắn
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            _formatTime(msg.time),
                            style: TextStyle(
                              fontSize: 10,
                              color: msg.isUser
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : (isDark ? Colors.white38 : Colors.black38),
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
                child: _buildSpendingReportCard(msg.spendingReport!, isDark, primaryColor),
              ),
            ],

            // Card Đề xuất phân bổ tài chính & Tip tiết kiệm
            if (msg.financialAdvice != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _buildFinancialAdviceCard(msg.financialAdvice!, isDark, primaryColor),
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
                child: _buildNavigationActionCard(msg.navigationTarget!, isDark, primaryColor),
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

            // Card xem trước giao dịch AI trích xuất được
            if (msg.transactions != null && msg.transactions!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...msg.transactions!.map((tx) => _buildTransactionPreviewCard(
                          tx,
                          isDark,
                          primaryColor,
                          needsAmount: msg.needsAmount,
                        )),
                    const SizedBox(height: 8),
                    if (msg.needsAmount) ...[
                      AnimatedScaleButton(
                        onTap: () => _openPrefilledAddTransaction(msg.transactions!.first),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF438883),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF438883).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Mở form điền sẵn để nhập số tiền',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (msg.isPendingSaving) ...[
                      AnimatedScaleButton(
                        onTap: () => _saveAllTransactions(msg.transactions!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Lưu vào sổ thu chi',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
  }) {
    final isExpense = tx.type == 'expense';
    final amountColor = needsAmount
        ? Colors.amber.shade700
        : (isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amountColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: amountColor.withValues(alpha: 0.12),
            child: Icon(IconData(tx.categoryIconCode, fontFamily: 'MaterialIcons'), color: amountColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : tx.category,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      tx.category,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (tx.walletName.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.walletName,
                          style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (tx.photoPath != null && tx.photoPath!.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                      const Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF438883)),
                      const SizedBox(width: 2),
                      const Text(
                        'Có hóa đơn',
                        style: TextStyle(fontSize: 11, color: Color(0xFF438883), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            needsAmount
                ? 'Chưa có số tiền'
                : '${isExpense ? '-' : '+'}${CurrencyUtils.formatCurrency(tx.amount)}',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingReportCard(SpendingReportResult report, bool isDark, Color primaryColor) {
    final net = report.netBalance;
    final isSurplus = net >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF438883), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Báo cáo: ${report.periodText}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSurplus ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSurplus ? 'Thặng dư' : 'Thâm hụt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSurplus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReportStat('Tổng thu', report.totalIncome, const Color(0xFF10B981)),
              _buildReportStat('Tổng chi', report.totalExpense, const Color(0xFFEF4444)),
              _buildReportStat(
                isSurplus ? 'Còn dư' : 'Thâm hụt',
                net.abs(),
                isSurplus ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
                      value: (report.totalExpense / report.totalIncome).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        report.totalExpense > report.totalIncome ? const Color(0xFFEF4444) : primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${((report.totalExpense / report.totalIncome) * 100).toStringAsFixed(0)}% chi',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          AnimatedScaleButton(
            onTap: () {
              Navigator.push(context, PageTransitions.slideRight(const StatisticsScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Xem biểu đồ chi tiết ➔',
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialAdviceCard(FinancialAdviceResult advice, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2826) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                    Expanded(flex: 50, child: Container(color: const Color(0xFF3B82F6))),
                    Expanded(flex: 30, child: Container(color: const Color(0xFFF59E0B))),
                    Expanded(flex: 20, child: Container(color: const Color(0xFF10B981))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAllocationPill('50% Thiết yếu', advice.needs50, const Color(0xFF3B82F6), isDark),
                _buildAllocationPill('30% Linh hoạt', advice.wants30, const Color(0xFFF59E0B), isDark),
                _buildAllocationPill('20% Tiết kiệm', advice.savings20, const Color(0xFF10B981), isDark),
              ],
            ),
          ],
          if (advice.actionableTips.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Gợi ý hành động từ Mono:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            ...advice.actionableTips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 6),
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                      ),
                      Expanded(
                        child: Text(
                          tip.replaceAll('**', ''),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          AnimatedScaleButton(
            onTap: () {
              Navigator.push(context, PageTransitions.slideRight(const BudgetAndGoalsScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Quản lý Ngân Sách & Mục Tiêu ➔',
                  style: TextStyle(
                    color: Color(0xFF059669),
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

  Widget _buildAllocationPill(String label, double amount, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildReportStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          CurrencyUtils.formatCurrency(amount),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  Widget _buildSecurityRestrictedCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C1C) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bảo mật & Quyền riêng tư',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vui lòng tự thao tác để bảo vệ thông tin cá nhân',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(context, PageTransitions.slideRight(const SecurityScreen()));
            },
            child: const Text('Đi tới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationActionCard(String target, bool isDark, Color primaryColor) {
    final title = AiActionHandler().getScreenTitle(target);
    final icon = AiActionHandler().getScreenIcon(target);

    return AnimatedScaleButton(
      onTap: () => AiActionHandler().navigateToScreen(context, target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E2C) : const Color(0xFFE8F5F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primaryColor.withValues(alpha: isDark ? 0.4 : 0.45),
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
              'Mở $title',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1C4542),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark, Color primaryColor) {
    return _MonoThinkingBubble(isDark: isDark, primaryColor: primaryColor);
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
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF2F7E79),
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
            color: isDark ? const Color(0xFF162423) : const Color(0xFFF0FDF8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF438883).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF438883).withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sóng âm thanh thời gian thực
              VoiceWaveform(
                isListening: true,
                currentLevel: _soundLevel,
              ),
              const SizedBox(height: 8),

              // Khung chữ tiếng Việt chạy theo thời gian thực (Live Vietnamese Speech Streamer)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52, maxHeight: 96),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasText
                        ? const Color(0xFF438883).withValues(alpha: 0.5)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
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
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đang nghe tiếng Việt... (VD: "Ăn bún bò 35k ví MoMo")',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                              ),
                            ),
                            _BlinkingCursor(color: isDark ? Colors.white38 : Colors.black38),
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
                          ? 'Đang lắng nghe... Dừng nói hoặc nhấn "Gửi ngay"'
                          : 'Hãy nói yêu cầu của bạn bằng tiếng Việt...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
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
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                      label: const Text(
                        'Hủy',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF438883), Color(0xFF2F7E79)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF438883).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 19),
                            SizedBox(width: 6),
                            Text(
                              'Gửi ngay',
                              style: TextStyle(
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rảnh tay: Tự động lưu sau $_autoSaveCountdown giây...',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Lưu ngay', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2827) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
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
                        tooltip: 'Chụp ảnh hóa đơn',
                        onTap: () => _handlePickImage(ImageSource.camera),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _buildInputActionButton(
                        icon: Icons.image_outlined,
                        tooltip: 'Chọn ảnh hóa đơn từ thư viện',
                        onTap: () => _handlePickImage(ImageSource.gallery),
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      _buildInputActionButton(
                        icon: Icons.content_paste_rounded,
                        tooltip: 'Dán SMS / Biến động số dư',
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
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 14.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Hỏi Mono hoặc nhập lệnh...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF438883), Color(0xFF2F7E79)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF438883).withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            hasText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
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

class _BouncingDotsState extends State<_BouncingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
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
            final bounce = (progress < 0.5) ? progress * 2 : (1.0 - progress) * 2;
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

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
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
/// Giúp người dùng cảm thấy ứng dụng đang phản hồi sống động, không sốt ruột ở ngưỡng 800 - 1500ms
class _MonoThinkingBubble extends StatefulWidget {
  final bool isDark;
  final Color primaryColor;

  const _MonoThinkingBubble({
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<_MonoThinkingBubble> createState() => _MonoThinkingBubbleState();
}

class _MonoThinkingBubbleState extends State<_MonoThinkingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _textTimer;
  String _thinkingText = 'Mono đang tính toán...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Sau 800ms (ngưỡng 800-1500ms), tự động chuyển text trạng thái để người dùng yên tâm
    _textTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _thinkingText = 'Mono đang trích xuất dữ liệu tài chính...';
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _textTimer?.cancel();
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
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2827) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mini Waveform động 4 thanh sóng âm nhịp nhàng
                _ThinkingMiniWaveform(controller: _animController, color: widget.primaryColor),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _thinkingText,
                    key: ValueKey<String>(_thinkingText),
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
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

  const _ThinkingMiniWaveform({
    required this.controller,
    required this.color,
  });

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
            final heightFactor = 0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
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
