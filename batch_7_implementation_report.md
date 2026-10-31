# BlackHole Flutter Maintenance — Batch 7 Implementation Report
## Phase D: Audio Engine, Playback Reliability & Background Services

**Date:** 2026-10-26  
**Active Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Reference Repository (Strictly Read-Only):** `D:\My-GitHub-Projects\BlackHole`  
**Target Branch:** `maintenance/build-compatibility-upgrade`  
**Baseline HEAD Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Application ID:** `com.shadow.blackhole`  
**Version:** `1.15.8+39`  

---

## 1. Executive Summary

Batch 7 focused strictly on the production-minded audit, correction, and stabilization of BlackHole's audio engine integration (`just_audio: 0.9.34`), audio background service (`audio_service: 0.18.10`), audio session management (`audio_session: 0.1.14`), queue integrity, media controls, and notification lifecycle.

All confirmed bugs—including negative queue index crashes, null media item UI dereferences, uncaught SongModel tag parsing failures, unhandled Hive box open states, unbounded notification indices, and missing audio interruption/headphone routing listeners—were resolved with surgical, targeted corrections. No architecture rewrites, no dependency upgrades, and no breaking UI changes were introduced.

All 16 focused automated unit tests in `test/batch_7_audio_engine_test.dart` and the complete repository suite of 265 Flutter tests completed normally with exit code `0`. A single final universal debug APK was compiled with `GRADLE_USER_HOME=D:\DevCaches\GradleUserHome` and verified against a new immutable checkpoint.

---

## 2. Verified Toolchain & Project Environment

- **Flutter SDK:** 3.47.7 (channel stable)
- **Dart SDK:** 3.13.5
- **Java:** OpenJDK 17.0.14
- **Gradle:** 8.14
- **Android Gradle Plugin (AGP):** 8.3.2
- **Kotlin:** 2.0.21
- **Compile SDK:** 36
- **Target SDK:** 29 (Preserved)
- **Minimum SDK:** 21
- **Gradle Cache Directory:** `D:\DevCaches\GradleUserHome` (verified `C:\Users\gkpsu\.gradle` was NOT created)
- **All 9 Dependency Overrides Preserved:**
  1. `receive_sharing_intent` (local path: `packages/receive_sharing_intent`)
  2. `sqflite` (2.4.5)
  3. `sqflite_android` (2.4.5)
  4. `audiotagger` (local path: `packages/audiotagger`)
  5. `flutter_plugin_android_lifecycle` (2.0.35)
  6. `collection` (1.17.1)
  7. `flutter_rust_bridge` (1.81.0)
  8. `http_parser` (4.0.2)
  9. `material_design_icons_flutter` (local path: `packages/material_design_icons_flutter`)

---

## 3. Playback Architecture & Source-to-Player Data Flow

BlackHole's audio architecture is structured as follows:

1. **User Selection & Song Input:**
   - Songs are picked from Home, Top Charts, Playlists, Downloads, or YouTube search/deep links.
   - `PlayerInvoke.init(...)` receives track lists and routes to online (`setValues`), offline local (`setOffValues`), or downloaded (`setDownValues`).
2. **Audio Service Layer (`AudioPlayerHandler` via `audio_service`):**
   - Registered as a singleton background audio handler (`AudioPlayerHandlerImpl`).
   - Converts `MediaItem` models to `AudioSource` via `ConcatenatingAudioSource`.
   - Maintains authoritative queue streams: `queue`, `mediaItem`, `playbackState`, and `queueState`.
3. **Audio Engine Layer (`just_audio`):**
   - Internal `AudioPlayer` manages native Android ExoPlayer instance.
   - Plays HTTP/HTTPS streaming URLs (including Batch 6 validated YouTube streams), local file URIs, or cached audio sources via `LockCachingAudioSource`.
4. **Hardware & System Layer (`audio_session`):**
   - Configures audio focus with speech/music attributes.
   - Handles interruptions (phone calls, ducking from GPS) and headphone disconnections (`becomingNoisyEventStream`).
