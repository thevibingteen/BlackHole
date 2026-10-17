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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeServices {
  static const String searchAuthority = 'www.youtube.com';
  static const Map paths = {
    'search': '/results',
    'channel': '/channel',
    'music': '/music',
    'playlist': '/playlist'
  };
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0'
  };
  final YoutubeExplode yt = YoutubeExplode();
  final Map<String, Future<List<String>>> _inFlightStreamRequests = {};

  Future<List<Video>> getPlaylistSongs(String id) async {
    try {
      final List<Video> results = await yt.playlists
          .getVideos(id)
          .toList()
          .timeout(const Duration(seconds: 15));
      return results;
    } catch (e) {
      Logger.root.severe('Error in getPlaylistSongs for $id: $e');
      return [];
    }
  }

  Future<Video?> getVideoFromId(String id) async {
    try {
      final Video result =
          await yt.videos.get(id).timeout(const Duration(seconds: 15));
      return result;
    } catch (e) {
      Logger.root.severe('Error while getting video from id $id', e);
      return null;
    }
  }

  Future<Map?> formatVideoFromId({
    required String id,
    Map? data,
    bool? getUrl,
  }) async {
    try {
      final Video? vid = await getVideoFromId(id);
      if (vid == null) {
        Logger.root.warning('getVideoFromId returned null for $id');
        return null;
      }
      String quality = 'Low';
      if (Hive.isBoxOpen('settings')) {
        quality = Hive.box('settings')
            .get(
              'ytQuality',
              defaultValue: 'Low',
            )
            .toString();
      }
      final Map? response = await formatVideo(
        video: vid,
        quality: quality,
        data: data,
        getUrl: getUrl ?? true,
      );
      return response;
    } catch (e) {
      Logger.root.severe('Error in formatVideoFromId for $id: $e');
      return null;
    }
  }

  Future<Map?> refreshLink(String id) async {
    try {
      final Video? res = await getVideoFromId(id);
      if (res == null) {
        return null;
      }
      String quality = 'Low';
      if (Hive.isBoxOpen('settings')) {
        quality = Hive.box('settings')
            .get('quality', defaultValue: 'Low')
            .toString();
      }
      final Map? data = await formatVideo(video: res, quality: quality);
      return data;
    } catch (e) {
      Logger.root.severe('Error in refreshLink for $id: $e');
      return null;
    }
  }

  Future<Playlist?> getPlaylistDetails(String id) async {
    try {
      final Playlist metadata =
          await yt.playlists.get(id).timeout(const Duration(seconds: 15));
      return metadata;
    } catch (e) {
      Logger.root.severe('Error in getPlaylistDetails for $id: $e');
      return null;
    }
  }

  Future<Map<String, List>> getMusicHome() async {
    final Uri link = Uri.https(
      searchAuthority,
      paths['music'].toString(),
    );
    try {
      final Response response = await get(link, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        Logger.root.warning('getMusicHome returned HTTP ${response.statusCode}');
        return {};
      }

      final String body = utf8.decode(response.bodyBytes);
      Map? data;

      // 1. Try ytInitialData regex
      final RegExp ytDataRegex =
          RegExp(r'var ytInitialData\s*=\s*({.*?});</script>', dotAll: true);
      final match = ytDataRegex.firstMatch(body);
      if (match != null) {
        try {
          data = json.decode(match.group(1)!) as Map?;
        } catch (e) {
          Logger.root.warning('Failed to parse ytInitialData JSON: $e');
        }
      }

      // 2. Fallback to legacy regex
      if (data == null) {
        final RegExp legacyRegex =
            RegExp(r'(\"contents\":{.*?}),\"metadata\"', dotAll: true);
        final legacyMatch = legacyRegex.firstMatch(body);
        if (legacyMatch != null) {
          try {
            data = json.decode('{${legacyMatch.group(1)!}}') as Map?;
          } catch (e) {
            Logger.root.warning('Failed to parse legacy JSON: $e');
          }
        }
      }

      if (data == null) {
        Logger.root.warning('Could not extract JSON data from YouTube /music page');
        return {};
      }

      final List finalResult = [];
      List finalHeadResult = [];

      // A. Try modern richGridRenderer
      try {
        final List tabs = data['contents']?['twoColumnBrowseResultsRenderer']
                ?['tabs'] as List? ??
            [];
        if (tabs.isNotEmpty && tabs[0] is Map) {
          final tabContent = tabs[0]['tabRenderer']?['content'];
          if (tabContent != null && tabContent['richGridRenderer'] != null) {
            final List gridContents =
                tabContent['richGridRenderer']['contents'] as List? ?? [];
            for (final c in gridContents) {
              if (c is! Map) continue;
              final rsr =
                  c['richSectionRenderer']?['content']?['richShelfRenderer'];
              if (rsr is! Map) continue;

              final String title = rsr['title']?['simpleText']?.toString() ??
                  (rsr['title']?['runs'] is List &&
                          (rsr['title']['runs'] as List).isNotEmpty
                      ? rsr['title']['runs'][0]['text']?.toString() ?? 'Music'
                      : 'Music');

              final List shelfItems = [];
              final List items = rsr['contents'] as List? ?? [];
              for (final it in items) {
                if (it is! Map) continue;
                final lvm =
                    it['richItemRenderer']?['content']?['lockupViewModel'];
                if (lvm is! Map) continue;

                final meta = lvm['metadata']?['lockupMetadataViewModel'];
                final String itemTitle =
                    meta?['title']?['content']?.toString() ?? '';
                if (itemTitle.isEmpty) continue;

                final List rows = meta?['metadata']?['contentMetadataViewModel']
                        ?['metadataRows'] as List? ??
                    [];
                final List<String> descParts = [];
                for (final r in rows) {
                  if (r is! Map) continue;
                  final List parts = r['metadataParts'] as List? ?? [];
                  for (final p in parts) {
                    if (p is Map) {
                      final t = p['text']?['content']?.toString();
                      if (t != null && t.isNotEmpty) descParts.add(t);
                    }
                  }
                }
                final String desc = descParts.take(2).join(' • ');

                // Image thumbnail
                List imgSources = lvm['contentImage']
                            ?['collectionThumbnailViewModel']
                        ?['primaryThumbnail']?['thumbnailViewModel']?['image']
                    ?['sources'] as List? ??
                    [];
                if (imgSources.isEmpty) {
                  imgSources = lvm['contentImage']?['thumbnailViewModel']
                      ?['image']?['sources'] as List? ??
                      [];
                }
                final String imgUrl = imgSources.isNotEmpty
                    ? imgSources.last['url']?.toString() ?? ''
                    : '';

                // Playlist / Video ID
                final String contentId = lvm['contentId']?.toString() ?? '';
                final cmd = lvm['rendererContext']?['commandContext']?['onTap']
                    ?['innertubeCommand'];
                final String playlistId =
                    cmd?['watchPlaylistEndpoint']?['playlistId']?.toString() ??
                        contentId;
                final String videoId =
                    cmd?['watchEndpoint']?['videoId']?.toString() ?? '';

                shelfItems.add({
                  'title': itemTitle,
                  'type': playlistId.isNotEmpty ? 'playlist' : 'video',
                  'description': desc,
                  'count': '',
                  'playlistId': playlistId,
                  'firstItemId': videoId.isNotEmpty ? videoId : contentId,
                  'image': imgUrl,
                  'imageMedium': imgUrl,
                  'imageStandard': imgUrl,
                  'imageMax': imgUrl,
                });
              }

              if (shelfItems.isNotEmpty) {
                finalResult.add({
                  'title': title,
                  'playlists': shelfItems,
                });
              }
            }
          }
        }
      } catch (e) {
        Logger.root.warning('Error parsing richGridRenderer in getMusicHome: $e');
      }

      // B. If modern parser yielded nothing, fallback to legacy sectionListRenderer
      if (finalResult.isEmpty) {
        try {
          final List result = data['contents']?['twoColumnBrowseResultsRenderer']
                  ?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']
              ?['contents'] as List? ??
              [];

          final List headResult = data['header']?['carouselHeaderRenderer']
                  ?['contents']?[0]?['carouselItemRenderer']?['carouselItems']
              as List? ??
              [];

          final List shelfRenderer = result
              .map((element) {
                return element['itemSectionRenderer']?['contents']?[0]
                    ?['shelfRenderer'];
              })
              .where((e) => e != null)
              .toList();

          for (final element in shelfRenderer) {
            if (element is! Map) continue;
            final String title =
                element['title']?['runs']?[0]?['text']?.toString() ?? '';
            final List items = element['content']?['horizontalListRenderer']
                    ?['items'] as List? ??
                [];
            final playlistItems = (title.trim() == 'Charts' ||
                    title.trim() == 'Classements')
                ? formatChartItems(items)
                : (title.contains('Music Videos') ||
                        title.contains('Nouveaux clips') ||
                        title.contains('En Musique Avec Moi') ||
                        title.contains('Performances Uniques'))
                    ? formatVideoItems(items)
                    : formatItems(items);
            if (playlistItems.isNotEmpty) {
              finalResult.add({
                'title': title,
                'playlists': playlistItems,
              });
            }
          }
          finalHeadResult = formatHeadItems(headResult);
        } catch (e) {
          Logger.root.warning('Error in legacy getMusicHome parsing: $e');
        }
      }

      return {'body': finalResult, 'head': finalHeadResult};
    } catch (e) {
      Logger.root.severe('Error in getMusicHome: $e');
      return {};
    }
  }

  Future<List> getSearchSuggestions({required String query}) async {
    const baseUrl =
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=';
    final Uri link = Uri.parse(baseUrl + query);
    try {
      final Response response =
          await get(link, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return [];
      }
      final unescape = HtmlUnescape();
      final List res =
          (jsonDecode(utf8.decode(response.bodyBytes)) as List)[1] as List;
      return res.map((e) => unescape.convert(e.toString())).toList();
    } catch (e) {
      Logger.root.severe('Error in getSearchSuggestions: $e');
      return [];
    }
  }

  List formatVideoItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['gridVideoRenderer']['title']['simpleText'],
          'type': 'video',
          'description': e['gridVideoRenderer']['shortBylineText']['runs'][0]
              ['text'],
          'count': e['gridVideoRenderer']['shortViewCountText']['simpleText'],
          'videoId': e['gridVideoRenderer']['videoId'],
          'firstItemId': e['gridVideoRenderer']['videoId'],
          'image':
              e['gridVideoRenderer']['thumbnail']['thumbnails'].last['url'],
          'imageMin': e['gridVideoRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['gridVideoRenderer']['thumbnail']['thumbnails'][1]
              ['url'],
          'imageStandard': e['gridVideoRenderer']['thumbnail']['thumbnails'][2]
              ['url'],
          'imageMax':
              e['gridVideoRenderer']['thumbnail']['thumbnails'].last['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatVideoItems: $e');
      return List.empty();
    }
  }

  List formatChartItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['gridPlaylistRenderer']['title']['runs'][0]['text'],
          'type': 'chart',
          'description': e['gridPlaylistRenderer']['shortBylineText']['runs'][0]
              ['text'],
          'count': e['gridPlaylistRenderer']['videoCountText']['runs'][0]
              ['text'],
          'playlistId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['playlistId'],
          'firstItemId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'image': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageStandard': e['gridPlaylistRenderer']['thumbnail']['thumbnails']
              [0]['url'],
          'imageMax': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatChartItems: $e');
      return List.empty();
    }
  }

  List formatItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['gridPlaylistRenderer']['title']['runs'][0]['text'],
          'type': 'playlist',
          'description': e['gridPlaylistRenderer']['shortBylineText']['runs'][0]
              ['text'],
          'count': e['gridPlaylistRenderer']['videoCountText']['runs'][0]
              ['text'],
          'playlistId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['playlistId'],
          'firstItemId': e['gridPlaylistRenderer']['navigationEndpoint']
              ['watchEndpoint']['videoId'],
          'image': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageMedium': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
          'imageStandard': e['gridPlaylistRenderer']['thumbnail']['thumbnails']
              [0]['url'],
          'imageMax': e['gridPlaylistRenderer']['thumbnail']['thumbnails'][0]
              ['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatItems: $e');
      return List.empty();
    }
  }

  List formatHeadItems(List itemsList) {
    try {
      final List result = itemsList.map((e) {
        return {
          'title': e['defaultPromoPanelRenderer']['title']['runs'][0]['text'],
          'type': 'video',
          'description': (e['defaultPromoPanelRenderer']['description']['runs']
                  as List)
              .map((e) => e['text'])
              .toList()
              .join(),
          'navigationEndpoint': e['defaultPromoPanelRenderer']
              ['navigationEndpoint']['watchEndpoint']['videoId'],
          'image': e['defaultPromoPanelRenderer']
                  ['largeFormFactorBackgroundThumbnail']
              ['thumbnailLandscapePortraitRenderer']['landscape']['thumbnails'][0]
              ['url'],
          'imageMedium': e['defaultPromoPanelRenderer']
                  ['largeFormFactorBackgroundThumbnail']
              ['thumbnailLandscapePortraitRenderer']['landscape']['thumbnails'][1]
              ['url'],
          'imageStandard': e['defaultPromoPanelRenderer']
                  ['largeFormFactorBackgroundThumbnail']
              ['thumbnailLandscapePortraitRenderer']['landscape']['thumbnails'][2]
              ['url'],
          'imageMax': e['defaultPromoPanelRenderer']
                          ['largeFormFactorBackgroundThumbnail']
                      ['thumbnailLandscapePortraitRenderer']['landscape']
                  ['thumbnails']
              .last['url'],
        };
      }).toList();

      return result;
    } catch (e) {
      Logger.root.severe('Error in formatHeadItems: $e');
      return List.empty();
    }
  }

  Future<Map?> formatVideo({
    required Video video,
    required String quality,
    Map? data,
    bool getUrl = true,
  }) async {
    if (video.duration?.inSeconds == null) return null;
    List<String> urls = [];
    String finalUrl = '';
    String expireAt = '0';
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (getUrl) {
      try {
        // check cache first
        if (Hive.isBoxOpen('ytlinkcache') &&
            Hive.box('ytlinkcache').containsKey(video.id.value)) {
          final Map? cachedData =
              Hive.box('ytlinkcache').get(video.id.value) as Map?;
          final int cachedExpiredAt =
              int.tryParse(cachedData?['expire_at']?.toString() ?? '') ?? 0;
          final String cachedUrl = cachedData?['url']?.toString() ?? '';

          if (cachedUrl.isNotEmpty && (now + 350 <= cachedExpiredAt)) {
            // giving valid cache link
            Logger.root.info('Valid cache found for ${video.id.value}');
            urls = [cachedUrl];
            finalUrl = cachedUrl;
            expireAt = cachedExpiredAt.toString();
          } else {
            // cache expired or invalid
            urls = await getUri(video);
          }
        } else {
          // cache not present
          urls = await getUri(video);
        }

        if (urls.isNotEmpty) {
          finalUrl = quality == 'High' ? urls.last : urls.first;
          final match = RegExp(r'expire=([0-9]+)').firstMatch(finalUrl);
          final int parsedExpire = match != null
              ? (int.tryParse(match.group(1)!) ?? (now + 18000))
              : (now + 18000);
          expireAt = parsedExpire.toString();

          if (Hive.isBoxOpen('ytlinkcache')) {
            try {
              await Hive.box('ytlinkcache').put(
                video.id.value,
                {
                  'url': finalUrl,
                  'expire_at': expireAt,
                  'quality': quality,
                  'lowUrl': urls.first,
                  'highUrl': urls.last,
                  'cached_at': now,
                },
              );
            } catch (e) {
              Logger.root.severe('Hive Error in formatVideo cache save: $e');
            }
          }
        } else {
          Logger.root.warning(
            'No stream URLs resolved for YouTube video ${video.id.value}',
          );
          return null;
        }
      } catch (e) {
        Logger.root.severe('Error resolving stream in formatVideo: $e');
        return null;
      }
    }
    return {
      'id': video.id.value,
      'album': (data?['album'] ?? '') != ''
          ? data!['album']
          : video.author.replaceAll('- Topic', '').trim(),
      'duration': video.duration?.inSeconds.toString(),
      'title':
          (data?['title'] ?? '') != '' ? data!['title'] : video.title.trim(),
      'artist': (data?['artist'] ?? '') != ''
          ? data!['artist']
          : video.author.replaceAll('- Topic', '').trim(),
      'image': video.thumbnails.maxResUrl,
      'secondImage': video.thumbnails.highResUrl,
      'language': 'YouTube',
      'genre': 'YouTube',
      'expire_at': expireAt,
      'url': finalUrl,
      'lowUrl': urls.isNotEmpty ? urls.first : '',
      'highUrl': urls.isNotEmpty ? urls.last : '',
      'year': video.uploadDate?.year.toString(),
      '320kbps': 'false',
      'has_lyrics': 'false',
      'release_date': video.publishDate.toString(),
      'album_id': video.channelId.value,
      'subtitle':
          (data?['subtitle'] ?? '') != '' ? data!['subtitle'] : video.author,
      'perma_url': video.url,
    };
  }

  Future<List<Map>> fetchSearchResults(String query) async {
    try {
      final List<Video> searchResults =
          await yt.search.search(query).timeout(const Duration(seconds: 15));
      final List<Map> videoResult = [];
      for (final Video vid in searchResults) {
        final res =
            await formatVideo(video: vid, quality: 'High', getUrl: false);
        if (res != null) videoResult.add(res);
      }
      return [
        {
          'title': 'Videos',
          'items': videoResult,
        }
      ];
    } catch (e) {
      Logger.root.severe('Error in fetchSearchResults for $query: $e');
      return [];
    }
  }

  Future<List<String>> getUri(Video video) async {
    // In-flight request deduplication to prevent duplicate concurrent network streams
    if (_inFlightStreamRequests.containsKey(video.id.value)) {
      return _inFlightStreamRequests[video.id.value]!;
    }

    final Future<List<String>> fetchFuture = _fetchUriInternal(video);
    _inFlightStreamRequests[video.id.value] = fetchFuture;
    try {
      final result = await fetchFuture;
      return result;
    } finally {
      _inFlightStreamRequests.remove(video.id.value);
    }
  }

  Future<List<String>> _fetchUriInternal(Video video) async {
    try {
      final StreamManifest manifest = await yt.videos.streamsClient
          .getManifest(video.id)
          .timeout(const Duration(seconds: 15));
      final List<AudioOnlyStreamInfo> sortedStreamInfo =
          manifest.audioOnly.sortByBitrate();

      if (sortedStreamInfo.isEmpty) {
        final muxed = manifest.muxed.sortByBitrate();
        if (muxed.isNotEmpty) {
          return [muxed.first.url.toString(), muxed.last.url.toString()];
        }
        return [];
      }

      if (Platform.isIOS || Platform.isMacOS) {
        final List<AudioOnlyStreamInfo> m4aStreams = sortedStreamInfo
            .where((element) => element.audioCodec.contains('mp4'))
            .toList();

        if (m4aStreams.isNotEmpty) {
          return [
            m4aStreams.first.url.toString(),
            m4aStreams.last.url.toString(),
          ];
        }
      }
      return [
        sortedStreamInfo.first.url.toString(),
        sortedStreamInfo.last.url.toString(),
      ];
    } catch (e) {
      Logger.root.severe(
        'Error getting YouTube stream manifest for ${video.id.value}: $e',
      );
      return [];
    }
  }
}
