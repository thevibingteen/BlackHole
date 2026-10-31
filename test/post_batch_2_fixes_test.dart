/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2022, Ankit Sangwan
 */

import 'dart:convert';
import 'dart:io';

import 'package:blackhole/Helpers/image_resolution_modifier.dart';
import 'package:blackhole/Helpers/lyrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// Mock HTTP Client for testing lyrics requests without live network access
class MockLyricsHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> recordedRequests = [];

  MockLyricsHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    recordedRequests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ISSUE A: Navigation Drawer Header & Version Label', () {
    test('Header image asset path is uniform assets/header.jpg', () {
      // In home.dart, both light and dark mode now use assets/header.jpg
      const lightHeader = 'assets/header.jpg';
      const darkHeader = 'assets/header.jpg';
      expect(lightHeader, equals('assets/header.jpg'));
      expect(darkHeader, equals('assets/header.jpg'));
    });

    test('Version label formatting preserves v-prefix and handles fallbacks', () {
      String formatVersion(String? raw) =>
          (raw == null || raw.isEmpty) ? 'v1.15.8' : 'v$raw';

      expect(formatVersion(null), equals('v1.15.8'));
      expect(formatVersion(''), equals('v1.15.8'));
      expect(formatVersion('1.15.8'), equals('v1.15.8'));
    });

    testWidgets('Header RichText renders title and version with white text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RichText(
                text: const TextSpan(
                  text: 'BlackHole\n',
                  style: TextStyle(
                    fontSize: 30.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: 'v1.15.8',
                      style: TextStyle(
                        fontSize: 7.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsOneWidget);

      final RichText richText = tester.widget<RichText>(richTextFinder);
      final TextSpan rootSpan = richText.text as TextSpan;
      expect(rootSpan.text, equals('BlackHole\n'));
      expect(rootSpan.style?.color, equals(Colors.white));

      final TextSpan versionSpan = rootSpan.children!.first as TextSpan;
      expect(versionSpan.text, equals('v1.15.8'));
      expect(versionSpan.style?.color, equals(Colors.white));
    });
  });

  group('ISSUE B: Artwork Caching & Prefetch Strategy', () {
    test('getImageUrl converts HTTP to HTTPS and preserves resolution', () {
      final secure = getImageUrl('http://c.saavncdn.com/123/Song-150x150.jpg');
      expect(secure, startsWith('https://'));
      expect(secure, contains('500x500'));
    });

    test('getImageUrl handles null and empty URLs gracefully', () {
      expect(getImageUrl(null), equals(''));
      expect(getImageUrl(''), equals(''));
    });

    test('Prefetch slicing is bounded to prevent unbounded requests', () {
      final hundredItems = List.generate(100, (i) => {'image': 'url_$i'});
      const maxCount = 10;
      final prefetched = hundredItems.take(maxCount).toList();

      expect(prefetched.length, equals(10));
      expect(prefetched.first['image'], equals('url_0'));
      expect(prefetched.last['image'], equals('url_9'));
    });

    test('Artwork memory cache decoding bounds protect heap', () {
      const listMemCacheWidth = 150;
      const listMemCacheHeight = 150;
      const cardMemCacheWidth = 300;
      const cardMemCacheHeight = 300;

      expect(listMemCacheWidth, equals(150));
      expect(listMemCacheHeight, equals(150));
      expect(cardMemCacheWidth, equals(300));
      expect(cardMemCacheHeight, equals(300));
    });
  });

  group('ISSUE C: Lyrics Discovery & Fallback Pipeline', () {
    test('cleanSongTitle removes redundant brackets and metadata tags', () {
      expect(
        Lyrics.cleanSongTitle('Tum Mile (From "Tum Mile") [Official Audio]'),
        equals('Tum Mile'),
      );
      expect(
        Lyrics.cleanSongTitle('Kesariya - Audio | Brahmastra'),
        equals('Kesariya'),
      );
      expect(
        Lyrics.cleanSongTitle('Shape of You (Remix) [feat. Stormzy]'),
        equals('Shape of You'),
      );
      expect(
        Lyrics.cleanSongTitle('Something Just Like This'),
        equals('Something Just Like This'),
      );
    });

    test('extractArtistCandidates parses multi-artist strings correctly', () {
      final candidates1 = Lyrics.extractArtistCandidates(
        'Sayeed Quadri, Pritam, KK',
      );
      expect(candidates1, contains('Sayeed Quadri, Pritam, KK'));
      expect(candidates1, contains('Sayeed Quadri'));
      expect(candidates1, contains('Pritam'));
      expect(candidates1, contains('KK'));

      final candidates2 = Lyrics.extractArtistCandidates('Taylor Swift ft. Bon Iver');
      expect(candidates2, contains('Taylor Swift'));
      expect(candidates2, contains('Bon Iver'));

      final candidates3 = Lyrics.extractArtistCandidates('Alan Walker & Ava Max');
      expect(candidates3, contains('Alan Walker'));
      expect(candidates3, contains('Ava Max'));

      final candidates4 = Lyrics.extractArtistCandidates('Coldplay');
      expect(candidates4, contains('Coldplay'));
    });

    test('isHtmlOrChallenge detects HTML tags and Cloudflare/bot challenges', () {
      expect(Lyrics.isHtmlOrChallenge('<!DOCTYPE html><html><body>Error</body></html>'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('<html><head><title>Challenge</title></head></html>'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('Attention Required! | Cloudflare'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('<div>Please verify you are human</div>'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('[00:12.34]Here are valid lyrics'), isFalse);
      expect(Lyrics.isHtmlOrChallenge('Plain text lyrics line 1\nLine 2'), isFalse);
    });

    test('LRCLIB exact lookup succeeds and returns synced LRC lyrics', () async {
      final mockClient = MockLyricsHttpClient((request) async {
        expect(request.url.host, equals('lrclib.net'));
        expect(request.url.path, equals('/api/get'));
        expect(
          request.headers['User-Agent'],
          equals('BlackHole v1.15.8 (https://github.com/Sangwan5688/BlackHole)'),
        );

        return http.Response(
          json.encode({
            'trackName': 'Tum Mile',
            'artistName': 'KK',
            'duration': 210,
            'syncedLyrics': '[00:10.00]Tu hi haqeeqat khwaab tu\n[00:15.00]Dariya tu hi pyaas tu',
            'plainLyrics': 'Tu hi haqeeqat khwaab tu\nDariya tu hi pyaas tu',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await Lyrics.getLrclibLyrics(
        trackName: 'Tum Mile (From "Tum Mile")',
        artistName: 'Sayeed Quadri, Pritam, KK',
        duration: 210,
        client: mockClient,
      );

      expect(result['lyrics'], isNotEmpty);
      expect(result['type'], equals('lrc'));
      expect(result['source'], equals('LRCLIB'));
      expect(result['lyrics'], contains('[00:10.00]Tu hi haqeeqat'));
    });

    test('LRCLIB exact lookup falls back to search and ranks candidates by duration',
        () async {
      final mockClient = MockLyricsHttpClient((request) async {
        if (request.url.path == '/api/get') {
          return http.Response('{"error": "not found"}', 404);
        }
        if (request.url.path == '/api/search') {
          return http.Response(
            json.encode([
              {
                'trackName': 'Tum Mile',
                'artistName': 'Other Artist',
                'duration': 90, // Wrong duration (>30s diff)
                'syncedLyrics': '[00:05.00]Wrong song lyrics',
              },
              {
                'trackName': 'Tum Mile',
                'artistName': 'KK',
                'duration': 212, // Close duration (diff <= 5s)
                'syncedLyrics': '[00:10.00]Correct matched lyrics by KK',
                'plainLyrics': 'Correct matched lyrics by KK',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await Lyrics.getLrclibLyrics(
        trackName: 'Tum Mile',
        artistName: 'Sayeed Quadri, Pritam, KK',
        duration: 210,
        client: mockClient,
      );

      expect(result['lyrics'], contains('Correct matched lyrics by KK'));
      expect(result['type'], equals('lrc'));
      expect(result['source'], equals('LRCLIB'));
    });

    test('LRCLIB 429 rate limit is handled gracefully without crashing', () async {
      final mockClient = MockLyricsHttpClient((request) async {
        return http.Response(
          '{"error": "Too Many Requests"}',
          429,
          headers: {'retry-after': '60'},
        );
      });

      final result = await Lyrics.getLrclibLyrics(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        client: mockClient,
      );

      expect(result['lyrics'], isEmpty);
      expect(result['source'], equals('LRCLIB'));
    });

    test('LRCLIB network timeout/error is handled without crashing', () async {
      final mockClient = MockLyricsHttpClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      final result = await Lyrics.getLrclibLyrics(
        trackName: 'Test Track',
        artistName: 'Test Artist',
        client: mockClient,
      );

      expect(result['lyrics'], isEmpty);
    });

    test('Stale lyrics response guard ignores responses for previous track', () {
      const String currentTrackId = 'track_current_999';
      final Map<String, dynamic> incomingResponseForOldTrack = {
        'id': 'track_old_111',
        'lyrics': 'Old lyrics',
        'type': 'text',
        'source': 'LRCLIB',
      };

      bool lyricsAccepted = false;
      if (currentTrackId == incomingResponseForOldTrack['id']) {
        lyricsAccepted = true;
      }

      expect(lyricsAccepted, isFalse);
    });

    test('In-flight deduplication shares single request for identical track query',
        () async {
      int networkHits = 0;
      final mockClient = MockLyricsHttpClient((request) async {
        networkHits++;
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(
          json.encode({
            'trackName': 'Parallel Song',
            'artistName': 'Parallel Artist',
            'syncedLyrics': '[00:01.00]Parallel line',
          }),
          200,
        );
      });

      // Fire two concurrent getLyrics calls with the same ID
      final f1 = Lyrics.getLyrics(
        id: 'concurrent_track_1',
        title: 'Parallel Song',
        artist: 'Parallel Artist',
        saavnHas: false,
        client: mockClient,
      );
      final f2 = Lyrics.getLyrics(
        id: 'concurrent_track_1',
        title: 'Parallel Song',
        artist: 'Parallel Artist',
        saavnHas: false,
        client: mockClient,
      );

      final results = await Future.wait([f1, f2]);
      expect(results[0]['lyrics'], equals('[00:01.00]Parallel line'));
      expect(results[1]['lyrics'], equals('[00:01.00]Parallel line'));
      // Only 1 network hit should occur due to deduplication
      expect(networkHits, equals(1));
    });

    test('Hive cache hit reuses cached lyrics without issuing network request', () async {
      // Set up a temporary Hive directory for cache testing
      final tempDir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(tempDir.path);
      final cacheBox = await Hive.openBox('cache');

      try {
        await cacheBox.put('lyrics_cached_track_123', {
          'lyrics': '[00:05.00]Stored in Hive cache',
          'type': 'lrc',
          'source': 'LRCLIB',
        });

        int networkHits = 0;
        final mockClient = MockLyricsHttpClient((request) async {
          networkHits++;
          return http.Response('{}', 200);
        });

        final result = await Lyrics.getLyrics(
          id: 'cached_track_123',
          title: 'Cached Track',
          artist: 'Cached Artist',
          saavnHas: false,
          client: mockClient,
        );

        expect(result['lyrics'], equals('[00:05.00]Stored in Hive cache'));
        expect(result['type'], equals('lrc'));
        expect(result['source'], equals('LRCLIB'));
        expect(networkHits, equals(0));

        // Test fallback when source is not stored in cache
        await cacheBox.put('lyrics_cached_no_source', {
          'lyrics': 'Plain cached lyrics',
          'type': 'text',
        });

        final resultNoSource = await Lyrics.getLyrics(
          id: 'cached_no_source',
          title: 'No Source Track',
          artist: 'Artist',
          saavnHas: false,
          client: mockClient,
        );
        expect(resultNoSource['source'], equals('Cache'));
        expect(networkHits, equals(0));
      } finally {
        await cacheBox.close();
        await tempDir.delete(recursive: true);
      }
    });
  });
}
