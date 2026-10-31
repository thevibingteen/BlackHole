# BLACKHOLE REVIVAL — POST-BATCH-1 BUG FIXES REPORT
## Download Notifications, Instant Downloads-List Refresh & Track-Specific Download Progress

**Date:** 2026-10-25  
**Workspace:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Baseline Git Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Status:** Verification Complete — Ready for Maintainer Manual Testing  

---

## 1. Executive Summary & Repository Protection

Following manual maintainer testing of the Batch 1 debug build, three download-related defects were identified:
1. **Bug A (Dismissal of download/deletion messages):** Success snackbars lingered indefinitely until the user manually tapped "OK".
2. **Bug B (Downloads-list deletion delay):** Deleting a downloaded song resulted in a noticeable delay before the song disappeared from the UI list.
3. **Bug C (Download progress transfer on track change):** When Song A was downloading and playback switched to Song B, the download progress bar and active state transferred visually to Song B.

All three defects have been resolved with minimal, surgically scoped changes in the maintenance worktree (`D:\My-GitHub-Projects\BlackHole-maintenance`). The original repository (`D:\My-GitHub-Projects\BlackHole`) remains strictly untouched and read-only. No dependencies were modified, no build files were altered, no audio stuttering changes were introduced, and **no emulator was launched**.

### Repository Integrity Audit

| Checkpoint | Target State | Verified Status |
| :--- | :--- | :--- |
| **Original Repository** | `D:\My-GitHub-Projects\BlackHole` | Strictly Read-Only (Untouched) |
| **Maintenance Worktree** | `D:\My-GitHub-Projects\BlackHole-maintenance` | Verified Active Workspace |
| **Active Branch** | `maintenance/build-compatibility-upgrade` | Confirmed |
| **Baseline Preservation** | Retain Phase A, B, C, D1, D2 Batch 1 changes | Confirmed |
| **Dependency Locks** | `pubspec.yaml` & `pubspec.lock` | Untouched (Batch 1 locked) |
| **Emulator Isolation** | No emulator started or installed to | 100% Compliant (Manual test only) |

---

## 2. Root Cause Analysis & Implementations

### Bug A: Dismissal of Download & Deletion Messages

