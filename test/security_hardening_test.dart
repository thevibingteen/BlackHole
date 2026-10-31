/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:blackhole/Helpers/app_links.dart';
import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/Helpers/route_handler.dart';
import 'package:blackhole/Helpers/song_delete_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase F1: Storage Safety & Deletion Path Validation Tests', () {
    test('isPathSafeForDeletion accepts legitimate audio file paths', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/song.mp3'),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Download/track.flac'),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('D:/Music/awesome_track.m4a'),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('C:/Users/Music/audio.opus'),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/sdcard/Music/recording.wav'),
        isTrue,
      );
    });

    test('isPathSafeForDeletion accepts legitimate artwork file paths', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion(
          '/storage/emulated/0/Music/cover.jpg',
          isArtwork: true,
        ),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion(
          'D:/Music/artwork.png',
          isArtwork: true,
        ),
        isTrue,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion(
          '/storage/emulated/0/Download/art.webp',
          isArtwork: true,
        ),
        isTrue,
      );
    });

    test('isPathSafeForDeletion rejects null, empty, or whitespace paths', () {
      expect(SongDeleteHelper.isPathSafeForDeletion(null), isFalse);
      expect(SongDeleteHelper.isPathSafeForDeletion(''), isFalse);
      expect(SongDeleteHelper.isPathSafeForDeletion('   '), isFalse);
    });

    test('isPathSafeForDeletion rejects null bytes in paths', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/song.mp3\x00.exe'),
        isFalse,
      );
    });

    test('isPathSafeForDeletion rejects directory traversal sequences', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/../../etc/passwd.mp3'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('../song.mp3'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('foo/bar/../../../system/song.flac'),
        isFalse,
      );
    });

    test('isPathSafeForDeletion rejects non-audio file extensions', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/malicious.exe'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/script.sh'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/database.hive'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/code.dart'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/storage/emulated/0/Music/app.apk'),
        isFalse,
      );
    });

    test('isPathSafeForDeletion rejects critical system and OS root paths', () {
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/system/bin/song.mp3'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('/etc/song.mp3'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('C:/Windows/System32/song.mp3'),
        isFalse,
      );
      expect(
        SongDeleteHelper.isPathSafeForDeletion('C:/Program Files/song.mp3'),
        isFalse,
      );
    });
  });

  group('Phase F1: ZIP Archive & Backup Resource Exhaustion Tests', () {
    test('validateBackupArchiveMetadata accepts valid legitimate backup metadata', () {
      final validEntries = [
        const ZipEntryMetadata(
          name: 'settings.hive',
          compressedSize: 1024,
          uncompressedSize: 2048,
        ),
        const ZipEntryMetadata(
          name: 'Favorite Songs.hive',
          compressedSize: 512,
          uncompressedSize: 1024,
        ),
      ];

      expect(
        () => validateBackupArchiveMetadata(validEntries),
        returnsNormally,
      );
    });

    test('validateBackupArchiveMetadata rejects empty archive entries list', () {
      expect(
        () => validateBackupArchiveMetadata([]),
        throwsA(isA<FormatException>()),
      );
    });

    test('validateBackupArchiveMetadata rejects excessive entry count (>100)', () {
      final excessiveEntries = List.generate(
        101,
        (i) => ZipEntryMetadata(
          name: 'entry_$i.hive',
          compressedSize: 10,
          uncompressedSize: 20,
        ),
      );

      expect(
        () => validateBackupArchiveMetadata(excessiveEntries),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('exceeds entry limit'),
          ),
        ),
      );
    });

    test('validateBackupArchiveMetadata rejects cumulative uncompressed payload > 100 MB', () {
      final oversizedEntries = [
        const ZipEntryMetadata(
          name: 'huge_box.hive',
          compressedSize: 20 * 1024 * 1024, // 20 MB compressed
          uncompressedSize: 105 * 1024 * 1024, // 105 MB uncompressed (> 100 MB)
        ),
      ];

      expect(
        () => validateBackupArchiveMetadata(oversizedEntries),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('exceeds cumulative uncompressed size limit'),
          ),
        ),
      );
    });

    test('validateBackupArchiveMetadata rejects decompression bomb (>100:1 ratio)', () {
      final zipBombEntries = [
        const ZipEntryMetadata(
          name: 'bomb.hive',
          compressedSize: 100, // 100 bytes
          uncompressedSize: 100 * 1000 * 10, // 1 MB (10,000:1 ratio)
        ),
      ];

      expect(
        () => validateBackupArchiveMetadata(zipBombEntries),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Suspicious compression expansion ratio'),
          ),
        ),
      );
    });

    test('validateBackupArchiveMetadata rejects path traversal entries', () {
      final traversalEntries = [
        const ZipEntryMetadata(
          name: '../../escape.hive',
          compressedSize: 100,
          uncompressedSize: 200,
        ),
      ];

      expect(
        () => validateBackupArchiveMetadata(traversalEntries),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('Path traversal or unsafe entry detected'),
          ),
        ),
      );
    });
  });

  group('Phase F2: Deep Links & Exact Host Validation Tests', () {
    test('isYouTubeHost accepts legitimate YouTube domains', () {
      expect(HandleRoute.isYouTubeHost('youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('www.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('m.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('music.youtube.com'), isTrue);
      expect(HandleRoute.isYouTubeHost('youtu.be'), isTrue);
    });

    test('isYouTubeHost rejects deceptive attacker domains', () {
      expect(HandleRoute.isYouTubeHost('attacker-youtube.com'), isFalse);
      expect(HandleRoute.isYouTubeHost('notyoutube.com'), isFalse);
      expect(HandleRoute.isYouTubeHost('youtube.com.attacker.example'), isFalse);
      expect(HandleRoute.isYouTubeHost('attacker.example'), isFalse);
    });

    test('isJioSaavnHost accepts legitimate Saavn domains', () {
      expect(HandleRoute.isJioSaavnHost('jiosaavn.com'), isTrue);
      expect(HandleRoute.isJioSaavnHost('www.jiosaavn.com'), isTrue);
      expect(HandleRoute.isJioSaavnHost('saavn.com'), isTrue);
    });

    test('isJioSaavnHost rejects deceptive Saavn domains', () {
      expect(HandleRoute.isJioSaavnHost('attacker-jiosaavn.com'), isFalse);
      expect(HandleRoute.isJioSaavnHost('fake-saavn.com'), isFalse);
      expect(HandleRoute.isJioSaavnHost('jiosaavn.com.attacker.example'), isFalse);
    });

    test('isSpotifyHost accepts legitimate Spotify domains', () {
      expect(HandleRoute.isSpotifyHost('spotify.com'), isTrue);
      expect(HandleRoute.isSpotifyHost('open.spotify.com'), isTrue);
    });

    test('isSpotifyHost rejects deceptive Spotify domains', () {
      expect(HandleRoute.isSpotifyHost('attacker-spotify.com'), isFalse);
      expect(HandleRoute.isSpotifyHost('notspotify.com'), isFalse);
      expect(HandleRoute.isSpotifyHost('spotify.com.attacker.example'), isFalse);
    });

    test('parseYouTubeUrl parses valid video link and rejects deceptive domains', () {
      final valid = HandleRoute.parseYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(valid, isNotNull);
      expect(valid!.id, equals('dQw4w9WgXcQ'));
      expect(valid.type, equals('v'));

      final validShort = HandleRoute.parseYouTubeUrl('https://youtu.be/dQw4w9WgXcQ');
      expect(validShort, isNotNull);
      expect(validShort!.id, equals('dQw4w9WgXcQ'));

      final deceptive = HandleRoute.parseYouTubeUrl('https://attacker-youtube.com/watch?v=dQw4w9WgXcQ');
      expect(deceptive, isNull);

      final redirectTrick = HandleRoute.parseYouTubeUrl('https://attacker.example/?redirect=youtube.com&v=dQw4w9WgXcQ');
      expect(redirectTrick, isNull);
    });
  });

  group('Phase F2: External URI Scheme Validation Tests (AppLinks)', () {
    test('AppLinks.isSchemeAllowed allows https, http, and mailto', () {
      expect(AppLinks.isSchemeAllowed('https://example.com'), isTrue);
      expect(AppLinks.isSchemeAllowed('http://radio.stream.com:8000/live'), isTrue);
      expect(AppLinks.isSchemeAllowed('mailto:support@blackhole.org'), isTrue);
    });

    test('AppLinks.isSchemeAllowed rejects dangerous or arbitrary schemes', () {
      expect(AppLinks.isSchemeAllowed('javascript:alert(1)'), isFalse);
      expect(AppLinks.isSchemeAllowed('file:///etc/passwd'), isFalse);
      expect(AppLinks.isSchemeAllowed('content://media/external/audio'), isFalse);
      expect(AppLinks.isSchemeAllowed('data:text/html,<h1>PWNED</h1>'), isFalse);
      expect(AppLinks.isSchemeAllowed('intent://scan/#Intent;scheme=zxing;end'), isFalse);
      expect(AppLinks.isSchemeAllowed('market://details?id=com.shadow.blackhole'), isFalse);
      expect(AppLinks.isSchemeAllowed(''), isFalse);
      expect(AppLinks.isSchemeAllowed(null), isFalse);
    });
  });
}

