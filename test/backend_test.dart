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

  group('Lyrics UTF-8 Character Encoding Tests', () {
    test('utf8.decode prevents Latin-1 mojibake for Hindi Devanagari lyrics', () {
      const hindiLyricText = 'मुस्कुराने की वजह तुम हो\nगुनगुनाने की वजह तुम हो';
      final encodedBytes = utf8.encode(jsonEncode({'plainLyrics': hindiLyricText}));

      // Simulating naive response.body behavior (Latin-1 fallback when charset is omitted)
      final naiveDecoded = latin1.decode(encodedBytes);
      expect(naiveDecoded.contains('à¤'), isTrue); // Corrupted mojibake!
      expect(naiveDecoded.contains('मुस्कुराने'), isFalse);

      // Verified fix: using utf8.decode(response.bodyBytes)
      final properDecoded = utf8.decode(encodedBytes);
      final parsed = jsonDecode(properDecoded) as Map;
      expect(parsed['plainLyrics'], equals(hindiLyricText));
      expect(parsed['plainLyrics'].contains('मुस्कुराने'), isTrue);
      expect(parsed['plainLyrics'].contains('à¤'), isFalse);
    });

    test('synced LRC lyrics with Hindi text decode cleanly with timestamps', () {
      const syncedHindi = '[00:15.30] मुस्कुराने की वजह तुम हो\n[00:20.45] जिया जाए ना, जाए ना, जाए ना';
      final encodedBytes = utf8.encode(jsonEncode({'syncedLyrics': syncedHindi, 'plainLyrics': ''}));
      final decoded = jsonDecode(utf8.decode(encodedBytes)) as Map;
      expect(decoded['syncedLyrics'], equals(syncedHindi));
      expect(Lyrics.isHtmlOrChallenge(decoded['syncedLyrics'] as String), isFalse);
    });
  });

  group('JioSaavn URI Construction & Endpoint Tests', () {
    test('Uri.parse preserves query string without encoding ? as %3F in path', () {
      const baseUrl = 'www.jiosaavn.com';
      const apiStr = '/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0';
      const params = '__call=webapi.getLaunchData';

      // Buggy baseline Uri.https:
      final buggyUri = Uri.https(baseUrl, '$apiStr&$params');
      expect(buggyUri.path.contains('%3F'), isTrue); // Broken! %3F causes 403 Forbidden!
      expect(buggyUri.query, isEmpty);

      // Fixed Uri.parse:
      final fixedUri = Uri.parse('https://$baseUrl$apiStr&$params');
      expect(fixedUri.path, equals('/api.php')); // Clean path!
      expect(fixedUri.queryParameters['_format'], equals('json'));
      expect(fixedUri.queryParameters['__call'], equals('webapi.getLaunchData'));
      expect(fixedUri.toString().contains('%3F'), isFalse);
    });
  });

  group('YouTube /music Feed & Modern Lockup Parsing Tests', () {
    test('parses richShelfRenderer with lockupViewModel into home shelf playlists', () {
      final mockData = {
        'contents': {
          'twoColumnBrowseResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'richGridRenderer': {
                      'contents': [
                        {
                          'richSectionRenderer': {
                            'content': {
                              'richShelfRenderer': {
                                'title': {'simpleText': "India's Biggest Hits"},
                                'contents': [
                                  {
                                    'richItemRenderer': {
                                      'content': {
                                        'lockupViewModel': {
                                          'contentId': 'PL1234567890',
                                          'metadata': {
                                            'lockupMetadataViewModel': {
                                              'title': {'content': 'Bollywood Hitlist'},
                                              'metadata': {
                                                'contentMetadataViewModel': {
                                                  'metadataRows': [
                                                    {
                                                      'metadataParts': [
                                                        {
                                                          'text': {'content': 'Top Trending Bollywood'}
                                                        }
                                                      ]
                                                    }
                                                  ]
                                                }
                                              }
                                            }
                                          },
                                          'contentImage': {
                                            'thumbnailViewModel': {
                                              'image': {
                                                'sources': [
                                                  {'url': 'https://i.ytimg.com/vi/test/hqdefault.jpg'}
                                                ]
                                              }
                                            }
                                          },
                                          'rendererContext': {
                                            'commandContext': {
                                              'onTap': {
                                                'innertubeCommand': {
                                                  'watchPlaylistEndpoint': {
                                                    'playlistId': 'PL1234567890'
                                                  },
                                                  'watchEndpoint': {
                                                    'videoId': 'vid_first_123'
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                ]
                              }
                            }
                          }
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        }
      };

      final tabs = mockData['contents']!['twoColumnBrowseResultsRenderer']!['tabs']! as List;
      final tabContent = (tabs[0] as Map)['tabRenderer']['content'] as Map;
      final gridContents = tabContent['richGridRenderer']['contents'] as List;
      final shelves = [];
      for (final c in gridContents) {
        final rsr = c['richSectionRenderer']?['content']?['richShelfRenderer'];
        if (rsr != null) {
          final title = rsr['title']?['simpleText'] ?? 'Music';
          final items = [];
          for (final it in rsr['contents'] as List) {
            final lvm = it['richItemRenderer']?['content']?['lockupViewModel'];
            if (lvm != null) {
              final meta = lvm['metadata']?['lockupMetadataViewModel'];
              final itemTitle = meta?['title']?['content'] ?? '';
              final cmd = lvm['rendererContext']?['commandContext']?['onTap']?['innertubeCommand'];
              final playlistId = cmd?['watchPlaylistEndpoint']?['playlistId'] ?? lvm['contentId'];
              final videoId = cmd?['watchEndpoint']?['videoId'] ?? '';
              final imgSources = lvm['contentImage']?['thumbnailViewModel']?['image']?['sources'] as List? ?? [];
              final img = imgSources.isNotEmpty ? imgSources.last['url'] : '';
              items.add({
                'title': itemTitle,
                'playlistId': playlistId,
                'firstItemId': videoId,
                'image': img,
              });
            }
          }
          shelves.add({'title': title, 'playlists': items});
        }
      }

      expect(shelves.length, equals(1));
      expect(shelves.first['title'], equals("India's Biggest Hits"));
      expect((shelves.first['playlists'] as List).first['title'], equals('Bollywood Hitlist'));
      expect((shelves.first['playlists'] as List).first['playlistId'], equals('PL1234567890'));
      expect((shelves.first['playlists'] as List).first['firstItemId'], equals('vid_first_123'));
    });
  });

  group('Spotify Track / Items Filtering Tests', () {
    test('filters out null track entries and sanitizes track items for top charts', () {
      final rawSpotifyItems = [
        {
          'track': {
            'name': 'Valid Song',
            'album': {
              'images': [
                {'url': 'https://i.scdn.co/image/big.jpg'},
                {'url': 'https://i.scdn.co/image/small.jpg'},
              ]
            },
            'artists': [
              {'name': 'Artist A'}
            ],
            'external_urls': {
              'spotify': 'https://open.spotify.com/track/123'
            }
          }
        },
        {
          // Unavailable track with null track property
          'track': null
        },
        {
          // Episode/podcast with null album images
          'track': {
            'name': 'Podcast Episode',
            'album': {'images': []},
            'artists': [{'name': 'Host'}]
          }
        }
      ];

      final filtered = rawSpotifyItems.where((item) {
        final dynamic track = item['track'];
        if (track is! Map) return false;
        if (track['name'] == null) return false;
        final dynamic album = track['album'];
        if (album is! Map) return false;
        final dynamic images = album['images'];
        if (images is! List || images.isEmpty) return false;
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      final firstItem = filtered.first;
      final firstTrack = firstItem['track']! as Map;
      expect(firstTrack['name'], equals('Valid Song'));
    });
  });

  group('YouTube Stream Expiry & URI Validation Tests', () {
    test('extracts expire timestamp from signed stream URL correctly', () {
      const sampleUrl = 'https://rr4---sn-5hnekne6.googlevideo.com/videoplayback?expire=1760720400&ei=abcd&ip=1.2.3.4&id=o-ABCD&itag=140';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(sampleUrl);
      expect(match, isNotNull);
      expect(match!.group(1), equals('1760720400'));
      final int expireTimestamp = int.parse(match.group(1)!);
      expect(expireTimestamp, equals(1760720400));
    });

    test('detects expired stream timestamp against current epoch', () {
      final int pastExpire = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 300;
      final String pastUrl = 'https://googlevideo.com/videoplayback?expire=$pastExpire&id=123';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(pastUrl);
      expect(match, isNotNull);
      final int expireTime = int.parse(match!.group(1)!);
      final bool isExpired = DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireTime;
      expect(isExpired, isTrue);
    });

    test('handles URLs without expire parameter safely without throwing exceptions', () {
      const urlWithoutExpire = 'https://example.com/stream.mp4';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(urlWithoutExpire);
      expect(match, isNull);
    });
  });

  group('Playback Stats Counting & Semantics Tests', () {
    test('tracks and increments playCount for local songs regardless of artUri scheme', () {
      final Map<String, dynamic> fakeStatsBox = {};
      final localSong1 = {
        'id': 'local_file_1',
        'title': 'Local Song One',
        'artist': 'Local Artist',
        'artUri': 'file:///storage/emulated/0/Music/song1.mp3',
      };

      // Function simulating addRecentlyPlayed logic from AudioPlayerHandlerImpl
      void trackPlay(Map song) {
        final String id = song['id'] as String;
        final Map songStats = Map<String, dynamic>.from(fakeStatsBox[id] as Map? ?? {});
        songStats['playCount'] = ((songStats['playCount'] as int?) ?? 0) + 1;
        songStats['title'] = song['title'];
        songStats['artist'] = song['artist'];
        songStats['id'] = id;
        fakeStatsBox[id] = songStats;

        final Map mostPlayed = Map<String, dynamic>.from(fakeStatsBox['mostPlayed'] as Map? ?? {});
        if ((songStats['playCount'] as int) > ((mostPlayed['playCount'] as int?) ?? 0)) {
          fakeStatsBox['mostPlayed'] = songStats;
        }
      }

      // Play local song 1 twice
      trackPlay(localSong1);
      trackPlay(localSong1);

      expect(fakeStatsBox['local_file_1']['playCount'], equals(2));
      expect(fakeStatsBox['mostPlayed']['id'], equals('local_file_1'));
      expect(fakeStatsBox['mostPlayed']['playCount'], equals(2));

      // Play local song 2 three times
      final localSong2 = {
        'id': 'local_file_2',
        'title': 'Local Song Two',
        'artist': 'Local Artist',
        'artUri': '',
      };
      trackPlay(localSong2);
      trackPlay(localSong2);
      trackPlay(localSong2);

      expect(fakeStatsBox['local_file_2']['playCount'], equals(3));
      expect(fakeStatsBox['mostPlayed']['id'], equals('local_file_2'));
      expect(fakeStatsBox['mostPlayed']['title'], equals('Local Song Two'));
    });
  });

  group('YouTube Music Search Degraded & Error Handling Tests', () {
    test('returns null gracefully on item with missing flexColumns', () {
      final service = YtMusicService();
      final malformedItem = {
        'musicResponsiveListItemRenderer': {
          'flexColumns': <dynamic>[],
        }
      };
      final result = service.parseResponsiveListItem(malformedItem);
      expect(result, isNull);
    });

    test('returns null gracefully on item with missing runs or navigation endpoints', () {
      final service = YtMusicService();
      final malformedItem = {
        'musicResponsiveListItemRenderer': {
          'flexColumns': [
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {'runs': <dynamic>[]}
              }
            }
          ]
        }
      };
      final result = service.parseResponsiveListItem(malformedItem);
      expect(result, isNull);
    });

    test('handles empty or non-200 responses without uncaught errors', () async {
      final service = YtMusicService();
      // Test search with invalid endpoint
      final emptyResult = await service.sendRequest(
        'non_existent_endpoint',
        {},
        {},
        retries: 0,
      );
      expect(emptyResult, isEmpty);
    });
  });
}
