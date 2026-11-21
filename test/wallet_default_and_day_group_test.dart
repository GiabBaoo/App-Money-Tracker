import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/services/language_service.dart';
import 'package:money_tracker_app/utils/time_utils.dart';
import 'package:money_tracker_app/widgets/day_grouped_transaction_list.dart';

TransactionModel _makeTx(
  String id, {
  required DateTime date,
  String type = 'expense',
  double amount = 50000,
}) {
  return TransactionModel(
    id: id,
    uid: 'u1',
    type: type,
    category: 'Ăn uống',
    categoryIconCode: Icons.fastfood.codePoint,
    amount: amount,
    date: date,
    time:
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
    walletId: 'w1',
  );
}

void main() {
  group('TimeUtils.groupTransactionsByDay', () {
    test('returns empty list for empty transactions', () {
      expect(TimeUtils.groupTransactionsByDay(const [], maxDays: 3), isEmpty);
    });

    test('keeps up to 3 most recent distinct days with transactions (non-consecutive)', () {
      final txs = [
        _makeTx('t1', date: DateTime(2026, 11, 21, 14, 0), amount: 100000),
        _makeTx('t2', date: DateTime(2026, 11, 21, 9, 0), type: 'income', amount: 500000),
        _makeTx('t3', date: DateTime(2026, 11, 18, 20, 0), amount: 45000),
        _makeTx('t4', date: DateTime(2026, 11, 15, 12, 0), amount: 30000),
        _makeTx('t5', date: DateTime(2026, 11, 15, 8, 0), amount: 20000),
        _makeTx('t6', date: DateTime(2026, 11, 10, 10, 0), amount: 999000),
      ];

      final groups = TimeUtils.groupTransactionsByDay(txs, maxDays: 3);
      expect(groups.length, 3);
      expect(groups[0].date, DateTime(2026, 11, 21));
      expect(groups[0].transactions.length, 2);
      expect(groups[0].totalIncome, 500000);
      expect(groups[0].totalExpense, 100000);

      expect(groups[1].date, DateTime(2026, 11, 18));
      expect(groups[1].transactions.length, 1);
      expect(groups[1].totalExpense, 45000);

      expect(groups[2].date, DateTime(2026, 11, 15));
      expect(groups[2].transactions.length, 2);
      expect(groups[2].totalExpense, 50000);
    });

    test('splits transactions across midnight into separate days and keeps all items per day', () {
      final txs = [
        for (int i = 0; i < 8; i++)
          _makeTx('d2_$i', date: DateTime(2026, 11, 21, 0, i), amount: 10000),
        _makeTx('d1_late', date: DateTime(2026, 11, 20, 23, 59), amount: 25000),
      ];

      final groups = TimeUtils.groupTransactionsByDay(txs, maxDays: 3);
      expect(groups.length, 2);
      expect(groups[0].date, DateTime(2026, 11, 21));
      expect(groups[0].transactions.length, 8);
      expect(groups[0].totalExpense, 80000);
      expect(groups[1].date, DateTime(2026, 11, 20));
      expect(groups[1].transactions.length, 1);
      expect(groups[1].totalExpense, 25000);
    });
  });

  group('TimeUtils.formatFriendlyDate', () {
    final now = DateTime(2026, 11, 21, 18, 0);

    test('formats today, yesterday and weekday in Vietnamese and English', () {
      expect(
        TimeUtils.formatFriendlyDate(DateTime(2026, 11, 21), isVi: true, now: now),
        'Hôm nay - 21/11/2026',
      );
      expect(
        TimeUtils.formatFriendlyDate(DateTime(2026, 11, 20), isVi: true, now: now),
        'Hôm qua - 20/11/2026',
      );
      expect(
        TimeUtils.formatFriendlyDate(DateTime(2026, 11, 21), isVi: false, now: now),
        'Today - 21/11/2026',
      );
      expect(
        TimeUtils.formatFriendlyDate(DateTime(2026, 11, 20), isVi: false, now: now),
        'Yesterday - 20/11/2026',
      );
      expect(
        TimeUtils.formatFriendlyDate(DateTime(2026, 11, 18), isVi: true, now: now),
        'Thứ Tư - 18/11/2026',
      );
    });
  });

  testWidgets('TransactionViewModeToggle switches between Recent and By day', (
    tester,
  ) async {
    bool groupByDay = false;
    await tester.pumpWidget(
      LanguageScope(
        service: LanguageService.instance,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => TransactionViewModeToggle(
                groupByDay: groupByDay,
                onChanged: (v) => setState(() => groupByDay = v),
              ),
            ),
          ),
        ),
      ),
    );

    final byDayText = LanguageService.instance.isVietnamese
        ? 'Theo ngày'
        : 'By day';
    await tester.tap(find.text(byDayText));
    await tester.pumpAndSettle();
    expect(groupByDay, isTrue);
  });
}
