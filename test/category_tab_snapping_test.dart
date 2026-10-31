import 'package:blackhole/CustomWidgets/custom_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Category Tab Page Snapping and Alignment Tests', () {
    test('CustomPhysics provides PageScrollPhysics parent and critical damping', () {
      const physics = CustomPhysics();
      expect(physics.parent, isA<PageScrollPhysics>());
      expect(physics.spring.damping, 20.0);
      expect(physics.spring.mass, 80.0);
      expect(physics.spring.stiffness, 100.0);
    });

    testWidgets('TabBarView snaps cleanly to next page when dragged past midpoint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                    Tab(text: 'Genres'),
                  ],
                ),
              ),
              body: const TabBarView(
                physics: PageScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  Center(child: Text('Page 0: Songs Content')),
                  Center(child: Text('Page 1: Albums Content')),
                  Center(child: Text('Page 2: Artists Content')),
                  Center(child: Text('Page 3: Genres Content')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Page 0: Songs Content'), findsOneWidget);
      expect(find.text('Page 1: Albums Content'), findsNothing);

      // Drag 60% of the screen width to the left (past the 50% midpoint)
      await tester.drag(find.text('Page 0: Songs Content'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      // Verified: Cleanly snapped to Page 1 with no partial alignment
      expect(find.text('Page 1: Albums Content'), findsOneWidget);
      expect(find.text('Page 0: Songs Content'), findsNothing);
    });

    testWidgets('TabBarView snaps back to original page when dragged before midpoint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                    Tab(text: 'Genres'),
                  ],
                ),
              ),
              body: const TabBarView(
                physics: PageScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  Center(child: Text('Page 0: Songs Content')),
                  Center(child: Text('Page 1: Albums Content')),
                  Center(child: Text('Page 2: Artists Content')),
                  Center(child: Text('Page 3: Genres Content')),
                ],
              ),
            ),
          ),
        ),
      );

      // Drag only 20% of screen width (less than midpoint) and release
      await tester.drag(find.text('Page 0: Songs Content'), const Offset(-100.0, 0.0));
      await tester.pumpAndSettle();

      // Verified: Snapped back cleanly to Page 0
      expect(find.text('Page 0: Songs Content'), findsOneWidget);
      expect(find.text('Page 1: Albums Content'), findsNothing);
    });

    testWidgets('Direct tab tap and horizontal swipe remain synchronized',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Songs'),
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                    Tab(text: 'Genres'),
                  ],
                ),
              ),
              body: const TabBarView(
                physics: PageScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  Center(child: Text('Page 0: Songs Content')),
                  Center(child: Text('Page 1: Albums Content')),
                  Center(child: Text('Page 2: Artists Content')),
                  Center(child: Text('Page 3: Genres Content')),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap on Tab 2 (Artists) directly
      await tester.tap(find.text('Artists'));
      await tester.pumpAndSettle();

      expect(find.text('Page 2: Artists Content'), findsOneWidget);

      // Swipe right to return to Albums
      await tester.drag(find.text('Page 2: Artists Content'), const Offset(500.0, 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Page 1: Albums Content'), findsOneWidget);
    });
  });
}
