# BLACKHOLE FLUTTER — BATCH 4 & BATCH 5 FINAL IMPLEMENTATION REPORT
## Storage & Permissions + Database, Persistence & Backup Security

**Date:** 2026-10-25  
**Active Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Reference Repository:** `D:\My-GitHub-Projects\BlackHole` (Strictly read-only, untouched)  
**Maintenance Branch:** `maintenance/build-compatibility-upgrade`  
**Baseline HEAD Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  

---

## 1. Baseline Environment & Verified Toolchain

Before making any source modifications, the local environment and toolchain were inspected and verified against project requirements:

- **Flutter SDK:** `3.47.7` (Channel stable, Dart 3.13.5)
- **Dart SDK:** `3.13.5`
- **Java Runtime:** Eclipse Adoptium OpenJDK 64-Bit Server VM `17.0.20.1` (build 17.0.20.1+1)
- **Gradle Version:** `8.14` (configured in `android/gradle/wrapper/gradle-wrapper.properties`)
- **Android Gradle Plugin (AGP):** `8.3.2`
- **Kotlin Version:** `2.0.21`
- **Android SDK Targets:** `compileSdkVersion 36`, `targetSdkVersion 29`, `minSdkVersion 21`
- **Application Identity:**
  - Application ID / Namespace: `com.shadow.blackhole`
  - Version: `1.15.8+39`
- **Approved Gradle Cache:** `GRADLE_USER_HOME=D:\DevCaches\GradleUserHome`
  - Confirmed `C:\Users\gkpsu\.gradle` does not exist (`Test-Path` returned `False`) and was not created during testing or build.

### Preserved Dependency Overrides (All 9 Intact)
All nine project overrides were verified intact and unmodified in `pubspec.yaml`:
1. `receive_sharing_intent` (local path: `packages/receive_sharing_intent`)
2. `sqflite`: `2.4.5`
3. `sqflite_android`: `2.4.5`
4. `audiotagger` (local path: `packages/audiotagger`)
5. `flutter_plugin_android_lifecycle`: `2.0.35`
6. `collection`: `1.17.1`
7. `flutter_rust_bridge`: `1.81.0`
8. `http_parser`: `4.0.2`
9. `material_design_icons_flutter` (local path: `packages/material_design_icons_flutter`)

### Preserved Previous Milestone Work
- Startup optimizations (parallel Hive box opening via `Future.wait`, deferred display-mode initialization until after first frame).
- Landscape display-cutout / notch fix (`shortEdges` layout in `styles.xml`).
- Artwork quality & loading enhancements (high-resolution image URL mapping in `image_resolution_modifier.dart` with fast-first fallback).

### Protected Checkpoints of Previous APKs
Prior to building replacement APKs, all previous milestone builds were preserved in dedicated directories:
- **Pre-Batch Checkpoint:** `D:\BlackHole-Checkpoints\pre-batch-4-5-checkpoint-20261025-193138\app-debug.apk` (197,270,429 bytes, SHA-256: `6d8c2734191c5c97a520b2783e3f8e907ed4b46f86aa7f340e01343201faeabd`)
- **Initial Combined Checkpoint:** `D:\BlackHole-Checkpoints\post-batch-4-5-initial-build-20261025-202100\app-debug.apk` (197,249,051 bytes, SHA-256: `563ffdfb243261803adf9886eea23c7a7a196f429b5194142cda7ed66cfc1839`)
- **Interim Replacement Checkpoint:** `D:\BlackHole-Checkpoints\post-batch-4-5-pre-final-20261025-213500\app-debug.apk` (197,250,532 bytes, SHA-256: `7b209a77e3cdef3d4f4bda053f40b67758123cd5ea6af6fe3f2f7793a08a9978`)
- **Final Security-Reviewed Checkpoint:** `D:\BlackHole-Checkpoints\post-batch-4-5-final-security-reviewed-20261025-213500\app-debug.apk` (197,251,266 bytes, SHA-256: `52c01db005d079938871e2df91a2f66d6cf5abeee4c5de4f7460565a81f5bd53`)

---

