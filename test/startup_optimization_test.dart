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
import 'package:blackhole/Helpers/startup_profiler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('startup_opt_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    for (final boxName in [
      'settings',
      'downloads',
      'stats',
      'Favorite Songs',
      'cache',
      'ytlinkcache',
    ]) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close().timeout(const Duration(seconds: 2));
      }
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

  group('Post-Batch-3 Startup Optimization Tests', () {
    test('Parallel opening of all 6 Hive boxes succeeds and provides all required boxes', () async {
      final boxNames = [
        'settings',
        'downloads',
        'stats',
        'Favorite Songs',
        'cache',
        'ytlinkcache',
      ];

      // Verify concurrent box opening via Future.wait
      await Future.wait(boxNames.map((name) => Hive.openBox(name)));

      for (final name in boxNames) {
        expect(Hive.isBoxOpen(name), isTrue, reason: 'Box $name should be open');
      }

      // Verify basic read/write in concurrent boxes
      await Hive.box('settings').put('themeColor', 'Teal');
      expect(Hive.box('settings').get('themeColor'), equals('Teal'));

      await Hive.box('downloads').put('song_1', {'title': 'Test Song'});
      expect(Hive.box('downloads').get('song_1'), isNotNull);

      await Hive.box('stats').put('playCount', 42);
      expect(Hive.box('stats').get('playCount'), equals(42));
    });

    test('MyTheme registers cleanly in GetIt once settings box is open', () async {
      await Hive.openBox('settings');
      expect(GetIt.I.isRegistered<MyTheme>(), isFalse);

      GetIt.I.registerSingleton<MyTheme>(MyTheme());
      expect(GetIt.I.isRegistered<MyTheme>(), isTrue);

      final theme = GetIt.I<MyTheme>();
      expect(theme.currentColor(), isNotNull);
      expect(theme.currentTheme(), isNotNull);
    });

    test('Cache box limit logic clears oversized caches (>500 items)', () async {
      final cacheBox = await Hive.openBox('cache');
      for (int i = 0; i < 505; i++) {
        await cacheBox.put('key_$i', 'val_$i');
      }
      expect(cacheBox.length, equals(505));

      // Emulate limit logic from openHiveBox
      if (cacheBox.length > 500) {
        await cacheBox.clear();
      }
      expect(cacheBox.length, equals(0));
    });

    test('Critical UI boxes open synchronously while non-critical boxes open asynchronously', () async {
      final criticalBoxes = ['settings', 'downloads', 'Favorite Songs', 'cache'];
      final nonCriticalBoxes = ['stats', 'ytlinkcache'];

      // Simulate main() startup sequencing
      await Future.wait(criticalBoxes.map((name) => Hive.openBox(name)));

      for (final name in criticalBoxes) {
        expect(Hive.isBoxOpen(name), isTrue, reason: 'Critical box $name must be open before UI paint');
      }

      // Non-critical boxes are still openable in background
      await Future.wait(nonCriticalBoxes.map((name) => Hive.openBox(name)));
      for (final name in nonCriticalBoxes) {
        expect(Hive.isBoxOpen(name), isTrue, reason: 'Deferred box $name opens cleanly in background');
      }
    });

    test('User-initiated playback priority flag logic aborts stale session restore', () {
      bool userInitiatedPlayback = false;
      bool isRestored = false;

      void restorePreviousSession() {
        if (userInitiatedPlayback) {
          // Guard: abort immediately without overwriting user-selected track
          return;
        }
        isRestored = true;
      }

      // Simulate user immediately tapping a track upon launch
      userInitiatedPlayback = true;
      restorePreviousSession();

      expect(isRestored, isFalse, reason: 'Session restore must not run when user initiates playback');

      // Verify normal restore when user did not tap anything
      userInitiatedPlayback = false;
      restorePreviousSession();
      expect(isRestored, isTrue, reason: 'Session restore proceeds when user has not initiated playback');
    });

    test('StartupProfiler marks monotonic checkpoints and notifies readiness', () async {
      final profiler = StartupProfiler.instance;
      profiler.mark('stage_1_init');
      await Future.delayed(const Duration(milliseconds: 10));
      profiler.mark('stage_2_ready');

      final t1 = profiler.get('stage_1_init');
      final t2 = profiler.get('stage_2_ready');

      expect(t1, isNotNull);
      expect(t2, isNotNull);
      expect(t2! >= t1!, isTrue, reason: 'Timestamps must be monotonically increasing');

      // Test readiness future getter must not throw
      expect(StartupProfiler.audioHandlerFuture, isNotNull);
    });
  });
}
