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
import 'dart:typed_data';

import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/Helpers/picker.dart';
import 'package:blackhole/Services/ext_storage_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ZipEntryMetadata {
  final String name;
  final int compressedSize;
  final int uncompressedSize;

  const ZipEntryMetadata({
    required this.name,
    required this.compressedSize,
    required this.uncompressedSize,
  });
}

const int maxBackupEntries = 100;
const int maxCumulativeUncompressedBytes = 100 * 1024 * 1024; // 100 MB
const double maxCompressionRatio = 100.0; // 100:1

void validateBackupArchiveMetadata(
  List<ZipEntryMetadata> entries, {
  String? destinationPath,
}) {
  if (entries.isEmpty) {
    throw const FormatException('Backup archive is empty or invalid');
  }

  if (entries.length > maxBackupEntries) {
    throw SecurityException(
      'Backup archive exceeds entry limit: ${entries.length} entries (maximum allowed: $maxBackupEntries)',
    );
  }

  int totalUncompressed = 0;
  for (final entry in entries) {
    final entryName = entry.name;

    // 1. Path traversal and illegal prefixes
    if (entryName.contains('\x00') ||
        entryName.startsWith('/') ||
        entryName.startsWith('\\') ||
        RegExp('^[a-zA-Z]:').hasMatch(entryName) ||
        entryName.split(RegExp(r'[\\/]')).contains('..')) {
      throw SecurityException(
        'Path traversal or unsafe entry detected in backup archive: $entryName',
      );
    }

    if (destinationPath != null && !isPathWithinRoot(destinationPath, entryName)) {
      throw SecurityException(
        'Path traversal escape detected in backup entry: $entryName',
      );
    }

    // 2. Validate individual entry sizes and prevent integer overflow
    if (entry.uncompressedSize < 0 || entry.compressedSize < 0) {
      throw const FormatException('Negative or malformed entry size in zip archive');
    }

    totalUncompressed += entry.uncompressedSize;
    if (totalUncompressed > maxCumulativeUncompressedBytes) {
      throw SecurityException(
        'Backup archive exceeds cumulative uncompressed size limit of 100 MB ($totalUncompressed bytes)',
      );
    }

    // 3. Decompression bomb ratio check (expansion ratio defense)
    if (entry.compressedSize > 0) {
      final ratio = entry.uncompressedSize / entry.compressedSize;
      if (ratio > maxCompressionRatio) {
        throw SecurityException(
          'Suspicious compression expansion ratio (${ratio.toStringAsFixed(1)}:1) for $entryName exceeds safe limit ($maxCompressionRatio:1)',
        );
      }
    } else if (entry.uncompressedSize > 1024 * 1024) {
      throw SecurityException(
        'Uncompressed payload of ${entry.uncompressedSize} bytes with zero compressed size in $entryName',
      );
    }
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}

/// Safely validates that [candidatePath] resides strictly inside [rootPath]
/// and does not escape via prefix-sharing sibling directories, parent traversal (../),
/// absolute paths, null bytes, or symbolic links pointing outside.
/// Correctly handles both existing and nonexistent targets by resolving parent hierarchies.
bool isPathWithinRoot(String rootPath, String candidatePath) {
  try {
    // 1. Immediate rejection of null bytes
    if (candidatePath.contains('\x00') || rootPath.contains('\x00')) {
      return false;
    }

    // 2. Canonicalize the root directory
    final Directory rootDir = Directory(rootPath);
    final String canonicalRoot = rootDir.existsSync()
        ? rootDir.resolveSymbolicLinksSync()
        : p.canonicalize(rootPath);

    // 3. Resolve candidate relative to root if not absolute
    final String fullCandidate = p.isAbsolute(candidatePath)
        ? candidatePath
        : p.join(canonicalRoot, candidatePath);

    // 4. Lexically canonicalize candidate path (normalizes '..' and '.')
    final String canonicalCandidate = p.canonicalize(fullCandidate);

    // 5. Handle symlinks for existing files and existing ancestor directories
    String resolvedCandidate = canonicalCandidate;
    final candidateFile = File(canonicalCandidate);
    if (candidateFile.existsSync()) {
      resolvedCandidate = candidateFile.resolveSymbolicLinksSync();
    } else {
      // Find deepest existing ancestor directory to resolve parent symlinks
      Directory current = candidateFile.parent;
      final List<String> trailingSegments = [p.basename(canonicalCandidate)];
      while (!current.existsSync() && current.path != current.parent.path) {
        trailingSegments.insert(0, p.basename(current.path));
        current = current.parent;
      }
      if (current.existsSync()) {
        final resolvedParent = current.resolveSymbolicLinksSync();
        resolvedCandidate =
            p.canonicalize(p.joinAll([resolvedParent, ...trailingSegments]));
      }
    }

    // 6. Enforce strict containment: must be strictly inside canonicalRoot
    // and not the root itself or a sibling directory
    return p.isWithin(canonicalRoot, resolvedCandidate);
  } catch (e) {
    Logger.root.warning('Path validation error for $candidatePath', e);
    return false;
  }
}

/// Reads entry metadata (name, compressedSize, uncompressedSize) from a ZIP archive's Central Directory.
Future<List<ZipEntryMetadata>> getZipEntryMetadata(File zipFile) async {
  final raf = await zipFile.open();
  try {
    final length = await raf.length();
    if (length < 22) {
      throw const FormatException('File is too short to be a valid zip archive');
    }

    final searchLength = length > 65557 ? 65557 : length;
    await raf.setPosition(length - searchLength);
    final buffer = await raf.read(searchLength);

    int eocdOffset = -1;
    for (int i = buffer.length - 22; i >= 0; i--) {
      if (buffer[i] == 0x50 &&
          buffer[i + 1] == 0x4b &&
          buffer[i + 2] == 0x05 &&
          buffer[i + 3] == 0x06) {
        eocdOffset = length - searchLength + i;
        break;
      }
    }

    if (eocdOffset == -1) {
      throw const FormatException('Could not find End of Central Directory record in zip');
    }

    await raf.setPosition(eocdOffset);
    final eocdHeader = await raf.read(22);
    final byteData = ByteData.sublistView(eocdHeader);
    final totalEntries = byteData.getUint16(10, Endian.little);
    final cdSize = byteData.getUint32(12, Endian.little);
    final cdOffset = byteData.getUint32(16, Endian.little);

    if (cdOffset + cdSize > length) {
      throw const FormatException('Corrupt zip archive: Central Directory extends beyond file');
    }

    await raf.setPosition(cdOffset);
    final cdData = await raf.read(cdSize);
    final cdByteData = ByteData.sublistView(cdData);

    final List<ZipEntryMetadata> entries = [];
    int offset = 0;
    for (int i = 0; i < totalEntries && offset < cdData.length; i++) {
      if (offset + 46 > cdData.length) break;
      final sig = cdByteData.getUint32(offset, Endian.little);
      if (sig != 0x02014b50) break; // Central directory file header signature

      final compressedSize = cdByteData.getUint32(offset + 20, Endian.little);
      final uncompressedSize = cdByteData.getUint32(offset + 24, Endian.little);
      final nameLength = cdByteData.getUint16(offset + 28, Endian.little);
      final extraLength = cdByteData.getUint16(offset + 30, Endian.little);
      final commentLength = cdByteData.getUint16(offset + 32, Endian.little);

      if (offset + 46 + nameLength > cdData.length) break;
      final nameBytes = cdData.sublist(offset + 46, offset + 46 + nameLength);
      final name = String.fromCharCodes(nameBytes);
      entries.add(
        ZipEntryMetadata(
          name: name,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
        ),
      );

      offset += 46 + nameLength + extraLength + commentLength;
    }

    return entries;
  } finally {
    await raf.close();
  }
}

/// Reads all entry names from a ZIP archive's Central Directory using standard Dart I/O.
Future<List<String>> getZipEntryNames(File zipFile) async {
  final entries = await getZipEntryMetadata(zipFile);
  return entries.map((e) => e.name).toList();
}

Future<void> createBackup(
  BuildContext context,
  List items,
  Map<String, List> boxNameData, {
  String? path,
  String? fileName,
  bool showDialog = true,
}) async {
  if (Platform.isAndroid) {
    await ExtStorageProvider.requestPermission(Permission.storage);
  }
  final String savePath = path ??
      await Picker.selectFolder(
        context: context,
        message: AppLocalizations.of(context)!.selectBackLocation,
      );
  if (savePath.trim() != '') {
    final List<File> files = [];
    try {
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      final List boxNames = [];

      for (int i = 0; i < items.length; i++) {
        boxNames.addAll(boxNameData[items[i]]!);
      }

      for (int i = 0; i < boxNames.length; i++) {
        await Hive.openBox(boxNames[i].toString());
        final Box box = Hive.box(boxNames[i].toString());
        final String? bPath = box.path;
        if (bPath == null) continue;

        try {
          await File(bPath).copy('$savePath/${boxNames[i]}.hive');
        } catch (e) {
          if (Platform.isAndroid) {
            await Permission.manageExternalStorage.request();
          }
          await File(bPath).copy('$savePath/${boxNames[i]}.hive');
        }

        files.add(File('$savePath/${boxNames[i]}.hive'));
      }

      if (files.isEmpty) {
        throw Exception('No valid data found to backup');
      }

      final now = DateTime.now();
      final String time =
          '${now.hour}${now.minute}_${now.day}${now.month}${now.year}';
      final zipFile =
          File('$savePath/${fileName ?? "BlackHole_Backup_$time"}.zip');

      await ZipFile.createFromFiles(
        sourceDir: saveDir,
        files: files,
        zipFile: zipFile,
      );
      if (!await zipFile.exists() || await zipFile.length() == 0) {
        throw Exception('Backup archive was not created or is empty');
      }
      if (showDialog) {
        ShowSnackBar().showSnackBar(
          context,
          AppLocalizations.of(context)!.backupSuccess,
        );
      }
    } catch (e) {
      Logger.root.severe('Error in creating backup', e);
      ShowSnackBar().showSnackBar(
        context,
        '${AppLocalizations.of(context)!.failedCreateBackup}\nError: $e',
      );
    } finally {
      // Ensure intermediate uncompressed .hive files are cleaned up from save directory
      for (int i = 0; i < files.length; i++) {
        try {
          if (await files[i].exists()) {
            await files[i].delete();
          }
        } catch (_) {}
      }
    }
  } else {
    ShowSnackBar().showSnackBar(
      context,
      AppLocalizations.of(context)!.noFolderSelected,
    );
  }
}

Future<void> restore(
  BuildContext context,
) async {
  Logger.root.info('Prompting for restore file selection');
  final String savePath = await Picker.selectFile(
    context: context,
    ext: ['zip'],
    message: AppLocalizations.of(context)!.selectBackFile,
  );
  Logger.root.info('Selected restore file path: $savePath');
  if (savePath != '') {
    final File zipFile = File(savePath);
    if (!savePath.toLowerCase().endsWith('.zip')) {
      ShowSnackBar().showSnackBar(
        context,
        '${AppLocalizations.of(context)!.failedImport}\nError: Invalid file format (expected .zip archive)',
      );
      return;
    }
    if (!await zipFile.exists() || await zipFile.length() == 0) {
      ShowSnackBar().showSnackBar(
        context,
        '${AppLocalizations.of(context)!.failedImport}\nError: Selected backup file does not exist or is empty',
      );
      return;
    }
    final Directory tempDir = await getTemporaryDirectory();
    final Directory destinationDir = Directory(
      '${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}',
    );

    try {
      if (await destinationDir.exists()) {
        await destinationDir.delete(recursive: true);
      }
      await destinationDir.create(recursive: true);

      // Pre-extraction validation: inspect Central Directory metadata, enforce entry limits,
      // cumulative uncompressed size limits (100 MB), compression ratio (100:1), and path boundaries
      // before the extractor ever touches disk.
      final List<ZipEntryMetadata> entries = await getZipEntryMetadata(zipFile);
      validateBackupArchiveMetadata(
        entries,
        destinationPath: destinationDir.path,
      );

      Logger.root.info(
        'Extracting ${entries.length} backup entries with real-time boundary and quota enforcement',
      );

      int cumulativeWrittenBytes = 0;
      await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: destinationDir,
        onExtracting: (zipEntry, progress) {
          final entryName = zipEntry.name;
          if (entryName.contains('\x00') ||
              entryName.startsWith('/') ||
              entryName.startsWith('\\') ||
              RegExp('^[a-zA-Z]:').hasMatch(entryName) ||
              entryName.split(RegExp(r'[\\/]')).contains('..') ||
              !isPathWithinRoot(destinationDir.path, entryName)) {
            Logger.root.severe(
              'Blocked unsafe archive entry before write: $entryName',
            );
            return ZipFileOperation.cancel;
          }

          // Real-time extraction quota enforcement against uncompressed payload overflow
          cumulativeWrittenBytes += zipEntry.uncompressedSize ?? 0;
          if (cumulativeWrittenBytes > maxCumulativeUncompressedBytes) {
            Logger.root.severe(
              'Aborting extraction: Cumulative bytes extracted ($cumulativeWrittenBytes) exceeded limit ($maxCumulativeUncompressedBytes)',
            );
            return ZipFileOperation.cancel;
          }

          return ZipFileOperation.includeItem;
        },
      );

      if (cumulativeWrittenBytes > maxCumulativeUncompressedBytes) {
        throw const SecurityException(
          'Backup archive extraction aborted: Payload exceeded 100 MB quota',
        );
      }
      final List<FileSystemEntity> extractedEntities =
          await destinationDir.list(recursive: true).toList();
      final List<File> hiveFiles = [];

      for (final entity in extractedEntities) {
        if (entity is File && entity.path.endsWith('.hive')) {
          // Post-extraction defense-in-depth: confirm file resides strictly within destinationDir
          if (!isPathWithinRoot(destinationDir.path, entity.path)) {
            Logger.root.warning(
              'Path traversal attempt detected in backup entry: ${entity.path}',
            );
            continue;
          }
          hiveFiles.add(entity);
        }
      }

      if (hiveFiles.isEmpty) {
        throw Exception(
          'Backup archive contains no valid BlackHole data files (.hive)',
        );
      }

      Logger.root.info('Found ${hiveFiles.length} valid backup data files');

      // Best-effort transactional restore with snapshot-based rollback on failure
      final Directory rollbackDir = Directory(
        '${tempDir.path}/rollback_${DateTime.now().millisecondsSinceEpoch}',
      );
      await rollbackDir.create(recursive: true);
      final List<Map<String, String>> rollbackList = [];

      try {
        for (int i = 0; i < hiveFiles.length; i++) {
          final String backupPath = hiveFiles[i].path;
          final String rawFileName = backupPath.split(RegExp(r'[\\/]')).last;
          final String boxName = rawFileName
              .replaceAll('.hive', '')
              .replaceAll(RegExp(r'[\.\\\*\:\"\?#/;\|]'), '')
              .trim();
          if (boxName.isEmpty) continue;

          // Safe sequence for open Hive boxes:
          // Close and flush any currently open box before touching disk files
          // to prevent in-memory cache and on-disk divergence or corruption.
          String? boxPath;
          if (Hive.isBoxOpen(boxName)) {
            final Box existingBox = Hive.box(boxName);
            boxPath = existingBox.path;
            await existingBox.compact();
            await existingBox.close();
          } else {
            final Box tempBox = await Hive.openBox(boxName);
            boxPath = tempBox.path;
            await tempBox.close();
          }

          if (boxPath == null) continue;

          // Snapshot current box file for rollback if it exists
          final File currentBoxFile = File(boxPath);
          if (await currentBoxFile.exists()) {
            final String snapshotPath = '${rollbackDir.path}/$boxName.hive';
            await currentBoxFile.copy(snapshotPath);
            rollbackList.add({
              'boxName': boxName,
              'boxPath': boxPath,
              'snapshotPath': snapshotPath,
            });
          }

          // Replace database file with validated backup copy
          await File(backupPath).copy(boxPath);

          // Reopen box so app state is immediately consistent with restored data
          await Hive.openBox(boxName);
        }
      } catch (boxError) {
        Logger.root.severe(
          'Error restoring boxes, executing rollback: $boxError',
          boxError,
        );
        // Rollback any replaced boxes to their previous snapshot state
        for (final entry in rollbackList) {
          try {
            final String name = entry['boxName']!;
            final String path = entry['boxPath']!;
            final String snap = entry['snapshotPath']!;

            if (Hive.isBoxOpen(name)) {
              await Hive.box(name).close();
            }
            if (await File(snap).exists()) {
              await File(snap).copy(path);
            }
            await Hive.openBox(name);
          } catch (rbError) {
            Logger.root.severe(
              'Error rolling back box ${entry['boxName']}: $rbError',
              rbError,
            );
          }
        }
        rethrow;
      } finally {
        if (await rollbackDir.exists()) {
          try {
            await rollbackDir.delete(recursive: true);
          } catch (_) {}
        }
      }

      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.importSuccess,
      );
    } catch (e) {
      Logger.root.severe('Error in restoring backup', e);
      ShowSnackBar().showSnackBar(
        context,
        '${AppLocalizations.of(context)!.failedImport}\nError: $e',
      );
    } finally {
      if (await destinationDir.exists()) {
        try {
          await destinationDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  } else {
    Logger.root.severe('Error in restoring backup', 'No file selected');
    ShowSnackBar().showSnackBar(
      context,
      AppLocalizations.of(context)!.noFileSelected,
    );
  }
}
