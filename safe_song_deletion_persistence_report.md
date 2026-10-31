# BlackHole — Safe Song Deletion & Persistence Report

**Author:** Android Media/Storage Engineer & Senior Flutter Architect  
**Date:** 2026-10-28  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  

---

## 1. Executive Summary

A critical issue observed on Android devices was that deleting songs either failed silently or deleted Hive database records while leaving orphan files on shared storage (`/storage/emulated/0/Music`). Furthermore, after uninstalling and reinstalling the application, pre-existing shared-storage songs became "stale" or undeletable due to permission restrictions or lost database references.

We implemented a unified, robust deletion and persistence engine in `lib/Helpers/song_delete_helper.dart` that handles single and bulk deletions, coordinates with active playback, deletes physical storage files safely, cleans up Hive database records, and triggers MediaStore indexing.

---

## 2. Technical Challenge & Scoped Storage Analysis

On Android 10+ (API 29+), applications operating with Scoped Storage face nuanced file lifecycle boundaries:
1. **Shared Storage Ownership:** Files downloaded to public shared storage (`/storage/emulated/0/Music`) retain file-system presence even after an app uninstall. Upon reinstall, the new app instance may not hold write ownership over legacy files created by previous app instances unless granted broad storage permissions or user approval.
2. **MediaStore Desynchronization:** If a file is deleted from the file system directly without triggering a MediaStore rescan (`scanMedia`), Android's native `on_audio_query` continues reporting the song as present, causing phantom songs in "My Music".
3. **Active Playback Conflicts:** If a deleted song is currently being played or queued by `AudioPlayerHandler`, deleting its backing file causes native decoder errors, audio engine hangs, or player crashes.

---

## 3. Architecture of SongDeleteHelper

We created `lib/Helpers/song_delete_helper.dart` with comprehensive safety features:

### 3.1 Audio Handler Playback Coordination
Before deleting any song, `SongDeleteHelper._coordinateWithAudioHandler(id, path)` checks whether the song is currently playing in `AudioPlayerHandler`:
- If the target song is actively playing and the queue contains other songs, it automatically invokes `skipToNext()`.
- If the target song is the only item in the queue, it invokes `stop()`.
- This guarantees zero decoder exceptions or lockups during file unlinking.

### 3.2 Dual-Target Deletion: Physical File + Database Record
- **Physical File Deletion:** Checks `File(filePath).existsSync()`. If present, attempts `await file.delete()`. If the file does not exist (e.g. stale record), it marks the file as removed and continues database cleanup without aborting.
- **Hive Database Cleanup:** Cleans all associated keys across `downloads`, `cache`, and playlist boxes.
- **Confirmation Dialogs:** Presents localized dialogs with clear warning messages, item counts, and confirmation actions before initiating file unlinking.

### 3.3 MediaStore Rescan with Timeout Protection
- Calls `OfflineAudioQuery.audioQuery.scanMedia(filePath)` wrapped in a 1-second timeout (`_safeScanMedia`).
- This ensures that platform channel deadlocks or mock environments in headless tests never freeze the UI thread.

### 3.4 Bulk Deletion Orchestration
- `SongDeleteHelper.deleteBulkSongs()` processes multiple songs with a unified progress indicator, batch database commit, and summary snackbar reporting the number of deleted files.

---

## 4. Verification & Automated Test Results

Automated unit and integration testing was implemented in `test/song_delete_persistence_test.dart` covering 5 critical scenarios:
1. `Single song deletion confirmation deletes physical file and Hive entry`: Passed.
2. `Single song deletion cancellation preserves file and box entry`: Passed.
3. `Bulk song deletion removes all selected files and records`: Passed.
4. `Stale record without physical file cleans up cleanly without error`: Passed.
5. `Playback coordination skips active song before file deletion`: Passed.

**Automated Test Suite Status:** 5 / 5 passed (0 failures).

