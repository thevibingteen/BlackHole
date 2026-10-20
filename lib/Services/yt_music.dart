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

import 'dart:convert';

import 'package:blackhole/Helpers/extensions.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:blackhole/Services/ytmusic/nav.dart';
import 'package:blackhole/Services/ytmusic/playlist.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

class YtMusicService {
  static const ytmDomain = 'music.youtube.com';
  static const httpsYtmDomain = 'https://music.youtube.com';
  static const baseApiEndpoint = '/youtubei/v1/';
  static const ytmParams = {
    'alt': 'json',
    'key': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30'
  };
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0';
  static const Map<String, String> endpoints = {
    'search': 'search',
    'browse': 'browse',
    'get_song': 'player',
    'get_playlist': 'playlist',
    'get_album': 'album',
    'get_artist': 'artist',
    'get_video': 'video',
    'get_channel': 'channel',
    'get_lyrics': 'lyrics',
    'search_suggestions': 'music/get_search_suggestions',
    'next': 'next',
  };
  static const filters = [
    'albums',
    'artists',
    'playlists',
    'community_playlists',
    'featured_playlists',
    'songs',
    'videos'
  ];
  static const scopes = ['library', 'uploads'];

  Map<String, String>? headers;
  int? signatureTimestamp;
  Map<String, dynamic>? context;

  static final YtMusicService _singleton = YtMusicService._internal();

  factory YtMusicService() {
    return _singleton;
  }

  YtMusicService._internal();

  Map<String, String> initializeHeaders() {
    return {
      'user-agent': userAgent,
      'accept': '*/*',
      'accept-encoding': 'gzip, deflate',
      'content-type': 'application/json',
      'origin': httpsYtmDomain,
      'cookie': 'CONSENT=YES+1'
    };
  }

  Future<Response> sendGetRequest(
    String url,
    Map<String, String>? headers,
  ) async {
    final Uri uri = Uri.https(url);
    try {
      final Response response =
          await get(uri, headers: headers).timeout(const Duration(seconds: 15));
      return response;
    } catch (e) {
      Logger.root.severe('Error in sendGetRequest for $url: $e');
      return Response('{}', 500);
    }
  }

  Future<String?> getVisitorId(Map<String, String>? headers) async {
    final response = await sendGetRequest(ytmDomain, headers);
    final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
    final matches = reg.firstMatch(response.body);
    String? visitorId;
    if (matches != null) {
      final ytcfg = json.decode(matches.group(1).toString());
      visitorId = ytcfg['VISITOR_DATA']?.toString();
    }
    return visitorId;
  }

