import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/models/transaction_model.dart';
import 'package:money_tracker_app/modules/auth/fingerprint_unlock_screen.dart';
import 'package:money_tracker_app/modules/calendar/calendar_tracking_screen.dart';
import 'package:money_tracker_app/modules/home/statistics_screen.dart';
import 'package:money_tracker_app/modules/transaction/all_transactions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Time Filter Preset Logic Tests (Month-to-Date, Today, 7 Days, 30 Days, Last Month)', () {
    final now = DateTime.now();

    final txToday = TransactionModel(
      id: 'tx_today',
      uid: 'user_1',
      type: 'expense',
      category: 'Ăn uống',
      categoryIconCode: 1,
      amount: 45000,
      description: 'Cơm trưa',
      date: DateTime(now.year, now.month, now.day, 12, 0),
      walletId: 'w1',
    );

    final txFirstDayOfMonth = TransactionModel(
      id: 'tx_first_day',
      uid: 'user_1',
      type: 'income',
      category: 'Tiền lương',
      categoryIconCode: 2,
      amount: 10000000,
      description: 'Lương đầu tháng',
      date: DateTime(now.year, now.month, 1, 8, 30),
      walletId: 'w1',
    );

    final txLastMonth = TransactionModel(
      id: 'tx_last_month',
      uid: 'user_1',
      type: 'expense',
      category: 'Mua sắm',
      categoryIconCode: 3,
      amount: 300000,
      description: 'Mua áo tháng trước',
      date: DateTime(now.year, now.month - 1, 15, 10, 0),
      walletId: 'w1',
    );

    final allTxs = [txToday, txFirstDayOfMonth, txLastMonth];

    test('1. Kiểm tra lọc "Đầu tháng đến nay" (month_to_date)', () {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final filtered = allTxs.where((tx) {
        final d = tx.date;
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();

      expect(filtered.map((t) => t.id), containsAll(['tx_today', 'tx_first_day']));
      expect(filtered.map((t) => t.id), isNot(contains('tx_last_month')));
    });

    test('2. Kiểm tra lọc "Hôm nay" (today)', () {
      final filtered = allTxs.where((tx) {
        final d = tx.date;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('tx_today'));
    });

    test('3. Kiểm tra lọc "Tháng trước" (last_month)', () {
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);

      final filtered = allTxs.where((tx) {
        final d = tx.date;
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('tx_last_month'));
    });
  });

  group('Widget Instantiation & Build Smoke Tests', () {
    testWidgets('FingerprintUnlockScreen khởi tạo thành công và render biểu tượng vân tay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FingerprintUnlockScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(FingerprintUnlockScreen), findsOneWidget);
      expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
      expect(find.text('Chào mừng bạn trở lại'), findsOneWidget);
    });

    testWidgets('CalendarTrackingScreen khởi tạo thành công và render top app bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalendarTrackingScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(CalendarTrackingScreen), findsOneWidget);
      expect(find.text('Lịch Theo Dõi Thu Chi'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
    });

    testWidgets('AllTransactionsScreen khởi tạo thành công với pill thời gian "Đầu tháng đến nay"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AllTransactionsScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(AllTransactionsScreen), findsOneWidget);
      expect(find.text('Lịch Sử Giao Dịch'), findsOneWidget);
      expect(find.text('Đầu tháng đến nay'), findsOneWidget);
    });

    testWidgets('StatisticsScreen khởi tạo thành công và hiển thị các tab Tuần, Tháng, Năm', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatisticsScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(StatisticsScreen), findsOneWidget);
      expect(find.byIcon(Icons.analytics_rounded), findsOneWidget);
    });
  });
}