## 2. Subphase A: Batch 4 — Storage & Permissions Implementation & Targeted Fixes

### Inventory & Audited Files
The existing storage, permission, file-picking and media querying mechanisms were investigated across:
- `lib/Helpers/picker.dart` (`FilePicker` usage and result handling)
- `lib/Helpers/audio_query.dart` (`OnAudioQuery` artwork caching and local media queries)
- `lib/Services/ext_storage_provider.dart` (`Permission.storage` vs `Permission.audio` and directory resolution)
- `lib/Services/download.dart` (download destination resolution, temp directories, permission gating)
- `lib/Screens/LocalMusic/downed_songs.dart` (local media filtering and path segmentation)
- `lib/Screens/Library/downloads.dart` (tag editing permissions and artwork saving)
- `android/app/src/main/AndroidManifest.xml` (storage permission declarations and SDK boundaries)

### Verified Defects Found & Remediated

1. **`lib/Helpers/picker.dart` (File Picker Path & Cancellation Null-Safety):**
   - *Defect:* `Picker().selectFile()` returned `result.files.first.path!`, causing an unhandled `NullCheckError` when a user cancelled the picker on Android SAF / file chooser or when a content URI didn't have a direct file path.
   - *Remediation:* Verified `result != null && result.files.isNotEmpty` and checked `file.path != null`. For custom extension filtering, updated `FilePicker.platform.pickFiles` to use `type: FileType.custom` with `allowedExtensions: ext` when an extension list is provided. Returns empty string safely upon user cancellation or missing path.

2. **`lib/Helpers/audio_query.dart` (Zero-Byte Artwork File Creation & Null Check Crash):**
   - *Defect:* In `queryNSave()`, if artwork query returned null or empty bytes, `File(path).create(recursive: true)` still ran followed by `image!`, causing a crash or leaving 0-byte corrupt placeholder image files in the cache.
   - *Remediation:* Guarded `if (image != null && image.isNotEmpty)` before creating the file. Changed blocking `file.writeAsBytesSync(image!)` to asynchronous non-blocking `await file.writeAsBytes(image)`.

3. **`android/app/src/main/AndroidManifest.xml` (Target SDK 29 Storage & Media Compatibility):**
   - *Defect:* The app targets SDK 29 (`targetSdkVersion 29`). Setting `maxSdkVersion="29"` on `WRITE_EXTERNAL_STORAGE` and `maxSdkVersion="32"` on `READ_EXTERNAL_STORAGE` stripped storage permissions on Android 11+ and Android 13+, breaking the OS legacy storage compatibility layer (`requestLegacyExternalStorage="true"`). Furthermore, `on_audio_query` on Android 13+ queries both `READ_MEDIA_AUDIO` and `READ_MEDIA_IMAGES`; without `READ_MEDIA_IMAGES` declared, `on_audio_query.permissionStatus()` failed permanently.
   - *Remediation:* Removed `maxSdkVersion` from both `WRITE_EXTERNAL_STORAGE` and `READ_EXTERNAL_STORAGE`. Declared both `READ_MEDIA_AUDIO` and `READ_MEDIA_IMAGES` in `AndroidManifest.xml` to satisfy `on_audio_query`. Kept `targetSdkVersion 29` strictly preserved.

4. **`lib/Services/ext_storage_provider.dart` (Android 13+ Audio & Storage Compatibility):**
   - *Defect:* Indiscriminately switching entirely to `Permission.audio` on Android 13+ broke devices where an app targeting SDK 29 requires `Permission.storage` under the system's legacy compatibility layer. Furthermore, if `/storage/emulated/0/Music` was inaccessible, the code threw an unhandled string `return throw 'something went wrong'`.
   - *Remediation:* On Android 13+, checks/requests `Permission.audio`, but if not granted, falls back to `Permission.storage` (`READ_EXTERNAL_STORAGE`). Added a graceful fallback: if the public Music directory cannot be resolved or accessed, it falls back to the app-specific external files music directory (`(await getExternalStorageDirectory())/Music`), which requires zero runtime storage permissions on Android 10+. Eliminated the crashing unhandled string throw.

