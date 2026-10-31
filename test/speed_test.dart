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
import 'package:blackhole/CustomWidgets/seek_bar.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';

/// Controllable fake audio engine representing the underlying player (just_audio).
class FakePlaybackEngine {
  double currentSpeed = 1.0;
  double currentPitch = 1.0;
  final List<double> speedCommandHistory = [];
  final List<double> pitchCommandHistory = [];
  final BehaviorSubject<double> _speedSubject =
      BehaviorSubject<double>.seeded(1.0);

  Stream<double> get speedStream => _speedSubject.stream;

  Future<void> setSpeed(double speed) async {
    currentSpeed = speed;
    speedCommandHistory.add(speed);
    _speedSubject.add(speed);
  }

  Future<void> setPitch(double pitch) async {
    currentPitch = pitch;
    pitchCommandHistory.add(pitch);
  }

  void simulateExternalEngineSpeedChange(double newSpeed) {
    currentSpeed = newSpeed;
    _speedSubject.add(newSpeed);
  }

  void dispose() {
    _speedSubject.close();
  }
}

/// Test harness implementation of AudioPlayerHandler matching AudioPlayerHandlerImpl's
/// exact speed synchronization, persistence, clamping, and engine bridge logic.
class SpeedTestAudioHandler extends BaseAudioHandler
    implements AudioPlayerHandler {
  final FakePlaybackEngine engine;
  final BehaviorSubject<double> _speed = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _volume = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<QueueState> _queueState = BehaviorSubject<QueueState>();
  StreamSubscription? _engineSpeedSubscription;

  SpeedTestAudioHandler({required this.engine}) {
    // 1. Initial speed from settings box (default 1.0)
    final double initialSpeed = Hive.isBoxOpen('settings')
        ? (Hive.box('settings').get('playbackSpeed', defaultValue: 1.0) as num)
            .toDouble()
        : 1.0;
    if (_speed.value != initialSpeed) {
      _speed.add(initialSpeed);
    }

    // 2. Initial rate applied to engine on startup
    engine.setSpeed(initialSpeed);
    engine.setPitch(1.0);

    // 3. Engine speedStream bound to handler to prevent silent divergence
    _engineSpeedSubscription = engine.speedStream.distinct().listen((engineSpeed) {
      if ((_speed.value - engineSpeed).abs() > 0.01) {
        _speed.add(engineSpeed);
      }
    });
  }

  @override
  ValueStream<double> get speed => _speed;

  @override
  ValueStream<double> get volume => _volume;

  @override
  Stream<QueueState> get queueState => _queueState.stream;

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {}

  @override
  Future<void> setVolume(double volume) async {
    _volume.add(volume);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final double sanitized = (speed * 10).round() / 10.0;
    final double clampedSpeed = sanitized.clamp(0.5, 3.0);
    _speed.add(clampedSpeed);
    await engine.setSpeed(clampedSpeed);
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').put('playbackSpeed', clampedSpeed);
    }
    playbackState.add(playbackState.value.copyWith(speed: clampedSpeed));
  }

  void dispose() {
    _engineSpeedSubscription?.cancel();
    _speed.close();
    _volume.close();
    _queueState.close();
  }
}

