# BlackHole Post-Batch-3 Artwork Quality & Loading Fix Report

**Date:** October 25, 2026  
**Active Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Target Milestone:** Post-Batch-3 Artwork Quality & Loading Fix  
**Original Repository (Strictly Read-Only):** `D:\My-GitHub-Projects\BlackHole`  
**Gradle User Home:** `D:\DevCaches\GradleUserHome`  

---

## 1. Executive Summary

During physical device testing of the post-Batch-3 build, the maintainer observed that song, album, chart, and video posters across Home, Charts, YouTube, and the Full Audio Player sections appeared visibly blurred, pixelated, or low-resolution after loading.

This targeted fix addresses the end-to-end artwork loading and resolution pipeline across all affected providers (JioSaavn, YouTube Music, and YouTube Video/Charts) without destabilizing audio playback, stream buffering, downloads, or existing UI layouts.

### Key Results
- **Root Cause Identified & Remediated:** Discovered five distinct contributing factors: (1) YouTube thumbnail parser selecting the smallest 60x60/120x90 thumbnails; (2) YouTube Music responsive list item parser picking `images.first` (60x60) instead of `images.last` (544x544); (3) `image_resolution_modifier.dart` lacking Google CDN dynamic sizing (`=w...-h...`) and YouTube video thumbnail enhancement (`default.jpg`/`mqdefault.jpg` -> `hqdefault.jpg`); (4) Disk cache downsampling in `CachedNetworkImage` widgets (`maxWidthDiskCache: 300`/`500`) causing downsampled disk files to be upscaled blurrily in the full player; (5) Raw image URLs in Search, Top Charts, and YouTube screens bypassing `getImageUrl(...)`.
- **Targeted Code Changes:** 17 production Dart files updated cleanly with minimal footprint; 1 comprehensive unit test file created (`test/artwork_quality_test.dart`).
- **Preservation of Past Work:** The landscape display-cutout / notch fix (`shortEdges` and `SafeArea`), all four Batch 3 modernised dependencies, and all nine dependency overrides remain 100% intact.
- **Automated Verification:**
  - Focused Artwork Quality Suite: **13/13 passed** (exit code 0).
  - Full Regression Suite: **198/198 passed** (exit code 0, 0 failures, 0 timeouts).
- **Build Verification:**
  - Debug APK successfully compiled via `D:\DevCaches\GradleUserHome` in 68.9s with exit code 0.
  - New APK size: **197,270,429 bytes**.
  - New APK SHA-256: `6d8c2734191c5c97a520b2783e3f8e907ed4b46f86aa7f340e01343201faeabd`.
  - Checkpoint APK preserved intact: `app-debug.apk.pre-artwork-quality` (170,300,686 bytes, SHA-256: `486355d220fdab0ea2c13ca3ebcf2fe655a315c4d7acd6c8490c0e1cc0cb515b`).
  - Strict isolation maintained: `C:\Users\gkpsu\.gradle` was not created (`Test-Path: False`).

---

## 2. Root Cause Analysis

Investigation across network service layers, image transformation helpers, caching strategies, and UI widgets revealed five root causes responsible for the blurry poster rendering:

### Root Cause 1: YouTube Services Parsing Lowest Thumbnail
In `lib/Services/youtube_services.dart`, methods `formatChartItems`, `formatItems`, and `formatHeadItems` parsed YouTube API responses by hardcoding index 0:
```dart
// Before:
'image': item['thumbnails'][0]['url'],
```
In YouTube Innertube / v3 responses, the `thumbnails` list is sorted in ascending resolution order (index 0 is typically 60x60 or 120x90). This meant BlackHole deliberately extracted the lowest-resolution thumbnail available.

### Root Cause 2: YouTube Music Responsive List Item Parsing Smallest Image
In `lib/Services/yt_music.dart`, the `_parseResponsiveListItem` helper mapped carousel items using `images.first`:
```dart
// Before:
'image': images.first['url'],
```
YouTube Music responsive items provide thumbnails ranging from 60x60 up to 544x544. Choosing `.first` guaranteed that the 60x60 thumbnail was selected. Additionally, `getPlaylistDetails` accessed `thumbs[0, 'url']` rather than the highest available resolution.

