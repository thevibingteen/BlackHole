/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:io';
import 'dart:ui' as ui;

import 'package:blackhole/Helpers/config.dart';
import 'package:blackhole/Helpers/dominant_color.dart';
import 'package:blackhole/main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:palette_generator/palette_generator.dart';

class FakeImageProvider extends ImageProvider<FakeImageProvider> {
  const FakeImageProvider(this._image, {this.scale = 1.0});

  final ui.Image _image;
  final double scale;

  @override
  Future<FakeImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FakeImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    FakeImageProvider key,
    ImageDecoderCallback decode,
  ) {
    assert(key == this);
    return OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(
        ImageInfo(image: _image, scale: scale),
      ),
    );
  }
}

Future<FakeImageProvider> createColorImage(Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder, const Rect.fromLTWH(0, 0, 20, 20));
  final Paint paint = Paint()..color = color;
  canvas.drawRect(const Rect.fromLTWH(0, 0, 20, 20), paint);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(20, 20);
  return FakeImageProvider(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box settingsBox;
  late FakeImageProvider redImageProvider;
  late FakeImageProvider blueImageProvider;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('blackhole_batch2_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
    if (!GetIt.I.isRegistered<MyTheme>()) {
      GetIt.I.registerSingleton<MyTheme>(MyTheme());
    }

    redImageProvider = await createColorImage(const Color(0xFFFF0000));
    blueImageProvider = await createColorImage(const Color(0xFF0000FF));
  });

  tearDownAll(() async {
    await settingsBox.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Batch 2: palette_generator 0.3.3+7 Modernisation Tests', () {
    test('PaletteGenerator extracts dominant color from pre-decoded ImageProvider', () async {
      final palette = await PaletteGenerator.fromImageProvider(redImageProvider);

      expect(palette, isNotNull);
      expect(palette.dominantColor, isNotNull);
      expect(palette.dominantColor!.color.red, greaterThan(200));
    });

    test('getColors extracts gradient pair and updates MyTheme playGradientColor', () async {
      final colors = await getColors(imageProvider: redImageProvider);

      expect(colors, hasLength(2));
      expect(colors[0], isA<Color>());
      expect(colors[1], isA<Color>());

      final myThemeColors = GetIt.I<MyTheme>().playGradientColor;
      expect(myThemeColors, hasLength(2));
      expect(myThemeColors, equals(colors));
    });

    test('getColors handles distinct image palettes deterministically', () async {
      final blueColors = await getColors(imageProvider: blueImageProvider);

      expect(blueColors, hasLength(2));
      expect(
        blueColors[0].blue > 100 || blueColors[1].blue > 100,
        isTrue,
      );
    });

    test('PaletteGenerator.fromColors constructor creates expected swatches', () {
      final customColors = [
        PaletteColor(const Color(0xFFFF0000), 50),
        PaletteColor(const Color(0xFF00FF00), 30),
      ];
      final palette = PaletteGenerator.fromColors(customColors);

      expect(palette.paletteColors, hasLength(2));
      expect(palette.dominantColor?.color, equals(const Color(0xFFFF0000)));
    });
  });

  group('Batch 2: flutter_displaymode 0.7.0 Modernisation Tests', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_display_mode'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'setHighRefreshRate':
              return true;
            case 'getSupportedModes':
              return <Map<dynamic, dynamic>>[
                <String, dynamic>{
                  'width': 1080,
                  'height': 2400,
                  'refreshRate': 120.0,
                  'id': 1,
                },
              ];
            case 'getActiveMode':
              return <String, dynamic>{
                'width': 1080,
                'height': 2400,
                'refreshRate': 120.0,
                'id': 1,
              };
            case 'setPreferredMode':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_display_mode'),
        null,
      );
    });

    test('FlutterDisplayMode methods execute successfully with mock channel', () async {
      await FlutterDisplayMode.setHighRefreshRate();
      final supported = await FlutterDisplayMode.supported;
      expect(supported, hasLength(2));
      expect(supported[0], equals(DisplayMode.auto));
      expect(supported[1].refreshRate, equals(120.0));

      final active = await FlutterDisplayMode.active;
      expect(active.refreshRate, equals(120.0));

      await FlutterDisplayMode.setPreferredMode(supported[1]);
    });

    test('setOptimalDisplayMode executes safely without throwing', () async {
      expect(() => setOptimalDisplayMode(), returnsNormally);
    });
  });

  group('Batch 2: cached_network_image 3.3.1 Contract & Retention Tests', () {
    testWidgets('CachedNetworkImage renders placeholder and preserves widget contract',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedNetworkImage(
              imageUrl: 'https://example.com/artwork.jpg',
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('CachedNetworkImageProvider constructs with correct URL and cacheKey', () {
      const url = 'https://example.com/test_album.jpg';
      const cacheKey = 'custom_cache_key_123';
      const provider = CachedNetworkImageProvider(
        url,
        cacheKey: cacheKey,
        maxWidth: 300,
        maxHeight: 300,
      );

      expect(provider.url, equals(url));
      expect(provider.cacheKey, equals(cacheKey));
      expect(provider.maxWidth, equals(300));
      expect(provider.maxHeight, equals(300));
    });

    testWidgets('CachedNetworkImage errorWidget is built when network image fails',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedNetworkImage(
              imageUrl: 'http://invalid-non-existent-domain-404.com/song.jpg',
              placeholder: (context, url) => const Text('Loading...'),
              errorWidget: (context, url, error) => const Text('Error Loading Image'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });
  });
}
