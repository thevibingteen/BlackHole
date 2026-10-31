# BLACKHOLE REVIVAL — POST-BATCH-2 UI, IMAGE LOADING & LYRICS IMPROVEMENTS
## Final Targeted Fixes and Verification Report

**Date:** 2026-10-25  
**Application:** BlackHole Music Player (`com.shadow.blackhole`, `v1.15.8+39`)  
**Workspace:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Baseline Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Authorised Scope:** Targeted post-Batch-2 fixes from maintainer manual hardware testing (Drawer header in dark mode, Song artwork blank placeholder delays, Lyrics engine discovery & fallback pipeline).  

---

## 1. Executive Summary

Following manual hardware testing of the Phase D2 Batch 2 debug APK, the maintainer reported three distinct regressions/friction points:
1. **Issue A (Drawer Header in Dark Mode):** The navigation drawer header appeared dark, blurry, vertically misaligned, and missing the application version label (`v1.15.8`) that was clearly visible in light mode.
2. **Issue B (Artwork Placeholders & Loading Delays):** Song posters and album artwork displayed blank placeholder images (`assets/cover.jpg`) for several seconds before rendering on Home and song-list screens.
3. **Issue C (Lyrics Availability):** The lyrics engine frequently displayed "Lyrics not available" even for popular songs with verified lyrics across external providers.

All three issues have been thoroughly investigated, root-caused, and surgically resolved without altering the application visual design language or introducing breaking dependency updates. All 17 new focused regression tests and all existing test suites pass, static analysis remains identical to the established project baseline, and a verified fresh debug APK has been produced.

---

## 2. Protected Workspace & Git Integrity

- **Original repository strictly read-only:** `D:\My-GitHub-Projects\BlackHole` was inspected and kept untouched.
- **Maintenance worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance` on branch `maintenance/build-compatibility-upgrade`.
- **Dependencies preserved:** `pubspec.yaml` and `pubspec.lock` were not modified. No new packages were added. `cached_network_image` remained at `^3.4.1`, `palette_generator` at `^0.3.3+7`, and `flutter_displaymode` at `^0.7.0`.
- **Whitespace and hygiene:** `git diff --check` executed with clean exit code 0 across all modified files.

---

## 3. Issue A — Dark Mode Navigation Drawer Header Correction

### Root Cause Analysis
1. **Pixel Density & Contrast Deficit:** In dark mode, `home.dart` used `assets/header-dark.jpg`. Visual inspection and pixel histogram analysis revealed that `assets/header-dark.jpg` is an intensely dark, crushed grayscale image with maximum pixel luminance of only 65/255 (mean luminance ~32/255). When passed through the existing `ShaderMask` (linear gradient from `0.8` opacity at top to `0.1` opacity at bottom with `BlendMode.dstIn`) overlaid on a dark surface, the header image effectively collapsed into a dark, muddy rectangle appearing blurry and incomplete.
2. **Missing Version Label & Text Color Fallback:**
   - In `_HomePageState`, `appVersion` was declared as a field (`String? appVersion;`) and fetched asynchronously in `PackageInfo.fromPlatform()`, but was never wrapped in `if (mounted) setState(() { appVersion = info.version; });`. Consequently, `appVersion` remained `null` on the initial frame and was not updated on rebuilds.
   - The version string in `RichText` relied on `appVersion == null ? const SizedBox() : TextSpan(...)`. Because `appVersion` remained `null`, the second line was never rendered.
   - Without the version line, the single "BlackHole" title line shifted downward due to `titlePadding: const EdgeInsets.only(bottom: 40.0)`.
   - In dark mode, `RichText` lacked an explicit `color: Colors.white` override, allowing theme-dependent inheritance which further degraded contrast against dark backgrounds.

### Implementation Details
- **File Modified:** [`lib/Screens/Home/home.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Home/home.dart)
- **Immediate State Initialization:** Initialized `appVersion` synchronously at field declaration using `Hive.box('settings').get('appVersion')?.toString() ?? '1.15.8'` so the version label is immediately present on the very first frame without awaiting an async platform channel.
- **Async Synchronization:** Updated `initState()` and `checkVersion()` to asynchronously fetch `PackageInfo.fromPlatform()`, persist the value to `Hive.box('settings').put('appVersion', ...)` and call `if (mounted) setState(() { appVersion = info.version; });`.
- **Header Asset Consolidation:** Changed the drawer `SliverAppBar` background image in both light and dark themes to use `'assets/header.jpg'`. `'assets/header.jpg'` contains high-dynamic-range artwork with crisp neon accents that renders vibrantly through the `ShaderMask` in both light and dark modes.
- **High-Contrast Text Styling:** Enforced explicit `color: Colors.white` on both the "BlackHole" title `TextStyle` (`fontSize: 30.0, fontWeight: FontWeight.w600`) and the version `TextSpan` (`fontSize: 7.0, color: Colors.white`).
- **Layout Preservation:** Preserved exact drawer dimensions, bottom title padding (`40.0`), drawer items, and routing.