5. **UI & Media Controls:**
   - `ControlButtons`, `miniplayer`, and `audioplayer` consume `audioHandler` streams.
   - Android Media Notification displays media metadata, compact actions, and handles transport buttons (Play/Pause, Skip, Like/Dislike, Stop).

---

## 4. Confirmed Defects Discovered & Root Cause Analysis

1. **`getQueueIndex` Negative Index Hard Crash:**
   - *Cause:* When idle or when playback transitions between tracks, `just_audio` emits `currentIndex == -1`. In `getQueueIndex`, `-1 < shuffleIndicesInv.length` evaluated to true in Dart, resulting in `shuffleIndicesInv[-1]`, which threw an unhandled `RangeError: Value not in range: -1`.
   - *Fix:* Added explicit bounds check `if (currentIndex == null || currentIndex < 0) return null;`, guarded `effectiveIndices.isEmpty`, and checked `target >= 0 && target < shuffleIndicesInv.length`.
2. **`_init` Startup Hive Null Cast Crash:**
   - *Cause:* In `_init`, `await Hive.box('cache').get('lastIndex', defaultValue: 0) as int` crashed with `type 'Null' is not a subtype of type 'int'` when `lastIndex` had been cached as `null` by a prior `stop()` or empty queue state.
   - *Fix:* Replaced with safe nullable cast and null-coalescing: `(Hive.box('cache').get('lastIndex') as int?) ?? 0`.
3. **Queue & Sequence Stream Null Expando Dereference:**
   - *Cause:* `_mediaItemExpando[source]!` caused `NullCheckOperatorUsedOnNull` whenever an audio source lacked an Expando mapping during dynamic playlist mutation.
   - *Fix:* Replaced with safe mapping and filter: `sequence.map((s) => _mediaItemExpando[s]).whereType<MediaItem>().toList()`.
4. **Missing Audio Session Interruption & Headphone Routing Listeners:**
   - *Cause:* `session.interruptionEventStream` and `session.becomingNoisyEventStream` were configured but had no active stream listeners in `audio_service.dart`. Incoming phone calls, navigation ducking, and unplugged headphones failed to pause or duck playback.
   - *Fix:* Added `_interruptionSubscription` (handling ducking to 50% volume and temporary pause/resume) and `_noisySubscription` (auto-pausing on headphone disconnect).
5. **Player Error State Freezing UI:**
   - *Cause:* When an audio stream encountered an error, `onError` in `playbackEventStream` logged the error but did not update `playbackState`, leaving the UI stuck in an indefinite loading or buffering spinner.
   - *Fix:* Transitioned `playbackState` to `AudioProcessingState.idle` with `playing: false` on playback error.
6. **Playback Stop Deadlock Risk:**
   - *Cause:* `stop()` used `await playbackState.firstWhere((s) => s.processingState == AudioProcessingState.idle)` without a timeout. If the engine had already reached idle before awaiting or if streams were closing, `stop()` would hang indefinitely.
   - *Fix:* Added `.timeout(const Duration(seconds: 2))` with graceful fallback.
7. **Local Track Tags Null Assertion Crash:**
   - *Cause:* `response.artist!` and `response.album!` in `PlayerInvoke.setTags` caused fatal crashes when playing local audio files lacking ID3 metadata. In addition, `response.size` threw a `TypeError` if `_size` was missing from the query map.
   - *Fix:* Replaced with `response.artist ?? 'Unknown'`, `response.album ?? 'Unknown'`, and safe dictionary lookup `response.getMap['_size'] ?? response.getMap['size']`.