### Root Cause 3: Canonical Image Modifier Lacked Support for Google CDN and YouTube Thumbnails
`lib/Helpers/image_resolution_modifier.dart` (`getImageUrl`) originally only performed string substitutions on JioSaavn URLs (`150x150` -> `500x500` and `50x50` -> `500x500`). It lacked logic to handle:
1. Google CDN / YouTube Music artwork: URLs containing `=w...-h...` or `=s...` on domains like `lh3.googleusercontent.com` or `*.ggpht.com`. When low dimension parameters were present, they remained low.
2. Standard YouTube video thumbnails: URLs containing `/default.jpg` (120x90) or `/mqdefault.jpg` (320x180) on `i.ytimg.com` / `img.youtube.com`. Because not all videos have `maxresdefault.jpg` (which returns HTTP 404 for non-HD uploads), upgrading to `hqdefault.jpg` (480x360) is universally valid and guaranteed across all YouTube videos.

### Root Cause 4: Disk Cache Downsampling in CachedNetworkImage Widgets
In several UI widgets (`horizontal_albumlist_separated.dart`, `horizontal_albumlist.dart`, `miniplayer.dart`), `CachedNetworkImage` was configured with:
```dart
maxWidthDiskCache: 300,
maxHeightDiskCache: 300,
```
When `maxWidthDiskCache` is specified, `cached_network_image` resizes and permanently downsamples the image bytes **before saving them to disk storage**.
Consequently, when the user tapped a song or album from the horizontal list, the audio player screen loaded the same URL from the disk cache. Even if the network URL was capable of yielding a 500x500 or 544x544 image, the cached file on disk was already permanently degraded to 300x300. When upscaled onto modern mobile viewports (1080x2400 with 2.75x–3.0x pixel density), the poster appeared blurry and pixelated.

### Root Cause 5: Unwrapped Image URLs in Search, Charts, and YouTube Screens
Several screen widgets referenced raw API response image fields directly without passing them through `getImageUrl(...)`:
- `lib/Screens/Top Charts/top.dart`: `showList[index]['image_url_big']` / `image_url_small`
- `lib/Screens/Search/search.dart`: `value[index]['image']`
- `lib/Screens/Search/albums.dart`: `entry['image']`
- `lib/Screens/Search/artists.dart`: `entry.value[index]['image']`
- `lib/Screens/YouTube/youtube_home.dart`: `headList[index]['image']` and `item['image']`
- `lib/Screens/YouTube/youtube_search.dart`: `section['items'][idx]['image']`
- `lib/Screens/YouTube/youtube_playlist.dart`: `entry['image']`
- `lib/Screens/YouTube/youtube_artist.dart`: `entry['image']`

---

## 3. Implementation Details

### A. Enhanced Canonical Image Resolution Modifier
**File:** `lib/Helpers/image_resolution_modifier.dart`
- Upgraded `getImageUrl` to support Google CDN (`googleusercontent.com`, `ggpht.com`):
  - High quality: maps `=w...-h...` to `=w544-h544` and `=s...` to `=s544`.
  - Medium quality: maps to `=w250-h250` and `=s250`.
  - Low quality: maps to `=w120-h120` and `=s120`.
- Upgraded YouTube video thumbnails (`i.ytimg.com`, `img.youtube.com`, `youtube.com`):
  - Automatically elevates `/default.jpg` (120x90) and `/mqdefault.jpg` (320x180) to guaranteed `/hqdefault.jpg` (480x360).
- Preserved existing JioSaavn resolution upgrades:
  - Replaces `150x150` and `50x50` with `500x500` (for both `.jpg` and `.webp`).
  - Enforces HTTPS on `http://` URLs.
- Gracefully handles null, empty, whitespace-only, and non-conforming URLs without throwing exceptions.

### B. YouTube Services Highest-Resolution Selection
**File:** `lib/Services/youtube_services.dart`
- `formatChartItems`: Replaced `thumbnails[0]['url']` with `thumbs.last['url']` (highest resolution available), guarding against empty thumbnail collections.
- `formatItems`: Replaced `thumbnails[0]['url']` with `thumbs.last['url']`.
- `formatHeadItems`: Replaced `thumbnails[0]['url']` with `thumbs.last['url']`.
- `formatVideo`: Prioritized `video.thumbnails.highResUrl` (and `maxResUrl` as fallback), assigning `secondImage` to `highResUrl`.
- `formatVideoFromInnerTube`: Prioritized non-empty `thumbUrl` from `videoDetails`.

