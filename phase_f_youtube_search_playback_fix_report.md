# BLACKHOLE — PHASE F.1: YOUTUBE SEARCH METADATA & PLAYBACK HOTFIX REPORT
## Investigation, Root Cause Analysis, Remediation, Automated Test Suite, Static Analysis & Checkpoint Verification

**Engineering Role:** Senior Flutter Engineer · YouTube Integration Specialist · Media Playback Engineer · API/Data-Mapping Specialist  
**Application:** BlackHole Music Player  
**Application ID:** `com.shadow.blackhole`  
**Version:** `1.15.8+39`  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Commit (HEAD):** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Candidate Checkpoint Directory:** `D:\BlackHole-Checkpoints\post-phase-f-youtube-playback-fix-20261031-202101`  
**Candidate Checkpoint APK:** `D:\BlackHole-Checkpoints\post-phase-f-youtube-playback-fix-20261031-202101\app-debug.apk`  
**Candidate APK SHA-256:** `BE2F23D42F429E5620BE6A9F6CA1CACDCA2AE2D64FE9602DF3276185A3348BBA`  
**Candidate APK Byte Size:** `197,236,083 bytes` (~188.10 MB)  
**Date & Time:** `2026-10-31 20:21:01 IST`  

---

## 1. Executive Summary

Following physical-device acceptance testing of candidate `D:\BlackHole-Checkpoints\post-phase-f-security-final-20261030-003224\app-debug.apk` (SHA-256: `D81C0A7FC89ED2EB5F54C7DF3CD6E10F24A87CB2D8ED5B15975FE514A4AC6E50`), the owner reported that while the **YT Music tab** worked properly, the **YouTube tab** presented two specific defects upon searching (e.g. for query `dhruv`):
1. **Metadata Display Bug:** Result thumbnails and titles loaded correctly, but every result subtitle displayed the literal string `"null"`.
2. **Playback Failure:** Tapping a YouTube search result failed to start audio playback.

A rigorous investigation traced the exact execution paths, identified both root causes, and applied surgical fixes across data mapping, media conversion, stream resolution, and UI rendering without regressing YT Music, JioSaavn, local playback, or any Phase F security hardening.

---

## 2. Confirmed Root Causes

### Root Cause 1: Literal `"null"` Subtitle Display
- **Search Fallback Activation:** When executing a search on YouTube via `fetchSearchResults(query)`, `yt.search.search(query)` in `youtube_explode_dart` failed because of recent YouTube web scraper changes (`FormatException: Invalid radix-10 number (at character 1) Streamed`), which correctly activated the `searchInnerTube` fallback endpoint.
- **Missing Field Mapping in InnerTube Model:** The `searchInnerTube` method parsed `ownerText` into `author` and `album`, but **omitted** the `'subtitle'` key completely from the resulting `Map`.
- **Unsafe String Coercion in UI Tile:** In `lib/Screens/YouTube/youtube_search.dart`, the `ListView.builder` rendered subtitles using:
  ```dart
  subtitle: Text(section['items'][idx]['subtitle'].toString())
  ```
  Because `section['items'][idx]['subtitle']` was `null`, Dart's `null.toString()` evaluated to the literal string `"null"`.

### Root Cause 2: Playback Failure Upon Result Selection
- **Formatted Duration Incompatibility:** YouTube InnerTube search responses return duration as formatted strings such as `"20:03"` or `"1:15:30"` in `lengthText`. `searchInnerTube` and `formatVideoFromInnerTube` populated this formatted string directly into `'duration'`.
- **Unhandled `FormatException` in Audio Queue Setup:** When the user tapped the search result tile in `youtube_search.dart`, `YouTubeServices().formatVideoFromId` resolved a valid googlevideo audio stream URL and returned the song dictionary. Next, `PlayerInvoke.init()` called `setValues()`, which invoked:
  ```dart
  MediaItemConverter.mapToMediaItem(songMap)
  ```
  Inside `MediaItemConverter.mapToMediaItem`:
  ```dart
  duration: Duration(
    seconds: int.parse(song['duration'].toString()),
  )
  ```
  Calling `int.parse("20:03")` threw an uncaught `FormatException: Invalid radix-10 number (at character 1) 20:03`.
- **Playback Pipeline Abort:** Because of this unhandled exception, `setValues` crashed before calling `updateNplay()`. As a result, `audioHandler.updateQueue()` and `audioHandler.play()` were never called, leaving the player idle and failing to start playback.

---

## 3. Implemented Corrections

