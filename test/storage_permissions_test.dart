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

import 'dart:io';

import 'package:blackhole/Helpers/audio_query.dart';
import 'package:blackhole/Services/ext_storage_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getExternalStoragePath() async =>
      '${Directory.systemTemp.path}/Android/data/com.shadow.blackhole/files';

  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = FakePathProviderPlatform();

  group('Storage & Permissions - Path and Fallback Resolution', () {
    test('ExtStorageProvider getExtStorage returns a valid fallback directory',
        () async {
      final String? path = await ExtStorageProvider.getExtStorage(
        dirName: 'Music',
        writeAccess: false,
      );
      expect(path, isNotNull);
      expect(path!.isNotEmpty, isTrue);
      expect(path, isNot(equals('/')));
    });

    test('queryNSave safely handles null/empty artwork without 0-byte files',
        () async {
      final Directory tempDir =
          await Directory.systemTemp.createTemp('artwork_test_');
      try {
        final String savedPath = await OfflineAudioQuery.queryNSave(
          id: -99999,
          type: ArtworkType.AUDIO,
          tempPath: tempDir.path,
          fileName: 'non_existent_art',
        );

        expect(savedPath, isEmpty);
        final File expectedFile = File('${tempDir.path}/non_existent_art.png');
        expect(await expectedFile.exists(), isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('Storage & Permissions - Local Media SongModel Null Safety', () {
    test('SongModel filter accepts songs with null isMusic without crashing',
        () {
      final SongModel nullTypesSong = SongModel({
        '_id': 101,
        'title': 'Test Song',
        'artist': 'Test Artist',
        'album': 'Test Album',
        'duration': 180000,
        '_data': '/storage/emulated/0/Music/test.mp3',
        'is_music': null,
        'is_podcast': null,
        'is_audiobook': null,
      });

      final SongModel explicitMusicSong = SongModel({
        '_id': 102,
        'title': 'Explicit Music',
        'artist': 'Test Artist',
        'album': 'Test Album',
        'duration': 240000,
        '_data': '/storage/emulated/0/Music/music.mp3',
        'is_music': true,
        'is_podcast': false,
        'is_audiobook': false,
      });

      final SongModel ringtoneSong = SongModel({
        '_id': 103,
        'title': 'Ringtone',
        'artist': 'Test Artist',
        'album': 'Ringtones',
        'duration': 15000,
        '_data': '/storage/emulated/0/Ringtones/ring.mp3',
        'is_music': false,
        'is_podcast': false,
        'is_audiobook': false,
      });

      final List<SongModel> rawList = [
        nullTypesSong,
        explicitMusicSong,
        ringtoneSong,
      ];

      final filtered = rawList.where((i) {
        final durationMatch = (i.duration ?? 60000) > 1000 * 10;
        final typeMatch = (i.isMusic ?? false) ||
            (i.isPodcast ?? false) ||
            (i.isAudioBook ?? false) ||
            (i.isMusic == null && i.isPodcast == null && i.isAudioBook == null);
        return durationMatch && typeMatch;
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.map((s) => s.id).toList(), containsAll([101, 102]));
      expect(filtered.map((s) => s.id).toList(), isNot(contains(103)));
    });

    test(
        'Data path folder splitting safely handles paths with or without subfolders',
        () {
      const String deepPath = '/storage/emulated/0/Music/Rock/Classic/song.mp3';
      final segments = deepPath.split('/');
      if (segments.length > 1) {
        segments.removeLast();
      }
      final folderPath = segments.join('/');
      expect(folderPath, equals('/storage/emulated/0/Music/Rock/Classic'));

      const String rootFile = 'song.mp3';
      final rootSegments = rootFile.split('/');
      if (rootSegments.length > 1) {
        rootSegments.removeLast();
      }
      expect(rootSegments.join('/'), equals('song.mp3'));
    });
  });
}
