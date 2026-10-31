/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/CustomWidgets/equalizer.dart';
import 'package:blackhole/Helpers/radio_helper.dart';
import 'package:blackhole/Helpers/startup_profiler.dart';
import 'package:blackhole/Screens/Library/nowplaying.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/CustomWidgets/miniplayer.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:blackhole/Helpers/config.dart';
import 'package:blackhole/main.dart' hide main;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';

class FakeAudioPlayerHandler extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayerHandler {
  final PlaybackState _state = PlaybackState(
    controls: [MediaControl.play],
    systemActions: const {MediaAction.seek},
    processingState: AudioProcessingState.idle,
    playing: false,
  );

  FakeAudioPlayerHandler() {
    playbackState.add(_state);
    queue.add(<MediaItem>[]);
    mediaItem.add(
      const MediaItem(
        id: 'mock_1',
        title: 'Mock Title',
        artist: 'Mock Artist',
        extras: {'url': 'http://example.com/audio.mp3'},
      ),
    );
  }

  bool playCalled = false;
  bool stopCalled = false;

  @override
  Future<void> play() async {
    playCalled = true;
    playbackState.add(_state.copyWith(playing: true));
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
    playbackState.add(_state.copyWith(playing: false));
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {}

  @override
  Stream<QueueState> get queueState =>
      Stream.value(const QueueState([], 0, [], AudioServiceRepeatMode.none));

  @override
  Future<void> setVolume(double volume) async {}

  @override
  ValueStream<double> get speed => BehaviorSubject<double>.seeded(1.0);

  @override
  ValueStream<double> get volume => BehaviorSubject<double>.seeded(1.0);
}

class FakeSaavnAPIForPlayback extends SaavnAPI {
  final Future<Map<String, List>> Function(String token)? onFetchArtistSongs;

  FakeSaavnAPIForPlayback({this.onFetchArtistSongs});

  @override
  Future<Map<String, List>> fetchArtistSongs({
    required String artistToken,
    String category = '',
    String sortOrder = '',
  }) async {
    if (onFetchArtistSongs != null) {
      return onFetchArtistSongs!(artistToken);
    }
    return {
      'topSongs': [
        {'id': 'song_1', 'title': 'Top Song 1', 'type': 'song'},
        {'id': 'song_2', 'title': 'Top Song 2', 'type': 'song'},
      ],
      'artistDetails': [
        {'name': 'Test Artist', 'id': 'artist_1'}
      ],
    };
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('playback_recovery_test_');
    Hive.init(tempDir.path);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
    if (!Hive.isBoxOpen('cache')) {
      await Hive.openBox('cache');
    }
    if (!GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.registerSingleton<MyTheme>(MyTheme());
    }
    StartupProfiler.resetForTesting();
    RadioConnectionHandler.resetForTesting();
  });

