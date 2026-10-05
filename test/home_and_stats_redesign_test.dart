import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker_app/modules/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget() {
    return const ProviderScope(
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Redesign Widget Tests', () {
    testWidgets('HomeScreen renders Floating Dock and 4 Quick Action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Kiểm tra 4 tab trên Floating Glassmorphic Dock
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // 2. Kiểm tra nút FAB thêm giao dịch ở trung tâm Dock
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // 3. Kiểm tra Bộ 4 nút Thao tác nhanh (Quick Actions Grid) trên HomeBody
      expect(find.text('Chuyển tiền'), findsOneWidget);
      expect(find.text('Quét hóa đơn'), findsOneWidget);
      expect(find.text('Ngân sách'), findsOneWidget);
      expect(find.text('Trợ lý Mono'), findsOneWidget);

      // 4. Kiểm tra nút con mắt ẩn/hiện số dư bảo mật
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.text('Hiện'), findsOneWidget);

      // Nhấn nút ẩn số dư
      await tester.tap(find.text('Hiện'));
      await tester.pump();

      // Kiểm tra chuyển sang trạng thái Ẩn
      expect(find.text('Ẩn'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.text('•••••••• ₫'), findsOneWidget);

      // Nhấn lại để hiện lại
      await tester.tap(find.text('Ẩn'));
      await tester.pump();
      expect(find.text('Hiện'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Chờ pending timer của staggered animation hoàn tất
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Switch tab via Floating Dock works smoothly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Chuyển sang Tab Thống kê (index 1)
      await tester.tap(find.byIcon(Icons.bar_chart_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Chuyển sang Tab Ví tiền (index 2)
      await tester.tap(find.byIcon(Icons.account_balance_wallet_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Chuyển lại Tab Trang chủ (index 0)
      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chuyển tiền'), findsOneWidget);

      // Chờ pending timers kết thúc an toàn
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
