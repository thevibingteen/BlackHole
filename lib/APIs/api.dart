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

import 'package:blackhole/Helpers/format.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

enum LanguageAvailability {
  available,
  unavailable,
  unknown,
}

class SaavnAPI {
  static const Duration availabilityCacheTtl = Duration(hours: 24);

  List preferredLanguages = Hive.box('settings')
      .get('preferredLanguage', defaultValue: ['Hindi']) as List;
  Map<String, String> headers = {};
  String baseUrl = 'www.jiosaavn.com';
  String apiStr = '/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0';
  Box settingsBox = Hive.box('settings');
  Map<String, String> endpoints = {
    'homeData': '__call=webapi.getLaunchData',
    'topSearches': '__call=content.getTopSearches',
    'fromToken': '__call=webapi.get',
    'featuredRadio': '__call=webradio.createFeaturedStation',
    'artistRadio': '__call=webradio.createArtistStation',
    'entityRadio': '__call=webradio.createEntityStation',
    'radioSongs': '__call=webradio.getSong',
    'songDetails': '__call=song.getDetails',
    'playlistDetails': '__call=playlist.getDetails',
    'albumDetails': '__call=content.getAlbumDetails',
    'getResults': '__call=search.getResults',
    'albumResults': '__call=search.getAlbumResults',
    'artistResults': '__call=search.getArtistResults',
    'playlistResults': '__call=search.getPlaylistResults',
    'getReco': '__call=reco.getreco',
    'getAlbumReco': '__call=reco.getAlbumReco', // still not used
    'artistOtherTopSongs':
        '__call=search.artistOtherTopSongs', // still not used
  };

  /// Determine availability from a parsed launch data response for a specific language.
  static LanguageAvailability determineAvailabilityFromLaunchData(
    Map data,
    String language,
  ) {
    try {
      final String langLower = language.trim().toLowerCase();
      final modules = (data['modules'] as Map?) ?? {};
      if (modules.isEmpty) {
        return LanguageAvailability.unknown;
      }

      int langItemsCount = 0;

      for (final entry in modules.entries) {
        final modKey = entry.key.toString();
        final modMeta = entry.value;
        final String title =
            (modMeta is Map ? modMeta['title']?.toString() : '') ?? '';
        final items = data[modKey];

        if (items is! List || items.isEmpty) continue;

        // 1. Check if the module title explicitly references this language
        final bool hasLangTitle = title.toLowerCase().contains(langLower);

        // 2. Check if individual items have matching language tags
        final bool hasLangItems = items.any((item) {
          if (item is! Map) return false;
          final itemLang = (item['language'] ??
                  item['more_info']?['language'] ??
                  item['more_info']?['editorial_language'])
              ?.toString()
              .toLowerCase();
          return itemLang == langLower;
        });

        if (hasLangTitle || hasLangItems) {
          langItemsCount += items.length;
        }
      }

      if (langItemsCount > 0) {
        return LanguageAvailability.available;
      }
      return LanguageAvailability.unavailable;
    } catch (e) {
      Logger.root.severe('Error determining availability for $language: $e');
      return LanguageAvailability.unknown;
    }
  }

  /// Check availability of a specific language with 24-hour Hive caching.
  Future<LanguageAvailability> checkLanguageAvailability(
    String language, {
    bool forceRefresh = false,
  }) async {
    final String langNormalized = language.trim();
    final String langKey = langNormalized.toLowerCase();

    // 1. Check cache if not forcing refresh
    if (!forceRefresh && Hive.isBoxOpen('cache')) {
      final cacheBox = Hive.box('cache');
      final Map cachedAvail = (cacheBox.get('languageAvailability', defaultValue: {}) as Map?) ?? {};
      if (cachedAvail.containsKey(langKey)) {
        final entry = cachedAvail[langKey];
        if (entry is Map) {
          final int timestamp = (entry['timestamp'] as int?) ?? 0;
          final int now = DateTime.now().millisecondsSinceEpoch;
          if (now - timestamp < availabilityCacheTtl.inMilliseconds) {
            final String status = entry['status']?.toString() ?? '';
            if (status == 'available') return LanguageAvailability.available;
            if (status == 'unavailable') return LanguageAvailability.unavailable;
          }
        }
      }
    }

    // 2. Query JioSaavn launchData isolated to this language
    try {
      final Uri url = Uri.parse('https://$baseUrl$apiStr&${endpoints['homeData']}');
      final Map<String, String> reqHeaders = {
        'cookie': 'L=$langKey',
        'Accept': '*/*',
        'User-Agent': 'Mozilla/5.0',
      };

      final res = await get(url, headers: reqHeaders)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        Logger.root.warning('checkLanguageAvailability HTTP ${res.statusCode} for $language');
        return LanguageAvailability.unknown;
      }

      final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) {
        return LanguageAvailability.unknown;
      }

