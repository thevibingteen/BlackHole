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

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/Helpers/audio_query.dart';
import 'package:blackhole/Helpers/spotify_helper.dart';
import 'package:blackhole/Screens/Common/song_list.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Screens/Search/search.dart';
import 'package:blackhole/Screens/YouTube/youtube_playlist.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:on_audio_query/on_audio_query.dart';

class YouTubeParsedItem {
  final String id;
  final String type; // 'v' or 'list'

  const YouTubeParsedItem({required this.id, required this.type});
}

// ignore: avoid_classes_with_only_static_members
class HandleRoute {
  static bool isYouTubeHost(String host) {
    final h = host.toLowerCase().trim();
    return h == 'youtube.com' ||
        h.endsWith('.youtube.com') ||
        h == 'youtu.be' ||
        h.endsWith('.youtu.be');
  }

  static bool isJioSaavnHost(String host) {
    final h = host.toLowerCase().trim();
    return h == 'jiosaavn.com' ||
        h.endsWith('.jiosaavn.com') ||
        h == 'saavn.com' ||
        h.endsWith('.saavn.com');
  }

  static bool isSpotifyHost(String host) {
    final h = host.toLowerCase().trim();
    return h == 'spotify.com' || h.endsWith('.spotify.com');
  }

  static String? _lastHandledUrl;
  static DateTime? _lastHandledTime;

  static bool isDuplicate(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final String clean = url.trim();
    final DateTime now = DateTime.now();
    if (_lastHandledUrl == clean &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 3)) {
      return true;
    }
    _lastHandledUrl = clean;
    _lastHandledTime = now;
    return false;
  }

  static YouTubeParsedItem? parseYouTubeUrl(String? input) {
    if (input == null) return null;
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 1. Extract URL if embedded in surrounding text (e.g. "Check out https://youtu.be/xyz")
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(trimmed);
    final String urlStr = urlMatch != null ? urlMatch.group(0)! : trimmed;

    final Uri? parsedUri =
        Uri.tryParse(urlStr.contains('://') ? urlStr : 'https://$urlStr');
    if (parsedUri == null) return null;
    final String scheme = parsedUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    final String host = parsedUri.host.toLowerCase();
    if (!isYouTubeHost(host)) return null;

    final listParam = parsedUri.queryParameters['list']?.trim();
      final vParam = parsedUri.queryParameters['v']?.trim();

      // If it's explicitly a /playlist route with a list param
      if (parsedUri.pathSegments.contains('playlist') &&
          listParam != null &&
          listParam.isNotEmpty) {
        return YouTubeParsedItem(id: listParam, type: 'list');
      }

      // If video parameter is explicitly present
      if (vParam != null && vParam.isNotEmpty) {
        return YouTubeParsedItem(id: vParam, type: 'v');
      }

      // If list parameter is present without video parameter
      if (listParam != null && listParam.isNotEmpty) {
        return YouTubeParsedItem(id: listParam, type: 'list');
      }

      // youtu.be/<id> short link
      if (host.endsWith('youtu.be') && parsedUri.pathSegments.isNotEmpty) {
        final segmentId = parsedUri.pathSegments.first.trim();
        if (segmentId.isNotEmpty && !segmentId.contains('/')) {
          return YouTubeParsedItem(id: segmentId, type: 'v');
        }
      }

      // /shorts/<id>
      if (parsedUri.pathSegments.contains('shorts')) {
        final idx = parsedUri.pathSegments.indexOf('shorts');
        if (idx + 1 < parsedUri.pathSegments.length) {
          final sId = parsedUri.pathSegments[idx + 1].trim();
          if (sId.isNotEmpty) {
            return YouTubeParsedItem(id: sId, type: 'v');
          }
        }
      }

      // /embed/<id> or /v/<id>
      for (final prefix in ['embed', 'v']) {
        if (parsedUri.pathSegments.contains(prefix)) {
          final idx = parsedUri.pathSegments.indexOf(prefix);
          if (idx + 1 < parsedUri.pathSegments.length) {
            final eId = parsedUri.pathSegments[idx + 1].trim();
            if (eId.isNotEmpty) {
              return YouTubeParsedItem(id: eId, type: 'v');
            }
          }
        }
      }

    // Fallback regex for non-standard formats or embedded links
    final listRegex = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(urlStr);
    if (listRegex != null && !urlStr.contains('v=')) {
      return YouTubeParsedItem(id: listRegex.group(1)!, type: 'list');
    }

    final videoRegex = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|shorts\/|watch\?(?:.*&)?v=))([a-zA-Z0-9_-]{11})',
    ).firstMatch(urlStr);
    if (videoRegex != null) {
      return YouTubeParsedItem(id: videoRegex.group(1)!, type: 'v');
    }

    return null;
  }

  static Route? handleRoute(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final String cleanUrl = url.trim();
    Logger.root.info('received route url: $cleanUrl');
    if (isDuplicate(cleanUrl)) {
      Logger.root.info(
        'Ignoring duplicate route delivery within debounce window: $cleanUrl',
      );
      return null;
    }
    final Uri? uri =
        Uri.tryParse(cleanUrl.contains('://') ? cleanUrl : 'https://$cleanUrl');
    final String host = uri?.host.toLowerCase() ?? '';

    if (uri != null && isJioSaavnHost(host)) {
      final RegExpMatch? songResult =
          RegExp(r'.*saavn\.com.*?\/(song)\/.*?\/(.*)').firstMatch('$cleanUrl?');
      if (songResult != null) {
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => SaavnUrlHandler(
            token: songResult[2]!,
            type: songResult[1]!,
          ),
        );
      } else {
        final RegExpMatch? playlistResult = RegExp(
          r'.*saavn\.com\/?s?\/(featured|playlist|album)\/.*\/(.*_)?[?/]',
        ).firstMatch('$cleanUrl?');
        if (playlistResult != null) {
          return PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => SaavnUrlHandler(
              token: playlistResult[2]!,
              type: playlistResult[1]!,
            ),
          );
        }
      }
    } else if (uri != null && isSpotifyHost(host)) {
      Logger.root.info('received spotify link');
      final RegExpMatch? songResult =
          RegExp(r'.*spotify\.com.*?\/(track)\/(.*?)[/?]').firstMatch('$cleanUrl/');
      if (songResult != null) {
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => SpotifyUrlHandler(
            id: songResult[2]!,
            type: songResult[1]!,
          ),
        );
      }
    } else if (uri != null && isYouTubeHost(host)) {
      final YouTubeParsedItem? item = parseYouTubeUrl(cleanUrl);
      if (item != null) {
        Logger.root.info(
          'Parsed YouTube deep link: id=${item.id}, type=${item.type}',
        );
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => YtUrlHandler(
            id: item.id,
            type: item.type,
          ),
        );
      }
    } else {
      final RegExpMatch? fileResult =
          RegExp(r'\/[0-9]+\/([0-9]+)\/').firstMatch('$cleanUrl/');
      if (fileResult != null) {
        return PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => OfflinePlayHandler(
            id: fileResult[1]!,
          ),
        );
      }
    }
    return null;
  }
}

