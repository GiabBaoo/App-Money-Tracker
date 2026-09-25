import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'gemini_ai_service.dart';
import 'connectivity_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  static const MethodChannel _platformChannel = MethodChannel('app.mono/settings');

  SpeechToText? _speechToTextInstance;
  SpeechToText get _speechToText => _speechToTextInstance ??= SpeechToText();

  AudioRecorder? _audioRecorderInstance;
  AudioRecorder get _audioRecorder => _audioRecorderInstance ??= AudioRecorder();

  bool _isInitialized = false;
  bool _supportsVietnamese = false;
  bool _isAudioRecording = false;
  bool _isListeningSTT = false;
  String _vietnameseLocaleId = 'vi_VN';
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _lastError;

  Function(String)? _activeResultCallback;
  VoidCallback? _activeDoneCallback;
  bool _hasDispatchedDone = false;

  String? get lastError => _lastError;
  bool get isAvailable => _isInitialized;
  bool get supportsVietnamese => _supportsVietnamese;
  bool get isAudioRecording => _isAudioRecording;
  bool get isAiVoiceMode => _isAudioRecording || !_supportsVietnamese;
  bool get isListening => _isListeningSTT || (_speechToTextInstance?.isListening == true) || _isAudioRecording;

  /// Mở trực tiếp màn hình cài đặt dịch vụ nhận dạng giọng nói trên Android / Xiaomi
  Future<bool> openVoiceInputSettings() async {
    try {
      final res = await _platformChannel.invokeMethod<bool>('openVoiceSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('VoiceService: Failed to open voice settings via channel: $e');
      try {
        return await openAppSettings();
      } catch (_) {
        return false;
      }
    }
  }

  void _safeDispatchDone() {
    if (!_hasDispatchedDone) {
      _hasDispatchedDone = true;
      final cb = _activeDoneCallback;
      _activeDoneCallback = null;
      cb?.call();
    }
  }

  Future<void> _internalCancel() async {
    _isListeningSTT = false;
    if (_speechToTextInstance?.isListening == true) {
      try {
        await _speechToTextInstance?.cancel();
        await Future.delayed(const Duration(milliseconds: 80));
      } catch (_) {}
    }
    if (_isAudioRecording) {
      _isAudioRecording = false;
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      try {
        final path = await _audioRecorderInstance?.stop();
        final finalPath = path ?? _currentRecordingPath;
        if (finalPath != null) {
          final file = File(finalPath);
          if (await file.exists()) {
            try { await file.delete(); } catch (_) {}
          }
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
  }

  Future<bool> init({bool forceReinit = false}) async {
    // 1. Kiểm tra và yêu cầu quyền microphone trước
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          _lastError = 'Chưa được cấp quyền Microphone. Vui lòng cấp quyền trong Cài đặt.';
          _isInitialized = false;
          return false;
        }
      }
    } catch (e) {
      debugPrint('VoiceService: Permission check error: $e');
    }

    if (_isInitialized && !forceReinit && _supportsVietnamese) return true;

    _lastError = null;

    // 2. Khởi tạo SpeechToText hệ thống để nhận diện trực tiếp thời gian thực (Native STT)
    try {
      final sttSuccess = await _speechToText.initialize(
        onError: (error) {
          debugPrint('VoiceService (STT Error): ${error.errorMsg} (permanent: ${error.permanent})');
          _lastError = error.errorMsg;

          // Bỏ qua các lỗi không nghiêm trọng khi người dùng chưa kịp nói hoặc khoảng lặng tự nhiên
          final isHarmless = error.errorMsg.contains('no_match') ||
              error.errorMsg.contains('speech_timeout');
          if (isHarmless && !error.permanent) {
            debugPrint('VoiceService: Harmless STT pause/silence, continuing listen...');
            return;
          }

          if (_isListeningSTT) {
            _isListeningSTT = false;
            if (error.errorMsg.contains('language') || error.errorMsg.contains('not_supported')) {
              _supportsVietnamese = false;
            }
            _safeDispatchDone();
          }
        },
        onStatus: (status) {
          debugPrint('VoiceService (STT Status): $status');
          // CHÚ Ý: KHÔNG ngắt mic khi status là 'notListening'!
          // Trên Android, onEndOfSpeech() gửi 'notListening' trước khi onResults kịp giải mã xong.
          // Chỉ ngắt và dispatch khi status thực sự là 'done'.
          if (status == 'done' && _isListeningSTT) {
            _isListeningSTT = false;
            Future.delayed(const Duration(milliseconds: 250), () {
              _safeDispatchDone();
            });
          }
        },
        debugLogging: false,
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('VoiceService: STT initialize timed out');
          return false;
        },
      );

      if (sttSuccess) {
        _supportsVietnamese = true; // Luôn kích hoạt native STT khi speech recognizer khả dụng
        _vietnameseLocaleId = 'vi_VN';

        try {
          final locales = await _speechToText.locales().timeout(
            const Duration(seconds: 3),
            onTimeout: () => [],
          );
          debugPrint('VoiceService: STT locales count = ${locales.length}');

          final viLocale = locales.firstWhere(
            (l) => l.localeId.toLowerCase().replaceAll('_', '-').startsWith('vi'),
            orElse: () => LocaleName('', ''),
          );

          if (viLocale.localeId.isNotEmpty) {
            _vietnameseLocaleId = viLocale.localeId;
            debugPrint('VoiceService: Matched Vietnamese locale from system: $_vietnameseLocaleId');
          } else {
            // Thiết bị Pixel / Samsung có thể chỉ liệt kê model offline tiếng Anh trong checkRecognitionSupport,
            // nhưng Google Speech Services vẫn nhận diện tiếng Việt online qua vi_VN rất mượt mà.
            _vietnameseLocaleId = 'vi_VN';
            debugPrint('VoiceService: System locales did not list vi (${locales.map((e) => e.localeId).join(", ")}). Defaulting to online vi_VN');
          }
        } catch (e) {
          debugPrint('VoiceService: Error querying locales: $e. Defaulting to vi_VN');
          _vietnameseLocaleId = 'vi_VN';
        }
      } else {
        _supportsVietnamese = false;
        debugPrint('VoiceService: STT initialize returned false.');
      }
    } catch (e) {
      debugPrint('VoiceService: STT init exception: $e');
      _supportsVietnamese = false;
    }

    _isInitialized = true;
    return true;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(double) onSoundLevelChange,
    required VoidCallback onDone,
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    await _internalCancel();

    _hasDispatchedDone = false;
    _activeResultCallback = onResult;
    _activeDoneCallback = onDone;

    final ready = await init();
    if (!ready) {
      debugPrint('VoiceService: Cannot start listening - not initialized');
      _safeDispatchDone();
      return;
    }

    // 1. NẾU MÁY HỖ TRỢ TIẾNG VIỆT QUA SPEECH-TO-TEXT HỆ THỐNG:
    if (_supportsVietnamese && _speechToText.isAvailable) {
      try {
        _isListeningSTT = true;
        await _speechToText.listen(
          onResult: (SpeechRecognitionResult result) {
            debugPrint('VoiceService (STT): "${result.recognizedWords}" (final: ${result.finalResult})');
            if (result.recognizedWords.isNotEmpty) {
              onResult(result.recognizedWords);
            }
            if (result.finalResult) {
              _isListeningSTT = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                _safeDispatchDone();
              });
            }
          },
          onSoundLevelChange: (level) {
            onSoundLevelChange(level.clamp(0.0, 10.0));
          },
          localeId: _vietnameseLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: pauseFor,
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
        debugPrint('VoiceService: Started real-time STT with $_vietnameseLocaleId');
        return;
      } catch (e) {
        debugPrint('VoiceService: Real-time STT failed: $e, switching to AI Audio Recording fallback');
        _isListeningSTT = false;
      }
    }

    // 2. NẾU MÁY KHÔNG HỖ TRỢ TIẾNG VIỆT HOẶC STT LỖI:
    try {
      final isOnline = ConnectivityService().isOnline;
      if (!isOnline) {
        _lastError = 'Thiết bị cần kết nối Internet để nhận diện giọng nói tiếng Việt qua AI.';
        _safeDispatchDone();
        return;
      }

      final dir = await getTemporaryDirectory();
      _currentRecordingPath = '${dir.path}/mono_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      _isAudioRecording = true;

      _amplitudeSub?.cancel();
      bool hasDetectedSpeech = false;
      DateTime? lastSpeechTime;
      final startTime = DateTime.now();
      double ambientNoise = -55.0;
      int sampleCount = 0;

      _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((amp) {
        final db = amp.current;
        double level = 0.0;
        if (db > -55) {
          level = ((db + 55) / 55) * 10.0;
        }
        onSoundLevelChange(level.clamp(0.0, 10.0));

        sampleCount++;
        if (sampleCount <= 4) {
          if (db < ambientNoise) ambientNoise = db;
        }

        final now = DateTime.now();
        final isSpeaking = db > -38.0 || (sampleCount > 4 && db > ambientNoise + 7.0 && db > -46.0);

        if (isSpeaking) {
          hasDetectedSpeech = true;
          lastSpeechTime = now;
        } else if (hasDetectedSpeech && lastSpeechTime != null) {
          final silenceDuration = now.difference(lastSpeechTime!);
          if (silenceDuration >= pauseFor) {
            debugPrint('VoiceService (VAD): Im lặng ${silenceDuration.inMilliseconds}ms >= ${pauseFor.inMilliseconds}ms -> Tự động kết thúc.');
            _amplitudeSub?.cancel();
            _amplitudeSub = null;
            _safeDispatchDone();
            return;
          }
        } else if (!hasDetectedSpeech && now.difference(startTime).inSeconds >= 10) {
          debugPrint('VoiceService (VAD): Không phát hiện tiếng nói sau 10s -> Dừng.');
          _amplitudeSub?.cancel();
          _amplitudeSub = null;
          _safeDispatchDone();
          return;
        }

        if (now.difference(startTime).inSeconds >= 30) {
          debugPrint('VoiceService (VAD): Đạt thời gian tối đa 30s -> Tự động dừng.');
          _amplitudeSub?.cancel();
          _amplitudeSub = null;
          _safeDispatchDone();
          return;
        }
      });

      debugPrint('VoiceService: Started AI Audio Recording with auto-execute (${pauseFor.inMilliseconds}ms) to $_currentRecordingPath');
    } catch (e) {
      debugPrint('VoiceService: Start recording error: $e');
      _lastError = 'Lỗi khởi động micro thu âm: $e';
      _isAudioRecording = false;
      _safeDispatchDone();
    }
  }

  /// Dừng hủy hoàn toàn không gửi kết quả
  Future<void> cancelListening() async {
    _hasDispatchedDone = true;
    _activeResultCallback = null;
    _activeDoneCallback = null;
    await _internalCancel();
  }

  Future<String?> stopListening() async {
    _isListeningSTT = false;

    // 1. Dừng STT nếu đang chạy
    if (_speechToTextInstance?.isListening == true) {
      try {
        await _speechToTextInstance?.stop();
        debugPrint('VoiceService: STT listening stopped');
      } catch (e) {
        debugPrint('VoiceService: Error stopping STT: $e');
      }
    }

    // 2. Dừng Audio Recording nếu đang chạy
    if (_isAudioRecording) {
      _isAudioRecording = false;
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      try {
        final path = await _audioRecorderInstance?.stop();
        final finalPath = path ?? _currentRecordingPath;
        if (finalPath != null) {
          final file = File(finalPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            try { await file.delete(); } catch (_) {}

            if (bytes.length >= 2048) {
              debugPrint('VoiceService: Transcribing ${bytes.length} audio bytes via Gemini...');
              final transcript = await GeminiAiService().transcribeAudio(bytes, mimeType: 'audio/mp4');
              if (transcript != null && transcript.trim().isNotEmpty) {
                final cleaned = transcript.trim();
                debugPrint('VoiceService (Gemini AI Result): "$cleaned"');
                _activeResultCallback?.call(cleaned);
                return cleaned;
              }
            } else {
              debugPrint('VoiceService: Audio file too short (${bytes.length} bytes), skipping transcription');
            }
          }
        }
      } catch (e) {
        debugPrint('VoiceService: Stop recording / transcribe error: $e');
      } finally {
        _currentRecordingPath = null;
      }
    }
    return null;
  }

  /// Trích xuất lý do/nội dung tinh gọn (chỉ giữ chi/thu vì cái gì)
  String _extractCleanReason(String originalText, String cleanText, String category) {
    String s = ' $cleanText ';
    final removeWords = [
      'tôi vừa mới', 'tôi vừa', 'tôi mới', 'vừa mới', 'vừa', 'mới',
      'hôm nay', 'sáng nay', 'trưa nay', 'chiều nay', 'tối nay', 'ngày mai',
      'tầm khoảng', 'khoảng', 'khoản', 'tầm', 'cỡ', 'độ', 'hết',
      'cho tôi', 'giúp tôi',
      'mới được nhận', 'vừa được nhận', 'được nhận',
      'mới được cộng', 'vừa được cộng', 'được cộng',
      'nhận được', 'mới nhận', 'vừa nhận',
      'cộng thêm', 'cộng vào', 'cộng tiền', 'tiền về',
      'vào ví', 'và ví', 'từ ví', 'tài khoản', 'ví',
      'momo', 'mono', 'zalopay', 'tiền mặt',
      'nghìn', 'ngàn', 'triệu', 'đồng', 'vnd', 'củ', 'lít', 'tỷ',
      'trăm', 'trắm', 'mươi', 'mưới', 'mười', 'chục', 'linh', 'lẻ', 'rưỡi',
      'không', 'một', 'mốt', 'hai', 'ba', 'bốn', 'tư', 'năm', 'lăm', 'nhăm', 'sáu', 'bảy', 'tám', 'chín',
      'nhé', 'nha', 'ạ', 'ơi', 'cho', 'nhận', 'được', 'và',
    ];
    // Sắp xếp từ dài đến ngắn để xóa cụm từ trước
    removeWords.sort((a, b) => b.length.compareTo(a.length));
    for (final w in removeWords) {
      s = s.replaceAll(' $w ', ' ');
    }
    s = s.replaceAll('+', ' ').replaceAll('-', ' ').replaceAll('₫', ' ').replaceAll('đ', ' ');
    s = s.replaceAll(RegExp(r'\d+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (s.isEmpty || s.length < 2) {
      if (category == 'Thu khác' && (originalText.contains(RegExp(r'momo|mono', caseSensitive: false)))) {
        return 'Cộng tiền vào ví MoMo';
      }
      return category;
    }

    return s[0].toUpperCase() + s.substring(1);
  }

  /// Giải mã số tiền đọc bằng chữ hoặc hỗn hợp số + chữ tiếng Việt
  /// Hỗ trợ cả biến thể phiên âm STT: "trắm" -> "trăm", "mưới" -> "mươi", v.v.
  double parseVietnameseNumber(String text) {
    String normalized = text.toLowerCase()
        .replaceAll('₫', ' ')
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

  /// Advanced parsing logic for Vietnamese
  Map<String, dynamic>? parseVoiceCommand(String text) {
    if (text.isEmpty) return null;
    
    String cleanText = text.toLowerCase().trim()
        .replaceAll('₫', 'đ')
        .replaceAll('và ví', 'vào ví')
        .replaceAll('  ', ' ');

    final bool hasPlusSign = cleanText.contains('+') || RegExp(r'\+\s*\d+').hasMatch(text);
    final bool hasMinusSign = cleanText.contains('-') || RegExp(r'-\s*\d+').hasMatch(text);
        
    int? parsedHour;
    int? parsedMinute;
    
    // Tìm thời gian (VD: "8h sáng", "8 giờ 30", "20h")
    final timeReg = RegExp(r'\b(\d{1,2})\s*(h|giờ|g|:)\s*(\d{1,2})?\s*(sáng|trưa|chiều|tối|đêm)?\b');
    final timeMatch = timeReg.firstMatch(cleanText);
    if (timeMatch != null) {
      parsedHour = int.tryParse(timeMatch.group(1)!);
      parsedMinute = timeMatch.group(3) != null ? int.tryParse(timeMatch.group(3)!) : 0;
      final session = timeMatch.group(4);
      
      if (parsedHour != null) {
        if (session == 'chiều' || session == 'tối' || session == 'đêm') {
          if (parsedHour < 12) parsedHour += 12;
        } else if (session == 'sáng' && parsedHour == 12) {
          parsedHour = 0;
        }
      }
      cleanText = cleanText.replaceFirst(timeMatch.group(0)!, ' ');
    }

    // 1. Trích xuất số tiền: Hỗ trợ phân cách hàng nghìn (9.880đ), đơn vị scale (1.5tr, 35k), số hỗn hợp (9 nghìn 8 trắm 8 mưới) và chữ số
    double amount = 0;

    // 1.1 Phân cách hàng nghìn kiểu Việt Nam: 9.880, 50.000, 1.500.000 (hỗ trợ cả +9.880, +50.000)
    final thousandsSepRegex = RegExp(r'(?:\+|-)?\s*(\d{1,3}(?:\.\d{3})+)\s*(đ|đồng|vnd)?\b', caseSensitive: false);
    final thousandsMatch = thousandsSepRegex.firstMatch(cleanText);
    if (thousandsMatch != null) {
      final cleanStr = thousandsMatch.group(1)!.replaceAll('.', '');
      final val = double.tryParse(cleanStr);
      if (val != null && val > 0) {
        amount = val;
      }
    }

    // 1.2 Số thập phân kèm đơn vị quy đổi: 1.5tr, 2.5k, 1,5 triệu (hỗ trợ cả +1.5tr)
    if (amount <= 0) {
      final scaleDecimalRegex = RegExp(r'(?:\+|-)?\s*(\d+[,\.]\d+)\s*(k|nghìn|ngàn|tr|triệu|củ)\b', caseSensitive: false);
      final scaleDecMatch = scaleDecimalRegex.firstMatch(cleanText);
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
        }
      }
    }

    // 1.3 Giải mã số hỗn hợp (chữ + số, biến thể âm STT): "9 nghìn 8 trắm 8 mưới", "9 nghìn 8 trăm 80", "chín nghìn tám trăm tám mươi"
    if (amount <= 0) {
      final compoundVal = parseVietnameseNumber(cleanText);
      if (compoundVal > 0) {
        amount = compoundVal;
      }
    }

    // 1.4 Số nguyên kèm đơn vị quy đổi thông thường: 35k, 50 nghìn, 2 triệu (hỗ trợ cả +50k)
    if (amount <= 0) {
      final scaleRegex = RegExp(r'(?:\+|-)?\s*(\d+(?:[\.,]\d+)?)\s*(k|nghìn|ngàn|tr|triệu|củ)\b', caseSensitive: false);
      final scaleMatch = scaleRegex.firstMatch(cleanText);
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
          if (cleanText.contains('rưỡi')) {
            if (unit == 'tr' || unit == 'triệu' || unit == 'củ') amount += 500000;
            if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') amount += 500;
          }
        }
      }
    }

    // 1.5 Số nguyên thông thường: 9880, 50000 (hỗ trợ cả +9880)
    if (amount <= 0) {
      final plainNumRegex = RegExp(r'(?:\+|-)?\s*(\d+)\s*(đ|đồng|vnd)?\b', caseSensitive: false);
      final plainMatch = plainNumRegex.firstMatch(cleanText);
      if (plainMatch != null) {
        amount = double.tryParse(plainMatch.group(1)!) ?? 0;
      }
    }

    if (amount <= 0) return null;

    // 2. Kiểm tra xem có phải là lệnh đặt hạn mức chi tiêu mỗi ngày không
    final limitKeywords = [
      'hạn mức', 'đặt hạn mức', 'cài hạn mức', 'hạn mức chi tiêu',
      'hạn mức ngày', 'giới hạn chi tiêu', 'set limit', 'daily limit', 'limit',
      'giới hạn', 'hạn mức tháng', 'giới hạn tháng',
    ];
    if (limitKeywords.any((kw) => cleanText.contains(kw))) {
      return {
        'isDailyLimit': true,
        'amount': amount,
        'description': text,
      };
    }

    // 2.1 Nhận diện Ví tiền
    String wallet = '';
    if (cleanText.contains('momo') || cleanText.contains('mono')) {
      wallet = 'MoMo';
    } else if (cleanText.contains('tiền mặt')) {
      wallet = 'Tiền mặt';
    } else if (cleanText.contains('zalopay')) {
      wallet = 'ZaloPay';
    } else if (cleanText.contains('ngân hàng') ||
        cleanText.contains('techcombank') ||
        cleanText.contains('vietcombank') ||
        cleanText.contains('mbbank') ||
        cleanText.contains('bidv') ||
        cleanText.contains('agribank') ||
        cleanText.contains('vpbank') ||
        cleanText.contains('tpbank') ||
        cleanText.contains('acb')) {
      wallet = 'Ngân hàng';
    }

    // 3. Match Category
    String category = 'Chi khác';
    String type = 'expense';
    
    final categoriesMap = {
      // INCOME CATEGORIES (Ưu tiên Lên Đầu)
      'Tiền lương': ['lương', 'salary', 'nhận lương', 'lãnh lương', 'ting ting lương', 'phát lương', 'tiền công', 'trả công'],
      'Tiền thưởng': ['thưởng', 'bonus', 'khoản thu', 'khoảng thu', 'hoa hồng', 'tiền bo', 'tip', 'kpi'],
      'Tiền thuê nhà': ['tiền thuê nhà', 'thuê nhà', 'thu tiền nhà', 'nhận tiền thuê nhà', 'tiền trọ', 'thu tiền trọ'],
      'Được cho/Tặng': [
        'lì xì', 'mẹ cho', 'bố cho', 'cho tiền', 'được cho', 'nhận được', 'cho tôi', 'tặng',
        'mẹ tôi cho', 'bố tôi cho', 'biếu', 'tài trợ', 'nhận tiền', 'được nhận', 'mới được nhận',
        'vừa được nhận', 'mới nhận', 'vừa nhận', 'ai cho'
      ],
      'Bán đồ': ['bán hàng', 'bán', 'lời', 'lãi', 'thu được', 'thanh lý', 'sang nhượng', 'đẩy đi', 'pass lại'],
      'Kinh doanh': ['kinh doanh', 'lợi nhuận', 'doanh thu', 'đầu tư', 'tiền lãi', 'cổ tức', 'nhận tiền nhà', 'cho thuê'],
      'Thu khác': [
        'trúng số', 'nhặt được', 'tiền rớt', 'quỹ đen', 'bồi thường',
        'được cộng', 'mới được cộng', 'vừa được cộng', 'cộng thêm', 'cộng vào', 'cộng tiền', 'vào ví', 'tiền về'
      ],

      // SPECIFIC EXPENSE CATEGORIES
      'Tiền nhà': ['thuê nhà', 'tiền nhà', 'trọ', 'nhà trọ', 'chung cư', 'quản lý phí'],
      'Tiền điện': ['điện', 'tiền điện', 'evn', 'nước', 'tiền nước', 'internet', 'wifi', 'cáp quang', 'tiền mạng', 'cước viễn thông'],
      'Điện thoại': ['điện thoại', 'nạp card', 'thẻ cào', 'thẻ viettel', 'thẻ mobi', 'thẻ vina', 'cước điện thoại', 'cước trả trước', 'cước trả sau', 'nạp thẻ', 'nạp tiền điện thoại'],
      'Sức khỏe': ['thuốc', 'khám', 'bệnh', 'nha khoa', 'vitamin', 'bệnh viện', 'phòng khám', 'xét nghiệm', 'bảo hiểm y tế', 'viện phí', 'tiêm phòng', 'băng cá nhân', 'y tế'],
      'Học tập': ['học', 'sách', 'vở', 'khóa học', 'bút', 'giáo trình', 'học phí', 'thi lại', 'hành trang', 'kỹ năng', 'toeic', 'ielts', 'tiếng anh'],
      'Thể thao': ['thể thao', 'gym', 'bơi', 'đá bóng', 'cầu lông', 'chạy', 'tennis', 'yoga', 'đạp xe', 'vợt', 'giày chạy', 'thuê sân', 'bóng đá', 'billard', 'bi a', 'bida'],
      'Di chuyển': ['xăng', 'xe', 'bus', 'grab', 'be', 'taxi', 'vé máy bay', 'tàu', 'gửi xe', 'bến', 'bơm xe', 'thay nhớt', 'rửa xe', 'vé xe', 'thu phí', 'bot', 'bảo dưỡng'],
      'Giải trí': ['phim', 'nhạc', 'game', 'karaoke', 'xem phim', 'netflix', 'spotify', 'gacha', 'nạp game', 'vé concert', 'nhạc hội', 'đi lượn', 'chơi'],
      'Du lịch': ['du lịch', 'khách sạn', 'homestay', 'resort', 'máy bay', 'phòng', 'vé tham quan', 'tour', 'visa', 'đặt phòng', 'villas'],
      'Quà tặng': ['quà', 'mừng', 'sinh nhật', 'lễ', 'đám cưới', 'chu cấp', 'thăm hỏi', 'phúng điếu', 'ma chay', 'thôi nôi', 'đầy tháng', 'tặng bạn', 'tặng người yêu'],
      'Tiết kiệm': ['tiết kiệm', 'bỏ ống heo', 'đút lợn', 'gửi ngân hàng', 'nuôi heo'],
      'Thú cưng': ['thú cưng', 'chó mèo', 'thức ăn chó mèo', 'pate', 'cát vệ sinh', 'cám chó', 'cám mèo', 'thú y'],
      'Từ thiện': ['từ thiện', 'quyên góp', 'ủng hộ', 'cúng dường', 'nhang đèn', 'đi chùa'],
      'Bảo hiểm': ['bảo hiểm nhân thọ', 'bảo hiểm xe', 'đóng bảo hiểm'],
      'Con cái': ['bỉm', 'sữa', 'đồ chơi', 'học phí cho con', 'nuôi con'],
      'Làm đẹp': ['spa', 'cắt tóc', 'gội đầu', 'làm móng', 'nail', 'skincare', 'makeup', 'nối mi', 'massage', 'làm đẹp'],

      // BROAD EXPENSE CATEGORIES
      'Ăn uống': ['ăn', 'uống', 'cafe', 'phở', 'bún', 'cơm', 'trà', 'nhậu', 'tiệc', 'bánh', 'mì', 'phê', 'sinh tố', 'trà sữa', 'ốc', 'nhà hàng', 'xôi', 'chè', 'đồ ăn', 'đồ uống', 'nước ép', 'bia', 'pizza', 'gà rán', 'hamburger', 'trái cây'],
      'Mua sắm': ['mua', 'shopee', 'lazada', 'quần', 'áo', 'giày', 'dép', 'túi', 'siêu thị', 'đồ dùng', 'mỹ phẩm', 'tiki', 'tiktok shop', 'váy', 'son', 'kem chống nắng', 'sắm'],
    };

    int maxKeywordLength = -1;
    for (var entry in categoriesMap.entries) {
      for (var keyword in entry.value) {
        if (cleanText.contains(keyword)) {
          if (keyword.length > maxKeywordLength) {
            category = entry.key;
            maxKeywordLength = keyword.length;
          }
        }
      }
    }

    // Determine type (income or expense)
    if (hasPlusSign ||
        ['Tiền lương', 'Tiền thưởng', 'Tiền thuê nhà', 'Kinh doanh', 'Được cho/Tặng', 'Bán đồ', 'Thu khác'].contains(category) || 
        cleanText.contains('được nhận') || cleanText.contains('mới được nhận') || cleanText.contains('vừa được nhận') ||
        cleanText.contains('nhận được') || cleanText.contains('mới nhận') || cleanText.contains('vừa nhận') ||
        cleanText.contains('được cộng') || cleanText.contains('mới được cộng') || cleanText.contains('vừa được cộng') ||
        cleanText.contains('cộng thêm') || cleanText.contains('cộng vào') || cleanText.contains('cộng tiền') ||
        cleanText.contains('thu nhập') || cleanText.contains('được cho') || cleanText.contains('mẹ cho') || 
        cleanText.contains('bố cho') || cleanText.contains('cho tiền') || cleanText.contains('trả tiền') || 
        cleanText.contains('khoản thu') || cleanText.contains('khoảng thu') || cleanText.contains('cho tôi') ||
        cleanText.contains('đưa tôi') || cleanText.contains('mẹ tôi cho') || cleanText.contains('bán') || 
        cleanText.contains('lời ') || cleanText.contains('lãi') || cleanText.contains('thu được') || 
        cleanText.contains('đầu tư') || cleanText.contains('trúng số') || cleanText.contains('nhận tiền') || 
        cleanText.contains('thu tiền') || cleanText.contains('cho thuê') || cleanText.contains('lãnh lương') || 
        cleanText.contains('thanh lý') || cleanText.contains('vào ví') || cleanText.contains('tiền về')) {
      type = 'income';
      if (category == 'Chi khác') {
        category = 'Thu khác';
      }
    }
    if (hasMinusSign && !hasPlusSign) {
      type = 'expense';
    }

    final reason = _extractCleanReason(text, cleanText, category);

    return {
      'category': category,
      'amount': amount,
      'type': type,
      'description': reason,
      'wallet': wallet,
      'walletName': wallet,
      'hour': parsedHour,
      'minute': parsedMinute,
    };
  }
}