5. **`lib/Services/download.dart` (Permission Overreach & Path Null Safety):**
   - *Defect:* `prepareDownload()` indiscriminately requested `Permission.accessMediaLocation` and `Permission.mediaLibrary` on top of storage, creating unnecessary permission prompts on startup or download initiation. On Windows/Desktop, `temp!.path` and `temp!` were dereferenced with `!` without checking if `getTemporaryDirectory()` returned null.
   - *Remediation:* Replaced legacy permission prompts with SDK-aware `ExtStorageProvider.requestPermission()`. Guarded temp directory resolution with fallbacks to `getApplicationDocumentsDirectory()` and ensured all paths are validated before use.

6. **`lib/Screens/LocalMusic/downed_songs.dart` (SongModel Null Safety Crash):**
   - *Defect:* `(i.isMusic! || i.isPodcast! || i.isAudioBook!)` used force-unwrapped booleans on `SongModel`. If `on_audio_query` returned null for any flag on certain Android OEM ROMs, the entire local music screen crashed with a runtime `NullCheckError`. In addition, `tempPath.removeLast()` threw a `StateError` if the song's path had no folder segments.
   - *Remediation:* Replaced force unwraps with null-safe coalescing: `((i.isMusic ?? false) || (i.isPodcast ?? false) || (i.isAudioBook ?? false))`. Guarded `tempPath.removeLast()` with `if (tempPath.isNotEmpty)`.

7. **`lib/Screens/Library/downloads.dart` (Platform-Unsafe Permission Call & Unawaited Async):**
   - *Defect:* `Permission.manageExternalStorage.request()` was invoked unconditionally without platform gating. On non-Android platforms or Android 10 and below, this triggers platform exceptions. Furthermore, `tagger.writeTags` was not awaited, causing race conditions when saving downloaded files.
   - *Remediation:* Guarded `manageExternalStorage` with `if (Platform.isAndroid)`. Awaited `tagger.writeTags()`, and made artwork file copying null-safe.

---

## 3. Subphase B: Batch 5 — Database, Persistence & Backup Security Targeted Implementation

### Inventory & Audited Files
The existing persistence layers and data serialization were audited across:
- `lib/main.dart` (`openHiveBox` error handling, box opening, parallel initialization)
- `lib/Services/audio_service.dart` (`preferredCompactNotificationButtons` deserialization from Hive)
- `lib/Screens/Settings/setting.dart` and `lib/Screens/Settings/app_ui.dart` (settings retrieval)
- `lib/Helpers/backup_restore.dart` (Hive backup creation, ZIP central directory reading, pre-write validation, and rollback)
- `lib/Helpers/import_export_playlist.dart` (JSON playlist import and export)

### Verified Defects Found & Remediated

1. **`lib/main.dart` (Hive Lock Verification & Zero-Data-Loss Architecture):**
   - *Defect:*
     1. `openHiveBox()` opened lock files using `lockFile.open(mode: FileMode.write)`. As documented by Dart, `FileMode.write` truncates the file immediately upon opening, destroying any lock content or metadata.
     2. Attempting to acquire an OS exclusive lock probe (`raf.lock()`) does not prove a lock is stale on Android runtime or distinguish process contention from an abandoned lock. Hive internally opens `.lock` files with `FileMode.write` and advisory locking; leftover lock files do not block future app launches.
     3. In error catch blocks, attempting to delete `.lock` files or calling `await dbFile.delete()` silently destroyed user database files (`settings`, `playlists`, `Favorite Songs`) and replaced them with empty boxes!
     4. Default `crashRecovery: true` in `Hive.openBox()` silently zeroes unreadable files.
     5. Lacked fast checks for `Hive.isBoxOpen(boxName)` when multiple parallel startup tasks ran.
   - *Remediation:*
     1. Added `if (Hive.isBoxOpen(boxName)) return;` at entry and inside the catch block to cleanly handle concurrent callers.
     2. Completely eliminated `lockFile.open(mode: FileMode.write)` and all file modification during lock inspection.
     3. Completely eliminated all `lockFile.delete()` and `dbFile.delete()` logic. User databases and lock files are preserved intact on disk under all failure conditions.
     4. Configured `Hive.openBox(boxName, crashRecovery: false)` to prevent Hive from silently truncating unreadable files to 0 bytes.
     5. If an error occurs, detailed actionable logs are emitted and an explanatory exception is thrown, preserving on-disk data for external recovery.

