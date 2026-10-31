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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

Widget createTestWidget({
  required Widget child,
  double textScaleFactor = 1.0,
  bool boldText = false,
  Size physicalSize = const Size(360, 640),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: physicalSize,
      textScaler: TextScaler.linear(textScaleFactor),
      boldText: boldText,
    ),
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('onboarding_test_');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
    if (!GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.registerSingleton<MyTheme>(MyTheme());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').close();
    }
    if (GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.unregister<MyTheme>();
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Fix B: Onboarding Responsive Layout & Accessibility Tests', () {
    testWidgets('AuthScreen renders at default 1.0x scale on 360dp phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(child: AuthScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('AuthScreen renders under 1.4x (XL) scale with bold text on narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: AuthScreen(),
          textScaleFactor: 1.4,
          boldText: true,
          physicalSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('AuthScreen renders under 2.0x (max) scale with bold text on narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: AuthScreen(),
          textScaleFactor: 2.0,
          boldText: true,
          physicalSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AuthScreen renders on landscape and tablet constraints without overflow', (tester) async {
      // Landscape 800x480
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: AuthScreen(),
          physicalSize: const Size(800, 480),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tablet 800x1280
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpWidget(
        createTestWidget(
          child: AuthScreen(),
          physicalSize: const Size(800, 1280),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrefScreen renders at default 1.0x scale on 360dp phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(child: const PrefScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('PrefScreen renders under 1.4x scale with bold text on narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const PrefScreen(),
          textScaleFactor: 1.4,
          boldText: true,
          physicalSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('PrefScreen renders under 2.0x scale with bold text on narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const PrefScreen(),
          textScaleFactor: 2.0,
          boldText: true,
          physicalSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PrefScreen renders on landscape and tablet constraints without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: const PrefScreen(),
          physicalSize: const Size(800, 480),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tablet 800x1280
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpWidget(
        createTestWidget(
          child: const PrefScreen(),
          physicalSize: const Size(800, 1280),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

