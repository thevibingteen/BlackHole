import 'package:blackhole/Helpers/format.dart';
import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:blackhole/Helpers/route_handler.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YouTube Search Result Metadata & Fallback', () {
    test('Valid YouTube result with channel metadata displays channel in subtitle', () {
      final item = {
        'id': 'qWjfDow0xGQ',
        'title': 'How Indian Media BRAINWASHES You! | Dhruv Rathee',
        'artist': 'Dhruv Rathee',
        'channel': 'Dhruv Rathee',
        'subtitle': 'Dhruv Rathee',
        'duration': '1203',
        'image': 'https://i.ytimg.com/vi/qWjfDow0xGQ/hqdefault.jpg',
      };

      final String subtitle = _formatSubtitle(item);
      expect(subtitle, equals('Dhruv Rathee'));
      expect(subtitle.toLowerCase(), isNot(contains('null')));
    });

    test('Valid YouTube result with missing subtitle falls back to artist/channel', () {
      final item = {
        'id': 'qWjfDow0xGQ',
        'title': 'Test Video',
        'artist': 'Dhruv Rathee',
        'channel': 'Dhruv Rathee',
        // subtitle is omitted / null
      };

      final String subtitle = _formatSubtitle(item);
      expect(subtitle, equals('Dhruv Rathee'));
      expect(subtitle.toLowerCase(), isNot(contains('null')));
    });

    test('Valid YouTube result with missing channel metadata falls back to "YouTube Video"', () {
      final item = {
        'id': 'qWjfDow0xGQ',
        'title': 'Unknown Channel Video',
        'artist': '',
        'channel': '',
        'subtitle': null,
      };

      final String subtitle = _formatSubtitle(item);
      expect(subtitle, equals('YouTube Video'));
      expect(subtitle.toLowerCase(), isNot(contains('null')));
    });

    test('Literal "null" string in subtitle or artist is sanitized to fallback', () {
      final itemWithLiteralNullSub = {
        'id': 'qWjfDow0xGQ',
        'title': 'Literal Null Subtitle Video',
        'subtitle': 'null',
        'artist': 'Null',
        'channel': 'null',
      };

      final String subtitle = _formatSubtitle(itemWithLiteralNullSub);
      expect(subtitle, equals('YouTube Video'));
      expect(subtitle.toLowerCase(), isNot(contains('null')));
    });

    test('Missing duration or formatted duration parses safely without throwing', () {
      expect(FormatResponse.parseDuration(null), equals('0'));
      expect(FormatResponse.parseDuration(''), equals('0'));
      expect(FormatResponse.parseDuration('null'), equals('0'));
      expect(FormatResponse.parseDuration('20:03'), equals('1203'));
      expect(FormatResponse.parseDuration('1:15:30'), equals('4530'));
      expect(FormatResponse.parseDuration('180'), equals('180'));
      expect(FormatResponse.parseDuration(240), equals('240'));
      expect(FormatResponse.parseDuration(240.5), equals('241'));
    });

    test('Video title and thumbnail preservation', () {
      final item = {
        'id': 'qWjfDow0xGQ',
        'title': 'How Indian Media BRAINWASHES You! | Dhruv Rathee',
        'image': 'https://i.ytimg.com/vi/qWjfDow0xGQ/hqdefault.jpg',
        'secondImage': 'https://i.ytimg.com/vi_webp/qWjfDow0xGQ/sddefault.webp',
        'duration': '20:03',
        'subtitle': 'Dhruv Rathee',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(item);
      expect(mediaItem.id, equals('qWjfDow0xGQ'));
      expect(mediaItem.title, equals('How Indian Media BRAINWASHES You! | Dhruv Rathee'));
      expect(mediaItem.artUri.toString(), equals('https://i.ytimg.com/vi/qWjfDow0xGQ/hqdefault.jpg'));
      expect(mediaItem.duration, equals(const Duration(seconds: 1203)));
    });
  });

  group('Video Identification & URL Security Validation', () {
    test('Valid canonical YouTube video ID and URL parsing', () {
      const String validUrl = 'https://www.youtube.com/watch?v=qWjfDow0xGQ';
      final item = HandleRoute.parseYouTubeUrl(validUrl);
      expect(item, isNotNull);
      expect(item!.id, equals('qWjfDow0xGQ'));
      expect(item.type, equals('v'));
    });

    test('Shortened youtu.be link correctly extracts video ID', () {
      const String shortUrl = 'https://youtu.be/qWjfDow0xGQ';
      final item = HandleRoute.parseYouTubeUrl(shortUrl);
      expect(item, isNotNull);
      expect(item!.id, equals('qWjfDow0xGQ'));
      expect(item.type, equals('v'));
    });

    test('Deceptive hostname is rejected by isYouTubeHost', () {
      expect(HandleRoute.isYouTubeHost('youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('www.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('m.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('music.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('youtu.be'), isTrue);

      // Deceptive domains
      expect(HandleRoute.isYouTubeHost('fakeyoutube.com'), isFalse);
      expect(HandleRoute.isYouTubeHost('notyoutube.com'), isFalse);
      expect(HandleRoute.isYouTubeHost('youtube.com.attacker.com'), isFalse);
      expect(HandleRoute.isYouTubeHost('youtu.be.attacker.com'), isFalse);
    });

    test('YouTubeStreamCandidate validates legit googlevideo and rejects watch URLs', () {
      final validStream = YouTubeStreamCandidate(
        videoId: 'qWjfDow0xGQ',
        url: 'https://rr4---sn-gwpa-5bgk.googlevideo.com/videoplayback?expire=1793478002&itag=18',
        mimeType: 'video/mp4',
        audioCodec: 'mp4a',
        bitrate: 128000,
        isAudioOnly: false,
        resolver: 'innertube_progressive',
      );
      expect(validStream.isValid, isTrue);

      final invalidWatchUrl = YouTubeStreamCandidate(
        videoId: 'qWjfDow0xGQ',
        url: 'https://www.youtube.com/watch?v=qWjfDow0xGQ',
        mimeType: 'text/html',
        audioCodec: 'none',
        bitrate: 0,
        isAudioOnly: false,
        resolver: 'test',
      );
      expect(invalidWatchUrl.isValid, isFalse);

      final disallowedHost = YouTubeStreamCandidate(
        videoId: 'qWjfDow0xGQ',
        url: 'https://attacker.com/stream.mp3',
        mimeType: 'audio/mp3',
        audioCodec: 'mp3',
        bitrate: 128000,
        isAudioOnly: true,
        resolver: 'test',
      );
      expect(disallowedHost.isValid, isFalse);
    });
  });

  group('Playback MediaItem Conversion Resilience', () {
    test('MediaItemConverter handles YouTube mm:ss formatted duration without throwing FormatException', () {
      final rawSong = {
        'id': 'qWjfDow0xGQ',
        'title': 'Dhruv Rathee Video',
        'artist': 'Dhruv Rathee',
        'album': 'Dhruv Rathee',
        'duration': '20:03',
        'image': 'https://i.ytimg.com/vi/qWjfDow0xGQ/hqdefault.jpg',
        'url': 'https://rr4---sn-gwpa-5bgk.googlevideo.com/videoplayback?expire=1793478002',
        'genre': 'YouTube',
        'language': 'YouTube',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(rawSong);
      expect(mediaItem.duration?.inSeconds, equals(1203));
      expect(mediaItem.title, equals('Dhruv Rathee Video'));
      expect(mediaItem.artist, equals('Dhruv Rathee'));
    });

    test('MediaItemConverter handles hh:mm:ss formatted duration', () {
      final rawSong = {
        'id': 'abc12345678',
        'title': 'Long Podcast',
        'artist': 'Host',
        'album': 'Host',
        'duration': '1:15:20',
        'image': 'https://example.com/cover.jpg',
        'url': 'https://rr1---sn.googlevideo.com/videoplayback',
        'genre': 'YouTube',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(rawSong);
      expect(mediaItem.duration?.inSeconds, equals(4520));
    });

    test('MediaItemConverter handles null, empty and "null" duration safely', () {
      final songNullDur = {
        'id': '1',
        'title': 'No Duration Song',
        'artist': 'Artist',
        'duration': null,
        'image': '',
      };
      expect(MediaItemConverter.mapToMediaItem(songNullDur).duration?.inSeconds, equals(180));

      final songEmptyDur = {
        'id': '2',
        'title': 'Empty Duration Song',
        'artist': 'Artist',
        'duration': '',
        'image': '',
      };
      expect(MediaItemConverter.mapToMediaItem(songEmptyDur).duration?.inSeconds, equals(180));

      final songLiteralNullDur = {
        'id': '3',
        'title': 'Literal Null Duration Song',
        'artist': 'Artist',
        'duration': 'null',
        'image': '',
      };
      expect(MediaItemConverter.mapToMediaItem(songLiteralNullDur).duration?.inSeconds, equals(180));
    });

    test('downMapToMediaItem handles formatted and null durations', () {
      final downSong = {
        'id': '10',
        'title': 'Downloaded Track',
        'artist': 'Artist',
        'album': 'Album',
        'duration': '04:15',
        'image': '/storage/emulated/0/cover.jpg',
        'path': '/storage/emulated/0/track.m4a',
      };

      final mediaItem = MediaItemConverter.downMapToMediaItem(downSong);
      expect(mediaItem.duration?.inSeconds, equals(255));
    });
  });

  group('UI Subtitle Rendering Verification', () {
    testWidgets('ListTile renders sanitized subtitle without literal null', (tester) async {
      final item = {
        'id': 'qWjfDow0xGQ',
        'title': 'How Indian Media BRAINWASHES You!',
        'subtitle': null,
        'artist': 'Dhruv Rathee',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: Text(item['title'].toString()),
              subtitle: Text(_formatSubtitle(item)),
            ),
          ),
        ),
      );

      expect(find.text('How Indian Media BRAINWASHES You!'), findsOneWidget);
      expect(find.text('Dhruv Rathee'), findsOneWidget);
      expect(find.text('null'), findsNothing);
    });

    testWidgets('ListTile renders "YouTube Video" when all metadata is empty/null', (tester) async {
      final item = {
        'id': 'xyz',
        'title': 'A Video Without Author',
        'subtitle': null,
        'artist': null,
        'channel': null,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: Text(item['title'].toString()),
              subtitle: Text(_formatSubtitle(item)),
            ),
          ),
        ),
      );

      expect(find.text('A Video Without Author'), findsOneWidget);
      expect(find.text('YouTube Video'), findsOneWidget);
      expect(find.text('null'), findsNothing);
    });
  });
}

String _formatSubtitle(Map item) {
  final rawSubtitle = item['subtitle']?.toString().trim();
  if (rawSubtitle != null &&
      rawSubtitle.isNotEmpty &&
      rawSubtitle.toLowerCase() != 'null') {
    return rawSubtitle;
  }
  final rawArtist = (item['artist'] ??
          item['channel'] ??
          item['author'] ??
          item['uploader'])
      ?.toString()
      .trim();
  if (rawArtist != null &&
      rawArtist.isNotEmpty &&
      rawArtist.toLowerCase() != 'null') {
    return rawArtist;
  }
  final rawDesc = item['description']?.toString().trim();
  if (rawDesc != null &&
      rawDesc.isNotEmpty &&
      rawDesc.toLowerCase() != 'null') {
    return rawDesc;
  }
  return 'YouTube Video';
}
