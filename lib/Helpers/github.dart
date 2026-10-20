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

import 'package:blackhole/Helpers/update.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

enum UpdateCheckStatus {
  updateAvailable,
  upToDate,
  noReleasesFound,
  failed,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final String? message;

  const UpdateCheckResult({
    required this.status,
    this.latestVersion,
    this.releaseUrl,
    this.message,
  });
}

class GitHub {
  static String repo = 'thevibingteen/BlackHole';
  static String baseUrl = 'api.github.com';
  static Map<String, String> headers = {
    'User-Agent': 'BlackHole',
    'Accept': 'application/vnd.github.v3+json',
  };
  static Map<String, String> endpoints = {
    'repo': '/repos',
    'releases': '/releases',
  };
  Map releasesData = {};

  static final GitHub _singleton = GitHub._internal();
  factory GitHub() {
    return _singleton;
  }
  GitHub._internal();

  static Future<Response> getResponse() async {
    final Uri url = Uri.https(
      baseUrl,
      '${endpoints["repo"]}/$repo${endpoints["releases"]}',
    );

    try {
      return await get(url, headers: headers)
          .timeout(const Duration(seconds: 10))
          .onError((error, stackTrace) {
        return Response(
          jsonEncode({
            'status': false,
            'message': error.toString(),
          }),
          404,
        );
      });
    } catch (e) {
      return Response(
        jsonEncode({
          'status': false,
          'message': e.toString(),
        }),
        404,
      );
    }
  }

  static Future<Map> fetchReleases() async {
    final res = await getResponse();
    if (res.statusCode == 200) {
      try {
        final resp = json.decode(res.body);
        if (resp is List && resp.isNotEmpty) {
          return resp[0] as Map;
        } else if (resp is Map) {
          Logger.root.severe('Failed to fetch releases', resp['message']);
        }
      } catch (e) {
        Logger.root.severe('Failed to parse releases response: $e');
      }
    } else {
      Logger.root.warning('Failed to fetch releases, status: ${res.statusCode}');
    }
    return {};
  }

  static Future<UpdateCheckResult> checkUpdate(String currentVersion) async {
    Logger.root.info('Checking for update for $repo');
    try {
      final res = await getResponse();
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is List) {
          if (decoded.isEmpty) {
            return const UpdateCheckResult(
              status: UpdateCheckStatus.noReleasesFound,
              message: 'No published releases found',
            );
          }
          final latestRelease = decoded[0] as Map;
          final rawTag = latestRelease['tag_name']?.toString() ?? '';
          final cleanVersion = rawTag.replaceAll(RegExp(r'^[vV]'), '').trim();
          if (cleanVersion.isEmpty) {
            return const UpdateCheckResult(
              status: UpdateCheckStatus.failed,
              message: 'Invalid release version tag',
            );
          }
          final isNewer = compareVersion(cleanVersion, currentVersion);
          final releaseUrl = latestRelease['html_url']?.toString() ??
              'https://github.com/$repo/releases';
          if (isNewer) {
            return UpdateCheckResult(
              status: UpdateCheckStatus.updateAvailable,
              latestVersion: cleanVersion,
              releaseUrl: releaseUrl,
            );
          } else {
            return UpdateCheckResult(
              status: UpdateCheckStatus.upToDate,
              latestVersion: cleanVersion,
              releaseUrl: releaseUrl,
            );
          }
        } else if (decoded is Map && decoded.containsKey('message')) {
          return UpdateCheckResult(
            status: UpdateCheckStatus.failed,
            message: decoded['message']?.toString(),
          );
        }
      }
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        message: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      Logger.root.severe('Error checking update: $e');
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        message: e.toString(),
      );
    }
  }

  static Future<String> getLatestVersion() async {
    Logger.root.info('Checking for update');
    final Map latestRelease = await fetchReleases();
    if (latestRelease.isEmpty) return '0.0.0';
    Logger.root.info(
      'Latest release: ${(latestRelease["tag_name"] as String?) ?? "v0.0.0"}',
    );
    return ((latestRelease['tag_name'] as String?) ?? 'v0.0.0')
        .replaceAll('v', '');
  }
}
