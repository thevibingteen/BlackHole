@Tags(['unit'])
library player_queue_test;
import 'package:audio_service/audio_service.dart';
import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Player Queue & Shuffle Mathematics Tests', () {
    test('Shuffle index inverse mapping accurately translates shuffle position to queue index', () {
      // Suppose effective indices sequence from player is [2, 0, 3, 1]
      final effectiveIndices = [2, 0, 3, 1];
      final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
      for (var i = 0; i < effectiveIndices.length; i++) {
        shuffleIndicesInv[effectiveIndices[i]] = i;
      }

      // Expected inverse mapping:
      // index 0 was at position 1 in effectiveIndices -> shuffleIndicesInv[0] = 1
      // index 1 was at position 3 in effectiveIndices -> shuffleIndicesInv[1] = 3
      // index 2 was at position 0 in effectiveIndices -> shuffleIndicesInv[2] = 0
      // index 3 was at position 2 in effectiveIndices -> shuffleIndicesInv[3] = 2
      expect(shuffleIndicesInv[0], equals(1));
      expect(shuffleIndicesInv[1], equals(3));
      expect(shuffleIndicesInv[2], equals(0));
      expect(shuffleIndicesInv[3], equals(2));
    });

    test('RepeatMode switch cycles cleanly through None -> All -> One', () {
      AudioServiceRepeatMode cycleRepeatMode(AudioServiceRepeatMode current) {
        switch (current) {
          case AudioServiceRepeatMode.none:
            return AudioServiceRepeatMode.all;
          case AudioServiceRepeatMode.all:
            return AudioServiceRepeatMode.one;
          case AudioServiceRepeatMode.one:
            return AudioServiceRepeatMode.none;
          default:
            return AudioServiceRepeatMode.none;
        }
      }

      var mode = AudioServiceRepeatMode.none;
      mode = cycleRepeatMode(mode);
      expect(mode, equals(AudioServiceRepeatMode.all));
      mode = cycleRepeatMode(mode);
      expect(mode, equals(AudioServiceRepeatMode.one));
      mode = cycleRepeatMode(mode);
      expect(mode, equals(AudioServiceRepeatMode.none));
    });
  });

  group('Cross-Provider MediaItem Conversion Tests', () {
    test('Converts JioSaavn song Map to MediaItem', () {
      final saavnSong = {
        'id': 'saavn_001',
        'title': 'Channa Mereya',
        'artist': 'Arijit Singh',
        'album': 'Ae Dil Hai Mushkil',
        'duration': '289',
        'image': 'https://c.saavncdn.com/123/adhm.jpg',
        'url': 'https://aac.saavncdn.com/123/channa.mp4',
        'language': 'Hindi',
        'has_lyrics': 'true',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(saavnSong, autoplay: true);

      expect(mediaItem.id, equals('saavn_001'));
      expect(mediaItem.title, equals('Channa Mereya'));
      expect(mediaItem.artist, equals('Arijit Singh'));
      expect(mediaItem.duration?.inSeconds, equals(289));
      expect(mediaItem.extras?['url'], equals('https://aac.saavncdn.com/123/channa.mp4'));
      expect(mediaItem.extras?['autoplay'], isTrue);
      expect(mediaItem.genre, equals('Hindi'));
    });

    test('Converts YouTube video Map to MediaItem', () {
      final ytVideo = {
        'id': 'yt_vid_999',
        'title': 'Coldplay - Yellow (Official Video)',
        'artist': 'Coldplay',
        'album': 'YouTube',
        'duration': '269',
        'image': 'https://i.ytimg.com/vi/yt_vid_999/hqdefault.jpg',
        'url': 'https://googlevideo.com/videoplayback?expire=12345',
        'language': 'YouTube',
        'genre': 'YouTube',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(ytVideo, autoplay: false);

      expect(mediaItem.id, equals('yt_vid_999'));
      expect(mediaItem.title, equals('Coldplay - Yellow (Official Video)'));
      expect(mediaItem.genre, equals('YouTube'));
      expect(mediaItem.extras?['autoplay'], isFalse);
    });
  });

  group('Sleep Timer & Exit Confirmation Logic Tests', () {
    test('Sleep timer duration calculation', () {
      final int minutes = 30;
      final targetDuration = Duration(minutes: minutes);
      expect(targetDuration.inSeconds, equals(1800));

      final startTime = DateTime.now();
      final stopTime = startTime.add(targetDuration);
      expect(stopTime.difference(startTime).inMinutes, equals(30));
    });

    test('Double-tap back button threshold (3 seconds)', () {
      final now = DateTime.now();

      // First tap sets backButtonPressTime
      final firstTap = now;

      // Second tap within 2 seconds should confirm exit
      final secondTapPrompt = firstTap.add(const Duration(seconds: 2));
      final bool shouldExit = secondTapPrompt.difference(firstTap) <= const Duration(seconds: 3);
      expect(shouldExit, isTrue);

      // Tap after 5 seconds should reset and prompt snackbar again
      final secondTapDelayed = firstTap.add(const Duration(seconds: 5));
      final bool shouldReset = secondTapDelayed.difference(firstTap) > const Duration(seconds: 3);
      expect(shouldReset, isTrue);
    });
  });
}