### 1. `lib/Helpers/mediaitem_converter.dart`
- Replaced raw `int.parse()` with resilient duration parsing using `FormatResponse.parseDuration(song['duration'])`.
- Applied identical parsing to both `mapToMediaItem()` and `downMapToMediaItem()`:
  ```dart
  duration: Duration(
    seconds: (int.tryParse(FormatResponse.parseDuration(song['duration'])) ?? 0) > 0
        ? (int.tryParse(FormatResponse.parseDuration(song['duration'])) ?? 0)
        : 180,
  ),
  ```
- Ensures that any duration format (`"20:03"`, `"1:15:30"`, `"180"`, `240`, `null`, `""`, or `"null"`) is safely converted into integer seconds without ever throwing `FormatException`.

### 2. `lib/Services/youtube_services.dart`
- **InnerTube Search Result Mapping (`searchInnerTube`):**
  - Added `'type': 'Video'`, `'channel': authorFallback`, `'author': authorFallback`, and `'artist': authorFallback`.
  - Added `'subtitle': subtitle` using clean author name with fallback to `'YouTube Video'`.
  - Converted raw duration (`"20:03"`) to integer seconds via `FormatResponse.parseDuration(rawDuration)` into `'duration'`, while preserving `'rawDuration'`.
  - Extracted view counts and published timestamps.
- **Stream Formatting & Cache Mapping (`formatVideo`, `formatVideoFromInnerTube`):**
  - Ensured `'subtitle'` is never `null` or `'null'`, falling back to `video.author` / `artist` or `'YouTube Video'`.
  - Normalized duration to integer seconds via `FormatResponse.parseDuration`.
  - Added `'channel'` and `'author'` keys across all format branches.

### 3. `lib/Screens/YouTube/youtube_search.dart`
- **Safe Subtitle Resolver (`_formatSubtitle`):**
  - Added robust fallback helper inspecting `'subtitle'`, `'artist'`, `'channel'`, `'author'`, `'uploader'`, and `'description'`.
  - Sanitizes against literal `"null"` or `"Null"` strings; guarantees fallback to `'YouTube Video'`.
- **Case-Insensitive Item Type Matching:**
  - Expanded `trailing` and `onTap` checks to support `'Song'`, `'Video'`, `'song'`, and `'video'`.
- **Awaited Playback Initialization:**
  - Added `await PlayerInvoke.init()` before navigating to `/player`.

### 4. `lib/Screens/Player/audioplayer.dart`
- Hardened song information dialogs (lines 325-326 and 1841-1842) by parsing `details['duration']` via `FormatResponse.parseDuration` and formatting cleanly as `mm:ss` with zero-padding (e.g. `20:03`).

### 5. `lib/CustomWidgets/song_tile_trailing_menu.dart`
- Added null-safety check before calling `MediaItemConverter.mapToMediaItem(songMap)`.

### 6. `lib/Screens/YouTube/youtube_home.dart`
- Protected carousel subtitle text from ever rendering literal `"null"`.

### 7. `lib/Services/player_service.dart`
- Hardened desktop offline playback duration parsing using `FormatResponse.parseDuration`.

---

## 4. Source Files Modified

| File | Changes Made |
| :--- | :--- |
| `lib/Helpers/mediaitem_converter.dart` | Duration parsing via `FormatResponse.parseDuration`; safe integer seconds fallback |
| `lib/Services/youtube_services.dart` | InnerTube search subtitle, author, duration conversion, type mapping; cache formatting |
| `lib/Screens/YouTube/youtube_search.dart` | `_formatSubtitle` fallback helper; case-insensitive itemType matching; awaited `PlayerInvoke.init` |
| `lib/Screens/Player/audioplayer.dart` | Duration formatting safety in song info dialogs |
| `lib/CustomWidgets/song_tile_trailing_menu.dart` | Null guard on `songMap` prior to `MediaItemConverter` invocation |
| `lib/Screens/YouTube/youtube_home.dart` | Subtitle fallback protection against literal `"null"` |
| `lib/Services/player_service.dart` | Added `FormatResponse` import and resilient duration parsing |
| `test/youtube_search_playback_test.dart` | **New:** 16 automated unit/widget tests for YouTube search metadata, URLs, and playback |

---

## 5. Separation of YT Music & YouTube

- **YT Music tab:** Uses `YtMusicService().search()`, returning categorized sections (`Songs`, `Videos`, `Albums`, `Artists`). Its data pipeline, metadata mapping, and playback paths remain completely untouched.
- **YouTube tab:** Uses `YouTubeServices().fetchSearchResults()`, returning `'Videos'`. Its data models now contain complete metadata (`title`, `subtitle`, `artist`, `duration`, `image`, `url`, `perma_url`).
- Both tabs operate independently and preserve choice-chip state without crosstalk.

---

## 6. Automated Test Suite Results

