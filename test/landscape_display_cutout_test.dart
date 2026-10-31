/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:blackhole/Helpers/config.dart';
import 'package:blackhole/Screens/Login/auth.dart';
import 'package:blackhole/Screens/Login/pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

Widget buildTestScreen({
  required Widget child,
  required Size size,
  required EdgeInsets padding,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: padding,
        viewPadding: padding,
      ),
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('blackhole_cutout_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
    if (!GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.registerSingleton<MyTheme>(MyTheme());
    }
  });

  tearDownAll(() async {
    await settingsBox.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Batch 3 Post-Test Fix - Display Cutout Layout Invariants', () {
    testWidgets(
        'AuthScreen portrait orientation layout renders cleanly without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 851));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestScreen(
          child: AuthScreen(),
          size: const Size(393, 851),
          padding: const EdgeInsets.only(top: 40.0, bottom: 24.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Enter Your Name'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      final Finder columnFinder = find.byType(Column).first;
      final RenderBox columnBox = tester.renderObject(columnFinder);
      final Offset columnOffset = columnBox.localToGlobal(Offset.zero);

      // In portrait, content column must be at or below top notch safe area (40.0)
      expect(columnOffset.dy, greaterThanOrEqualTo(40.0));
      expect(columnOffset.dx, equals(0.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AuthScreen landscape (notch on left) protects content from cutout clipping',
        (WidgetTester tester) async {
      const double notchWidth = 48.0;
      await tester.binding.setSurfaceSize(const Size(851, 393));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestScreen(
          child: AuthScreen(),
          size: const Size(851, 393),
          padding: const EdgeInsets.only(left: notchWidth, bottom: 20.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Enter Your Name'), findsOneWidget);

      // Background Stack must span edge-to-edge from 0.0 under the notch
      final Finder stackFinder = find.byType(Stack).first;
      final RenderBox stackBox = tester.renderObject(stackFinder);
      final Offset stackOffset = stackBox.localToGlobal(Offset.zero);
      expect(stackOffset.dx, equals(0.0));
      expect(stackBox.size.width, equals(851.0));

      // Interactive content Column is wrapped in SafeArea so its left boundary is at or past notchWidth
      final Finder columnFinder = find
          .descendant(
            of: find.byType(SafeArea),
            matching: find.byType(Column),
          )
          .first;
      final RenderBox columnBox = tester.renderObject(columnFinder);
      final Offset columnOffset = columnBox.localToGlobal(Offset.zero);

      expect(columnOffset.dx, greaterThanOrEqualTo(notchWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AuthScreen reverse landscape (notch on right) protects actions from cutout clipping',
        (WidgetTester tester) async {
      const double notchWidth = 48.0;
      const double screenWidth = 851.0;
      await tester.binding.setSurfaceSize(const Size(screenWidth, 393));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestScreen(
          child: AuthScreen(),
          size: const Size(screenWidth, 393),
          padding: const EdgeInsets.only(right: notchWidth, bottom: 20.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Skip button on the far right must stay within (screenWidth - notchWidth)
      final Finder skipFinder = find.text('Skip');
      final RenderBox skipBox = tester.renderObject(skipFinder);
      final Offset skipOffset = skipBox.localToGlobal(Offset.zero);
      final double skipRightEdge = skipOffset.dx + skipBox.size.width;

      expect(skipRightEdge, lessThanOrEqualTo(screenWidth - notchWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PrefScreen landscape mode layout renders cleanly without overflow',
        (WidgetTester tester) async {
      const double notchWidth = 48.0;
      await tester.binding.setSurfaceSize(const Size(851, 393));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestScreen(
          child: const PrefScreen(),
          size: const Size(851, 393),
          padding: const EdgeInsets.only(left: notchWidth, bottom: 20.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PrefScreen), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Stack must be full-screen edge-to-edge
      final Finder stackFinder = find.byType(Stack).first;
      final RenderBox stackBox = tester.renderObject(stackFinder);
      expect(stackBox.localToGlobal(Offset.zero).dx, equals(0.0));
      expect(stackBox.size.width, equals(851.0));

      // Content Column must respect left safe inset
      final Finder columnFinder = find
          .descendant(
            of: find.byType(SafeArea),
            matching: find.byType(Column),
          )
          .first;
      final RenderBox columnBox = tester.renderObject(columnFinder);
      expect(
        columnBox.localToGlobal(Offset.zero).dx,
        greaterThanOrEqualTo(notchWidth),
      );
      expect(tester.takeException(), isNull);
    });

    test(
        'Android styles.xml declares windowLayoutInDisplayCutoutMode shortEdges',
        () {
      final File lightStyles =
          File(r'android\app\src\main\res\values\styles.xml');
      final File darkStyles =
          File(r'android\app\src\main\res\values-night\styles.xml');

      expect(lightStyles.existsSync(), isTrue);
      expect(darkStyles.existsSync(), isTrue);

      final String lightXml = lightStyles.readAsStringSync();
      final String darkXml = darkStyles.readAsStringSync();

      expect(
        lightXml.contains(
          '<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>',
        ),
        isTrue,
      );
      expect(
        darkXml.contains(
          '<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>',
        ),
        isTrue,
      );
    });
  });
}
