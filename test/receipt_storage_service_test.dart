import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/services/receipt_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptStorageService Tests', () {
    testWidgets('buildReceiptImage renders placeholder when both path and url are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptStorageService.buildReceiptImage(
              photoLocalPath: '',
              photoUrl: '',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    });

    testWidgets('buildReceiptImage renders Image.memory for valid Base64 Data URI', (tester) async {
      // 1x1 transparent GIF encoded in Base64
      const sampleBase64 = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
      const sampleDataUri = 'data:image/gif;base64,$sampleBase64';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptStorageService.buildReceiptImage(
              photoLocalPath: '',
              photoUrl: sampleDataUri,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('buildReceiptImage falls back to placeholder on invalid Base64 URI', (tester) async {
      const invalidDataUri = 'data:image/jpeg;base64,invalid_base64_data!!!';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptStorageService.buildReceiptImage(
              photoLocalPath: '',
              photoUrl: invalidDataUri,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    });

    test('Base64 encode and decode roundtrip works correctly', () {
      final sampleBytes = utf8.encode('invoice_test_data_123456');
      final encoded = base64Encode(sampleBytes);
      final dataUri = 'data:image/jpeg;base64,$encoded';

      final extractedBase64 = dataUri.split(',').last;
      final decodedBytes = base64Decode(extractedBase64);
      final decodedString = utf8.decode(decodedBytes);

      expect(decodedString, 'invoice_test_data_123456');
    });
  });
}
