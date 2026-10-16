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

/// Pure-Dart retry policy for managing audio stream playback retries.
///
/// Prevents infinite retry loops on expiring streaming media (e.g. YouTube CDN 403s)
/// by ensuring at most one retry attempt per unique track ID before transitioning
/// to a controlled terminal error state.
class PlaybackRetryPolicy {
  String? _lastRetriedId;
  bool _isHandling = false;

  /// Whether a retry operation is currently in progress.
  bool get isHandling => _isHandling;

  /// The track ID that was most recently granted a retry attempt.
  String? get lastRetriedId => _lastRetriedId;

  /// Evaluates whether [trackId] is eligible for a playback retry.
  ///
  /// Returns `true` if this is the first failure on [trackId] and no concurrent
  /// retry is active. Returns `false` if [trackId] was already retried (resetting
  /// the tracking to prevent permanent lockouts) or if a retry is currently in flight.
  bool shouldRetry(String trackId) {
    if (_isHandling) return false;
    if (_lastRetriedId == trackId) {
      _lastRetriedId = null;
      return false;
    }
    _lastRetriedId = trackId;
    return true;
  }

  /// Marks a retry operation as underway.
  void beginHandling() {
    _isHandling = true;
  }

  /// Marks the current retry operation as complete.
  void endHandling() {
    _isHandling = false;
  }

  /// Resets internal retry state if the current track ID differs from the retried track ID.
  void resetIfDifferentTrack(String? currentTrackId) {
    if (_lastRetriedId != null && _lastRetriedId != currentTrackId) {
      _lastRetriedId = null;
    }
  }

  /// Resets internal retry state.
  void reset() {
    _lastRetriedId = null;
    _isHandling = false;
  }
}

