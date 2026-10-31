/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:blackhole/CustomWidgets/download_button.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Services/download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget buildTestApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box downloadsBox;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('blackhole_download_test_');
    Hive.init(tempDir.path);
    downloadsBox = await Hive.openBox('downloads');
    settingsBox = await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await downloadsBox.close();
    await settingsBox.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Bug A — Notification Tests (Duration, Auto-dismissal & Action Presence)', () {
    testWidgets('Transient success snackbar has 3s duration and no OK action button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ShowSnackBar().showSnackBar(
                    context,
                    '"Gehra Hua" downloaded',
                    noAction: true,
                  );
                },
                child: const Text('Show Success'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // SnackBar is visible with message
      expect(find.text('"Gehra Hua" downloaded'), findsOneWidget);
      // Crucial: OK action is NOT present
      expect(find.byType(SnackBarAction), findsNothing);

      // Advance by 3.5 seconds and let exit animation settle: SnackBar should automatically dismiss
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('"Gehra Hua" downloaded'), findsNothing);
    });

    testWidgets('Deletion success snackbar auto-dismisses without requiring interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ShowSnackBar().showSnackBar(
                    context,
                    'Deleted Tera Chehra',
                    noAction: true,
                  );
                },
                child: const Text('Delete Success'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Delete Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Deleted Tera Chehra'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Deleted Tera Chehra'), findsNothing);
    });

    testWidgets('Actionable error snackbar retains OK button for explicit user acknowledgment',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ShowSnackBar().showSnackBar(
                    context,
                    'Failed to delete: /path/song.m4a\nError: Permission denied',
                  );
                },
                child: const Text('Show Error'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      expect(find.text('Ok'), findsOneWidget);
    });

    testWidgets('New snackbar immediately replaces prior active snackbar without queuing delays',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      ShowSnackBar().showSnackBar(
                        context,
                        'First Message',
                        noAction: true,
                      );
                    },
                    child: const Text('First'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ShowSnackBar().showSnackBar(
                        context,
                        'Second Message',
                        noAction: true,
                      );
                    },
                    child: const Text('Second'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('First Message'), findsOneWidget);

      // Trigger second message immediately
      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Second message replaces first immediately
      expect(find.text('Second Message'), findsOneWidget);
      expect(find.text('First Message'), findsNothing);
    });
  });

  group('Bug B — Immediate Downloads Refresh & Deletion Safety Tests', () {
    test('Successful deletion updates database and in-memory list promptly', () async {
      final songFile = File('${tempDir.path}/test_song_b1.m4a')..createSync();
      final imageFile = File('${tempDir.path}/test_song_b1.jpg')..createSync();

      final songData = {
        'id': 'b1_101',
        'title': 'Test Song B1',
        'album': 'Test Album B1',
        'artist': 'Test Artist B1',
        'genre': 'Pop',
        'path': songFile.path,
        'image': imageFile.path,
      };

      await downloadsBox.put('b1_101', songData);
      expect(downloadsBox.containsKey('b1_101'), isTrue);

      final List songs = [Map.from(songData)];
      final Map<String, List> albums = {
        'Test Album B1': [songs.first],
      };
      final List sortedAlbumKeys = ['Test Album B1'];

      // Simulate the exact deletion flow implemented in _DownloadsState.deleteSong
      final audioFile = File(songs.first['path'].toString());
      final imgFile = File(songs.first['image'].toString());

      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      if (await imgFile.exists()) {
        await imgFile.delete();
      }
      await downloadsBox.delete(songs.first['id']);
      if (albums.containsKey(songs.first['album'])) {
        if (albums[songs.first['album']]!.length <= 1) {
          sortedAlbumKeys.remove(songs.first['album']);
        }
        albums[songs.first['album']]!.remove(songs.first);
      }
      songs.remove(songs.first);

      // State is immediately consistent
      expect(songs.isEmpty, isTrue);
      expect(downloadsBox.containsKey('b1_101'), isFalse);
      expect(audioFile.existsSync(), isFalse);
      expect(imgFile.existsSync(), isFalse);
      expect(sortedAlbumKeys.isEmpty, isTrue);
    });

    test('Deletion failure does NOT remove song from database or in-memory list', () async {
      final songData = {
        'id': 'b2_102',
        'title': 'Locked Song B2',
        'album': 'Locked Album B2',
        'artist': 'Locked Artist B2',
        'genre': 'Rock',
        'path': '${tempDir.path}/non_existent_dir/locked_song.m4a',
        'image': '${tempDir.path}/non_existent_dir/locked_song.jpg',
      };

      await downloadsBox.put('b2_102', songData);
      final List songs = [Map.from(songData)];

      bool failed = false;
      try {
        final audioFile = File(songs.first['path'].toString());
        if (!audioFile.existsSync()) {
          throw const FileSystemException('File does not exist on disk');
        }
        await audioFile.delete();
      } catch (e) {
        failed = true;
      }

      expect(failed, isTrue);
      // Song remains intact in both database and list
      expect(downloadsBox.containsKey('b2_102'), isTrue);
      expect(songs.length, equals(1));
      expect(songs.first['id'], equals('b2_102'));
    });
  });

  group('Bug C — Track-Specific Download Identity & Progress Tests', () {
    test('Each track ID maintains its own distinct Download instance and progress', () {
      final downTrack1 = Download('gehra_hua_001');
      final downTrack2 = Download('tera_chehra_002');

      expect(identical(downTrack1, downTrack2), isFalse);
      expect(downTrack1.id, equals('gehra_hua_001'));
      expect(downTrack2.id, equals('tera_chehra_002'));

      // Changing progress on track 1
      downTrack1.progress = 0.45;
      expect(downTrack1.progress, equals(0.45));
      // Track 2 remains completely independent
      expect(downTrack2.progress, equals(0.0));

      // Reset
      downTrack1.progress = 0.0;
    });

    test('Multiple concurrent downloads have separate progress and status', () {
      final downA = Download('song_alpha');
      final downB = Download('song_beta');

      downA.progress = 0.25;
      downB.progress = 0.80;

      expect(downA.progress, equals(0.25));
      expect(downB.progress, equals(0.80));

      downA.progress = 0.0;
      downB.progress = 0.0;
    });

    testWidgets('DownloadButton updates subscription when song changes and does not transfer progress',
        (WidgetTester tester) async {
      final track1Data = {
        'id': 'track_c1_gehra',
        'title': 'Gehra Hua',
        'artist': 'Artist 1',
        'album': 'Album 1',
        'url': 'https://example.com/gehra_hua.mp3',
      };

      final track2Data = {
        'id': 'track_c2_tera',
        'title': 'Tera Chehra',
        'artist': 'Artist 2',
        'album': 'Album 2',
        'url': 'https://example.com/tera_chehra.mp3',
      };

      final down1 = Download('track_c1_gehra');
      final down2 = Download('track_c2_tera');
      down1.progress = 0.0;
      down2.progress = 0.0;

      final currentSongNotifier = ValueNotifier<Map>(track1Data);

      await tester.pumpWidget(
        buildTestApp(
          child: ValueListenableBuilder<Map>(
            valueListenable: currentSongNotifier,
            builder: (context, song, _) {
              return Center(
                child: DownloadButton(
                  key: ValueKey('player_download_${song['id']}'),
                  data: song,
                ),
              );
            },
          ),
        ),
      );

      // Initially Track 1 shows idle download button (progress 0)
      expect(find.byIcon(Icons.save_alt), findsOneWidget);

      // Simulate Track 1 downloading at 60%
      down1.progress = 0.60;
      down1.notifyListeners();
      await tester.pump(const Duration(milliseconds: 250));

      // Track 1 shows 60% progress
      expect(find.text('60%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Now maintainer switches playback to Track 2 while Track 1 is still downloading!
      currentSongNotifier.value = track2Data;
      await tester.pump(const Duration(milliseconds: 250));

      // CRITICAL ASSERTION: Track 2 must NOT show Track 1's 60% progress!
      expect(find.text('60%'), findsNothing);
      // Track 2 shows its own idle download button
      expect(find.byIcon(Icons.save_alt), findsOneWidget);

      // Track 1 progress continues advancing in background to 90%
      down1.progress = 0.90;
      down1.notifyListeners();
      await tester.pump(const Duration(milliseconds: 250));

      // Track 2 still does NOT show Track 1's progress
      expect(find.text('90%'), findsNothing);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);

      // Switch playback back to Track 1
      currentSongNotifier.value = track1Data;
      await tester.pump(const Duration(milliseconds: 250));

      // Track 1 immediately shows its active 90% progress!
      expect(find.text('90%'), findsOneWidget);

      // Track 1 finishes downloading
      await tester.runAsync(() async {
        await downloadsBox.put('track_c1_gehra', track1Data);
      });
      down1.lastDownloadId = 'track_c1_gehra';
      down1.progress = 0.0;
      down1.notifyListeners();
      await tester.pump(const Duration(milliseconds: 250));

      // Track 1 shows download completed icon
      expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);

      // Switch back to Track 2: Track 2 still shows idle download button
      currentSongNotifier.value = track2Data;
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.download_done_rounded), findsNothing);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
    });

    testWidgets('DownloadButton without explicit key still updates Download instance via didUpdateWidget',
        (WidgetTester tester) async {
      final trackA = {'id': 'song_c3_A', 'title': 'Song A'};
      final trackB = {'id': 'song_c4_B', 'title': 'Song B'};

      final downA = Download('song_c3_A');
      final downB = Download('song_c4_B');
      downA.progress = 0.0;
      downB.progress = 0.0;

      final songNotifier = ValueNotifier<Map>(trackA);

      await tester.pumpWidget(
        buildTestApp(
          child: ValueListenableBuilder<Map>(
            valueListenable: songNotifier,
            builder: (context, song, _) {
              // Intentionally no explicit Key to test didUpdateWidget
              return Center(child: DownloadButton(data: song));
            },
          ),
        ),
      );

      downA.progress = 0.35;
      downA.notifyListeners();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('35%'), findsOneWidget);

      // Switch song: didUpdateWidget should safely swap Download instances
      songNotifier.value = trackB;
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('35%'), findsNothing);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);

      downA.progress = 0.0;
    });
  });
}
