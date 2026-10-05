import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_keys.dart';

class AiConfigService extends ChangeNotifier {
  static final AiConfigService _instance = AiConfigService._internal();
  factory AiConfigService() => _instance;
  AiConfigService._internal();

  static const _keyStorageKey = 'gemini_api_key';
  static const _modelStorageKey = 'gemini_model_name';
  static const _silenceDurationKey = 'voice_silence_duration_ms';
  static const _responseDelayKey = 'mono_response_delay_ms';
  static const _engineModeStorageKey = 'ai_engine_mode';
  static const _localModelStorageKey = 'local_model_name';
  static const _localEndpointStorageKey = 'local_ai_endpoint';

  final _secureStorage = const FlutterSecureStorage();
  String _apiKey = '';
  static const String latestModel = 'gemini-3.6-flash';
  String _modelName = latestModel;
  int _voiceSilenceDurationMs = 2000; // Mặc định 2.0 giây
  int _responseDelayMs = 700; // Mặc định 700ms (Chuẩn / Cân bằng)
  
  // Cấu hình AI Local (Mặc định: Qwen 2.5 1.5B-Instruct On-Device/Local)
  static const String defaultLocalModel = 'qwen2.5:1.5b';
  static const String defaultLocalEndpoint = 'http://10.0.2.2:11434';
  String _engineMode = 'local_qwen'; // 'local_qwen' hoặc 'cloud_gemini'
  String _localModelName = defaultLocalModel;
  String _localEndpoint = defaultLocalEndpoint;
  bool _isInitialized = false;

  String get apiKey => _apiKey;
  String get modelName => _modelName;
  int get voiceSilenceDurationMs => _voiceSilenceDurationMs;
  int get responseDelayMs => _responseDelayMs;
  bool get hasValidKey => _apiKey.trim().isNotEmpty;
  String get engineMode => _engineMode;
  bool get isLocalAi => _engineMode == 'local_qwen';
  String get localModelName => _localModelName;
  String get localEndpoint => _localEndpoint;
  bool get isReady => isLocalAi || hasValidKey;

  /// Khởi tạo và đọc API key từ SecureStorage
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final savedKey = await _secureStorage.read(key: _keyStorageKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _apiKey = savedKey.trim();
      } else if (ApiKeys.defaultGeminiApiKey.isNotEmpty) {
        // Fallback vào key cấu hình bí mật cục bộ
        _apiKey = ApiKeys.defaultGeminiApiKey.trim();
        await _secureStorage.write(key: _keyStorageKey, value: _apiKey);
      }

      final savedModel = await _secureStorage.read(key: _modelStorageKey);
      // Tự động nâng cấp các model đã bị Google khai tử (2.0, 1.5, 2.5) hoặc model 3.8 đang dính 503 spike lên 3.6-flash ổn định
      if (savedModel != null &&
          savedModel.isNotEmpty &&
          !savedModel.contains('2.0') &&
          !savedModel.contains('1.5') &&
          !savedModel.contains('2.5') &&
          savedModel != 'gemini-3.8-flash') {
        _modelName = savedModel;
      } else {
        _modelName = latestModel;
        await _secureStorage.write(key: _modelStorageKey, value: latestModel);
      }

      final savedSilence = await _secureStorage.read(key: _silenceDurationKey);
      if (savedSilence != null) {
        final parsed = int.tryParse(savedSilence);
        if (parsed != null && parsed >= 1500 && parsed <= 5000) {
          _voiceSilenceDurationMs = parsed;
        } else {
          // Tự động nâng cấp các mốc < 1500 (như 1000ms cũ) lên mốc chuẩn 2000ms
          _voiceSilenceDurationMs = 2000;
          await _secureStorage.write(key: _silenceDurationKey, value: '2000');
        }
      }

      final savedDelay = await _secureStorage.read(key: _responseDelayKey);
      if (savedDelay != null) {
        final parsed = int.tryParse(savedDelay);
        if (parsed != null && (parsed == 300 || parsed == 700 || parsed == 1500)) {
          _responseDelayMs = parsed;
        } else {
          _responseDelayMs = 700;
          await _secureStorage.write(key: _responseDelayKey, value: '700');
        }
      }

