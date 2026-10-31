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

import 'package:blackhole/APIs/api.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';

class RadioConnectionHandler {
  static int _activeRequestId = 0;
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _currentIndicator;

  @visibleForTesting
  static int get activeRequestId => _activeRequestId;

  @visibleForTesting
  static void resetForTesting() {
    _activeRequestId = 0;
    try {
      _currentIndicator?.close();
    } catch (_) {}
    _currentIndicator = null;
  }

  /// Connects to a radio station, handles the pending message lifecycle,
  /// initiates playback on success, and dismisses the indicator cleanly.
  static Future<bool> connectAndPlay({
    required BuildContext context,
    required String stationName,
    required String stationType,
    String? language,
    SaavnAPI? api,
    Duration timeout = const Duration(seconds: 15),
    bool shuffle = false,
    Function(List songs)? onPlaybackStarted,
    Function()? onNavigateToPlayer,
  }) async {
    final int currentRequest = ++_activeRequestId;
    final SaavnAPI saavnApi = api ?? SaavnAPI();

    // Close any previous radio pending indicator without touching unrelated SnackBars.
    if (_currentIndicator != null) {
      _dismissIndicator(context, _currentIndicator);
    }

    if (!context.mounted) return false;

    final String connectingText =
        AppLocalizations.of(context)?.connectingRadio ?? 'Connecting to Radio…';

    // Show non-blocking indicator while connection is genuinely pending (no manual OK required).
    final controller = ShowSnackBar().showSnackBar(
      context,
      connectingText,
      duration: timeout,
      noAction: true,
    );
    _currentIndicator = controller;

    try {
      final String? stationId = await saavnApi
          .createRadio(
            names: [stationName],
            language: language,
            stationType: stationType,
          )
          .timeout(timeout);

      // Guard against superseding station changes.
      if (currentRequest != _activeRequestId) {
        Logger.root.info(
          'Radio request $currentRequest superseded by newer request $_activeRequestId',
        );
        return false;
      }

      if (stationId != null && stationId.isNotEmpty) {
        final List songs = await saavnApi
            .getRadioSongs(stationId: stationId)
            .timeout(timeout);

        if (currentRequest != _activeRequestId) {
          Logger.root.info(
            'Radio request $currentRequest superseded by newer request $_activeRequestId',
          );
          return false;
        }

        if (songs.isNotEmpty) {
          // 1. Initiate audio playback.
          if (onPlaybackStarted != null) {
            onPlaybackStarted(songs);
          } else {
            PlayerInvoke.init(
              songsList: songs,
              index: 0,
              isOffline: false,
              shuffle: shuffle,
            );
          }

          // 2. Automatically dismiss the pending indicator upon successful playback startup.
          _dismissIndicator(context, controller);

          // 3. Navigate to player screen if still mounted.
          if (context.mounted) {
            try {
              if (onNavigateToPlayer != null) {
                onNavigateToPlayer();
              } else {
                Navigator.pushNamed(context, '/player');
              }
            } catch (e) {
              Logger.root.warning('Failed to navigate to /player: $e');
            }
          }
          return true;
        }
      }

      // Station resolution failed or returned no songs.
      _dismissAndShowError(context, controller, currentRequest);
      return false;
    } catch (e) {
      Logger.root.severe(
        'Error while connecting to radio station (request $currentRequest): $e',
      );
      _dismissAndShowError(context, controller, currentRequest);
      return false;
    }
  }

  static void _dismissIndicator(
    BuildContext context,
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller,
  ) {
    try {
      controller?.close();
    } catch (_) {}
    if (context.mounted && _currentIndicator == controller) {
      try {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      } catch (_) {}
    }
    if (_currentIndicator == controller) {
      _currentIndicator = null;
    }
  }

  static void _dismissAndShowError(
    BuildContext context,
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller,
    int requestId,
  ) {
    if (requestId != _activeRequestId) return;

    _dismissIndicator(context, controller);

    if (context.mounted) {
      ShowSnackBar().showSnackBar(
        context,
        'Failed to connect to Radio',
        duration: const Duration(seconds: 3),
      );
    }
  }
}
