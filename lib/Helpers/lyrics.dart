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

import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/Helpers/matcher.dart';
import 'package:blackhole/Helpers/spotify_helper.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

// ignore: avoid_classes_with_only_static_members
class Lyrics {
  static bool isHtmlOrChallenge(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    if (lower.contains('<!doctype') ||
        lower.contains('<html') ||
        lower.contains('<head') ||
        lower.contains('<body') ||
        lower.contains('<script') ||
        lower.contains('<style') ||
        lower.contains('captcha') ||
        lower.contains('enable javascript') ||
        lower.contains('challenge-platform') ||
        lower.contains('cloudflare') ||
        (lower.contains('<div') && lower.contains('</div>'))) {
      return true;
    }
    return false;
  }

  static Future<Map<String, String>> getLyrics({
    required String id,
    required String title,
    required String artist,
    required bool saavnHas,
    String? album,
    int? duration,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': '',
      'id': id,
    };

    // 1. Try LRCLIB structured API first (preferred source for synced and plain lyrics)
    try {
      Logger.root.info('Getting lyrics from LRCLIB for $title - $artist');
      final lrclibRes = await getLrclibLyrics(
        trackName: title,
        artistName: artist,
        albumName: album,
        duration: duration,
      );
      if (lrclibRes['lyrics']!.isNotEmpty &&
          !isHtmlOrChallenge(lrclibRes['lyrics']!)) {
        result['lyrics'] = lrclibRes['lyrics']!;
        result['type'] = lrclibRes['type']!;
        result['source'] = 'LRCLIB';
        return result;
      }
    } catch (e) {
      Logger.root.warning('Error in LRCLIB lyrics lookup: $e');
    }

    // 2. Try Spotify synced lyrics (if user authenticated or available)
    try {
      Logger.root.info('Getting Synced Lyrics from Spotify');
      final res = await getSpotifyLyrics(title, artist);
      if (res['lyrics']!.isNotEmpty && !isHtmlOrChallenge(res['lyrics']!)) {
        result['lyrics'] = res['lyrics']!;
        result['type'] = res['type']!;
        result['source'] = res['source']!;
        return result;
      }
    } catch (e) {
      Logger.root.warning('Error in Spotify lyrics lookup: $e');
    }

    // 3. Try Saavn lyrics if track has them
    if (saavnHas) {
      try {
        Logger.root.info('Getting Lyrics from Saavn');
        final saavnLyrics = await getSaavnLyrics(id);
        if (saavnLyrics.isNotEmpty && !isHtmlOrChallenge(saavnLyrics)) {
          result['lyrics'] = saavnLyrics;
          result['type'] = 'text';
          result['source'] = 'Jiosaavn';
          return result;
        }
      } catch (e) {
        Logger.root.warning('Error in Saavn lyrics lookup: $e');
      }
    }

    // 4. Try MusixMatch text lyrics
    try {
      Logger.root.info('Lyrics not available on Saavn/Spotify, finding on Musixmatch');
      final mmLyrics = await getMusixMatchLyrics(title: title, artist: artist);
      if (mmLyrics.isNotEmpty && !isHtmlOrChallenge(mmLyrics)) {
        result['lyrics'] = mmLyrics;
        result['type'] = 'text';
        result['source'] = 'Musixmatch';
        return result;
      }
    } catch (e) {
      Logger.root.warning('Error in Musixmatch lyrics lookup: $e');
    }

    // Google scraper is intentionally removed from active fallback chain
    // to prevent Google challenge/HTML responses from reaching the lyrics renderer.
    if (isHtmlOrChallenge(result['lyrics']!)) {
      result['lyrics'] = '';
    }
    return result;
  }

