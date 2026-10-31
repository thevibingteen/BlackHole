/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_parser/http_parser.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 8 - Local Compatibility Fork: receive_sharing_intent', () {
    test('SharedMediaFile parses JSON and handles null/empty fields safely', () {
      final jsonMap = {
        'path': '/storage/emulated/0/Download/test.json',
        'type': 2, // FILE
        'thumbnail': null,
        'duration': null,
      };

      final mediaFile = SharedMediaFile.fromJson(jsonMap);
      expect(mediaFile.path, equals('/storage/emulated/0/Download/test.json'));
      expect(mediaFile.type, equals(SharedMediaType.FILE));
      expect(mediaFile.thumbnail, isNull);
      expect(mediaFile.duration, isNull);
    });

    test('SharedMediaFile correctly maps IMAGE and VIDEO types', () {
      final imageMap = {
        'path': '/storage/emulated/0/Download/cover.jpg',
        'type': 0, // IMAGE
      };
      final videoMap = {
        'path': '/storage/emulated/0/Download/clip.mp4',
        'type': 1, // VIDEO
      };

      expect(SharedMediaFile.fromJson(imageMap).type, equals(SharedMediaType.IMAGE));
      expect(SharedMediaFile.fromJson(videoMap).type, equals(SharedMediaType.VIDEO));
    });

    test('JSON decoding of media list handles empty or malformed strings gracefully', () {
      List<SharedMediaFile> parseMediaJson(String? data) {
        if (data == null || data.trim().isEmpty) return [];
        try {
          final decoded = jsonDecode(data);
          if (decoded is List) {
            return decoded
                .whereType<Map>()
                .map(
                  (item) => SharedMediaFile.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList();
          }
        } catch (_) {}
        return [];
      }

      expect(parseMediaJson(null), isEmpty);
      expect(parseMediaJson(''), isEmpty);
      expect(parseMediaJson('[]'), isEmpty);
      expect(parseMediaJson('not valid json'), isEmpty);

      final validJson = jsonEncode([
        {'path': '/path/file1.mp3', 'type': 2},
        {'path': '/path/file2.mp3', 'type': 2},
      ]);
      final files = parseMediaJson(validJson);
      expect(files.length, equals(2));
      expect(files[0].path, equals('/path/file1.mp3'));
    });
  });

  group('Batch 8 - Local Compatibility Fork: material_design_icons_flutter', () {
    test('MdiIcons constants have correct font family and non-zero codePoints', () {
      const icon = MdiIcons.music;
      expect(icon.fontFamily, equals('Material Design Icons'));
      expect(icon.fontPackage, equals('material_design_icons_flutter'));
      expect(icon.codePoint, isPositive);

      const playIcon = MdiIcons.play;
      expect(playIcon.fontFamily, equals('Material Design Icons'));
      expect(playIcon.codePoint, isPositive);

      const heartIcon = MdiIcons.heart;
      expect(heartIcon.fontFamily, equals('Material Design Icons'));
      expect(heartIcon.codePoint, isPositive);
    });
  });

  group('Batch 8 - Pinned Remote Dependencies Integrity', () {
    test('Pinned collection package (1.17.1) provides expected extension methods', () {
      final list = [1, 2, 3, 4, 5];
      final found = list.firstWhereOrNull((element) => element > 3);
      expect(found, equals(4));

      final notFound = list.firstWhereOrNull((element) => element > 10);
      expect(notFound, isNull);

      const equality = ListEquality();
      expect(equality.equals([1, 2], [1, 2]), isTrue);
      expect(equality.equals([1, 2], [2, 1]), isFalse);
    });

    test('Pinned http_parser package (4.0.2) parses media types and headers correctly', () {
      final mediaType = MediaType.parse('audio/mpeg; charset=utf-8');
      expect(mediaType.type, equals('audio'));
      expect(mediaType.subtype, equals('mpeg'));
      expect(mediaType.parameters['charset'], equals('utf-8'));

      final jsonType = MediaType.parse('application/json');
      expect(jsonType.mimeType, equals('application/json'));
    });
  });
}
