import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/language_service.dart';
import 'package:money_tracker_app/services/gemini_ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageService Zero-Tech-Leak Tests', () {
    final lang = LanguageService.instance;

    test('All wallet creation form keys return clean human readable Vietnamese', () {
      expect(lang.t('initial_balance_label'), equals('Số dư ban đầu'));
      expect(lang.t('current_balance_label'), equals('Số dư hiện tại'));
      expect(lang.t('wallet_name_label'), equals('Tên chiếc ví'));
      expect(lang.t('wallet_type_label'), equals('Loại ví tiền'));
      expect(lang.t('color_label'), equals('Màu sắc nhận diện'));
      expect(lang.t('icon_label'), equals('Biểu tượng đại diện'));
      expect(lang.t('default_wallet_label'), equals('Đặt làm ví mặc định'));
      expect(lang.t('note_optional_label'), equals('Ghi chú (tùy chọn)'));
      expect(lang.t('create_wallet_btn'), equals('Tạo ví ngay'));
      expect(lang.t('save_changes'), equals('Lưu thay đổi'));
      expect(lang.t('enter_wallet_name_error'), equals('Vui lòng nhập tên ví!'));
      expect(lang.t('create_wallet_success'), equals('Đã tạo ví mới thành công!'));
    });

    test('No key containing _label or _error leaks raw snake_case when mapped', () {
      final keys = [
        'initial_balance_label',
        'wallet_name_label',
        'wallet_type_label',
        'color_label',
        'icon_label',
        'default_wallet_label',
        'note_optional_label',
      ];

      for (final k in keys) {
        final val = lang.t(k);
        expect(val.contains('_'), isFalse, reason: 'Key $k leaked raw snake_case: $val');
      }
    });

    test('Zero-Tech-Leak Fallback handles unexpected missing _label keys gracefully', () {
      // If a key like 'total_balance_label' was queried, it falls back to 'total_balance'
      final fallbackVal = lang.t('total_balance_label');
      expect(fallbackVal, equals('Tổng số dư'));
    });
  });

  group('GeminiAiService Sanitize and Clean Text Tests', () {
    test('JSON code fences and raw actionType are stripped cleanly', () {
      const rawResponse = '```json\n{"actionType": "generalChat", "reply": "Chào bạn, hôm nay bạn đã chi tiêu hợp lý lắm!"}\n```';
      final parsed = GeminiAiService().parseJsonFromAiTextForTesting(rawResponse);
      expect(parsed.isSuccess, isTrue);
      expect(parsed.aiReply, equals('Chào bạn, hôm nay bạn đã chi tiêu hợp lý lắm!'));
      expect(parsed.aiReply.contains('```'), isFalse);
      expect(parsed.aiReply.contains('actionType'), isFalse);
    });

    test('Malformed JSON with unescaped text extracts reply cleanly in catch block', () {
      const malformedJson = '{"actionType": "generalChat", "reply": "Mẹo tiết kiệm: Hãy ghi chép lại mọi khoản chi nhỏ 10k, 20k nhé!", bad_trailing:';
      final parsed = GeminiAiService().parseJsonFromAiTextForTesting(malformedJson);
      expect(parsed.isSuccess, isTrue);
      expect(parsed.aiReply, contains('Mẹo tiết kiệm: Hãy ghi chép lại'));
      expect(parsed.aiReply.contains('actionType'), isFalse);
    });

    test('Truncated JSON without reply field falls back gracefully with zero code leakage', () {
      const truncatedRaw = '{\n  "actionType": "generalChat",\n  "navigationTarget": null,\n  "themeMode": null,\n  ';
      final parsed = GeminiAiService().parseJsonFromAiTextForTesting(truncatedRaw);
      expect(parsed.isSuccess, isTrue);
      expect(parsed.aiReply.contains('actionType'), isFalse);
      expect(parsed.aiReply.contains('{'), isFalse);
      expect(parsed.aiReply.contains('null'), isFalse);
      expect(parsed.aiReply, contains('Trợ lý Mono'));
    });
  });
}
