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

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/Helpers/format.dart';
import 'package:blackhole/Helpers/playlist.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ignore: avoid_classes_with_only_static_members
class SearchAddPlaylist {
  static String? parseYtPlaylistId(String inLink) {
    final trimmed = inLink.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'[?&]list=([^#&]+)').firstMatch(trimmed);
    if (match != null) return match.group(1);
    if (!trimmed.contains('/') && trimmed.length >= 10) return trimmed;
    return null;
  }

  static String? parseSpotifyPlaylistId(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;
    final uriMatch =
        RegExp(r'spotify:playlist:([a-zA-Z0-9]+)').firstMatch(trimmed);
    if (uriMatch != null) return uriMatch.group(1);
    final urlMatch = RegExp(r'playlist\/([a-zA-Z0-9]+)').firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  static Future<Map> addYtPlaylist(String inLink) async {
    try {
      final String? playlistId = parseYtPlaylistId(inLink);
      if (playlistId != null && playlistId.isNotEmpty) {
        final Playlist metadata =
            await YouTubeServices().getPlaylistDetails(playlistId);
        final List<Video> tracks =
            await YouTubeServices().getPlaylistSongs(playlistId);
        return {
          'title': metadata.title,
          'image': metadata.thumbnails.standardResUrl,
          'author': metadata.author,
          'description': metadata.description,
          'tracks': tracks,
          'count': tracks.length,
        };
      }
      return {};
    } catch (e) {
      Logger.root.severe('Error while adding YT playlist: $e');
      return {};
    }
  }

  static Future<Map> addSpotifyPlaylist(
    String title,
    String accessToken,
    String playlistId,
  ) async {
    try {
      final List tracks =
          await SpotifyApi().getAllTracksOfPlaylist(accessToken, playlistId);
      return {
        'title': title,
        'count': tracks.length,
        'tracks': tracks,
      };
    } catch (e) {
      Logger.root.severe('Error while adding Spotify playlist: $e');
      return {};
    }
  }

  static Future<String?> parseDeezerPlaylistId(String link) async {
    final trimmed = link.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return trimmed;
    }
    final match = RegExp(r'(?:playlist|album)\/(\d+)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1);
    }
    if (trimmed.contains('deezer.page.link') ||
        trimmed.contains('deezer.com')) {
      try {
        final req = Request('GET', Uri.parse(trimmed))..followRedirects = false;
        final client = Client();
        final streamed =
            await client.send(req).timeout(const Duration(seconds: 10));
        client.close();
        final location = streamed.headers['location'];
        if (location != null && location.isNotEmpty) {
          final locMatch =
              RegExp(r'(?:playlist|album)\/(\d+)').firstMatch(location);
          if (locMatch != null) {
            return locMatch.group(1);
          }
        }
      } catch (e) {
        Logger.root.warning('Failed to resolve Deezer redirect: $e');
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> getDeezerPlaylistDetails({
    required String playlistId,
  }) async {
    final Uri link = Uri.parse('https://api.deezer.com/playlist/$playlistId');
    try {
      final Response response =
          await get(link).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        Logger.root.warning('Deezer API returned ${response.statusCode}');
        return {};
      }
      final dynamic res = jsonDecode(response.body);
      if (res is! Map) return {};
      if (res['error'] != null) {
        Logger.root.warning('Deezer API error: ${res['error']}');
        return {};
      }
      final String title = res['title']?.toString() ?? 'Deezer Playlist';
      final List allTracks = [];
      if (res['tracks'] is Map && res['tracks']['data'] is List) {
        allTracks.addAll(res['tracks']['data'] as List);
        String? nextUrl = res['tracks']['next']?.toString();
        while (
            nextUrl != null && nextUrl.isNotEmpty && allTracks.length < 500) {
          try {
            final pageRes = await get(Uri.parse(nextUrl))
                .timeout(const Duration(seconds: 10));
            if (pageRes.statusCode == 200) {
              final dynamic pageJson = jsonDecode(pageRes.body);
              if (pageJson is Map && pageJson['data'] is List) {
                allTracks.addAll(pageJson['data'] as List);
                nextUrl = pageJson['next']?.toString();
              } else {
                break;
              }
            } else {
              break;
            }
          } catch (_) {
            break;
          }
        }
      }
      return {
        'title': title,
        'count': allTracks.length,
        'tracks': allTracks,
        'image': res['picture_medium']?.toString() ?? '',
      };
    } catch (e) {
      Logger.root.severe('Error fetching Deezer playlist: $e');
      return {};
    }
  }

  static Future<Map> addDeezerPlaylist(String inLink) async {
    try {
      final String? playlistId = await parseDeezerPlaylistId(inLink);
      if (playlistId != null && playlistId.isNotEmpty) {
        return await getDeezerPlaylistDetails(playlistId: playlistId);
      }
      return {};
    } catch (e) {
      Logger.root.severe('Error while adding Deezer playlist: $e');
      return {};
    }
  }

  static Stream<Map> deezerSongsAdder(String playName, List tracks) async* {
    int done = 0;
    for (final track in tracks) {
      String? trackName;
      String? artistName;
      try {
        trackName = track['title']?.toString() ?? '';
        artistName = track['artist']?['name']?.toString() ?? '';
        final displayName =
            artistName.isNotEmpty ? '$trackName - $artistName' : trackName;
        yield {'done': ++done, 'name': displayName};
      } catch (e) {
        yield {'done': ++done, 'name': ''};
      }
      try {
        final query = (artistName != null && artistName.isNotEmpty)
            ? '$trackName by $artistName'
            : (trackName ?? '');
        if (query.isNotEmpty) {
          final List result = await SaavnAPI().fetchTopSearchResult(query);
          if (result.isNotEmpty && result[0] is Map) {
            addMapToPlaylist(playName, result[0] as Map);
          }
        }
      } catch (e) {
        Logger.root.severe('Error adding track $done: $e');
      }
    }
  }

  static Future<Map> addRessoPlaylist(String inLink) async {
    try {
      final RegExpMatch? id = RegExp(r'.*?id\=(.*)&').firstMatch('$inLink&');
      if (id != null) {
        final List tracks = await getRessoSongs(playlistId: id[1]!);
        return {
          'title': 'Resso Playlist',
          'count': tracks.length,
          'tracks': tracks,
        };
      } else {
        final Request req = Request('Get', Uri.parse(inLink))
          ..followRedirects = false;
        final Client baseClient = Client();
        final StreamedResponse response = await baseClient.send(req);
        final Uri redirectUri =
            Uri.parse(response.headers['location'].toString());
        baseClient.close();
        final RegExpMatch? id2 =
            RegExp(r'.*?id\=(.*)&').firstMatch('$redirectUri&');
        if (id2 != null) {
          final List tracks = await getRessoSongs(playlistId: id2[1]!);
          return {
            'title': 'Resso Playlist',
            'count': tracks.length,
            'tracks': tracks,
          };
        }
      }
      return {};
    } catch (e) {
      Logger.root.severe('Error while adding Resso playlist: $e');
      return {};
    }
  }

  static Future<List> getRessoSongs({required String playlistId}) async {
    const url = 'https://api.resso.app/resso/playlist/detail?playlist_id=';
    final Uri link = Uri.parse(url + playlistId);
    try {
      final Response response =
          await get(link).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        Logger.root.warning(
          'Resso service returned status ${response.statusCode} (service retired/unavailable)',
        );
        return [];
      }
      final res = jsonDecode(response.body);
      if (res is Map && res['tracks'] is List) {
        return res['tracks'] as List;
      }
    } catch (e) {
      Logger.root
          .warning('Resso service error (service retired/unavailable): $e');
    }
    return [];
  }

  static String parseJioSaavnToken(String inLink) {
    try {
      final uri = Uri.parse(inLink.trim());
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (pathSegments.isNotEmpty) {
        return pathSegments.last;
      }
    } catch (_) {}
    final cleaned =
        inLink.trim().split('?').first.replaceAll(RegExp(r'/+$'), '');
    return cleaned.split('/').last;
  }

  static Future<Map> addJioSaavnPlaylist(String inLink) async {
    try {
      final String id = parseJioSaavnToken(inLink);
      final String type = inLink.contains('/album/') ? 'album' : 'playlist';
      if (id.isNotEmpty) {
        final Map data = await SaavnAPI().getSongFromToken(id, type, n: -1);
        final rawTracks = (data['list'] ?? data['songs']) as List? ?? [];
        if (data.isNotEmpty && rawTracks.isNotEmpty) {
          final List formattedTracks =
              await FormatResponse.formatSongsResponse(rawTracks, type);
          return {
            'title': data['title'] ?? 'JioSaavn Playlist',
            'count': formattedTracks.length,
            'tracks': formattedTracks,
          };
        }
      }
      return {};
    } catch (e) {
      Logger.root.severe('Error while adding JioSaavn playlist: $e');
      return {};
    }
  }

  static Stream<Map> ytSongsAdder(String playName, List tracks) async* {
    int done = 0;
    for (final track in tracks) {
      String? trackName;
      try {
        final video = track as Video;
        trackName = video.title;
        yield {'done': ++done, 'name': trackName};

        final Map songMap = {
          'id': video.id.value,
          'album': video.author.replaceAll('- Topic', '').trim(),
          'duration': video.duration?.inSeconds.toString() ?? '0',
          'title': video.title.trim(),
          'artist': video.author.replaceAll('- Topic', '').trim(),
          'image': video.thumbnails.highResUrl,
          'secondImage': video.thumbnails.standardResUrl,
          'language': 'YouTube',
          'genre': 'YouTube',
          'expire_at': 0,
          'url': '',
          'lowUrl': '',
          'highUrl': '',
          'year': video.uploadDate?.year.toString() ?? '',
          '320kbps': 'false',
          'has_lyrics': 'false',
          'release_date': video.publishDate.toString(),
          'album_id': video.channelId.value,
          'subtitle': video.author,
          'perma_url': video.url,
        };
        addMapToPlaylist(playName, songMap);
      } catch (e) {
        yield {'done': ++done, 'name': ''};
        Logger.root.severe('Error adding YouTube track $done: $e');
      }
    }
  }

  static Stream<Map> spotifySongsAdder(String playName, List tracks) async* {
    int done = 0;
    for (final track in tracks) {
      String? trackName;
      String? artistName;
      try {
        trackName = track['track']['name'].toString();
        artistName = (track['track']['artists'] as List)
            .map((e) => e['name'])
            .toList()
            .join(', ');
        yield {'done': ++done, 'name': '$trackName - $artistName'};
      } catch (e) {
        yield {'done': ++done, 'name': ''};
      }
      try {
        final List result =
            await SaavnAPI().fetchTopSearchResult('$trackName by $artistName');
        addMapToPlaylist(playName, result[0] as Map);
      } catch (e) {
        Logger.root.severe('Error in $done: $e');
      }
    }
  }

  static Stream<Map> ressoSongsAdder(String playName, List tracks) async* {
    int done = 0;
    for (final track in tracks) {
      String? trackName;
      String? artistName;
      try {
        trackName = track['name'].toString();
        artistName = (track['artists'] as List)
            .map((e) => e['name'])
            .toList()
            .join(', ');

        yield {'done': ++done, 'name': '$trackName - $artistName'};
      } catch (e) {
        yield {'done': ++done, 'name': ''};
      }
      try {
        final List result =
            await SaavnAPI().fetchTopSearchResult('$trackName by $artistName');
        addMapToPlaylist(playName, result[0] as Map);
      } catch (e) {
        Logger.root.severe('Error in $done: $e');
      }
    }
  }

  static Future<void> showProgress(
    int total,
    BuildContext cxt,
    Stream songAdd,
  ) async {
    if (total != 0) {
      await showModalBottomSheet(
        isDismissible: false,
        backgroundColor: Colors.transparent,
        context: cxt,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStt) {
              return BottomGradientContainer(
                child: SizedBox(
                  height: 300,
                  width: 300,
                  child: StreamBuilder<Object>(
                    stream: songAdd as Stream<Object>?,
                    builder: (ctxt, AsyncSnapshot snapshot) {
                      final Map? data = snapshot.data as Map?;
                      final int done = (data ?? const {})['done'] as int? ?? 0;
                      final String name =
                          (data ?? const {})['name'] as String? ?? '';
                      if (done == total) Navigator.pop(ctxt);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Center(
                            child: Text(
                              AppLocalizations.of(context)!.convertingSongs,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(
                            height: 80,
                            width: 80,
                            child: Stack(
                              children: [
                                Center(
                                  child: Text('$done / $total'),
                                ),
                                Center(
                                  child: SizedBox(
                                    height: 77,
                                    width: 77,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(ctxt).colorScheme.secondary,
                                      ),
                                      value: done / total,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }
}