2. **`lib/Services/audio_service.dart`, `setting.dart`, `app_ui.dart` (Hive Deserialization Type Safety):**
   - *Defect:* Hive deserializes stored lists as untyped `List<dynamic>`. The code performed `Hive.box('settings').get('preferredCompactNotificationButtons', defaultValue: [1, 2, 3]) as List<int>`. Because a deserialized `List<dynamic>` cannot be cast directly to `List<int>`, this threw a fatal runtime `TypeError: type 'List<dynamic>' is not a subtype of type 'List<int>' in type cast`, crashing the audio service initialization on startup.
   - *Remediation:* Replaced unsafe direct cast with safe mapping:
     ```dart
     final rawButtons = Hive.box('settings').get('preferredCompactNotificationButtons', defaultValue: [1, 2, 3]);
     final preferredCompactNotificationButtons = (rawButtons is List)
         ? rawButtons.map((e) => int.tryParse(e.toString()) ?? 1).toList()
         : <int>[1, 2, 3];
     ```
     Applied identically across audio service initialization and settings UI screens.

3. **`lib/Helpers/backup_restore.dart` (Pre-Extraction ZIP Central Directory Validation & Pre-Write Boundary Enforcement):**
   - *Defect:*
     1. Post-extraction checking is fundamentally unsafe because malicious entries are already written to disk before validation runs.
     2. Android's native `flutter_archive` plugin (`FlutterArchivePlugin.kt`) checks `!outputFileCanonicalPath.startsWith(destinationDir.canonicalPath)` without a trailing separator boundary, allowing prefix-sharing sibling paths (`/restore_123_evil` matching `/restore_123`).
     3. If an archive entry target does not exist yet on disk, `resolveSymbolicLinksSync()` directly on the candidate fails.
     4. Restoring `.hive` files while Hive has open boxes in memory causes in-memory cache and on-disk files to diverge, causing data corruption.
     5. Multi-box restore had no snapshot rollback mechanism; if restore failed halfway, databases were left in an inconsistent partial state.
   - *Remediation:*
     1. **Pure Dart Central Directory Parser (`getZipEntryNames`):** Implemented an in-memory ZIP central directory parser that reads the archive's End of Central Directory (EOCD) record and Central Directory headers directly using `dart:io` and `dart:typed_data`. All entry paths are inspected before extracting a single byte.
     2. **Pre-Extraction Quarantine:** If any entry contains `..`, absolute drive/root paths, null bytes (`\x00`), or escapes the root boundary, a `SecurityException` is thrown before calling native extraction.
     3. **Pre-Write Callback (`onExtracting`):** Enforced active cancellation via the `onExtracting` callback in `ZipFile.extractToDirectory()`. If an unsafe path is encountered during native extraction, `ZipFileOperation.cancel` is returned immediately.
     4. **Robust Boundary Verification (`isPathWithinRoot`):** Uses `package:path` (`p.isWithin` and `p.canonicalize`), enforces path separator boundaries, and for nonexistent targets, traverses up to the nearest existing ancestor directory to resolve symbolic links.
     5. **Open Box Flush & Close:** Before modifying any box file on disk, if the box is open in memory, it is compacted/flushed and cleanly closed (`await box.compact(); await box.close();`).
     6. **Snapshot-Based Rollback:** Before overwriting `.hive` files, original files are snapshotted into a temporary `rollback_snapshot/` folder. If any failure occurs during restoration, open boxes are closed, snapshotted originals are restored, and boxes are reopened in their original state.

4. **`lib/Helpers/import_export_playlist.dart` (Safe Playlist Import Validation & Size Bounds):**
   - *Defect:* `importPlaylist()` called `File(path!).readAsString()` and `jsonDecode()` without verifying file existence, non-emptiness, or file size limits, risking memory exhaustion or crashing on empty/malformed files.
   - *Remediation:* Added pre-checks verifying that the file exists, has size > 0, and does not exceed a safe maximum (20 MB). Safely catch `FormatException` and display a user-friendly error message rather than crashing.