### C. YouTube Music Highest-Resolution Selection
**File:** `lib/Services/yt_music.dart`
- `_parseResponsiveListItem`: Updated `images.first['url']` to `images.last['url']`, guaranteeing that the sharp 544x544 artwork variant is extracted.
- `getPlaylistDetails`: Updated `thumbs[0, 'url']` to `thumbs.last['url']`.

### D. Elimination of Disk Cache Downsampling & Memory Optimization
**Files:**
- `lib/CustomWidgets/horizontal_albumlist_separated.dart`
- `lib/CustomWidgets/horizontal_albumlist.dart`
- `lib/CustomWidgets/image_card.dart`
- `lib/CustomWidgets/miniplayer.dart`
- `lib/Screens/Home/saavn.dart`

**Changes:**
- Removed `maxWidthDiskCache` and `maxHeightDiskCache` so full-resolution images are cached on disk and shared losslessly across both compact list views and the full player.
- Sized `memCacheWidth` and `memCacheHeight` conservatively according to display requirements (200x200 for miniplayer, 250x250 for small cards, 500x500 for larger cards/carousels) to prevent excessive memory consumption.
- In `saavn.dart`, aligned `precacheImage` with `maxWidth: 500, maxHeight: 500`.

### E. Screen-Level Canonical URL Ingestion
**Files:**
- `lib/Screens/Top Charts/top.dart`: Wrapped `image_url_big` and `image_url_small` with `getImageUrl(...)`.
- `lib/Screens/Search/search.dart`: Wrapped search result images with `getImageUrl(...)`.
- `lib/Screens/Search/albums.dart`: Wrapped album images with `getImageUrl(...)`.
- `lib/Screens/Search/artists.dart`: Wrapped artist images with `getImageUrl(...)`.
- `lib/Screens/YouTube/youtube_home.dart`: Wrapped `headList` and carousel item images with `getImageUrl(...)`.
- `lib/Screens/YouTube/youtube_search.dart`: Wrapped search item images with `getImageUrl(...)`.
- `lib/Screens/YouTube/youtube_playlist.dart`: Wrapped playlist item images with `getImageUrl(...)`.
- `lib/Screens/YouTube/youtube_artist.dart`: Wrapped artist item images with `getImageUrl(...)`.

### F. MediaItem Fallback Safety
**File:** `lib/Helpers/mediaitem_converter.dart`
- In `mapToMediaItem`, passed `song['image']` through `getImageUrl(...)`, and added safe fallback to `song['secondImage']` if `song['image']` is empty or null.

---

## 4. Verification & Testing

### 4.1 Focused Artwork Quality Tests
A dedicated unit test suite was implemented in `test/artwork_quality_test.dart` containing 13 deterministic tests covering all aspects of the fix:
- `getImageUrl JioSaavn .jpg`: upgrades 150x150 and 50x50 to 500x500 and enforces HTTPS.
- `getImageUrl JioSaavn .webp`: upgrades 150x150 and 50x50 to 500x500 for webp assets.
- `getImageUrl Google CDN / YouTube Music`: upgrades dynamic sizing parameters to 544px.
- `getImageUrl Google CDN`: respects medium (250px) and low (120px) quality parameters.
- `getImageUrl YouTube standard video thumbnails`: upgrades default/mqdefault to hqdefault.
- `getImageUrl`: gracefully handles null, empty string, and whitespace.
- `YouTubeServices - formatChartItems`: selects highest resolution thumbnail (last entry).
- `YouTubeServices - formatItems`: selects highest resolution thumbnail (last entry).
- `YouTubeServices - formatHeadItems`: selects highest resolution thumbnail.
- `YouTubeServices - formatChartItems`: gracefully handles missing thumbnails.
- `YtMusicService - parseResponsiveListItem`: selects sharpest (last) image from thumbnail list.
- `MediaItemConverter - mapToMediaItem`: sets artUri using `getImageUrl`.
- `MediaItemConverter - mapToMediaItem`: falls back to `secondImage` if `image` is empty.

**Execution Command:**
```powershell
flutter test test/artwork_quality_test.dart --reporter expanded
```
**Result:** **13/13 passed** (exit code 0).

