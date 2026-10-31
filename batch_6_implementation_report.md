# BLACKHOLE FLUTTER — BATCH 6 IMPLEMENTATION REPORT
## YouTube Streaming, Deep Links & Sharing Integration
### Production-Minded Compatibility, Reliability, Security, and Regression Prevention

---

## 1. Executive Summary

This report documents the implementation and validation of **Batch 6** of the BlackHole Flutter maintenance project, including the **Targeted URL Validation Review**. Batch 6 focuses strictly on three deeply connected subsystems:
1. **YouTube streaming and stream resolution**
2. **Deep links and external URL handling**
3. **Incoming and outgoing sharing integration**

All modifications were applied strictly within the active maintenance worktree (`D:\My-GitHub-Projects\BlackHole-maintenance`) without modifying the immutable reference repository (`D:\My-GitHub-Projects\BlackHole`).

The build and test pipeline verified:
- **Focused Test Suite:** 27/27 tests passed in `test/batch_6_youtube_deeplink_sharing_test.dart`.
- **Full Flutter Test Suite:** 249/249 tests passed (`flutter test --reporter expanded`) with exit code 0.
- **Git Diff Hygiene:** `git diff --check` passed cleanly with exit code 0.
- **Static Analysis:** Verified baseline; all newly modified and created Batch 6 files are 100% clean of errors and warnings.
- **Final Debug APK Output:** Successfully built universal debug APK with `GRADLE_USER_HOME=D:\DevCaches\GradleUserHome` and verified against checkpoints.

---

## 2. Baseline Environment & Pre-Flight State

### 2.1 Repository & Branch State
- **Active Maintenance Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`
- **Active Git Branch:** `maintenance/build-compatibility-upgrade`
- **HEAD Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`
- **Immutable Reference Repository:** `D:\My-GitHub-Projects\BlackHole` (strictly untouched, read-only)

### 2.2 Pre-Existing Uncommitted Modifications
The working tree contained pre-existing uncommitted modifications from previously accepted Batches 1 to 5 (including Hive non-destructive recovery, storage/permission updates, notch layout handling, high-res artwork resolution, and the APK size forensic audit). All pre-existing work was preserved.

### 2.3 Toolchain Verification & Channel Reconciliation
- **Actual `flutter --version` Output:**
  ```
  Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
  Framework • revision abaf9c5237 (2 weeks ago) • 2026-10-08 09:51:21 -0700
  Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (18 days ago) • 2026-10-07 17:09:12.000Z
  Tools • Dart 3.13.5 • DevTools 2.60.0
  ```
- **Channel Reconciliation:** The actual installed Flutter channel is **stable** (revision `abaf9c5237`), confirming exact adherence to the approved toolchain specification. An earlier draft of the Batch 6 report noted "channel master" as a reporting discrepancy; this has been reconciled and corrected.
- **Java Runtime:** OpenJDK 17.0.12 (Zulu 17.52.17-CA-win64)
- **Gradle Version:** 8.14
- **Android Gradle Plugin (AGP):** 8.3.2
- **Kotlin Version:** 2.0.21
- **Gradle User Home:** `D:\DevCaches\GradleUserHome` (strictly preserved; `C:\Users\gkpsu\.gradle` was not created)

### 2.4 Android Application Identity & Manifest
- **Application ID:** `com.shadow.blackhole` (strictly preserved)
- **Version Code / Name:** `1.15.8+39` (strictly preserved)
- **Compile SDK:** 36
- **Target SDK:** 29 (strictly preserved)
- **Minimum SDK:** 21

### 2.5 Nine Preserved Dependency Overrides
All 9 approved dependency overrides remain intact in `pubspec.yaml`:
1. `receive_sharing_intent`: local path `packages/receive_sharing_intent`
2. `sqflite`: `2.4.5`
3. `sqflite_android`: `2.4.5`
4. `audiotagger`: local path `packages/audiotagger`
5. `flutter_plugin_android_lifecycle`: `2.0.35`
6. `collection`: `1.17.1`
7. `flutter_rust_bridge`: `1.81.0`
8. `http_parser`: `4.0.2`
9. `material_design_icons_flutter`: local path `packages/material_design_icons_flutter`

