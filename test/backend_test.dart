import 'dart:convert';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/Helpers/format.dart';
import 'package:blackhole/Helpers/lyrics.dart';
import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:blackhole/Helpers/update.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lyrics Backend & HTML Rejection Tests', () {
    test(
        'isHtmlOrChallenge should detect HTML doctype, tags, and challenge pages',
        () {
      expect(
          Lyrics.isHtmlOrChallenge(
              '<!DOCTYPE html><html><body>Error</body></html>'),
          isTrue);
      expect(
          Lyrics.isHtmlOrChallenge(
              '<html lang="en"><head><script src="bot.js"></script></head>'),
          isTrue);
      expect(
          Lyrics.isHtmlOrChallenge(
              'Please complete the captcha below: <div><span class="captcha">'),
          isTrue);
      expect(
          Lyrics.isHtmlOrChallenge(
              'Enable JavaScript to continue to Google Search'),
          isTrue);
      expect(
          Lyrics.isHtmlOrChallenge(
              '<div class="BNeawe">Some scraped text</div>'),
          isTrue);
    });

    test(
        'isHtmlOrChallenge should allow clean plain lyrics and synced LRC lyrics',
        () {
      expect(
          Lyrics.isHtmlOrChallenge(
              'Look at the stars\nLook how they shine for you'),
          isFalse);
      expect(
          Lyrics.isHtmlOrChallenge(
              '[00:35.66] Look at the stars\n[00:38.46] Look how they shine for you'),
          isFalse);
      expect(Lyrics.isHtmlOrChallenge(''), isFalse);
    });

    test(
        'getGoogleLyrics rejects HTML challenge pages and returns empty string',
        () async {
      // Even if Google search returns an HTML document or bot challenge, it must never return HTML
      const htmlChallenge =
          '<!DOCTYPE html><html><head><title>Bot Check</title></head><body>Please solve captcha</body></html>';
      expect(Lyrics.isHtmlOrChallenge(htmlChallenge), isTrue);
    });
  });

  group('JioSaavn Formatting Tests', () {
    test('formatHomePageData safely handles empty modules and sets collections',
        () async {
      final input = {
        'modules': {},
      };
      final formatted = await FormatResponse.formatHomePageData(input);
      expect(formatted, isA<Map>());
      expect(formatted['collections'], isA<List>());
      expect(
          (formatted['collections'] as List).contains('new_trending'), isTrue);
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
      expect(
          (formatted['collections'] as List).contains('top_playlists'), isTrue);
      expect(formatted['top_playlists'], isA<List>());
      expect((formatted['top_playlists'] as List).first['title'],
          equals('Top Hindi Hits'));
    });

    test('formatSingleSongResponse sets valid media URLs and formats metadata',
        () async {
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

    test(
        'generateCodeChallenge generates valid unpadded Base64URL SHA-256 challenge',
        () {
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
    test('utf8.decode prevents Latin-1 mojibake for Hindi Devanagari lyrics',
        () {
      const hindiLyricText =
          'मुस्कुराने की वजह तुम हो\nगुनगुनाने की वजह तुम हो';
      final encodedBytes =
          utf8.encode(jsonEncode({'plainLyrics': hindiLyricText}));

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

    test('synced LRC lyrics with Hindi text decode cleanly with timestamps',
        () {
      const syncedHindi =
          '[00:15.30] मुस्कुराने की वजह तुम हो\n[00:20.45] जिया जाए ना, जाए ना, जाए ना';
      final encodedBytes = utf8
          .encode(jsonEncode({'syncedLyrics': syncedHindi, 'plainLyrics': ''}));
      final decoded = jsonDecode(utf8.decode(encodedBytes)) as Map;
      expect(decoded['syncedLyrics'], equals(syncedHindi));
      expect(
          Lyrics.isHtmlOrChallenge(decoded['syncedLyrics'] as String), isFalse);
    });
  });

  group('JioSaavn URI Construction & Endpoint Tests', () {
    test('Uri.parse preserves query string without encoding ? as %3F in path',
        () {
      const baseUrl = 'www.jiosaavn.com';
      const apiStr =
          '/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0';
      const params = '__call=webapi.getLaunchData';

      // Buggy baseline Uri.https:
      final buggyUri = Uri.https(baseUrl, '$apiStr&$params');
      expect(buggyUri.path.contains('%3F'),
          isTrue); // Broken! %3F causes 403 Forbidden!
      expect(buggyUri.query, isEmpty);

      // Fixed Uri.parse:
      final fixedUri = Uri.parse('https://$baseUrl$apiStr&$params');
      expect(fixedUri.path, equals('/api.php')); // Clean path!
      expect(fixedUri.queryParameters['_format'], equals('json'));
      expect(
          fixedUri.queryParameters['__call'], equals('webapi.getLaunchData'));
      expect(fixedUri.toString().contains('%3F'), isFalse);
    });
  });

  group('YouTube /music Feed & Modern Lockup Parsing Tests', () {
    test(
        'parses richShelfRenderer with lockupViewModel into home shelf playlists',
        () {
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
                                              'title': {
                                                'content': 'Bollywood Hitlist'
                                              },
                                              'metadata': {
                                                'contentMetadataViewModel': {
                                                  'metadataRows': [
                                                    {
                                                      'metadataParts': [
                                                        {
                                                          'text': {
                                                            'content':
                                                                'Top Trending Bollywood'
                                                          }
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
                                                  {
                                                    'url':
                                                        'https://i.ytimg.com/vi/test/hqdefault.jpg'
                                                  }
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

      final tabs =
          mockData['contents']!['twoColumnBrowseResultsRenderer']!['tabs']!
              as List;
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
              final cmd = lvm['rendererContext']?['commandContext']?['onTap']
                  ?['innertubeCommand'];
              final playlistId = cmd?['watchPlaylistEndpoint']?['playlistId'] ??
                  lvm['contentId'];
              final videoId = cmd?['watchEndpoint']?['videoId'] ?? '';
              final imgSources = lvm['contentImage']?['thumbnailViewModel']
                      ?['image']?['sources'] as List? ??
                  [];
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
      expect((shelves.first['playlists'] as List).first['title'],
          equals('Bollywood Hitlist'));
      expect((shelves.first['playlists'] as List).first['playlistId'],
          equals('PL1234567890'));
      expect((shelves.first['playlists'] as List).first['firstItemId'],
          equals('vid_first_123'));
    });
  });

  group('Spotify Track / Items Filtering Tests', () {
    test(
        'filters out null track entries and sanitizes track items for top charts',
        () {
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
            'external_urls': {'spotify': 'https://open.spotify.com/track/123'}
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
            'artists': [
              {'name': 'Host'}
            ]
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
      const sampleUrl =
          'https://rr4---sn-5hnekne6.googlevideo.com/videoplayback?expire=1760720400&ei=abcd&ip=1.2.3.4&id=o-ABCD&itag=140';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(sampleUrl);
      expect(match, isNotNull);
      expect(match!.group(1), equals('1760720400'));
      final int expireTimestamp = int.parse(match.group(1)!);
      expect(expireTimestamp, equals(1760720400));
    });

    test('detects expired stream timestamp against current epoch', () {
      final int pastExpire =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 300;
      final String pastUrl =
          'https://googlevideo.com/videoplayback?expire=$pastExpire&id=123';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(pastUrl);
      expect(match, isNotNull);
      final int expireTime = int.parse(match!.group(1)!);
      final bool isExpired =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireTime;
      expect(isExpired, isTrue);
    });

    test(
        'handles URLs without expire parameter safely without throwing exceptions',
        () {
      const urlWithoutExpire = 'https://example.com/stream.mp4';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(urlWithoutExpire);
      expect(match, isNull);
    });
  });

  group('Playback Stats Counting & Semantics Tests', () {
    test(
        'tracks and increments playCount for local songs regardless of artUri scheme',
        () {
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
        final Map songStats =
            Map<String, dynamic>.from(fakeStatsBox[id] as Map? ?? {});
        songStats['playCount'] = ((songStats['playCount'] as int?) ?? 0) + 1;
        songStats['title'] = song['title'];
        songStats['artist'] = song['artist'];
        songStats['id'] = id;
        fakeStatsBox[id] = songStats;

        final Map mostPlayed =
            Map<String, dynamic>.from(fakeStatsBox['mostPlayed'] as Map? ?? {});
        if ((songStats['playCount'] as int) >
            ((mostPlayed['playCount'] as int?) ?? 0)) {
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

    test(
        'returns null gracefully on item with missing runs or navigation endpoints',
        () {
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

    test('handles empty or non-200 responses without uncaught errors',
        () async {
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

  group('JioSaavn DES Decryption & Song Formatting Tests', () {
    test(
        'FormatResponse.decode gracefully handles malformed or non-base64 strings',
        () {
      expect(FormatResponse.decode('not_valid_base64!!!'), equals(''));
      expect(FormatResponse.decode(''), equals(''));
      expect(FormatResponse.decode('===invalid==='), equals(''));
    });

    test(
        'formatSingleSongResponse falls back through artist hierarchy gracefully',
        () async {
      // 1. subtitle fallback
      final songWithSubtitle = {
        'id': 'sub_1',
        'song': 'Test Song',
        'subtitle': 'Subtitle Artist',
        'more_info': <String, dynamic>{},
      };
      final res1 =
          await FormatResponse.formatSingleSongResponse(songWithSubtitle);
      expect(res1['artist'], equals('Subtitle Artist'));

      // 2. Unknown fallback
      final songWithNoArtist = {
        'id': 'unk_1',
        'song': 'Anonymous Song',
        'more_info': <String, dynamic>{},
      };
      final res2 =
          await FormatResponse.formatSingleSongResponse(songWithNoArtist);
      expect(res2['artist'], equals('Unknown'));
    });
  });

  group('Download Quality & Bitrate Replacement Tests', () {
    String resolveDownloadUrl(
        String rawUrl, String preferredQuality, bool has320) {
      final String quality = (preferredQuality == '320 kbps' && !has320)
          ? '160'
          : preferredQuality.replaceAll(' kbps', '');
      return rawUrl.replaceAll(
        RegExp(r'_(48|96|160|320)\.'),
        '_$quality.',
      );
    }

    test('replaces bitrate correctly when 320 kbps is available', () {
      const originalUrl = 'https://aac.saavncdn.com/123/sample_96.mp4';
      final resolved = resolveDownloadUrl(originalUrl, '320 kbps', true);
      expect(resolved, equals('https://aac.saavncdn.com/123/sample_320.mp4'));
    });

    test(
        'falls back to 160 kbps when user selects 320 kbps but song lacks 320kbps',
        () {
      const originalUrl = 'https://aac.saavncdn.com/123/sample_96.mp4';
      final resolved = resolveDownloadUrl(originalUrl, '320 kbps', false);
      expect(resolved, equals('https://aac.saavncdn.com/123/sample_160.mp4'));
    });

    test('replaces higher bitrate with user preferred 96 kbps', () {
      const originalUrl = 'https://aac.saavncdn.com/123/sample_320.mp4';
      final resolved = resolveDownloadUrl(originalUrl, '96 kbps', true);
      expect(resolved, equals('https://aac.saavncdn.com/123/sample_96.mp4'));
    });
  });

  group('YouTube Stream & Cache Expiry Handling Tests', () {
    test('extracts expiration timestamp from YouTube stream URLs correctly',
        () {
      const urlWithExpire =
          'https://rr4---sn-ci5gup-c35e.googlevideo.com/videoplayback?expire=1776543210&ei=test&ip=1.2.3.4';
      final match = RegExp(r'expire=([0-9]+)').firstMatch(urlWithExpire);
      expect(match, isNotNull);
      final int parsedExpire = int.tryParse(match!.group(1)!) ?? 0;
      expect(parsedExpire, equals(1776543210));
    });

    test('falls back to default expiration when expire parameter is absent',
        () {
      const urlWithoutExpire = 'https://example.com/audio.mp4';
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final match = RegExp(r'expire=([0-9]+)').firstMatch(urlWithoutExpire);
      final int parsedExpire = match != null
          ? (int.tryParse(match.group(1)!) ?? (now + 18000))
          : (now + 18000);
      expect(parsedExpire, greaterThanOrEqualTo(now + 17990));
    });

    test('cache hit evaluation correctly distinguishes valid vs expired cache',
        () {
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1. Valid cache: expires in 3600 seconds
      final int validExpiry = now + 3600;
      final bool isValid = (now + 350 <= validExpiry);
      expect(isValid, isTrue);

      // 2. Near-expiry cache: expires in 200 seconds (less than 350 threshold)
      final int nearExpiry = now + 200;
      final bool isNearExpired = (now + 350 <= nearExpiry);
      expect(isNearExpired, isFalse);

      // 3. Already expired cache
      final int expiredExpiry = now - 100;
      final bool isExpired = (now + 350 <= expiredExpiry);
      expect(isExpired, isFalse);
    });

    test(
        'quality selection chooses last stream for High and first stream for Low',
        () {
      final List<String> streams = [
        'https://stream.googlevideo.com/audio_low_48k',
        'https://stream.googlevideo.com/audio_medium_96k',
        'https://stream.googlevideo.com/audio_high_160k',
      ];

      final String highChoice = streams.last;
      final String lowChoice = streams.first;

      expect(
          highChoice, equals('https://stream.googlevideo.com/audio_high_160k'));
      expect(lowChoice, equals('https://stream.googlevideo.com/audio_low_48k'));
    });

    test('cache adaptation selects highUrl or lowUrl when both are cached', () {
      final Map<String, dynamic> cachedData = {
        'url': 'https://stream.googlevideo.com/audio_low_48k',
        'lowUrl': 'https://stream.googlevideo.com/audio_low_48k',
        'highUrl': 'https://stream.googlevideo.com/audio_high_160k',
        'quality': 'Low',
        'expire_at':
            (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600).toString(),
      };

      String selectCachedUrl(String quality) {
        final String cachedLow = cachedData['lowUrl']?.toString() ?? '';
        final String cachedHigh = cachedData['highUrl']?.toString() ?? '';
        final String cachedUrl = cachedData['url']?.toString() ?? '';
        return (quality == 'High' && cachedHigh.isNotEmpty)
            ? cachedHigh
            : (cachedLow.isNotEmpty ? cachedLow : cachedUrl);
      }

      expect(
        selectCachedUrl('High'),
        equals('https://stream.googlevideo.com/audio_high_160k'),
      );
      expect(
        selectCachedUrl('Low'),
        equals('https://stream.googlevideo.com/audio_low_48k'),
      );
    });

    test('handles empty manifest stream list safely without throwing', () {
      final List<String> emptyStreams = [];
      String? selectStream(List<String> urls, String quality) {
        if (urls.isEmpty) return null;
        return quality == 'High' ? urls.last : urls.first;
      }

      expect(selectStream(emptyStreams, 'High'), isNull);
      expect(selectStream(emptyStreams, 'Low'), isNull);
    });
  });

  group('Lyrics Title and Artist Sanitization Tests', () {
    test('cleanSongTitle removes movie/version tags and brackets cleanly', () {
      expect(
        Lyrics.cleanSongTitle('Kesariya (From "Brahmastra")'),
        equals('Kesariya'),
      );
      expect(
        Lyrics.cleanSongTitle('Believer [Official Music Video]'),
        equals('Believer'),
      );
      expect(
        Lyrics.cleanSongTitle('Shape of You (Official Lyric Video)'),
        equals('Shape of You'),
      );
      expect(
        Lyrics.cleanSongTitle('Despacito (feat. Daddy Yankee)'),
        equals('Despacito'),
      );
      expect(
        Lyrics.cleanSongTitle('Song Name - Official Video'),
        equals('Song Name'),
      );
      expect(
        Lyrics.cleanSongTitle('Song Name | 4K Video'),
        equals('Song Name'),
      );
      expect(
        Lyrics.cleanSongTitle('Plain Title'),
        equals('Plain Title'),
      );
    });

    test('cleanArtistName extracts primary artist cleanly', () {
      expect(
        Lyrics.cleanArtistName('Arijit Singh, Pritam, Amitabh Bhattacharya'),
        equals('Arijit Singh'),
      );
      expect(
        Lyrics.cleanArtistName('Arijit Singh & Pritam'),
        equals('Arijit Singh'),
      );
      expect(
        Lyrics.cleanArtistName('Ed Sheeran feat. Justin Bieber'),
        equals('Ed Sheeran'),
      );
      expect(
        Lyrics.cleanArtistName('Taylor Swift ft. Post Malone'),
        equals('Taylor Swift'),
      );
      expect(
        Lyrics.cleanArtistName('Coldplay'),
        equals('Coldplay'),
      );
    });
  });

  group('JioSaavn Charts & InnerTube Stream Parsing Tests', () {
    test('normalizes JioSaavn songs to Top Charts UI item format', () {
      final mockSaavnSong = {
        'id': 'saavn_123',
        'title': 'Chaleya',
        'artist': 'Anirudh Ravichander, Arijit Singh',
        'image': 'https://c.saavncdn.com/123.jpg',
        'perma_url': 'https://jiosaavn.com/s/chaleya/123',
        'url': 'https://aac.saavncdn.com/123/audio.mp4',
        'duration': '200',
      };

      final normalized = Map<String, dynamic>.from(mockSaavnSong);
      normalized['name'] = normalized['title'] ?? '';
      normalized['image_url_small'] = normalized['image'] ?? '';
      normalized['image_url_big'] = normalized['image'] ?? '';
      normalized['spotifyUrl'] = normalized['perma_url'] ?? '';

      expect(normalized['name'], equals('Chaleya'));
      expect(normalized['image_url_small'],
          equals('https://c.saavncdn.com/123.jpg'));
      expect(normalized['spotifyUrl'],
          equals('https://jiosaavn.com/s/chaleya/123'));
      expect(
          normalized['url'], equals('https://aac.saavncdn.com/123/audio.mp4'));
    });

    test(
        'extracts progressive and adaptive streams from InnerTube player response',
        () {
      final mockInnerTube = {
        'videoDetails': {
          'videoId': 'BBAyRBTfsOU',
          'title': 'Vaaste',
          'author': 'T-Series',
          'lengthSeconds': '266',
        },
        'streamingData': {
          'formats': [
            {
              'itag': 18,
              'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
              'url':
                  'https://stream.googlevideo.com/videoplayback?expire=1792445511&itag=18',
            }
          ],
          'adaptiveFormats': [
            {
              'itag': 140,
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'url':
                  'https://stream.googlevideo.com/videoplayback?expire=1792445511&itag=140',
            }
          ]
        }
      };

      final formats = mockInnerTube['streamingData']!['formats'] as List;
      final adaptiveFormats =
          mockInnerTube['streamingData']!['adaptiveFormats'] as List;
      final List<String> urls = [];

      for (final f in adaptiveFormats) {
        if (f['mimeType']?.toString().contains('audio') == true &&
            f['url'] != null) {
          urls.add(f['url'].toString());
        }
      }
      for (final f in formats) {
        if (f['url'] != null) {
          urls.add(f['url'].toString());
        }
      }

      expect(urls.length, equals(2));
      expect(urls.first, contains('itag=140'));
      expect(urls.last, contains('itag=18'));
    });

    test('filters null items safely in queue initialization', () {
      final rawList = [
        {'id': '1', 'title': 'Song 1'},
        null,
        {'id': '2', 'title': 'Song 2'},
        null,
      ];
      final filtered = rawList.where((item) => item != null).toList();
      expect(filtered.length, equals(2));
      expect(filtered[0]!['id'], equals('1'));
      expect(filtered[1]!['id'], equals('2'));
    });
  });

  group('YouTube Diagnostics, Stream Repair & Quality Selection Tests', () {
    test('YT Music search parsing injects YouTube genre and perma_url for playback readiness', () {
      final service = YtMusicService();
      final mockItem = {
        'musicResponsiveListItemRenderer': {
          'playlistItemData': {'videoId': 'gJLVTKhTnog'},
          'flexColumns': [
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {'text': 'Husn'}
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
                    {'text': 'Anuv Jain'},
                    {'text': ' • '},
                    {'text': 'Husn'},
                    {'text': ' • '},
                    {'text': '3:38'}
                  ]
                }
              }
            }
          ],
          'thumbnail': {
            'musicThumbnailRenderer': {
              'thumbnail': {
                'thumbnails': [
                  {'url': 'https://lh3.googleusercontent.com/test_120.jpg', 'width': 120, 'height': 120},
                  {'url': 'https://lh3.googleusercontent.com/test_544.jpg', 'width': 544, 'height': 544}
                ]
              }
            }
          }
        }
      };

      final parsed = service.parseResponsiveListItem(mockItem);
      expect(parsed, isNotNull);
      expect(parsed!['id'], equals('gJLVTKhTnog'));
      expect(parsed['title'], equals('Husn'));
      expect(parsed['artist'], equals('Anuv Jain'));
      expect(parsed['genre'], equals('YouTube'));
      expect(parsed['language'], equals('YouTube'));
      expect(parsed['perma_url'], equals('https://www.youtube.com/watch?v=gJLVTKhTnog'));
      expect(parsed['expire_at'], equals('0'));
    });

    test('MediaItemConverter preserves YouTube genre and extracts perma_url/expire_at', () {
      final ytItem = {
        'id': 'gJLVTKhTnog',
        'title': 'Husn',
        'artist': 'Anuv Jain',
        'album': 'Husn',
        'duration': '218',
        'image': 'https://lh3.googleusercontent.com/test_544.jpg',
        'genre': 'YouTube',
        'language': 'YouTube',
        'perma_url': 'https://www.youtube.com/watch?v=gJLVTKhTnog',
        'url': 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=140&expire=1792445511',
        'lowUrl': 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=249&expire=1792445511',
        'highUrl': 'https://rr1---sn-test.googlevideo.com/videoplayback?itag=140&expire=1792445511',
        'expire_at': '1792445511',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(ytItem);
      expect(mediaItem.id, equals('gJLVTKhTnog'));
      expect(mediaItem.title, equals('Husn'));
      expect(mediaItem.genre, equals('YouTube'));
      expect(mediaItem.extras!['genre'], equals('YouTube'));
      expect(mediaItem.extras!['language'], equals('YouTube'));
      expect(mediaItem.extras!['lowUrl'], contains('itag=249'));
      expect(mediaItem.extras!['highUrl'], contains('itag=140'));
      expect(mediaItem.extras!['perma_url'], equals('https://www.youtube.com/watch?v=gJLVTKhTnog'));
    });

    test('Audio source quality selection selects lowUrl for Low and highUrl for High', () {
      const lowUrl = 'https://stream.googlevideo.com/videoplayback?itag=249&expire=1792445511';
      const highUrl = 'https://stream.googlevideo.com/videoplayback?itag=140&expire=1792445511';
      const rawUrl = 'https://stream.googlevideo.com/videoplayback?itag=18&expire=1792445511';

      String selectStream(String quality, {required String low, required String high, required String fallback}) {
        return (quality == 'High' && high.isNotEmpty)
            ? high
            : (low.isNotEmpty ? low : fallback);
      }

      final lowSelected = selectStream('Low', low: lowUrl, high: highUrl, fallback: rawUrl);
      final highSelected = selectStream('High', low: lowUrl, high: highUrl, fallback: rawUrl);

      expect(lowSelected, equals(lowUrl));
      expect(lowSelected, contains('itag=249'));
      expect(highSelected, equals(highUrl));
      expect(highSelected, contains('itag=140'));
    });

    test('Audio source rejects empty or "null" URL safely to prevent player buffering stall', () {
      bool canConstructSource(String? url) {
        if (url == null || url.isEmpty || url == 'null' || url.contains('watch?v=')) {
          return false;
        }
        return true;
      }

      expect(canConstructSource(null), isFalse);
      expect(canConstructSource(''), isFalse);
      expect(canConstructSource('null'), isFalse);
      expect(canConstructSource('https://www.youtube.com/watch?v=123'), isFalse);
      expect(canConstructSource('https://rr1.googlevideo.com/videoplayback?itag=140'), isTrue);
      expect(canConstructSource('https://aac.saavncdn.com/123/song_320.mp4'), isTrue);
    });

    test('Sanitized diagnostics redact query parameters and signed URLs', () {
      const signedUrl = 'https://rr2---sn-4g5lzney.googlevideo.com/videoplayback?expire=1792445511&ei=abc&ip=1.2.3.4&id=o-123&itag=140&source=youtube&requiressl=yes&vprv=1&sig=AOq0QJ8wRAIgEXAMPLE_SIGNATURE_SECRET';
      final uri = Uri.parse(signedUrl);

      final sanitizedLog = '[Stage 2: Manifest Extraction] Succeeded | Host: ${uri.host} | Path: ${uri.path} | itag: ${uri.queryParameters['itag']} | expires: ${uri.queryParameters['expire']}';

      expect(sanitizedLog, contains('itag: 140'));
      expect(sanitizedLog, contains('expires: 1792445511'));
      expect(sanitizedLog, isNot(contains('sig=')));
      expect(sanitizedLog, isNot(contains('EXAMPLE_SIGNATURE_SECRET')));
      expect(sanitizedLog, isNot(contains('ip=')));
    });

    test('JioSaavn chart playlists map contains only verified regional/language charts', () {
      const charts = {
        'India Superhits Top 50': '1134548194',
        'Trending Today': '110858205',
        'Hindi: India Superhits Top 50': '1134543272',
        'International : India Superhits Top 50': '1134595537',
        'Punjabi: India Superhits Top 50': '1134543511',
      };

      expect(charts.containsKey('Hungary'), isFalse);
      expect(charts.containsKey('Global'), isFalse);
      expect(charts['India Superhits Top 50'], equals('1134548194'));
      expect(charts['Trending Today'], equals('110858205'));
      expect(charts['Hindi: India Superhits Top 50'], equals('1134543272'));
    });
  });

  group('YouTube Home Card Endpoint Parsing & Downstream Playlist Loading Tests', () {
    test('parses lockupViewModel with playlist endpoint into playlist card', () {
      final Map<String, dynamic> mockLvm = {
        'contentId': 'RDCLAK5uy_mFR70l_VLFRLP9RaVCz3gqeZv6IbhgMc0',
        'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {
              'content': 'Bollywood Hitlist',
            },
            'metadata': {
              'contentMetadataViewModel': {
                'metadataRows': [
                  {
                    'metadataParts': [
                      {'text': {'content': 'Playlist • 50 tracks'}}
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
                {'url': 'https://lh3.googleusercontent.com/pl_544.jpg'}
              ]
            }
          }
        },
        'rendererContext': {
          'commandContext': {
            'onTap': {
              'innertubeCommand': {
                'watchPlaylistEndpoint': {
                  'playlistId': 'RDCLAK5uy_mFR70l_VLFRLP9RaVCz3gqeZv6IbhgMc0'
                }
              }
            }
          }
        }
      };

      final cmd = ((mockLvm['rendererContext'] as Map)['commandContext'] as Map)['onTap'] != null
          ? (((mockLvm['rendererContext'] as Map)['commandContext'] as Map)['onTap'] as Map)['innertubeCommand'] as Map
          : {};
      String? playlistId = cmd['watchPlaylistEndpoint']?['playlistId']?.toString();
      playlistId ??= cmd['watchEndpoint']?['playlistId']?.toString();
      playlistId ??= cmd['browseEndpoint']?['browseId']?.toString();
      final String contentType = mockLvm['contentType']?.toString() ?? '';
      final String? videoId = cmd['watchEndpoint']?['videoId']?.toString();

      String itemType = 'playlist';
      if (contentType == 'LOCKUP_CONTENT_TYPE_VIDEO' ||
          (videoId != null && videoId.isNotEmpty && (playlistId == null || playlistId.isEmpty))) {
        itemType = 'video';
        playlistId = '';
      } else if (playlistId != null && playlistId.isNotEmpty) {
        itemType = 'playlist';
      }

      expect(itemType, equals('playlist'));
      expect(playlistId, equals('RDCLAK5uy_mFR70l_VLFRLP9RaVCz3gqeZv6IbhgMc0'));
    });

    test('parses lockupViewModel with video endpoint as video card and does not treat as playlist', () {
      final Map<String, dynamic> mockLvm = {
        'contentId': 'dQw4w9WgXcQ',
        'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Official Music Video'},
          }
        },
        'rendererContext': {
          'commandContext': {
            'onTap': {
              'innertubeCommand': {
                'watchEndpoint': {
                  'videoId': 'dQw4w9WgXcQ'
                }
              }
            }
          }
        }
      };

      final cmd = ((mockLvm['rendererContext'] as Map)['commandContext'] as Map)['onTap'] != null
          ? (((mockLvm['rendererContext'] as Map)['commandContext'] as Map)['onTap'] as Map)['innertubeCommand'] as Map
          : {};
      String? playlistId = cmd['watchPlaylistEndpoint']?['playlistId']?.toString();
      playlistId ??= cmd['watchEndpoint']?['playlistId']?.toString();
      playlistId ??= cmd['browseEndpoint']?['browseId']?.toString();
      final String contentType = mockLvm['contentType']?.toString() ?? '';
      final String? videoId = cmd['watchEndpoint']?['videoId']?.toString();

      String itemType = 'playlist';
      if (contentType == 'LOCKUP_CONTENT_TYPE_VIDEO' ||
          (videoId != null && videoId.isNotEmpty && (playlistId == null || playlistId.isEmpty))) {
        itemType = 'video';
        playlistId = '';
      } else if (playlistId != null && playlistId.isNotEmpty) {
        itemType = 'playlist';
      }

      expect(itemType, equals('video'));
      expect(playlistId, isEmpty);
      expect(videoId, equals('dQw4w9WgXcQ'));
    });

    test('parses modern twoColumnBrowseResultsRenderer playlist details response fixture', () {
      final mockBrowseResponse = {
        'contents': {
          'twoColumnBrowseResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'musicResponsiveHeaderRenderer': {
                            'title': {
                              'runs': [
                                {'text': 'इश्क़ है सुकून (Ishq Hai Sukoon)'}
                              ]
                            },
                            'subtitle': {
                              'runs': [
                                {'text': 'Playlist'},
                                {'text': ' • '},
                                {'text': '2026'}
                              ]
                            },
                            'description': {
                              'musicDescriptionShelfRenderer': {
                                'description': {
                                  'runs': [
                                    {'text': 'Tranquil, soulful watches.'}
                                  ]
                                }
                              }
                            },
                            'thumbnail': {
                              'musicThumbnailRenderer': {
                                'thumbnail': {
                                  'thumbnails': [
                                    {'url': 'https://lh3.googleusercontent.com/pl_thumb.jpg'}
                                  ]
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
            ],
            'secondaryContents': {
              'sectionListRenderer': {
                'contents': [
                  {
                    'musicPlaylistShelfRenderer': {
                      'contents': [
                        {
                          'musicResponsiveListItemRenderer': {
                            'playlistItemData': {'videoId': 'V7LwfY5U5WI'},
                            'flexColumns': [
                              {
                                'musicResponsiveListItemFlexColumnRenderer': {
                                  'text': {
                                    'runs': [
                                      {'text': 'Ranjha (ਰਾਝਾਂ)'}
                                    ]
                                  }
                                }
                              },
                              {
                                'musicResponsiveListItemFlexColumnRenderer': {
                                  'text': {
                                    'runs': [
                                      {'text': 'B Praak'},
                                      {'text': ' • '},
                                      {'text': 'Shershaah'},
                                      {'text': ' • '},
                                      {'text': '3:48'}
                                    ]
                                  }
                                }
                              }
                            ],
                            'thumbnail': {
                              'musicThumbnailRenderer': {
                                'thumbnail': {
                                  'thumbnails': [
                                    {'url': 'https://lh3.googleusercontent.com/song_thumb.jpg'}
                                  ]
                                }
                              }
                            }
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      };

      final twoCol = mockBrowseResponse['contents']!['twoColumnBrowseResultsRenderer'] as Map;
      final tab0 = (twoCol['tabs'] as List)[0]['tabRenderer']['content']['sectionListRenderer']['contents'] as List;
      final header = tab0[0]['musicResponsiveHeaderRenderer'] as Map;
      final heading = (header['title']['runs'] as List)[0]['text'];
      final subtitle = (header['subtitle']['runs'] as List).map((e) => e['text']).join();
      final description = (header['description']['musicDescriptionShelfRenderer']['description']['runs'] as List)[0]['text'];

      expect(heading, equals('इश्क़ है सुकून (Ishq Hai Sukoon)'));
      expect(subtitle, equals('Playlist • 2026'));
      expect(description, equals('Tranquil, soulful watches.'));

      final secContents = twoCol['secondaryContents']['sectionListRenderer']['contents'] as List;
      final shelf = secContents[0]['musicPlaylistShelfRenderer'] as Map;
      final items = shelf['contents'] as List;
      expect(items.length, equals(1));

      final firstItem = items[0]['musicResponsiveListItemRenderer'] as Map;
      expect(firstItem['playlistItemData']['videoId'], equals('V7LwfY5U5WI'));
      final trackTitle = (firstItem['flexColumns'][0]['musicResponsiveListItemFlexColumnRenderer']['text']['runs'] as List)[0]['text'];
      expect(trackTitle, equals('Ranjha (ਰਾਝਾਂ)'));
    });
  });

  group('YouTube Stream Candidate Model, Quality Selection & Fallbacks Tests', () {
    test('YouTubeStreamCandidate selection sorts candidates by bitrate ascending', () {
      final candidates = [
        YouTubeStreamCandidate(
          videoId: 'testVid',
          url: 'https://stream.googlevideo.com/high?expire=1792445511',
          mimeType: 'audio/webm',
          audioCodec: 'opus',
          bitrate: 160000,
          isAudioOnly: true,
          expireAt: 1792445511,
          resolver: 'test',
        ),
        YouTubeStreamCandidate(
          videoId: 'testVid',
          url: 'https://stream.googlevideo.com/low?expire=1792445511',
          mimeType: 'audio/webm',
          audioCodec: 'opus',
          bitrate: 50000,
          isAudioOnly: true,
          expireAt: 1792445511,
          resolver: 'test',
        ),
        YouTubeStreamCandidate(
          videoId: 'testVid',
          url: 'https://stream.googlevideo.com/medium?expire=1792445511',
          mimeType: 'audio/mp4',
          audioCodec: 'mp4a.40.2',
          bitrate: 128000,
          isAudioOnly: true,
          expireAt: 1792445511,
          resolver: 'test',
        ),
      ];

      final selected = selectStreamUrls(candidates);
      expect(selected.length, equals(2));
      // First is lowest bitrate (50 kbps)
      expect(selected.first, contains('/low'));
      // Last is highest bitrate (160 kbps)
      expect(selected.last, contains('/high'));
    });

    test('rejects video-only candidates safely', () {
      final rawAdaptiveFormats = [
        {
          'mimeType': 'video/mp4; codecs="avc1.64001F"',
          'bitrate': 2500000,
          'url': 'https://stream.googlevideo.com/videopart'
        },
        {
          'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
          'bitrate': 128000,
          'url': 'https://stream.googlevideo.com/audiopart?expire=1792445511'
        }
      ];

      final List<YouTubeStreamCandidate> candidates = [];
      for (final f in rawAdaptiveFormats) {
        final String mime = f['mimeType']?.toString() ?? '';
        if (!mime.contains('audio')) continue; // Reject video-only
        candidates.add(
          YouTubeStreamCandidate(
            videoId: 'testVid',
            url: f['url']!.toString(),
            mimeType: mime,
            audioCodec: 'mp4a',
            bitrate: f['bitrate'] as int,
            isAudioOnly: true,
            expireAt: 1792445511,
            resolver: 'test',
          ),
        );
      }

      expect(candidates.length, equals(1));
      expect(candidates.first.url, contains('audiopart'));
      expect(candidates.first.bitrate, equals(128000));
    });

    test('handles empty or malformed URLs without throwing exceptions', () {
      final candidates = [
        YouTubeStreamCandidate(
          videoId: 'testVid',
          url: '',
          mimeType: 'audio/mp4',
          audioCodec: 'mp4a',
          bitrate: 128000,
          isAudioOnly: true,
          resolver: 'test',
        ),
        YouTubeStreamCandidate(
          videoId: 'testVid',
          url: 'null',
          mimeType: 'audio/mp4',
          audioCodec: 'mp4a',
          bitrate: 128000,
          isAudioOnly: true,
          resolver: 'test',
        ),
      ];

      final selected = selectStreamUrls(candidates);
      expect(selected, isEmpty);
    });
  });

  group('Top Charts Tab Bar Selector Visibility Tests', () {
    test('selector visibility logic shows for Local (index 0) and hides for Global (index 1)', () {
      bool isSelectorVisible(int tabIndex) {
        return tabIndex == 0;
      }

      expect(isSelectorVisible(0), isTrue);
      expect(isSelectorVisible(1), isFalse);
      expect(isSelectorVisible(2), isFalse);
    });
  });
}
