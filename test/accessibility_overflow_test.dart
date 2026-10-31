import 'package:blackhole/CustomWidgets/animated_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Accessibility XL Text Layout & Overflow Regression Tests', () {
    testWidgets(
        'Home greeting header renders without bottom overflow under 1.4x (XL) text scale',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      // Test using 1.4x text scaler corresponding to Android XL text accessibility setting
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxScrolled) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final greetingExpandedHeight = textScale > 1.0
                      ? 135.0 + (textScale - 1.0) * 55.0
                      : 135.0;
                  return [
                    SliverAppBar(
                      expandedHeight: greetingExpandedHeight,
                      toolbarHeight: 65,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: textScale > 1.15 ? 40 : 60),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15.0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Good Morning',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15.0,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Guest User Profile',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: const Center(child: Text('Content')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Good Morning'), findsOneWidget);
      expect(find.text('Guest User Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'YouTube Home long section heading wraps cleanly without right edge overflow under XL text scale',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      const longTitle =
          'Charts - Top Music Videos & Trending Hits - Global Weekly Billboard Exclusive';

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(10, 10, 10, 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        longTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        softWrap: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Now Playing title/subtitle with AnimatedText renders cleanly without bottom overflow under XL text scale',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      const double height = 240.0;
      const double width = 360.0;
      const longTitle = 'Casa Tupka Anthemo - Extended Club Mix Live';
      const longSubtitle = 'Artist Name Collaboration • Album Title Special Edition';

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final double titleBoxHeight = height * (textScale > 1.15 ? 0.28 : 0.25);

                  return SizedBox(
                    width: width,
                    height: height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          height: titleBoxHeight,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: textScale > 1.15 ? 2.0 : titleBoxHeight / 10,
                                  ),
                                  AnimatedText(
                                    text: longTitle,
                                    pauseAfterRound: const Duration(seconds: 3),
                                    style: TextStyle(
                                      fontSize: titleBoxHeight / 2.75,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: textScale > 1.15 ? 2.0 : titleBoxHeight / 40,
                                  ),
                                  AnimatedText(
                                    text: longSubtitle,
                                    pauseAfterRound: const Duration(seconds: 3),
                                    style: TextStyle(
                                      fontSize: titleBoxHeight / 6.75,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AnimatedText), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // Clean up Marquee postFrameCallback timers by advancing and unmounting widget tree
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
