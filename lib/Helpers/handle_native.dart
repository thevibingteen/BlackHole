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

import 'package:blackhole/Helpers/route_handler.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

void handleSharedText(
  String sharedText,
  GlobalKey<NavigatorState> navigatorKey,
) {
  final String cleanText = sharedText.trim();
  if (cleanText.isEmpty) return;

  // Add a delay to allow the app to load completely before handling the route
  Future.delayed(const Duration(seconds: 1), () {
    try {
      final route = HandleRoute.handleRoute(cleanText);
      if (route != null) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(route);
        } else {
          Logger.root.warning(
            'handleSharedText: navigatorKey.currentState is null, retrying after 500ms',
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            navigatorKey.currentState?.push(route);
          });
        }
      }
    } catch (e) {
      Logger.root.severe('Error in handleSharedText: $e');
    }
  });
}