Widget buildSpeedTestApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_speed_test');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
  });

  tearDownAll(() async {
    try {
      await settingsBox.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    await settingsBox.clear();
  });

  group('Playback Speed Engine Bridge & State Synchronization Tests', () {
    test('Default speed: engine receives 1.0 and state agrees at 1.0', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      // Verify initial state
      expect(handler.speed.value, equals(1.0));
      expect(engine.currentSpeed, equals(1.0));
      expect(engine.currentPitch, equals(1.0));
      expect(engine.speedCommandHistory, contains(1.0));
      expect(engine.pitchCommandHistory, contains(1.0));

      handler.dispose();
      engine.dispose();
    });

    test('Selecting faster speed (1.5x) sends 1.5 to engine and persists setting', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      await handler.setSpeed(1.5);

      // Verify engine and handler are synchronized at 1.5
      expect(handler.speed.value, equals(1.5));
      expect(engine.currentSpeed, equals(1.5));
      expect(handler.playbackState.value.speed, equals(1.5));
      expect(settingsBox.get('playbackSpeed'), equals(1.5));

      handler.dispose();
      engine.dispose();
    });

    test('Selecting slower speed (0.7x) sends 0.7 to engine and updates state', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      await handler.setSpeed(0.7);

      expect(handler.speed.value, equals(0.7));
      expect(engine.currentSpeed, equals(0.7));
      expect(handler.playbackState.value.speed, equals(0.7));
      expect(settingsBox.get('playbackSpeed'), equals(0.7));

      handler.dispose();
      engine.dispose();
    });

    test('Returning to 1.0x genuinely resets engine to normal speed', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      // Accelerate first
      await handler.setSpeed(1.8);
      expect(engine.currentSpeed, equals(1.8));

      // Reset back to normal 1.0x
      await handler.setSpeed(1.0);

      expect(handler.speed.value, equals(1.0));
      expect(engine.currentSpeed, equals(1.0));
      expect(settingsBox.get('playbackSpeed'), equals(1.0));
      expect(engine.speedCommandHistory.last, equals(1.0));

      handler.dispose();
      engine.dispose();
    });

    test('Clamping & sanitization: bounds between 0.5x and 3.0x without float drift', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      // Value below min
      await handler.setSpeed(0.2);
      expect(handler.speed.value, equals(0.5));
      expect(engine.currentSpeed, equals(0.5));

      // Value above max
      await handler.setSpeed(4.5);
      expect(handler.speed.value, equals(3.0));
      expect(engine.currentSpeed, equals(3.0));

      // Float precision drift (e.g. 1.2000000000000002)
      await handler.setSpeed(1.2000000000000002);
      expect(handler.speed.value, equals(1.2));
      expect(engine.currentSpeed, equals(1.2));

      handler.dispose();
      engine.dispose();
    });

    test('Engine speed changes propagate to handler (cannot silently disagree)', () async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      expect(handler.speed.value, equals(1.0));

      // Engine updates externally
      engine.simulateExternalEngineSpeedChange(1.25);
      await pumpEventQueue();

      // Handler stream must reflect engine rate
      expect(handler.speed.value, equals(1.25));

      handler.dispose();
      engine.dispose();
    });
  });

  group('Speed Dialog & UI Controls Widget Tests', () {
    testWidgets('Speed dialog displays current speed and +/- buttons correctly adjust speed',
        (WidgetTester tester) async {
      final engine = FakePlaybackEngine();
      final handler = SpeedTestAudioHandler(engine: engine);

      await tester.pumpWidget(
        buildSpeedTestApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showSliderDialog(
                      context: context,
                      title: 'Adjust Speed',
                      divisions: 25,
                      min: 0.5,
                      max: 3.0,
                      audioHandler: handler,
                    );
                  },
                  child: const Text('Open Speed Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Speed Dialog'));
      await tester.pumpAndSettle();

      // Verify title and initial 1.0 text in dialog
      expect(find.text('Adjust Speed'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);

      // Tap + button to increase speed
      await tester.tap(find.byIcon(CupertinoIcons.plus));
      await tester.pumpAndSettle();

      // UI updates to 1.1 and engine received 1.1
      expect(find.text('1.1'), findsOneWidget);
      expect(engine.currentSpeed, equals(1.1));
      expect(handler.speed.value, equals(1.1));

      // Tap - button twice
      await tester.tap(find.byIcon(CupertinoIcons.minus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.minus));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // UI updates to 0.9 and engine received 0.9
      expect(find.text('0.9'), findsOneWidget);
      expect(engine.currentSpeed, equals(0.9));
      expect(handler.speed.value, equals(0.9));

      handler.dispose();
      engine.dispose();
    });
  });
}
