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
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

/// Pure-Dart SHA-256 implementation compliant with FIPS 180-2.
class _PureSha256 {
  static final List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static Uint8List hash(List<int> data) {
    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final int bitLength = data.length * 8;
    final int padLength = ((data.length + 8) ~/ 64 + 1) * 64;
    final Uint8List padded = Uint8List(padLength);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    final ByteData bd = ByteData.view(padded.buffer);
    bd.setUint64(padLength - 8, bitLength, Endian.big);

    final List<int> w = List.filled(64, 0);

    for (int i = 0; i < padLength; i += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = bd.getUint32(i + t * 4, Endian.big);
      }
      for (int t = 16; t < 64; t++) {
        final int s0 =
            _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
        final int s1 =
            _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int t = 0; t < 64; t++) {
        final int s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final int ch = (e & f) ^ ((~e) & g);
        final int temp1 = (h + s1 + ch + _k[t] + w[t]) & 0xFFFFFFFF;
        final int s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final int maj = (a & b) ^ (a & c) ^ (b & c);
        final int temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final Uint8List out = Uint8List(32);
    final ByteData outBd = ByteData.view(out.buffer);
    outBd.setUint32(0, h0, Endian.big);
    outBd.setUint32(4, h1, Endian.big);
    outBd.setUint32(8, h2, Endian.big);
    outBd.setUint32(12, h3, Endian.big);
    outBd.setUint32(16, h4, Endian.big);
    outBd.setUint32(20, h5, Endian.big);
    outBd.setUint32(24, h6, Endian.big);
    outBd.setUint32(28, h7, Endian.big);
    return out;
  }
}

class SpotifyApi {
  final List<String> _scopes = [
    'user-read-private',
    'user-read-email',
    'playlist-read-private',
    'playlist-read-collaborative',
  ];

  static const String _defaultClientId = 'fcaf490c5719430595cd17c577c04489';
  static const String configuredClientId =
      String.fromEnvironment('SPOTIFY_CLIENT_ID', defaultValue: '');

  String get clientID =>
      configuredClientId.isNotEmpty ? configuredClientId : _defaultClientId;

  final String redirectUrl = 'app://blackhole/auth';
  final String spotifyApiUrl = 'https://accounts.spotify.com/api';
  final String spotifyApiBaseUrl = 'https://api.spotify.com/v1';
  final String spotifyUserPlaylistEndpoint = '/me/playlists';
  final String spotifyPlaylistTrackEndpoint = '/playlists';
  final String spotifyRegionalChartsEndpoint = '/views/charts-regional';
  final String spotifyFeaturedPlaylistsEndpoint = '/browse/featured-playlists';
  final String spotifyBaseUrl = 'https://accounts.spotify.com';
  final String requestToken = 'https://accounts.spotify.com/api/token';

  /// Generates a high-entropy PKCE code verifier (RFC 7636).
  static String generateCodeVerifier([int length = 64]) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Generates an unpadded Base64URL-encoded SHA-256 code challenge (RFC 7636).
  static String generateCodeChallenge(String verifier) {
    final hash = _PureSha256.hash(ascii.encode(verifier));
    return base64Url.encode(hash).replaceAll('=', '');
  }

  /// Prepares the Spotify authorization URL using PKCE.
  String requestAuthorization([String? codeChallenge]) {
    String challenge = codeChallenge ?? '';
    if (challenge.isEmpty) {
      final verifier = generateCodeVerifier();
      challenge = generateCodeChallenge(verifier);
      try {
        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('spotifyCodeVerifier', verifier);
        }
      } catch (e) {
        Logger.root.warning('Failed to save spotifyCodeVerifier: $e');
      }
    }
    return 'https://accounts.spotify.com/authorize?client_id=$clientID&response_type=code&redirect_uri=$redirectUrl&scope=${_scopes.join('%20')}&code_challenge_method=S256&code_challenge=$challenge';
  }

