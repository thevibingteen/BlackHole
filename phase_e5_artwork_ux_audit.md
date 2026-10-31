# Phase E5 — Artwork Memory, Scrolling & UX Polish Audit

## 1. Executive Summary
Phase E5 targets memory consumption spikes, scrolling stutter, and visual feedback across list views, album cards, and search result tiles throughout BlackHole.

The audit identified a pervasive memory footprint issue:
1. **Unconstrained High-Resolution Bitmap Decoding on Small Thumbnails**:
   - `CachedNetworkImage` instances across multiple screens (including YouTube Search, YouTube Home, YouTube Playlist, YouTube Artist, Top Charts, Search, Albums, Artists, Recently Played, Liked Songs, and Collage) lacked `memCacheWidth` and `memCacheHeight` constraints.
   - Remote artwork providers often deliver images at 500x500 to 1280x720 resolutions.
   - Without decode constraints, Flutter allocates raw uncompressed RGBA pixel buffers (4 bytes per pixel):
     - A 1280x720 bitmap requires ~3.7 MB of uncompressed memory.
     - A 500x500 bitmap requires ~1.0 MB of uncompressed memory.
   - In lists rendering 50 to 100 tiles (50dp x 50dp), image buffers accumulated 100 MB to 350+ MB of RAM, forcing the Android OS Garbage Collector to run aggressive concurrent collections during scroll events, resulting in noticeable dropped frames and jank.
2. **Oversized Thumbnails in Horizontal Carousels and Cards**:
   - In `image_card.dart` and `horizontal_albumlist.dart`, thumbnails were decoded with a 500x500 memory cache bound despite being rendered inside ~120-170dp containers.
3. **Multi-Image Grid Overheads**:
   - In `collage.dart`, 4-image grid representations for playlists were decoding 4 separate unconstrained images for a single 50x50 tile (each sub-image occupying only 25x25dp on screen).

---

## 2. Bottlenecks Verified & Architectural Solutions

### 2.1 Applied Realistic Decoding Bounds Across Image Consumers
- **List Tiles (50dp–55dp)**:
  - Applied `memCacheWidth: 200, memCacheHeight: 200` (~160 KB uncompressed RAM vs 1.0–3.7 MB).
  - Target files:
    - [lib/Screens/YouTube/youtube_search.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/YouTube/youtube_search.dart)
    - [lib/Screens/YouTube/youtube_playlist.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/YouTube/youtube_playlist.dart)
    - [lib/Screens/YouTube/youtube_artist.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/YouTube/youtube_artist.dart)
    - [lib/Screens/Top Charts/top.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Top%20Charts/top.dart)
    - [lib/Screens/Search/search.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Search/search.dart)
    - [lib/Screens/Search/albums.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Search/albums.dart)
    - [lib/Screens/Search/artists.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Search/artists.dart)
    - [lib/Screens/Library/recent.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/recent.dart)
    - [lib/Screens/Library/liked.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/liked.dart)
    - [lib/Screens/Library/show_songs.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/show_songs.dart)
    - [lib/Screens/Library/import.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/import.dart)
    - [lib/CustomWidgets/data_search.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/data_search.dart)
- **Cards & Albums (120dp–170dp)**:
  - Downscaled bounds from 500x500 to `memCacheWidth: 250, memCacheHeight: 250` (~250 KB uncompressed RAM).
  - Target files:
    - [lib/CustomWidgets/image_card.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/image_card.dart)
    - [lib/CustomWidgets/horizontal_albumlist.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/horizontal_albumlist.dart)
    - [lib/Screens/YouTube/youtube_home.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/YouTube/youtube_home.dart) (horizontal list items at 300x300; carousel banner at 600x400)
- **Collage Grids (25dp sub-tiles)**:
  - Set `memCacheWidth: 100, memCacheHeight: 100` for 4-image grid cells in [lib/CustomWidgets/collage.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/collage.dart).
- **Hero & Playlist Headers (200dp–300dp)**:
  - Sized headers to `memCacheWidth: 600, memCacheHeight: 600` in [lib/CustomWidgets/bouncy_sliver_scroll_view.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/bouncy_sliver_scroll_view.dart) and [lib/CustomWidgets/bouncy_playlist_header_scroll_view.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/bouncy_playlist_header_scroll_view.dart).

---

## 3. Preserved Safeguards
- Disk cache properties (`maxWidthDiskCache`, `maxHeightDiskCache`) and network caching are preserved.
- Image aspect ratio (`fit: BoxFit.cover`) and error fallbacks (`assets/cover.jpg`, `assets/album.png`, `assets/artist.png`) remain 100% intact.
- 2x/3x retina display density clarity is maintained with ~200px decode for 50dp tiles.