### 4.2 Full Automated Regression Suite
The complete project test suite was executed sequentially to ensure zero regressions across audio playback, downloads, routing, lyrics, radio, notch handling, and UI widgets:
```powershell
flutter test --reporter expanded
```
**Result:** **198/198 passed** (exit code 0, 0 failures, 0 timeouts).

### 4.3 Static Code Analysis
```powershell
flutter analyze lib test
```
**Result:** Verified that no new errors or warnings were introduced by the artwork modifications. The single error at `lib/Helpers/format.dart:727:33` (`argument_type_not_assignable`) is a documented historical baseline issue unrelated to artwork.

---

## 5. Build & Artifact Verification

### 5.1 Compilation Command & Environment
```powershell
$env:GRADLE_USER_HOME = 'D:\DevCaches\GradleUserHome'
flutter build apk --debug
```
- **Execution Time:** 68.9 seconds.
- **Exit Code:** 0.
- **Effective Gradle User Home:** `D:\DevCaches\GradleUserHome`.
- **System Isolation:** `Test-Path 'C:\Users\gkpsu\.gradle'` confirmed `False`.

### 5.2 Artifact Details
| Property | Value |
|---|---|
| **Target APK Path** | `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk` |
| **File Size** | 197,270,429 bytes |
| **SHA-256 Checksum** | `6d8c2734191c5c97a520b2783e3f8e907ed4b46f86aa7f340e01343201faeabd` |
| **Checkpoint APK Path** | `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk.pre-artwork-quality` |
| **Checkpoint Size** | 170,300,686 bytes |
| **Checkpoint SHA-256** | `486355d220fdab0ea2c13ca3ebcf2fe655a315c4d7acd6c8490c0e1cc0cb515b` |

---

## 6. Changed Files Summary

| File | Nature of Modification |
|---|---|
| `lib/Helpers/image_resolution_modifier.dart` | Added Google CDN dynamic sizing (`=w544-h544`) and YouTube thumbnail upgrading (`hqdefault.jpg`). |
| `lib/Services/youtube_services.dart` | Updated `formatChartItems`, `formatItems`, `formatHeadItems`, `formatVideo`, `formatVideoFromInnerTube` to choose highest available resolution. |
| `lib/Services/yt_music.dart` | Updated `_parseResponsiveListItem` and `getPlaylistDetails` to select highest-resolution thumbnail. |
| `lib/CustomWidgets/horizontal_albumlist_separated.dart` | Removed `maxWidthDiskCache: 300`; tuned `memCacheWidth: 250`. |
| `lib/CustomWidgets/horizontal_albumlist.dart` | Removed `maxWidthDiskCache: 500`; tuned `memCacheWidth: 500`. |
| `lib/CustomWidgets/image_card.dart` | Removed `maxWidthDiskCache: 500`; tuned `memCacheWidth: 500`. |
| `lib/CustomWidgets/miniplayer.dart` | Removed `maxWidthDiskCache: 500`; tuned `memCacheWidth: 200`. |
| `lib/Screens/Home/saavn.dart` | Removed `maxWidthDiskCache: 500`; aligned `precacheImage` and `memCacheWidth: 500`. |
| `lib/Screens/Top Charts/top.dart` | Wrapped chart image URLs with `getImageUrl(...)`. |
| `lib/Screens/Search/search.dart` | Wrapped search result image URLs with `getImageUrl(...)`. |
| `lib/Screens/Search/albums.dart` | Wrapped search album image URLs with `getImageUrl(...)`. |
| `lib/Screens/Search/artists.dart` | Wrapped search artist image URLs with `getImageUrl(...)`. |
| `lib/Screens/YouTube/youtube_home.dart` | Wrapped YouTube Home carousel and header image URLs with `getImageUrl(...)`. |
| `lib/Screens/YouTube/youtube_search.dart` | Wrapped YouTube search result image URLs with `getImageUrl(...)`. |
| `lib/Screens/YouTube/youtube_playlist.dart` | Wrapped YouTube playlist image URLs with `getImageUrl(...)`. |
| `lib/Screens/YouTube/youtube_artist.dart` | Wrapped YouTube artist image URLs with `getImageUrl(...)`. |
| `lib/Helpers/mediaitem_converter.dart` | Wrapped `song['image']` with `getImageUrl(...)` and added safe fallback to `secondImage`. |
| `test/artwork_quality_test.dart` | Added 13 comprehensive unit tests validating resolution modifier, parsers, and converters. |
