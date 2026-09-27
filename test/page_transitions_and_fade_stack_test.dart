import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/utils/page_transitions.dart';
import 'package:money_tracker_app/widgets/fade_indexed_stack.dart';

void main() {
  group('PageTransitions Unit & Widget Tests', () {
    test('PageTransitions creates non-null Route instances with correct settings', () {
      final dummyPage = Container();

      final slideRightRoute = PageTransitions.slideRight(dummyPage) as PageRouteBuilder;
      expect(slideRightRoute, isA<PageRouteBuilder>());
      expect(slideRightRoute.transitionDuration, equals(const Duration(milliseconds: 300)));
      expect(slideRightRoute.reverseTransitionDuration, equals(const Duration(milliseconds: 250)));

      final slideUpRoute = PageTransitions.slideUp(dummyPage) as PageRouteBuilder;
      expect(slideUpRoute, isA<PageRouteBuilder>());
      expect(slideUpRoute.transitionDuration, equals(const Duration(milliseconds: 300)));

      final fadeRoute = PageTransitions.fade(dummyPage) as PageRouteBuilder;
      expect(fadeRoute, isA<PageRouteBuilder>());
      expect(fadeRoute.transitionDuration, equals(const Duration(milliseconds: 250)));

      final scaleRoute = PageTransitions.scale(dummyPage) as PageRouteBuilder;
      expect(scaleRoute, isA<PageRouteBuilder>());
      expect(scaleRoute.transitionDuration, equals(const Duration(milliseconds: 300)));
    });

    testWidgets('FadeIndexedStack renders selected tab and transitions smoothly', (WidgetTester tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FadeIndexedStack(
                  index: activeIndex,
                  duration: const Duration(milliseconds: 200),
                  children: const [
                    Text('Tab 0 Content'),
                    Text('Tab 1 Content'),
                    Text('Tab 2 Content'),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      activeIndex = 1;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Ban đầu Tab 0 hiển thị
      expect(find.text('Tab 0 Content'), findsOneWidget);
      expect(find.text('Tab 1 Content'), findsNothing);

      // Chuyển sang Tab 1
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 100)); // Halfway

      // Tab 1 đã xuất hiện và đang fade in
      expect(find.text('Tab 1 Content'), findsOneWidget);

      await tester.pumpAndSettle(); // Hoàn tất animation
      expect(find.text('Tab 1 Content'), findsOneWidget);
    });
  });
}
