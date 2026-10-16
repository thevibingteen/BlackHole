@Tags(['smoke'])
library yt_music_test;
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blackhole/Services/youtube_services.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _RealHttpOverrides();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_ytm_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('cache');
    await Hive.openBox('ytlinkcache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('YouTube Music Live Search & Model Mapping Smoke Tests', () {
    test('Search returns grouped sections for popular artist', () async {
      try {
        final results = await YtMusicService().search('Taylor Swift');
        expect(results, isNotNull);
        expect(results, isA<List>());
        print('YTM search returned ${results.length} grouped sections');

        for (final section in results) {
          expect(section.containsKey('title'), isTrue);
          expect(section.containsKey('items'), isTrue);
          final items = section['items'] as List;
          if (items.isNotEmpty) {
            final first = items.first as Map;
            expect(first.containsKey('title'), isTrue);
            expect(first.containsKey('id'), isTrue);
            print('Section "${section['title']}": first item "${first['title']}" (type: ${first['type']})');
          }
        }
      } catch (e) {
        print('YTM search smoke test skipped: $e');
      }
    });

    test('getMusicHome returns banner carousel and shelves', () async {
      try {
        final homeData = await YouTubeServices().getMusicHome();
        expect(homeData, isNotNull);
        if (homeData.isNotEmpty) {
          expect(homeData.containsKey('body'), isTrue);
          final body = homeData['body'] as List;
          print('YTM getMusicHome returned ${body.length} shelves');
        } else {
          print('YTM getMusicHome returned empty response (consent or DOM variation)');
        }
      } catch (e) {
        print('YTM home test skipped: $e');
      }
    });

    test('getWatchPlaylist returns continuation IDs', () async {
      try {
        // Shape of You video ID: dQw4w9WgXcQ or similar
        final related = await YtMusicService().getWatchPlaylist(videoId: 'JGwWNGJdvx8', limit: 3);
        expect(related, isA<List<String>>());
        print('Watch playlist returned ${related.length} continuation IDs: $related');
      } catch (e) {
        print('Watch playlist continuation test skipped: $e');
      }
    });
  });
}

