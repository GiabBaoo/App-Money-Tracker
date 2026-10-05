import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/widgets/app_logo.dart';
import 'package:money_tracker_app/modules/onboarding/onboarding_screen.dart';
import 'package:money_tracker_app/modules/transaction/edit_transaction_screen.dart';
import 'package:money_tracker_app/models/transaction_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLogo Widget Tests', () {
    testWidgets('AppLogo.wordmark renders Image.asset with assets/images/logo.png', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo.wordmark(height: 32, color: Colors.teal),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, 'assets/images/logo.png');
      expect(imageWidget.color, Colors.teal);
    });

    testWidgets('AppLogo.badge renders Container with logo asset inside', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo.badge(size: 64),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, 'assets/images/logo.png');
      expect(imageWidget.color, Colors.white);
    });
  });

  group('OnboardingScreen Redesign Tests', () {
    testWidgets('OnboardingScreen renders AppLogo, carousel, skip button, and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Verify AppLogo badge và wordmark được render
      expect(find.byType(AppLogo), findsNWidgets(2));

      // Verify nút 'Bỏ qua' hiển thị ở slide đầu tiên
      expect(find.text('Bỏ qua'), findsOneWidget);

      // Verify tiêu đề slide đầu tiên
      expect(find.textContaining('Chi tiêu thông minh'), findsOneWidget);

      // Verify nút Tiếp tục
      expect(find.text('Tiếp tục'), findsOneWidget);

      // Verify dòng đăng nhập
      expect(find.textContaining('Đăng nhập'), findsOneWidget);
    });

    testWidgets('OnboardingScreen swipe or next page updates page and shows Bắt đầu ngay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Bấm nút Tiếp tục để sang slide 2
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trợ lý tài chính AI'), findsOneWidget);

      // Bấm Tiếp tục tiếp để sang slide 3
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Quỹ chi tiêu nhóm'), findsOneWidget);
      expect(find.text('Bắt đầu ngay'), findsOneWidget);
    });
  });

  group('EditTransactionScreen Date Time Auto-scale Tests', () {
    testWidgets('EditTransactionScreen renders Ngày & Giờ tiles with full width layout', (tester) async {
      final sampleTx = TransactionModel(
        id: 'test_tx_001',
        uid: 'user_123',
        amount: 35000,
        type: 'expense',
        category: 'Ăn uống',
        categoryIconCode: Icons.fastfood_rounded.codePoint,
        description: 'Cà phê sáng',
        date: DateTime(2026, 9, 28),
        time: '09:30',
        walletId: 'default_wallet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditTransactionScreen(transaction: sampleTx),
        ),
      );

      // Verify tiêu đề màn hình
      expect(find.text('Chỉnh sửa giao dịch'), findsOneWidget);

      // Verify nhãn Ngày và Giờ
      expect(find.text('Ngày'), findsOneWidget);
      expect(find.text('Giờ'), findsOneWidget);

      // Verify giá trị ngày giờ được render
      expect(find.text('28/09/2026'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);

      // Verify FittedBox tồn tại để đảm bảo auto-scale chữ khi đổi kích thước màn hình
      expect(find.byType(FittedBox), findsWidgets);
    });
  });
}