8. **`ControlButtons` and `miniplayer` Null Dereference Crashes:**
   - *Cause:* `ControlButtons.build` used `audioHandler.mediaItem.value!` and `mediaItem.extras!['url']`. If the player was idle with no track loaded, opening screens with `ControlButtons` crashed. Similarly, `miniplayer` accessed `mediaItem.duration!.inSeconds` without null-checking, causing crashes on live/radio streams.
   - *Fix:* Made `mediaItem` nullable in `ControlButtons` and guarded null duration and bounds in `miniplayer` and `seek_bar`.
9. **Android Compact Notification Index Out of Bounds:**
   - *Cause:* `preferredCompactNotificationButtons` was passed directly to `androidCompactActionIndices` without verifying indices against available `controls.length` (5 controls), risking Android `IndexOutOfBoundsException` in `MediaStyle`.
   - *Fix:* Added `.where((i) => i >= 0 && i < controls.length).toList()` filtering.
10. **Hive Box Unopened Access in State Broadcast:**
    - *Cause:* `checkPlaylist` was invoked on every playback event by `_broadcastState`. If `Hive.box(name)` was accessed before opening or while closed, `HiveError` was thrown.
    - *Fix:* Guarded with `if (!Hive.isBoxOpen(name)) return false;`.

---

## 5. Summary of Files Changed

| File Path | Description of Changes |
| :--- | :--- |
| `lib/Services/audio_service.dart` | Fixed negative queue index RangeError in `getQueueIndex`, safely filtered sequence expando items, added AudioSession interruption and noisy event streams, protected `_init` and `stop()` against Hive null/timeout deadlocks, replaced leaky `_tappedMediaActionNumber` BehaviorSubject with debounced click counter, bounded compact notification indices, and clamped seek/playback positions. |
| `lib/Services/player_service.dart` | Guarded `audioHandler.mediaItem.value` in `init`, safely parsed local track tags in `setTags` (defaults for null artist, album, and size), hardened `refreshYtLink` against invalid cache casts, and wrapped `updateNplay` in try/catch with safe Hive box checks. |
| `lib/Screens/Player/audioplayer.dart` | Made `ControlButtons` null-safe for `mediaItem` and `mediaItem.extras`, prevented parameter reassignment in `NowPlayingStream.onReorder`, guarded null URLs in playlist download actions, and safely handled null artist names. |
| `lib/CustomWidgets/miniplayer.dart` | Guarded null or zero duration in progress slider, eliminating crashes on live streams or initial buffering states. |
| `lib/CustomWidgets/seek_bar.dart` | Clamped `value` and `bufferedPosition` to `[0.0, maxDuration]`, preventing Flutter Slider framework assertion failures on negative positions. |
| `lib/Helpers/playlist.dart` | Added `Hive.isBoxOpen` guards to `checkPlaylist` and `removeLiked`, preventing fatal `HiveError: Box not found` crashes. |
| `test/batch_7_audio_engine_test.dart` | Created 16 dedicated unit tests validating queue calculations, interruptions, notification bounds, tag parsing, UI null safety, seek clamping, and stop timeouts. |

---

## 6. Verification & Test Evidence

### 6.1 Focused Batch 7 Suite
- **Command:** `flutter test test/batch_7_audio_engine_test.dart --reporter expanded`
- **Result:** Exit code `0`
- **Output:** 16 tests passed, 0 failed.

### 6.2 Full Repository Flutter Test Suite
- **Command:** `flutter test --reporter expanded`
- **Result:** Exit code `0`
- **Output:** 265 tests passed, 0 failed across all test files.

### 6.3 Git Diff Check
- **Command:** `git diff --check`
- **Result:** Exit code `0` (clean, no whitespace errors or merge conflict markers).

### 6.4 Static Analysis
- **Command:** `flutter analyze lib test`
- **Result:** Zero errors in any Batch 7 files. The single pre-existing diagnostic at `lib/Helpers/format.dart:727` remains unmodified as documented in project guidelines.

---

## 7. Final APK Build & Checkpoint Integrity

