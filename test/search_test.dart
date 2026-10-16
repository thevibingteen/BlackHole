@Tags(['smoke'])
library search_test;

// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _RealHttpOverrides();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_test_');
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

  group('JioSaavn Live API Smoke Tests', () {
    test('Search for songs and verify valid decrypted streaming URLs', () async {
      final results = await SaavnAPI().fetchSongSearchResults(
        searchQuery: 'Kesariya',
        count: 5,
      );
      expect(results, isNotNull);
      final songs = results['songs'] as List;
      expect(songs.isNotEmpty, isTrue, reason: 'Should return at least one song for Kesariya');
      final firstSong = songs.first as Map;
      expect(firstSong['title'], isNotNull);
      expect(firstSong['url'], isNotNull);
      expect(
        firstSong['url'].toString().startsWith('https://') || firstSong['url'].toString().startsWith('http://'),
        isTrue,
        reason: 'Decrypted streaming URL must be a valid URL',
      );
      print('JioSaavn Test Passed! First song: "${firstSong['title']}" URL: ${firstSong['url']}');
    });

    test('Search for albums/playlists/artists via fetchSearchResults', () async {
      final results = await SaavnAPI().fetchSearchResults('Aashiqui 2');
      expect(results, isNotNull);
      expect(results.isNotEmpty, isTrue, reason: 'Should return categorized search results');
      print('JioSaavn Category Test Passed! Found categories: ${results.length}');
    });
  });

  group('YouTube Explode Live API Smoke Tests', () {
    test('Search YouTube videos and fetch audio-only stream manifest', () async {
      final yt = YoutubeExplode();
      try {
        final searchResults = await yt.search.search('Shape of You');
        expect(searchResults.isNotEmpty, isTrue);
        final firstVideo = searchResults.first;
        expect(firstVideo.title, isNotNull);
        expect(firstVideo.id.value.isNotEmpty, isTrue);

        // Fetch stream manifest to ensure cipher/decryption works
        final manifest = await yt.videos.streamsClient.getManifest(firstVideo.id);
        final audioStreams = manifest.audioOnly;
        expect(audioStreams.isNotEmpty, isTrue, reason: 'Should have valid playable audio streams');
        final highestBitrate = audioStreams.withHighestBitrate();
        expect(highestBitrate.url.toString().isNotEmpty, isTrue);
        print('YouTube Test Passed! First video: "${firstVideo.title}" Audio URL: ${highestBitrate.url}');
      } finally {
        yt.close();
      }
    });

    test('refreshLink bypasses stale cache and fetches fresh stream URL', () async {
      final box = Hive.box('ytlinkcache');
      const testVideoId = 'dQw4w9WgXcQ';
      const staleUrl = 'https://example.com/stale_expired_stream_403.mp4';

      // Seed cache with a stale/expired stream URL
      await box.put(testVideoId, {
        'url': staleUrl,
        'expire_at': '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) - 100}',
        'quality': 'Low',
      });
      expect((box.get(testVideoId) as Map)['url'], equals(staleUrl));

      // Invalidate and refresh
      await YouTubeServices().invalidateCache(testVideoId);
      final freshData = await YouTubeServices().refreshLink(testVideoId);

      expect(freshData, isNotNull);
      expect(freshData!['url'], isNotNull);
      expect(freshData['url'].toString(), isNotEmpty);
      expect(freshData['url'].toString(), isNot(equals(staleUrl)),
          reason: 'refreshLink must bypass stale cache and obtain a real fresh stream');
      expect(freshData['url'].toString().startsWith('https://'), isTrue);

      // Verify cache was updated with the fresh stream
      final cachedEntry = box.get(testVideoId) as Map;
      expect(cachedEntry['url'], equals(freshData['url']));
    });
  });
}