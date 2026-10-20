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

import 'package:logging/logging.dart';

bool compareVersion(String latestVersion, String currentVersion) {
  try {
    final cleanLatest = latestVersion.trim().replaceAll(RegExp(r'^[vV]'), '');
    final cleanCurrent = currentVersion.trim().replaceAll(RegExp(r'^[vV]'), '');

    List<int> parseParts(String v) {
      return v.split('.').map((p) {
        final digits = RegExp(r'^\d+').firstMatch(p)?.group(0);
        return digits != null ? int.parse(digits) : 0;
      }).toList();
    }

    final latestParts = parseParts(cleanLatest);
    final currentParts = parseParts(cleanCurrent);

    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  } catch (e) {
    Logger.root.severe('Error while comparing versions: $e');
    return false;
  }
}
