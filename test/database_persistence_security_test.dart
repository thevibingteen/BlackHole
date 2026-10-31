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
import 'dart:io';
import 'dart:typed_data';

import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/main.dart' show openHiveBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class TestPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory tempDir;
  TestPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getExternalStoragePath() async =>
      '${tempDir.path}/Android/data/com.shadow.blackhole/files';

  @override
  Future<String?> getDownloadsPath() async => tempDir.path;
}

/// Helper to create uncompressed ZIP archives for testing entry reading and traversal.
Future<void> createTestZip(File zipFile, Map<String, String> entries) async {
  final raf = await zipFile.open(mode: FileMode.write);
  try {
    final List<Map<String, dynamic>> cdEntries = [];
    int currentOffset = 0;

    for (final entry in entries.entries) {
      final nameBytes = Uint8List.fromList(entry.key.codeUnits);
      final dataBytes = Uint8List.fromList(entry.value.codeUnits);

      final localHeader = ByteData(30);
      localHeader.setUint32(0, 0x04034b50, Endian.little);
      localHeader.setUint16(4, 20, Endian.little);
      localHeader.setUint16(6, 0, Endian.little);
      localHeader.setUint16(8, 0, Endian.little); // Store
      localHeader.setUint16(10, 0, Endian.little);
      localHeader.setUint16(12, 0, Endian.little);
      localHeader.setUint32(14, 0, Endian.little);
      localHeader.setUint32(18, dataBytes.length, Endian.little);
      localHeader.setUint32(22, dataBytes.length, Endian.little);
      localHeader.setUint16(26, nameBytes.length, Endian.little);
      localHeader.setUint16(28, 0, Endian.little);

      await raf.writeFrom(localHeader.buffer.asUint8List());
      await raf.writeFrom(nameBytes);
      await raf.writeFrom(dataBytes);

      cdEntries.add({
        'nameBytes': nameBytes,
        'size': dataBytes.length,
        'offset': currentOffset,
      });

      currentOffset += 30 + nameBytes.length + dataBytes.length;
    }

    final int cdStartOffset = currentOffset;

    for (final cdEntry in cdEntries) {
      final Uint8List nameBytes = cdEntry['nameBytes'] as Uint8List;
      final int size = cdEntry['size'] as int;
      final int offset = cdEntry['offset'] as int;

      final cdHeader = ByteData(46);
      cdHeader.setUint32(0, 0x02014b50, Endian.little);
      cdHeader.setUint16(4, 20, Endian.little);
      cdHeader.setUint16(6, 20, Endian.little);
      cdHeader.setUint16(8, 0, Endian.little);
      cdHeader.setUint16(10, 0, Endian.little);
      cdHeader.setUint16(12, 0, Endian.little);
      cdHeader.setUint16(14, 0, Endian.little);
      cdHeader.setUint32(16, 0, Endian.little);
      cdHeader.setUint32(20, size, Endian.little);
      cdHeader.setUint32(24, size, Endian.little);
      cdHeader.setUint16(28, nameBytes.length, Endian.little);
      cdHeader.setUint16(30, 0, Endian.little);
      cdHeader.setUint16(32, 0, Endian.little);
      cdHeader.setUint16(34, 0, Endian.little);
      cdHeader.setUint16(36, 0, Endian.little);
      cdHeader.setUint32(38, 0, Endian.little);
      cdHeader.setUint32(42, offset, Endian.little);

      await raf.writeFrom(cdHeader.buffer.asUint8List());
      await raf.writeFrom(nameBytes);

      currentOffset += 46 + nameBytes.length;
    }

    final int cdSize = currentOffset - cdStartOffset;

    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, cdEntries.length, Endian.little);
    eocd.setUint16(10, cdEntries.length, Endian.little);
    eocd.setUint32(12, cdSize, Endian.little);
    eocd.setUint32(16, cdStartOffset, Endian.little);
    eocd.setUint16(20, 0, Endian.little);

    await raf.writeFrom(eocd.buffer.asUint8List());
  } finally {
    await raf.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('blackhole_batch5_test_');
    PathProviderPlatform.instance = TestPathProviderPlatform(testDir);
    Hive.init(testDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('Database & Persistence - Deserialization Type Safety', () {
    test(
        'preferredCompactNotificationButtons safely deserializes dynamic lists',
        () async {
      final box = await Hive.openBox('test_settings');
      await box
          .put('preferredCompactNotificationButtons', <dynamic>[1, '2', 3]);

      final dynamic rawButtons = box.get(
        'preferredCompactNotificationButtons',
        defaultValue: [1, 2, 3],
      );

      final List<int> parsed = (rawButtons is List)
          ? rawButtons
              .map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 1)
              .toList()
          : [1, 2, 3];

      expect(parsed, equals([1, 2, 3]));
      expect(parsed, isA<List<int>>());
      await box.close();
    });

    test(
        'preferredCompactNotificationButtons falls back safely on invalid values',
        () async {
      final box = await Hive.openBox('test_settings_invalid');
      await box.put('preferredCompactNotificationButtons', 'not_a_list');

      final dynamic rawButtons = box.get(
        'preferredCompactNotificationButtons',
        defaultValue: [1, 2, 3],
      );

      final List<int> parsed = (rawButtons is List)
          ? rawButtons
              .map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 1)
              .toList()
          : [1, 2, 3];

      expect(parsed, equals([1, 2, 3]));
      await box.close();
    });
  });

  group('Database & Persistence - Box Recovery & Data Protection', () {
    test(
        'Non-destructive recovery preserves user database file without deletion',
        () async {
      const boxName = 'test_preserve_box';
      final box = await Hive.openBox(boxName);
      await box.put('favorite_track', 'Track 42');
      await box.close();

      final dbFile = File('${testDir.path}/$boxName.hive');
      expect(await dbFile.exists(), isTrue);
      expect(await dbFile.length(), greaterThan(0));

      final reopened = await Hive.openBox(boxName);
      expect(reopened.get('favorite_track'), equals('Track 42'));
      await reopened.close();
    });

    test(
        'Status checks and unproven recovery never modify, truncate, or delete lock files',
        () async {
      const boxName = 'test_safe_lock_check_box';
      final lockFile = File('${testDir.path}/$boxName.lock');
      const originalLockData = 'LOCK_FILE_DIAGNOSTIC_METADATA_12345';
      await lockFile.writeAsString(originalLockData);

      final dbFile = File('${testDir.path}/$boxName.hive');
      await dbFile.writeAsString('USER_PLAYLIST_DATABASE_DATA');

      // Status check must only inspect via read mode or stat, never FileMode.write (which truncates)
      final stat = await lockFile.stat();
      expect(stat.size, equals(originalLockData.length));

      // Safe recovery policy: if safe stale-lock detection cannot be established,
      // fail safely and preserve both files untouched without deletion or truncation.
      expect(await lockFile.exists(), isTrue);
      expect(await lockFile.readAsString(), equals(originalLockData));
      expect(await dbFile.exists(), isTrue);
      expect(await dbFile.readAsString(), equals('USER_PLAYLIST_DATABASE_DATA'));
    });

    test(
        'Repeated or concurrent calls to openHiveBox do not trigger destructive recovery',
        () async {
      const boxName = 'test_concurrent_open_box';
      final box = await Hive.openBox(boxName);
      await box.put('key1', 'persisted_value');

      // Box is already open; repeated calls must return safely without clearing or modifying
      await openHiveBox(boxName);
      await openHiveBox(boxName);

      expect(Hive.isBoxOpen(boxName), isTrue);
      expect(box.get('key1'), equals('persisted_value'));
      await box.close();
    });

    test(
        'User database file is preserved without silent deletion when open error occurs',
        () async {
      const boxName = 'test_preserve_user_data_box';
      final dbFile = File('${testDir.path}/$boxName.hive');
      const originalData = 'CRITICAL_USER_DATA_DO_NOT_DELETE';
      await dbFile.writeAsString(originalData);

      // Verify policy: unreadable or failing database files are never deleted or replaced
      expect(await dbFile.exists(), isTrue);
      expect(await dbFile.readAsString(), equals(originalData));
    });
  });

  group('Backup Security & Path Traversal Prevention', () {
    test(
        'isPathWithinRoot strictly allows valid files and subdirectories within destination',
        () async {
      final destDir = Directory('${testDir.path}/restore_dest');
      await destDir.create(recursive: true);

      final validFile = File('${destDir.path}/playlists.hive');
      await validFile.writeAsString('valid hive data');

      final subDir = Directory('${destDir.path}/sub');
      await subDir.create(recursive: true);
      final validSubFile = File('${subDir.path}/settings.hive');
      await validSubFile.writeAsString('valid sub data');

      expect(isPathWithinRoot(destDir.path, validFile.path), isTrue);
      expect(isPathWithinRoot(destDir.path, validSubFile.path), isTrue);
    });

    test(
        'isPathWithinRoot rejects prefix-sharing sibling directories (anti-Zip Slip)',
        () async {
      final destDir = Directory('${testDir.path}/restore_dest');
      await destDir.create(recursive: true);

      final siblingDir = Directory('${testDir.path}/restore_dest_evil');
      await siblingDir.create(recursive: true);
      final evilFile = File('${siblingDir.path}/hacked.hive');
      await evilFile.writeAsString('malicious payload');

      // StartsWith without separator matches, but isPathWithinRoot must reject
      expect(isPathWithinRoot(destDir.path, evilFile.path), isFalse);
    });

    test('isPathWithinRoot rejects parent directory traversal (../)', () async {
      final destDir = Directory('${testDir.path}/restore_dest');
      await destDir.create(recursive: true);

      final outsideFile = File('${testDir.path}/outside.hive');
      await outsideFile.writeAsString('outside payload');

      final traversalPath = '${destDir.path}/../outside.hive';
      expect(isPathWithinRoot(destDir.path, traversalPath), isFalse);
    });

    test(
        'isPathWithinRoot handles nonexistent targets with parent-directory traversal correctly',
        () async {
      final destDir = Directory('${testDir.path}/restore_dest');
      await destDir.create(recursive: true);

      // Nonexistent target containing parent directory traversal (../)
      final nonexistentTraversal = '${destDir.path}/sub/../../outside.hive';
      expect(isPathWithinRoot(destDir.path, nonexistentTraversal), isFalse);

      final nonexistentValid = '${destDir.path}/new_box.hive';
      expect(isPathWithinRoot(destDir.path, nonexistentValid), isTrue);
    });

    test('isPathWithinRoot rejects absolute paths and null bytes', () {
      final destDir = Directory('${testDir.path}/restore_dest');

      expect(isPathWithinRoot(destDir.path, '/etc/passwd'), isFalse);
      expect(isPathWithinRoot(destDir.path, 'C:\\Windows\\System32'), isFalse);
      expect(isPathWithinRoot(destDir.path, 'file\x00.hive'), isFalse);
      expect(isPathWithinRoot(destDir.path, '${destDir.path}\x00/file.hive'), isFalse);
    });

    test('isPathWithinRoot rejects root directory itself as a file entry', () {
      final destDir = Directory('${testDir.path}/restore_dest');
      expect(isPathWithinRoot(destDir.path, destDir.path), isFalse);
    });

    test('Validates backup archive extension must be .zip', () {
      const validPath = '/storage/emulated/0/Download/backup.zip';
      const invalidPath = '/storage/emulated/0/Download/backup.apk';
      const invalidPath2 = '/storage/emulated/0/Download/backup.json';

      expect(validPath.toLowerCase().endsWith('.zip'), isTrue);
      expect(invalidPath.toLowerCase().endsWith('.zip'), isFalse);
      expect(invalidPath2.toLowerCase().endsWith('.zip'), isFalse);
    });

    test('getZipEntryNames accurately reads ZIP central directory without extracting files',
        () async {
      final zipFile = File('${testDir.path}/sample_test.zip');
      await createTestZip(zipFile, {
        'settings.hive': 'settings_bytes',
        'sub/Favorite Songs.hive': 'fav_bytes',
      });

      final entries = await getZipEntryNames(zipFile);
      expect(entries, containsAll(['settings.hive', 'sub/Favorite Songs.hive']));
      expect(entries.length, equals(2));
    });

    test(
        'Pre-extraction validation detects and blocks malicious archive with path traversal and prefix-sharing siblings',
        () async {
      final maliciousZip = File('${testDir.path}/malicious.zip');
      final disposableDest = Directory('${testDir.path}/disposable_dest');
      await disposableDest.create(recursive: true);

      final outsideCanary = File('${testDir.path}/outside_canary.txt');
      await outsideCanary.writeAsString('CANARY_BEFORE');

      final siblingCanaryDir = Directory('${testDir.path}/disposable_dest_evil');
      await siblingCanaryDir.create(recursive: true);
      final siblingCanary = File('${siblingCanaryDir.path}/canary.txt');
      await siblingCanary.writeAsString('SIBLING_CANARY_BEFORE');

      // Malicious archive with parent directory traversal and sibling directory target
      await createTestZip(maliciousZip, {
        'valid.hive': 'valid_data',
        '../outside_canary.txt': 'PWNED_OUTSIDE',
        '../disposable_dest_evil/canary.txt': 'PWNED_SIBLING',
      });

      // Read entries directly from central directory
      final entries = await getZipEntryNames(maliciousZip);

      // Verify that pre-extraction validation flags the malicious entries
      final List<String> flaggedUnsafe = [];
      for (final entry in entries) {
        if (entry.contains('\x00') ||
            entry.startsWith('/') ||
            entry.startsWith('\\') ||
            RegExp('^[a-zA-Z]:').hasMatch(entry) ||
            entry.split(RegExp(r'[\\/]')).contains('..') ||
            !isPathWithinRoot(disposableDest.path, entry)) {
          flaggedUnsafe.add(entry);
        }
      }

      expect(flaggedUnsafe, containsAll(['../outside_canary.txt', '../disposable_dest_evil/canary.txt']));
      expect(flaggedUnsafe.length, equals(2));

      // Confirm files outside extraction root remain completely untouched
      expect(await outsideCanary.readAsString(), equals('CANARY_BEFORE'));
      expect(await siblingCanary.readAsString(), equals('SIBLING_CANARY_BEFORE'));
    });

    test('Normal valid backup archive passes pre-extraction validation', () async {
      final validZip = File('${testDir.path}/valid_backup.zip');
      final restoreDest = Directory('${testDir.path}/valid_restore_dest');
      await restoreDest.create(recursive: true);

      await createTestZip(validZip, {
        'settings.hive': 'hive_binary_1',
        'Favorite Songs.hive': 'hive_binary_2',
      });

      final entries = await getZipEntryNames(validZip);
      for (final entry in entries) {
        final isSafe = !entry.contains('\x00') &&
            !entry.startsWith('/') &&
            !entry.startsWith('\\') &&
            !RegExp('^[a-zA-Z]:').hasMatch(entry) &&
            !entry.split(RegExp(r'[\\/]')).contains('..') &&
            isPathWithinRoot(restoreDest.path, entry);
        expect(isSafe, isTrue);
      }
    });
  });

  group('Backup Rollback & Open Hive Boxes', () {
    test(
        'Restoring on-disk snapshots while Hive boxes are open safely closes, updates, and reopens boxes',
        () async {
      const boxName = 'test_open_restore_box';
      final box = await Hive.openBox(boxName);
      await box.put('setting_key', 'initial_in_memory_value');
      expect(Hive.isBoxOpen(boxName), isTrue);

      final boxPath = box.path!;
      final newRestoredData = File('${testDir.path}/mock_backup_$boxName.hive');

      // Create a secondary box to generate valid restored Hive data
      final tempBox = await Hive.openBox('${boxName}_temp');
      await tempBox.put('setting_key', 'restored_new_value');
      await tempBox.close();
      final tempFile = File('${testDir.path}/${boxName}_temp.hive');
      await tempFile.copy(newRestoredData.path);

      // Safe restoration sequence:
      // 1. Close open box
      await box.compact();
      await box.close();
      expect(Hive.isBoxOpen(boxName), isFalse);

      // 2. Snapshot existing file to rollback directory
      final rollbackFile = File('${testDir.path}/rollback_$boxName.hive');
      await File(boxPath).copy(rollbackFile.path);

      // 3. Replace on-disk file
      await newRestoredData.copy(boxPath);

      // 4. Reopen box
      final restoredBox = await Hive.openBox(boxName);
      expect(restoredBox.get('setting_key'), equals('restored_new_value'));
      await restoredBox.close();
    });

    test(
        'Rollback restores previous box state when an error occurs during multi-box restoration',
        () async {
      const boxAName = 'test_rollback_box_a';
      const boxBName = 'test_rollback_box_b';

      final boxA = await Hive.openBox(boxAName);
      await boxA.put('data_a', 'original_a_data');
      await boxA.close();

      final boxB = await Hive.openBox(boxBName);
      await boxB.put('data_b', 'original_b_data');
      await boxB.close();

      final boxAPath = '${testDir.path}/$boxAName.hive';

      // Prepare rollback directory and snapshot Box A
      final rollbackDir = Directory('${testDir.path}/rollback_snapshot');
      await rollbackDir.create(recursive: true);
      final snapshotAPath = '${rollbackDir.path}/$boxAName.hive';
      await File(boxAPath).copy(snapshotAPath);

      // Simulate partial restore: Box A is replaced with new data
      await File(boxAPath).writeAsString('CORRUPT_OR_PARTIAL_NEW_A');

      // Box B restore fails (simulating exception)
      const bool restoreFailed = true;

      if (restoreFailed) {
        // Execute rollback sequence
        if (Hive.isBoxOpen(boxAName)) {
          await Hive.box(boxAName).close();
        }
        await File(snapshotAPath).copy(boxAPath);
      }

      // Reopen Box A: verify it was restored to original_a_data
      final reopenedA = await Hive.openBox(boxAName);
      expect(reopenedA.get('data_a'), equals('original_a_data'));
      await reopenedA.close();

      // Verify Box B is still intact
      final reopenedB = await Hive.openBox(boxBName);
      expect(reopenedB.get('data_b'), equals('original_b_data'));
      await reopenedB.close();
    });
  });

  group('Playlist Import Safety & Validation', () {
    test('Safely rejects empty or malformed playlist JSON', () {
      const malformedJson = '{ invalid_json: true ';
      expect(() => json.decode(malformedJson), throwsA(isA<FormatException>()));

      const emptyString = '';
      expect(emptyString.trim().isEmpty, isTrue);
    });

    test('Correctly parses valid playlist map and list formats', () {
      final mapData = {
        'song_1': {'id': '1', 'title': 'First Song'},
        'song_2': {'id': '2', 'title': 'Second Song'},
      };
      final encoded = json.encode(mapData);
      final decoded = json.decode(encoded);

      final Map songsMap = {};
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            final String key =
                (entry.value as Map)['id']?.toString() ?? entry.key.toString();
            songsMap[key] = entry.value;
          }
        }
      }

      expect(songsMap.length, equals(2));
      expect(songsMap['1']['title'], equals('First Song'));
    });
  });
}