---

## 3. Pre-Batch 6 Checkpoint & Verification

Before modifying any source files, the approved pre-Batch 6 APK from Batch 4+5 testing was verified:
- **Baseline Checkpoint Location:** `D:\BlackHole-Checkpoints\post-batch-4-5-final-security-reviewed-20261025-213500\app-debug.apk`
- **Byte Size:** `197,251,266` bytes
- **SHA-256:** `52C01DB005D079938871E2DF91A2F66D6CF5ABEEE4C5DE4F7460565A81F5BD53`
- **Immutable Dedicated Pre-Batch 6 Checkpoint Created:** `D:\BlackHole-Checkpoints\pre-batch-6-checkpoint-20261025-231500\app-debug.apk` (197,251,266 bytes).

---

## 4. End-to-End Discovery & Existing Architecture

The investigation traced the lifecycle and data flow of external URLs, shared intents, YouTube search, and stream resolution:

```
[External URL / Android Sharesheet]
                │
                ▼
      AndroidManifest.xml
   (ACTION_VIEW / ACTION_SEND)
                │
                ├──────────────────────────────────────┐
                │ (Cold Start VIEW Intent)             │ (Sharing Plugin Stream / Initial Text)
                ▼                                      ▼
     MaterialApp.onGenerateRoute              ReceiveSharingIntent.getTextStream()
                │                             ReceiveSharingIntent.getInitialText()
                │                                      │
                │                                      ▼
                │                             handleSharedText(sharedText)
                │                                      │
                └───────────────┬──────────────────────┘
                                │
                                ▼
                    HandleRoute.handleRoute(url)
                                │
        ┌───────────────────────┴───────────────────────┐
        ▼                                               ▼
  Saavn / Spotify / Local                       YouTube URL / Video ID
                                                        │
                                                        ▼
                                                   YtUrlHandler
                                                        │
                                                        ▼
                                       YouTubeServices.formatVideoFromId()
                                                        │
                                ┌───────────────────────┴───────────────────────┐
                                ▼                                               ▼
                   1. yt.videos.streamsClient (Manifest)            2. InnerTube Android Endpoint
                                │                                               │
                                └───────────────────────┬───────────────────────┘
                                                        │
                                                        ▼
                                            YouTubeStreamCandidate
                                        (Host validation & Bitrate sorting)
                                                        │
                                                        ▼
                                                  Hive ytlinkcache
                                                        │
                                                        ▼
                                            PlayerInvoke.init() / Player
```

---

## 5. Confirmed Defects and Implemented Fixes

### 5.1 Subphase A: YouTube Streaming and Stream Resolution

#### Defect A1: InnerTube Stream Quality Inversion and Lack of Validation in `formatVideoFromInnerTube`
- **Location:** `lib/Services/youtube_services.dart:1180-1235`
- **Defect:** In `formatVideoFromInnerTube`, stream formats were appended directly without verifying `c.isValid` or sorting by bitrate. Worse, muxed video formats from `formats` were appended *after* `adaptiveFormats`. Because `quality == 'High'` selects `urls.last`, users selecting high quality received a low-bitrate muxed stream (often 96kbps or lower) rather than the high-bitrate Opus/AAC audio-only stream (160kbps).
- **Fix:** Refactored `formatVideoFromInnerTube` to collect `adaptiveFormats` and fallback `formats` into `List<YouTubeStreamCandidate>`, matching the robust logic of `fetchStreamsFromInnerTube`. Streams are validated with `c.isValid`, audio-only formats are prioritized, candidates are sorted by bitrate ascending, and `selectStreamUrls` returns `[lowUrl, highUrl]`.

