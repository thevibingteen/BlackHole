import 'dart:convert';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/Helpers/format.dart';
import 'package:blackhole/Helpers/lyrics.dart';
import 'package:blackhole/Helpers/update.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lyrics Backend & HTML Rejection Tests', () {
    test('isHtmlOrChallenge should detect HTML doctype, tags, and challenge pages', () {
      expect(Lyrics.isHtmlOrChallenge('<!DOCTYPE html><html><body>Error</body></html>'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('<html lang="en"><head><script src="bot.js"></script></head>'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('Please complete the captcha below: <div><span class="captcha">'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('Enable JavaScript to continue to Google Search'), isTrue);
      expect(Lyrics.isHtmlOrChallenge('<div class="BNeawe">Some scraped text</div>'), isTrue);
    });

    test('isHtmlOrChallenge should allow clean plain lyrics and synced LRC lyrics', () {
      expect(Lyrics.isHtmlOrChallenge('Look at the stars\nLook how they shine for you'), isFalse);
      expect(Lyrics.isHtmlOrChallenge('[00:35.66] Look at the stars\n[00:38.46] Look how they shine for you'), isFalse);
      expect(Lyrics.isHtmlOrChallenge(''), isFalse);
    });

    test('getGoogleLyrics rejects HTML challenge pages and returns empty string', () async {
      // Even if Google search returns an HTML document or bot challenge, it must never return HTML
      const htmlChallenge = '<!DOCTYPE html><html><head><title>Bot Check</title></head><body>Please solve captcha</body></html>';
      expect(Lyrics.isHtmlOrChallenge(htmlChallenge), isTrue);
    });
  });

  group('JioSaavn Formatting Tests', () {
    test('formatHomePageData safely handles empty modules and sets collections', () async {
      final input = {
        'modules': {},
      };
      final formatted = await FormatResponse.formatHomePageData(input);
      expect(formatted, isA<Map>());
      expect(formatted['collections'], isA<List>());
      expect((formatted['collections'] as List).contains('new_trending'), isTrue);
    });

    test('formatHomePageData safely formats modules with items', () async {
      final input = {
        'modules': {
          'top_playlists': {
            'title': 'Top Playlists',
            'subtitle': 'Trending today',
            'position': '1',
          }
        },
        'top_playlists': [
          {
            'id': '12345',
            'title': 'Top Hindi Hits',
            'subtitle': 'Various Artists',
            'type': 'playlist',
            'image': 'https://c.saavncdn.com/test.jpg',
            'perma_url': 'https://jiosaavn.com/p/12345',
          }
        ]
      };
      final formatted = await FormatResponse.formatHomePageData(input);
      expect(formatted['collections'], isA<List>());
      expect((formatted['collections'] as List).contains('top_playlists'), isTrue);
      expect(formatted['top_playlists'], isA<List>());
      expect((formatted['top_playlists'] as List).first['title'], equals('Top Hindi Hits'));
    });

    test('formatSingleSongResponse sets valid media URLs and formats metadata', () async {
      final rawSong = {
        'id': 'song_1',
        'song': 'Kesariya',
        'singers': 'Arijit Singh',
        'album': 'Brahmastra',
        'year': '2022',
        'duration': '268',
        'image': 'https://c.saavncdn.com/123/Kesariya-500x500.jpg',
        'media_preview_url': 'https://aac.saavncdn.com/123/preview_96_p.mp4',
        'encrypted_media_url': '',
        '320kbps': 'true',
      };
      final formatted = await FormatResponse.formatSingleSongResponse(rawSong);
      expect(formatted['id'], equals('song_1'));
      expect(formatted['title'], equals('Kesariya'));
      expect(formatted['artist'], equals('Arijit Singh'));
      expect(formatted['url'], isNotEmpty);
      expect(formatted['320kbps'], isTrue);
    });
  });

  group('YouTube Music InnerTube Parser Tests', () {
    test('parses modern InnerTube musicResponsiveListItemRenderer', () {
      final service = YtMusicService();
      final mockItem = {
        'musicResponsiveListItemRenderer': {
          'flexColumns': [
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {
                      'text': 'Muskan',
                      'navigationEndpoint': {
                        'watchEndpoint': {
                          'videoId': 'vid_muskan_123',
                        }
                      }
                    }
                  ]
                }
              }
            },
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {'text': 'Song'},
                    {'text': ' • '},
                    {'text': 'Artist Name'},
                    {'text': ' • '},
                    {'text': 'Album Name'},
                    {'text': ' • '},
                    {'text': '3:45'}
                  ]
                }
              }
            }
          ],
          'thumbnail': {
            'musicThumbnailRenderer': {
              'thumbnail': {
                'thumbnails': [
                  {'url': 'https://lh3.googleusercontent.com/test=w120-h120'}
                ]
              }
            }
          }
        }
      };

      final parsed = service.parseResponsiveListItem(
        mockItem,
        defaultSectionTitle: 'Songs',
      );
      expect(parsed, isNotNull);
      expect(parsed!['id'], equals('vid_muskan_123'));
      expect(parsed['title'], equals('Muskan'));
      expect(parsed['artist'], equals('Artist Name'));
      expect(parsed['album'], equals('Album Name'));
      expect(parsed['duration'], equals('3:45'));
    });
  });

  group('Spotify PKCE Tests', () {
    test('generateCodeVerifier creates high-entropy URL-safe string', () {
      final verifier1 = SpotifyApi.generateCodeVerifier(64);
      final verifier2 = SpotifyApi.generateCodeVerifier(64);
      expect(verifier1.length, equals(64));
      expect(verifier2.length, equals(64));
      expect(verifier1, isNot(equals(verifier2)));
      // Check character set [A-Za-z0-9-._~]
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier1), isTrue);
    });

    test('generateCodeChallenge generates valid unpadded Base64URL SHA-256 challenge', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = SpotifyApi.generateCodeChallenge(verifier);
      expect(challenge, isNotEmpty);
      expect(challenge.contains('='), isFalse);
      expect(challenge.contains('+'), isFalse);
      expect(challenge.contains('/'), isFalse);
    });

    test('requestAuthorization contains PKCE parameters', () {
      final api = SpotifyApi();
      const testChallenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      final authUrl = api.requestAuthorization(testChallenge);
      expect(authUrl, contains('response_type=code'));
      expect(authUrl, contains('code_challenge_method=S256'));
      expect(authUrl, contains('code_challenge=$testChallenge'));
      expect(authUrl, contains(api.clientID));
    });
  });

  group('Update Version Comparator Tests', () {
    test('compareVersion identifies newer versions', () {
      expect(compareVersion('1.15.9', '1.15.8'), isTrue);
      expect(compareVersion('2.0.0', '1.15.8'), isTrue);
      expect(compareVersion('1.15.8', '1.15.8'), isFalse);
      expect(compareVersion('1.15.7', '1.15.8'), isFalse);
    });
  });
}
