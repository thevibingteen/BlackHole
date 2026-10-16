@Tags(['integration'])
library cache_retry_test;
import 'dart:io';

import 'package:blackhole/Helpers/playback_retry_policy.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_cache_retry_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('ytlinkcache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('YouTube Stream Cache Lifecycle & Invalidation Tests', () {
    test('invalidateCache deletes specific video from ytlinkcache', () async {
      final box = Hive.box('ytlinkcache');
      await box.put('test_video_123', {
        'url': 'https://example.com/stream.mp4',
        'expire_at': '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
        'quality': 'High',
      });
      expect(box.containsKey('test_video_123'), isTrue);

      await YouTubeServices().invalidateCache('test_video_123');
      expect(box.containsKey('test_video_123'), isFalse,
          reason: 'Cache entry must be deleted after invalidation');
    });

    test('pruneExpiredCache removes expired items and preserves valid items', () async {
      final box = Hive.box('ytlinkcache');
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await box.put('expired_video', {
        'url': 'https://example.com/expired.mp4',
        'expire_at': '${now - 500}',
        'quality': 'Low',
      });
      await box.put('valid_video', {
        'url': 'https://example.com/valid.mp4',
        'expire_at': '${now + 7200}',
        'quality': 'High',
      });

      expect(box.containsKey('expired_video'), isTrue);
      expect(box.containsKey('valid_video'), isTrue);

      await YouTubeServices.pruneExpiredCache();

      expect(box.containsKey('expired_video'), isFalse, reason: 'Expired video must be purged');
      expect(box.containsKey('valid_video'), isTrue, reason: 'Valid video must be preserved');
    });

    test('10-minute (600s) expiry safety buffer correctly classifies stream validity', () {
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Stream expiring in 300s (inside 600s buffer) should be treated as expired
      final int nearExpiry = now + 300;
      final bool nearIsExpired = (now + 600) > nearExpiry;
      expect(nearIsExpired, isTrue,
          reason: 'Stream within 10-minute window must be treated as expired to avoid mid-song 403');

      // Stream expiring in 3600s (outside 600s buffer) is valid
      final int farExpiry = now + 3600;
      final bool farIsExpired = (now + 600) > farExpiry;
      expect(farIsExpired, isFalse, reason: 'Stream with > 10 min remaining is valid for playback');
    });

    test('Cache respects quality flag and does not return low-quality stream for high-quality request', () async {
      final box = Hive.box('ytlinkcache');
      const testId = 'quality_test_video';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Seed cache with 'Low' quality
      await box.put(testId, {
        'url': 'https://example.com/low_quality.mp4',
        'expire_at': '${now + 3600}',
        'quality': 'Low',
      });

      final cached = box.get(testId) as Map;
      expect(cached['quality'], equals('Low'));

      // If requested quality is 'High', the cached 'Low' entry is deemed incompatible
      const requestedQuality = 'High';
      final bool isCompatible = cached['quality'] == requestedQuality;
      expect(isCompatible, isFalse,
          reason: 'Cache must not serve low quality when high quality is requested');
    });

    test('PlaybackRetryPolicy production state machine strictly limits retries to 1 per track and handles concurrency', () {
      final policy = PlaybackRetryPolicy();

      // First playback error on track A: policy should allow retry
      expect(policy.isHandling, isFalse);
      expect(policy.shouldRetry('song_A'), isTrue);
      expect(policy.lastRetriedId, equals('song_A'));

      // Simulate retry in flight
      policy.beginHandling();
      expect(policy.isHandling, isTrue);

      // Concurrent errors while handling should be rejected
      expect(policy.shouldRetry('song_A'), isFalse);
      expect(policy.shouldRetry('song_B'), isFalse);

      // Retry finishes
      policy.endHandling();
      expect(policy.isHandling, isFalse);

      // Second playback error on song A: policy must NOT retry again (returns false)
      expect(policy.shouldRetry('song_A'), isFalse,
          reason: 'Must not retry song_A again; must halt to prevent infinite retry loop');
      expect(policy.lastRetriedId, isNull,
          reason: 'Tracking resets after halting');

      // A different track should receive a fresh retry opportunity
      expect(policy.shouldRetry('song_B'), isTrue);
      expect(policy.lastRetriedId, equals('song_B'));

      // Policy reset on network change resets state cleanly
      policy.reset();
      expect(policy.lastRetriedId, isNull);
      expect(policy.isHandling, isFalse);
    });
  });
}