#### Defect A2: Stream Candidate Inadvertently Permitting Lookalike Domains and Watch Pages
- **Location:** `lib/Services/youtube_services.dart:50-80`
- **Defect:** `YouTubeStreamCandidate.isValid` previously used substring matching (`url.contains('googlevideo.com')`) and string checks (`!url.contains('/watch?')`). This allowed potential lookalike hostnames (e.g. `googlevideo.com.evil.example` or `evilgooglevideo.com`) and did not reject watch pages lacking query parameters (`https://youtube.com/watch`).
- **Fix (Targeted URL Validation Review):**
  Replaced substring checks with strict parsed URI component validation:
  1. Enforces `Uri.tryParse(url)` with `hasAbsolutePath == true`.
  2. Enforces approved schemes (`https` and `http`).
  3. Validates hostname strictly against `host == 'googlevideo.com' || host.endsWith('.googlevideo.com')` and `host == 'youtube.com' || host.endsWith('.youtube.com')`. Lookalike hostnames (e.g. `youtube.com.evil.example`, `googlevideo.com.evil.example`, `evilgooglevideo.com`) are strictly rejected.
  4. Explicitly rejects HTML watch pages, search results, and non-stream endpoints regardless of whether query parameters are present (`/watch`, `/results`, `/playlist`, `/channel`, `/shorts`, `/feed`).
  5. Preserves all legitimate stream URL formats on `*.googlevideo.com` with signed query parameters intact.

#### Defect A3: Unescaped Query Parameters in `getSearchSuggestions`
- **Location:** `lib/Services/youtube_services.dart:495-515`
- **Defect:** `Uri.parse(baseUrl + query)` performed string concatenation without RFC-compliant percent-encoding. Queries containing special characters (`&`, `#`, `+`, spaces) resulted in malformed URIs.
- **Fix:** Converted to canonical `Uri.https`:
  ```dart
  final Uri link = Uri.https(
    'suggestqueries.google.com',
    '/complete/search',
    {
      'client': 'firefox',
      'ds': 'yt',
      'q': query,
    },
  );
  ```

#### Defect A4: Missing Playability Status Diagnostics
- **Location:** `lib/Services/youtube_services.dart:1005-1025`
- **Defect:** InnerTube responses returning HTTP 200 for unavailable, private, or age-restricted videos were dropped with a generic warning without inspecting `playabilityStatus`.
- **Fix:** Added safe inspection of `decoded['playabilityStatus']`. If status is not `'OK'`, the exact status (e.g. `'UNPLAYABLE'`, `'LOGIN_REQUIRED'`) and reason are logged without exposing tokens or cookies.

---

### 5.2 Subphase B: Deep Links and External URL Handling

#### Defect B1: Missing `youtu.be` Host in Android Manifest Intent Filters
- **Location:** `android/app/src/main/AndroidManifest.xml:123-135`
- **Defect:** The Android `ACTION_VIEW` intent filter only declared `android:host="*youtube.com"`. Standard YouTube mobile sharing uses `https://youtu.be/<id>`. When users clicked or opened `youtu.be` links in external messaging apps or browsers, Android never presented BlackHole in the App Chooser.
- **Fix:** Added `http` and `https` scheme support for `youtu.be` and `*youtu.be` alongside `*youtube.com`:
  ```xml
  <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <category android:name="android.intent.category.DEFAULT" />
      <data android:scheme="http" />
      <data android:scheme="https" />
      <data android:host="*youtube.com" />
      <data android:host="youtu.be" />
      <data android:host="*youtu.be" />
  </intent-filter>
  ```

#### Defect B2: Brittle Regex and Inability to Parse Standard YouTube URL Variants
- **Location:** `lib/Helpers/route_handler.dart:35-160`
- **Defect:** The legacy regex `RegExp(r'.*[\?\/](v|list)[=\/](.*?)[\/\?&#]').firstMatch('$url/')` failed on:
  - `https://youtu.be/<id>` (no `v=` in path)
  - `https://www.youtube.com/watch?feature=share&v=<id>` (`v` preceded by `&`)
  - `https://www.youtube.com/shorts/<id>` (no `v=`)
  - `https://music.youtube.com/watch?v=<id>`
  - Embedded URLs inside shared text (e.g. `"Check this out https://youtu.be/<id>"`)
  - Unsanitized empty parameter values
- **Fix:** Implemented `YouTubeParsedItem` and `HandleRoute.parseYouTubeUrl`:
  - Isolates URL substrings embedded in arbitrary text.
  - Parses structured URI components using `Uri.tryParse`.
  - Supports `/watch?v=`, `youtu.be/<id>`, `/shorts/<id>`, `/embed/<id>`, `/v/<id>`, and `/playlist?list=`.
  - Validates that extracted IDs are non-empty and well-formed.
  - Returns null for invalid or empty inputs without crashing.

