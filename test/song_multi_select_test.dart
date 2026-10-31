/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:blackhole/Screens/Library/downloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', '')],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<Map<String, dynamic>> testSongs = [
    {
      'id': '101',
      'title': 'Test Song Alpha',
      'artist': 'Artist A',
      'album': 'Album A',
      'path': '/storage/emulated/0/Music/alpha.mp3',
      'image': '',
    },
    {
      'id': '102',
      'title': 'Test Song Beta',
      'artist': 'Artist B',
      'album': 'Album B',
      'path': '/storage/emulated/0/Music/beta.mp3',
      'image': '',
    },
    {
      'id': '103',
      'title': 'Test Song Gamma',
      'artist': 'Artist C',
      'album': 'Album C',
      'path': '/storage/emulated/0/Music/gamma.mp3',
      'image': '',
    },
  ];

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('multi_select_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('downloads');
  });

  tearDown(() async {
    for (final box in ['settings', 'downloads']) {
      if (Hive.isBoxOpen(box)) {
        await Hive.box(box).close();
      }
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Song Multi-Select Widget Tests', () {
    testWidgets('Normal mode shows song list without checkboxes and with popup menu', (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildTestApp(
          DownSongsTab(
            songs: List.from(testSongs),
            onDelete: (item) async {},
            scrollController: scrollController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 3 songs rendered
      expect(find.text('Test Song Alpha'), findsOneWidget);
      expect(find.text('Test Song Beta'), findsOneWidget);
      expect(find.text('Test Song Gamma'), findsOneWidget);

      // In normal mode, no checkboxes exist
      expect(find.byType(Checkbox), findsNothing);

      // More vert popup button exists
      expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(3));
    });

    testWidgets('Long press enters selection mode, displays toolbar and checkbox', (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildTestApp(
          DownSongsTab(
            songs: List.from(testSongs),
            onDelete: (item) async {},
            scrollController: scrollController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press on the first song
      await tester.longPress(find.text('Test Song Alpha'));
      await tester.pumpAndSettle();

      // Selection toolbar should now be visible
      expect(find.text('1 Selected'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);

      // Checkbox is displayed
      expect(find.byType(Checkbox), findsAtLeastNWidgets(1));

      // Tapping second song in selection mode selects it
      await tester.tap(find.text('Test Song Beta'));
      await tester.pumpAndSettle();
      expect(find.text('2 Selected'), findsOneWidget);

      // Tapping Select All selects all 3 songs
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('3 Selected'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tapping Clear deselects all and exits selection mode
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('1 Selected'), findsNothing);
      expect(find.text('3 Selected'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('Single song popup menu contains Select and Delete options', (WidgetTester tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        _buildTestApp(
          DownSongsTab(
            songs: List.from(testSongs),
            onDelete: (item) async {},
            scrollController: scrollController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 3-dots on first song
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      // Verify menu options
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Add to Playlist'), findsOneWidget);

      // Tap Select in popup menu
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Should enter selection mode
      expect(find.text('1 Selected'), findsOneWidget);
      expect(find.byType(Checkbox), findsAtLeastNWidgets(1));
    });
  });
}

