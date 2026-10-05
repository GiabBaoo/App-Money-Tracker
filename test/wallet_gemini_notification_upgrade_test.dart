import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/ai_config_service.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini API Upgrade & Multi-Model Failover Tests', () {
    test('AiConfigService defaults to gemini-3.6-flash', () {
      final config = AiConfigService();
      expect(config.modelName, equals('gemini-3.6-flash'));
      expect(AiConfigService.latestModel, equals('gemini-3.6-flash'));
    });

    test('GeminiAiService primary and fallback models are updated and supported', () {
      expect(GeminiAiService.primaryModel, equals('gemini-3.6-flash'));
      expect(GeminiAiService.fallbackModel, equals('gemini-flash-lite-latest'));
      // Đảm bảo không còn chứa các model đã bị Google khai tử
      expect(GeminiAiService.primaryModel, isNot(contains('gemini-2.0-flash')));
      expect(GeminiAiService.primaryModel, isNot(contains('gemini-1.5-flash')));
      expect(GeminiAiService.fallbackModel, isNot(contains('gemini-2.0-flash')));
      expect(GeminiAiService.fallbackModel, isNot(contains('gemini-1.5-flash')));
    });
  });
}
