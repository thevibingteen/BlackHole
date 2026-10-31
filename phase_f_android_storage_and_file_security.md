# BlackHole — Phase F: Android Storage & File Security Report

**Engineering Role:** Android Storage Specialist & Application Security Engineer  
**Date:** 2026-10-30  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Base Commit (HEAD):** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Candidate Checkpoint Directory:** `D:\BlackHole-Checkpoints\post-phase-f-security-final-20261030-003224`  
**Candidate APK:** `D:\BlackHole-Checkpoints\post-phase-f-security-final-20261030-003224\app-debug.apk`  
**Candidate APK SHA-256:** `D81C0A7FC89ED2EB5F54C7DF3CD6E10F24A87CB2D8ED5B15975FE514A4AC6E50`  

---

## 1. Executive Summary

Phase F1 focused on comprehensive hardening of Android storage interactions, single and bulk song deletion, path validation, and backup archive decompression. 

In previous iterations, file deletion in `downloads.dart` and `song_delete_helper.dart` invoked `File(path).delete()` without validating that target paths were canonical, constrained to user storage, and genuinely represented valid audio/image files. Furthermore, backup archive restoration (`backup_restore.dart`) lacked strict quota caps on entry counts, uncompressed byte limits, and compression ratios.

All storage operations have now been fortified with multi-layered defensive boundary checks, canonicalization, resource quotas, and transactional rollback mechanisms.

---

## 2. Storage Distinctions & Boundary Enforcement

BlackHole manages media across multiple storage tiers:
1. **App-Private Data Sandboxes:**
   - Database files (`.hive`, `.lock`) inside app documents: `getApplicationDocumentsDirectory()`.
   - Downloaded temporary artwork inside app cache: `getTemporaryDirectory()`.
2. **App-Managed & Public Media Storage:**
   - Downloaded music tracks stored in `/storage/emulated/0/Music/` or custom user-configured folders.
   - User-imported offline tracks indexed via MediaStore `content://` URIs or filesystem paths.
3. **External Untrusted Archives:**
   - ZIP backup archives selected via file pickers.

### Implemented Path Safety Validator (`SongDeleteHelper.isPathSafeForDeletion`)
Every deletion target (both audio and artwork) is subjected to strict structural validation:
1. **Null Byte Rejection:** Rejects strings containing `\x00` to prevent C-level null byte truncation attacks.
2. **Directory Traversal Rejection:** Normalizes path separators and rejects paths containing `..` segments.
3. **Extension Whitelisting:**
   - Audio files must strictly match: `.mp3`, `.m4a`, `.flac`, `.wav`, `.ogg`, `.opus`, `.aac`, `.wma`, `.m4p`, `.mid`, `.midi`, `.webm`.
   - Artwork files must strictly match: `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`.
   - Rejects executables, scripts, databases (`.hive`, `.db`), code files, and libraries (`.so`, `.apk`, `.dart`, `.sh`).
4. **Prohibited System Paths:**
   - Blacklists `/system`, `/etc`, `/sbin`, `/bin`, `/usr`, `/dev`, `/proc`, `/sys`, `C:/Windows`, `C:/Program Files`.
5. **Android Storage Anchoring:**
   - On Android devices, enforces that target files reside strictly under `/storage/`, `/sdcard/`, or the app's sandboxed data directories (`/data/user/0/com.shadow.blackhole/`, `/data/data/com.shadow.blackhole/`).
6. **Canonical Symlink Resolution:**
   - Resolves symlinks using `File.resolveSymbolicLinksSync()` to ensure symlink pointers do not escape permitted directories.

---

## 3. Song Deletion & Lifecycle Coordination

### Single & Bulk Deletion Hardening
- **Path Pre-Validation:** In both `SongDeleteHelper.deleteSingleSong()` and `SongDeleteHelper.deleteBulkSongs()`, paths failing `isPathSafeForDeletion()` are rejected immediately without performing any I/O.
- **Audio Handler Coordination:** Before deleting any active song file, `SongDeleteHelper.coordinateWithAudioHandler()` checks `AudioPlayerHandler.mediaItem.value`. If the song being deleted is currently playing, the queue automatically advances to the next track, or stops cleanly if only one song remains.
- **MediaStore Reconciliation:** After physical deletion, `OfflineAudioQuery.audioQuery.scanMedia(path)` is triggered with a 1-second timeout to refresh Android's MediaStore index.
- **Database Consistency:** On deletion, corresponding entries are removed from `downloads` and `Favorite Songs` Hive boxes, preventing dead or unplayable references.
- **Accurate Partial Reporting:** In bulk deletion, the UI receives a breakdown of `filesDeleted`, `staleRecordsRemoved`, and `failed` count.

---

## 4. ZIP Backup & Restore Safety (`SEC-ARCH-001`)

### Resource Quotas Enforced
- **Maximum Archive Entries:** `100` entries (`maxBackupEntries`).
- **Maximum Cumulative Payload:** `100 MB` (`maxCumulativeUncompressedBytes = 100 * 1024 * 1024`).
- **Maximum Compression Ratio:** `100:1` (`maxCompressionRatio = 100.0`).

### Central Directory Pre-Inspection
Before writing any file to disk:
1. `getZipEntryMetadata(File zipFile)` inspects the ZIP Central Directory header at byte offsets `20` (compressed size) and `24` (uncompressed size).
2. `validateBackupArchiveMetadata()` verifies total entry count, accumulates uncompressed sizes, tests individual compression ratios, and ensures all file paths remain strictly inside `destinationDir` using `isPathWithinRoot`.
3. During extraction (`ZipFile.extractToDirectory`), a real-time extraction quota monitor tracks `cumulativeWrittenBytes`. If decompression exceeds 100 MB, extraction cancels immediately (`ZipFileOperation.cancel`).
4. Temporary extraction files are cleaned up safely, and existing user data is protected by a pre-restore snapshot rollback directory (`rollbackDir`).

---

## 5. Manifest Intent-Filter Cleanliness (`SEC-MAN-002`)

The three empty scheme declarations (`<data android:scheme="" />`) were removed from `android/app/src/main/AndroidManifest.xml`. Valid audio MIME types and protocols (`file`, `content`, `http`, `https`) were fully preserved.