#### Defect B3: Cold-Start Duplicate Navigation and Playback Trigger
- **Location:** `lib/main.dart:205-220` and `lib/Helpers/handle_native.dart:25-45`
- **Defect:** On cold start from an external intent, both `MaterialApp.onGenerateRoute` AND `ReceiveSharingIntent.getInitialText()` (plus `getTextStream()`) fired with the identical URL. `handleSharedText` delayed 1 second and unconditionally pushed the route onto `navigatorKey`, triggering double navigation, redundant network requests, and competing audio playback.
- **Fix:** Added a central debounce deduplication mechanism in `HandleRoute.isDuplicate(url)`. If the exact same URL is received within a 3-second debounce window, it is logged and dropped. Furthermore, `handleSharedText` was protected with input trimming and null-safe navigator retries.

#### Defect B4: Unsafe Pop and Missing Loading Feedback in `YtUrlHandler`
- **Location:** `lib/Helpers/route_handler.dart:193-245`
- **Defect:** While resolving video streams, `YtUrlHandler` returned `const SizedBox()`, providing zero visual feedback. If resolution failed, it called `Navigator.pop(context)` unconditionally, which threw an exception if `Navigator.canPop(context)` was false.
- **Fix:** Updated `YtUrlHandler` to return a transparent `Scaffold` with `Center(child: CircularProgressIndicator())`. On resolution failure, it checks `Navigator.canPop(context)` before popping and displays a user-facing `SnackBar` explaining that the stream could not be resolved.

---

### 5.3 Subphase C: Incoming and Outgoing Sharing Integration

#### Defect C1: Potential Stream URL and Private Token Leakage in Outgoing Shares
- **Location:** `lib/CustomWidgets/song_tile_trailing_menu.dart:172-190, 365-375` and `lib/Screens/Player/audioplayer.dart:274-305`
- **Defect:**
  - `Share.share(widget.data['perma_url'].toString())` shared the literal string `'null'` if `perma_url` was missing.
  - In `audioplayer.dart`, `mediaItem.extras!['perma_url'].toString()` performed an unsafe non-null assertion on `extras!`.
  - If a temporary `googlevideo.com` CDN stream URL was stored in `perma_url`, it could inadvertently be shared instead of the canonical public media page.
- **Fix:**
  - Sanitized share URLs across both trailing menus and the audio player.
  - Filtered out any URL containing `googlevideo.com`.
  - Ensured fallback to canonical public watch URL (`https://youtube.com/watch?v=$id`) for YouTube items.
  - Prevented sharing empty or `'null'` strings.
  - Replaced unsafe `extras!` assertion with null-safe navigation.

---

## 6. Files Changed and Summary of Modifications

| File | Subphase | Modifications |
| :--- | :--- | :--- |
| `android/app/src/main/AndroidManifest.xml` | B | Added `youtu.be` and `*youtu.be` hosts with `http` and `https` schemes to the `ACTION_VIEW` intent filter. |
| `lib/Services/youtube_services.dart` | A | Overhauled `YouTubeStreamCandidate.isValid` to use parsed host and path validation (rejecting lookalike domains and HTML pages); sanitized `getSearchSuggestions` with `Uri.https`; added `playabilityStatus` diagnostics; ensured bitrate-ordered stream candidate selection in `formatVideoFromInnerTube`. |
| `lib/Helpers/route_handler.dart` | B, C | Added `YouTubeParsedItem` model and `parseYouTubeUrl`; implemented `isDuplicate` debounce deduplication; hardened `handleRoute`; improved `YtUrlHandler` UI feedback and safe pop behavior. |
| `lib/Helpers/handle_native.dart` | B, C | Hardened `handleSharedText` against empty strings, added error handling and null-safe navigator fallback. |
| `lib/CustomWidgets/song_tile_trailing_menu.dart` | C | Sanitized outgoing share URLs; prevented sharing raw stream URLs or `'null'`. |
| `lib/Screens/Player/audioplayer.dart` | C | Sanitized outgoing share URLs in audio player; guarded against null extras assertions. |
| `test/batch_6_youtube_deeplink_sharing_test.dart` | A, B, C | Comprehensive unit and integration test suite (27 tests) including host parsing, lookalike rejection, queryless watch page rejection, and signed parameter preservation. |