---

## 4. Issue B — Song Artwork Delays & Blank Placeholders

### Root Cause Analysis
1. **Unbounded Full-Resolution Bitmaps:** In `song_list.dart`, `horizontal_albumlist.dart`, `miniplayer.dart`, and `image_card.dart`, `CachedNetworkImage` was instantiated without `memCacheWidth` or `memCacheHeight`. Each 500x500 image decoded to an uncompressed 1 MB RGBA bitmap in RAM. Loading a playlist of 50 songs forced 50 MB into the Flutter image cache, causing premature memory eviction, cache thrashing, and repetitive decoding on scroll.
2. **Missing Viewport Prefetching:** In `song_list.dart` and `saavn.dart`, images were loaded purely on-demand as items scrolled into the viewport. When a user opened a playlist or home section, all 8–10 visible cards simultaneously fired uncached network requests.
3. **Cache Key Divergence:** `song_list.dart` built image URLs using `entry["image"].replaceAll('http:', 'https:')`, whereas `saavn.dart` and other components used `getImageUrl(...)` (which canonicalizes Saavn image dimensions, e.g. replacing `150x150` with `500x500`). As a result, the same track viewed on the Home screen and in a Playlist had different cache keys and could not share disk or memory cache.
4. **Perceived Lag from Fade Transition:** The default `fadeInDuration` in `CachedNetworkImage` is 1000 ms, creating an artificial 1-second delay even after bytes arrived from network or disk.

### Implementation Details
- **Files Modified:**
  - [`lib/Screens/Common/song_list.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Common/song_list.dart)
  - [`lib/Screens/Home/saavn.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Home/saavn.dart)
  - [`lib/CustomWidgets/miniplayer.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/miniplayer.dart)
  - [`lib/CustomWidgets/horizontal_albumlist.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/horizontal_albumlist.dart)
  - [`lib/CustomWidgets/horizontal_albumlist_separated.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/horizontal_albumlist_separated.dart)
  - [`lib/CustomWidgets/image_card.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/image_card.dart)
- **URL Canonicalization:** Standardized all image URL generation onto `getImageUrl(url)` so identical tracks share the identical cache key across Home, Search, Playlists, Song Lists, and the Miniplayer.
- **Memory Decoding Bounds:** Added explicit decode bounds:
  - `memCacheWidth: 150`, `memCacheHeight: 150` for thumbnail lists and the miniplayer (reducing RAM per image from ~1.0 MB to ~90 KB).
  - `memCacheWidth: 300`, `memCacheHeight: 300` for cards and horizontal album carousels.
  - `maxWidthDiskCache: 500`, `maxHeightDiskCache: 500` to prevent oversized disk cache entries.
- **Snappy Transitions:** Reduced `fadeInDuration` from the default 1000 ms to `const Duration(milliseconds: 200)` for immediate visual appearance upon arrival.
- **Bounded Viewport Prefetching:**
  - In `song_list.dart`, added `_prefetchThumbnails(List songs, [int maxCount = 10])`. Upon data arrival in `songs`, `album`, `playlist`, `mix`, and `show` branches, the first 10 thumbnails are primed using `precacheImage(CachedNetworkImageProvider(url), context)` via `addPostFrameCallback`.
  - In `saavn.dart`, added `_prefetchHomeThumbnails()` bounded to 10 items across top sections (`new_trending`, `top_playlists`, `new_albums`, `charts`), executed on initial launch when cached data exists.
- **Limitations:** Prefetching is strictly bounded to the initial 10 items per screen to prevent excessive bandwidth usage on metered mobile data connections.

---

## 5. Issue C — Lyrics Discovery & Source Fallback Pipeline

### Root Cause Analysis
1. **The Boolean Type Mismatch Bug:** In `lib/Screens/Player/audioplayer.dart` (lines 1291 and 1328) and `lib/Services/download.dart` (line 480), the code evaluated:
   ```dart
   saavnHas: widget.mediaItem.extras?['has_lyrics'] == 'true'
   ```
   JioSaavn API responses return `has_lyrics` as a boolean (`true`), not a string (`'true'`). In Dart, `true == 'true'` evaluates to `false`. Consequently, JioSaavn's official lyrics API was **never invoked**, even when lyrics were guaranteed to exist on JioSaavn.