A dedicated test suite was created in `test/youtube_search_playback_test.dart`:
- **Search Result Metadata & Fallbacks:**
  - Channel name properly rendered in subtitle.
  - Missing subtitle falls back to artist/channel.
  - Missing channel falls back to `'YouTube Video'`.
  - Literal string `"null"` sanitized to `'YouTube Video'`.
  - Formatted duration strings (`"20:03"`, `"1:15:30"`, `"180"`, `240`) safely converted.
  - Video title and thumbnails preserved.
- **Video Identification & URL Security Validation:**
  - Canonical YouTube watch URL parsed (`?v=qWjfDow0xGQ`).
  - Shortened `youtu.be` URL parsed.
  - Deceptive hostnames rejected (`fakeyoutube.com`, `youtube.com.attacker.com`).
  - `YouTubeStreamCandidate` validates legitimate `.googlevideo.com` streams and rejects HTML watch URLs.
- **Playback MediaItem Conversion Resilience:**
  - `mapToMediaItem` handles `"20:03"` duration without throwing `FormatException`.
  - `mapToMediaItem` handles `"1:15:20"` podcast duration.
  - `mapToMediaItem` handles `null`, `""`, and `"null"` duration safely.
  - `downMapToMediaItem` handles formatted and null durations.
- **UI Subtitle Rendering:**
  - Widget tests verify `ListTile` renders sanitized subtitles and never displays `"null"`.

### Test Execution Commands & Results
```powershell
flutter test test/youtube_search_playback_test.dart
# Result: 16 passed, 0 failed (Code 0)

flutter test --reporter expanded
# Result: 364 passed, 0 failed (Code 0)
```
**Total Tests Passed:** 364 / 364 (100% pass rate, zero failures).

---

## 7. Static Analysis & Git Integrity

### `flutter analyze lib test`
```
Analyzing 2 items...
381 issues found (0 errors, 1 warning in localization, 380 baseline linter info diagnostics).
```
- **Errors:** 0 errors.
- **Warnings/Info:** Identical to accepted Phase F baseline.

### `git diff --check`
```
warning: in the working copy of 'android/gradle/wrapper/gradle-wrapper.properties', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'lib/CustomWidgets/miniplayer.dart', LF will be replaced by CRLF the next time Git touches it
Exit Code: 0
```
- No trailing whitespaces, whitespace errors, or conflict markers.

---

## 8. Candidate Checkpoint & Delivery Artifact

| Property | Value |
| :--- | :--- |
| **Checkpoint Directory** | `D:\BlackHole-Checkpoints\post-phase-f-youtube-playback-fix-20261031-202101` |
| **Candidate APK Path** | `D:\BlackHole-Checkpoints\post-phase-f-youtube-playback-fix-20261031-202101\app-debug.apk` |
| **File Size** | `197,236,083 bytes` (~188.10 MB) |
| **SHA-256 Checksum** | `BE2F23D42F429E5620BE6A9F6CA1CACDCA2AE2D64FE9602DF3276185A3348BBA` |
| **Package ID** | `com.shadow.blackhole` |
| **Version Code / Name** | `39` / `1.15.8` |
| **SDK Versions** | `minSdkVersion: 24`, `targetSdkVersion: 29`, `compileSdkVersion: 36` |
| **Toolchain Preserved** | Flutter `3.47.7` stable / Dart `3.13.5` / Java 17 LTS / Gradle `8.14` / AGP `8.3.2` / Kotlin `2.0.21` |
| **Dedicated Gradle Home** | `D:\DevCaches\GradleUserHome` |
| **Protected Invariants** | 9 dependency overrides & 3 local compatibility packages intact; Phase F security intact |

---

## 9. Physical-Device Acceptance Instructions

> [!IMPORTANT]
> **This candidate is ready for physical-device acceptance.**
>
> Please install `D:\BlackHole-Checkpoints\post-phase-f-youtube-playback-fix-20261031-202101\app-debug.apk` on your Android device and perform the following verification:
>
> 1. **YouTube Search:** Search for `dhruv` in the search bar. Switch to the **YouTube** tab.
> 2. **Verify Metadata:** Confirm video thumbnails and titles load, and that result subtitles display the channel name (e.g. `Dhruv Rathee`) instead of literal `"null"`.
> 3. **Verify Playback:** Tap the first result (`How Indian Media BRAINWASHES You!`). Confirm that the player opens and audio playback begins immediately.
> 4. **Test Second Video:** Select a second YouTube search result and confirm playback starts cleanly.
> 5. **Verify YT Music Tab:** Switch to the **YT Music** tab for the same query. Confirm music results load and play correctly as before.
> 6. **Background & Notification Controls:** Verify notification controls and lock-screen playback work for YouTube tracks.
> 7. **Regression Check:** Verify JioSaavn, local songs, and Downloads playback remain fully operational.

