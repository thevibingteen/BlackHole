// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blackhole/Helpers/lyrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  HttpOverrides.global = _RealHttpOverrides();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_lyrics_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Lyrics Service Tests', () {
    test('Fetch lyrics through Lyrics.getLyrics pipeline', () async {
      final res = await Lyrics.getLyrics(
        id: 'KGfDrbWe',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        saavnHas: true,
      );

      print('Pipeline result source: ${res["source"]}, type: ${res["type"]}');
      expect(res, isNotNull);
      expect(res['lyrics'], isNotEmpty, reason: 'Lyrics should not be empty');
      expect(res['type'], isIn(['lrc', 'text']));
      expect(res['source'], isNotEmpty);
      print('Full Lyrics pipeline test passed! Source: ${res["source"]} (${res["type"]})');
    });

    test('Fetch Saavn lyrics directly', () async {
      final lyrics = await Lyrics.getSaavnLyrics('50325493');
      expect(lyrics, isNotNull);
      print('Saavn lyrics test completed (length: ${lyrics.length})');
    });
  });
}
