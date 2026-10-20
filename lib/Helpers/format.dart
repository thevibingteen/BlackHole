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
import 'dart:typed_data';

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/Helpers/extensions.dart';
import 'package:blackhole/Helpers/image_resolution_modifier.dart';
import 'package:dart_des/dart_des.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

// ignore: avoid_classes_with_only_static_members
class FormatResponse {
  static String decode(String input) {
    try {
      const String key = '38346591';
      final DES desECB = DES(key: key.codeUnits);

      final Uint8List encrypted = base64.decode(input);
      final List<int> decrypted = desECB.decrypt(encrypted);
      final String decoded = utf8
          .decode(decrypted)
          .replaceAll(RegExp(r'\.mp4.*'), '.mp4')
          .replaceAll(RegExp(r'\.m4a.*'), '.m4a');
      return decoded.replaceAll('http:', 'https:');
    } catch (e) {
      Logger.root.warning('Failed to DES decode media URL: $e');
      return '';
    }
  }

  static Future<List> formatSongsResponse(
    List responseList,
    String type,
  ) async {
    final List searchedList = [];
    for (int i = 0; i < responseList.length; i++) {
      if (responseList[i] is! Map) continue;
      Map? response;
      switch (type) {
        case 'song':
        case 'album':
        case 'playlist':
        case 'show':
        case 'mix':
          response = await formatSingleSongResponse(responseList[i] as Map);
          break;
        default:
          break;
      }

      if (response != null && response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatSongsResponse: ${response["Error"]}',
        );
      } else {
        if (response != null) {
          searchedList.add(response);
        }
      }
    }
    return searchedList;
  }

  static const List<String> masterLanguages = [
    'Hindi',
    'English',
    'Punjabi',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
    'Bengali',
    'Kannada',
    'Bhojpuri',
    'Malayalam',
    'Urdu',
    'Haryanvi',
    'Rajasthani',
    'Odia',
    'Assamese',
  ];

  static String parseDuration(dynamic raw) {
    if (raw == null) return '0';
    if (raw is int) {
      return raw > 0 ? raw.toString() : '0';
    }
    if (raw is double) {
      return raw > 0 ? raw.round().toString() : '0';
    }
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == '0') return '0';
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        final total = m * 60 + s;
        return total > 0 ? total.toString() : '0';
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        final total = h * 3600 + m * 60 + s;
        return total > 0 ? total.toString() : '0';
      }
    }
    final parsed = int.tryParse(str) ?? double.tryParse(str)?.round() ?? 0;
    return parsed > 0 ? parsed.toString() : '0';
  }

  static bool isLanguageUnselected(String langName, Set<String> activeLangs) {
    final lower = langName.trim().toLowerCase();
    final isCatalogue = masterLanguages.any((l) => l.toLowerCase() == lower);
    if (!isCatalogue) return false;
    return !activeLangs.contains(lower);
  }

  static bool moduleMatchesUnselectedLanguage(String title, Set<String> activeLangs) {
    final lowerTitle = title.toLowerCase();
    for (final l in masterLanguages) {
      final lLower = l.toLowerCase();
      final regex = RegExp('\\b${RegExp.escape(lLower)}\\b', caseSensitive: false);
      if (regex.hasMatch(lowerTitle)) {
        if (!activeLangs.contains(lLower)) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<Map> formatSingleSongResponse(Map response) async {
    try {
      final List artistNames = [];
      final moreInfo = (response['more_info'] as Map?) ?? {};
      final artistMap = (moreInfo['artistMap'] as Map?) ?? {};
      final primaryArtists = (artistMap['primary_artists'] as List?) ?? [];
      final featuredArtists = (artistMap['featured_artists'] as List?) ?? [];
      final artists = (artistMap['artists'] as List?) ?? [];

      if (primaryArtists.isNotEmpty) {
        for (final el in primaryArtists) {
          if (el is Map && el['name'] != null) {
            artistNames.add(el['name'].toString());
          }
        }
      } else if (featuredArtists.isNotEmpty) {
        for (final el in featuredArtists) {
          if (el is Map && el['name'] != null) {
            artistNames.add(el['name'].toString());
          }
        }
      } else if (artists.isNotEmpty) {
        for (final el in artists) {
          if (el is Map && el['name'] != null) {
            artistNames.add(el['name'].toString());
          }
        }
      } else if (moreInfo['music'] != null) {
        artistNames.add(moreInfo['music'].toString());
      } else if (response['singers'] != null &&
          response['singers'].toString().trim().isNotEmpty) {
        artistNames.add(response['singers'].toString());
      } else if (moreInfo['singers'] != null &&
          moreInfo['singers'].toString().trim().isNotEmpty) {
        artistNames.add(moreInfo['singers'].toString());
      } else if (response['subtitle'] != null &&
          response['subtitle'].toString().trim().isNotEmpty) {
        artistNames.add(response['subtitle'].toString());
      } else if (moreInfo['show_title'] != null &&
          moreInfo['show_title'].toString().trim().isNotEmpty) {
        artistNames.add(moreInfo['show_title'].toString());
      } else if (response['show_title'] != null &&
          response['show_title'].toString().trim().isNotEmpty) {
        artistNames.add(response['show_title'].toString());
      } else if (moreInfo['partner_name'] != null &&
          moreInfo['partner_name'].toString().trim().isNotEmpty &&
          moreInfo['partner_name'].toString().trim().toLowerCase() != 'podcaster') {
        artistNames.add(moreInfo['partner_name'].toString());
      } else if (response['header_desc'] != null &&
          response['header_desc'].toString().trim().isNotEmpty &&
          response['header_desc'].toString().startsWith('Episode from ')) {
        final epShow = response['header_desc']
            .toString()
            .replaceFirst('Episode from ', '')
            .replaceAll(RegExp(r'\.+$'), '')
            .trim();
        if (epShow.isNotEmpty) {
          artistNames.add(epShow);
        } else {
          artistNames.add('Unknown');
        }
      } else {
        artistNames.add('Unknown');
      }

      final String encUrl = moreInfo['encrypted_media_url']?.toString() ??
          response['encrypted_media_url']?.toString() ??
          '';
      String decodedUrl = encUrl.isNotEmpty ? decode(encUrl) : '';
      if (decodedUrl.isEmpty) {
        decodedUrl = (moreInfo['media_preview_url'] ??
                response['media_preview_url'] ??
                moreInfo['media_url'] ??
                response['media_url'] ??
                response['url'] ??
                '')
            .toString();
      }

      String parsedDuration = parseDuration(moreInfo['duration']);
      if (parsedDuration == '0') {
        parsedDuration = parseDuration(response['duration']);
      }

      final String albumVal = (moreInfo['album']?.toString() ?? '').isNotEmpty
          ? moreInfo['album'].toString().unescape()
          : ((moreInfo['show_title']?.toString() ?? '').isNotEmpty
              ? moreInfo['show_title'].toString().unescape()
              : (response['show_title']?.toString().unescape() ?? ''));

      return {
        'id': response['id']?.toString() ?? '',
        'type': response['type']?.toString() ?? 'song',
        'album': albumVal,
        'year': (response['year'] ?? moreInfo['year'] ?? '').toString(),
        'duration': parsedDuration,
        'language': (response['language'] ??
                moreInfo['editorial_language'] ??
                '')
            .toString()
            .capitalize(),
        'genre': (response['language'] ??
                moreInfo['editorial_language'] ??
                '')
            .toString()
            .capitalize(),
        '320kbps': (moreInfo['320kbps'] == 'true' ||
            moreInfo['320kbps'] == true ||
            response['320kbps'] == 'true' ||
            response['320kbps'] == true),
        'has_lyrics': (moreInfo['has_lyrics'] == 'true' ||
            moreInfo['has_lyrics'] == true ||
            response['has_lyrics'] == 'true' ||
            response['has_lyrics'] == true),
        'lyrics_snippet':
            moreInfo['lyrics_snippet']?.toString().unescape() ?? '',
        'release_date': (moreInfo['release_date'] ?? '').toString(),
        'album_id': (moreInfo['album_id'] ?? '').toString(),
        'subtitle': response['subtitle']?.toString().unescape() ?? '',
        'title':
            (response['title'] ?? response['song'] ?? '').toString().unescape(),
        'artist': artistNames.join(', ').unescape(),
        'album_artist': moreInfo['music'] ?? response['music'] ?? '',
        'image': getImageUrl(response['image']?.toString() ?? ''),
        'perma_url': (response['perma_url'] ?? '').toString(),
        'url': decodedUrl,
      };
    } catch (e) {
      Logger.root.severe('Error inside FormatSingleSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleAlbumSongResponse(Map response) async {
    try {
      final List artistNames = [];
      if (response['primary_artists'] == null ||
          response['primary_artists'].toString().trim() == '') {
        if (response['featured_artists'] == null ||
            response['featured_artists'].toString().trim() == '') {
          if (response['singers'] == null ||
              response['singer'].toString().trim() == '') {
            response['singers'].toString().split(', ').forEach((element) {
              artistNames.add(element);
            });
          } else {
            artistNames.add('Unknown');
          }
        } else {
          response['featured_artists']
              .toString()
              .split(', ')
              .forEach((element) {
            artistNames.add(element);
          });
        }
      } else {
        response['primary_artists'].toString().split(', ').forEach((element) {
          artistNames.add(element);
        });
      }

      String parsedDuration = parseDuration(response['duration']);
      if (parsedDuration == '0') {
        parsedDuration = parseDuration(response['more_info']?['duration']);
      }

      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['album'].toString().unescape(),
        // .split('(')
        // .first
        'year': response['year'],
        'duration': parsedDuration,
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        '320kbps': response['320kbps'],
        'has_lyrics': response['has_lyrics'],
        'lyrics_snippet': response['lyrics_snippet'].toString().unescape(),
        'release_date': response['release_date'],
        'album_id': response['album_id'],
        'subtitle':
            '${response["primary_artists"].toString().trim()} - ${response["album"].toString().trim()}'
                .unescape(),

        'title': response['song'].toString().unescape(),
        // .split('(')
        // .first
        'artist': artistNames.join(', ').unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'perma_url': response['perma_url'],
        'url': decode(response['encrypted_media_url'].toString())
      };
    } catch (e) {
      Logger.root.severe('Error inside FormatSingleAlbumSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List<Map>> formatAlbumResponse(
    List responseList,
    String type,
  ) async {
    final List<Map> searchedAlbumList = [];
    for (int i = 0; i < responseList.length; i++) {
      Map? response;
      switch (type) {
        case 'album':
          response = await formatSingleAlbumResponse(responseList[i] as Map);
          break;
        case 'artist':
          response = await formatSingleArtistResponse(responseList[i] as Map);
          break;
        case 'playlist':
          response = await formatSinglePlaylistResponse(responseList[i] as Map);
          break;
        case 'show':
          response = await formatSingleShowResponse(responseList[i] as Map);
          break;
      }
      if (response!.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatAlbumResponse: ${response["Error"]}',
        );
      } else {
        searchedAlbumList.add(response);
      }
    }
    return searchedAlbumList;
  }

  static Future<Map> formatSingleAlbumResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'year': response['more_info']?['year'] ?? response['year'],
        'language': response['more_info']?['language'] == null
            ? response['language'].toString().capitalize()
            : response['more_info']['language'].toString().capitalize(),
        'genre': response['more_info']?['language'] == null
            ? response['language'].toString().capitalize()
            : response['more_info']['language'].toString().capitalize(),
        'album_id': response['id'],
        'subtitle': response['description'] == null
            ? response['subtitle'].toString().unescape()
            : response['description'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        'artist': response['music'] == null
            ? (response['more_info']?['music'] == null)
                ? (response['more_info']?['artistMap']?['primary_artists'] ==
                            null ||
                        (response['more_info']?['artistMap']?['primary_artists']
                                as List)
                            .isEmpty)
                    ? ''
                    : response['more_info']['artistMap']['primary_artists'][0]
                            ['name']
                        .toString()
                        .unescape()
                : response['more_info']['music'].toString().unescape()
            : response['music'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'count': response['more_info']?['song_pids'] == null
            ? 0
            : response['more_info']['song_pids'].toString().split(', ').length,
        'songs_pids': response['more_info']['song_pids'].toString().split(', '),
        'perma_url': response['url'].toString(),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleAlbumResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSinglePlaylistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'language': response['language'] == null
            ? response['more_info']['language'].toString().capitalize()
            : response['language'].toString().capitalize(),
        'genre': response['language'] == null
            ? response['more_info']['language'].toString().capitalize()
            : response['language'].toString().capitalize(),
        'playlistId': response['id'],
        'subtitle': response['description'] == null
            ? response['subtitle'].toString().unescape()
            : response['description'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        'artist': response['extra'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
        'perma_url': response['url'].toString(),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSinglePlaylistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleArtistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'] == null
            ? response['name'].toString().unescape()
            : response['title'].toString().unescape(),
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        'artistId': response['id'],
        'artistToken': response['url'] == null
            ? response['perma_url'].toString().split('/').last
            : response['url'].toString().split('/').last,
        'subtitle': response['description'] == null
            ? response['role'].toString().capitalize()
            : response['description'].toString().unescape(),
        'title': response['title'] == null
            ? response['name'].toString().unescape()
            : response['title'].toString().unescape(),
        // .split('(')
        // .first
        'perma_url': response['url'].toString(),
        'artist': response['title'].toString().unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleArtistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List> formatArtistTopAlbumsResponse(List responseList) async {
    final List result = [];
    for (int i = 0; i < responseList.length; i++) {
      final Map response =
          await formatSingleArtistTopAlbumSongResponse(responseList[i] as Map);
      if (response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatArtistTopAlbumsResponse: ${response["Error"]}',
        );
      } else {
        result.add(response);
      }
    }
    return result;
  }

  static Future<Map> formatSingleArtistTopAlbumSongResponse(
    Map response,
  ) async {
    try {
      final List artistNames = [];
      if (response['more_info']?['artistMap']?['primary_artists'] == null ||
          response['more_info']['artistMap']['primary_artists'].length == 0) {
        if (response['more_info']?['artistMap']?['featured_artists'] == null ||
            response['more_info']['artistMap']['featured_artists'].length ==
                0) {
          if (response['more_info']?['artistMap']?['artists'] == null ||
              response['more_info']['artistMap']['artists'].length == 0) {
            artistNames.add('Unknown');
          } else {
            response['more_info']['artistMap']['artists'].forEach((element) {
              artistNames.add(element['name']);
            });
          }
        } else {
          response['more_info']['artistMap']['featured_artists']
              .forEach((element) {
            artistNames.add(element['name']);
          });
        }
      } else {
        response['more_info']['artistMap']['primary_artists']
            .forEach((element) {
          artistNames.add(element['name']);
        });
      }

      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        // .split('(')
        // .first
        'year': response['year'],
        'language': response['language'].toString().capitalize(),
        'genre': response['language'].toString().capitalize(),
        'album_id': response['id'],
        'subtitle': response['subtitle'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        // .split('(')
        // .first
        'artist': artistNames.join(', ').unescape(),
        'album_artist': response['more_info'] == null
            ? response['music']
            : response['more_info']['music'],
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root
          .severe('Error inside formatSingleArtistTopAlbumSongResponse: $e');
      return {'Error': e};
    }
  }

  static Future<List> formatSimilarArtistsResponse(List responseList) async {
    final List result = [];
    for (int i = 0; i < responseList.length; i++) {
      final Map response =
          await formatSingleSimilarArtistResponse(responseList[i] as Map);
      if (response.containsKey('Error')) {
        Logger.root.severe(
          'Error at index $i inside FormatSimilarArtistsResponse: ${response["Error"]}',
        );
      } else {
        result.add(response);
      }
    }
    return result;
  }

  static Future<Map> formatSingleSimilarArtistResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'artist': response['name'].toString().unescape(),
        'title': response['name'].toString().unescape(),
        'subtitle': response['dominantType'].toString().capitalize(),
        'image': getImageUrl(response['image_url'].toString()),
        'artistToken': response['perma_url'].toString().split('/').last,
        'perma_url': response['perma_url'].toString(),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleSimilarArtistResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatSingleShowResponse(Map response) async {
    try {
      return {
        'id': response['id'],
        'type': response['type'],
        'album': response['title'].toString().unescape(),
        'subtitle': response['description'] == null
            ? response['subtitle'].toString().unescape()
            : response['description'].toString().unescape(),
        'title': response['title'].toString().unescape(),
        'image': getImageUrl(response['image'].toString()),
      };
    } catch (e) {
      Logger.root.severe('Error inside formatSingleShowResponse: $e');
      return {'Error': e};
    }
  }

  static Future<Map> formatHomePageData(
    Map inputData, {
    List? preferredLangs,
  }) async {
    final Map data = Map<dynamic, dynamic>.from(inputData);
    try {
      final activeLangs = (preferredLangs ??
              (Hive.isBoxOpen('settings')
                  ? Hive.box('settings')
                      .get('preferredLanguage', defaultValue: ['Hindi']) as List
                  : ['Hindi']))
          .map((e) => e.toString().trim().toLowerCase())
          .toSet();

      List filterItemsInList(List list) {
        return list.where((item) {
          if (item is! Map) return false;
          final itemLang = (item['language'] ??
                  item['more_info']?['language'] ??
                  item['more_info']?['editorial_language'])
              ?.toString()
              .trim()
              .toLowerCase();
          if (itemLang != null && itemLang.isNotEmpty) {
            if (isLanguageUnselected(itemLang, activeLangs)) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      if (data['new_trending'] != null && data['new_trending'] is List) {
        data['new_trending'] = filterItemsInList(data['new_trending'] as List);
        data['new_trending'] =
            await formatSongsInList(data['new_trending'] as List);
      }
      if (data['new_albums'] != null && data['new_albums'] is List) {
        data['new_albums'] = filterItemsInList(data['new_albums'] as List);
        data['new_albums'] =
            await formatSongsInList(data['new_albums'] as List);
      }
      if (data['city_mod'] != null && data['city_mod'] is List) {
        data['city_mod'] = filterItemsInList(data['city_mod'] as List);
        data['city_mod'] = await formatSongsInList(data['city_mod'] as List);
      }
      final List promoList = [];
      final List promoListTemp = [];
      if (data['modules'] != null && data['modules'] is Map) {
        (data['modules'] as Map).forEach((k, v) {
          if (k.toString().startsWith('promo')) {
            final modTitle = (v is Map ? v['title']?.toString() : '') ?? '';
            if (moduleMatchesUnselectedLanguage(modTitle, activeLangs)) {
              return;
            }
            final modData = data[k];
            if (modData is List) {
              data[k] = filterItemsInList(modData);
              if ((data[k] as List).isNotEmpty) {
                final firstItem = data[k][0];
                if (firstItem is Map &&
                    firstItem['type'] == 'song' &&
                    (firstItem['mini_obj'] as bool? ?? false)) {
                  if (firstItem['more_info']?['encrypted_media_url'] != null) {
                    promoList.add(k.toString());
                  } else {
                    promoListTemp.add(k.toString());
                  }
                } else {
                  promoList.add(k.toString());
                }
              }
            }
          }
        });
      }
      for (int i = 0; i < promoList.length; i++) {
        if (data[promoList[i]] is List) {
          data[promoList[i]] =
              await formatSongsInList(data[promoList[i]] as List);
        }
      }

      final candidateCollections = [
        'new_trending',
        'charts',
        'new_albums',
        'tag_mixes',
        'top_playlists',
        'radio',
        'city_mod',
        'artist_recos',
        ...promoList
      ];

      final filteredCollections = <String>[];
      for (final col in candidateCollections) {
        final modTitle = data['modules']?[col]?['title']?.toString() ?? '';
        if (moduleMatchesUnselectedLanguage(modTitle, activeLangs)) {
          continue;
        }
        filteredCollections.add(col);
      }

      data['collections'] = filteredCollections;
      data['collections_temp'] = promoListTemp;
      data['preferredLanguage'] = activeLangs.toList();
    } catch (e) {
      Logger.root.severe('Error inside formatHomePageData: $e');
      data['collections'] ??= [
        'new_trending',
        'charts',
        'new_albums',
        'tag_mixes',
        'top_playlists',
        'radio',
        'city_mod',
        'artist_recos',
      ];
      data['collections_temp'] ??= [];
    }
    return data;
  }

  static Future<Map> formatPromoLists(Map data) async {
    try {
      final List promoList = (data['collections_temp'] as List?) ?? [];
      for (int i = 0; i < promoList.length; i++) {
        final colKey = promoList[i].toString();
        if (data[colKey] is List) {
          data[colKey] =
              await formatSongsInList(data[colKey] as List);
          if ((data[colKey] as List).isNotEmpty && data['collections'] is List) {
            if (!(data['collections'] as List).contains(colKey)) {
              (data['collections'] as List).add(colKey);
            }
          }
        }
      }
      data['collections_temp'] = [];
    } catch (e) {
      Logger.root.severe('Error inside formatPromoLists: $e');
    }
    return data;
  }

  static Future<List> formatSongsInList(List list) async {
    if (list.isNotEmpty) {
      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is Map && item['type'] == 'song') {
          if (item['more_info']?['encrypted_media_url'] != null) {
            final formatted = await formatSingleSongResponse(item);
            if (!formatted.containsKey('Error')) {
              list[i] = formatted;
              continue;
            }
          }
          if (item['mini_obj'] as bool? ?? false) {
            Map cachedDetails = Hive.box('cache')
                .get(item['id'].toString(), defaultValue: {}) as Map;
            if (cachedDetails.isEmpty) {
              cachedDetails =
                  await SaavnAPI().fetchSongDetails(item['id'].toString());
              if (cachedDetails.isNotEmpty && cachedDetails['id'] != null) {
                Hive.box('cache')
                    .put(cachedDetails['id'].toString(), cachedDetails);
              }
            }
            if (cachedDetails.isNotEmpty) {
              list[i] = cachedDetails;
            }
            continue;
          }
          final formatted = await formatSingleSongResponse(item);
          if (!formatted.containsKey('Error')) {
            list[i] = formatted;
          }
        }
      }
    }
    list.removeWhere(
      (value) => value == null || (value is Map && value.isEmpty),
    );
    return list;
  }

  static List buildHomeLists(
    Map homeData,
    Map likedArtistsMap, {
    List likedRadioList = const [],
    Set<String>? preferredLangs,
  }) {
    final activeLangs = preferredLangs ??
        (Hive.isBoxOpen('settings')
                ? Hive.box('settings')
                    .get('preferredLanguage', defaultValue: ['Hindi']) as List
                : ['Hindi'])
            .map((e) => e.toString().toLowerCase())
            .toSet();

    final rawCollections = (homeData['collections'] as List?) ?? [];
    final validCollections = <String>[];

    for (final col in rawCollections) {
      final colKey = col.toString();
      final items = homeData[colKey];
      final modTitle =
          homeData['modules']?[colKey]?['title']?.toString() ?? '';
      final isRadio = colKey == 'radio' ||
          modTitle == 'Radio Stations' ||
          modTitle.toLowerCase().contains('radio');

      if (moduleMatchesUnselectedLanguage(modTitle, activeLangs)) {
        continue;
      }

      if (isRadio) {
        if (likedRadioList.isNotEmpty ||
            (items is List && items.isNotEmpty)) {
          validCollections.add(colKey);
        }
        continue;
      }

      if (items is List && items.isNotEmpty) {
        validCollections.add(colKey);
      }
    }

    final List combined = ['recent', 'playlist', ...validCollections];
    if (likedArtistsMap.isNotEmpty) {
      combined.insert((combined.length / 2).round(), 'likedArtists');
    }
    return combined;
  }
}