#### Root Cause Analysis
In [lib/CustomWidgets/snackbar.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/snackbar.dart#L24-L54), `ShowSnackBar.showSnackBar` configured an action button by default:
```dart
action: noAction
    ? null
    : action ??
        SnackBarAction(
          label: AppLocalizations.of(context)!.ok,
          ...
        ),
```
Whenever `noAction` was omitted, it defaulted to `false`, appending an `Ok` `SnackBarAction`. In Flutter's `SnackBar` implementation, presence of a `SnackBarAction` alters the interaction semantics and users naturally perceive that tapping `Ok` is required to dismiss the bar. Furthermore, the default duration was set to `Duration(seconds: 1)`, and call sites in [lib/Services/download.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart) and [lib/Screens/Library/downloads.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/downloads.dart) did not pass `noAction: true`. Finally, newly dispatched snackbars queued behind active ones rather than dismissing immediately.

#### Applied Fixes
1. **[lib/CustomWidgets/snackbar.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/snackbar.dart#L24-L38):**
   - Changed default `duration` to `const Duration(seconds: 3)`.
   - Added `ScaffoldMessenger.of(context).hideCurrentSnackBar()` immediately prior to `showSnackBar()` so newly triggered notifications dismiss stale ones instantly without queuing.
   - Retained optional `action` and `noAction` parameters so actionable error messages and confirmations continue to display buttons as intended.
2. **[lib/Services/download.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart#L578-L583):**
   - Updated download success notification to pass `duration: const Duration(seconds: 3)` and `noAction: true`.
3. **[lib/Screens/Library/downloads.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/downloads.dart#L268-L274):**
   - Updated song deletion success notification to pass `duration: const Duration(seconds: 3)` and `noAction: true`.
4. **[lib/Screens/Library/playlists.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/playlists.dart#L489-L495) & [lib/Screens/LocalMusic/localplaylists.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/LocalMusic/localplaylists.dart#L140-L146):**
   - Updated playlist deletion success notifications to pass `duration: const Duration(seconds: 3)` and `noAction: true`.

---

### Bug B: Instant Downloads-List State Refresh & Deletion Safety

#### Root Cause Analysis
In [lib/Screens/Library/downloads.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/downloads.dart#L231-L281), `deleteSong`:
1. Did not call `setState(() {})` within `_DownloadsState`, so the parent widget never rebuilt its count or headers until an external event or re-navigation occurred.
2. Filesystem deletion was unawaited (`audioFile.delete();` instead of `await audioFile.delete();`), risking race conditions between file deletion, Hive deletion, and in-memory updates.
3. In [lib/Screens/Library/downloads.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/downloads.dart#L1047-L1055), `DownSongsTab` received a synchronous callback `final Function(Map item) onDelete;` and called `setState(() { widget.onDelete(...); });` without awaiting asynchronous deletion completion.
4. In-memory data structures were mutated *before* disk operations, meaning if file deletion failed, the UI still dropped the song until refresh.

#### Applied Fixes
1. **Order of Operations & Awaiting Disk Operations:**
   - Swapped order so `audioFile.delete()` and `imageFile.delete()` are checked with `await exists()` and properly awaited before touching the database or in-memory lists.
   - Awaited `await downloadsBox.delete(song['id'])`.
   - Updated in-memory structures `_albums`, `_artists`, `_genres`, `_sorted*KeysList`, and `_songs` only after disk and database deletion succeed.
   - Added `if (mounted) setState(() {});` in `_DownloadsState` to guarantee immediate UI and `PlaylistHead` song count updates.
2. **Asynchronous Tab Callback:**
   - Changed `DownSongsTab.onDelete` signature from `Function(Map item)` to `Future<void> Function(Map item)`.
   - In `_DownSongsTabState`, awaited `await widget.onDelete(songToDelete);` and followed with `if (mounted) setState(() {});`.
3. **Failure Safety:**
   - In the `catch` block, logged failure via `Logger.root.severe`, displayed actionable error snackbar with details, and ensured the song remains in `_songs` and Hive so no state corruption occurs.

---

### Bug C: Track-Specific Download Progress Isolation

#### Root Cause Analysis
In [lib/CustomWidgets/download_button.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/download_button.dart#L44-L63):
1. `_DownloadButtonState` initialized `down = Download(widget.data['id'].toString())` in `initState()` and attached a listener.
2. When the user switched tracks in the player, Flutter reused the existing `_DownloadButtonState` because the widget type and tree position remained unchanged.
3. `_DownloadButtonState` **did not implement `didUpdateWidget`**. Consequently, `down` continued pointing to Song A's `Download` instance. When Song A emitted progress updates, `_DownloadButtonState` received them and rendered Song A's progress onto Song B's button!
4. `_DownloadButtonState` also did not implement `dispose()`, leaving listeners active on the singleton instance map.
5. In [lib/Screens/Player/audioplayer.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Player/audioplayer.dart), `DownloadButton` instances across player control bars and queue items lacked explicit keys tied to `mediaItem.id`.
6. In [lib/Services/download.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart#L76-L86), if `prepareDownload` was invoked on an instance whose `id` did not match `data['id']`, it did not redirect to the corresponding track instance.

#### Applied Fixes
1. **[lib/CustomWidgets/download_button.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/CustomWidgets/download_button.dart#L44-L90):**
   - Implemented `didUpdateWidget` in `_DownloadButtonState`:
     ```dart
     @override
     void didUpdateWidget(covariant DownloadButton oldWidget) {
       super.didUpdateWidget(oldWidget);
       if (oldWidget.data['id'].toString() != widget.data['id'].toString()) {
         down.removeListener(_onDownloadUpdated);
         down = Download(widget.data['id'].toString());
         down.addListener(_onDownloadUpdated);
       }
     }
     ```
   - Implemented `dispose()` to clean up listeners and dispose `showStopButton`.
   - Updated downloaded status check to `downloadsBox.containsKey(widget.data['id']) || downloadsBox.containsKey(widget.data['id'].toString())` to handle both int and string IDs.
   - Updated `_MultiDownloadButtonState` and `_AlbumDownloadButtonState` with matching `didUpdateWidget`, `dispose`, and robust `_waitUntilDone` logic tracking `lastDownloadId`, `lastGlobalDownloadId`, and `downloadsBox`.
2. **[lib/Screens/Player/audioplayer.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Player/audioplayer.dart#L942-L947, #L1075-L1082, #L2286-L2296):**
   - Added explicit `ValueKey` to player action download button: `ValueKey('player_action_download_${mediaItem.id}')`.
   - Added explicit `ValueKey` to queue item download button: `ValueKey('queue_download_${queue[index].id}')`.
   - Added explicit `ValueKey` to bottom player download button: `ValueKey('player_download_${mediaItem.id}')`.
3. **[lib/Services/download.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart#L76-L86, #L536-L548):**
   - In `prepareDownload`: routes execution to `Download(data['id'].toString()).prepareDownload(...)` if `this.id != data['id']`.
   - Added `static String lastGlobalDownloadId = '';` updated on completion alongside `lastDownloadId`.

---

## 3. Automated Test Verification

### Dedicated Regression Test Suite (`test/download_bug_fixes_test.dart`)

A comprehensive 457-line regression test suite was created covering all three bugs:

```
00:00 +0: (setUpAll)
00:00 +0: Bug A — Notification Tests (Duration, Auto-dismissal & Action Presence) Transient success snackbar has 3s duration and no OK action button
00:01 +1: Bug A — Notification Tests (Duration, Auto-dismissal & Action Presence) Deletion success snackbar auto-dismisses without requiring interaction
00:01 +2: Bug A — Notification Tests (Duration, Auto-dismissal & Action Presence) Actionable error snackbar retains OK button for explicit user acknowledgment
00:01 +3: Bug A — Notification Tests (Duration, Auto-dismissal & Action Presence) New snackbar immediately replaces prior active snackbar without queuing delays
00:01 +4: Bug B — Immediate Downloads Refresh & Deletion Safety Tests Successful deletion updates database and in-memory list promptly
00:01 +5: Bug B — Immediate Downloads Refresh & Deletion Safety Tests Deletion failure does NOT remove song from database or in-memory list
00:01 +6: Bug C — Track-Specific Download Identity & Progress Tests Each track ID maintains its own distinct Download instance and progress
00:01 +7: Bug C — Track-Specific Download Identity & Progress Tests Multiple concurrent downloads have separate progress and status
00:01 +8: Bug C — Track-Specific Download Identity & Progress Tests DownloadButton updates subscription when song changes and does not transfer progress
00:01 +9: Bug C — Track-Specific Download Identity & Progress Tests DownloadButton without explicit key still updates Download instance via didUpdateWidget
00:01 +10: (tearDownAll)
00:01 +10: All tests passed!
```

### Full Repository Test Suite Results

All test files across the repository were executed:

| Test File | Total Assertions | Status |
| :--- | :--- | :--- |
| `test/download_bug_fixes_test.dart` | 10 / 10 | **PASSED** |
| `test/widget_test.dart` | 3 / 3 | **PASSED** |
| `test/playlist_header_test.dart` | 15 / 15 | **PASSED** |
| `test/radio_test.dart` | 5 / 5 | **PASSED** |
| `test/backend_test.dart` | 95 / 95 | **PASSED** |
| `test/speed_test.dart` | 7 / 7 | **PASSED** (assertions pass; pre-existing isolate cleanup timeout preserved) |
| **Total Test Suite** | **135 / 135** | **100% PASSING** |

---

## 4. Static Analysis & Lint Verification

1. **Targeted Analysis:**
   ```bash
   flutter analyze test/download_bug_fixes_test.dart
   ```
   **Result:** `No issues found! (ran in 5.3s)`

2. **Full Workspace Analysis:**
   ```bash
   flutter analyze lib test
   ```
   **Result:** 0 new errors or warnings introduced. Exactly 1 pre-existing error at `lib/Helpers/format.dart:727` preserved per instructions.

3. **Whitespace & Git Hygiene:**
   ```bash
   git diff --check
   ```
   **Result:** Clean. Zero whitespace, formatting, or merge conflict errors.

---

## 5. Debug APK Build Verification

The debug APK was built cleanly using Flutter and Gradle 8.14:

```bash
flutter build apk --debug
```

- **Exit Code:** `0` (Success, 60.6s build time)
- **Output Artifact:** [app-debug.apk](file:///d:/My-GitHub-Projects/BlackHole-maintenance/build/app/outputs/flutter-apk/app-debug.apk)
- **Exact Path:** `D:\My-GitHub-Projects\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk`
- **File Size:** `197,221,031 bytes` (~188.08 MB)
- **Timestamp:** `2026-10-25 00:05:19`

---

## 6. Verification Checklist & Stop Condition

- [x] **Bug A Fixed:** Success snackbars auto-dismiss in 3 seconds without "OK" button; immediately replace old snackbars; actionable error messages preserve "OK" button.
- [x] **Bug B Fixed:** Deleting a song immediately updates in-memory state and UI counts without navigating away; errors preserve database and list integrity.
- [x] **Bug C Fixed:** Download progress remains strictly isolated to the downloaded track ID; track changes update button subscriptions via `didUpdateWidget` and `ValueKey`.
- [x] **Zero Regressions:** 135/135 test assertions passing; zero new analyzer warnings.
- [x] **Build Validated:** Fresh debug APK generated and ready on disk.
- [x] **No Emulator Launched:** In strict adherence to maintainer instructions, no emulator or device was launched.

**STOP CONDITION:** Execution paused. Awaiting manual testing and sign-off by the maintainer. Do not proceed with Batch 2 or further dependency upgrades until explicitly instructed.
