/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:blackhole/CustomWidgets/bouncy_playlist_header_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildHeaderTestApp({
  required double width,
  required double textScale,
  required String title,
  required String subtitle,
  required String secondarySubtitle,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: BouncyPlaylistHeaderScrollView(
          scrollController: ScrollController(),
          title: title,
          subtitle: subtitle,
          secondarySubtitle: secondarySubtitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
          onPlayTap: () {},
          onShuffleTap: () {},
          sliverList: SliverList(
            delegate: SliverChildListDelegate(
              List.generate(
                10,
                (index) => ListTile(
                  title: Text('Song #$index'),
                  subtitle: Text('Artist #$index'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('BouncyPlaylistHeaderScrollView Overflow Regression Tests', () {
    const screenWidths = [320.0, 360.0, 393.0, 411.0, 480.0];
    const textScales = [1.0, 1.25, 1.5];
    const longTitle =
        'Very Very Long Playlist Title That Could Cause Text Overflows Across Multiple Screen Sizes and Orientations In Production';
    const longSubtitle =
        'Extremely long description and subtitle with detailed genre tags, creator names, and song count metadata';
    const longSecondarySubtitle =
        'Secondary metadata subtitle line with extra duration, year, and studio information';

    for (final width in screenWidths) {
      for (final textScale in textScales) {
        testWidgets(
            'Renders cleanly without RenderFlex overflow at ${width.toInt()}dp width (scale: ${textScale}x)',
            (WidgetTester tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            buildHeaderTestApp(
              width: width,
              textScale: textScale,
              title: longTitle,
              subtitle: longSubtitle,
              secondarySubtitle: longSecondarySubtitle,
            ),
          );

          // Let widget layout and animations settle
          await tester.pumpAndSettle();

          // Verify widget rendered
          expect(find.byType(BouncyPlaylistHeaderScrollView), findsOneWidget);

          // Verify no Flutter exceptions / overflows occurred
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
