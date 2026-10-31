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

import 'package:blackhole/Helpers/image_resolution_modifier.dart';
import 'package:blackhole/Helpers/mediaitem_converter.dart';
import 'package:blackhole/Services/youtube_services.dart';
import 'package:blackhole/Services/yt_music.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Artwork Quality & Resolution Enhancement - getImageUrl', () {
    test(
        'JioSaavn .jpg: upgrades 150x150 and 50x50 to 500x500 and enforces HTTPS',
        () {
      expect(
        getImageUrl('http://c.saavncdn.com/123/Song-Title-150x150.jpg'),
        equals('https://c.saavncdn.com/123/Song-Title-500x500.jpg'),
      );
      expect(
        getImageUrl('http://c.saavncdn.com/123/Song-Title-50x50.jpg'),
        equals('https://c.saavncdn.com/123/Song-Title-500x500.jpg'),
      );
    });

    test(
        'JioSaavn .webp: upgrades 150x150 and 50x50 to 500x500 for webp assets',
        () {
      expect(
        getImageUrl('http://c.saavncdn.com/456/Album-Art-150x150.webp'),
        equals('https://c.saavncdn.com/456/Album-Art-500x500.webp'),
      );
      expect(
        getImageUrl('https://c.saavncdn.com/456/Album-Art-50x50.webp'),
        equals('https://c.saavncdn.com/456/Album-Art-500x500.webp'),
      );
    });

    test(
        'Google CDN / YouTube Music: upgrades dynamic sizing parameters to 544px',
        () {
      const lowResUrl =
          'https://lh3.googleusercontent.com/sample_image=w60-h60-l90-rj';
      expect(
        getImageUrl(lowResUrl),
        equals(
            'https://lh3.googleusercontent.com/sample_image=w544-h544-l90-rj',),
      );

      const medResUrl =
          'https://lh3.googleusercontent.com/sample_image=w120-h120-l90-rj';
      expect(
        getImageUrl(medResUrl),
        equals(
            'https://lh3.googleusercontent.com/sample_image=w544-h544-l90-rj',),
      );

      const avatarUrl =
          'https://yt3.ggpht.com/ytc/sample_avatar=s68-c-k-c0x00ffffff-no-rj';
      expect(
        getImageUrl(avatarUrl),
        equals(
            'https://yt3.ggpht.com/ytc/sample_avatar=s544-c-k-c0x00ffffff-no-rj',),
      );
    });

    test('Google CDN: respects medium and low quality parameters', () {
      const url =
          'https://lh3.googleusercontent.com/sample_image=w60-h60-l90-rj';
      expect(
        getImageUrl(url, quality: 'medium'),
        equals(
            'https://lh3.googleusercontent.com/sample_image=w226-h226-l90-rj',),
      );
      expect(
        getImageUrl(url, quality: 'low'),
        equals(
            'https://lh3.googleusercontent.com/sample_image=w120-h120-l90-rj',),
      );
    });

    test(
        'YouTube standard video thumbnails: upgrades default/mqdefault to hqdefault',
        () {
      expect(
        getImageUrl('https://i.ytimg.com/vi/M7lc1UVf-VE/default.jpg'),
        equals('https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg'),
      );
      expect(
        getImageUrl('https://i.ytimg.com/vi/M7lc1UVf-VE/mqdefault.jpg'),
        equals('https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg'),
      );
      // hqdefault and maxresdefault are preserved
      expect(
        getImageUrl('https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg'),
        equals('https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg'),
      );
      expect(
        getImageUrl('https://i.ytimg.com/vi/M7lc1UVf-VE/maxresdefault.jpg'),
        equals('https://i.ytimg.com/vi/M7lc1UVf-VE/maxresdefault.jpg'),
      );
    });

    test('Gracefully handles null, empty string, and whitespace', () {
      expect(getImageUrl(null), equals(''));
      expect(getImageUrl(''), equals(''));
      expect(getImageUrl('   '), equals(''));
    });
  });

  group('YouTubeServices - High-Resolution Item Formatting', () {
    final mockChartItem = [
      {
        'gridPlaylistRenderer': {
          'title': {
            'runs': [
              {'text': 'Top 50 India'},
            ],
          },
          'shortBylineText': {
            'runs': [
              {'text': 'YouTube Music'},
            ],
          },
          'videoCountText': {
            'runs': [
              {'text': '50 tracks'},
            ],
          },
          'navigationEndpoint': {
            'watchEndpoint': {
              'playlistId': 'PL_mock_playlist',
              'videoId': 'mock_video_id',
            },
          },
          'thumbnail': {
            'thumbnails': [
              {
                'url': 'https://i.ytimg.com/vi/mock/w60.jpg',
                'width': 60,
                'height': 60,
              },
              {
                'url': 'https://i.ytimg.com/vi/mock/w120.jpg',
                'width': 120,
                'height': 120,
              },
              {
                'url': 'https://i.ytimg.com/vi/mock/w226.jpg',
                'width': 226,
                'height': 226,
              },
              {
                'url': 'https://i.ytimg.com/vi/mock/w544.jpg',
                'width': 544,
                'height': 544,
              },
            ],
          },
        },
      }
    ];

    test('formatChartItems selects highest resolution thumbnail (last entry)',
        () {
      final yt = YouTubeServices();
      final results = yt.formatChartItems(mockChartItem);

      expect(results.length, equals(1));
      final item = results.first;
      expect(item['title'], equals('Top 50 India'));
      expect(item['image'], equals('https://i.ytimg.com/vi/mock/w544.jpg'));
      expect(item['imageMax'], equals('https://i.ytimg.com/vi/mock/w544.jpg'));
      expect(item['imageStandard'],
          equals('https://i.ytimg.com/vi/mock/w226.jpg'),);
      expect(
          item['imageMedium'], equals('https://i.ytimg.com/vi/mock/w120.jpg'),);
    });

    test('formatItems selects highest resolution thumbnail (last entry)', () {
      final yt = YouTubeServices();
      final results = yt.formatItems(mockChartItem);

      expect(results.length, equals(1));
      final item = results.first;
      expect(item['title'], equals('Top 50 India'));
      expect(item['image'], equals('https://i.ytimg.com/vi/mock/w544.jpg'));
      expect(item['imageMax'], equals('https://i.ytimg.com/vi/mock/w544.jpg'));
    });

    test('formatHeadItems selects highest resolution thumbnail', () {
      final mockHeadItem = [
        {
          'defaultPromoPanelRenderer': {
            'title': {
              'runs': [
                {'text': 'Featured Head Promo'},
              ],
            },
            'description': {
              'runs': [
                {'text': 'Promo Description'},
              ],
            },
            'navigationEndpoint': {
              'watchEndpoint': {'videoId': 'promo_vid_123'},
            },
            'largeFormFactorBackgroundThumbnail': {
              'thumbnailLandscapePortraitRenderer': {
                'landscape': {
                  'thumbnails': [
                    {
                      'url': 'https://i.ytimg.com/vi/promo/w320.jpg',
                      'width': 320,
                    },
                    {
                      'url': 'https://i.ytimg.com/vi/promo/w640.jpg',
                      'width': 640,
                    },
                    {
                      'url': 'https://i.ytimg.com/vi/promo/w1280.jpg',
                      'width': 1280,
                    },
                  ],
                },
              },
            },
          },
        }
      ];

      final yt = YouTubeServices();
      final results = yt.formatHeadItems(mockHeadItem);

      expect(results.length, equals(1));
      final item = results.first;
      expect(item['title'], equals('Featured Head Promo'));
      expect(item['image'], equals('https://i.ytimg.com/vi/promo/w1280.jpg'));
      expect(
          item['imageMax'], equals('https://i.ytimg.com/vi/promo/w1280.jpg'),);
    });

    test('formatChartItems gracefully handles missing thumbnails', () {
      final yt = YouTubeServices();
      final emptyThumbsItem = [
        {
          'gridPlaylistRenderer': {
            'title': {
              'runs': [
                {'text': 'Empty Thumbs Playlist'},
              ],
            },
            'shortBylineText': {
              'runs': [
                {'text': 'Author'},
              ],
            },
            'videoCountText': {
              'runs': [
                {'text': '0 tracks'},
              ],
            },
            'navigationEndpoint': {
              'watchEndpoint': {
                'playlistId': 'PL_empty',
                'videoId': 'vid_empty',
              },
            },
            'thumbnail': {'thumbnails': []},
          },
        }
      ];

      final results = yt.formatChartItems(emptyThumbsItem);
      expect(results.length, equals(1));
      expect(results.first['image'], equals(''));
      expect(results.first['imageMax'], equals(''));
    });
  });

  group('YtMusicService - Responsive List Item Parsing', () {
    test(
        'parseResponsiveListItem selects sharpest (last) image from thumbnail list',
        () {
      final ytMusic = YtMusicService();
      final mockChild = {
        'musicResponsiveListItemRenderer': {
          'thumbnail': {
            'musicThumbnailRenderer': {
              'thumbnail': {
                'thumbnails': [
                  {
                    'url': 'https://lh3.googleusercontent.com/art=w60-h60',
                    'width': 60,
                  },
                  {
                    'url': 'https://lh3.googleusercontent.com/art=w120-h120',
                    'width': 120,
                  },
                  {
                    'url': 'https://lh3.googleusercontent.com/art=w544-h544',
                    'width': 544,
                  },
                ],
              },
            },
          },
          'flexColumns': [
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {'text': 'High Quality Track'},
                  ],
                },
              },
            },
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {'text': 'Track Artist'},
                  ],
                },
              },
            }
          ],
          'playlistItemData': {'videoId': 'hq_video_id_001'},
        },
      };

      final parsed = ytMusic.parseResponsiveListItem(mockChild);
      expect(parsed, isNotNull);
      expect(parsed!['id'], equals('hq_video_id_001'));
      expect(parsed['title'], equals('High Quality Track'));
      expect(
        parsed['image'],
        equals('https://lh3.googleusercontent.com/art=w544-h544'),
      );
    });
  });

  group('MediaItemConverter - Artwork URI & Fallbacks', () {
    test('mapToMediaItem sets artUri using getImageUrl', () {
      final songMap = {
        'id': 'test_song_1',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'album': 'Test Album',
        'duration': '240',
        'image': 'http://c.saavncdn.com/789/Art-150x150.jpg',
        'genre': 'Pop',
        'url': 'https://stream.example.com/audio.mp4',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(songMap);
      expect(
        mediaItem.artUri.toString(),
        equals('https://c.saavncdn.com/789/Art-500x500.jpg'),
      );
    });

    test('mapToMediaItem falls back to secondImage if image is empty', () {
      final songMap = {
        'id': 'test_song_2',
        'title': 'Fallback Song',
        'artist': 'Fallback Artist',
        'album': 'Fallback Album',
        'duration': '180',
        'image': '',
        'secondImage': 'https://i.ytimg.com/vi/fallback/hqdefault.jpg',
        'genre': 'YouTube',
        'url': 'https://stream.example.com/yt.mp4',
      };

      final mediaItem = MediaItemConverter.mapToMediaItem(songMap);
      expect(
        mediaItem.artUri.toString(),
        equals('https://i.ytimg.com/vi/fallback/hqdefault.jpg'),
      );
    });
  });
}
