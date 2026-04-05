import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../services/firestore_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speechToText.initialize(
      onError: (e) => print('Speech Error: $e'),
      onStatus: (s) => print('Speech Status: $s'),
    );
    return _isInitialized;
  }

  bool get isListening => _speechToText.isListening;

  Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onDone,
  }) async {
    final ready = await init();
    if (!ready) return;

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone();
        }
      },
      localeId: 'vi_VN', // Set to Vietnamese
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  /// Simple parsing logic: "Ăn sáng 30 ngàn" -> {category: "Ăn uống", amount: 30000}
  Map<String, dynamic>? parseVoiceCommand(String text) {
    if (text.isEmpty) return null;
    
    // Normalize text
    final cleanText = text.toLowerCase();
    
    // Extract number
    final RegExp numReg = RegExp(r'(\d+)');
    final match = numReg.firstMatch(cleanText);
    double amount = 0;
    if (match != null) {
      amount = double.tryParse(match.group(1)!) ?? 0;
      
      // Handle "ngàn" or "k"
      if (cleanText.contains('ngàn') || cleanText.contains('nghìn') || cleanText.contains(' k')) {
        amount *= 1000;
      } else if (cleanText.contains('triệu') || cleanText.contains(' tr')) {
        amount *= 1000000;
      }
    }

    if (amount <= 0) return null;

    // Map keywords to category names
    String category = 'Khác';
    if (cleanText.contains('ăn') || cleanText.contains('uống') || cleanText.contains('cafe') || cleanText.contains('phở')) {
      category = 'Ăn uống';
    } else if (cleanText.contains('xăng') || cleanText.contains('xe') || cleanText.contains('bus') || cleanText.contains('grab')) {
      category = 'Di chuyển';
    } else if (cleanText.contains('khám') || cleanText.contains('thuốc') || cleanText.contains('bệnh')) {
      category = 'Sức khỏe';
    } else if (cleanText.contains('học') || cleanText.contains('sách')) {
      category = 'Học tập';
    } else if (cleanText.contains('lương')) {
      category = 'Tiền lương';
    } else if (cleanText.contains('thưởng')) {
      category = 'Tiền thưởng';
    }

    return {
      'category': category,
      'amount': amount,
      'isIncome': cleanText.contains('lương') || cleanText.contains('thưởng') || cleanText.contains('nhận') || cleanText.contains('thu'),
      'note': text,
    };
  }
}
