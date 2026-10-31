/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Helpers/audio_query.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

enum DeleteOutcome {
  fileDeleted,
  staleRecordRemoved,
  permissionDenied,
  failed,
  cancelled,
}

class SongDeleteResult {
  final int filesDeleted;
  final int staleRecordsRemoved;
  final int failed;
  final List<String> removedIds;

  const SongDeleteResult({
    this.filesDeleted = 0,
    this.staleRecordsRemoved = 0,
    this.failed = 0,
    this.removedIds = const [],
  });
}

class SongDeleteHelper {
  static const Set<String> allowedAudioExtensions = {
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.aac',
    '.wma',
    '.m4p',
    '.mid',
    '.midi',
    '.webm',
  };

  static const Set<String> allowedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
  };

  /// Validates that a file path is structurally safe for deletion, resides in permitted
  /// storage locations, has a legitimate media extension, and does not attempt path traversal
  /// or target critical system directories.
  static bool isPathSafeForDeletion(String? rawPath, {bool isArtwork = false}) {
    if (rawPath == null) return false;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return false;

    // 1. Reject embedded null bytes
    if (trimmed.contains('\x00')) return false;

    // 2. Normalize path separators
    final normalized = trimmed.replaceAll('\\', '/');

    // 3. Reject directory traversal sequences
    final segments = normalized.split('/');
    if (segments.contains('..')) return false;

    // 4. Validate extension against allowed media formats
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1) return false;
    final ext = normalized.substring(dotIndex).toLowerCase();
    final allowedExts =
        isArtwork ? allowedImageExtensions : allowedAudioExtensions;
    if (!allowedExts.contains(ext)) return false;

    // 5. Reject critical system, boot, and root filesystem prefixes
    final lower = normalized.toLowerCase();
    final prohibitedPrefixes = [
      '/system',
      '/etc',
      '/sbin',
      '/bin',
      '/usr',
      '/dev',
      '/proc',
      '/sys',
      'c:/windows',
      'c:/program files',
      'c:/program files (x86)',
    ];
    for (final prefix in prohibitedPrefixes) {
      if (lower == prefix || lower.startsWith('$prefix/')) {
        return false;
      }
    }

    // 6. On Android, enforce that media resides strictly in external or app storage
    if (Platform.isAndroid) {
      final allowedAndroidPrefixes = [
        '/storage/',
        '/sdcard/',
        '/data/user/0/com.shadow.blackhole/',
        '/data/data/com.shadow.blackhole/',
      ];
      final isAllowed =
          allowedAndroidPrefixes.any((prefix) => lower.startsWith(prefix));
      if (!isAllowed) {
        return false;
      }
    }

    // 7. Resolve canonical symlink path if the file exists and verify target
    try {
      final file = File(trimmed);
      if (file.existsSync()) {
        final canonical =
            file.resolveSymbolicLinksSync().replaceAll('\\', '/').toLowerCase();
        for (final prefix in prohibitedPrefixes) {
          if (canonical == prefix || canonical.startsWith('$prefix/')) {
            return false;
          }
        }
      }
    } catch (_) {
      // If symlink resolution fails, lexical checks above suffice
    }

    return true;
  }

  static Future<void> coordinateWithAudioHandler(String id, String? path) async {
    try {
      if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
        final handler = PlayerInvoke.audioHandler;
        final currentMedia = handler.mediaItem.value;
        if (currentMedia != null) {
          final isCurrent = currentMedia.id == id ||
              (path != null && currentMedia.extras?['url']?.toString() == path);
          if (isCurrent) {
            final queue = handler.queue.value;
            if (queue.length > 1) {
              await handler.skipToNext();
            } else {
              await handler.stop();
            }
          }
        }
      }
    } catch (e) {
      Logger.root.warning('SongDeleteHelper coordinate with audio handler error: $e');
    }
  }

  static Future<void> _safeScanMedia(String filePath) async {
    try {
      await OfflineAudioQuery.audioQuery.scanMedia(filePath).timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
    } catch (e) {
      Logger.root.warning('scanMedia error: $e');
    }
  }

  /// Delete a single song from local storage or downloads.
  static Future<DeleteOutcome> deleteSingleSong({
    required BuildContext context,
    required String id,
    required String title,
    required String filePath,
    String? imagePath,
    bool fromDownloads = false,
  }) async {
    if (!isPathSafeForDeletion(filePath)) {
      Logger.root.severe('SongDeleteHelper: Rejected unsafe deletion path: $filePath');
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'Deletion rejected: Unsafe file path',
        );
      }
      return DeleteOutcome.failed;
    }
    final file = File(filePath);
    final bool fileExists = await file.exists();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            fileExists
                ? AppLocalizations.of(context)!.delete
                : 'Remove Stale Record',
          ),
          content: Text(
            fileExists
                ? 'Are you sure you want to permanently delete "$title" from your device storage?'
                : 'The file for "$title" was not found on device storage. Remove this stale entry from your library?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                fileExists
                    ? AppLocalizations.of(context)!.delete
                    : 'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return DeleteOutcome.cancelled;
    }

    await coordinateWithAudioHandler(id, filePath);

    if (!fileExists) {
      // Remove stale record from Hive and MediaStore
      if (fromDownloads && Hive.isBoxOpen('downloads')) {
        await Hive.box('downloads').delete(id);
      }
      if (Hive.isBoxOpen('Favorite Songs')) {
        await Hive.box('Favorite Songs').delete(id);
      }
      await _safeScanMedia(filePath);
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'Removed stale entry "$title" from library',
        );
      }
      return DeleteOutcome.staleRecordRemoved;
    }

    // Try deleting physical file
    try {
      await file.delete();
      if (imagePath != null && imagePath.isNotEmpty && isPathSafeForDeletion(imagePath, isArtwork: true)) {
        final img = File(imagePath);
        if (await img.exists()) {
          try {
            await img.delete();
          } catch (_) {}
        }
      }
      if (fromDownloads && Hive.isBoxOpen('downloads')) {
        await Hive.box('downloads').delete(id);
      }
      if (Hive.isBoxOpen('Favorite Songs')) {
        await Hive.box('Favorite Songs').delete(id);
      }
      await _safeScanMedia(filePath);
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'Deleted "$title"',
        );
      }
      return DeleteOutcome.fileDeleted;
    } on FileSystemException catch (e) {
      Logger.root.warning('File delete failed: $e, checking permissions');
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          try {
            await file.delete();
            if (fromDownloads && Hive.isBoxOpen('downloads')) {
              await Hive.box('downloads').delete(id);
            }
            await _safeScanMedia(filePath);
            if (context.mounted) {
              ShowSnackBar().showSnackBar(
                context,
                'Deleted "$title"',
              );
            }
            return DeleteOutcome.fileDeleted;
          } catch (retryErr) {
            Logger.root.severe('Retry delete failed: $retryErr');
          }
        }
      }
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'Could not delete file: Permission denied by system',
        );
      }
      return DeleteOutcome.permissionDenied;
    } catch (e) {
      Logger.root.severe('Delete song error: $e');
      if (context.mounted) {
        ShowSnackBar().showSnackBar(
          context,
          'Failed to delete "$title"',
        );
      }
      return DeleteOutcome.failed;
    }
  }

  /// Bulk delete selected songs with detailed confirmation and outcome breakdown.
  static Future<SongDeleteResult> deleteBulkSongs({
    required BuildContext context,
    required List<Map<String, String>> itemsToDelete, // Each has 'id', 'title', 'path', optional 'image'
    bool fromDownloads = false,
  }) async {
    if (itemsToDelete.isEmpty) {
      return const SongDeleteResult();
    }

    int existingFileCount = 0;
    int missingRecordCount = 0;

    for (final item in itemsToDelete) {
      final p = item['path'] ?? '';
      if (p.isNotEmpty && File(p).existsSync()) {
        existingFileCount++;
      } else {
        missingRecordCount++;
      }
    }

    final String message = missingRecordCount > 0
        ? 'Delete ${itemsToDelete.length} items? ($existingFileCount files will be deleted from storage, and $missingRecordCount stale records will be removed from your library.)'
        : 'Are you sure you want to permanently delete ${itemsToDelete.length} songs from your device storage?';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Text(
            'Delete ${itemsToDelete.length} Songs',
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return const SongDeleteResult();
    }

    int filesDeleted = 0;
    int staleRemoved = 0;
    int failed = 0;
    final List<String> removedIds = [];

    for (final item in itemsToDelete) {
      final String id = item['id'] ?? '';
      final String path = item['path'] ?? '';
      final String? image = item['image'];

      if (!isPathSafeForDeletion(path)) {
        Logger.root.warning('SongDeleteHelper: Skipping unsafe bulk deletion path: $path');
        failed++;
        continue;
      }

      await coordinateWithAudioHandler(id, path);

      final file = File(path);
      if (!file.existsSync()) {
        // Stale record
        if (fromDownloads && Hive.isBoxOpen('downloads')) {
          await Hive.box('downloads').delete(id);
        }
        await _safeScanMedia(path);
        staleRemoved++;
        removedIds.add(id);
        continue;
      }

      // Existing file
      try {
        await file.delete();
        if (image != null && image.isNotEmpty && isPathSafeForDeletion(image, isArtwork: true)) {
          final img = File(image);
          if (img.existsSync()) {
            try {
              await img.delete();
            } catch (_) {}
          }
        }
        if (fromDownloads && Hive.isBoxOpen('downloads')) {
          await Hive.box('downloads').delete(id);
        }
        await _safeScanMedia(path);
        filesDeleted++;
        removedIds.add(id);
      } on FileSystemException {
        if (Platform.isAndroid) {
          final status = await Permission.manageExternalStorage.request();
          if (status.isGranted) {
            try {
              await file.delete();
              if (fromDownloads && Hive.isBoxOpen('downloads')) {
                await Hive.box('downloads').delete(id);
              }
              await _safeScanMedia(path);
              filesDeleted++;
              removedIds.add(id);
              continue;
            } catch (_) {}
          }
        }
        failed++;
      } catch (e) {
        Logger.root.warning('Bulk delete failed for $path: $e');
        failed++;
      }
    }

    if (context.mounted) {
      if (failed == 0) {
        final summary = staleRemoved > 0
            ? 'Deleted $filesDeleted songs and removed $staleRemoved stale records'
            : 'Deleted $filesDeleted songs';
        ShowSnackBar().showSnackBar(context, summary);
      } else {
        ShowSnackBar().showSnackBar(
          context,
          'Deleted $filesDeleted songs. $failed items could not be deleted (permission denied).',
        );
      }
    }

    return SongDeleteResult(
      filesDeleted: filesDeleted,
      staleRecordsRemoved: staleRemoved,
      failed: failed,
      removedIds: removedIds,
    );
  }
}
