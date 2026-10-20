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

import 'package:hive_flutter/hive_flutter.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeStreamCandidate {
  final String videoId;
  final String url;
  final String mimeType;
  final String audioCodec;
  final int bitrate;
  final bool isAudioOnly;
  final int? expireAt;
  final String resolver;

  YouTubeStreamCandidate({
    required this.videoId,
    required this.url,
    required this.mimeType,
    required this.audioCodec,
    required this.bitrate,
    required this.isAudioOnly,
    this.expireAt,
    required this.resolver,
  });

  bool get isValid =>
      url.isNotEmpty &&
      url != 'null' &&
      Uri.tryParse(url)?.hasAbsolutePath == true &&
      (url.contains('googlevideo.com') || url.contains('youtube.com'));
}

List<String> selectStreamUrls(List<YouTubeStreamCandidate> candidates) {
  final valid = candidates.where((c) => c.isValid).toList();
  if (valid.isEmpty) return [];

  // Filter for audio-only streams first
  final audioOnly = valid.where((c) => c.isAudioOnly).toList();
  final usable = audioOnly.isNotEmpty ? audioOnly : valid;

  // Sort by bitrate ascending (lowest is Low, highest is High)
  usable.sort((a, b) => a.bitrate.compareTo(b.bitrate));

  final String low = usable.first.url;
  final String high = usable.last.url;
  return [low, high];
}

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

  static String extractThumbnailUrl(
    dynamic raw, {
    String? videoId,
    int index = -1,
  }) {
    List candidateList = [];

    if (raw is List) {
      candidateList = raw;
    } else if (raw is Map) {
      if (raw['thumbnails'] is List) {
        candidateList = raw['thumbnails'] as List;
      } else if (raw['sources'] is List) {
        candidateList = raw['sources'] as List;
      } else if (raw['image'] is Map && raw['image']['sources'] is List) {
        candidateList = raw['image']['sources'] as List;
      } else if (raw['url'] != null) {
        candidateList = [raw];
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      String url = raw.trim();
      if (url.startsWith('//')) {
        url = 'https:$url';
      }
      return url;
    }

    final flattened = <dynamic>[];
    for (final item in candidateList) {
      if (item is List) {
        flattened.addAll(item);
      } else if (item != null) {
        flattened.add(item);
      }
    }

    if (flattened.isNotEmpty) {
      Map? chosen;
      if (index >= 0 && index < flattened.length) {
        chosen = flattened[index] is Map ? flattened[index] as Map : null;
      } else {
        final target = (index < 0) ? flattened.last : flattened.first;
        chosen = target is Map ? target as Map : null;
      }

      final rawUrl = chosen?['url']?.toString().trim();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        if (rawUrl.startsWith('//')) {
          return 'https:$rawUrl';
        }
        return rawUrl;
      }
    }

    if (videoId != null &&
        videoId.length == 11 &&
        !videoId.startsWith('PL') &&
        !videoId.startsWith('RD') &&
        !videoId.startsWith('UC')) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }

    return '';
  }

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
      final String entryPoint = (data?['type'] ?? 'direct').toString();
      final String videoTitle = (data?['title'] ?? id).toString();
      Logger.root.info(
        'formatVideoFromId | id: $id, entryPoint: $entryPoint, title: "$videoTitle", getUrl: $getUrl',
      );

      String quality = 'Low';
      if (Hive.isBoxOpen('settings')) {
        quality = Hive.box('settings')
            .get(
              'ytQuality',
              defaultValue: 'Low',
            )
            .toString();
      }

      final Video? vid = await getVideoFromId(id);
      if (vid != null) {
        final Map? response = await formatVideo(
          video: vid,
          quality: quality,
          data: data,
          getUrl: getUrl ?? true,
        );
        if (response != null) {
          return response;
        }
      }

      // If getVideoFromId failed or formatVideo returned null, resolve directly via InnerTube
      if (getUrl ?? true) {
        Logger.root.info(
          'formatVideoFromId | falling back to InnerTube stream resolution for $id',
        );
        return await formatVideoFromInnerTube(
          id: id,
          quality: quality,
          data: data,
        );
      }

      return null;
    } catch (e) {
      Logger.root.severe('Error in formatVideoFromId for $id: $e');
      return null;
    }
  }

  Future<Map?> refreshLink(String id) async {
    try {
      String quality = 'Low';
      if (Hive.isBoxOpen('settings')) {
        quality = Hive.box('settings')
            .get('ytQuality', defaultValue: 'Low')
            .toString();
      }
      // Invalidate cache before refreshing to ensure fresh stream URL from provider
      if (Hive.isBoxOpen('ytlinkcache')) {
        await Hive.box('ytlinkcache').delete(id);
      }
      Logger.root.info(
        'refreshLink | id: $id, cache invalidated, resolving fresh stream (quality: $quality)',
      );

      final Video? res = await getVideoFromId(id);
      if (res != null) {
        final Map? data = await formatVideo(video: res, quality: quality);
        if (data != null) {
          return data;
        }
      }

      // Fall back to direct InnerTube stream resolution
      return await formatVideoFromInnerTube(id: id, quality: quality);
    } catch (e) {
      Logger.root.severe('Error in refreshLink for $id: $e');
      return null;
    }
  }

  Future<Playlist> getPlaylistDetails(String id) async {
    try {
      final Playlist metadata =
          await yt.playlists.get(id).timeout(const Duration(seconds: 15));
      return metadata;
    } catch (e) {
      Logger.root.severe('Error in getPlaylistDetails for $id: $e');
      rethrow;
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
        Logger.root
            .warning('getMusicHome returned HTTP ${response.statusCode}');
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
        Logger.root
            .warning('Could not extract JSON data from YouTube /music page');
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
                            ?['primaryThumbnail']?['thumbnailViewModel']
                        ?['image']?['sources'] as List? ??
                    [];
                if (imgSources.isEmpty) {
                  imgSources = lvm['contentImage']?['thumbnailViewModel']
                          ?['image']?['sources'] as List? ??
                      [];
                }
                final String imgUrl = imgSources.isNotEmpty
                    ? imgSources.last['url']?.toString() ?? ''
                    : '';

                // Structured navigation endpoint parsing
                final String contentType =
                    lvm['contentType']?.toString() ?? '';
                final String contentId = lvm['contentId']?.toString() ?? '';
                final cmd = lvm['rendererContext']?['commandContext']?['onTap']
                    ?['innertubeCommand'];

                String? playlistId =
                    cmd?['watchPlaylistEndpoint']?['playlistId']?.toString();
                playlistId ??= cmd?['watchEndpoint']?['playlistId']?.toString();
                playlistId ??= cmd?['browseEndpoint']?['browseId']?.toString();

                final String? videoId =
                    cmd?['watchEndpoint']?['videoId']?.toString();

                String itemType = 'playlist';
                if (contentType == 'LOCKUP_CONTENT_TYPE_VIDEO' ||
                    (videoId != null &&
                        videoId.isNotEmpty &&
                        (playlistId == null || playlistId.isEmpty))) {
                  itemType = 'video';
                  playlistId = '';
                } else if (playlistId != null && playlistId.isNotEmpty) {
                  itemType = 'playlist';
                } else if (contentId.isNotEmpty) {
                  if (contentId.startsWith('PL') ||
                      contentId.startsWith('RD') ||
                      contentId.startsWith('OL') ||
                      contentId.startsWith('VL')) {
                    itemType = 'playlist';
                    playlistId = contentId;
                  } else if (contentId.length == 11) {
                    itemType = 'video';
                    playlistId = '';
                  } else {
                    itemType = 'playlist';
                    playlistId = contentId;
                  }
                } else {
                  continue;
                }

                shelfItems.add({
                  'title': itemTitle,
                  'type': itemType,
                  'description': desc,
                  'count': '',
                  'playlistId': playlistId ?? '',
                  'firstItemId': (videoId != null && videoId.isNotEmpty)
                      ? videoId
                      : contentId,
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
        Logger.root
            .warning('Error parsing richGridRenderer in getMusicHome: $e');
      }

      // B. If modern parser yielded nothing, fallback to legacy sectionListRenderer
      if (finalResult.isEmpty) {
        try {
          final List result = data['contents']
                          ?['twoColumnBrowseResultsRenderer']?['tabs']?[0]
                      ?['tabRenderer']?['content']?['sectionListRenderer']
                  ?['contents'] as List? ??
              [];

          final List headResult = data['header']?['carouselHeaderRenderer']
                      ?['contents']?[0]?['carouselItemRenderer']
                  ?['carouselItems'] as List? ??
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
            final playlistItems =
                (title.trim() == 'Charts' || title.trim() == 'Classements')
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
      final Response response = await get(link, headers: headers)
          .timeout(const Duration(seconds: 10));
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
        final renderer = (e is Map ? e['gridVideoRenderer'] : null) as Map? ?? {};
        final videoId = renderer['videoId']?.toString() ?? '';
        final thumbs = renderer['thumbnail'];

        final imageMax =
            extractThumbnailUrl(thumbs, videoId: videoId, index: -1);
        final imageMin =
            extractThumbnailUrl(thumbs, videoId: videoId, index: 0);
        final imageMed =
            extractThumbnailUrl(thumbs, videoId: videoId, index: 1);
        final imageStd =
            extractThumbnailUrl(thumbs, videoId: videoId, index: 2);

        final String title = renderer['title']?['simpleText']?.toString() ??
            renderer['title']?['runs']?[0]?['text']?.toString() ??
            '';
        final String desc =
            renderer['shortBylineText']?['runs']?[0]?['text']?.toString() ?? '';
        final String count =
            renderer['shortViewCountText']?['simpleText']?.toString() ?? '';

        return {
          'title': title,
          'type': 'video',
          'description': desc,
          'count': count,
          'videoId': videoId,
          'firstItemId': videoId,
          'image': imageMax,
          'imageMin': imageMin.isNotEmpty ? imageMin : imageMax,
          'imageMedium': imageMed.isNotEmpty ? imageMed : imageMax,
          'imageStandard': imageStd.isNotEmpty ? imageStd : imageMax,
          'imageMax': imageMax,
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
        final renderer =
            (e is Map ? e['gridPlaylistRenderer'] : null) as Map? ?? {};
        final firstItemId = renderer['navigationEndpoint']?['watchEndpoint']
                ?['videoId']
            ?.toString();
        final playlistId = renderer['navigationEndpoint']?['watchEndpoint']
                ?['playlistId']
            ?.toString() ??
            '';
        final thumbs = renderer['thumbnail'];

        final img = extractThumbnailUrl(thumbs, videoId: firstItemId, index: -1);

        final String title =
            renderer['title']?['runs']?[0]?['text']?.toString() ?? '';
        final String desc =
            renderer['shortBylineText']?['runs']?[0]?['text']?.toString() ?? '';
        final String count =
            renderer['videoCountText']?['runs']?[0]?['text']?.toString() ?? '';

        return {
          'title': title,
          'type': 'chart',
          'description': desc,
          'count': count,
          'playlistId': playlistId,
          'firstItemId': firstItemId ?? '',
          'image': img,
          'imageMedium': img,
          'imageStandard': img,
          'imageMax': img,
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
        final renderer =
            (e is Map ? e['gridPlaylistRenderer'] : null) as Map? ?? {};
        final firstItemId = renderer['navigationEndpoint']?['watchEndpoint']
                ?['videoId']
            ?.toString();
        final playlistId = renderer['navigationEndpoint']?['watchEndpoint']
                ?['playlistId']
            ?.toString() ??
            '';
        final thumbs = renderer['thumbnail'];

        final img = extractThumbnailUrl(thumbs, videoId: firstItemId, index: -1);

        final String title =
            renderer['title']?['runs']?[0]?['text']?.toString() ?? '';
        final String desc =
            renderer['shortBylineText']?['runs']?[0]?['text']?.toString() ?? '';
        final String count =
            renderer['videoCountText']?['runs']?[0]?['text']?.toString() ?? '';

        return {
          'title': title,
          'type': 'playlist',
          'description': desc,
          'count': count,
          'playlistId': playlistId,
          'firstItemId': firstItemId ?? '',
          'image': img,
          'imageMedium': img,
          'imageStandard': img,
          'imageMax': img,
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
        final renderer =
            (e is Map ? e['defaultPromoPanelRenderer'] : null) as Map? ?? {};
        final videoId = renderer['navigationEndpoint']?['watchEndpoint']
                ?['videoId']
            ?.toString();
        final thumbs = renderer['largeFormFactorBackgroundThumbnail']
            ?['thumbnailLandscapePortraitRenderer']?['landscape']?['thumbnails'];

        final imgMax = extractThumbnailUrl(thumbs, videoId: videoId, index: -1);
        final imgMin = extractThumbnailUrl(thumbs, videoId: videoId, index: 0);
        final imgMed = extractThumbnailUrl(thumbs, videoId: videoId, index: 1);
        final imgStd = extractThumbnailUrl(thumbs, videoId: videoId, index: 2);

        final String title =
            renderer['title']?['runs']?[0]?['text']?.toString() ?? '';
        final String desc = ((renderer['description']?['runs'] as List?) ?? [])
            .map((e) => e is Map ? e['text']?.toString() ?? '' : e.toString())
            .toList()
            .join();

        return {
          'title': title,
          'type': 'video',
          'description': desc,
          'navigationEndpoint': videoId ?? '',
          'image': imgMin.isNotEmpty ? imgMin : imgMax,
          'imageMedium': imgMed.isNotEmpty ? imgMed : imgMax,
          'imageStandard': imgStd.isNotEmpty ? imgStd : imgMax,
          'imageMax': imgMax,
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
    final int durSec = video.duration?.inSeconds ??
        int.tryParse(data?['duration']?.toString() ?? '') ??
        180;
    final String durationStr = durSec.toString();

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
          final String cachedQuality = cachedData?['quality']?.toString() ?? '';
          final String cachedLow = cachedData?['lowUrl']?.toString() ?? '';
          final String cachedHigh = cachedData?['highUrl']?.toString() ?? '';

          final bool notExpired = now + 350 <= cachedExpiredAt;
          final String chosenUrl = (quality == 'High' && cachedHigh.isNotEmpty)
              ? cachedHigh
              : (cachedLow.isNotEmpty ? cachedLow : cachedUrl);

          if (chosenUrl.isNotEmpty &&
              notExpired &&
              (cachedQuality == quality ||
                  (cachedLow.isNotEmpty && cachedHigh.isNotEmpty))) {
            // giving valid cache link
            Logger.root.info(
              '[Stage 1: Cache Check] Cache HIT for ${video.id.value} (quality: $quality, expires in ${cachedExpiredAt - now}s)',
            );
            urls = [
              cachedLow.isNotEmpty ? cachedLow : chosenUrl,
              cachedHigh.isNotEmpty ? cachedHigh : chosenUrl
            ];
            finalUrl = chosenUrl;
            expireAt = cachedExpiredAt.toString();
          } else {
            // cache expired, invalid, or quality mismatch
            final String reason = !notExpired
                ? 'expired'
                : (chosenUrl.isEmpty
                    ? 'invalid URL'
                    : 'quality mismatch ($cachedQuality != $quality)');
            Logger.root.info(
              '[Stage 1: Cache Check] Cache REFRESH for ${video.id.value} ($reason), fetching fresh manifest',
            );
            urls = await getUri(video);
          }
        } else {
          // cache not present
          Logger.root.info(
            '[Stage 1: Cache Check] Cache MISS for ${video.id.value}, fetching fresh manifest',
          );
          urls = await getUri(video);
        }

        if (urls.isEmpty) {
          Logger.root.info(
            'formatVideo | getUri returned 0 URLs for ${video.id.value}, attempting InnerTube fallback',
          );
          final Map? fallbackMap = await formatVideoFromInnerTube(
            id: video.id.value,
            quality: quality,
            data: data,
          );
          if (fallbackMap != null) {
            return fallbackMap;
          }
          Logger.root.warning(
            '[Stage 5: Final Result] No stream URLs resolved for YouTube video ${video.id.value}',
          );
          return null;
        }

        finalUrl = quality == 'High' ? urls.last : urls.first;
        final match = RegExp('expire=([0-9]+)').firstMatch(finalUrl);
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
      'duration': durationStr,
      'title':
          (data?['title'] ?? '') != '' ? data!['title'] : video.title.trim(),
      'artist': (data?['artist'] ?? '') != ''
          ? data!['artist']
          : video.author.replaceAll('- Topic', '').trim(),
      'image': extractThumbnailUrl(
        video.thumbnails.maxResUrl.isNotEmpty
            ? video.thumbnails.maxResUrl
            : video.thumbnails.highResUrl,
        videoId: video.id.value,
      ),
      'secondImage': extractThumbnailUrl(
        video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.standardResUrl,
        videoId: video.id.value,
      ),
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
      if (videoResult.isNotEmpty) {
        return [
          {
            'title': 'Videos',
            'items': videoResult,
          }
        ];
      }
    } catch (e) {
      Logger.root.warning(
        'yt.search.search failed for "$query": $e, attempting InnerTube search fallback',
      );
    }

    try {
      final List<Map> fallbackResults = await searchInnerTube(query);
      if (fallbackResults.isNotEmpty) {
        Logger.root.info(
          'InnerTube search fallback succeeded for "$query" (${fallbackResults.length} results)',
        );
        return [
          {
            'title': 'Videos',
            'items': fallbackResults,
          }
        ];
      }
    } catch (e) {
      Logger.root.severe('InnerTube search fallback failed for "$query": $e');
    }

    return [];
  }

  Future<List<Map>> searchInnerTube(String query) async {
    try {
      final Uri uri = Uri.parse('https://www.youtube.com/youtubei/v1/search');
      final body = json.encode({
        'query': query,
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '21.26.364',
            'androidSdkVersion': 30,
            'userAgent':
                'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
            'osName': 'Android',
            'osVersion': '11',
            'hl': 'en',
            'gl': 'US',
          },
        },
      });

      final headers = {
        'Content-Type': 'application/json',
        'User-Agent':
            'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '21.26.364',
      };

      final Response res = await post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];

      final data = json.decode(utf8.decode(res.bodyBytes));
      final contents =
          data['contents']?['sectionListRenderer']?['contents'] as List? ?? [];
      final List<Map> results = [];

      for (final sec in contents) {
        final itemSec =
            sec['itemSectionRenderer']?['contents'] as List? ?? [];
        for (final item in itemSec) {
          final vid = item['videoRenderer'] ?? item['compactVideoRenderer'];
          if (vid != null && vid['videoId'] != null) {
            final String videoId = vid['videoId'].toString();
            final String title =
                vid['title']?['runs']?[0]?['text']?.toString() ??
                    vid['title']?['simpleText']?.toString() ??
                    '';
            final String author =
                vid['ownerText']?['runs']?[0]?['text']?.toString() ??
                    vid['shortBylineText']?['runs']?[0]?['text']?.toString() ??
                    '';
            final String durationStr =
                vid['lengthText']?['simpleText']?.toString() ??
                    vid['lengthText']?['runs']?[0]?['text']?.toString() ??
                    '180';
            final String thumbUrl = extractThumbnailUrl(
              vid['thumbnail']?['thumbnails'],
              videoId: videoId,
            );

            if (title.isNotEmpty) {
              results.add({
                'id': videoId,
                'title': title,
                'artist': author.replaceAll('- Topic', '').trim(),
                'album': author.replaceAll('- Topic', '').trim(),
                'duration': durationStr,
                'image': thumbUrl,
                'secondImage': thumbUrl,
                'language': 'YouTube',
                'genre': 'YouTube',
                'perma_url': 'https://www.youtube.com/watch?v=$videoId',
                'url': 'https://www.youtube.com/watch?v=$videoId',
                'expire_at': '0',
                '320kbps': 'false',
                'has_lyrics': 'false',
              });
            }
          }
        }
      }
      return results;
    } catch (e) {
      Logger.root.warning('Error in searchInnerTube for "$query": $e');
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

  Future<Map<String, dynamic>?> _requestInnerTubePlayer(String videoId) async {
    try {
      final Uri uri = Uri.parse('https://www.youtube.com/youtubei/v1/player');
      final body = json.encode({
        'videoId': videoId,
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '21.26.364',
            'androidSdkVersion': 30,
            'userAgent':
                'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
            'osName': 'Android',
            'osVersion': '11',
            'hl': 'en',
            'gl': 'US',
          },
        },
        'contentCheckOk': true,
        'racyCheckOk': true,
      });

      final headers = {
        'Content-Type': 'application/json',
        'User-Agent':
            'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '21.26.364',
      };

      final Response res = await post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>?;
      } else {
        Logger.root.warning(
          'InnerTube player returned HTTP ${res.statusCode} for $videoId',
        );
      }
    } catch (e) {
      Logger.root.severe('Error in _requestInnerTubePlayer for $videoId: $e');
    }
    return null;
  }

  Future<List<String>> fetchStreamsFromInnerTube(String videoId) async {
    final Map<String, dynamic>? data = await _requestInnerTubePlayer(videoId);
    if (data == null) return [];

    final Map<String, dynamic>? streamingData =
        data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return [];

    final List formats = streamingData['formats'] as List? ?? [];
    final List adaptiveFormats =
        streamingData['adaptiveFormats'] as List? ?? [];

    final List<YouTubeStreamCandidate> candidates = [];

    // 1. Prioritize direct audio streams from adaptiveFormats
    for (final f in adaptiveFormats) {
      if (f is! Map) continue;
      final String url = f['url']?.toString() ?? '';
      if (url.isEmpty || url == 'null') continue;
      final String mime = f['mimeType']?.toString() ?? '';
      if (!mime.contains('audio')) continue; // Reject video-only streams

      final codecMatch = RegExp(r'codecs="([^"]+)"').firstMatch(mime);
      final String codec = codecMatch?.group(1) ?? 'audio';
      final int bitrate = int.tryParse(f['bitrate']?.toString() ?? '') ??
          int.tryParse(f['averageBitrate']?.toString() ?? '') ??
          128000;
      final match = RegExp(r'expire=([0-9]+)').firstMatch(url);
      final int? exp = match != null ? int.tryParse(match.group(1)!) : null;

      candidates.add(
        YouTubeStreamCandidate(
          videoId: videoId,
          url: url,
          mimeType: mime,
          audioCodec: codec,
          bitrate: bitrate,
          isAudioOnly: true,
          expireAt: exp,
          resolver: 'innertube_adaptive',
        ),
      );
    }

    // 2. Also collect progressive formats (e.g. itag 18 mp4 with AAC audio)
    if (candidates.isEmpty) {
      for (final f in formats) {
        if (f is! Map) continue;
        final String url = f['url']?.toString() ?? '';
        if (url.isEmpty || url == 'null') continue;
        final String mime = f['mimeType']?.toString() ?? '';
        if (!mime.contains('mp4a') &&
            !mime.contains('aac') &&
            !mime.contains('opus') &&
            f['audioQuality'] == null) continue;

        final codecMatch = RegExp(r'codecs="([^"]+)"').firstMatch(mime);
        final String codec = codecMatch?.group(1) ?? 'muxed_audio';
        final int bitrate =
            int.tryParse(f['bitrate']?.toString() ?? '') ?? 128000;
        final match = RegExp(r'expire=([0-9]+)').firstMatch(url);
        final int? exp = match != null ? int.tryParse(match.group(1)!) : null;

        candidates.add(
          YouTubeStreamCandidate(
            videoId: videoId,
            url: url,
            mimeType: mime,
            audioCodec: codec,
            bitrate: bitrate,
            isAudioOnly: false,
            expireAt: exp,
            resolver: 'innertube_progressive',
          ),
        );
      }
    }

    return selectStreamUrls(candidates);
  }

  Future<Map?> formatVideoFromInnerTube({
    required String id,
    required String quality,
    Map? data,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check cache first
    if (Hive.isBoxOpen('ytlinkcache') &&
        Hive.box('ytlinkcache').containsKey(id)) {
      final Map? cachedData = Hive.box('ytlinkcache').get(id) as Map?;
      final int cachedExpiredAt =
          int.tryParse(cachedData?['expire_at']?.toString() ?? '') ?? 0;
      final String cachedUrl = cachedData?['url']?.toString() ?? '';
      final String cachedLow = cachedData?['lowUrl']?.toString() ?? '';
      final String cachedHigh = cachedData?['highUrl']?.toString() ?? '';

      final bool notExpired = now + 350 <= cachedExpiredAt;
      final String chosenUrl = (quality == 'High' && cachedHigh.isNotEmpty)
          ? cachedHigh
          : (cachedLow.isNotEmpty ? cachedLow : cachedUrl);

      if (chosenUrl.isNotEmpty && notExpired) {
        Logger.root.info(
          'formatVideoFromInnerTube | Cache HIT for $id (expires in ${cachedExpiredAt - now}s)',
        );
        return {
          'id': id,
          'album': data?['album']?.toString() ?? '',
          'duration': data?['duration']?.toString() ?? '180',
          'title': data?['title']?.toString() ?? id,
          'artist': data?['artist']?.toString() ?? '',
          'image': data?['image']?.toString() ?? '',
          'secondImage': data?['secondImage']?.toString() ?? '',
          'language': 'YouTube',
          'genre': 'YouTube',
          'expire_at': cachedExpiredAt.toString(),
          'url': chosenUrl,
          'lowUrl': cachedLow.isNotEmpty ? cachedLow : chosenUrl,
          'highUrl': cachedHigh.isNotEmpty ? cachedHigh : chosenUrl,
          'year': data?['year']?.toString() ?? '',
          '320kbps': 'false',
          'has_lyrics': 'false',
          'release_date': data?['release_date']?.toString() ?? '',
          'album_id': data?['album_id']?.toString() ?? '',
          'subtitle': data?['subtitle']?.toString() ?? '',
          'perma_url': 'https://youtube.com/watch?v=$id',
        };
      }
    }

    final Map<String, dynamic>? playerResponse =
        await _requestInnerTubePlayer(id);
    if (playerResponse == null) return null;

    final Map<String, dynamic>? videoDetails =
        playerResponse['videoDetails'] as Map<String, dynamic>?;

    final Map<String, dynamic>? streamingData =
        playerResponse['streamingData'] as Map<String, dynamic>?;

    final List formats = streamingData?['formats'] as List? ?? [];
    final List adaptiveFormats =
        streamingData?['adaptiveFormats'] as List? ?? [];

    final List<String> urls = [];

    for (final f in adaptiveFormats) {
      if (f is Map &&
          f['mimeType']?.toString().contains('audio') == true &&
          f['url'] != null &&
          f['url'].toString().isNotEmpty) {
        urls.add(f['url'].toString());
      }
    }

    for (final f in formats) {
      if (f is Map && f['url'] != null && f['url'].toString().isNotEmpty) {
        urls.add(f['url'].toString());
      }
    }

    if (urls.isEmpty) {
      Logger.root.warning('No stream URLs found in InnerTube response for $id');
      return null;
    }

    final String finalUrl = quality == 'High' ? urls.last : urls.first;
    final match = RegExp('expire=([0-9]+)').firstMatch(finalUrl);
    final int parsedExpire = match != null
        ? (int.tryParse(match.group(1)!) ?? (now + 18000))
        : (now + 18000);
    final String expireAt = parsedExpire.toString();

    if (Hive.isBoxOpen('ytlinkcache')) {
      try {
        await Hive.box('ytlinkcache').put(
          id,
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
        Logger.root
            .severe('Hive Error in formatVideoFromInnerTube cache save: $e');
      }
    }

    final String thumbUrl = extractThumbnailUrl(
      videoDetails?['thumbnail']?['thumbnails'],
      videoId: id,
    );

    final String title = (data?['title']?.toString() ?? '').isNotEmpty
        ? data!['title'].toString()
        : (videoDetails?['title']?.toString() ?? id);

    final String artist = (data?['artist']?.toString() ?? '').isNotEmpty
        ? data!['artist'].toString()
        : (videoDetails?['author']?.toString() ?? '');

    final String duration = (data?['duration']?.toString() ?? '').isNotEmpty
        ? data!['duration'].toString()
        : (videoDetails?['lengthSeconds']?.toString() ?? '180');

    final String image = (data?['image']?.toString() ?? '').isNotEmpty
        ? data!['image'].toString()
        : thumbUrl;

    return {
      'id': id,
      'album': (data?['album']?.toString() ?? '').isNotEmpty
          ? data!['album'].toString()
          : artist,
      'duration': duration,
      'title': title.trim(),
      'artist': artist.replaceAll('- Topic', '').trim(),
      'image': image,
      'secondImage': thumbUrl,
      'language': 'YouTube',
      'genre': 'YouTube',
      'expire_at': expireAt,
      'url': finalUrl,
      'lowUrl': urls.first,
      'highUrl': urls.last,
      'year': data?['year']?.toString() ?? '',
      '320kbps': 'false',
      'has_lyrics': 'false',
      'release_date': data?['release_date']?.toString() ?? '',
      'album_id': videoDetails?['channelId']?.toString() ?? '',
      'subtitle': (data?['subtitle']?.toString() ?? '').isNotEmpty
          ? data!['subtitle'].toString()
          : artist,
      'perma_url': 'https://youtube.com/watch?v=$id',
    };
  }

  Future<List<String>> _fetchUriInternal(Video video) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    // 1. Prioritize youtube_explode manifest extraction for pure audio-only streams
    try {
      final StreamManifest manifest = await yt.videos.streamsClient
          .getManifest(video.id)
          .timeout(const Duration(seconds: 35));
      stopwatch.stop();

      final List<YouTubeStreamCandidate> candidates = [];
      for (final s in manifest.audioOnly) {
        final String streamUrl = s.url.toString();
        if (streamUrl.isEmpty || streamUrl == 'null') continue;
        final match = RegExp(r'expire=([0-9]+)').firstMatch(streamUrl);
        final int? exp = match != null ? int.tryParse(match.group(1)!) : null;
        candidates.add(
          YouTubeStreamCandidate(
            videoId: video.id.value,
            url: streamUrl,
            mimeType: s.container.name,
            audioCodec: s.audioCodec,
            bitrate: s.bitrate.bitsPerSecond,
            isAudioOnly: true,
            expireAt: exp,
            resolver: 'youtube_explode_audio_only',
          ),
        );
      }

      if (candidates.isEmpty) {
        for (final s in manifest.muxed) {
          final String streamUrl = s.url.toString();
          if (streamUrl.isEmpty || streamUrl == 'null') continue;
          if (!s.audioCodec.contains('mp4a') &&
              !s.audioCodec.contains('opus') &&
              !s.audioCodec.contains('aac')) continue;
          final match = RegExp(r'expire=([0-9]+)').firstMatch(streamUrl);
          final int? exp = match != null ? int.tryParse(match.group(1)!) : null;
          candidates.add(
            YouTubeStreamCandidate(
              videoId: video.id.value,
              url: streamUrl,
              mimeType: s.container.name,
              audioCodec: s.audioCodec,
              bitrate: s.bitrate.bitsPerSecond,
              isAudioOnly: false,
              expireAt: exp,
              resolver: 'youtube_explode_muxed',
            ),
          );
        }
      }

      final List<String> urls = selectStreamUrls(candidates);
      if (urls.isNotEmpty) {
        Logger.root.info(
          '[Stage 2: Manifest Extraction] Succeeded in ${stopwatch.elapsedMilliseconds}ms for ${video.id.value} | '
          'Candidates: ${candidates.length} | '
          'Low: ${candidates.first.bitrate ~/ 1000}kbps (${candidates.first.audioCodec}) | '
          'High: ${candidates.last.bitrate ~/ 1000}kbps (${candidates.last.audioCodec})',
        );
        return urls;
      } else {
        Logger.root.warning(
          '[Stage 2: Manifest Extraction] Empty valid streams for ${video.id.value} after ${stopwatch.elapsedMilliseconds}ms, falling back to InnerTube',
        );
      }
    } catch (e) {
      Logger.root.warning(
        '[Stage 2: Manifest Extraction] Failed for ${video.id.value} after ${stopwatch.elapsedMilliseconds}ms '
        '(${e.runtimeType}): $e, falling back to [Stage 4: InnerTube Fallback]',
      );
    }

    // 2. Fallback to InnerTube mobile player endpoint
    try {
      final innerWatch = Stopwatch()..start();
      final List<String> innerTubeUrls =
          await fetchStreamsFromInnerTube(video.id.value);
      innerWatch.stop();
      if (innerTubeUrls.isNotEmpty) {
        Logger.root.info(
          '[Stage 4: InnerTube Fallback] Succeeded in ${innerWatch.elapsedMilliseconds}ms for ${video.id.value} '
          '(${innerTubeUrls.length} stream URLs resolved)',
        );
        return innerTubeUrls;
      } else {
        Logger.root.warning(
          '[Stage 4: InnerTube Fallback] Returned 0 stream URLs for ${video.id.value} after ${innerWatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      Logger.root.severe(
        '[Stage 4: InnerTube Fallback] Failed for ${video.id.value} (${e.runtimeType}): $e',
      );
    }

    Logger.root.severe(
      '[Stage 5: Final Result] Failed to resolve any stream URL for ${video.id.value}',
    );
    return [];
  }
}

