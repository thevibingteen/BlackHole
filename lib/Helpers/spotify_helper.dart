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

import 'package:app_links/app_links.dart';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

Future<String?> retriveAccessToken() async {
  String? accessToken = Hive.box('settings')
      .get('spotifyAccessToken', defaultValue: null)
      ?.toString();
  String? refreshToken = Hive.box('settings')
      .get('spotifyRefreshToken', defaultValue: null)
      ?.toString();
  final dynamic expireVal =
      Hive.box('settings').get('spotifyTokenExpireAt', defaultValue: 0.0);
  final double expiredAt = (expireVal is num) ? expireVal.toDouble() : 0.0;

  if (accessToken == null || refreshToken == null) {
    return null;
  } else {
    final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
    if ((currentTime + 60) >= expiredAt) {
      final List<String> data =
          await SpotifyApi().getAccessToken(refreshToken: refreshToken);
      if (data.isNotEmpty) {
        Hive.box('settings').put('spotifySigned', true);
        accessToken = data[0];
        Hive.box('settings').put('spotifyAccessToken', data[0]);
        if (data.length > 1 && data[1] != 'null' && data[1].isNotEmpty) {
          refreshToken = data[1];
          Hive.box('settings').put('spotifyRefreshToken', data[1]);
        }
        if (data.length > 2) {
          Hive.box('settings').put(
            'spotifyTokenExpireAt',
            currentTime + (double.tryParse(data[2]) ?? 3600.0),
          );
        }
      }
    }
    return accessToken;
  }
}

Future<void> callSpotifyFunction({
  required Function(String accessToken)? function,
  bool forceSign = true,
}) async {
  final String? accessToken = await retriveAccessToken();
  if (accessToken != null && function != null) {
    return await function.call(accessToken);
  }
  if (accessToken == null && forceSign) {
    final verifier = SpotifyApi.generateCodeVerifier();
    final challenge = SpotifyApi.generateCodeChallenge(verifier);
    Hive.box('settings').put('spotifyCodeVerifier', verifier);

    final authUrl =
        SpotifyApi().requestAuthorization(challenge);

    try {
      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      Logger.root.severe('Error launching Spotify auth URL: $e');
    }

    final appLinks = AppLinks();
    StreamSubscription? sub;
    sub = appLinks.allUriLinkStream.listen(
      (uri) async {
        final link = uri.toString();
        if (link.contains('code=')) {
          final code = uri.queryParameters['code'] ??
              link.split('code=')[1].split('&')[0];
          Hive.box('settings').put('spotifyAppCode', code);
          final savedVerifier =
              Hive.box('settings').get('spotifyCodeVerifier')?.toString() ??
                  verifier;
          final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
          final List<String> data = await SpotifyApi().getAccessToken(
            code: code,
            codeVerifier: savedVerifier,
          );
          if (data.isNotEmpty) {
            Hive.box('settings').put('spotifySigned', true);
            Hive.box('settings').put('spotifyAccessToken', data[0]);
            if (data.length > 1 && data[1] != 'null' && data[1].isNotEmpty) {
              Hive.box('settings').put('spotifyRefreshToken', data[1]);
            }
            if (data.length > 2) {
              Hive.box('settings').put(
                'spotifyTokenExpireAt',
                currentTime + (double.tryParse(data[2]) ?? 3600.0),
              );
            }
            if (function != null) {
              await function.call(data[0]);
            }
            sub?.cancel();
          }
        }
      },
      onError: (err) {
        Logger.root.warning('Error listening to Spotify auth link: $err');
      },
    );
  }
}
