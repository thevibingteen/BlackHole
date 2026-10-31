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

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:blackhole/Helpers/config.dart';
import 'package:blackhole/Helpers/countrycodes.dart';
import 'package:blackhole/Helpers/handle_native.dart';
import 'package:blackhole/Helpers/import_export_playlist.dart';
import 'package:blackhole/Helpers/logging.dart';
import 'package:blackhole/Helpers/route_handler.dart';
import 'package:blackhole/Helpers/startup_profiler.dart';
import 'package:blackhole/Screens/About/about.dart';
import 'package:blackhole/Screens/Home/home.dart';
import 'package:blackhole/Screens/Library/downloads.dart';
import 'package:blackhole/Screens/Library/nowplaying.dart';
import 'package:blackhole/Screens/Library/playlists.dart';
import 'package:blackhole/Screens/Library/recent.dart';
import 'package:blackhole/Screens/Library/stats.dart';
import 'package:blackhole/Screens/Login/auth.dart';
import 'package:blackhole/Screens/Login/pref.dart';
import 'package:blackhole/Screens/Player/audioplayer.dart';
import 'package:blackhole/Screens/Settings/new_settings_page.dart';
import 'package:blackhole/Services/audio_service.dart';
import 'package:blackhole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

Future<void> main() async {
  final profiler = StartupProfiler.instance;
  profiler.mark('main_entry');

  WidgetsFlutterBinding.ensureInitialized();
  profiler.mark('binding_initialized');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await Hive.initFlutter('BlackHole');
  } else {
    await Hive.initFlutter();
  }
  profiler.mark('hive_init_done');

  // Open core essential boxes before starting the service
  await Future.wait([
    openHiveBox('settings'),
    openHiveBox('downloads'),
    openHiveBox('cache', limit: true),
    openHiveBox('Favorite Songs'),
  ]);
  profiler.mark('core_boxes_open');

  if (!GetIt.I.isRegistered<MyTheme>()) {
    GetIt.I.registerSingleton<MyTheme>(MyTheme());
  }
  profiler.mark('theme_registered');

  // Start audio service now that all required boxes are guaranteed open
  await startService();
  profiler.mark('audio_service_ready');

  // Open non-critical boxes in background without blocking initial UI paint
  unawaited(
    Future.wait([
      openHiveBox('stats'),
      openHiveBox('ytlinkcache', limit: true),
    ]),
  );

  if (Platform.isAndroid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setOptimalDisplayMode();
    });
  }

  profiler.mark('run_app_start');
  runApp(MyApp());
  profiler.mark('run_app_done');
}

Future<void> setOptimalDisplayMode() async {
  await FlutterDisplayMode.setHighRefreshRate();
}

bool _isStartingAudioService = false;

Future<void> startService({bool isRetry = false}) async {
  if (GetIt.I.isRegistered<AudioPlayerHandler>()) {
    Logger.root.info('startService: AudioPlayerHandler is already registered, skipping.');
    return;
  }
  if (_isStartingAudioService) {
    Logger.root.info('startService: AudioService initialization already in progress, awaiting.');
    try {
      await StartupProfiler.audioHandlerFuture;
    } catch (_) {}
    return;
  }
  _isStartingAudioService = true;
  if (isRetry) {
    StartupProfiler.prepareForRetry();
  }
  if (!GetIt.I.isRegistered<MyTheme>()) {
    GetIt.I.registerSingleton<MyTheme>(MyTheme());
  }
  unawaited(initializeLogging());
  unawaited(
    Future(() {
      try {
        MetadataGod.initialize();
      } catch (e) {
        Logger.root.warning('MetadataGod deferred init error: $e');
      }
    }),
  );
  try {
    final AudioPlayerHandler audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandlerImpl(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.shadow.blackhole.channel.audio',
        androidNotificationChannelName: 'BlackHole',
        androidNotificationIcon: 'drawable/ic_stat_music_note',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
        notificationColor: Colors.grey[900],
      ),
    );
    if (!GetIt.I.isRegistered<AudioPlayerHandler>()) {
      GetIt.I.registerSingleton<AudioPlayerHandler>(audioHandler);
    }
    StartupProfiler.notifyAudioServiceReady(audioHandler);
    StartupProfiler.instance.mark('audio_service_ready');
  } catch (e, st) {
    Logger.root.severe('Failed to initialize AudioService: $e', e, st);
    StartupProfiler.notifyAudioServiceFailed(e, st);
    StartupProfiler.instance.mark('audio_service_failed');
  } finally {
    _isStartingAudioService = false;
  }
}

