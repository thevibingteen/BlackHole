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

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ignore: avoid_classes_with_only_static_members
class ExtStorageProvider {
  // asking for permission
  static Future<bool> requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    }

    if (Platform.isAndroid && permission == Permission.storage) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          if (await Permission.audio.isGranted) {
            return true;
          }
          final audioResult = await Permission.audio.request();
          if (audioResult == PermissionStatus.granted) {
            return true;
          }
        }
      } catch (e) {
        Logger.root.warning('Error querying Android SDK version: $e');
      }
    }

    final result = await permission.request();
    return result == PermissionStatus.granted;
  }

  // getting external storage path
  static Future<String?> getExtStorage({
    required String dirName,
    required bool writeAccess,
  }) async {
    try {
      if (Platform.isAndroid) {
        final Directory? extDir = await getExternalStorageDirectory();
        if (extDir == null) {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          return appDocDir.path;
        }

        final String targetPath = extDir.path
            .replaceFirst('Android/data/com.shadow.blackhole/files', dirName);
        final Directory targetDir = Directory(targetPath);

        bool canUseTarget = false;
        try {
          if (await targetDir.exists()) {
            canUseTarget = true;
          } else {
            await requestPermission(Permission.storage);
            if (writeAccess) {
              await Permission.manageExternalStorage.request();
            }
            await targetDir.create(recursive: true);
            canUseTarget = await targetDir.exists();
          }
        } catch (e) {
          Logger.root
              .info('Target directory $targetPath not directly accessible: $e');
          canUseTarget = false;
        }

        if (canUseTarget) {
          return targetPath;
        }

        // Graceful fallback to app-specific external files directory
        final Directory fallbackDir = Directory('${extDir.path}/$dirName');
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        return fallbackDir.path;
      } else if (Platform.isIOS) {
        final Directory directory = await getApplicationDocumentsDirectory();
        return directory.path;
      } else {
        final Directory? directory = await getDownloadsDirectory();
        return directory?.path ??
            (await getApplicationDocumentsDirectory()).path;
      }
    } catch (e) {
      Logger.root.severe('Error getting storage directory: $e');
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      return appDocDir.path;
    }
  }
}
