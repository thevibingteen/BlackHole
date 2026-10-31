/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';

import 'package:blackhole/Helpers/song_delete_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en', '')],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.lucasjosino.on_audio_query'),
    (MethodCall methodCall) async {
      return true;
    },
  );

  late Directory tempDir;
  late Directory musicDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('delete_test_');
    musicDir = Directory('${tempDir.path}/Music')..createSync(recursive: true);
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('SongDeleteHelper & Persistence Tests', () {
    test('SongDeleteResult initializes with expected defaults', () {
      const res = SongDeleteResult();
      expect(res.filesDeleted, equals(0));
      expect(res.staleRecordsRemoved, equals(0));
      expect(res.failed, equals(0));
      expect(res.removedIds, isEmpty);
    });

    testWidgets('Single song deletion cancellation preserves file and box entry', (WidgetTester tester) async {
      final testAudio = File('${musicDir.path}/song1.mp3')..writeAsStringSync('audio content');
      await tester.runAsync(() async {
        Hive.init(tempDir.path);
        await Hive.openBox('settings');
        await Hive.openBox('downloads');
        await Hive.box('downloads').put('song1', {
          'id': 'song1',
          'title': 'Song 1',
          'path': testAudio.path,
        });
      });

      DeleteOutcome? outcome;
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              savedContext = context;
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<DeleteOutcome>? deleteFuture;
      await tester.runAsync(() async {
        deleteFuture = SongDeleteHelper.deleteSingleSong(
          context: savedContext,
          id: 'song1',
          title: 'Song 1',
          filePath: testAudio.path,
          fromDownloads: true,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.runAsync(() async {
        outcome = await deleteFuture;
      });
      await tester.pumpAndSettle();

      expect(outcome, equals(DeleteOutcome.cancelled));
      expect(testAudio.existsSync(), isTrue);
      expect(Hive.box('downloads').containsKey('song1'), isTrue);

      await tester.runAsync(() async {
        await Hive.close();
      });
    });

    testWidgets('Single song deletion confirmation deletes physical file and Hive entry', (WidgetTester tester) async {
      final testAudio = File('${musicDir.path}/song2.mp3')..writeAsStringSync('audio content 2');
      final testCover = File('${musicDir.path}/song2.jpg')..writeAsStringSync('cover');
      await tester.runAsync(() async {
        Hive.init(tempDir.path);
        await Hive.openBox('settings');
        await Hive.openBox('downloads');
        await Hive.box('downloads').put('song2', {
          'id': 'song2',
          'title': 'Song 2',
          'path': testAudio.path,
          'image': testCover.path,
        });
      });

      DeleteOutcome? outcome;
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              savedContext = context;
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<DeleteOutcome>? deleteFuture;
      await tester.runAsync(() async {
        deleteFuture = SongDeleteHelper.deleteSingleSong(
          context: savedContext,
          id: 'song2',
          title: 'Song 2',
          filePath: testAudio.path,
          imagePath: testCover.path,
          fromDownloads: true,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      final deleteButtons = find.widgetWithText(TextButton, 'Delete');
      expect(deleteButtons, findsOneWidget);
      await tester.tap(deleteButtons);

      await tester.runAsync(() async {
        outcome = await deleteFuture;
      });
      await tester.pumpAndSettle();

      expect(outcome, equals(DeleteOutcome.fileDeleted));
      expect(testAudio.existsSync(), isFalse, reason: 'Physical audio file must be deleted');
      expect(testCover.existsSync(), isFalse, reason: 'Physical cover image must be deleted');
      expect(Hive.box('downloads').containsKey('song2'), isFalse, reason: 'Record must be removed from downloads box');

      await tester.runAsync(() async {
        await Hive.close();
      });
    });

    testWidgets('Stale song record (missing physical file) is safely removed from library', (WidgetTester tester) async {
      final missingPath = '${musicDir.path}/nonexistent_reinstall_song.mp3';
      await tester.runAsync(() async {
        Hive.init(tempDir.path);
        await Hive.openBox('settings');
        await Hive.openBox('downloads');
        await Hive.box('downloads').put('stale_1', {
          'id': 'stale_1',
          'title': 'Stale Song',
          'path': missingPath,
        });
      });

      DeleteOutcome? outcome;
      late BuildContext savedContext;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              savedContext = context;
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<DeleteOutcome>? deleteFuture;
      await tester.runAsync(() async {
        deleteFuture = SongDeleteHelper.deleteSingleSong(
          context: savedContext,
          id: 'stale_1',
          title: 'Stale Song',
          filePath: missingPath,
          fromDownloads: true,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('Remove Stale Record'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.runAsync(() async {
        outcome = await deleteFuture;
      });
      await tester.pumpAndSettle();

      expect(outcome, equals(DeleteOutcome.staleRecordRemoved));
      expect(Hive.box('downloads').containsKey('stale_1'), isFalse);

      await tester.runAsync(() async {
        await Hive.close();
      });
    });

    testWidgets('Bulk delete handles mix of physical files and stale records with breakdown', (WidgetTester tester) async {
      final file1 = File('${musicDir.path}/bulk1.mp3')..writeAsStringSync('data 1');
      final file2 = File('${musicDir.path}/bulk2.mp3')..writeAsStringSync('data 2');
      final stalePath = '${musicDir.path}/bulk_stale.mp3';

      await tester.runAsync(() async {
        Hive.init(tempDir.path);
        await Hive.openBox('settings');
        await Hive.openBox('downloads');
        await Hive.box('downloads').put('b1', {'id': 'b1', 'title': 'Bulk 1', 'path': file1.path});
        await Hive.box('downloads').put('b2', {'id': 'b2', 'title': 'Bulk 2', 'path': file2.path});
        await Hive.box('downloads').put('b3', {'id': 'b3', 'title': 'Bulk 3', 'path': stalePath});
      });

      SongDeleteResult? result;
      late BuildContext savedContext;

      final items = [
        {'id': 'b1', 'title': 'Bulk 1', 'path': file1.path},
        {'id': 'b2', 'title': 'Bulk 2', 'path': file2.path},
        {'id': 'b3', 'title': 'Bulk 3', 'path': stalePath},
      ];

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              savedContext = context;
              return Container();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<SongDeleteResult>? bulkFuture;
      await tester.runAsync(() async {
        bulkFuture = SongDeleteHelper.deleteBulkSongs(
          context: savedContext,
          itemsToDelete: items,
          fromDownloads: true,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.text('Delete 3 Songs'), findsOneWidget);
      expect(find.textContaining('2 files will be deleted from storage, and 1 stale records will be removed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.runAsync(() async {
        result = await bulkFuture;
      });
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.filesDeleted, equals(2));
      expect(result!.staleRecordsRemoved, equals(1));
      expect(result!.failed, equals(0));
      expect(result!.removedIds, containsAll(['b1', 'b2', 'b3']));

      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isFalse);
      expect(Hive.box('downloads').containsKey('b1'), isFalse);
      expect(Hive.box('downloads').containsKey('b2'), isFalse);
      expect(Hive.box('downloads').containsKey('b3'), isFalse);

      await tester.runAsync(() async {
        await Hive.close();
      });
    });
  });
}
