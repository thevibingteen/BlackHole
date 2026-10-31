/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

class _DummyAudioPlayerHandler extends BaseAudioHandler
    implements AudioPlayerHandler {
  @override
  Stream<QueueState> get queueState => const Stream.empty();
  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {}
  @override
  ValueStream<double> get volume => BehaviorSubject<double>.seeded(1.0);
  @override
  Future<void> setVolume(double volume) async {}
  @override
  ValueStream<double> get speed => BehaviorSubject<double>.seeded(1.0);
}

class StartupProfiler {
  StartupProfiler._() {
    _stopwatch.start();
  }
  static final StartupProfiler instance = StartupProfiler._();

  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, int> _checkpoints = {};
  static Completer<AudioPlayerHandler> _audioReadyCompleter =
      Completer<AudioPlayerHandler>();
  static Object? _audioServiceError;
  static StackTrace? _audioServiceStackTrace;

  static Future<AudioPlayerHandler> get audioHandlerFuture =>
      _audioReadyCompleter.future;

  static bool get hasAudioServiceFailed => _audioServiceError != null;
  static Object? get audioServiceError => _audioServiceError;
  static StackTrace? get audioServiceStackTrace => _audioServiceStackTrace;
  static bool get isAudioServiceReady =>
      _audioReadyCompleter.isCompleted && !hasAudioServiceFailed;

  static void notifyAudioServiceReady(AudioPlayerHandler handler) {
    if (!_audioReadyCompleter.isCompleted) {
      _audioReadyCompleter.complete(handler);
    }
  }

  static void notifyAudioServiceFailed(Object error, [StackTrace? stackTrace]) {
    _audioServiceError = error;
    _audioServiceStackTrace = stackTrace;
    if (!_audioReadyCompleter.isCompleted) {
      _audioReadyCompleter.completeError(error, stackTrace);
      // Suppress unhandled zone error if no listener attaches before error completion
      _audioReadyCompleter.future.catchError((Object err, StackTrace st) {
        return _DummyAudioPlayerHandler();
      });
    }
  }

  static void prepareForRetry() {
    if (!isAudioServiceReady) {
      _audioReadyCompleter = Completer<AudioPlayerHandler>();
      _audioServiceError = null;
      _audioServiceStackTrace = null;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _audioReadyCompleter = Completer<AudioPlayerHandler>();
    _audioServiceError = null;
    _audioServiceStackTrace = null;
  }

  void mark(String name) {
    final int elapsed = _stopwatch.elapsedMilliseconds;
    _checkpoints[name] = elapsed;
    if (kDebugMode) {
      Logger.root.info('[StartupProfiler] $name: ${elapsed}ms');
    }
  }

  int? get(String name) => _checkpoints[name];

  Map<String, int> get allCheckpoints => Map.unmodifiable(_checkpoints);

  void dumpSummary() {
    if (!kDebugMode) return;
    final buffer = StringBuffer('=== BlackHole Startup Timeline ===\n');
    _checkpoints.forEach((key, ms) {
      buffer.writeln('  +${ms.toString().padLeft(5)} ms : $key');
    });
    buffer.writeln('==================================');
    Logger.root.info(buffer.toString());
  }
}