---

## 4. Verification & Validation Telemetry

### Focused Unit Tests
1. **`test/storage_permissions_test.dart` (Subphase A):**
   - `ExtStorageProvider getExtStorage returns a valid fallback directory`: **PASSED**
   - `queryNSave safely handles null/empty artwork without 0-byte files`: **PASSED**
   - `SongModel filter accepts songs with null isMusic without crashing`: **PASSED**
   - `Data path folder splitting safely handles paths with or without subfolders`: **PASSED**
   - **Focused Subphase A Total:** 4/4 passed (0 failures, 0 timeouts).

2. **`test/database_persistence_security_test.dart` (Subphase B):**
   - `preferredCompactNotificationButtons safely deserializes dynamic lists`: **PASSED**
   - `preferredCompactNotificationButtons falls back safely on invalid values`: **PASSED**
   - `Non-destructive recovery preserves user database file without deletion`: **PASSED**
   - `Status checks and unproven recovery never modify, truncate, or delete lock files`: **PASSED**
   - `Repeated or concurrent calls to openHiveBox do not trigger destructive recovery`: **PASSED**
   - `User database file is preserved without silent deletion when open error occurs`: **PASSED**
   - `isPathWithinRoot strictly allows valid files and subdirectories within destination`: **PASSED**
   - `isPathWithinRoot rejects prefix-sharing sibling directories (anti-Zip Slip)`: **PASSED**
   - `isPathWithinRoot rejects parent directory traversal (../)`: **PASSED**
   - `isPathWithinRoot handles nonexistent targets with parent-directory traversal correctly`: **PASSED**
   - `isPathWithinRoot rejects absolute paths and null bytes`: **PASSED**
   - `isPathWithinRoot rejects root directory itself as a file entry`: **PASSED**
   - `Validates backup archive extension must be .zip`: **PASSED**
   - `getZipEntryNames accurately reads ZIP central directory without extracting files`: **PASSED**
   - `Pre-extraction validation detects and blocks malicious archive with path traversal and prefix-sharing siblings`: **PASSED**
   - `Normal valid backup archive passes pre-extraction validation`: **PASSED**
   - `Restoring on-disk snapshots while Hive boxes are open safely closes, updates, and reopens boxes`: **PASSED**
   - `Rollback restores previous box state when an error occurs during multi-box restoration`: **PASSED**
   - `Safely rejects empty or malformed playlist JSON`: **PASSED**
   - `Correctly parses valid playlist map and list formats`: **PASSED**
   - **Focused Subphase B Total:** 20/20 passed (0 failures, 0 timeouts).

### Full Regression Test Suite Results
Full test suite executed via `flutter test --reporter expanded`:
- **Total Test Cases:** **222 passed**
- **Failures:** **0**
- **Errors / Timeouts:** **0**
- **Exit Code:** **0**
- **Elapsed Time:** ~8.5s

### Code Quality & Static Analysis (`flutter analyze`)
- Executed: `flutter analyze lib/main.dart lib/Helpers/backup_restore.dart test/database_persistence_security_test.dart`
- **Result:** `No issues found! (ran in 3.2s)`
- All Batch 4 & Batch 5 files conform cleanly to project lint rules (`directives_ordering`, `require_trailing_commas`, `unnecessary_await_in_return`).

### Git Diff Check (`git diff --check`)
- Command: `git diff --check`
- **Result:** Exit code 0 (clean; no whitespace errors or merge conflict markers).

---

## 5. Final Replacement Debug APK Delivery

The combined debug APK containing both Batch 4 (Storage & Permissions) and Batch 5 (Database, Persistence & Backup Security) was built with the approved toolchain and isolated Gradle User Home:

