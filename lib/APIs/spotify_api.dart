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
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

class SpotifyApi {
  final List<String> _scopes = [
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
  ];

  /// You can signup for spotify developer account and get your own clientID and clientSecret incase you don't want to use these
  String get clientID {
    const envId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
    if (envId.isNotEmpty) return envId;
    if (Hive.isBoxOpen('settings')) {
      final custom = Hive.box('settings').get('spotifyClientId')?.toString().trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    return '';
  }

  String get clientSecret {
    const envSecret = String.fromEnvironment('SPOTIFY_CLIENT_SECRET');
    if (envSecret.isNotEmpty) return envSecret;
    if (Hive.isBoxOpen('settings')) {
      final custom = Hive.box('settings').get('spotifyClientSecret')?.toString().trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    return '';
  }
  final String redirectUrl = 'app://blackhole/auth';
  final String spotifyApiUrl = 'https://accounts.spotify.com/api';
  final String spotifyApiBaseUrl = 'https://api.spotify.com/v1';
  final String spotifyUserPlaylistEndpoint = '/me/playlists';
  final String spotifyPlaylistTrackEndpoint = '/playlists';
  final String spotifyRegionalChartsEndpoint = '/views/charts-regional';
  final String spotifyFeaturedPlaylistsEndpoint = '/browse/featured-playlists';
  final String spotifyBaseUrl = 'https://accounts.spotify.com';
  final String requestToken = 'https://accounts.spotify.com/api/token';

  /// Generates a cryptographically random PKCE code verifier (RFC 7636).
  static String generateCodeVerifier([int length = 64]) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Derives an S256 code challenge from a [codeVerifier] (RFC 7636).
  static String generateCodeChallenge(String codeVerifier) {
    final bytes = ascii.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String requestAuthorization({String? codeChallenge}) {
    final challengeParam = (codeChallenge != null && codeChallenge.isNotEmpty)
        ? '&code_challenge_method=S256&code_challenge=$codeChallenge'
        : '';
    return 'https://accounts.spotify.com/authorize?client_id=$clientID&response_type=code&redirect_uri=$redirectUrl&scope=${_scopes.join('%20')}$challengeParam';
  }

  // Future<String> authenticate() async {
  //   final url = SpotifyApi().requestAuthorization();
  //   final callbackUrlScheme = 'accounts.spotify.com';

  //   try {
  //     final result = await FlutterWebAuth.authenticate(
  //         url: url, callbackUrlScheme: callbackUrlScheme);
  // print('got result....');
  // print(result);
  //     return result;
  //   } catch (e) {
  // print('Got error: $e');
  //     return 'ERROR';
  //   }
  // }

  Future<List<String>> getAccessToken({
    String? code,
    String? refreshToken,
    String? codeVerifier,
  }) async {
    if (clientID.isEmpty) {
      Logger.root.info('Spotify client credentials not configured.');
      return [];
    }
    final Map<String, String> headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final Map<String, String> body = {};
    if (code != null) {
      body['grant_type'] = 'authorization_code';
      body['code'] = code;
      body['redirect_uri'] = redirectUrl;
      body['client_id'] = clientID;
      if (codeVerifier != null && codeVerifier.isNotEmpty) {
        body['code_verifier'] = codeVerifier;
      } else if (clientSecret.isNotEmpty) {
        headers['Authorization'] =
            "Basic ${base64.encode(utf8.encode("$clientID:$clientSecret"))}";
      }
    } else if (refreshToken != null) {
      body['grant_type'] = 'refresh_token';
      body['refresh_token'] = refreshToken;
      body['client_id'] = clientID;
      if (clientSecret.isNotEmpty) {
        headers['Authorization'] =
            "Basic ${base64.encode(utf8.encode("$clientID:$clientSecret"))}";
      }
    }

    if (body.isEmpty) {
      return [];
    }

    try {
      final Uri path = Uri.parse(requestToken);
      final response = await post(path, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map result = jsonDecode(response.body) as Map;
        return <String>[
          result['access_token'].toString(),
          result['refresh_token'].toString(),
          result['expires_in'].toString(),
        ];
      } else {
        Logger.root.severe(
          'Error in getAccessToken, called: $path, returned: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in getting spotify access token: $e');
    }
    return [];
  }

  Future<List> getUserPlaylists(String accessToken) async {
    try {
      final Uri path =
          Uri.parse('$spotifyApiBaseUrl$spotifyUserPlaylistEndpoint?limit=50');

      final response = await get(
        path,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List playlists = result['items'] as List;
        return playlists;
      } else {
        Logger.root.severe(
          'Error in getUserPlaylists, called: $path, returned: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in getting spotify user playlists: $e');
    }
    return [];
  }

  Future<List> getAllTracksOfPlaylist(
    String accessToken,
    String playlistId,
  ) async {
    final List tracks = [];
    int totalTracks = 100;

    final Map data = await SpotifyApi().getHundredTracksOfPlaylist(
      accessToken,
      playlistId,
      0,
    );
    totalTracks = data['total'] as int;
    tracks.addAll(data['tracks'] as List);

    if (totalTracks > 100) {
      for (int i = 1; i * 100 <= totalTracks; i++) {
        final Map data = await SpotifyApi().getHundredTracksOfPlaylist(
          accessToken,
          playlistId,
          i * 100,
        );
        tracks.addAll(data['tracks'] as List);
      }
    }
    return tracks;
  }

  Future<Map> getHundredTracksOfPlaylist(
    String accessToken,
    String playlistId,
    int offset,
  ) async {
    try {
      final Uri path = Uri.parse(
        '$spotifyApiBaseUrl$spotifyPlaylistTrackEndpoint/$playlistId/tracks?limit=100&offset=$offset',
      );
      final response = await get(
        path,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final result = await jsonDecode(response.body);
        final List tracks = result['items'] as List;
        final int total = result['total'] as int;
        return {'tracks': tracks, 'total': total};
      } else {
        Logger.root.severe(
          'Error in getHundredTracksOfPlaylist, called: $path, returned: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in getting spotify playlist tracks: $e');
    }
    return {};
  }

  Future<Map> searchTrack({
    required String accessToken,
    required String query,
    int limit = 10,
    String type = 'track',
  }) async {
    final Uri path = Uri.parse(
      '$spotifyApiBaseUrl/search?q=$query&type=$type&limit=$limit',
    );

    final response = await get(
      path,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map;
      return result;
    } else {
      Logger.root.severe(
        'Error in searchTrack, called: $path, returned: ${response.statusCode}',
        response.body,
      );
    }
    return {};
  }

  Future<Map> getTrackDetails(String accessToken, String trackId) async {
    final Uri path = Uri.parse(
      '$spotifyApiBaseUrl/tracks/$trackId',
    );
    final response = await get(
      path,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json'
      },
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body) as Map;
      return result;
    } else {
      Logger.root.severe(
        'Error in getTrackDetails, called: $path, returned: ${response.statusCode}',
        response.body,
      );
    }
    return {};
  }

  Future<List<Map>> getFeaturedPlaylists(String accessToken) async {
    try {
      final Uri path = Uri.parse(
        '$spotifyApiBaseUrl/browse/featured-playlists',
      );
      final response = await get(
        path,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json'
        },
      );
      final List<Map> songsData = [];
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        await for (final element in result['playlists']['items'] as Stream) {
          songsData.add({
            'name': element['name'],
            'id': element['id'],
            'image': element['images'][0]['url'],
            'description': element['description'],
            'externalUrl': element['external_urls']['spotify'],
            'tracks': await SpotifyApi().getAllTracksOfPlaylist(
              accessToken,
              element['id'].toString(),
            ),
          });
        }
      } else {
        Logger.root.severe(
          'Error in getFeaturedPlaylists, called: $path, returned: ${response.statusCode}',
          response.body,
        );
      }
      return songsData;
    } catch (e) {
      Logger.root.severe('Error in getting spotify featured playlists: $e');
      return List.empty();
    }
  }
}