2. **Dead Heroku Endpoint:** `getSpotifyLyricsFromId` pointed to `spotify-lyric-api.herokuapp.com`. Free Dynos on Heroku were deprecated and turned off in late 2022; this endpoint unconditionally returned 404/503.
3. **Multi-Artist Track Mismatches on LRCLIB:**
   - Previous logic used `cleanArtistName(artist)` which split on commas and returned only the first token: `artist.split(',').first.trim()`.
   - On Indian and collaborative music tracks, the first token is frequently the lyricist or music composer (e.g. `Sayeed Quadri, Pritam, KK` -> `Sayeed Quadri`).
   - LRCLIB catalogues tracks under the performing singer (e.g. `KK` or `Pritam`), causing exact lookup (`/api/get`) to return 404.
4. **Missing Informative User-Agent:** LRCLIB's official API documentation mandates an informative `User-Agent` (`AppName vX.Y (URL)`). The generic `BlackHole/1.0` was subject to edge filtering or rate limits.
5. **No Negative Caching or Request Deduplication:** Rapid repeated navigation or track changes caused bursts of redundant network requests for tracks known to have no lyrics.
6. **Stale Response Race Condition:** When a user skipped songs quickly, a delayed network response for Track A could resolve after Track B started playing, overwriting Track B's lyrics with Track A's lyrics.

