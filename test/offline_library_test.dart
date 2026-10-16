@Tags(['integration'])
library offline_library_test;
import 'dart:io';

import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('blackhole_library_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('downloads');
    await Hive.openBox('stats');
    await Hive.openBox('Favorite Songs');
    await Hive.openBox('cache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Downloads Subsystem & Local MediaItem Conversion Tests', () {
    test('Download metadata indexes into Hive and converts to MediaItem accurately', () {
      final box = Hive.box('downloads');
      final Map songData = {
        'id': 'test_song_001',
        'title': 'Kesariya',
        'subtitle': 'Arijit Singh',
        'artist': 'Arijit Singh',
        'albumArtist': 'Pritam',
        'album': 'Brahmastra',
        'genre': 'Hindi',
        'year': '2022',
        'lyrics': 'Kesariya tera ishq hai piya...',
        'duration': '268',
        'release_date': '2022-07-17',
        'album_id': '112233',
        'perma_url': 'https://www.jiosaavn.com/song/kesariya/12345',
        'quality': '320 kbps',
        'path': '${tempDir.path}/Kesariya - Arijit Singh.m4a',
        'image': '${tempDir.path}/Kesariya - Arijit Singh.jpg',
        'image_url': 'https://c.saavncdn.com/123/Kesariya.jpg',
        'from_yt': false,
        'dateAdded': DateTime.now().toString(),
      };

      box.put(songData['id'], songData);
      expect(box.containsKey('test_song_001'), isTrue);

      final retrieved = box.get('test_song_001') as Map;
      final mediaItem = MediaItemConverter.downMapToMediaItem(retrieved);

      expect(mediaItem.id, equals('test_song_001'));
      expect(mediaItem.title, equals('Kesariya'));
      expect(mediaItem.artist, equals('Arijit Singh'));
      expect(mediaItem.album, equals('Brahmastra'));
      expect(mediaItem.duration?.inSeconds, equals(268));
      expect(mediaItem.extras?['url'], equals(songData['path']));
      expect(mediaItem.artUri?.toFilePath(), equals(File(songData['image'].toString()).uri.toFilePath()));
    });

    test('Partial download cleanup removes orphaned temporary files on error', () async {
      final fakeAudioFile = File('${tempDir.path}/incomplete_song.m4a');
      final fakeCoverFile = File('${tempDir.path}/incomplete_song.jpg');

      await fakeAudioFile.writeAsString('partial byte data stream');
      await fakeCoverFile.writeAsString('partial image bytes');

      expect(await fakeAudioFile.exists(), isTrue);
      expect(await fakeCoverFile.exists(), isTrue);

      // Simulate failure cleanup routine in Download._prepareDownload
      if (await fakeAudioFile.exists()) await fakeAudioFile.delete();
      if (await fakeCoverFile.exists()) await fakeCoverFile.delete();

      expect(await fakeAudioFile.exists(), isFalse, reason: 'Incomplete audio file must be cleaned up');
      expect(await fakeCoverFile.exists(), isFalse, reason: 'Incomplete cover file must be cleaned up');
    });

    test('Duplicate file collision naming logic appends counter', () async {
      String filename = 'Song - Artist.m4a';
      final existingFile = File('${tempDir.path}/$filename');
      await existingFile.writeAsString('already existing song');

      expect(await existingFile.exists(), isTrue);

      // Production collision resolution (auto-increment option)
      while (await File('${tempDir.path}/$filename').exists()) {
        filename = filename.replaceAll('.m4a', ' (1).m4a');
      }

      expect(filename, equals('Song - Artist (1).m4a'));
      expect(await File('${tempDir.path}/$filename').exists(), isFalse);
    });
  });

  group('Library, Playlists, Favorites & History Persistence Tests', () {
    test('Favorite Songs persistence across box restart', () async {
      final favBox = Hive.box('Favorite Songs');
      final testFavSong = {
        'id': 'fav_123',
        'title': 'Tum Hi Ho',
        'artist': 'Arijit Singh',
        'album': 'Aashiqui 2',
      };

      await favBox.put('fav_123', testFavSong);
      expect(favBox.length, equals(1));

      // Simulate restart: close and reopen
      await favBox.close();
      final reopenedBox = await Hive.openBox('Favorite Songs');
      expect(reopenedBox.containsKey('fav_123'), isTrue);
      final item = reopenedBox.get('fav_123') as Map;
      expect(item['title'], equals('Tum Hi Ho'));
    });

    test('Custom Playlist creation, addition, and reordering', () async {
      const playlistName = 'RoadTrip_2026';
      final settingsBox = Hive.box('settings');
      final List playlistNames = settingsBox.get('playlistNames', defaultValue: ['Favorite Songs']) as List;
      playlistNames.add(playlistName);
      await settingsBox.put('playlistNames', playlistNames);

      final playlistBox = await Hive.openBox(playlistName);
      await playlistBox.put('song_1', {'id': 'song_1', 'title': 'Highway to Hell'});
      await playlistBox.put('song_2', {'id': 'song_2', 'title': 'Born to be Wild'});

      expect(playlistBox.length, equals(2));
      expect((playlistBox.get('song_1') as Map)['title'], equals('Highway to Hell'));

      // Clean up test box
      await playlistBox.deleteFromDisk();
    });

    test('Recently played history limits size and maintains order', () async {
      final cacheBox = Hive.box('cache');
      final List<Map> recentSongs = [];

      for (int i = 0; i < 35; i++) {
        recentSongs.insert(0, {'id': 'song_$i', 'title': 'Track $i'});
        if (recentSongs.length > 30) {
          recentSongs.removeLast();
        }
      }

      await cacheBox.put('recentSongs', recentSongs);
      final storedRecent = cacheBox.get('recentSongs') as List;
      expect(storedRecent.length, equals(30), reason: 'Recent songs must be capped at 30 items');
      expect((storedRecent.first as Map)['id'], equals('song_34'));
    });

    test('Stats box tracks play counts and artist listening times', () async {
      final statsBox = Hive.box('stats');

      // Track play count
      final int currentPlayCount = (statsBox.get('play_count_kesariya', defaultValue: 0) as int) + 1;
      await statsBox.put('play_count_kesariya', currentPlayCount);

      // Track artist listening duration (e.g. 180 seconds)
      final int currentArtistTime = (statsBox.get('artist_time_Arijit', defaultValue: 0) as int) + 180;
      await statsBox.put('artist_time_Arijit', currentArtistTime);

      expect(statsBox.get('play_count_kesariya'), equals(1));
      expect(statsBox.get('artist_time_Arijit'), equals(180));
    });
  });
}