---

## 7. Dependency State Verification

No dependencies were added, removed, or upgraded. All 9 dependency overrides remain strictly intact in `pubspec.yaml` and `pubspec.lock`.

---

## 8. Testing Strategy and Full Suite Results

### 8.1 Focused Batch 6 Test Suite
- **Command:** `flutter test test/batch_6_youtube_deeplink_sharing_test.dart --reporter expanded`
- **Result:** **27 / 27 passed** (exit code 0).
- **Targeted Test Coverage:**
  - Standard watch URLs (`?v=...`)
  - Watch URLs with query parameters before `v` (`?feature=share&v=...`)
  - Short URLs (`youtu.be/...`) and short URLs with tracking parameters (`?si=...&t=...`)
  - YouTube Shorts URLs (`/shorts/...`)
  - YouTube Music URLs (`music.youtube.com/watch?v=...`)
  - YouTube Embed and `/v/` URLs
  - YouTube Playlist URLs (`/playlist?list=...`)
  - YouTube links embedded in shared text
  - Raw URLs without scheme
  - Malformed, empty, blank, and non-YouTube URL rejection
  - Debounce deduplication of identical URLs within 3-second window
  - Processing of distinct URLs without debouncing
  - Authentic `googlevideo.com` CDN stream URL validation
  - Legitimate supported `*.googlevideo.com` subdomains with signed query parameters
  - Strict rejection of lookalike hostnames attempting substring spoofing (`youtube.com.evil.example`, `googlevideo.com.evil.example`, `evilgooglevideo.com`, etc.)
  - Rejection of HTML watch pages with or without query strings (`https://youtube.com/watch`, `watch?v=...`, `shorts/...`)
  - Rejection of search results pages with or without query parameters (`/results`, `/results?search_query=...`)
  - Rejection of non-HTTP(S) schemes (`ftp://...`, `javascript:...`, `file://...`) and malformed URLs
  - Bitrate-based ordering of low and high stream URLs
  - Audio-only prioritization over muxed video streams
  - Outgoing share URL sanitization (prevention of raw CDN URL sharing and fallback to canonical watch URLs)

### 8.2 Full Flutter Test Suite Verification
- **Command:** `flutter test --reporter expanded`
- **Total Test Files:** 14 test suites
- **Result:** **249 / 249 passed** (exit code 0).
  - Baseline tests: 222 passed
  - Batch 6 tests: 27 passed
  - Total passing: 249 passed (0 failed, 0 skipped)

### 8.3 Static Analysis
- **Command:** `flutter analyze lib test`
- **Result:** Verified baseline. All newly modified and created Batch 6 files are completely clean of errors and warnings.

### 8.4 Git Diff Check
- **Command:** `git diff --check`
- **Result:** Passed cleanly with exit code 0.

---

## 9. Final Debug APK Verification

The final debug APK was rebuilt after passing all verification gates:
- **Build Command:**
  ```powershell
  powershell -Command "[System.Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\DevCaches\GradleUserHome', 'Process'); flutter build apk --debug"
  ```
- **Build Result:** Exited with code 0 (`√ Built build\app\outputs\flutter-apk\app-debug.apk in 127.9s`).
- **Primary Build Artifact:**
  - **Path:** `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk`
  - **Byte Size:** `197,266,497` bytes (~188.13 MB)
  - **SHA-256:** `DDE066FCF851EED55E55B51F5210D01C331627034E7C01E5ABE44E73A35A2B25`

### 9.1 Checkpoint Integrity
- **Updated Dedicated Checkpoint Location:**
  `D:\BlackHole-Checkpoints\post-batch-6-final-targeted-review-20261025-234500\app-debug.apk`
  - **Byte Size:** `197,266,497` bytes
  - **SHA-256:** `DDE066FCF851EED55E55B51F5210D01C331627034E7C01E5ABE44E73A35A2B25`