  /// Exchanges an authorization code or refresh token for Spotify access tokens.
  /// Follows the standard PKCE flow (no client secret in mobile client).
  Future<List<String>> getAccessToken({
    String? code,
    String? refreshToken,
    String? codeVerifier,
  }) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    Map<String, String>? body;
    if (code != null) {
      final cleanCode = code
          .replaceFirst('code=', '')
          .split('&')
          .first
          .trim();
      final verifier = codeVerifier ??
          (Hive.isBoxOpen('settings')
              ? Hive.box('settings').get('spotifyCodeVerifier')?.toString()
              : null);

      body = {
        'grant_type': 'authorization_code',
        'client_id': clientID,
        'code': cleanCode,
        'redirect_uri': redirectUrl,
      };
      if (verifier != null && verifier.isNotEmpty) {
        body['code_verifier'] = verifier;
      }
    } else if (refreshToken != null) {
      body = {
        'grant_type': 'refresh_token',
        'client_id': clientID,
        'refresh_token': refreshToken,
      };
    }

    if (body == null) {
      return [];
    }

    try {
      final Uri path = Uri.parse(requestToken);
      final response = await post(
        path,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map result = jsonDecode(response.body) as Map;
        return <String>[
          result['access_token'].toString(),
          (result['refresh_token'] ?? refreshToken ?? '').toString(),
          result['expires_in'].toString(),
        ];
      } else {
        Logger.root.severe(
          'Error in getAccessToken, returned: ${response.statusCode}',
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
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map && result['items'] is List) {
          final List playlists = result['items'] as List;
          return playlists;
        }
      } else {
        Logger.root.severe(
          'Error in getUserPlaylists, returned: ${response.statusCode}',
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

    final Map data = await getHundredTracksOfPlaylist(
      accessToken,
      playlistId,
      0,
    );
    if (data.isEmpty || data['tracks'] == null) {
      return tracks;
    }
    totalTracks = data['total'] as int? ?? 0;
    tracks.addAll(data['tracks'] as List);

    if (totalTracks > 100) {
      for (int i = 1; i * 100 <= totalTracks; i++) {
        final Map nextData = await getHundredTracksOfPlaylist(
          accessToken,
          playlistId,
          i * 100,
        );
        if (nextData.isNotEmpty && nextData['tracks'] != null) {
          tracks.addAll(nextData['tracks'] as List);
        }
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
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map && result['items'] is List) {
          final List tracks = result['items'] as List;
          final int total = (result['total'] as int?) ?? tracks.length;
          return {'tracks': tracks, 'total': total};
        }
      } else {
        Logger.root.severe(
          'Error in getHundredTracksOfPlaylist, returned: ${response.statusCode}',
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
    try {
      final Uri path = Uri.parse(
        '$spotifyApiBaseUrl/search?q=$query&type=$type&limit=$limit',
      );

      final response = await get(
        path,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map) {
          return result;
        }
      } else {
        Logger.root.severe(
          'Error in searchTrack, returned: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in searchTrack: $e');
    }
    return {};
  }

  Future<Map> getTrackDetails(String accessToken, String trackId) async {
    try {
      final Uri path = Uri.parse(
        '$spotifyApiBaseUrl/tracks/$trackId',
      );
      final response = await get(
        path,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map) {
          return result;
        }
      } else {
        Logger.root.severe(
          'Error in getTrackDetails, returned: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in getTrackDetails: $e');
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
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      final List<Map> songsData = [];
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map &&
            result['playlists'] is Map &&
            result['playlists']['items'] is List) {
          final items = result['playlists']['items'] as List;
          for (final element in items) {
            if (element is Map) {
              songsData.add({
                'name': element['name'],
                'id': element['id'],
                'image': (element['images'] is List &&
                        (element['images'] as List).isNotEmpty)
                    ? element['images'][0]['url']
                    : '',
                'description': element['description'],
                'externalUrl': element['external_urls']?['spotify'],
                'tracks': await getAllTracksOfPlaylist(
                  accessToken,
                  element['id'].toString(),
                ),
              });
            }
          }
        }
      } else {
        Logger.root.severe(
          'Error in getFeaturedPlaylists, returned: ${response.statusCode}',
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
