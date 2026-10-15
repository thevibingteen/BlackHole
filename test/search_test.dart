// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blackhole/APIs/api.dart';
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
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('JioSaavn API Tests', () {
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

  group('YouTube Explode API Tests', () {
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
  });
}
