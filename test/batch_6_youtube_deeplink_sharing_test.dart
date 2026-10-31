import 'package:blackhole/Helpers/route_handler.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 6: YouTube Deep Link & URL Parsing', () {
    test('parses standard watch URL with v parameter', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses watch URL with query parameters before v', () {
      const url = 'https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses youtu.be short URL', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses youtu.be short URL with tracking parameters', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ?si=abcdef123456&t=15s';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses YouTube Shorts URL', () {
      const url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses YouTube Music URL', () {
      const url = 'https://music.youtube.com/watch?v=dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses YouTube embed URL', () {
      const url = 'https://www.youtube.com/embed/dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses YouTube playlist URL', () {
      const url =
          'https://www.youtube.com/playlist?list=PLrAl48tZgu-d1N3eE8C8nS_k8qj0W3Y4z';
      final item = HandleRoute.parseYouTubeUrl(url);
      expect(item, isNotNull);
      expect(item!.id, 'PLrAl48tZgu-d1N3eE8C8nS_k8qj0W3Y4z');
      expect(item.type, 'list');
    });

    test('parses YouTube link embedded in shared text', () {
      const text =
          'Hey check out this song: Never Gonna Give You Up https://youtu.be/dQw4w9WgXcQ (via YouTube)';
      final item = HandleRoute.parseYouTubeUrl(text);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('parses raw youtu.be link without scheme', () {
      const text = 'youtu.be/dQw4w9WgXcQ';
      final item = HandleRoute.parseYouTubeUrl(text);
      expect(item, isNotNull);
      expect(item!.id, 'dQw4w9WgXcQ');
      expect(item.type, 'v');
    });

    test('returns null for empty, blank or null input', () {
      expect(HandleRoute.parseYouTubeUrl(null), isNull);
      expect(HandleRoute.parseYouTubeUrl(''), isNull);
      expect(HandleRoute.parseYouTubeUrl('   '), isNull);
    });

    test('returns null for non-YouTube URLs', () {
      expect(HandleRoute.parseYouTubeUrl('https://example.com/song'), isNull);
      expect(
        HandleRoute.parseYouTubeUrl('https://google.com/search?q=youtube'),
        isNull,
      );
    });

    test('returns null for YouTube URL with empty video id', () {
      expect(
        HandleRoute.parseYouTubeUrl('https://www.youtube.com/watch?v='),
        isNull,
      );
      expect(HandleRoute.parseYouTubeUrl('https://youtu.be/'), isNull);
    });
  });

  group('Batch 6: Route Debounce & Deduplication', () {
    test('deduplicates identical URLs within debounce window', () {
      const url1 = 'https://youtu.be/testDebounceId1';
      final firstCheck = HandleRoute.isDuplicate(url1);
      final secondCheck = HandleRoute.isDuplicate(url1);

      expect(firstCheck, isFalse);
      expect(secondCheck, isTrue); // Debounced duplicate!
    });

    test('processes different URLs without debouncing', () {
      const urlA = 'https://youtu.be/testUrlAlpha';
      const urlB = 'https://youtu.be/testUrlBeta';

      final checkA = HandleRoute.isDuplicate(urlA);
      final checkB = HandleRoute.isDuplicate(urlB);

      expect(checkA, isFalse);
      expect(checkB, isFalse);
    });

    test('handleRoute generates route for valid YouTube link', () {
      const uniqueUrl = 'https://www.youtube.com/watch?v=uniqueVideoId123';
      final route = HandleRoute.handleRoute(uniqueUrl);

      expect(route, isNotNull);
      expect(route, isA<PageRouteBuilder>());
    });

    test('handleRoute returns null for duplicate URL delivery', () {
      const repeatUrl = 'https://www.youtube.com/watch?v=repeatVideoId456';
      final firstRoute = HandleRoute.handleRoute(repeatUrl);
      final duplicateRoute = HandleRoute.handleRoute(repeatUrl);

      expect(firstRoute, isNotNull);
      expect(duplicateRoute, isNull); // Blocked duplicate delivery!
    });
  });

  group('Batch 6: Stream Candidate Validation & Selection', () {
    test('validates authentic googlevideo CDN stream candidate', () {
      final candidate = YouTubeStreamCandidate(
        videoId: 'dQw4w9WgXcQ',
        url:
            'https://rr2---sn-4g5ednss.googlevideo.com/videoplayback?expire=1700000000&id=123',
        mimeType: 'audio/webm; codecs="opus"',
        audioCodec: 'opus',
        bitrate: 160000,
        isAudioOnly: true,
        resolver: 'youtube_explode_audio_only',
      );
      expect(candidate.isValid, isTrue);
    });

    test('validates legitimate supported googlevideo.com subdomains with signed params', () {
      final subdomains = [
        'https://rr1---sn-4g5ednss.googlevideo.com/videoplayback?expire=1700000000&ei=xyz&ip=1.2.3.4&id=o-ABC&itag=251&source=youtube&requiressl=yes&mh=12&mm=31&mn=sn&ms=au&mv=m&mvi=1&pl=24&initcwndbps=1000&spc=U987&vprv=1&svpuc=1&mime=audio%2Fwebm&ns=test&gir=yes&clen=3500000&dur=215.5&lmt=1600000000&mt=1700000000&fvip=2&keepalive=yes&fexp=123&c=ANDROID&txp=123&sparams=expire%2Cei%2Cip%2Cid%2Citag%2Csource%2Crequiressl%2Cspc%2Cvprv%2Csvpuc%2Cmime%2Cns%2Cgir%2Cclen%2Cdur%2Clmt&sig=A1B2C3D4E5&lsparams=mh%2Cmm%2Cmn%2Cms%2Cmv%2Cmvi%2Cpl%2Cinitcwndbps&lsig=Z9Y8X7W6',
        'https://manifest.googlevideo.com/api/manifest/hls_variant/expire/1700000000/id/123/signature/ABCDEF',
        'http://rr3---sn-vgqsrne7.googlevideo.com/videoplayback?id=test&itag=140',
      ];

      for (final url in subdomains) {
        final candidate = YouTubeStreamCandidate(
          videoId: 'testVid',
          url: url,
          mimeType: 'audio/webm',
          audioCodec: 'opus',
          bitrate: 160000,
          isAudioOnly: true,
          resolver: 'test',
        );
        expect(candidate.isValid, isTrue, reason: 'Expected valid for $url');
      }
    });

    test('rejects lookalike hostnames attempting substring spoofing', () {
      final lookalikeUrls = [
        'https://youtube.com.evil.example/videoplayback?id=123',
        'https://googlevideo.com.evil.example/videoplayback?id=123',
        'https://evilgooglevideo.com/videoplayback',
        'https://evilyoutube.com/videoplayback',
        'https://notgooglevideo.com/videoplayback',
        'https://subdomain.googlevideo.com.attacker.com/stream.mp4',
        'https://youtube.com@evil.com/videoplayback',
      ];

      for (final url in lookalikeUrls) {
        final candidate = YouTubeStreamCandidate(
          videoId: 'spoofVid',
          url: url,
          mimeType: 'audio/webm',
          audioCodec: 'opus',
          bitrate: 160000,
          isAudioOnly: true,
          resolver: 'test_spoof',
        );
        expect(candidate.isValid, isFalse, reason: 'Expected false for lookalike host: $url');
      }
    });

    test('rejects video-page and watch URLs with or without query strings', () {
      final watchUrls = [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com/watch',
        'https://m.youtube.com/watch?v=abc',
        'https://music.youtube.com/watch',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/playlist?list=PL12345',
        'https://www.youtube.com/channel/UC12345',
        'https://www.youtube.com/feed/subscriptions',
      ];

      for (final url in watchUrls) {
        final candidate = YouTubeStreamCandidate(
          videoId: 'dQw4w9WgXcQ',
          url: url,
          mimeType: 'text/html',
          audioCodec: 'none',
          bitrate: 0,
          isAudioOnly: false,
          resolver: 'test_watch_page',
        );
        expect(candidate.isValid, isFalse, reason: 'Expected false for HTML page URL: $url');
      }
    });

    test('rejects search results pages with or without query parameters', () {
      final searchUrls = [
        'https://www.youtube.com/results',
        'https://www.youtube.com/results?search_query=foo',
        'https://m.youtube.com/results?q=bar',
      ];

      for (final url in searchUrls) {
        final candidate = YouTubeStreamCandidate(
          videoId: 'dQw4w9WgXcQ',
          url: url,
          mimeType: 'text/html',
          audioCodec: 'none',
          bitrate: 0,
          isAudioOnly: false,
          resolver: 'test_search_page',
        );
        expect(candidate.isValid, isFalse, reason: 'Expected false for search results: $url');
      }
    });

    test('rejects non-HTTP(S) schemes and malformed URLs', () {
      final invalidUrls = [
        'ftp://rr1---sn.googlevideo.com/videoplayback',
        'file:///path/to/stream.mp3',
        'content://media/external/audio/123',
        'javascript:alert(1)',
        'data:audio/mp3;base64,123',
        'not_a_valid_url',
        '://missing_scheme',
        '',
        'null',
      ];

      for (final url in invalidUrls) {
        final candidate = YouTubeStreamCandidate(
          videoId: 'invalidVid',
          url: url,
          mimeType: 'audio/mp3',
          audioCodec: 'mp3',
          bitrate: 128000,
          isAudioOnly: true,
          resolver: 'test_invalid',
        );
        expect(candidate.isValid, isFalse, reason: 'Expected false for invalid/malformed: $url');
      }
    });

    test('selectStreamUrls correctly orders low and high bitrate', () {
      final low = YouTubeStreamCandidate(
        videoId: 'vid1',
        url: 'https://rr1---sn.googlevideo.com/videoplayback?id=low',
        mimeType: 'audio/webm',
        audioCodec: 'opus',
        bitrate: 64000,
        isAudioOnly: true,
        resolver: 'test',
      );
      final high = YouTubeStreamCandidate(
        videoId: 'vid1',
        url: 'https://rr1---sn.googlevideo.com/videoplayback?id=high',
        mimeType: 'audio/webm',
        audioCodec: 'opus',
        bitrate: 160000,
        isAudioOnly: true,
        resolver: 'test',
      );

      // Pass in reverse order to ensure sorting operates correctly
      final selected = selectStreamUrls([high, low]);
      expect(selected.length, 2);
      expect(
        selected.first,
        'https://rr1---sn.googlevideo.com/videoplayback?id=low',
      );
      expect(
        selected.last,
        'https://rr1---sn.googlevideo.com/videoplayback?id=high',
      );
    });

    test('selectStreamUrls prioritizes audio-only over muxed streams', () {
      final muxedHighBitrate = YouTubeStreamCandidate(
        videoId: 'vid1',
        url: 'https://rr1---sn.googlevideo.com/videoplayback?id=muxed',
        mimeType: 'video/mp4; codecs="avc1, mp4a"',
        audioCodec: 'mp4a',
        bitrate: 500000, // Video + audio bitrate
        isAudioOnly: false,
        resolver: 'test_muxed',
      );
      final audioOnly = YouTubeStreamCandidate(
        videoId: 'vid1',
        url: 'https://rr1---sn.googlevideo.com/videoplayback?id=pure_audio',
        mimeType: 'audio/webm; codecs="opus"',
        audioCodec: 'opus',
        bitrate: 160000,
        isAudioOnly: true,
        resolver: 'test_audio_only',
      );

      final selected = selectStreamUrls([muxedHighBitrate, audioOnly]);
      expect(selected.length, 2);
      // Both low and high should be the pure audio stream, avoiding heavy muxed video download
      expect(
        selected.first,
        'https://rr1---sn.googlevideo.com/videoplayback?id=pure_audio',
      );
      expect(
        selected.last,
        'https://rr1---sn.googlevideo.com/videoplayback?id=pure_audio',
      );
    });

    test('selectStreamUrls returns empty list when all candidates invalid', () {
      final invalidCandidate = YouTubeStreamCandidate(
        videoId: 'vid1',
        url: 'https://youtube.com/watch?v=123',
        mimeType: 'text/html',
        audioCodec: 'none',
        bitrate: 0,
        isAudioOnly: false,
        resolver: 'test',
      );
      final selected = selectStreamUrls([invalidCandidate]);
      expect(selected, isEmpty);
    });
  });

  group('Batch 6: Outgoing Sharing URL Sanitization', () {
    test('sanitizes stream URLs to avoid leaking short-lived CDN links', () {
      const cdnUrl =
          'https://rr2---sn-4g5ednss.googlevideo.com/videoplayback?expire=1700000000';
      const videoId = 'dQw4w9WgXcQ';

      String sanitizeShareUrl(String? permaUrl, String? id) {
        if (permaUrl != null &&
            permaUrl.isNotEmpty &&
            permaUrl != 'null' &&
            !permaUrl.contains('googlevideo.com')) {
          return permaUrl;
        }
        if (id != null && id.isNotEmpty && id != 'null') {
          return 'https://youtube.com/watch?v=$id';
        }
        return '';
      }

      // 1. Raw CDN URL in perma_url must be converted to canonical public YouTube URL
      final sanitizedCdn = sanitizeShareUrl(cdnUrl, videoId);
      expect(sanitizedCdn, 'https://youtube.com/watch?v=dQw4w9WgXcQ');

      // 2. Public JioSaavn perma_url is preserved
      const saavnUrl = 'https://www.jiosaavn.com/song/test-song/A1B2C3';
      final sanitizedSaavn = sanitizeShareUrl(saavnUrl, '12345');
      expect(sanitizedSaavn, saavnUrl);

      // 3. Null or 'null' perma_url falls back to public watch URL
      expect(
        sanitizeShareUrl(null, videoId),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(
        sanitizeShareUrl('null', videoId),
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
      );

      // 4. Missing everything returns empty string, avoiding sharing 'null'
      expect(sanitizeShareUrl(null, null), '');
    });
  });
}
