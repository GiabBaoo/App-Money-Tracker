import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/session/session_manager.dart';
import 'package:money_tracker_app/core/utils/firestore_parse.dart';
import 'package:money_tracker_app/features/group_expense/domain/services/vnd_split_calculator.dart';
import 'package:money_tracker_app/services/language_service.dart';

void main() {
  group('FirestoreParse', () {
    test('parseDate supports Timestamp, int, String ISO, DateTime, null', () {
      final dt = DateTime.utc(2026, 5, 10, 12, 30);
      expect(FirestoreParse.parseDate(Timestamp.fromDate(dt))?.toUtc(), dt);
      expect(FirestoreParse.parseDate(dt), dt);
      expect(
        FirestoreParse.parseDate(dt.millisecondsSinceEpoch)?.toUtc(),
        dt,
      );
      expect(FirestoreParse.parseDate(dt.toIso8601String())?.toUtc(), dt);
      expect(FirestoreParse.parseDate(null), isNull);
      expect(FirestoreParse.parseDate('invalid-date'), isNull);
    });

    test('parseBool supports bool, num, String', () {
      expect(FirestoreParse.parseBool(true), isTrue);
      expect(FirestoreParse.parseBool(false), isFalse);
      expect(FirestoreParse.parseBool(1), isTrue);
      expect(FirestoreParse.parseBool(0), isFalse);
      expect(FirestoreParse.parseBool('true'), isTrue);
      expect(FirestoreParse.parseBool('1'), isTrue);
      expect(FirestoreParse.parseBool('false'), isFalse);
      expect(FirestoreParse.parseBool(null, defaultValue: true), isTrue);
    });

    test('parseInt and parseDouble handle int, double, String safely', () {
      expect(FirestoreParse.parseInt(42), 42);
      expect(FirestoreParse.parseInt(42.9), 42);
      expect(FirestoreParse.parseInt('123'), 123);
      expect(FirestoreParse.parseInt('123.7'), 123);
      expect(FirestoreParse.parseInt('abc'), isNull);

      expect(FirestoreParse.parseDouble(100), 100.0);
      expect(FirestoreParse.parseDouble('99.5'), 99.5);
      expect(FirestoreParse.parseDouble(null, defaultValue: 5.0), 5.0);
    });
  });

  group('VndSplitCalculator', () {
    test('equal split preserves exact integer sum with remainder to payer', () {
      final splits = VndSplitCalculator.calculateEqualSplit(
        totalAmountVnd: 100000,
        participantIds: ['u1', 'u2', 'u3'],
        payerId: 'u2',
      );
      expect(splits.values.reduce((a, b) => a + b), 100000);
      expect(splits['u2'], 33334);
      expect(splits['u1'], 33333);
      expect(splits['u3'], 33333);
    });

    test('percentage split preserves exact integer sum', () {
      final splits = VndSplitCalculator.calculatePercentageSplit(
        totalAmountVnd: 100000,
        percentages: {'u1': 33.33, 'u2': 33.33, 'u3': 33.34},
        payerId: 'u1',
      );
      expect(splits.values.reduce((a, b) => a + b), 100000);
    });

    test('shares split preserves exact integer sum', () {
      final splits = VndSplitCalculator.calculateSharesSplit(
        totalAmountVnd: 100000,
        shares: {'u1': 1, 'u2': 2},
        payerId: 'u1',
      );
      expect(splits.values.reduce((a, b) => a + b), 100000);
      expect(splits['u1'], 33333);
      expect(splits['u2'], 66667);
    });

    test('exact split throws on sum mismatch', () {
      expect(
        () => VndSplitCalculator.calculateExactSplit(
          totalAmountVnd: 100000,
          exactAmounts: {'u1': 40000, 'u2': 50000},
        ),
        throwsArgumentError,
      );
    });
  });

  group('LanguageService translations', () {
    test('required Vietnamese keys are defined and not raw keys', () {
      final lang = LanguageService.instance;
      const requiredKeys = [
        'total_income',
        'total_expense',
        'change_photo',
        'no_data',
        'total',
        'all_transactions',
        'delete_wallet',
      ];
      for (final key in requiredKeys) {
        final translated = lang.t(key);
        expect(translated, isNot(equals(key)), reason: 'Missing key: $key');
      }
      expect(lang.t('total_income'), 'Tổng thu');
      expect(lang.t('total_expense'), 'Tổng chi');
      expect(lang.t('change_photo'), 'Đổi ảnh');
    });
  });

  group('SessionManager', () {
    test('activate emits SessionSnapshot with uid and end emits null', () async {
      final events = <SessionSnapshot?>[];
      final sub = SessionManager.instance.changes.listen(events.add);
      addTearDown(sub.cancel);

      SessionManager.instance.activate('user_test_123');
      SessionManager.instance.end();
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0]?.uid, 'user_test_123');
      expect(events[1], isNull);
    });
  });
}
