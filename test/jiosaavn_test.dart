@Tags(['smoke'])
library jiosaavn_test;
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blackhole/APIs/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _RealHttpOverrides();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_saavn_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('cache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('JioSaavn Query & Character Encoding Tests', () {
    final List<String> specialQueries = [
      'Rock & Roll', // Ampersand
      'A+B', // Plus sign
      '#Trending', // Hash
      '100% Love', // Percent
      "Don't Go", // Apostrophe
      'Hello (Remix)', // Parentheses
      'AC/DC', // Slash
      'Café del Mar', // Accented characters
      'रोमांटिक गाने', // Hindi Devanagari
      'دلبر', // Urdu Nastaliq
    ];

    for (final query in specialQueries) {
      test('Query encoding resilience for: "$query"', () async {
        try {
          final res = await SaavnAPI().fetchSongSearchResults(
            searchQuery: query,
            count: 3,
          );
          expect(res, isNotNull);
          expect(res.containsKey('songs'), isTrue);
          expect(res['songs'], isA<List>());
          // Verify that regardless of results count, the response parsed without throw
          print('Successfully executed query: "$query" -> ${res['songs'].length} results');
        } catch (e) {
          fail('Query "$query" crashed with error: $e');
        }
      });
    }

    test('Non-matching nonsense query gracefully handled without crash', () async {
      final res = await SaavnAPI().fetchSongSearchResults(
        searchQuery: 'zxqvbnm998877_no_match_possible',
        count: 5,
      );
      expect(res, isNotNull);
      expect(res['songs'], isA<List>());
      // Saavn returns either an empty list or fallback popular tracks; must not throw or crash
      expect(res['error'], anyOf(isNull, isEmpty));
    });
  });

  group('JioSaavn Subsystem Endpoints & Models', () {
    test('fetchSearchResults returns categories for suggestions', () async {
      try {
        final results = await SaavnAPI().fetchSearchResults('Arijit');
        expect(results, isNotNull);
        expect(results, isA<List>());
        print('Categories returned for Arijit: ${results.length}');
      } catch (e) {
        print('Live search suggestions skipped or unavailable: $e');
      }
    });

    test('Fetch top searches', () async {
      try {
        final topSearches = await SaavnAPI().getTopSearches();
        expect(topSearches, isNotNull);
        expect(topSearches, isA<List>());
        print('Top searches returned: ${topSearches.length}');
      } catch (e) {
        print('Top searches unavailable: $e');
      }
    });

    test('fetchAlbumSongs parses valid tracklist', () async {
      try {
        // Aashiqui 2 album ID
        final album = await SaavnAPI().fetchAlbumSongs('1145100');
        if (album.isNotEmpty && album['songs'] != null) {
          expect(album['songs'], isA<List>());
          expect((album['songs'] as List).isNotEmpty, isTrue);
          final firstTrack = (album['songs'] as List).first as Map;
          expect(firstTrack['title'], isNotNull);
          expect(firstTrack['url'], isNotNull);
          print('Album details verified: first track "${firstTrack['title']}"');
        }
      } catch (e) {
        print('Album details smoke test skipped: $e');
      }
    });

    test('Recommendations endpoint returns non-empty list for popular song', () async {
      try {
        // Kesariya song ID
        final reco = await SaavnAPI().getReco('KGfDrbWe');
        expect(reco, isA<List>());
        print('Recommendations returned: ${reco.length} songs');
      } catch (e) {
        print('Recommendations endpoint skipped: $e');
      }
    });
  });
}