### Implementation Details
- **Files Modified:**
  - [`lib/Helpers/lyrics.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/lyrics.dart)
  - [`lib/Screens/Player/audioplayer.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Player/audioplayer.dart)
  - [`lib/Services/download.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart)
- **Boolean Check Correction:** Fixed `has_lyrics` check in both `audioplayer.dart` and `download.dart`:
  ```dart
  saavnHas: widget.mediaItem.extras?['has_lyrics'] == true ||
      widget.mediaItem.extras?['has_lyrics'] == 'true'
  ```
- **Metadata Propagation:** Passed `album: widget.mediaItem.album` and `duration: widget.mediaItem.duration?.inSeconds` into `Lyrics.getLyrics(...)`.
- **LRCLIB Compliant User-Agent:** Configured header:
  ```dart
  'User-Agent': 'BlackHole v1.15.8 (https://github.com/Sangwan5688/BlackHole)'
  ```
- **Multi-Artist Candidate Extraction:** Implemented `extractArtistCandidates(String artist)` which decomposes artist strings across separators (`,`, `&`, `/`, `|`, `feat.`, `ft.`, `with`) and returns individual artists as well as the composite string.
- **LRCLIB Multi-Stage Lookup & Candidate Ranking:**
  - **Stage 1 (Exact Lookup `/api/get`):** Queries `/api/get` sequentially for top artist candidates with `track_name`, `artist_name`, `album_name`, and `duration`. If 404 occurs with `album_name`, immediately retries without `album_name` (handling differences in album edition naming).
  - **Stage 2 (Search Fallback `/api/search`):** If exact lookup fails, searches `/api/search?q=...`. Evaluates returned results against candidate artists, tracks, and verifies duration within a $\pm$15-second tolerance. Rejects candidates with $>30$-second duration discrepancies.
  - **Rate Limiting (429):** Reads `Retry-After` header and returns gracefully without crashing or throwing.
- **Persistent & In-Memory Caching:**
  - **Persistent Hive Cache:** Stores successful plain and synced lyrics in `Hive.box('cache')` keyed by `lyrics_$id` or normalized `lyrics_${title}_${artist}`.
  - **In-Flight Request Deduplication:** Tracks ongoing futures in `_inFlightRequests` so concurrent requests for the same track share a single network call.
  - **Short-Lived Negative Cache:** Tracks empty results in `_negativeCache` with a 10-minute expiry to prevent request storms. Transient network socket errors do not trigger negative caching.
- **Stale Response Protection:** In `audioplayer.dart`, guarded lyrics callbacks with:
  ```dart
  if (!mounted || widget.mediaItem.id != value['id']) {
    done.value = true;
    return;
  }
  ```
- **Testing Hook:** Added `Client? customClient` and optional `client` parameters to all retrieval methods to enable deterministic unit testing without live network calls.

---

## 6. Automated Test Results

### 1. Focused Post-Batch-2 Regression Test Suite
**Command:** `flutter test test/post_batch_2_fixes_test.dart`  
**Status:** **PASSED (17/17 tests passing, 0 failures)**

| # | Test Group | Description | Result |
|---|---|---|---|
| 1 | Drawer Header | Header image asset path is uniform `assets/header.jpg` | **PASS** |
| 2 | Drawer Header | Version label formatting preserves `v`-prefix and handles fallbacks | **PASS** |
| 3 | Drawer Header | Header `RichText` renders title and version with white text | **PASS** |
| 4 | Artwork Caching | `getImageUrl` converts HTTP to HTTPS and preserves resolution | **PASS** |
| 5 | Artwork Caching | `getImageUrl` handles null and empty URLs gracefully | **PASS** |
| 6 | Artwork Caching | Prefetch slicing is bounded to prevent unbounded requests | **PASS** |
| 7 | Artwork Caching | Artwork memory cache decoding bounds protect heap (`150x150`, `300x300`) | **PASS** |
| 8 | Lyrics Pipeline | `cleanSongTitle` removes redundant brackets and metadata tags | **PASS** |
| 9 | Lyrics Pipeline | `extractArtistCandidates` parses multi-artist strings correctly | **PASS** |
| 10 | Lyrics Pipeline | `isHtmlOrChallenge` detects HTML tags and Cloudflare/bot challenges | **PASS** |
| 11 | Lyrics Pipeline | LRCLIB exact lookup succeeds and returns synced LRC lyrics | **PASS** |
| 12 | Lyrics Pipeline | LRCLIB exact lookup falls back to search and ranks candidates by duration | **PASS** |
| 13 | Lyrics Pipeline | LRCLIB 429 rate limit is handled gracefully without crashing | **PASS** |
| 14 | Lyrics Pipeline | LRCLIB network timeout/error is handled without crashing | **PASS** |
| 15 | Lyrics Pipeline | Stale lyrics response guard ignores responses for previous track | **PASS** |
| 16 | Lyrics Pipeline | In-flight deduplication shares single request for identical track query | **PASS** |
| 17 | Lyrics Pipeline | Hive cache hit reuses cached lyrics without issuing network request | **PASS** |

### 2. Full Regression Test Suite Execution
- `test/batch_2_modernisation_test.dart`: **9/9 PASS**
- `test/download_bug_fixes_test.dart`: **10/10 PASS**
- `test/playlist_header_test.dart`: **10/10 PASS**
- `test/radio_test.dart`: **10/10 PASS**
- `test/speed_test.dart`: **7/7 assertions PASS** (subject to the known test runner isolate cleanup timeout noted in baseline).

**Total Test Assertions Passed:** **63/63 active assertions** across test suites.

---

## 7. Static Analysis & Baseline Comparison

**Command:** `flutter analyze lib test`  
**Execution Time:** 6.9s  
**Total Issues:** 342 diagnostics (all existing info/deprecation notices across codebase)

### Error Comparison
- **Baseline Error Count:** 1 pre-existing error at [`lib/Helpers/format.dart:727`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/format.dart#L727) (`A value of type 'Object?' can't be assigned to a variable of type 'List<dynamic>'`).
- **Post-Fix Error Count:** Exactly 1 error (the identical pre-existing baseline error in `format.dart:727`).
- **New Errors Introduced:** **0**
- **New Warnings Introduced:** **0**
- **New Lints in Modified Files:** **0**

---

## 8. Build Verification & APK Deliverable

The fresh debug APK was built using the canonical project toolchain without modifying Gradle or dependency configurations.

**Command:** `flutter build apk --debug`  
**Build Time:** 63.2s  
**Exit Code:** 0  

### APK Artifact Details
- **Relative Path:** `build/app/outputs/flutter-apk/app-debug.apk`
- **Absolute Path:** `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk`
- **File Size:** `197,217,008 bytes` (`188.08 MB`)
- **Build Timestamp:** `2026-10-25 01:57:15`
- **SHA-256 Checksum:** `9d04ca58c0f1434ec11c7e8baf739dd467940e5965125b1cd994f7e337edb6ca`

---

## 9. Outstanding Limitations & Recommended Manual Hardware Testing

Because Antigravity strictly operates under the **NO EMULATOR** constraint, visual and audio playback verification must be conducted by the maintainer on physical Android hardware.

### Recommended Manual Hardware Test Checklist:
1. **Drawer Header in Dark Mode:**
   - Launch app with device theme set to Dark Mode.
   - Open navigation drawer: verify `assets/header.jpg` neon background is crisp and bright, title reads "BlackHole", and version label reads "v1.15.8" in clean white text.
   - Switch device theme to Light Mode: verify drawer header remains clear and properly aligned.
2. **Artwork Placeholders & Scrolling Performance:**
   - Open Home screen and navigate through "New & Trending", "Top Playlists", and "Charts".
   - Verify initial posters render within milliseconds without displaying persistent blank placeholders.
   - Open a long playlist (e.g. 50+ songs) and fling scroll: verify memory consumption remains stable without crash or stutter.
3. **Lyrics Discovery & Synchronisation:**
   - Play a popular Bollywood/collaborative track (e.g. tracks by Arijit Singh, Pritam, KK): verify synced or plain lyrics load from LRCLIB or JioSaavn.
   - Rapidly skip through 5 tracks in the Now Playing queue: verify lyrics for previous tracks do not flash or overwrite the current song.
   - Disconnect network while playing a song whose lyrics were previously fetched: verify lyrics render instantly from Hive cache.

---

## 10. Mandatory Stop Condition

This targeted bug fix task is complete. No dependency upgrades were performed, no changes outside the three authorized issues were made, and Phase D2 Batch 3 has **not** been started.

**Awaiting maintainer manual testing and formal review before any further phase authorization.**