      final availability = determineAvailabilityFromLaunchData(decoded, langNormalized);

      // Only cache confirmed 'available' or 'unavailable' (transient 'unknown' is NOT cached)
      if (availability != LanguageAvailability.unknown && Hive.isBoxOpen('cache')) {
        try {
          final cacheBox = Hive.box('cache');
          final Map cachedAvail = Map<String, dynamic>.from(
            (cacheBox.get('languageAvailability', defaultValue: {}) as Map?) ?? {},
          );
          cachedAvail[langKey] = {
            'status': availability == LanguageAvailability.available ? 'available' : 'unavailable',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          await cacheBox.put('languageAvailability', cachedAvail);
        } catch (e) {
          Logger.root.severe('Error saving language availability cache: $e');
        }
      }

      return availability;
    } catch (e) {
      Logger.root.severe('Error in checkLanguageAvailability for $language: $e');
      return LanguageAvailability.unknown;
    }
  }

  /// Concurrently validate multiple languages with bounded concurrency (3 max)
  Future<Map<String, LanguageAvailability>> validateLanguages(
    List<String> languages, {
    bool forceRefresh = false,
  }) async {
    final Map<String, LanguageAvailability> results = {};
    if (languages.isEmpty) return results;

    for (int i = 0; i < languages.length; i += 3) {
      final end = (i + 3 < languages.length) ? i + 3 : languages.length;
      final batch = languages.sublist(i, end);
      final futures = batch.map((lang) async {
        final avail = await checkLanguageAvailability(lang, forceRefresh: forceRefresh);
        return MapEntry(lang, avail);
      });
      final batchResults = await Future.wait(futures);
      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
    }
    return results;
  }

  Future<Response> getResponse(
    String params, {
    bool usev4 = true,
    bool useProxy = false,
  }) async {
    final String query = usev4
        ? '$apiStr&$params'
        : '$apiStr&$params'.replaceAll('&api_version=4', '');
    final Uri url = Uri.parse('https://$baseUrl$query');

    if (Hive.isBoxOpen('settings')) {
      preferredLanguages = Hive.box('settings')
          .get('preferredLanguage', defaultValue: ['Hindi']) as List;
    }
    preferredLanguages =
        preferredLanguages.map((lang) => lang.toString().toLowerCase()).toList();
    final String languageHeader = 'L=${preferredLanguages.join('%2C')}';
    headers = {'cookie': languageHeader, 'Accept': '*/*'};

    const timeoutDuration = Duration(seconds: 15);
    if (useProxy && settingsBox.get('useProxy', defaultValue: false) as bool) {
      final String proxyIP = settingsBox.get('proxyIp').toString();
      final proxyHeaders = headers;
      proxyHeaders['X-FORWARDED-FOR'] = proxyIP;
      final res = await get(url, headers: proxyHeaders)
          .timeout(timeoutDuration)
          .onError((error, stackTrace) {
        Logger.root.severe('Proxy network error fetching $url: $error');
        return Response(
          jsonEncode({
            'status': 'failure',
            'error': error.toString(),
          }),
          404,
        );
      });
      if (res.statusCode != 200) {
        Logger.root.warning(
          'JioSaavn proxy request to $url returned HTTP ${res.statusCode}',
        );
      }
      return res;
    }
    final res = await get(url, headers: headers)
        .timeout(timeoutDuration)
        .onError((error, stackTrace) {
      Logger.root.severe('Network error fetching $url: $error');
      return Response(
        jsonEncode({
          'status': 'failure',
          'error': error.toString(),
        }),
        404,
      );
    });
    if (res.statusCode != 200) {
      Logger.root.warning(
        'JioSaavn request to $url returned HTTP ${res.statusCode}',
      );
    }
    return res;
  }

  Future<Map> fetchHomePageData() async {
    Map result = {};
    try {
      final res = await getResponse(endpoints['homeData']!);
      if (res.statusCode == 200) {
        final Map data = json.decode(utf8.decode(res.bodyBytes)) as Map;
        result = await FormatResponse.formatHomePageData(data);
      } else {
        Logger.root.warning(
          'fetchHomePageData returned HTTP ${res.statusCode}',
        );
      }
    } catch (e) {
      Logger.root.severe('Error in fetchHomePageData: $e');
    }
    return result;
  }

  Future<Map> getSongFromToken(
    String token,
    String type, {
    int n = 10,
    int p = 1,
  }) async {
    if (n == -1) {
      final String params =
          "token=$token&type=$type&n=5&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = json.decode(utf8.decode(res.bodyBytes)) as Map;
          final String count = getMain['list_count'].toString();
          final String params2 =
              "token=$token&type=$type&n=$count&p=$p&${endpoints['fromToken']}";
          final res2 = await getResponse(params2);
          if (res2.statusCode == 200) {
            final Map getMain2 = json.decode(utf8.decode(res2.bodyBytes)) as Map;
            if (type == 'album' || type == 'playlist') return getMain2;
            final List responseList = getMain2['songs'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
              'title': getMain2['title'],
            };
          }
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken with -1: $e');
      }
      return {'songs': List.empty()};
    } else {
      final String params =
          "token=$token&type=$type&n=$n&p=$p&${endpoints['fromToken']}";
      try {
        final res = await getResponse(params);
        if (res.statusCode == 200) {
          final Map getMain = json.decode(utf8.decode(res.bodyBytes)) as Map;
          if (getMain['status'] == 'failure') {
            Logger.root.severe('Error in getSongFromToken response: $getMain');
            return {'songs': List.empty()};
          }
          if (type == 'album' || type == 'playlist') {
            return getMain;
          }
          if (type == 'show') {
            final List responseList = getMain['episodes'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
            };
          }
          if (type == 'mix') {
            final List responseList = getMain['list'] as List;
            return {
              'songs':
                  await FormatResponse.formatSongsResponse(responseList, type),
            };
          }
          final List responseList = getMain['songs'] as List;
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, type),
            'title': getMain['title'],
          };
        }
      } catch (e) {
        Logger.root.severe('Error in getSongFromToken: $e');
      }
      return {'songs': List.empty()};
    }
  }

  Future<List> getReco(String pid) async {
    final String params = "${endpoints['getReco']}&pid=$pid";
    final res = await getResponse(params);
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final List getMain = json.decode(utf8.decode(res.bodyBytes)) as List;
      return FormatResponse.formatSongsResponse(getMain, 'song');
    } else {
      Logger.root.severe(
        'Error in getReco returned status: ${res.statusCode}, response: ${res.body}',
      );
    }
    return List.empty();
  }

  Future<String?> createRadio({
    required List<String> names,
    required String stationType,
    String? language,
  }) async {
    try {
      if (names.isEmpty || names[0].trim().isEmpty) return null;
      final rawName = names[0].trim();
      final encodedName = Uri.encodeComponent(rawName);

      String? activeLang = (language != null && language.trim().isNotEmpty)
          ? language.trim().toLowerCase()
          : null;
      if (activeLang == null) {
        if (Hive.isBoxOpen('settings')) {
          final List preferred = Hive.box('settings')
              .get('preferredLanguage', defaultValue: ['Hindi']) as List;
          if (preferred.isNotEmpty) {
            activeLang = preferred.first.toString().trim().toLowerCase();
          }
        }
      }
      activeLang ??= 'hindi';

      String params;
      if (stationType == 'featured') {
        params =
            "name=$encodedName&language=$activeLang&${endpoints['featuredRadio']}";
      } else if (stationType == 'artist') {
        params =
            "name=$encodedName&query=$encodedName&language=$activeLang&${endpoints['artistRadio']}";
      } else if (stationType == 'entity') {
        final encodedList =
            names.map((e) => '"${Uri.encodeComponent(e)}"').toList();
        params =
            'entity_id=$encodedList&entity_type=queue&${endpoints["entityRadio"]}';
      } else {
        params =
            "name=$encodedName&query=$encodedName&language=$activeLang&${endpoints['featuredRadio']}";
      }

      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final stationId =
              decoded['stationid'] ?? decoded['station_id'] ?? decoded['id'];
          if (stationId != null && stationId.toString().trim().isNotEmpty) {
            return stationId.toString().trim();
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error inside createRadio: $e');
    }
    return null;
  }

  Future<List> getRadioSongs({
    required String stationId,
    int count = 20,
    int next = 1,
  }) async {
    try {
      final cleanStationId = stationId.trim();
      if (cleanStationId.isEmpty || count <= 0) return [];
      final encodedStationId = Uri.encodeComponent(cleanStationId);
      final String params =
          "stationid=$encodedStationId&k=$count&next=$next&${endpoints['radioSongs']}";
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        final List responseList = [];
        if (decoded is Map) {
          for (int i = 0; i < count; i++) {
            final entry = decoded[i.toString()];
            if (entry is Map && entry['song'] != null && entry['song'] is Map) {
              responseList.add(entry['song']);
            }
          }
          if (responseList.isEmpty) {
            decoded.forEach((key, val) {
              if (val is Map && val['song'] != null && val['song'] is Map) {
                responseList.add(val['song']);
              }
            });
          }
          return await FormatResponse.formatSongsResponse(responseList, 'song');
        } else if (decoded is List) {
          return await FormatResponse.formatSongsResponse(decoded, 'song');
        }
      }
    } catch (e) {
      Logger.root.severe('Error inside getRadioSongs: $e');
    }
    return [];
  }

  Future<List<String>> getTopSearches() async {
    try {
      final res = await getResponse(endpoints['topSearches']!, useProxy: true);
      if (res.statusCode == 200) {
        final List getMain = json.decode(utf8.decode(res.bodyBytes)) as List;
        return getMain.map((element) {
          return element['title'].toString();
        }).toList();
      }
    } catch (e) {
      Logger.root.severe('Error in getTopSearches: $e');
    }
    return List.empty();
  }

  Future<Map> fetchSongSearchResults({
    required String searchQuery,
    int count = 20,
    int page = 1,
  }) async {
    final String params =
        "p=$page&q=$searchQuery&n=$count&${endpoints['getResults']}";

    try {
      final res = await getResponse(params, useProxy: true);
      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final List responseList = (decoded['results'] as List?) ?? [];
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, 'song'),
            'error': '',
          };
        }
      }
      return {
        'songs': List.empty(),
        'error': res.body,
      };
    } catch (e) {
      Logger.root.severe('Error in fetchSongSearchResults: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<List<Map>> fetchSearchResults(String searchQuery) async {
    final Map<String, List> result = {};
    final Map<int, String> position = {};
    List searchedAlbumList = [];
    List searchedPlaylistList = [];
    List searchedArtistList = [];
    List searchedTopQueryList = [];

    final String params =
        '__call=autocomplete.get&cc=in&includeMetaTags=1&query=$searchQuery';

    try {
      final res = await getResponse(params, usev4: false, useProxy: true);
      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final Map getMain = decoded;

          final List albumResponseList =
              (getMain['albums']?['data'] as List?) ?? [];
          if (getMain['albums']?['position'] != null) {
            position[getMain['albums']['position'] as int] = 'Albums';
          }

          final List playlistResponseList =
              (getMain['playlists']?['data'] as List?) ?? [];
          if (getMain['playlists']?['position'] != null) {
            position[getMain['playlists']['position'] as int] = 'Playlists';
          }

          final List artistResponseList =
              (getMain['artists']?['data'] as List?) ?? [];
          if (getMain['artists']?['position'] != null) {
            position[getMain['artists']['position'] as int] = 'Artists';
          }

          final List topQuery = (getMain['topquery']?['data'] as List?) ?? [];

          searchedAlbumList = await FormatResponse.formatAlbumResponse(
            albumResponseList,
            'album',
          );
          if (searchedAlbumList.isNotEmpty) {
            result['Albums'] = searchedAlbumList;
          }

          searchedPlaylistList = await FormatResponse.formatAlbumResponse(
            playlistResponseList,
            'playlist',
          );
          if (searchedPlaylistList.isNotEmpty) {
            result['Playlists'] = searchedPlaylistList;
          }

          searchedArtistList = await FormatResponse.formatAlbumResponse(
            artistResponseList,
            'artist',
          );
          if (searchedArtistList.isNotEmpty) {
            result['Artists'] = searchedArtistList;
          }

          if (topQuery.isNotEmpty &&
              (topQuery[0]['type'] != 'playlist' ||
                  topQuery[0]['type'] == 'artist' ||
                  topQuery[0]['type'] == 'album')) {
            if (getMain['topquery']?['position'] != null) {
              position[getMain['topquery']['position'] as int] = 'Top Result';
            }
            if (getMain['songs']?['position'] != null) {
              position[getMain['songs']['position'] as int] = 'Songs';
            }

            switch (topQuery[0]['type'] as String) {
              case 'artist':
                searchedTopQueryList =
                    await FormatResponse.formatAlbumResponse(topQuery, 'artist');
                break;
              case 'album':
                searchedTopQueryList =
                    await FormatResponse.formatAlbumResponse(topQuery, 'album');
                break;
              case 'playlist':
                searchedTopQueryList =
                    await FormatResponse.formatAlbumResponse(topQuery, 'playlist');
                break;
              default:
                break;
            }
            if (searchedTopQueryList.isNotEmpty) {
              result['Top Result'] = searchedTopQueryList;
            }
          } else {
            if (topQuery.isNotEmpty && topQuery[0]['type'] == 'song') {
              if (getMain['topquery']?['position'] != null) {
                position[getMain['topquery']['position'] as int] = 'Songs';
              }
            } else {
              if (getMain['songs']?['position'] != null) {
                position[getMain['songs']['position'] as int] = 'Songs';
              }
            }
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSearchResults: $e');
    }
    return [result, position];
  }

  Future<List<Map>> fetchAlbums({
    required String searchQuery,
    required String type,
    int count = 20,
    int page = 1,
  }) async {
    String? params;
    if (type == 'playlist') {
      params =
          'p=$page&q=$searchQuery&n=$count&${endpoints["playlistResults"]}';
    }
    if (type == 'album') {
      params = 'p=$page&q=$searchQuery&n=$count&${endpoints["albumResults"]}';
    }
    if (type == 'artist') {
      params = 'p=$page&q=$searchQuery&n=$count&${endpoints["artistResults"]}';
    }

    final res = await getResponse(params!);
    if (res.statusCode == 200) {
      final getMain = json.decode(utf8.decode(res.bodyBytes));
      final List responseList = getMain['results'] as List;
      return FormatResponse.formatAlbumResponse(responseList, type);
    }
    return List.empty();
  }

  Future<Map> fetchAlbumSongs(String albumId) async {
    final String params = '${endpoints['albumDetails']}&cc=in&albumid=$albumId';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final getMain = json.decode(utf8.decode(res.bodyBytes));
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          return {
            'songs':
                await FormatResponse.formatSongsResponse(responseList, 'album'),
            'error': '',
          };
        }
      }
      Logger.root.severe('Songs not found in fetchAlbumSongs: ${res.body}');
      return {
        'songs': List.empty(),
        'error': '',
      };
    } catch (e) {
      Logger.root.severe('Error in fetchAlbumSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<Map<String, List>> fetchArtistSongs({
    required String artistToken,
    String category = '',
    String sortOrder = '',
  }) async {
    final Map<String, List> data = {};
    final String params =
        '${endpoints["fromToken"]}&type=artist&p=&n_song=50&n_album=50&sub_type=&category=$category&sort_order=$sortOrder&includeMetaTags=0&token=$artistToken';
    final res = await getResponse(params);
    if (res.statusCode == 200) {
      final Map getMain = json.decode(utf8.decode(res.bodyBytes)) as Map;
      final List topSongsResponseList = getMain['topSongs'] as List;
      final List latestReleaseResponseList = getMain['latest_release'] as List;
      final List topAlbumsResponseList = getMain['topAlbums'] as List;
      final List singlesResponseList = getMain['singles'] as List;
      final List dedicatedResponseList =
          getMain['dedicated_artist_playlist'] as List;
      final List featuredResponseList =
          getMain['featured_artist_playlist'] as List;
      final List similarArtistsResponseList = getMain['similarArtists'] as List;

      final List topSongsSearchedList =
          await FormatResponse.formatSongsResponse(
        topSongsResponseList,
        'song',
      );
      if (topSongsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topSongs']?['title']?.toString() ??
            'Top Songs'] = topSongsSearchedList;
      }

      final List latestReleaseSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        latestReleaseResponseList,
      );
      if (latestReleaseSearchedList.isNotEmpty) {
        data[getMain['modules']?['latest_release']?['title']?.toString() ??
            'Latest Releases'] = latestReleaseSearchedList;
      }

      final List topAlbumsSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        topAlbumsResponseList,
      );
      if (topAlbumsSearchedList.isNotEmpty) {
        data[getMain['modules']?['topAlbums']?['title']?.toString() ??
            'Top Albums'] = topAlbumsSearchedList;
      }

      final List singlesSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        singlesResponseList,
      );
      if (singlesSearchedList.isNotEmpty) {
        data[getMain['modules']?['singles']?['title']?.toString() ??
            'Singles'] = singlesSearchedList;
      }

      final List dedicatedSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        dedicatedResponseList,
      );
      if (dedicatedSearchedList.isNotEmpty) {
        data[getMain['modules']?['dedicated_artist_playlist']?['title']
                ?.toString() ??
            'Dedicated Playlists'] = dedicatedSearchedList;
      }

      final List featuredSearchedList =
          await FormatResponse.formatArtistTopAlbumsResponse(
        featuredResponseList,
      );
      if (featuredSearchedList.isNotEmpty) {
        data[getMain['modules']?['featured_artist_playlist']?['title']
                ?.toString() ??
            'Featured Playlists'] = featuredSearchedList;
      }

      final List similarArtistsSearchedList =
          await FormatResponse.formatSimilarArtistsResponse(
        similarArtistsResponseList,
      );
      if (similarArtistsSearchedList.isNotEmpty) {
        data[getMain['modules']?['similarArtists']?['title']?.toString() ??
            'Similar Artists'] = similarArtistsSearchedList;
      }
    }
    return data;
  }

  Future<Map> fetchPlaylistSongs(String playlistId) async {
    final String params =
        '${endpoints["playlistDetails"]}&cc=in&listid=$playlistId';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final getMain = json.decode(utf8.decode(res.bodyBytes));
        if (getMain['list'] != '') {
          final List responseList = getMain['list'] as List;
          return {
            'songs': await FormatResponse.formatSongsResponse(
              responseList,
              'playlist',
            ),
            'error': '',
          };
        }
        return {
          'songs': List.empty(),
          'error': '',
        };
      } else {
        return {
          'songs': List.empty(),
          'error': res.body,
        };
      }
    } catch (e) {
      Logger.root.severe('Error in fetchPlaylistSongs: $e');
      return {
        'songs': List.empty(),
        'error': e,
      };
    }
  }

  Future<List> fetchTopSearchResult(String searchQuery) async {
    final String params = 'p=1&q=$searchQuery&n=10&${endpoints["getResults"]}';
    final res = await getResponse(params, useProxy: true);
    if (res.statusCode == 200) {
      final getMain = json.decode(utf8.decode(res.bodyBytes));
      final List responseList = getMain['results'] as List;
      return [
        await FormatResponse.formatSingleSongResponse(responseList[0] as Map)
      ];
    }
    return List.empty();
  }

  Future<Map> fetchSongDetails(String songId) async {
    final String params = 'pids=$songId&${endpoints["songDetails"]}';
    try {
      final res = await getResponse(params);
      if (res.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map) {
          final List songs = (decoded['songs'] as List?) ?? [];
          if (songs.isNotEmpty && songs[0] is Map) {
            return await FormatResponse.formatSingleSongResponse(
              songs[0] as Map,
            );
          }
        }
      }
    } catch (e) {
      Logger.root.severe('Error in fetchSongDetails: $e');
    }
    return {};
  }
}