### 7.1 Primary Build Artifact
- **Path:** `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk`
- **Build Command:** `$env:GRADLE_USER_HOME="D:\DevCaches\GradleUserHome"; flutter build apk --debug`
- **Exit Code:** `0` (Build completed in 63.3s)
- **File Size:** `197,272,727` bytes
- **SHA-256:** `FEE883BA246654468B4714C0594E66568EB2332708DECDFF94936C4B69DB2CC7`

### 7.2 Immutable Batch 7 Checkpoint
- **Path:** `D:\BlackHole-Checkpoints\post-batch-7-final-20261026-003500\app-debug.apk`
- **File Size:** `197,272,727` bytes
- **SHA-256:** `FEE883BA246654468B4714C0594E66568EB2332708DECDFF94936C4B69DB2CC7`
- **Integrity:** Exact byte-for-byte match with primary build artifact.

### 7.3 Preservation of Accepted Batch 6 Checkpoint
- **Path:** `D:\BlackHole-Checkpoints\post-batch-6-final-targeted-review-20261025-234500\app-debug.apk`
- **Expected Size:** `197,266,497` bytes
- **Expected SHA-256:** `DDE066FCF851EED55E55B51F5210D01C331627034E7C01E5ABE44E73A35A2B25`
- **Verified Size:** `197,266,497` bytes
- **Verified SHA-256:** `DDE066FCF851EED55E55B51F5210D01C331627034E7C01E5ABE44E73A35A2B25`
- **Integrity Status:** Preserved unchanged.

---

## 8. Physical-Device Manual Acceptance Checklist

The developer should perform the following manual acceptance tests using `adb install -r D:\BlackHole-Checkpoints\post-batch-7-final-20261026-003500\app-debug.apk` without clearing user data:

### A. Installation & Startup
- [ ] Install the Batch 7 APK over Batch 6 (`adb install -r`).
- [ ] Launch BlackHole and confirm normal startup without crashes.
- [ ] Verify existing playlists, favorites, and settings are fully preserved.

### B. Playback Controls & Lifecycle
- [ ] Play a local audio file and verify playback starts smoothly.
- [ ] Play an online song (e.g. JioSaavn / YouTube stream).
- [ ] Test Play, Pause, Seek (forward and back), and Track Skip (Next / Previous).
- [ ] Confirm playback speed adjustments (0.5x to 3.0x) take effect and persist.
- [ ] Let a track finish and verify automatic transition to the next track.

### C. Queue Management & Transitions
- [ ] Add multiple songs to the now-playing queue.
- [ ] Reorder songs in the queue and verify playback queue remains consistent.
- [ ] Remove items from the queue and verify no crash or index misalignment occurs.
- [ ] Test shuffle and repeat modes (Repeat All, Repeat One, Repeat None).

### D. Background Audio & Notification Controls
- [ ] Start audio playback and press the Home button to send BlackHole to the background.
- [ ] Turn off the phone screen and verify uninterrupted playback.
- [ ] Use notification buttons (Play, Pause, Skip Next, Skip Previous, Stop) from lock screen.
- [ ] Verify compact notification view shows correct icons without visual glitches.
- [ ] Return to foreground and verify the UI state matches current playing audio.

### E. Audio Focus & Interruption Handling
- [ ] Receive a simulated phone call or trigger another audio app; confirm BlackHole pauses.
- [ ] End the call; confirm playback resumes appropriately.
- [ ] Unplug wired headphones or disconnect Bluetooth; verify audio automatically pauses without playing through the loudspeaker.

### F. Batch 1–6 Regression Check
- [ ] Open a YouTube link shared into BlackHole; confirm single playback trigger.
- [ ] Check high-resolution album artwork rendering on Home, Charts, and Player.
- [ ] Rotate device to landscape; verify display cutout does not obscure controls.
- [ ] Check downloaded songs library and verify existing files play offline.

---

## 9. Boundary Statement

Batch 7 work is complete. Batches 8 and 9 have not been started. No git commits, pushes, merges, or branch switches were executed.