- **Build Command:** `flutter build apk --debug` with `GRADLE_USER_HOME=D:\DevCaches\GradleUserHome`
- **Build Exit Code:** `0` (Success, 70.5s)
- **Gradle User Home Used:** `D:\DevCaches\GradleUserHome`
- **Workstation Isolation Verified:** `C:\Users\gkpsu\.gradle` does not exist (`False`).
- **Final Built APK Location:**  
  [`D:/My-GitHub-Projects/BlackHole-maintenance/build/app/outputs/flutter-apk/app-debug.apk`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/build/app/outputs/flutter-apk/app-debug.apk)
- **File Size:** `197,251,266` bytes
- **SHA-256 Hash:** `52c01db005d079938871e2df91a2f66d6cf5abeee4c5de4f7460565a81f5bd53`

### Checkpoint APKs Preserved (All Intact)
1. `D:\BlackHole-Checkpoints\pre-batch-3-gradle-cleanup-20261025-024025`
2. `D:\BlackHole-Checkpoints\pre-batch-4-5-checkpoint-20261025-193138\app-debug.apk` (197,270,429 bytes, SHA-256: `6d8c2734191c5c97a520b2783e3f8e907ed4b46f86aa7f340e01343201faeabd`)
3. `D:\BlackHole-Checkpoints\post-batch-4-5-initial-build-20261025-202100\app-debug.apk` (197,249,051 bytes, SHA-256: `563ffdfb243261803adf9886eea23c7a7a196f429b5194142cda7ed66cfc1839`)
4. `D:\BlackHole-Checkpoints\post-batch-4-5-pre-final-20261025-213500\app-debug.apk` (197,250,532 bytes, SHA-256: `7b209a77e3cdef3d4f4bda053f40b67758123cd5ea6af6fe3f2f7793a08a9978`)
5. `D:\BlackHole-Checkpoints\post-batch-4-5-final-security-reviewed-20261025-213500\app-debug.apk` (197,251,266 bytes, SHA-256: `52c01db005d079938871e2df91a2f66d6cf5abeee4c5de4f7460565a81f5bd53`)

---

## 6. Physical-Device Test Checklist for the Developer

Please use the following checklist to test the new debug APK on a physical Android device:

### A. Installation & Startup
- [ ] Install the APK (`adb install -r build/app/outputs/flutter-apk/app-debug.apk`) over the existing build without clearing app data.
- [ ] Confirm the app launches cleanly without crashing during parallel Hive box opening.
- [ ] Verify that existing settings, favourites, and playlists remain intact from previous sessions.

### B. Permissions & Storage (Android 13+ and Legacy)
- [ ] On Android 13+ (API 33+), verify that the app requests Audio/Media permissions when scanning local music.
- [ ] Deny the audio permission once; verify the app displays a graceful rationale/fallback rather than crashing.
- [ ] Grant permission via Android Settings -> Apps -> BlackHole -> Permissions -> Music & Audio; return to BlackHole and verify local songs appear without restarting the app.
- [ ] Open the file picker (e.g. for custom background image or playlist import); cancel the file picker and verify the app does not crash.

### C. Local Music & Artwork
- [ ] Navigate to the Local Music section; verify songs, albums, and artists load properly.
- [ ] Verify that songs without embedded album art show the default placeholder without generating 0-byte cache files.
- [ ] Verify that downloading a track saves audio to the designated Music folder (or app-specific storage fallback).

### D. Backup, Export & Restore Security
- [ ] Go to Settings -> Backup & Restore -> Create Backup. Select a destination folder and verify a `.zip` archive is successfully created.
- [ ] In Settings -> Backup & Restore -> Restore, pick the newly created backup zip; verify all settings and playlists restore cleanly.
- [ ] Attempt to restore an invalid or renamed non-zip file (e.g., `.txt` or `.png`); verify the app displays a clean error message and leaves existing boxes intact without partial corruption.
- [ ] Export a playlist to JSON; re-import it and verify tracks are restored.

### E. Audio Playback & Visual Regressions
- [ ] Play a song and ensure notification controls (compact notification buttons `[1, 2, 3]`) appear and operate correctly without crashing.
- [ ] Verify landscape orientation: ensure the top notch / display cutout does not obscure player controls (`shortEdges` layout).
- [ ] Verify album art on Home, Top Charts, and YouTube sections displays at high resolution without blurriness.