  static Future<Map<String, String>> getLrclibLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? duration,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'LRCLIB',
    };

    // Clean track name for search (remove extraneous tags like '(Official Video)', etc.)
    final cleanTrackName = trackName
        .split('(From')[0]
        .split('(Official')[0]
        .split('[Official')[0]
        .split('|')[0]
        .trim();
    final cleanArtistName = artistName.split(',')[0].trim();

    // 1. Exact track lookup
    try {
      final queryParams = <String, String>{
        'track_name': cleanTrackName,
        'artist_name': cleanArtistName,
      };
      if (albumName != null && albumName.isNotEmpty) {
        queryParams['album_name'] = albumName;
      }
      if (duration != null && duration > 0) {
        queryParams['duration'] = duration.toString();
      }

      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final res = await get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'BlackHole/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data is Map) {
          final synced = data['syncedLyrics']?.toString() ?? '';
          final plain = data['plainLyrics']?.toString() ?? '';
          if (synced.isNotEmpty && !isHtmlOrChallenge(synced)) {
            result['lyrics'] = synced;
            result['type'] = 'lrc';
            return result;
          } else if (plain.isNotEmpty && !isHtmlOrChallenge(plain)) {
            result['lyrics'] = plain;
            result['type'] = 'text';
            return result;
          }
        }
      }
    } catch (e) {
      Logger.root.warning('Exact LRCLIB lookup failed: $e');
    }

    // 2. Search fallback
    try {
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'q': '$cleanTrackName $cleanArtistName',
      });
      final searchRes = await get(
        searchUri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'BlackHole/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (searchRes.statusCode == 200) {
        final list = json.decode(utf8.decode(searchRes.bodyBytes));
        if (list is List && list.isNotEmpty) {
          for (final item in list) {
            if (item is Map) {
              final synced = item['syncedLyrics']?.toString() ?? '';
              final plain = item['plainLyrics']?.toString() ?? '';
              if (synced.isNotEmpty && !isHtmlOrChallenge(synced)) {
                result['lyrics'] = synced;
                result['type'] = 'lrc';
                return result;
              } else if (plain.isNotEmpty && !isHtmlOrChallenge(plain)) {
                result['lyrics'] = plain;
                result['type'] = 'text';
                return result;
              }
            }
          }
        }
      }
    } catch (e) {
      Logger.root.warning('Search LRCLIB lookup failed: $e');
    }

    return result;
  }

  static Future<String> getSaavnLyrics(String id) async {
    try {
      final Uri lyricsUrl = Uri.parse(
        'https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=$id&ctx=web6dot0&api_version=4&_format=json',
      );
      final Response res = await get(
        lyricsUrl,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return '';
      final List<String> rawLyrics = utf8.decode(res.bodyBytes).split('-->');
      Map fetchedLyrics = {};
      if (rawLyrics.length > 1) {
        fetchedLyrics = json.decode(rawLyrics[1]) as Map;
      } else {
        fetchedLyrics = json.decode(rawLyrics[0]) as Map;
      }
      final String lyrics =
          fetchedLyrics['lyrics'].toString().replaceAll('<br>', '\n');
      if (isHtmlOrChallenge(lyrics)) return '';
      return lyrics;
    } catch (e) {
      Logger.root.severe('Error in getSaavnLyrics', e);
      return '';
    }
  }

  static Future<Map<String, String>> getSpotifyLyrics(
    String title,
    String artist,
  ) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    await callSpotifyFunction(
      function: (String accessToken) async {
        final value = await SpotifyApi().searchTrack(
          accessToken: accessToken,
          query: '$title - $artist',
          limit: 1,
        );
        try {
          if (value['tracks']?['items'] == null ||
              (value['tracks']['items'] as List).isEmpty) {
            Logger.root.info('No song found');
            return result;
          }
          String title2 = '';
          String artist2 = '';
          try {
            title2 = value['tracks']['items'][0]['name'].toString();
            artist2 =
                value['tracks']['items'][0]['artists'][0]['name'].toString();
          } catch (e) {
            Logger.root.severe(
              'Error in extracting artist/title in getSpotifyLyrics for $title - $artist',
              e,
            );
          }
          final trackId = value['tracks']['items'][0]['id'].toString();
          if (matchSongs(
            title: title,
            artist: artist,
            title2: title2,
            artist2: artist2,
          )) {
            final Map<String, String> res =
                await getSpotifyLyricsFromId(trackId);
            result['lyrics'] = res['lyrics']!;
            result['type'] = res['type']!;
            result['source'] = res['source']!;
          } else {
            Logger.root.info('Song not matched');
          }
        } catch (e) {
          Logger.root.severe('Error in getSpotifyLyrics', e);
        }
      },
      forceSign: false,
    );
    if (isHtmlOrChallenge(result['lyrics']!)) {
      result['lyrics'] = '';
    }
    return result;
  }

  static Future<Map<String, String>> getSpotifyLyricsFromId(
    String trackId,
  ) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    try {
      final Uri lyricsUrl = Uri.https('spotify-lyric-api.herokuapp.com', '/', {
        'trackid': trackId,
        'format': 'lrc',
      });
      final Response res = await get(
        lyricsUrl,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final Map lyricsData = json.decode(utf8.decode(res.bodyBytes)) as Map;
        if (lyricsData['error'] == false) {
          final List lines = lyricsData['lines'] as List;
          if (lyricsData['syncType'] == 'LINE_SYNCED') {
            result['lyrics'] = lines
                .map((e) => '[${e["timeTag"]}]${e["words"]}')
                .toList()
                .join('\n');
            result['type'] = 'lrc';
          } else {
            result['lyrics'] = lines.map((e) => e['words']).toList().join('\n');
            result['type'] = 'text';
          }
        }
      } else {
        Logger.root.severe(
          'getSpotifyLyricsFromId returned ${res.statusCode}',
          res.body,
        );
      }
      if (isHtmlOrChallenge(result['lyrics']!)) {
        result['lyrics'] = '';
      }
      return result;
    } catch (e) {
      Logger.root.severe('Error in getSpotifyLyrics', e);
      return result;
    }
  }

  static Future<String> getGoogleLyrics({
    required String title,
    required String artist,
  }) async {
    const String url =
        'https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=';
    const String delimiter1 =
        '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const String delimiter2 =
        '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';
    String lyrics = '';
    try {
      lyrics = (await get(
        Uri.parse(Uri.encodeFull('$url$title by $artist lyrics')),
      ).timeout(const Duration(seconds: 8)))
          .body;
      lyrics = lyrics.split(delimiter1).last;
      lyrics = lyrics.split(delimiter2).first;
      if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
    } catch (_) {
      try {
        lyrics = (await get(
          Uri.parse(
            Uri.encodeFull('$url$title by $artist song lyrics'),
          ),
        ).timeout(const Duration(seconds: 8)))
            .body;
        lyrics = lyrics.split(delimiter1).last;
        lyrics = lyrics.split(delimiter2).first;
        if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
      } catch (_) {
        try {
          lyrics = (await get(
            Uri.parse(
              Uri.encodeFull(
                '$url${title.split("-").first} by $artist lyrics',
              ),
            ),
          ).timeout(const Duration(seconds: 8)))
              .body;
          lyrics = lyrics.split(delimiter1).last;
          lyrics = lyrics.split(delimiter2).first;
          if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
        } catch (_) {
          lyrics = '';
        }
      }
    }
    final trimmed = lyrics.trim();
    if (isHtmlOrChallenge(trimmed)) return '';
    return trimmed;
  }

  static Future<String> getOffLyrics(String path) async {
    try {
      final Audiotagger tagger = Audiotagger();
      final Tag? tags = await tagger.readTags(path: path);
      final raw = tags?.lyrics ?? '';
      if (isHtmlOrChallenge(raw)) return '';
      return raw;
    } catch (e) {
      return '';
    }
  }

  static Future<String> getLyricsLink(String song, String artist) async {
    const String authority = 'www.musixmatch.com';
    final String unencodedPath = '/search/$song $artist';
    final Response res = await get(
      Uri.https(authority, unencodedPath),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return '';
    final RegExpMatch? result =
        RegExp(r'href=\"(\/lyrics\/.*?)\"').firstMatch(res.body);
    return result == null ? '' : result[1]!;
  }

  static Future<String> scrapLink(String unencodedPath) async {
    Logger.root.info('Trying to scrap lyrics from $unencodedPath');
    const String authority = 'www.musixmatch.com';
    final Response res = await get(
      Uri.https(authority, unencodedPath),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return '';
    final List<String?> lyrics = RegExp(
      r'<span class=\"lyrics__content__ok\">(.*?)<\/span>',
      dotAll: true,
    ).allMatches(utf8.decode(res.bodyBytes)).map((m) => m[1]).toList();

    final result = lyrics.isEmpty ? '' : lyrics.join('\n');
    if (isHtmlOrChallenge(result)) return '';
    return result;
  }

  static Future<String> getMusixMatchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final String link = await getLyricsLink(title, artist);
      Logger.root.info('Found Musixmatch Lyrics Link: $link');
      if (link.isEmpty) return '';
      final String lyrics = await scrapLink(link);
      return lyrics;
    } catch (e) {
      Logger.root.severe('Error in getMusixMatchLyrics', e);
      return '';
    }
  }
}