      // Đọc cấu hình Local AI
      final savedEngineMode = await _secureStorage.read(key: _engineModeStorageKey);
      if (savedEngineMode != null && savedEngineMode.isNotEmpty) {
        _engineMode = savedEngineMode;
      } else {
        _engineMode = 'local_qwen';
        await _secureStorage.write(key: _engineModeStorageKey, value: 'local_qwen');
      }

      final savedLocalModel = await _secureStorage.read(key: _localModelStorageKey);
      if (savedLocalModel != null && savedLocalModel.isNotEmpty) {
        _localModelName = savedLocalModel;
      } else {
        _localModelName = defaultLocalModel;
        await _secureStorage.write(key: _localModelStorageKey, value: defaultLocalModel);
      }

      final savedEndpoint = await _secureStorage.read(key: _localEndpointStorageKey);
      if (savedEndpoint != null && savedEndpoint.isNotEmpty) {
        _localEndpoint = savedEndpoint.trim();
      } else {
        _localEndpoint = defaultLocalEndpoint;
        await _secureStorage.write(key: _localEndpointStorageKey, value: defaultLocalEndpoint);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AiConfigService init error: $e');
    }
  }

  /// Cập nhật chế độ Engine ('local_qwen' hoặc 'cloud_gemini')
  Future<void> setEngineMode(String mode) async {
    _engineMode = mode;
    await _secureStorage.write(key: _engineModeStorageKey, value: _engineMode);
    notifyListeners();
  }

  /// Cập nhật tên mô hình Local (VD: 'qwen2.5:1.5b' hoặc 'qwen2.5:0.5b')
  Future<void> setLocalModelName(String model) async {
    _localModelName = model;
    await _secureStorage.write(key: _localModelStorageKey, value: _localModelName);
    notifyListeners();
  }

  /// Cập nhật endpoint Local AI (VD: 'http://10.0.2.2:11434' hoặc 'http://127.0.0.1:11434')
  Future<void> setLocalEndpoint(String endpoint) async {
    _localEndpoint = endpoint.trim();
    await _secureStorage.write(key: _localEndpointStorageKey, value: _localEndpoint);
    notifyListeners();
  }

  /// Cập nhật độ trễ phản hồi của Mono (ms)
  Future<void> setResponseDelayMs(int ms) async {
    _responseDelayMs = ms;
    await _secureStorage.write(key: _responseDelayKey, value: ms.toString());
    notifyListeners();
  }

  /// Cập nhật thời gian chờ im lặng giọng nói (ms)
  Future<void> setVoiceSilenceDurationMs(int ms) async {
    final validMs = ms < 1500 ? 2000 : ms;
    _voiceSilenceDurationMs = validMs;
    await _secureStorage.write(key: _silenceDurationKey, value: validMs.toString());
    notifyListeners();
  }

  /// Cập nhật và lưu API Key mới vào SecureStorage
  Future<void> setApiKey(String newKey) async {
    _apiKey = newKey.trim();
    await _secureStorage.write(key: _keyStorageKey, value: _apiKey);
    notifyListeners();
  }

  /// Cập nhật model name
  Future<void> setModelName(String model) async {
    _modelName = model;
    await _secureStorage.write(key: _modelStorageKey, value: _modelName);
    notifyListeners();
  }

  /// Trả về chuỗi API key đã được che mờ bảo mật (VD: "AQ.Ab8R••••••••Hg")
  String getMaskedApiKey() {
    if (_apiKey.isEmpty) return 'Chưa cấu hình API Key';
    if (_apiKey.length <= 10) return '••••••••••••';
    return '${_apiKey.substring(0, 8)}••••••••${_apiKey.substring(_apiKey.length - 4)}';
  }

  /// Xóa API key khỏi thiết bị
  Future<void> clearApiKey() async {
    _apiKey = '';
    await _secureStorage.delete(key: _keyStorageKey);
    notifyListeners();
  }
}
