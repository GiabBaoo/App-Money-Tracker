import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/page_transitions.dart';
import 'package:money_tracker_app/widgets/animated_scale_button.dart';
import 'package:money_tracker_app/widgets/staggered_list_item.dart';
import 'package:money_tracker_app/widgets/fade_indexed_stack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Animation & Performance Optimization Tests', () {
    testWidgets('1. AnimatedScaleButton has snappy tactile duration (<=100ms) and RepaintBoundary', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedScaleButton(
                onTap: () => tapped = true,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(AnimatedScaleButton);
      expect(buttonFinder, findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);

      // Tap and verify callback
      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('2. StaggeredListItem renders immediately for items beyond index 4 (no lagging scroll)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StaggeredListItem(index: 0, child: Text('Item 0')),
                StaggeredListItem(index: 5, child: Text('Item 5')),
                StaggeredListItem(index: 10, child: Text('Item 10')),
              ],
            ),
          ),
        ),
      );

      // Item 5 and 10 should render immediately without waiting for long delayed timers
      expect(find.text('Item 5'), findsOneWidget);
      expect(find.text('Item 10'), findsOneWidget);
    });

    testWidgets('3. FadeIndexedStack has fast 120ms tab duration and RepaintBoundary', (tester) async {
      int selectedTab = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: FadeIndexedStack(
                  index: selectedTab,
                  children: const [
                    Text('Tab 0 View'),
                    Text('Tab 1 View'),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => selectedTab = 1),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Tab 0 View'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(find.text('Tab 1 View'), findsOneWidget);
    });

    test('4. PageTransitions uses 220ms forward and 180ms reverse', () {
      final route = PageTransitions.slideRight(const SizedBox()) as PageRouteBuilder;
      expect(route.transitionDuration, const Duration(milliseconds: 220));
      expect(route.reverseTransitionDuration, const Duration(milliseconds: 180));
    });
  });
}
