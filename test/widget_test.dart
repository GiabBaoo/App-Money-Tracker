import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/widgets/animated_scale_button.dart';

void main() {
  testWidgets('AnimatedScaleButton renders child and handles taps', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedScaleButton(
            onTap: () {
              tapped = true;
            },
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);

    await tester.tap(find.text('Tap Me'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}