Future<void> openHiveBox(String boxName, {bool limit = false}) async {
  if (Hive.isBoxOpen(boxName)) {
    final box = Hive.box(boxName);
    if (limit && box.length > 500) {
      box.clear();
    }
    return;
  }

  try {
    final box = await Hive.openBox(boxName, crashRecovery: false);
    if (limit && box.length > 500) {
      box.clear();
    }
  } catch (error, stackTrace) {
    Logger.root.severe(
      'Failed to open $boxName Box: $error',
      error,
      stackTrace,
    );

    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      if (limit && box.length > 500) {
        box.clear();
      }
      return;
    }

    Logger.root.severe(
      'Box $boxName could not be opened safely. Preserving database (.hive) and lock (.lock) files intact without modification.',
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();

  // ignore: unreachable_from_main
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en', '');
  late StreamSubscription _intentTextStreamSubscription;
  late StreamSubscription _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _intentTextStreamSubscription.cancel();
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final String systemLangCode = Platform.localeName.substring(0, 2);
    if (ConstantCodes.languageCodes.values.contains(systemLangCode)) {
      _locale = Locale(systemLangCode);
    } else {
      final String lang =
          Hive.box('settings').get('lang', defaultValue: 'English') as String;
      _locale = Locale(ConstantCodes.languageCodes[lang] ?? 'en');
    }

    AppTheme.currentTheme.addListener(() {
      setState(() {});
    });

    if (Platform.isAndroid || Platform.isIOS) {
      // For sharing or opening urls/text coming from outside the app while the app is in the memory
      _intentTextStreamSubscription =
          ReceiveSharingIntent.getTextStream().listen(
        (String value) {
          Logger.root.info('Received intent on stream: $value');
          handleSharedText(value, navigatorKey);
        },
        onError: (err) {
          Logger.root.severe('ERROR in getTextStream', err);
        },
      );

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then(
        (String? value) {
          Logger.root.info('Received Intent initially: $value');
          if (value != null) handleSharedText(value, navigatorKey);
        },
        onError: (err) {
          Logger.root.severe('ERROR in getInitialTextStream', err);
        },
      );

      // For sharing files coming from outside the app while the app is in the memory
      _intentDataStreamSubscription =
          ReceiveSharingIntent.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          if (value.isNotEmpty) {
            for (final file in value) {
              if (file.path.endsWith('.json')) {
                final List playlistNames = Hive.box('settings')
                        .get('playlistNames')
                        ?.toList() as List? ??
                    ['Favorite Songs'];
                importFilePlaylist(
                  null,
                  playlistNames,
                  path: file.path,
                  pickFile: false,
                ).then(
                  (value) => navigatorKey.currentState?.pushNamed('/playlists'),
                );
              }
            }
          }
        },
        onError: (err) {
          Logger.root.severe('ERROR in getDataStream', err);
        },
      );

      // For sharing files coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialMedia()
          .then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          for (final file in value) {
            if (file.path.endsWith('.json')) {
              final List playlistNames = Hive.box('settings')
                      .get('playlistNames')
                      ?.toList() as List? ??
                  ['Favorite Songs'];
              importFilePlaylist(
                null,
                playlistNames,
                path: file.path,
                pickFile: false,
              ).then(
                (value) => navigatorKey.currentState?.pushNamed('/playlists'),
              );
            }
          }
        }
      });
    }
  }

  void setLocale(Locale value) {
    setState(() {
      _locale = value;
    });
  }

  Widget initialFuntion() {
    return Hive.box('settings').get('userId') != null
        ? HomePage()
        : AuthScreen();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: AppTheme.themeMode == ThemeMode.system
            ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                ? Brightness.light
                : Brightness.dark
            : AppTheme.themeMode == ThemeMode.dark
                ? Brightness.light
                : Brightness.dark,
        systemNavigationBarIconBrightness:
            AppTheme.themeMode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark
                : AppTheme.themeMode == ThemeMode.dark
                    ? Brightness.light
                    : Brightness.dark,
      ),
      child: MaterialApp(
        title: 'BlackHole',
        restorationScopeId: 'blackhole',
        debugShowCheckedModeBanner: false,
        themeMode: AppTheme.themeMode,
        theme: AppTheme.lightTheme(
          context: context,
        ),
        darkTheme: AppTheme.darkTheme(
          context: context,
        ),
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: ConstantCodes.languageCodes.entries
            .map((languageCode) => Locale(languageCode.value, ''))
            .toList(),
        routes: {
          '/': (context) => initialFuntion(),
          '/pref': (context) => const PrefScreen(),
          '/setting': (context) => const NewSettingsPage(),
          '/about': (context) => AboutScreen(),
          '/playlists': (context) => PlaylistScreen(),
          '/nowplaying': (context) => NowPlaying(),
          '/recent': (context) => RecentlyPlayed(),
          '/downloads': (context) => const Downloads(),
          '/stats': (context) => const Stats(),
        },
        navigatorKey: navigatorKey,
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == '/player') {
            return PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => const PlayScreen(),
            );
          }
          return HandleRoute.handleRoute(settings.name);
        },
      ),
    );
  }
}
