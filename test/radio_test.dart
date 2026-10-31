/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';
import 'dart:io';

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/Helpers/radio_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class FakeSaavnAPI extends SaavnAPI {
  final Future<String?> Function(
    List<String> names,
    String? language,
    String stationType,
  )? onCreateRadio;

  final Future<List> Function(
    String stationId,
    int count,
    int next,
  )? onGetRadioSongs;

  FakeSaavnAPI({
    this.onCreateRadio,
    this.onGetRadioSongs,
  });

  @override
  Future<String?> createRadio({
    required List<String> names,
    String? language,
    String stationType = 'featured',
  }) async {
    if (onCreateRadio != null) {
      return onCreateRadio!(names, language, stationType);
    }
    return 'station_123';
  }

  @override
  Future<List> getRadioSongs({
    required String stationId,
    int count = 20,
    int next = 1,
  }) async {
    if (onGetRadioSongs != null) {
      return onGetRadioSongs!(stationId, count, next);
    }
    return [
      {'id': 'song_1', 'title': 'Test Song 1'},
      {'id': 'song_2', 'title': 'Test Song 2'},
    ];
  }
}

Widget buildTestApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      '/player': (ctx) => const Scaffold(body: Center(child: Text('Player Screen'))),
    },
    home: home,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_radio_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    RadioConnectionHandler.resetForTesting();
  });

  group('RadioConnectionHandler Tests', () {
    testWidgets(
        'Successful connection: displays connecting message, triggers playback and auto-dismisses indicator',
        (WidgetTester tester) async {
      bool playbackStarted = false;
      bool navigatedToPlayer = false;
      List? playedSongs;

      final fakeApi = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'valid_station_id';
        },
        onGetRadioSongs: (stationId, count, next) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return [
            {'id': 'song_100', 'title': 'Station Song'}
          ];
        },
      );

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    RadioConnectionHandler.connectAndPlay(
                      context: context,
                      stationName: 'Mirchi Top 20',
                      stationType: 'featured',
                      api: fakeApi,
                      onPlaybackStarted: (songs) {
                        playbackStarted = true;
                        playedSongs = songs;
                      },
                      onNavigateToPlayer: () {
                        navigatedToPlayer = true;
                      },
                    );
                  },
                  child: const Text('Start Radio'),
                );
              },
            ),
          ),
        ),
      );

      // Initially no SnackBar
      expect(find.byType(SnackBar), findsNothing);

      // Tap to connect
      await tester.tap(find.text('Start Radio'));
      await tester.pump(); // Render SnackBar

      // Connecting indicator is shown without an 'OK' button action
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('OK'), findsNothing);

      // Settle async API calls
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      // Playback started with received songs
      expect(playbackStarted, isTrue);
      expect(playedSongs, isNotNull);
      expect(playedSongs!.first['id'], equals('song_100'));
      expect(navigatedToPlayer, isTrue);

      // SnackBar has auto-dismissed after success!
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'Failed station creation: dismisses connecting indicator and shows error SnackBar',
        (WidgetTester tester) async {
      final fakeApi = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async {
          return null; // Station creation returns null
        },
      );

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    RadioConnectionHandler.connectAndPlay(
                      context: context,
                      stationName: 'Invalid Station',
                      stationType: 'featured',
                      api: fakeApi,
                    );
                  },
                  child: const Text('Start Radio'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Radio'));
      await tester.pump(); // Show connecting SnackBar
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pumpAndSettle(); // Resolve failure

      // Error SnackBar is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Failed to connect to Radio'), findsOneWidget);
    });

    testWidgets(
        'Empty songs list: dismisses connecting indicator and shows error SnackBar',
        (WidgetTester tester) async {
      final fakeApi = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async => 'empty_station',
        onGetRadioSongs: (stationId, count, next) async => [], // Empty songs
      );

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    RadioConnectionHandler.connectAndPlay(
                      context: context,
                      stationName: 'Empty Station',
                      stationType: 'featured',
                      api: fakeApi,
                    );
                  },
                  child: const Text('Start Radio'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Radio'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Failed to connect to Radio'), findsOneWidget);
    });

    testWidgets(
        'Station change in flight: newer station request supersedes older request',
        (WidgetTester tester) async {
      final completer1 = Completer<List>();
      final completer2 = Completer<List>();
      final List<String> playbackCalls = [];

      final fakeApi1 = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async => 'station_1',
        onGetRadioSongs: (stationId, count, next) => completer1.future,
      );

      final fakeApi2 = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async => 'station_2',
        onGetRadioSongs: (stationId, count, next) => completer2.future,
      );

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        RadioConnectionHandler.connectAndPlay(
                          context: context,
                          stationName: 'Station 1',
                          stationType: 'featured',
                          api: fakeApi1,
                          onPlaybackStarted: (songs) => playbackCalls.add('Station 1'),
                        );
                      },
                      child: const Text('Station 1'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        RadioConnectionHandler.connectAndPlay(
                          context: context,
                          stationName: 'Station 2',
                          stationType: 'featured',
                          api: fakeApi2,
                          onPlaybackStarted: (songs) => playbackCalls.add('Station 2'),
                        );
                      },
                      child: const Text('Station 2'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Start station 1
      await tester.tap(find.text('Station 1'));
      await tester.pump();
      expect(RadioConnectionHandler.activeRequestId, equals(1));

      // Quickly switch to station 2 while station 1 is in-flight
      await tester.tap(find.text('Station 2'));
      await tester.pump();
      expect(RadioConnectionHandler.activeRequestId, equals(2));

      // Station 1 completes now
      completer1.complete([{'id': 's1', 'title': 'Old Station Song'}]);
      await tester.pump();

      // Station 1 must NOT start playback because it was superseded
      expect(playbackCalls, isEmpty);

      // Station 2 completes
      completer2.complete([{'id': 's2', 'title': 'New Station Song'}]);
      await tester.pumpAndSettle();

      // Only Station 2 started playback
      expect(playbackCalls, equals(['Station 2']));
      // SnackBar dismissed
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
        'Exception / network error: dismisses connecting indicator and shows error message',
        (WidgetTester tester) async {
      final fakeApi = FakeSaavnAPI(
        onCreateRadio: (names, language, stationType) async {
          throw Exception('Network unreachable');
        },
      );

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    RadioConnectionHandler.connectAndPlay(
                      context: context,
                      stationName: 'Error Station',
                      stationType: 'featured',
                      api: fakeApi,
                    );
                  },
                  child: const Text('Start Radio'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Radio'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Failed to connect to Radio'), findsOneWidget);
    });
  });
}