class SaavnUrlHandler extends StatelessWidget {
  final String token;
  final String type;
  const SaavnUrlHandler({super.key, required this.token, required this.type});

  @override
  Widget build(BuildContext context) {
    SaavnAPI().getSongFromToken(token, type).then((value) {
      if (!context.mounted) return;
      if (type == 'song') {
        if (value['songs'] != null && (value['songs'] as List).isNotEmpty) {
          PlayerInvoke.init(
            songsList: value['songs'] as List,
            index: 0,
            isOffline: false,
          );
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => const PlayScreen(),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
      if (type == 'album' || type == 'playlist' || type == 'featured') {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => SongsListPage(
              listItem: value,
            ),
          ),
        );
      }
    }).catchError((error, stackTrace) {
      Logger.root.severe('Error getting shared song from token', error);
      if (context.mounted) {
        Navigator.pop(context);
      }
    });
    return Container();
  }
}

class SpotifyUrlHandler extends StatelessWidget {
  final String id;
  final String type;
  const SpotifyUrlHandler({super.key, required this.id, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == 'track') {
      callSpotifyFunction(
        function: (String accessToken) {
          SpotifyApi().getTrackDetails(accessToken, id).then((value) {
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => SearchPage(
                  query: (value['artists'] != null &&
                          (value['artists'] as List).isNotEmpty)
                      ? '${value["name"]} by ${value["artists"][0]["name"]}'
                      : value['name'].toString(),
                ),
              ),
            );
          }).catchError((error, stackTrace) {
            Logger.root.severe('Error getting shared Spotify track details', error);
            if (context.mounted) {
              Navigator.pop(context);
            }
          });
        },
      );
    }
    return Container();
  }
}

class YtUrlHandler extends StatelessWidget {
  final String id;
  final String type;
  const YtUrlHandler({super.key, required this.id, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == 'v') {
      YouTubeServices().formatVideoFromId(id: id).then((Map? response) async {
        if (!context.mounted) return;
        if (response != null &&
            response['url'] != null &&
            response['url'].toString().isNotEmpty) {
          PlayerInvoke.init(
            songsList: [response],
            index: 0,
            isOffline: false,
            recommend: false,
          );
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => const PlayScreen(),
            ),
          );
        } else {
          Logger.root.warning(
            'YtUrlHandler: Unable to resolve playable stream for video $id',
          );
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text('Failed to resolve playable YouTube stream'),
                duration: Duration(seconds: 3),
              ),
            );
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        }
      }).catchError((error, stackTrace) {
        Logger.root.severe('Error resolving shared YouTube video $id', error);
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Error resolving YouTube stream'),
              duration: Duration(seconds: 3),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      });
    } else if (type == 'list') {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => YouTubePlaylist(
              playlistId: id,
            ),
          ),
        );
      });
    }
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class OfflinePlayHandler extends StatelessWidget {
  final String id;
  const OfflinePlayHandler({super.key, required this.id});

  Future<List> playOfflineSong(String id) async {
    final OfflineAudioQuery offlineAudioQuery = OfflineAudioQuery();
    await offlineAudioQuery.requestPermission();

    final List<SongModel> songs = await offlineAudioQuery.getSongs();
    final int index = songs.indexWhere((i) => i.id.toString() == id);

    return [index, songs];
  }

  @override
  Widget build(BuildContext context) {
    playOfflineSong(id).then((value) {
      final int index = value[0] as int;
      final List<SongModel> songs = value[1] as List<SongModel>;

      if (index < 0 || index >= songs.length) {
        Logger.root.warning(
          'OfflinePlayHandler: song ID $id was not found on local storage',
        );
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Song not found on device storage'),
              duration: Duration(seconds: 3),
            ),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        return;
      }

      PlayerInvoke.init(
        songsList: songs,
        index: index,
        isOffline: true,
        recommend: false,
      );
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => const PlayScreen(),
          ),
        );
      }
    });
    return const SizedBox();
  }
}
