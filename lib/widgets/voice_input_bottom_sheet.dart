import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_service.dart';
import '../services/language_service.dart';
import '../utils/category_utils.dart';
import '../utils/currency_format_utils.dart';
import '../utils/page_transitions.dart';
import '../modules/transaction/add_transaction_screen.dart';
import '../data/repositories/transaction_repository.dart';
import '../services/auth_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/ai_config_service.dart';
import '../modules/ai_assistant/ai_assistant_screen.dart';
import 'voice_waveform.dart';
import 'top_toast.dart';

class VoiceInputBottomSheet extends StatefulWidget {
  const VoiceInputBottomSheet({super.key});

  @override
  State<VoiceInputBottomSheet> createState() => _VoiceInputBottomSheetState();
}

class _VoiceInputBottomSheetState extends State<VoiceInputBottomSheet> with SingleTickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  final GeminiAiService _geminiService = GeminiAiService();
  
  String _recognizedText = "";
  bool _isListening = false;
  bool _isInitializing = true;
  bool _isAiProcessing = false;
  String? _errorMessage;
  double _soundLevel = 0;
  Map<String, dynamic>? _parsedData;
  late AnimationController _orbAnimationController;
  Timer? _silenceTimer;

  // Hạn mức tiêu dùng
  double? _dailyLimit;
  bool _dailyLimitEnabled = false;
  double _todayExpenseTotal = 0;

  final List<String> _quickSuggestions = [
    'Bún bò 35k',
    'Cà phê 30 ngàn',
    'Đổ xăng 50k',
    'Đặt hạn mức ngày 200k',
    'Hạn mức 500k',
    'Tiền lương 15 triệu',
  ];

  @override
  void initState() {
    super.initState();
    _orbAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _loadSpendingLimitInfo();
    _initAndStartListening();
  }

  Future<void> _loadSpendingLimitInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyLimitEnabled = prefs.getBool('daily_limit_enabled') ?? false;
      _dailyLimit = prefs.getDouble('daily_spending_limit');

      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthService().offlineUid;
      if (uid != null) {
        final txRepo = TransactionRepository();
        txRepo.setUid(uid);
        final allTx = await txRepo.getAllTransactions();
        final now = DateTime.now();
        final todayTx = allTx.where((t) =>
            t.type == 'expense' &&
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day).toList();
        _todayExpenseTotal = todayTx.fold<double>(0.0, (acc, t) => acc + t.amount);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _orbAnimationController.dispose();
    _voiceService.cancelListening();
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    // 1. Kiểm tra quyền Microphone
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'Cần cấp quyền Microphone để sử dụng giọng nói.\nVào Cài đặt > Ứng dụng > mono > Quyền > Micro';
          });
        }
        return;
      }
    }

    // 2. Khởi tạo VoiceService
    final isReady = await _voiceService.init();
    if (!mounted) return;

    if (!isReady) {
      setState(() {
        _isInitializing = false;
        _errorMessage = _voiceService.lastError ?? 'Không thể khởi tạo nhận diện giọng nói.\nThiết bị có thể chưa hỗ trợ tính năng này.';
      });
      return;
    }

    setState(() => _isInitializing = false);
    _startListening();
  }

  void _startListening() async {
    if (!mounted) return;
    
    setState(() {
      _isListening = true;
      _parsedData = null;
      _recognizedText = "";
      _errorMessage = null;
    });

    final silenceMs = AiConfigService().voiceSilenceDurationMs;
    _silenceTimer?.cancel();
    await _voiceService.startListening(
      pauseFor: Duration(milliseconds: silenceMs),
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
          });
          // Tự động phát hiện nói xong theo cấu hình phản hồi
          _silenceTimer?.cancel();
          if (text.trim().isNotEmpty) {
            _silenceTimer = Timer(Duration(milliseconds: silenceMs), () async {
              if (mounted && _isListening && _recognizedText.trim().isNotEmpty) {
                debugPrint('VoiceInput: Ngừng nói ${silenceMs}ms, tự động ngắt mic và bóc tách thông tin');
                setState(() => _isListening = false);
                await _voiceService.stopListening();
                _processText(_recognizedText);
              }
            });
          }
        }
      },
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level;
          });
        }
      },
      onDone: () async {
        _silenceTimer?.cancel();
        if (mounted) {
          if (_voiceService.isAudioRecording) {
            await _voiceService.stopListening();
          }
          if (mounted) {
            setState(() {
              _isListening = false;
              _isAiProcessing = false;
              if (_recognizedText.isNotEmpty) {
                _processText(_recognizedText);
              }
            });
          }
        }
      },
    );
  }

  Future<void> _processText(String text) async {
    if (!mounted || text.trim().isEmpty) return;

    // 1. Phân tích nhanh bằng regex để hiện UI ngay lập tức
    final localParsed = _voiceService.parseVoiceCommand(text);
    if (mounted) {
      setState(() {
        _parsedData = localParsed;
        if (_parsedData != null && _parsedData!['isDailyLimit'] != true) {
          final categoryName = _parsedData!['category'];
          _parsedData!['iconCode'] = CategoryUtils.getCategoryIcon(categoryName).codePoint;
        }
      });
    }

    // 2. Gọi Google AI Studio (Gemini 2.0/3.6 Flash) để phân tích ngữ nghĩa chuẩn xác
    try {
      if (mounted) setState(() => _isAiProcessing = true);
      final aiResult = await _geminiService.parseNaturalLanguage(text);

      // Nếu là câu lệnh trợ lý thông minh (Chia tiền, Hạn mức, Thủng ví, Dự báo, Lời khuyên, Cố vấn...), chuyển thẳng sang Trợ lý Mono
      if (aiResult.actionType != AiActionType.recordTransaction) {
        if (mounted) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => AiAssistantScreen(initialVoiceText: text)));
          return;
        }
      }

      if (mounted && aiResult.isSuccess && aiResult.transactions.isNotEmpty) {
        final tx = aiResult.transactions.first;
        setState(() {
          _parsedData = {
            'amount': tx.amount,
            'category': tx.category,
            'iconCode': tx.categoryIconCode,
            'type': tx.type,
            'description': tx.description,
            'time': '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}',
            'walletName': tx.walletName,
            'isFromGemini': true,
          };
          _isAiProcessing = false;
        });
      } else {
        if (mounted) setState(() => _isAiProcessing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  void _confirmSelection() async {
    if (_parsedData == null) return;

    // Xử lý lệnh đặt hạn mức chi tiêu ngày
    if (_parsedData!['isDailyLimit'] == true) {
      final amount = (_parsedData!['amount'] as num).toDouble();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('daily_spending_limit', amount);
      await prefs.setBool('daily_limit_enabled', true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'settings': {
              'dailySpendingLimit': amount,
              'dailyLimitEnabled': true,
            }
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        TopToast.show(
          context,
          '🎯 ${context.tr('daily_limit_saved')}: ${CurrencyUtils.formatCurrency(amount)}',
        );
      }
      return;
    }
    
    // Đóng Bottom Sheet hiện tại và mở Màn hình Add Transaction với dữ liệu đã được parse
    final parsedCopy = Map<String, dynamic>.from(_parsedData!);
    if (!mounted) return;
    
    // Lấy navigator trước khi pop
    final navigator = Navigator.of(context);
    navigator.pop();
    
    // Delay nhỏ cho animation pop hoàn thành
    await Future.delayed(const Duration(milliseconds: 250));
    
    navigator.push(
      PageTransitions.slideUp(AddTransactionScreen(initialData: parsedCopy)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isListening = _isListening;
    final hasParsedData = _parsedData != null;
    final isLimit = _parsedData?['isDailyLimit'] == true;
    final hasError = _errorMessage != null;

    final bgColor = isDark ? const Color(0xFF132220) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Cân bằng không gian
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasError
                      ? Colors.red.withValues(alpha: 0.15)
                      : (isListening
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9))),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasError
                        ? Colors.red.withValues(alpha: 0.3)
                        : (isListening ? const Color(0xFF10B981).withValues(alpha: 0.4) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1))),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hasError
                            ? Colors.red
                            : (isListening ? const Color(0xFF10B981) : (isDark ? Colors.grey : const Color(0xFF64748B))),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasError
                          ? 'Lỗi'
                          : (_isInitializing 
                              ? 'Đang khởi tạo...'
                              : (_isAiProcessing
                                  ? '✨ Trợ lý đang xử lý...'
                                  : (isListening 
                                      ? '✨ Đang lắng nghe...' 
                                      : context.tr('voice_input_title')))),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiAssistantScreen(initialVoiceText: _recognizedText),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF438883).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: Color(0xFF438883)),
                      SizedBox(width: 4),
                      Text('Chat AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF438883))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ERROR STATE
          if (hasError) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withValues(alpha: 0.12) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFFECACA)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF991B1B), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _initAndStartListening,
                        icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : const Color(0xFF334155), size: 18),
                        label: Text('Thử lại', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155))),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final micStatus = await Permission.microphone.status;
                          if (!micStatus.isGranted) {
                            await openAppSettings();
                          } else {
                            await _voiceService.openVoiceInputSettings();
                          }
                        },
                        icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                        label: const Text('Cài đặt giọng nói'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF438883),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // INITIALIZING STATE
          if (_isInitializing) ...[
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5),
            const SizedBox(height: 10),
            Text(
              'Đang khởi tạo nhận diện giọng nói...',
              style: TextStyle(color: subtextColor, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],

          // NORMAL STATE - MIC ORB
          if (!_isInitializing && !hasError) ...[
            GestureDetector(
              onTap: () async {
                if (_isListening) {
                  _silenceTimer?.cancel();
                  setState(() {
                    _isListening = false;
                    if (_voiceService.isAiVoiceMode) {
                      _isAiProcessing = true;
                    }
                  });
                  await _voiceService.stopListening();
                  if (!_voiceService.isAiVoiceMode && _recognizedText.isNotEmpty) {
                    _processText(_recognizedText);
                  }
                } else {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _orbAnimationController,
                builder: (context, child) {
                  final pulse = _isListening ? _orbAnimationController.value : 0.0;
                  final scale = 1.0 + (pulse * 0.12) + (_soundLevel.clamp(0.0, 10.0) * 0.02);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withValues(alpha: _isListening ? 0.5 + (pulse * 0.3) : 0.2),
                            blurRadius: _isListening ? 24 : 10,
                            spreadRadius: _isListening ? 6 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Smooth Waveform
            VoiceWaveform(
              isListening: _isListening,
              currentLevel: _soundLevel,
            ),
            const SizedBox(height: 10),

            // Recognized Text Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Text(
                _recognizedText.isEmpty
                    ? (_isAiProcessing
                        ? '✨ Đang chuyển giọng nói thành văn bản qua AI...'
                        : (_isListening
                            ? (_voiceService.isAiVoiceMode ? 'Đang lắng nghe... Bấm mic khi nói xong' : context.tr('voice_listening'))
                            : context.tr('voice_tap_to_speak')))
                    : _recognizedText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: _recognizedText.isEmpty ? 0.6 : 0.95)
                      : (_recognizedText.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontStyle: _recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Quick Suggestion Chips (Adapted for Light & Dark mode)
          if (!_isInitializing && !hasError) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_outlined, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('voice_suggestions_title'),
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickSuggestions.map((suggestion) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _voiceService.cancelListening();
                            setState(() {
                              _isListening = false;
                              _recognizedText = suggestion;
                            });
                            _processText(suggestion);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F766E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Parsed Results Preview - Thẻ xem trước chi tiết thông tin tinh gọn
          if (hasParsedData) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isLimit
                    ? (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFFFEF3C7))
                    : (_parsedData!['type'] == 'income'
                        ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFFF97316).withValues(alpha: 0.15) : const Color(0xFFFFF7ED))),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLimit
                      ? (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : const Color(0xFFFDE68A))
                      : (_parsedData!['type'] == 'income'
                          ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0))
                          : (isDark ? const Color(0xFFF97316).withValues(alpha: 0.4) : const Color(0xFFFED7AA))),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isLimit
                            ? Colors.amber
                            : CategoryUtils.getVibrantColor(_parsedData!['category'] ?? ''),
                        child: Icon(
                          isLimit ? Icons.track_changes : Icons.check,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLimit
                                  ? '🎯 ${context.tr('daily_limit_title')}'
                                  : '${_parsedData!['type'] == 'income' ? context.tr('income') : context.tr('expense')} • ${context.trCat(_parsedData!['category'] ?? '')}',
                              style: TextStyle(
                                color: isLimit
                                    ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                    : (_parsedData!['type'] == 'income'
                                        ? (isDark ? Colors.greenAccent : const Color(0xFF047857))
                                        : (isDark ? Colors.orangeAccent : const Color(0xFFC2410C))),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.formatCurrency((_parsedData!['amount'] as num).toDouble()),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Hiển thị lý do/nội dung tinh gọn
                  if (_parsedData!['description'] != null &&
                      (_parsedData!['description'] as String).isNotEmpty &&
                      _parsedData!['description'] != _parsedData!['category']) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lý do: ${_parsedData!['description']}',
                        style: TextStyle(
                          color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  // Tích hợp cảnh báo / trạng thái hạn mức tiêu dùng
                  if (!isLimit &&
                      _parsedData!['type'] == 'expense' &&
                      _dailyLimitEnabled &&
                      _dailyLimit != null &&
                      _dailyLimit! > 0) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final expenseAmount = (_parsedData!['amount'] as num).toDouble();
                        final projectedTotal = _todayExpenseTotal + expenseAmount;
                        final isOver = projectedTotal > _dailyLimit!;
                        final diff = (projectedTotal - _dailyLimit!).abs();

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isOver
                                ? (isDark ? Colors.red.withValues(alpha: 0.2) : const Color(0xFFFEE2E2))
                                : (isDark ? Colors.teal.withValues(alpha: 0.2) : const Color(0xFFE0F2FE)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOver
                                  ? (isDark ? Colors.redAccent.withValues(alpha: 0.4) : const Color(0xFFFCA5A5))
                                  : (isDark ? Colors.tealAccent.withValues(alpha: 0.4) : const Color(0xFFBAE6FD)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOver ? Icons.warning_amber_rounded : Icons.track_changes_rounded,
                                size: 16,
                                color: isOver ? Colors.redAccent : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isOver
                                      ? 'Cảnh báo: Khoản chi này sẽ vượt hạn mức ngày ${CurrencyUtils.formatCurrency(diff)}!'
                                      : 'Hạn mức ngày: Còn lại ${CurrencyUtils.formatCurrency(_dailyLimit! - projectedTotal)}.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isOver
                                        ? (isDark ? Colors.redAccent : const Color(0xFFB91C1C))
                                        : (isDark ? Colors.tealAccent : const Color(0xFF0369A1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (hasParsedData && !_isListening) {
                      _startListening();
                    } else {
                      _silenceTimer?.cancel();
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(hasParsedData && !_isListening ? Icons.refresh_rounded : Icons.close, size: 18),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  label: Text(hasParsedData && !_isListening ? 'Nói lại' : context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isInitializing
                      ? null
                      : (hasError
                          ? _initAndStartListening
                          : (_isListening
                              ? () async {
                                  _silenceTimer?.cancel();
                                  await _voiceService.stopListening();
                                  if (mounted) {
                                    setState(() => _isListening = false);
                                    _processText(_recognizedText);
                                  }
                                }
                              : (hasParsedData ? _confirmSelection : null))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasError
                        ? Colors.orange
                        : (isLimit ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    disabledForegroundColor: isDark ? Colors.white30 : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    hasError
                        ? 'Thử lại'
                        : (_isListening
                            ? 'Dừng nói'
                            : (isLimit ? context.tr('save') : 'Kiểm tra & Xác nhận')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