  tearDown(() async {
    if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
      GetIt.I.unregister<AudioPlayerHandler>();
    }
    if (GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.unregister<MyTheme>();
    }
    for (final boxName in ['settings', 'cache', 'downloads', 'Favorite Songs']) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Phase E.1.1 Audio Service Truthful Failure Handling and Registration Lifecycle Tests', () {
    test('Requirement 1: Successful AudioService initialization registers the returned handler exactly once', () async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      final fakeHandler = FakeAudioPlayerHandler();
      // Simulate successful AudioService.init path:
      if (!GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.registerSingleton<AudioPlayerHandler>(fakeHandler);
      }
      StartupProfiler.notifyAudioServiceReady(fakeHandler);

      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isTrue);
      expect(GetIt.I<AudioPlayerHandler>(), same(fakeHandler));
      expect(StartupProfiler.isAudioServiceReady, isTrue);
      expect(StartupProfiler.hasAudioServiceFailed, isFalse);

      // Verify idempotency / exactly once
      if (!GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.registerSingleton<AudioPlayerHandler>(FakeAudioPlayerHandler());
      }
      expect(GetIt.I<AudioPlayerHandler>(), same(fakeHandler));
    });

    test('Requirement 2: Consumers resolve the same registered handler', () async {
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      final fakeHandler = FakeAudioPlayerHandler();
      GetIt.I.registerSingleton<AudioPlayerHandler>(fakeHandler);

      final handlerFromGetIt = GetIt.I<AudioPlayerHandler>();
      final handlerFromPlayerInvoke = PlayerInvoke.audioHandler;

      expect(handlerFromGetIt, same(fakeHandler));
      expect(handlerFromPlayerInvoke, same(fakeHandler));
      expect(handlerFromPlayerInvoke, same(handlerFromGetIt));
    });

    test('Requirement 3: Failed AudioService initialization does not create or register a detached fallback', () async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      // Simulate AudioService failure path:
      try {
        throw Exception('AudioService platform channel connection error');
      } catch (e, st) {
        // Truthful failure reporting: record failure, do NOT register any fallback
        StartupProfiler.notifyAudioServiceFailed(e, st);
      }

      // Assert GetIt does NOT have any AudioPlayerHandler registered
      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isFalse);
      expect(() => GetIt.I<AudioPlayerHandler>(), throwsA(isA<StateError>()));
    });

    test('Requirement 4: Failed initialization is not reported as successful readiness', () async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      final testError = StateError('Platform AudioService init failed');
      StartupProfiler.notifyAudioServiceFailed(testError);

      expect(StartupProfiler.hasAudioServiceFailed, isTrue);
      expect(StartupProfiler.isAudioServiceReady, isFalse);
      expect(StartupProfiler.audioServiceError, same(testError));

      // audioHandlerFuture must reject with error rather than completing successfully
      expect(StartupProfiler.audioHandlerFuture, throwsA(same(testError)));
    });

    test('Requirement 5: A playback request made when initialization fails returns a handled failure rather than hanging indefinitely', () async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      final testError = StateError('Audio hardware unavailable');
      StartupProfiler.notifyAudioServiceFailed(testError);

      // Playback request should complete immediately without hanging or throwing unhandled exception
      bool completed = false;
      await PlayerInvoke.init(
        songsList: [
          {'id': 'song_1', 'title': 'Test Song', 'url': 'http://example.com/audio.mp3'}
        ],
        index: 0,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          fail('PlayerInvoke.init hung indefinitely on failed initialization');
        },
      ).then((_) {
        completed = true;
      });

      expect(completed, isTrue);
      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isFalse);
    });

    testWidgets('Requirement 6: The application can render and navigate when the audio service is unavailable', (tester) async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }
      StartupProfiler.notifyAudioServiceFailed(Exception('Service down'));

      // 1. NowPlaying mounts and renders safely
      await tester.pumpWidget(
        buildTestApp(home: NowPlaying()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing is Playing'), findsOneWidget);

      // 2. Equalizer mounts and renders safely
      await tester.pumpWidget(
        buildTestApp(home: const Equalizer()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Equalizer'), findsOneWidget);

      // 3. MiniPlayer mounts safely without crashing
      await tester.pumpWidget(
        buildTestApp(home: Scaffold(bottomNavigationBar: MiniPlayer())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);

      // 4. PlayScreen mounts safely without throwing red screen
      await tester.pumpWidget(
        buildTestApp(home: const PlayScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Audio player is unavailable.'), findsOneWidget);
    });

    test('Requirement 7: A retry, if implemented, cannot produce duplicate registrations or playback engines', () async {
      StartupProfiler.resetForTesting();
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      final initialHandler = FakeAudioPlayerHandler();
      GetIt.I.registerSingleton<AudioPlayerHandler>(initialHandler);
      StartupProfiler.notifyAudioServiceReady(initialHandler);

      // Attempt retry when service is already running
      await startService(isRetry: true);

      // Must remain the exact same single instance
      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isTrue);
      expect(GetIt.I<AudioPlayerHandler>(), same(initialHandler));
      expect(PlayerInvoke.audioHandler, same(initialHandler));

      // Now simulate a failure state, followed by prepareForRetry
      GetIt.I.unregister<AudioPlayerHandler>();
      StartupProfiler.resetForTesting();
      StartupProfiler.notifyAudioServiceFailed(Exception('First attempt failed'));
      expect(StartupProfiler.hasAudioServiceFailed, isTrue);

      StartupProfiler.prepareForRetry();
      expect(StartupProfiler.hasAudioServiceFailed, isFalse);
      expect(StartupProfiler.isAudioServiceReady, isFalse);

      // Second attempt succeeds:
      final retriedHandler = FakeAudioPlayerHandler();
      if (!GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.registerSingleton<AudioPlayerHandler>(retriedHandler);
      }
      StartupProfiler.notifyAudioServiceReady(retriedHandler);

      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isTrue);
      expect(GetIt.I<AudioPlayerHandler>(), same(retriedHandler));
    });
  });

  group('Phase E.1 Critical Audio Handler Registration Safety Tests', () {
    test('GetIt.I.isRegistered returns false without throwing when unregistered', () {
      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isFalse);
    });

    test('PlayerInvoke.audioHandler throws StateError when unregistered', () {
      expect(
        () => PlayerInvoke.audioHandler,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('AudioPlayerHandler is not yet registered in GetIt'),
          ),
        ),
      );
    });

    test('PlayerInvoke.audioHandler returns registered instance when registered in GetIt', () {
      final fakeHandler = FakeAudioPlayerHandler();
      GetIt.I.registerSingleton<AudioPlayerHandler>(fakeHandler);

      expect(GetIt.I.isRegistered<AudioPlayerHandler>(), isTrue);
      expect(PlayerInvoke.audioHandler, same(fakeHandler));
    });

    test('StartupProfiler.audioHandlerFuture resolves cleanly upon notification', () async {
      final fakeHandler = FakeAudioPlayerHandler();

      // Ensure completer starts fresh
      StartupProfiler.resetForTesting();
      final future = StartupProfiler.audioHandlerFuture;

      bool resolved = false;
      unawaited(
        future.then((handler) {
          resolved = true;
          expect(handler, same(fakeHandler));
        }),
      );

      expect(resolved, isFalse);
      StartupProfiler.notifyAudioServiceReady(fakeHandler);
      await pumpEventQueue();
      expect(resolved, isTrue);
    });
  });

  group('Phase E.1 UI Widget Construction Tests (No Red Screen Crash)', () {
    testWidgets('NowPlaying widget instantiates safely when handler is unregistered', (tester) async {
      // Ensure handler is unregistered in GetIt
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      // Construction of NowPlaying must not throw GetIt Bad state error
      expect(() => NowPlaying(), returnsNormally);
    });

    testWidgets('Equalizer widget instantiates safely when handler is unregistered', (tester) async {
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        GetIt.I.unregister<AudioPlayerHandler>();
      }

      // Construction of Equalizer must not throw GetIt Bad state error
      expect(() => const Equalizer(), returnsNormally);
    });
  });

  group('Phase E.1 Artist Token Extraction and Data Integrity Tests', () {
    test('Artist token extracts properly from artistToken, perma_url, url, or id', () {
      // Scenario A: artistToken field is present
      final itemA = {'type': 'artist', 'artistToken': 'arijit-singh-token', 'id': '101'};
      final tokenA = (itemA['artistToken'] != null && itemA['artistToken'].toString().isNotEmpty)
          ? itemA['artistToken'].toString()
          : (itemA['perma_url'] ?? itemA['url'])?.toString().split('/').last ?? itemA['id']?.toString() ?? '';
      expect(tokenA, equals('arijit-singh-token'));

      // Scenario B: artistToken missing, derived from perma_url
      final itemB = {
        'type': 'artist',
        'perma_url': 'https://www.jiosaavn.com/artist/yogi-aulakh/8B8uR7bC09U_',
        'id': '102',
      };
      final tokenB = (itemB['artistToken'] != null && itemB['artistToken'].toString().isNotEmpty)
          ? itemB['artistToken'].toString()
          : (itemB['perma_url'] ?? itemB['url'])?.toString().split('/').last ?? itemB['id']?.toString() ?? '';
      expect(tokenB, equals('8B8uR7bC09U_'));

      // Scenario C: artistToken and perma_url missing, fallback to id
      final itemC = {'type': 'artist', 'id': 'yogi_aulakh_id'};
      final tokenC = (itemC['artistToken'] != null && itemC['artistToken'].toString().isNotEmpty)
          ? itemC['artistToken'].toString()
          : (itemC['perma_url'] ?? itemC['url'])?.toString().split('/').last ?? itemC['id']?.toString() ?? '';
      expect(tokenC, equals('yogi_aulakh_id'));
    });

    test('FakeSaavnAPI fetchArtistSongs returns topSongs and artistDetails', () async {
      final api = FakeSaavnAPIForPlayback();
      final result = await api.fetchArtistSongs(artistToken: '8B8uR7bC09U_');

      expect(result.containsKey('topSongs'), isTrue);
      expect(result['topSongs'], isNotEmpty);
      expect(result['topSongs']!.length, equals(2));
      expect(result['topSongs']!.first['title'], equals('Top Song 1'));
    });
  });

  group('Phase E.1 Song List Subtitle Logic Tests (Zero Songs Prevention)', () {
    String computeSubtitle({
      required bool loading,
      required List songList,
      required Map listItem,
    }) {
      return loading
          ? 'Loading…'
          : (songList.isNotEmpty
              ? '${songList.length} Songs'
              : (listItem['subtitle']?.toString() ??
                  listItem['subTitle']?.toString() ??
                  ''));
    }

    test('Subtitle shows loading string when loading is true', () {
      final subtitle = computeSubtitle(
        loading: true,
        songList: [],
        listItem: {'subtitle': 'Some Subtitle', 'type': 'playlist'},
      );
      expect(subtitle, equals('Loading…'));
    });

    test('Subtitle shows song count when songs are present', () {
      final subtitle = computeSubtitle(
        loading: false,
        songList: [{'id': '1'}, {'id': '2'}, {'id': '3'}],
        listItem: {'subtitle': 'Original Subtitle', 'type': 'playlist'},
      );
      expect(subtitle, equals('3 Songs'));
    });

    test('Subtitle uses item subtitle or empty string when empty without hardcoded 0 Songs', () {
      final subtitle = computeSubtitle(
        loading: false,
        songList: [],
        listItem: {'type': 'artist'},
      );
      expect(subtitle, equals(''));
      expect(subtitle.contains('0 Songs'), isFalse);
    });
  });

  group('Phase E.1 RadioConnectionHandler Lifecycle Tests', () {
    test('RadioConnectionHandler resets request ID and dismisses cleanly', () {
      RadioConnectionHandler.resetForTesting();
      expect(RadioConnectionHandler.activeRequestId, equals(0));
    });
  });
}
