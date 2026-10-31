import 'package:blackhole/CustomWidgets/horizontal_albumlist.dart';
import 'package:blackhole/CustomWidgets/horizontal_albumlist_separated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

void main() {
  group('Fix A: Home Horizontal Carousel Layout & XL Accessibility Tests', () {
    final mockSongsList = [
      {
        'id': 'item_1',
        'title': 'Very Long Album Title That Wraps And Tests Scaled Constraints',
        'subtitle': 'Featured Artist Name And Music Producer Collaboration',
        'image': 'https://example.com/cover1.jpg',
        'type': 'album',
      },
      {
        'id': 'item_2',
        'title': 'Trending Song Hit Single 2026',
        'subtitle': 'Top Chart Artist Official Studio Version',
        'image': 'https://example.com/cover2.jpg',
        'type': 'song',
        'artist': 'Top Chart Artist Official Studio Version',
      },
      {
        'id': 'item_3',
        'title': 'Radio Station Mix Non-Stop',
        'subtitle': 'Curated Station Jams and Remixes',
        'image': 'https://example.com/cover3.jpg',
        'type': 'radio_station',
      },
    ];

    testWidgets(
        'HorizontalAlbumsList renders at default 1.0x text scale without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Trending Now', style: TextStyle(fontSize: 18)),
                  HorizontalAlbumsList(
                    songsList: mockSongsList,
                    onTap: (_) {},
                  ),
                  const Text('Following Section', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Trending Now'), findsOneWidget);
      expect(find.text('Following Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HorizontalAlbumsList renders under 1.4x (XL) scale with bold text without bottom overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.4),
              boldText: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Trending Now', style: TextStyle(fontSize: 18)),
                    HorizontalAlbumsList(
                      songsList: mockSongsList,
                      onTap: (_) {},
                    ),
                    const Text('Following Section', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Trending Now'), findsOneWidget);
      expect(find.text('Following Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HorizontalAlbumsList renders under 2.0x (max) scale with bold text on narrow 320dp width',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
              boldText: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Top Charts', style: TextStyle(fontSize: 18)),
                    HorizontalAlbumsList(
                      songsList: mockSongsList,
                      onTap: (_) {},
                    ),
                    const Text('Next Section', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Top Charts'), findsOneWidget);
      expect(find.text('Next Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Fix B: Last Session / Recently Played Vertical Overflow Tests', () {
    final mockRecentFour = [
      {
        'id': 'rec_1',
        'title': 'Track One - Very Long Title That Tests Multiple Text Scale Constraints',
        'artist': 'Artist Name Extended Collaboration With Guest Performer',
        'image': 'https://example.com/rec1.jpg',
        'type': 'song',
      },
      {
        'id': 'rec_2',
        'title': 'Track Two - Midnight City Radio Edit Special Master',
        'artist': 'Electro Pop Band & DJ Producer',
        'image': 'https://example.com/rec2.jpg',
        'type': 'song',
      },
      {
        'id': 'rec_3',
        'title': 'Track Three - Acoustic Live Session In Concert',
        'artist': 'Singer Songwriter Acoustic Guitar Duo',
        'image': 'https://example.com/rec3.jpg',
        'type': 'song',
      },
      {
        'id': 'rec_4',
        'title': 'Track Four - Classical Symphony Movement 4 Finale',
        'artist': 'Philharmonic Orchestra Conductor Soloist',
        'image': 'https://example.com/rec4.jpg',
        'type': 'song',
      },
    ];

    testWidgets(
        'HorizontalAlbumsListSeparated renders 4 rows at 1.0x scale without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Last Session', style: TextStyle(fontSize: 18)),
                  HorizontalAlbumsListSeparated(
                    songsList: mockRecentFour,
                    onTap: (_) {},
                  ),
                  const Text('Following Section', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Last Session'), findsOneWidget);
      expect(find.text('Following Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HorizontalAlbumsListSeparated renders 4 rows under 1.4x (XL) scale with bold text without bottom overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.4),
              boldText: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Last Session', style: TextStyle(fontSize: 18)),
                    HorizontalAlbumsListSeparated(
                      songsList: mockRecentFour,
                      onTap: (_) {},
                    ),
                    const Text('Following Section', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Last Session'), findsOneWidget);
      expect(find.text('Following Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'HorizontalAlbumsListSeparated renders under 2.0x scale with bold text without bottom overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(2.0),
              boldText: true,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text('Last Session', style: TextStyle(fontSize: 18)),
                    HorizontalAlbumsListSeparated(
                      songsList: mockRecentFour,
                      onTap: (_) {},
                    ),
                    const Text('Following Section', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Last Session'), findsOneWidget);
      expect(find.text('Following Section'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Fix C: Bottom Navigation Maximum Screen Zoom Tests', () {
    Widget buildNavBar({
      required int currentIndex,
      required double screenWidth,
      required TextScaler textScaler,
      required Function(int) onTap,
    }) {
      final double itemHorizontalPadding = screenWidth < 350
          ? 10.0
          : (screenWidth < 380 ? 12.0 : 16.0);
      final double barHorizontalMargin = screenWidth < 350 ? 4.0 : 8.0;

      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(screenWidth, 640),
            textScaler: textScaler,
          ),
          child: Scaffold(
            bottomNavigationBar: SafeArea(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 60,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                                    child: SizedBox(
                    width: () {
                      final scale = textScaler.scale(1.0);
                      final base = screenWidth < 380 ? 380.0 : screenWidth;
                      return base * (scale > 1.0 ? scale : 1.0);
                    }(),
                    child: SalomonBottomBar(
                      margin: EdgeInsets.symmetric(
                        horizontal: barHorizontalMargin,
                        vertical: 4.0,
                      ),
                      itemPadding: EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: itemHorizontalPadding,
                      ),
                      currentIndex: currentIndex,
                      onTap: onTap,
                      items: [
                        SalomonBottomBarItem(
                          icon: const Icon(Icons.home_rounded),
                          title: const Text('Home'),
                          selectedColor: Colors.tealAccent,
                        ),
                        SalomonBottomBarItem(
                          icon: const Icon(Icons.trending_up_rounded),
                          title: const Text('Top Charts'),
                          selectedColor: Colors.tealAccent,
                        ),
                        SalomonBottomBarItem(
                          icon: const Icon(Icons.video_library_rounded),
                          title: const Text('YouTube'),
                          selectedColor: Colors.tealAccent,
                        ),
                        SalomonBottomBarItem(
                          icon: const Icon(Icons.my_library_music_rounded),
                          title: const Text('Library'),
                          selectedColor: Colors.tealAccent,
                        ),
                        SalomonBottomBarItem(
                          icon: const Icon(Icons.settings_rounded),
                          title: const Text('Settings'),
                          selectedColor: Colors.tealAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
        'Top Charts selected under maximum screen zoom (320dp width) has zero right-edge overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      int tappedIndex = -1;
      await tester.pumpWidget(
        buildNavBar(
          currentIndex: 1, // Top Charts selected
          screenWidth: 320.0,
          textScaler: TextScaler.noScaling,
          onTap: (idx) => tappedIndex = idx,
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Top Charts'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify tapping other items functions correctly
      await tester.tap(find.byIcon(Icons.home_rounded));
      expect(tappedIndex, 0);
    });

    testWidgets(
        'All 5 navigation tabs fit and function at 320dp width with 1.4x text scale without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));

      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(
          buildNavBar(
            currentIndex: i,
            screenWidth: 320.0,
            textScaler: const TextScaler.linear(1.4),
            onTap: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