  Map<String, dynamic> initializeContext() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final String date = year + month + day;
    return {
      'context': {
        'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.$date.01.00'},
        'user': {}
      }
    };
  }

  Future<Map> sendRequest(
    String endpoint,
    Map body,
    Map<String, String>? headers, {
    int retries = 1,
  }) async {
    final Uri uri = Uri.https(ytmDomain, baseApiEndpoint + endpoint, ytmParams);
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final decoded = json.decode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            return decoded;
          }
          Logger.root.warning('YtMusic decoded response is not a Map: $endpoint');
          return {};
        } else if (response.statusCode >= 500 && attempt < retries) {
          Logger.root.warning(
            'YtMusic returned retryable status ${response.statusCode} on attempt $attempt, retrying...',
          );
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        } else {
          Logger.root.severe(
            'YtMusic returned HTTP ${response.statusCode} for $endpoint: ${response.body}',
          );
          return {};
        }
      } catch (e) {
        if (attempt < retries) {
          Logger.root.warning(
            'Transient error in sendRequest for $endpoint (attempt $attempt), retrying: $e',
          );
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        Logger.root.severe('Error in sendRequest for $endpoint: $e');
        return {};
      }
    }
    return {};
  }

  String? getParam2(String filter) {
    final filterParams = {
      'songs': 'I',
      'videos': 'Q',
      'albums': 'Y',
      'artists': 'g',
      'playlists': 'o'
    };
    return filterParams[filter];
  }

  String? getSearchParams({
    String? filter,
    String? scope,
    bool ignoreSpelling = false,
  }) {
    String? params;
    String? param1;
    String? param2;
    String? param3;
    if (!ignoreSpelling && filter == null && scope == null) {
      return params;
    }

    if (scope == 'uploads') {
      params = 'agIYAw%3D%3D';
    }

    if (scope == 'library') {
      if (filter != null) {
        param1 = 'EgWKAQI';
        param2 = getParam2(filter);
        param3 = 'AWoKEAUQCRADEAoYBA%3D%3D';
      } else {
        params = 'agIYBA%3D%3D';
      }
    }

    if (scope == null && filter != null) {
      if (filter == 'playlists') {
        params = 'Eg-KAQwIABAAGAAgACgB';
        if (!ignoreSpelling) {
          params += 'MABqChAEEAMQCRAFEAo%3D';
        } else {
          params += 'MABCAggBagoQBBADEAkQBRAK';
        }
      } else {
        if (filter.contains('playlists')) {
          param1 = 'EgeKAQQoA';
          if (filter == 'featured_playlists') {
            param2 = 'Dg';
          } else {
            // community_playlists
            param2 = 'EA';
          }

          if (!ignoreSpelling) {
            param3 = 'BagwQDhAKEAMQBBAJEAU%3D';
          } else {
            param3 = 'BQgIIAWoMEA4QChADEAQQCRAF';
          }
        } else {
          param1 = 'EgWKAQI';
          param2 = getParam2(filter);
          if (!ignoreSpelling) {
            param3 = 'AWoMEA4QChADEAQQCRAF';
          } else {
            param3 = 'AUICCAFqDBAOEAoQAxAEEAkQBQ%3D%3D';
          }
        }
      }
    }

    if (scope == null && filter == null && ignoreSpelling) {
      params = 'EhGKAQ4IARABGAEgASgAOAFAAUICCAE%3D';
    }

    if (params != null) {
      return params;
    } else {
      return '$param1$param2$param3';
    }
  }

  Future<void> init() async {
    headers = initializeHeaders();
    if (!headers!.containsKey('X-Goog-Visitor-Id')) {
      headers!['X-Goog-Visitor-Id'] = await getVisitorId(headers) ?? '';
    }
    context = initializeContext();
    context!['context']['client']['hl'] = 'en';
  }

  Map? parseResponsiveListItem(
    Map childItem, {
    String defaultSectionTitle = '',
  }) =>
      _parseResponsiveListItem(
        childItem,
        defaultSectionTitle: defaultSectionTitle,
      );

  Map? _parseResponsiveListItem(
    Map childItem, {
    String defaultSectionTitle = '',
  }) {
    final renderer = childItem['musicResponsiveListItemRenderer'] as Map?;
    if (renderer == null) return null;

    final List images = (nav(childItem, [
          'musicResponsiveListItemRenderer',
          'thumbnail',
          'musicThumbnailRenderer',
          'thumbnail',
          'thumbnails'
        ]) as List? ??
        [])
        .map((e) => (e as Map)['url'])
        .toList();

    final String title = nav(childItem, [
          'musicResponsiveListItemRenderer',
          'flexColumns',
          0,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs',
          0,
          'text'
        ])?.toString() ??
        '';

    if (title.isEmpty) return null;

    final List subtitleList = (nav(childItem, [
          'musicResponsiveListItemRenderer',
          'flexColumns',
          1,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs'
        ]) as List?) ??
        [];

    int count = 0;
    String type = '';
    String album = '';
    String artist = '';
    String views = '';
    String duration = '';
    String subtitle = '';
    String year = '';
    String countSongs = '';
    String subscribers = '';

    for (final element in subtitleList) {
      if (element is! Map) continue;
      final String text = element['text']?.toString() ?? '';
      subtitle += text;
      if (text.trim() == '•') {
        count++;
      } else {
        if (count == 0) {
          type += text;
        } else if (count == 1) {
          if (defaultSectionTitle == 'Artists' || type == 'Artist') {
            subscribers += text;
          } else {
            if (text.trim() == '&') {
              artist += ', ';
            } else {
              artist += text;
            }
          }
        } else if (count == 2) {
          if (defaultSectionTitle == 'Songs' ||
              type == 'Song' ||
              type == 'Single') {
            album += text;
          } else if (defaultSectionTitle == 'Videos' || type == 'Video') {
            views += text;
          } else if (defaultSectionTitle == 'Albums' || type == 'Album') {
            year += text;
          } else if (defaultSectionTitle.toLowerCase().contains('playlist') ||
              type.toLowerCase().contains('playlist')) {
            countSongs += text;
          } else {
            album += text;
          }
        } else if (count == 3) {
          duration += text;
        }
      }
    }

    if (type.isEmpty) {
      if (defaultSectionTitle == 'Songs') {
        type = 'Song';
      } else if (defaultSectionTitle == 'Videos') {
        type = 'Video';
      } else if (defaultSectionTitle == 'Artists') {
        type = 'Artist';
      } else if (defaultSectionTitle == 'Albums') {
        type = 'Album';
      } else if (defaultSectionTitle.toLowerCase().contains('playlist')) {
        type = 'Playlist';
      } else {
        type = 'Song';
      }
    }

    // Extract ID safely from videoId or browseEndpoint
    String? videoId;
    videoId = renderer['playlistItemData']?['videoId']?.toString();
    videoId ??= renderer['overlay']?['musicItemThumbnailOverlayRenderer']
            ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']
            ?['watchEndpoint']?['videoId']
        ?.toString();
    videoId ??= renderer['navigationEndpoint']?['watchEndpoint']?['videoId']
        ?.toString();
    videoId ??=
        renderer['doubleTapCommand']?['watchEndpoint']?['videoId']?.toString();
    videoId ??= nav(childItem, [
      'musicResponsiveListItemRenderer',
      'flexColumns',
      0,
      'musicResponsiveListItemFlexColumnRenderer',
      'text',
      'runs',
      0,
      'navigationEndpoint',
      'watchEndpoint',
      'videoId'
    ])?.toString();

    final String? browseId = renderer['navigationEndpoint']?['browseEndpoint']
            ?['browseId']
        ?.toString();

    final String lowerType = type.toLowerCase();
    String? id;
    if (lowerType == 'artist' ||
        lowerType == 'profile' ||
        lowerType == 'album' ||
        lowerType == 'playlist' ||
        lowerType == 'single') {
      id = browseId ?? videoId;
      if (lowerType == 'profile') type = 'Artist';
    } else {
      id = videoId ?? browseId;
      if (videoId != null && type != 'Video') {
        type = 'Song';
      }
    }

    if (id == null || id.isEmpty) return null;

    final String image = images.isNotEmpty ? images.first.toString() : '';
    final bool isPlayable = type == 'Song' || type == 'Video';

    return {
      'id': id,
      'type': type,
      'title': title,
      'artist': type == 'Artist' ? title : artist,
      'album': album,
      'duration': duration,
      'views': views,
      'year': year,
      'countSongs': countSongs,
      'subtitle': subtitle,
      'image': image,
      'images': images,
      'subscribers': subscribers,
      if (isPlayable) ...{
        'genre': 'YouTube',
        'language': 'YouTube',
        'perma_url': 'https://www.youtube.com/watch?v=$id',
        'url': 'https://www.youtube.com/watch?v=$id',
        'expire_at': '0',
      },
    };
  }

  Future<List<Map>> search(
    String query, {
    String? scope,
    bool ignoreSpelling = false,
    String? filter,
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['query'] = query;
      final params = getSearchParams(
        filter: filter,
        scope: scope,
        ignoreSpelling: ignoreSpelling,
      );
      if (params != null) {
        body['params'] = params;
      }
      final List<Map> searchResults = [];
      final res = await sendRequest(endpoints['search']!, body, headers);
      if (!res.containsKey('contents')) {
        Logger.root.info('YtMusic returned no contents');
        return List.empty();
      }

      Map<String, dynamic> results = {};

      if ((res['contents'] as Map).containsKey('tabbedSearchResultsRenderer')) {
        final tabIndex =
            (scope == null || filter != null) ? 0 : scopes.indexOf(scope) + 1;
        results = nav(res, [
          'contents',
          'tabbedSearchResultsRenderer',
          'tabs',
          tabIndex,
          'tabRenderer',
          'content'
        ]) as Map<String, dynamic>;
      } else {
        Logger.root.info('tabbedSearchResultsRenderer not found');
        results = res['contents'] as Map<String, dynamic>;
      }

      final List finalResults =
          nav(results, ['sectionListRenderer', 'contents']) as List? ?? [];
      for (final sectionItem in finalResults) {
        if (sectionItem is! Map) continue;

        // 1. Classical musicShelfRenderer
        if (sectionItem.containsKey('musicShelfRenderer')) {
          final shelf = sectionItem['musicShelfRenderer'] as Map;
          final String sectionTitle = (shelf['title']?['runs']?[0]?['text'] ??
                  'Top Result')
              .toString();
          final List sectionChildItems = (shelf['contents'] as List?) ?? [];
          final sectionSearchResults = [];
          for (final childItem in sectionChildItems) {
            if (childItem is Map) {
              final parsed = _parseResponsiveListItem(
                childItem,
                defaultSectionTitle: sectionTitle,
              );
              if (parsed != null) sectionSearchResults.add(parsed);
            }
          }
          if (sectionSearchResults.isNotEmpty) {
            searchResults.add({
              'title': sectionTitle,
              'items': sectionSearchResults,
            });
          }
        }
        // 2. Modern itemSectionRenderer
        else if (sectionItem.containsKey('itemSectionRenderer')) {
          final itemSection = sectionItem['itemSectionRenderer'] as Map;
          final List subContents = (itemSection['contents'] as List?) ?? [];
          for (final sub in subContents) {
            if (sub is Map) {
              if (sub.containsKey('musicShelfRenderer')) {
                final shelf = sub['musicShelfRenderer'] as Map;
                final String sectionTitle =
                    (shelf['title']?['runs']?[0]?['text'] ?? 'Results')
                        .toString();
                final List sectionChildItems =
                    (shelf['contents'] as List?) ?? [];
                final sectionSearchResults = [];
                for (final childItem in sectionChildItems) {
                  if (childItem is Map) {
                    final parsed = _parseResponsiveListItem(
                      childItem,
                      defaultSectionTitle: sectionTitle,
                    );
                    if (parsed != null) sectionSearchResults.add(parsed);
                  }
                }
                if (sectionSearchResults.isNotEmpty) {
                  searchResults.add({
                    'title': sectionTitle,
                    'items': sectionSearchResults,
                  });
                }
              } else if (sub.containsKey('musicResponsiveListItemRenderer')) {
                final parsed = _parseResponsiveListItem(sub);
                if (parsed != null) {
                  final String lower = parsed['type'].toString().toLowerCase();
                  final String sTitle = (lower == 'song' || lower == 'single')
                      ? 'Songs'
                      : (lower == 'video')
                          ? 'Videos'
                          : (lower == 'album')
                              ? 'Albums'
                              : (lower == 'artist')
                                  ? 'Artists'
                                  : 'Results';
                  final existingSection = searchResults.firstWhere(
                    (s) => s['title'] == sTitle,
                    orElse: () {
                      final newSection = {'title': sTitle, 'items': []};
                      searchResults.add(newSection);
                      return newSection;
                    },
                  );
                  (existingSection['items'] as List).add(parsed);
                }
              }
            }
          }
        }
        // 3. Top result card
        else if (sectionItem.containsKey('musicCardShelfRenderer')) {
          final card = sectionItem['musicCardShelfRenderer'] as Map;
          final List cardContents = (card['contents'] as List?) ?? [];
          final sectionSearchResults = [];
          for (final childItem in cardContents) {
            if (childItem is Map) {
              final parsed = _parseResponsiveListItem(
                childItem,
                defaultSectionTitle: 'Top Result',
              );
              if (parsed != null) sectionSearchResults.add(parsed);
            }
          }
          if (sectionSearchResults.isNotEmpty) {
            searchResults.insert(0, {
              'title': 'Top Result',
              'items': sectionSearchResults,
            });
          }
        }
      }
      return searchResults;
    } catch (e) {
      Logger.root.severe('Error in yt search', e);
      return List.empty();
    }
  }

  Future<List<String>> getSearchSuggestions({
    required String query,
    String? scope,
    bool ignoreSpelling = false,
    String? filter = 'songs',
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['input'] = query;
      final Map response =
          await sendRequest(endpoints['search_suggestions']!, body, headers);
      final List finalResult = nav(response, [
            'contents',
            0,
            'searchSuggestionsSectionRenderer',
            'contents'
          ]) as List? ??
          [];
      final List<String> results = [];
      for (final item in finalResult) {
        results.add(
          nav(item, [
            'searchSuggestionRenderer',
            'navigationEndpoint',
            'searchEndpoint',
            'query'
          ]).toString(),
        );
      }
      return results;
    } catch (e) {
      Logger.root.severe('Error in yt search suggestions', e);
      return List.empty();
    }
  }

  int getDatestamp() {
    final DateTime now = DateTime.now();
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final Duration difference = now.difference(epoch);
    final int days = difference.inDays;
    return days;
  }

  Future<Map> getSongData({required String videoId}) async {
    if (headers == null) {
      await init();
    }
    try {
      signatureTimestamp = signatureTimestamp ?? getDatestamp() - 1;
      final body = Map.from(context!);
      body['playbackContext'] = {
        'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
      };
      body['video_id'] = videoId;
      final Map response =
          await sendRequest(endpoints['get_song']!, body, headers);
      if (response.isEmpty) return {};

      int maxBitrate = 0;
      String? cipherUrl;
      String? directUrl;

      final dynamic formatsData =
          await nav(response, ['streamingData', 'formats']);
      if (formatsData is List) {
        for (final element in formatsData) {
          if (element is Map && element['bitrate'] != null) {
            final int bitrate =
                int.tryParse(element['bitrate'].toString()) ?? 0;
            if (bitrate > maxBitrate) {
              maxBitrate = bitrate;
              if (element['url'] != null) {
                directUrl = element['url'].toString();
              } else if (element['signatureCipher'] != null) {
                cipherUrl = element['signatureCipher'].toString();
              }
            }
          }
        }
      }

      String result = '';
      if (directUrl != null && directUrl.isNotEmpty) {
        result = directUrl;
      } else if (cipherUrl != null && cipherUrl.isNotEmpty) {
        final reg = RegExp(r'url=([^&]+)');
        final matches = reg.firstMatch(cipherUrl);
        if (matches != null && matches.group(1) != null) {
          result = Uri.decodeComponent(matches.group(1)!);
        }
      }

      final dynamic videoDetailsData = await nav(response, ['videoDetails']);
      if (videoDetailsData is! Map) {
        return {};
      }
      final Map videoDetails = videoDetailsData;

      final List thumbs =
          (videoDetails['thumbnail']?['thumbnails'] as List?) ?? [];
      final String image =
          thumbs.isNotEmpty ? thumbs.last['url']?.toString() ?? '' : '';

      return {
        'id': videoDetails['videoId']?.toString() ?? videoId,
        'title': videoDetails['title']?.toString() ?? '',
        'artist': videoDetails['author']?.toString() ?? '',
        'duration': videoDetails['lengthSeconds']?.toString() ?? '0',
        'url': result,
        'views': videoDetails['viewCount']?.toString() ?? '0',
        'image': image,
        'images': thumbs
            .map((e) => e is Map ? e['url'] : '')
            .where((u) => u != '')
            .toList(),
      };
    } catch (e) {
      Logger.root.severe('Error in yt get song data for $videoId', e);
      return {};
    }
  }

  Future<Map> getPlaylistDetails(String playlistId) async {
    if (headers == null) {
      await init();
    }
    try {
      final browseId = playlistIdExtender(playlistId);
      final body = Map.from(context!);
      body['browseId'] = browseId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);

      // 1. Locate Header (supports both twoColumnBrowseResultsRenderer and singleColumn / header)
      Map? header;
      if (response['header'] is Map) {
        final h = response['header'] as Map;
        header = (h['musicDetailHeaderRenderer'] as Map?) ??
            (h['musicResponsiveHeaderRenderer'] as Map?);
      }
      final twoCol =
          response['contents']?['twoColumnBrowseResultsRenderer'] as Map?;
      if (header == null && twoCol != null) {
        final tabs = twoCol['tabs'] as List? ?? [];
        if (tabs.isNotEmpty) {
          final secList = tabs[0]['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List? ?? [];
          for (final item in secList) {
            if (item is Map) {
              if (item['musicResponsiveHeaderRenderer'] != null) {
                header = item['musicResponsiveHeaderRenderer'] as Map;
                break;
              }
              if (item['musicDetailHeaderRenderer'] != null) {
                header = item['musicDetailHeaderRenderer'] as Map;
                break;
              }
            }
          }
        }
      }

      String? heading;
      String subtitle = '';
      String? description;
      List images = [];

      if (header != null) {
        heading = nav(header, ['title', 'runs', 0, 'text']) as String? ??
            (nav(header, ['title', 'runs']) as List?)
                ?.map((e) => e['text'])
                .join();

        subtitle = (nav(header, ['subtitle', 'runs']) as List? ?? [])
            .map((e) => e['text'])
            .toList()
            .join();

        description = nav(header, [
              'description',
              'musicDescriptionShelfRenderer',
              'description',
              'runs',
              0,
              'text'
            ]) as String? ??
            nav(header, ['description', 'runs', 0, 'text']) as String? ??
            (nav(header, ['description', 'runs']) as List?)
                ?.map((e) => e['text'])
                .join();

        final thumbs = nav(header, [
              'thumbnail',
              'musicThumbnailRenderer',
              'thumbnail',
              'thumbnails'
            ]) as List? ??
            nav(header, [
              'thumbnail',
              'croppedSquareThumbnailRenderer',
              'thumbnail',
              'thumbnails'
            ]) as List? ??
            [];
        images = thumbs.map((e) => e['url']).toList();
      }

      // 2. Locate Playlist Song Items (checks twoColumn secondaryContents, tabs, or singleColumn)
      List finalResults = [];
      if (twoCol != null) {
        final secContents = twoCol['secondaryContents']
            ?['sectionListRenderer']?['contents'] as List? ?? [];
        for (final sec in secContents) {
          if (sec is Map) {
            final shelf = sec['musicPlaylistShelfRenderer'] ??
                sec['musicShelfRenderer'];
            if (shelf != null && shelf['contents'] is List) {
              finalResults = shelf['contents'] as List;
              break;
            }
          }
        }
        if (finalResults.isEmpty) {
          final tabContents = twoCol['tabs']?[0]?['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List? ?? [];
          for (final item in tabContents) {
            if (item is Map) {
              final shelf = item['musicPlaylistShelfRenderer'] ??
                  item['musicShelfRenderer'];
              if (shelf != null && shelf['contents'] is List) {
                finalResults = shelf['contents'] as List;
                break;
              }
            }
          }
        }
      } else {
        finalResults = nav(response, [
              'contents',
              'singleColumnBrowseResultsRenderer',
              'tabs',
              0,
              'tabRenderer',
              'content',
              'sectionListRenderer',
              'contents',
              0,
              'musicPlaylistShelfRenderer',
              'contents'
            ]) as List? ??
            [];
      }

      final List<Map> songResults = [];
      for (final item in finalResults) {
        if (item is! Map) continue;
        final renderer =
            item['musicResponsiveListItemRenderer'] as Map? ?? item;

        // Video ID extraction with fallbacks
        String? id =
            nav(renderer, ['playlistItemData', 'videoId'])?.toString();
        if (id == null || id.isEmpty || id == 'null') {
          id = nav(renderer, [
            'overlay',
            'musicItemThumbnailOverlayRenderer',
            'content',
            'musicPlayButtonRenderer',
            'playNavigationEndpoint',
            'watchEndpoint',
            'videoId'
          ])?.toString();
        }
        if (id == null || id.isEmpty || id == 'null') {
          id = nav(renderer, [
            'flexColumns',
            0,
            'musicResponsiveListItemFlexColumnRenderer',
            'text',
            'runs',
            0,
            'navigationEndpoint',
            'watchEndpoint',
            'videoId'
          ])?.toString();
        }
        if (id == null || id.isEmpty || id == 'null') continue;

        // Image extraction
        final thumbs = nav(renderer, [
          'thumbnail',
          'musicThumbnailRenderer',
          'thumbnail',
          'thumbnails',
        ]) as List? ?? [];
        final String image = thumbs.isNotEmpty
            ? thumbs.last['url']?.toString() ?? ''
            : (images.isNotEmpty ? images.last.toString() : '');

        // Title extraction
        final String title = nav(renderer, [
              'flexColumns',
              0,
              'musicResponsiveListItemFlexColumnRenderer',
              'text',
              'runs',
              0,
              'text'
            ])?.toString() ??
            '';

        // Subtitle / artist / album / duration extraction
        final List subtitleList = (nav(renderer, [
              'flexColumns',
              1,
              'musicResponsiveListItemFlexColumnRenderer',
              'text',
              'runs'
            ]) as List?) ??
            [];

        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';

        for (final element in subtitleList) {
          if (element is! Map) continue;
          subtitle += element['text'].toString();
          if (element['text'].toString().trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }

        // Additional columns if available (e.g. duration or album in col 2 or col 3)
        final flexCols = renderer['flexColumns'] as List? ?? [];
        if (flexCols.length > 2 && duration.isEmpty) {
          final col2Runs = nav(renderer, [
            'flexColumns',
            2,
            'musicResponsiveListItemFlexColumnRenderer',
            'text',
            'runs'
          ]) as List? ?? [];
          for (final r in col2Runs) {
            final t = r['text']?.toString() ?? '';
            if (t.contains(':')) {
              duration = t;
              break;
            } else if (album.isEmpty && !t.contains('•')) {
              album = t;
            }
          }
        }
        if (flexCols.length > 3 && duration.isEmpty) {
          final col3Runs = nav(renderer, [
            'flexColumns',
            3,
            'musicResponsiveListItemFlexColumnRenderer',
            'text',
            'runs'
          ]) as List? ?? [];
          for (final r in col3Runs) {
            final t = r['text']?.toString() ?? '';
            if (t.contains(':')) {
              duration = t;
              break;
            }
          }
        }

        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album,
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': '',
          'expire_at': '0',
        });
      }

      // 3. Fallback to youtube_explode if InnerTube yielded 0 songs
      if (songResults.isEmpty) {
        try {
          final cleanId = playlistIdTrimmer(playlistId);
          final ytServices = YouTubeServices();
          final ytPlaylist = await ytServices.yt.playlists
              .get(cleanId)
              .timeout(const Duration(seconds: 12));
          heading ??= ytPlaylist.title;
          description ??= ytPlaylist.description;
          if (images.isEmpty && ytPlaylist.thumbnails.highResUrl.isNotEmpty) {
            images = [ytPlaylist.thumbnails.highResUrl];
          }
          await for (final video in ytServices.yt.playlists
              .getVideos(cleanId)
              .take(100)) {
            songResults.add({
              'id': video.id.value,
              'type': 'song',
              'title': video.title,
              'artist': video.author,
              'genre': 'YouTube',
              'language': 'YouTube',
              'year': '',
              'album_artist': video.author,
              'album': ytPlaylist.title,
              'duration': video.duration?.toString() ?? '',
              'subtitle': video.author,
              'image': video.thumbnails.highResUrl,
              'perma_url': 'https://www.youtube.com/watch?v=${video.id.value}',
              'url': 'https://www.youtube.com/watch?v=${video.id.value}',
              'release_date': '',
              'album_id': '',
              'expire_at': '0',
            });
          }
        } catch (e) {
          Logger.root.warning(
            'youtube_explode fallback in getPlaylistDetails for $playlistId: $e',
          );
        }
      }

      return {
        'songs': songResults,
        'name': heading ?? '',
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': playlistId,
        'type': 'playlist',
      };
    } catch (e) {
      Logger.root.severe('Error in ytmusic getPlaylistDetails', e);
      return {};
    }
  }

  Future<Map> getAlbumDetails(String albumId) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['browseId'] = albumId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);

      // Locate Header
      Map? header;
      if (response['header'] is Map) {
        final h = response['header'] as Map;
        header = (h['musicDetailHeaderRenderer'] as Map?) ??
            (h['musicResponsiveHeaderRenderer'] as Map?);
      }
      final twoCol =
          response['contents']?['twoColumnBrowseResultsRenderer'] as Map?;
      if (header == null && twoCol != null) {
        final tabs = twoCol['tabs'] as List? ?? [];
        if (tabs.isNotEmpty) {
          final secList = tabs[0]['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List? ?? [];
          for (final item in secList) {
            if (item is Map) {
              if (item['musicResponsiveHeaderRenderer'] != null) {
                header = item['musicResponsiveHeaderRenderer'] as Map;
                break;
              }
              if (item['musicDetailHeaderRenderer'] != null) {
                header = item['musicDetailHeaderRenderer'] as Map;
                break;
              }
            }
          }
        }
      }

      String? heading;
      String subtitle = '';
      String? description;
      List images = [];

      if (header != null) {
        heading = nav(header, ['title', 'runs', 0, 'text']) as String? ??
            (nav(header, ['title', 'runs']) as List?)
                ?.map((e) => e['text'])
                .join();

        subtitle = (nav(header, ['subtitle', 'runs']) as List? ?? [])
            .map((e) => e['text'])
            .toList()
            .join();

        description = nav(header, [
              'description',
              'musicDescriptionShelfRenderer',
              'description',
              'runs',
              0,
              'text'
            ]) as String? ??
            nav(header, ['description', 'runs', 0, 'text']) as String? ??
            (nav(header, ['description', 'runs']) as List?)
                ?.map((e) => e['text'])
                .join();

        final thumbs = nav(header, [
              'thumbnail',
              'musicThumbnailRenderer',
              'thumbnail',
              'thumbnails'
            ]) as List? ??
            nav(header, [
              'thumbnail',
              'croppedSquareThumbnailRenderer',
              'thumbnail',
              'thumbnails'
            ]) as List? ??
            [];
        images = thumbs.map((e) => e['url']).toList();
      }

      // Locate Album Song Items
      List finalResults = [];
      if (twoCol != null) {
        final secContents = twoCol['secondaryContents']
            ?['sectionListRenderer']?['contents'] as List? ?? [];
        for (final sec in secContents) {
          if (sec is Map) {
            final shelf = sec['musicShelfRenderer'] ??
                sec['musicPlaylistShelfRenderer'];
            if (shelf != null && shelf['contents'] is List) {
              finalResults = shelf['contents'] as List;
              break;
            }
          }
        }
        if (finalResults.isEmpty) {
          final tabContents = twoCol['tabs']?[0]?['tabRenderer']?['content']
              ?['sectionListRenderer']?['contents'] as List? ?? [];
          for (final item in tabContents) {
            if (item is Map) {
              final shelf = item['musicShelfRenderer'] ??
                  item['musicPlaylistShelfRenderer'];
              if (shelf != null && shelf['contents'] is List) {
                finalResults = shelf['contents'] as List;
                break;
              }
            }
          }
        }
      } else {
        finalResults = nav(response, [
              ...singleColumnTab,
              ...sectionListItem,
              ...musicShelf,
              'contents',
            ]) as List? ??
            [];
      }

      final List<Map> songResults = [];
      for (final item in finalResults) {
        if (item is! Map) continue;
        final renderer =
            item['musicResponsiveListItemRenderer'] as Map? ?? item;

        String? id =
            nav(renderer, ['playlistItemData', 'videoId'])?.toString();
        if (id == null || id.isEmpty || id == 'null') {
          id = nav(renderer, [
            'overlay',
            'musicItemThumbnailOverlayRenderer',
            'content',
            'musicPlayButtonRenderer',
            'playNavigationEndpoint',
            'watchEndpoint',
            'videoId'
          ])?.toString();
        }
        if (id == null || id.isEmpty || id == 'null') {
          id = nav(renderer, [
            'flexColumns',
            0,
            'musicResponsiveListItemFlexColumnRenderer',
            'text',
            'runs',
            0,
            'navigationEndpoint',
            'watchEndpoint',
            'videoId'
          ])?.toString();
        }
        if (id == null || id.isEmpty || id == 'null') continue;

        final thumbs = nav(renderer, [
          'thumbnail',
          'musicThumbnailRenderer',
          'thumbnail',
          'thumbnails',
        ]) as List? ?? [];
        final String image = thumbs.isNotEmpty
            ? thumbs.last['url']?.toString() ?? ''
            : (images.isNotEmpty ? images.last.toString() : '');

        final String title = nav(renderer, [
              'flexColumns',
              0,
              'musicResponsiveListItemFlexColumnRenderer',
              'text',
              'runs',
              0,
              'text'
            ])?.toString() ??
            '';

        final List subtitleList = (nav(renderer, [
              'flexColumns',
              1,
              'musicResponsiveListItemFlexColumnRenderer',
              'text',
              'runs'
            ]) as List?) ??
            [];

        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';

        for (final element in subtitleList) {
          if (element is! Map) continue;
          subtitle += element['text'].toString();
          if (element['text'].toString().trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }

        final flexCols = renderer['flexColumns'] as List? ?? [];
        if (flexCols.length > 2 && duration.isEmpty) {
          final col2Runs = nav(renderer, [
            'flexColumns',
            2,
            'musicResponsiveListItemFlexColumnRenderer',
            'text',
            'runs'
          ]) as List? ?? [];
          for (final r in col2Runs) {
            final t = r['text']?.toString() ?? '';
            if (t.contains(':')) {
              duration = t;
              break;
            } else if (album.isEmpty && !t.contains('•')) {
              album = t;
            }
          }
        }

        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album.isNotEmpty ? album : (heading ?? ''),
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': albumId,
          'expire_at': '0',
        });
      }

      return {
        'songs': songResults,
        'name': heading ?? '',
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': albumId,
        'type': 'album',
      };
    } catch (e) {
      Logger.root.severe('Error in ytmusic getAlbumDetails', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> getArtistDetails(String id) async {
    if (headers == null) {
      await init();
    }
    String artistId = id;
    if (artistId.startsWith('MPLA')) {
      artistId = artistId.substring(4);
    }
    try {
      final body = Map.from(context!);
      body['browseId'] = artistId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);
      // final header = response['header']['musicImmersiveHeaderRenderer']
      final String? heading =
          nav(response, [...immersiveHeaderDetail, ...titleText]) as String?;
      final String subtitle = joinRunTexts(
        nav(response, [...immersiveHeaderDetail, ...subtitleRuns]) as List? ??
            [],
      );
      final String description = joinRunTexts(
        nav(response, [...immersiveHeaderDetail, ...secondSubtitleRuns])
                as List? ??
            [],
      );
      final List images = runUrls(
        nav(response, [...immersiveHeaderDetail, ...thumbnails]) as List? ?? [],
      );
      final List finalResults = nav(response, [
            ...singleColumnTab,
            ...sectionList,
            0,
            ...musicShelf,
            'contents',
          ]) as List? ??
          [];
      final List<Map> songResults = [];
      for (final item in finalResults) {
        final String id = nav(item, mrlirPlaylistId).toString();
        final String image = nav(item, [
          mRLIR,
          ...thumbnails,
          0,
          'url',
        ]).toString();
        final String title = nav(item, [
          mRLIR,
          'flexColumns',
          0,
          mRLIFCR,
          ...textRunText,
        ]).toString();
        final List subtitleList = nav(item, [
              mRLIR,
              'flexColumns',
              1,
              mRLIFCR,
              ...textRuns,
            ]) as List? ??
            [];
        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';
        year = '';
        for (final element in subtitleList) {
          // ignore: use_string_buffers
          subtitle += element['text'].toString();
          if (element['text'].trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }
        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album,
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': '',
        });
      }
      return {
        'songs': songResults,
        'name': heading,
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': artistId,
        'type': 'artist',
      };
    } catch (e) {
      Logger.root.info('Error in ytmusic getArtistDetails', e);
      return {};
    }
  }

  Future<List<String>> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    int limit = 25,
    bool radio = false,
    bool shuffle = false,
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['enablePersistentPlaylistPanel'] = true;
      body['isAudioOnly'] = true;
      body['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';

      if (videoId == null && playlistId == null) {
        return [];
      }
      if (videoId != null) {
        body['videoId'] = videoId;
        playlistId ??= 'RDAMVM$videoId';
        if (!(radio || shuffle)) {
          body['watchEndpointMusicSupportedConfigs'] = {
            'watchEndpointMusicConfig': {
              'hasPersistentPlaylistPanel': true,
              'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV;',
            }
          };
        }
      }
      // bool is_playlist = false;

      body['playlistId'] = playlistIdTrimmer(playlistId!);
      // is_playlist = body['playlistId'].toString().startsWith('PL') ||
      //     body['playlistId'].toString().startsWith('OLA');

      if (shuffle) body['params'] = 'wAEB8gECKAE%3D';
      if (radio) body['params'] = 'wAEB';
      final Map response = await sendRequest(endpoints['next']!, body, headers);
      final Map results = nav(response, [
            'contents',
            'singleColumnMusicWatchNextResultsRenderer',
            'tabbedRenderer',
            'watchNextTabbedResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'musicQueueRenderer',
            'content',
            'playlistPanelRenderer',
          ]) as Map? ??
          {};
      final playlist = (results['contents'] as List<dynamic>).where(
        (x) =>
            nav(x, ['playlistPanelVideoRenderer', ...navigationPlaylistId]) !=
            null,
      );
      int count = 0;
      final List<String> songResults = [];
      for (final item in playlist) {
        if (count > 0) {
          final String id =
              nav(item, ['playlistPanelVideoRenderer', 'videoId']).toString();
          songResults.add(id);
        } else {
          count++;
        }
      }
      return songResults;
    } catch (e) {
      Logger.root.severe('Error in ytmusic getWatchPlaylist', e);
      return [];
    }
  }
}
