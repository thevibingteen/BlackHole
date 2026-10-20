// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:blackhole/Helpers/update.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('update check tests', () {
    test('compareVersion should return true if update is available', () {
      // Arrange: Set up the necessary variables and inputs
      const String currentVersion = '1.1.2';
      const String latestVerion = '1.1.3';

      final result = compareVersion(latestVerion, currentVersion);

      expect(result, equals(true));
    });

    test('compareVersion should return false if update is not available', () {
      // Arrange: Set up the necessary variables and inputs
      const String currentVersion = '1.1.2';
      const String latestVerion = '1.1.2';

      final result = compareVersion(latestVerion, currentVersion);

      expect(result, equals(false));
    });
  });

  group('Top Charts Selector Widget Tests', () {
    testWidgets(
        'chart selector action is visible on Local tab and hidden on Global tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                actions: [
                  Builder(
                    builder: (BuildContext tabContext) {
                      final TabController? tabController =
                          DefaultTabController.maybeOf(tabContext);
                      if (tabController == null) {
                        return const SizedBox.shrink();
                      }
                      return AnimatedBuilder(
                        animation: tabController,
                        builder: (BuildContext ctx, Widget? child) {
                          if (tabController.index != 0) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.my_location_rounded),
                            tooltip: 'Select Chart',
                            onPressed: () {},
                          );
                        },
                      );
                    },
                  ),
                ],
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Local'),
                    Tab(text: 'Global'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  Center(child: Text('Local Content')),
                  Center(child: Text('Global Content')),
                ],
              ),
            ),
          ),
        ),
      );

      // Initially on Local tab (index 0)
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byTooltip('Select Chart'), findsOneWidget);

      // Switch to Global tab (index 1)
      await tester.tap(find.text('Global'));
      await tester.pumpAndSettle();

      // On Global tab: icon button must be hidden
      expect(find.byIcon(Icons.my_location_rounded), findsNothing);
      expect(find.byTooltip('Select Chart'), findsNothing);

      // Switch back to Local tab (index 0)
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      // On Local tab again: icon button must be visible
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byTooltip('Select Chart'), findsOneWidget);
    });
  });
}
