/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
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
 */

import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UrlLauncherFunc = Future<bool> Function(
  Uri uri, {
  LaunchMode mode,
});

/// Centralized configuration and safe launching utility for all external URLs.
class AppLinks {
  // External destinations
  static const String buyMeACoffeeUrl =
      'https://buymeacoffee.com/thevibingteen';
  static const String paypalDonationUrl =
      'https://www.paypal.com/ncp/payment/859SMGK59Z48L';
  static const String contactEmail = 'thevibingteen@gmail.com';
  static const String contactEmailUrl = 'mailto:thevibingteen@gmail.com';
  static const String instagramUrl = 'https://www.instagram.com/thevibingteen';
  static const String telegramGroupUrl = 'https://t.me/+_9wHWiHi1MdmMGM1';
  static const String telegramChannelUrl = 'https://t.me/blackholerevived';
  static const String githubRepoUrl =
      'https://github.com/thevibingteen/BlackHole';

  // Optional test hook to mock external launcher without platform dependencies
  static UrlLauncherFunc? launchUrlOverride;

  // Debounce timestamp to prevent duplicate rapid launches
  static DateTime? _lastLaunchTime;

  /// Resets test overrides and state (for unit testing).
  @visibleForTesting
  static void resetForTesting() {
    launchUrlOverride = null;
    _lastLaunchTime = null;
  }

  /// Safely launches an external URL with debounce, error handling, and user feedback.
  static Future<bool> open(
    BuildContext context,
    String urlString, {
    LaunchMode mode = LaunchMode.externalApplication,
    String? failureMessage,
  }) async {
    final now = DateTime.now();
    if (_lastLaunchTime != null &&
        now.difference(_lastLaunchTime!).inMilliseconds < 1000) {
      return false;
    }
    _lastLaunchTime = now;

    try {
      final sanitized = urlString.trim();
      final uri = Uri.parse(sanitized);

      final launcher = launchUrlOverride ?? launchUrl;
      final success = await launcher(uri, mode: mode);
      if (!success && context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          failureMessage ?? 'Unable to open link. Please try again later.',
        );
      }
      return success;
    } catch (e) {
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          failureMessage ?? 'Unable to open link. Please try again later.',
        );
      }
      return false;
    }
  }

  /// Safely launches the email client with a mailto URI and provides feedback on failure.
  static Future<bool> openEmail(BuildContext context) async {
    final now = DateTime.now();
    if (_lastLaunchTime != null &&
        now.difference(_lastLaunchTime!).inMilliseconds < 1000) {
      return false;
    }
    _lastLaunchTime = now;

    try {
      final uri = Uri.parse(contactEmailUrl);
      final launcher = launchUrlOverride ?? launchUrl;
      final success = await launcher(uri, mode: LaunchMode.externalApplication);
      if (!success && context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'No email app found. Please send an email to $contactEmail',
        );
      }
      return success;
    } catch (e) {
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'No email app found. Please send an email to $contactEmail',
        );
      }
      return false;
    }
  }
}