- **Preserved Prior Checkpoints:**
  - `post-batch-6-final-20261025-233200\app-debug.apk` (`197,265,381` bytes, SHA-256 `5744A8D05D93A1DBAE6FBC4224CDEB290391EDF9AD804CA306B07ADFCB20EF86`)
  - `pre-batch-6-checkpoint-20261025-231500\app-debug.apk` (`197,251,266` bytes, SHA-256 `52C01DB005D079938871E2DF91A2F66D6CF5ABEEE4C5DE4F7460565A81F5BD53`)
  - `post-batch-4-5-final-security-reviewed-20261025-213500\app-debug.apk` (`197,251,266` bytes, SHA-256 `52C01DB005D079938871E2DF91A2F66D6CF5ABEEE4C5DE4F7460565A81F5BD53`)

---

## 10. Known Limitations

1. **Remote YouTube Service Fluctuations:**
   YouTube periodically modifies InnerTube client requirements and bot-detection heuristics. While BlackHole implements a dual-path resolver (`YoutubeExplode` manifest parsing + InnerTube Android mobile player fallback), live streaming availability depends on remote YouTube servers.
2. **Third-Party Domain Verification:**
   `android:autoVerify` cannot be claimed for `youtube.com` or `youtu.be` because the developer does not control Google's `assetlinks.json`. The Android OS displays the standard App Chooser dialog when handling external links.
3. **Age-Restricted / Login-Required Content:**
   Content requiring user authentication on YouTube cannot be streamed anonymously without OAuth credentials, which are intentionally out of scope to avoid credential leakage.

---

## 11. Safeguard Confirmations

- [x] No `git reset`, `git clean`, `git stash`, `git checkout`, `git switch`, `git restore`, `git commit`, `git push`, `git merge`, or `git rebase` commands were executed.
- [x] Immutable reference repository (`D:\My-GitHub-Projects\BlackHole`) was not modified in any way.
- [x] All 9 dependency overrides remain intact.
- [x] Target SDK remains strictly 29; compile SDK 36; min SDK 21.
- [x] Application ID remains `com.shadow.blackhole`; version `1.15.8+39`.
- [x] No credentials, private tokens, or paid APIs were added.
- [x] `GRADLE_USER_HOME=D:\DevCaches\GradleUserHome` was strictly enforced.
- [x] Batch 7 (audio-engine/background-service refactoring) was **NOT** started.

---

## 12. Physical-Device Acceptance Checklist

Please perform the following physical-device acceptance checks with the final APK:

```powershell
adb install -r "D:\BlackHole-Checkpoints\post-batch-6-final-targeted-review-20261025-234500\app-debug.apk"
```

- [ ] **Installation & Startup:** Confirm normal launch, and verify existing settings, favorites, and playlists are preserved without data clearing.
- [ ] **YouTube Search & Playback:** Search for a normal public YouTube track via YouTube Search. Select a track and confirm playback starts with valid audio.
- [ ] **Stream Quality Toggle:** Switch stream quality between Low and High in Settings, and verify successful playback.
- [ ] **Short Link Deep Linking (`youtu.be`):** Tap a `https://youtu.be/<id>` link from WhatsApp, Chrome, or Notes. Verify BlackHole appears in the chooser and opens the track.
- [ ] **Standard Link Deep Linking (`youtube.com`):** Tap a `https://www.youtube.com/watch?feature=share&v=<id>` link and verify smooth resolution.
- [ ] **Foreground/Background Intent:** Open a YouTube deep link while BlackHole is already running. Confirm only a single track resolution and playback starts (no double playback).
- [ ] **Sharesheet Integration:** From the YouTube app, tap Share -> BlackHole. Confirm successful resolution and playback.
- [ ] **Outgoing Share Verification:** Tap the Share button in the player or song list. Verify the shared link is a canonical public link (`https://youtube.com/watch?v=...`) and NOT a `googlevideo.com` stream link.
- [ ] **Regression Sanity Check:** Play local music, verify background notification controls, and rotate device to landscape to confirm the notch layout remains unobstructed.
