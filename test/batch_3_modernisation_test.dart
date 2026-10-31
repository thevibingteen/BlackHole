/*
 *  This file is part of BlackHole (https://github.com/thevibingteen/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'package:blackhole/Helpers/app_links.dart';
import 'package:blackhole/Helpers/update.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 3 - Connectivity Multi-Result Evaluation Tests', () {
    String determineConnectionType(List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        return 'wifi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        return 'mobile';
      } else if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        return 'none';
      } else {
        return 'other';
      }
    }

    test('WiFi alone selects wifi connection type', () {
      expect(determineConnectionType([ConnectivityResult.wifi]), 'wifi');
    });

    test('Ethernet alone selects wifi connection type', () {
      expect(determineConnectionType([ConnectivityResult.ethernet]), 'wifi');
    });

    test('WiFi + Mobile data prefers high-speed wifi connection type', () {
      expect(
        determineConnectionType([
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ]),
        'wifi',
      );
    });

    test('Mobile alone selects mobile connection type', () {
      expect(determineConnectionType([ConnectivityResult.mobile]), 'mobile');
    });

    test('Mobile + VPN selects mobile connection type', () {
      expect(
        determineConnectionType([
          ConnectivityResult.mobile,
          ConnectivityResult.vpn,
        ]),
        'mobile',
      );
    });

    test('None or empty selects none connection type', () {
      expect(determineConnectionType([ConnectivityResult.none]), 'none');
      expect(determineConnectionType([]), 'none');
    });

    test('Other or bluetooth alone selects other connection type', () {
      expect(determineConnectionType([ConnectivityResult.bluetooth]), 'other');
      expect(determineConnectionType([ConnectivityResult.other]), 'other');
    });
  });

  group('Batch 3 - App Version Comparison & Metadata Tests', () {
    test('compareVersion detects newer version correctly', () {
      expect(compareVersion('1.15.9', '1.15.8'), true);
      expect(compareVersion('1.16.0', '1.15.8'), true);
      expect(compareVersion('2.0.0', '1.15.8'), true);
    });

    test('compareVersion rejects equal or older version', () {
      expect(compareVersion('1.15.8', '1.15.8'), false);
      expect(compareVersion('1.15.7', '1.15.8'), false);
      expect(compareVersion('1.14.9', '1.15.8'), false);
    });

    test('compareVersion handles build metadata and v prefixes safely', () {
      expect(compareVersion('v1.15.9', '1.15.8'), true);
      expect(
        compareVersion('1.15.8+40', '1.15.8+39'),
        false,
      ); // SemVer core same
    });
  });

  group('Batch 3 - URL Launcher & Safe AppLinks Tests', () {
    setUp(() {
      AppLinks.resetForTesting();
    });

    testWidgets(
        'AppLinks.open launches valid external URL using externalApplication mode',
        (tester) async {
      Uri? capturedUri;
      LaunchMode? capturedMode;

      AppLinks.launchUrlOverride =
          (Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
        capturedUri = uri;
        capturedMode = mode;
        return true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppLinks.open(
                    context,
                    'https://github.com/thevibingteen/BlackHole',
                  );
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(
        capturedUri,
        Uri.parse('https://github.com/thevibingteen/BlackHole'),
      );
      expect(capturedMode, LaunchMode.externalApplication);
    });

    testWidgets('AppLinks.open debounces rapid repeated taps within 1000ms',
        (tester) async {
      int launchCount = 0;

      AppLinks.launchUrlOverride =
          (Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
        launchCount++;
        return true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppLinks.open(
                    context,
                    'https://github.com/thevibingteen/BlackHole',
                  );
                },
                child: const Text('Launch Rapid'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Launch Rapid'));
      await tester.tap(find.text('Launch Rapid'));
      await tester.pumpAndSettle();

      expect(launchCount, 1);
    });

    testWidgets('AppLinks.open handles launcher failure gracefully',
        (tester) async {
      AppLinks.launchUrlOverride =
          (Uri uri, {LaunchMode mode = LaunchMode.externalApplication}) async {
        return false;
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppLinks.open(context, 'https://invalid.test');
                  },
                  child: const Text('Launch Fail'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Launch Fail'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Batch 3 - Device Info Defensive ABIs Logic Tests', () {
    List<String> getEffectiveAbis({
      required bool isAndroid,
      List<String>? androidAbis,
    }) {
      if (isAndroid) {
        return androidAbis ?? [];
      }
      return [];
    }

    test('Returns supported ABIs on Android', () {
      final abis = getEffectiveAbis(
        isAndroid: true,
        androidAbis: ['arm64-v8a', 'armeabi-v7a'],
      );
      expect(abis, ['arm64-v8a', 'armeabi-v7a']);
    });

    test('Returns empty list when Android returns null', () {
      final abis = getEffectiveAbis(isAndroid: true);
      expect(abis, isEmpty);
    });

    test('Returns empty list on non-Android platforms', () {
      final abis = getEffectiveAbis(
        isAndroid: false,
        androidAbis: ['x86_64'],
      );
      expect(abis, isEmpty);
    });
  });
}
