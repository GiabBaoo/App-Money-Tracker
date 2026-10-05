import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/modules/home/wallet_screen.dart';
import 'package:money_tracker_app/modules/settings/ai_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet Screen Ergonomic Scrolling & Thumb Zone Tests', () {
    testWidgets('1. WalletScreen builds with smooth Stack, Hero Net Worth and Action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WalletScreen(),
        ),
      );
      // Settle staggered animations
      await tester.pump(const Duration(seconds: 1));

      // Verify that Hero Net Worth card is present
      expect(find.byKey(const PageStorageKey('wallet_unified_scroll')), findsOneWidget);
      expect(find.text('Tổng tài sản'), findsOneWidget);

      // Verify Quick Action Hub (Chuyển tiền, Thêm ví, Cân đối) is completely removed for clean UI
      expect(find.text('Chuyển tiền'), findsNothing);
      expect(find.text('Thêm ví'), findsNothing);
      expect(find.text('Cân đối'), findsNothing);

      // Verify Privacy Eye Toggle in Hero Net Worth card
      expect(find.text('Ẩn'), findsOneWidget);
      await tester.tap(find.text('Ẩn'));
      await tester.pump();
      expect(find.text('Hiện'), findsOneWidget);

      // Verify top title when at top
      expect(find.byKey(const ValueKey('normal_title')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('2. WalletScreen scrolling triggers Sticky Mini Balance Bar and Floating Capsule', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WalletScreen(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Cuộn xuống 250px
      final scrollFinder = find.byKey(const PageStorageKey('wallet_unified_scroll'));
      await tester.drag(scrollFinder, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));

      // Khi cuộn xuống sâu, Sticky Mini Balance Bar phải xuất hiện
      expect(find.byKey(const ValueKey('sticky_mini_balance')), findsOneWidget);
    });
  });

  group('AI Settings Screen Sticky Bottom Bar & Ergonomics Tests', () {
    testWidgets('1. AiSettingsScreen renders AppBar with dynamic status chip and Sticky Bottom Bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AiSettingsScreen(),
        ),
      );
      await tester.pump();

      // Verify AppBar title
      expect(find.text('Cài đặt Trợ lý AI Mono'), findsOneWidget);

      // Verify buttons
      expect(find.text('Kiểm tra Qwen 2.5'), findsOneWidget);
      expect(find.text('Lưu cấu hình'), findsOneWidget);

      // Verify sections exist
      expect(find.text('Cấu hình Mô hình Trí tuệ Nhân tạo'), findsOneWidget);
      expect(find.text('Cổng kết nối Local AI (Endpoint)'), findsOneWidget);
      expect(find.text('Độ trễ phản hồi của Mono'), findsOneWidget);
    });
  });
}
