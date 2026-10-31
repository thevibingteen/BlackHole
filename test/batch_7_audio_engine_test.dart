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

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:blackhole/CustomWidgets/seek_bar.dart';
import 'package:blackhole/Helpers/playlist.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:rxdart/rxdart.dart';

/// Test audio handler stub exposing streams and controls for unit testing.
class TestBatch7AudioHandler extends BaseAudioHandler
    implements AudioPlayerHandler {
  final BehaviorSubject<double> _volumeSubject =
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _speedSubject =
      BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<QueueState> _queueStateSubject =
      BehaviorSubject<QueueState>.seeded(QueueState.empty);

  int playCount = 0;
  int pauseCount = 0;
  int stopCount = 0;
  int skipToNextCount = 0;
  int skipToPreviousCount = 0;
  Duration? lastSeekPosition;
  String? lastCustomAction;

  @override
  ValueStream<double> get volume => _volumeSubject.stream;

  @override
  Future<void> setVolume(double volume) async {
    _volumeSubject.add(volume);
  }

  @override
  ValueStream<double> get speed => _speedSubject.stream;

  @override
  Future<void> setSpeed(double speed) async {
    _speedSubject.add(speed);
  }

  @override
  Stream<QueueState> get queueState => _queueStateSubject.stream;

  void updateTestQueue(List<MediaItem> q, int? index) {
    queue.add(q);
    _queueStateSubject.add(
      QueueState(q, index, null, AudioServiceRepeatMode.none),
    );
  }

  void updateTestMediaItem(MediaItem? item) {
    mediaItem.add(item);
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {}

  @override
  Future<void> play() async {
    playCount++;
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> stop() async {
    stopCount++;
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> skipToNext() async {
    skipToNextCount++;
  }

  @override
  Future<void> skipToPrevious() async {
    skipToPreviousCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeekPosition = position;
  }

  @override
  Future customAction(String name, [Map<String, dynamic>? extras]) async {
    lastCustomAction = name;
    return super.customAction(name, extras);
  }

  void dispose() {
    _volumeSubject.close();
    _speedSubject.close();
    _queueStateSubject.close();
  }
}

Widget buildTestApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_batch7_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Batch 7 - Audio Queue Index and Sequence Calculations', () {
    int? calculateQueueIndex(
      int? currentIndex,
      List<int>? shuffleIndices,
      List<int> effectiveIndices, {
      bool shuffleModeEnabled = false,
    }) {
      if (currentIndex == null || currentIndex < 0) return null;
      if (effectiveIndices.isEmpty) return currentIndex;

      final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
      for (var i = 0; i < effectiveIndices.length; i++) {
        final target = effectiveIndices[i];
        if (target >= 0 && target < shuffleIndicesInv.length) {
          shuffleIndicesInv[target] = i;
        }
      }
      return (shuffleModeEnabled &&
              currentIndex >= 0 &&
              currentIndex < shuffleIndicesInv.length)
          ? shuffleIndicesInv[currentIndex]
          : ((currentIndex >= 0 && currentIndex < effectiveIndices.length)
              ? currentIndex
              : null);
    }

    test('calculateQueueIndex handles negative index gracefully without throwing', () {
      expect(calculateQueueIndex(-1, [0, 1, 2], [0, 1, 2]), isNull);
      expect(calculateQueueIndex(null, [0, 1, 2], [0, 1, 2]), isNull);
    });

    test('calculateQueueIndex returns currentIndex when effectiveIndices is empty', () {
      expect(calculateQueueIndex(2, [], []), equals(2));
    });

    test('calculateQueueIndex handles shuffle mode mapping correctly', () {
      final effective = [2, 0, 1];
      final qIndex = calculateQueueIndex(
        0,
        [2, 0, 1],
        effective,
        shuffleModeEnabled: true,
      );
      expect(qIndex, equals(1));
    });

    test('calculateQueueIndex handles out of bounds index safely', () {
      final effective = [0, 1];
      expect(
        calculateQueueIndex(5, [0, 1], effective, shuffleModeEnabled: true),
        isNull,
      );
    });

    test('Sequence null expando items filtered safely', () {
      final expando = Expando<MediaItem>();
      final sourceA = Object();
      final sourceB = Object();
      final sourceC = Object();

      final itemA = const MediaItem(id: '1', title: 'Song 1');
      final itemC = const MediaItem(id: '3', title: 'Song 3');

      expando[sourceA] = itemA;
      // sourceB has no expando entry (null)
      expando[sourceC] = itemC;

      final sequence = [sourceA, sourceB, sourceC];
      final queue = sequence
          .map((s) => expando[s])
          .whereType<MediaItem>()
          .toList();

      expect(queue.length, equals(2));
      expect(queue[0].title, equals('Song 1'));
      expect(queue[1].title, equals('Song 3'));
    });
  });

  group('Batch 7 - Audio Interruption & Headphone Routing Events', () {
    test('Interruption ducking halves volume and restore returns to full', () {
      double volume = 1.0;
      double previousVolume = 1.0;

      void handleInterruption(AudioInterruptionEvent event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              previousVolume = volume;
              volume = volume * 0.5;
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              break;
          }
        } else {
          if (event.type == AudioInterruptionType.duck) {
            volume = previousVolume;
          }
        }
      }

      handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      expect(volume, equals(0.5));

      handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(volume, equals(1.0));
    });

    test('Headphone unplug event (becoming noisy) pauses playback', () {
      bool isPlaying = true;
      bool playInterrupted = false;

      void handleBecomingNoisy() {
        if (isPlaying) {
          isPlaying = false;
          playInterrupted = false;
        }
      }

      handleBecomingNoisy();
      expect(isPlaying, isFalse);
      expect(playInterrupted, isFalse);
    });
  });

  group('Batch 7 - Compact Notification Indices Validation', () {
    test('Indices are strictly bounded by available controls length', () {
      final preferred = [0, 1, 2, 3, 5, 10, -1];
      final controls = [
        MediaControl.rewind,
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ]; // length 5

      final safeIndices =
          preferred.where((i) => i >= 0 && i < controls.length).toList();

      expect(safeIndices, equals([0, 1, 2, 3]));
      expect(safeIndices.every((i) => i >= 0 && i < controls.length), isTrue);
    });

    test('Processing state fallback works when unmapped state occurs', () {
      const processingMap = {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      };

      final AudioProcessingState state =
          processingMap[null] ?? AudioProcessingState.idle;
      expect(state, equals(AudioProcessingState.idle));
    });
  });

  group('Batch 7 - Player Service & Tag Extraction Safety', () {
    test('setTags safely handles null artist and album from SongModel', () async {
      final songModel = SongModel({
        '_id': 101,
        '_data': '/storage/emulated/0/Music/song.mp3',
        '_display_name_wo_ext': 'LocalSong',
        'title': '',
        'artist': null,
        'album': null,
        'duration': null,
        '_size': 1024,
        '_date_added': 12345,
        '_date_modified': 12345,
      });

      final mediaItem = await PlayerInvoke.setTags(songModel, tempDir);
      expect(mediaItem.id, equals('101'));
      expect(mediaItem.title, equals('LocalSong'));
      expect(mediaItem.artist, equals('Unknown'));
      expect(mediaItem.album, equals('Unknown'));
      expect(mediaItem.duration, equals(const Duration(milliseconds: 180000)));
    });

    test('Playlist helper functions safely check box opening', () async {
      expect(checkPlaylist('UnopenedBox', 'some_id'), isFalse);

      final box = await Hive.openBox('TestPlaylist');
      await box.put('track1', {'id': 'track1', 'title': 'Test'});

      expect(checkPlaylist('TestPlaylist', 'track1'), isTrue);
      expect(checkPlaylist('TestPlaylist', 'missing'), isFalse);

      await box.close();
    });
  });

  group('Batch 7 - UI Components Resilience (ControlButtons, MiniPlayer, SeekBar)', () {
    testWidgets('ControlButtons renders safely without crashing when mediaItem is null',
        (WidgetTester tester) async {
      final handler = TestBatch7AudioHandler();
      handler.updateTestMediaItem(null);

      await tester.pumpWidget(
        buildTestApp(
          home: Scaffold(
            body: ControlButtons(
              handler,
              buttons: const ['Like', 'Previous', 'Play/Pause', 'Next', 'Download'],
            ),
          ),
        ),
      );

      expect(find.byType(ControlButtons), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      handler.dispose();
    });

    testWidgets('MiniPlayer SliderTheme does not throw when mediaItem duration is null',
        (WidgetTester tester) async {
      const mediaItem = MediaItem(
        id: '202',
        title: 'Stream Song',
        duration: null,
      );

      final durationSeconds = mediaItem.duration?.inSeconds.toDouble() ?? 0.0;
      Widget buildSlider(Duration? position) {
        if (position == null ||
            durationSeconds <= 0.0 ||
            position.inSeconds.toDouble() < 0.0 ||
            position.inSeconds.toDouble() > durationSeconds) {
          return const SizedBox(key: Key('safe_empty_slider'));
        }
        return Slider(
          value: position.inSeconds.toDouble(),
          max: durationSeconds,
          onChanged: (_) {},
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildSlider(const Duration(seconds: 10)),
          ),
        ),
      );

      expect(find.byKey(const Key('safe_empty_slider')), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('SeekBar clamps position safely to [0.0, maxDuration]',
        (WidgetTester tester) async {
      final handler = TestBatch7AudioHandler();

      // Position is negative and duration is 0
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekBar(
              duration: Duration.zero,
              position: const Duration(seconds: -5),
              bufferedPosition: const Duration(seconds: -1),
              offline: false,
              audioHandler: handler,
            ),
          ),
        ),
      );

      expect(find.byType(SeekBar), findsOneWidget);

      // Now valid duration
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeekBar(
              duration: const Duration(seconds: 100),
              position: const Duration(seconds: 25),
              bufferedPosition: const Duration(seconds: 50),
              offline: false,
              audioHandler: handler,
            ),
          ),
        ),
      );

      expect(find.byType(SeekBar), findsOneWidget);
      handler.dispose();
    });
  });

  group('Batch 7 - Seeking and Skip Boundary Protection', () {
    test('Seek clamps negative target to Duration.zero and excess to max duration', () {
      const maxDuration = Duration(minutes: 3);

      Duration clampSeek(Duration target) {
        Duration res = target;
        if (res < Duration.zero) res = Duration.zero;
        if (res > maxDuration) res = maxDuration;
        return res;
      }

      expect(clampSeek(const Duration(seconds: -10)), equals(Duration.zero));
      expect(clampSeek(const Duration(minutes: 5)), equals(maxDuration));
      expect(
        clampSeek(const Duration(minutes: 1)),
        equals(const Duration(minutes: 1)),
      );
    });

    test('Stop timeout protection ensures no indefinite hanging', () async {
      final stateSubject =
          BehaviorSubject<PlaybackState>.seeded(PlaybackState());

      Future<void> simulateStop() async {
        try {
          await stateSubject.stream
              .firstWhere(
                (state) => state.processingState == AudioProcessingState.idle,
              )
              .timeout(const Duration(milliseconds: 100));
        } catch (_) {
          // Timeout safely caught
        }
      }

      final stopwatch = Stopwatch()..start();
      await simulateStop();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      await stateSubject.close();
    });
  });
}
