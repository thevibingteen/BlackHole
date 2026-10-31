# BlackHole — Phase F0: Security Baseline Audit Report

**Author:** Senior Application Security Engineer & Android Security Specialist  
**Date:** 2026-10-28  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**HEAD:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Gradle User Home:** `D:\DevCaches\GradleUserHome`  

---

## 1. Executive Summary & Audit Scope

As mandated by Phase F0 of the BlackHole Maintenance Project, a comprehensive, read-only security audit was conducted across the entire codebase, Android platform manifests, native service integrations, storage engines, networking layers, dependency trees, and CI/CD automation workflows.

In strict adherence to the **prerequisite gate**:
- **Phase F0 is strictly read-only.**
- **Zero source code, configuration files, or dependencies were modified during this audit.**
- **Physical-device acceptance of candidate `post-startup-responsive-song-management-final-20261028-184624\app-debug.apk` is held as an explicit prerequisite gate before any Phase F1–F6 implementation proceeds.**

The audit established that the core application architecture possesses robust foundational protections implemented in Phases D and E (e.g., Central Directory pre-parsing for ZIP archives, PKCE authentication for Spotify without embedded client secrets, granular monotonic startup telemetry, and debounced URL dispatch). However, specific high- and medium-priority security risks and robustness gaps were discovered that require disciplined remediation in Phase F1–F5.

---

## 2. Preflight Environment & Cryptographic Checkpoint Verification

### 2.1 Repository & Toolchain Baseline
- **Repository Root:** `D:\My-GitHub-Projects\BlackHole-maintenance`
- **Current Branch:** `maintenance/build-compatibility-upgrade`
- **Current HEAD Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`
- **Flutter Version:** `3.47.7` stable / Dart `3.13.5`
- **Gradle Version:** `8.14` / AGP `8.3.2` / Kotlin `2.0.21`
- **Compile SDK:** `36` / Target SDK: `29` / Effective Min SDK: `24`
- **Application ID:** `com.shadow.blackhole` (Version `1.15.8+39`)
- **Gradle Cache:** Dedicated cache at `D:\DevCaches\GradleUserHome` verified active and isolated.
- **Git Working Tree:** Preserves all accumulated uncommitted work from Phase D, Phase E, and song management (`git status` verified).

### 2.2 Verified Candidate Checkpoint
- **Directory:** `D:\BlackHole-Checkpoints\post-startup-responsive-song-management-final-20261028-184624`
- **Debug APK:** `app-debug.apk` (170,379,188 bytes, 162.49 MB)
  - **SHA-256:** `50646CFF92AA7F3C05F16DC4A8A743F25E55B62A6E48C4CD6A69F76DBA0A353A`
- **Profile APK:** `app-profile.apk` (101,784,798 bytes, 97.07 MB)
  - **SHA-256:** `BB62AFAAE38F6BD63C36A0A209C8ECCA23BBC2E00F6BC41B36447B3EA822DE5F`
- **Automated Regression Suite:** 307 / 307 tests passing (100% pass rate in 14.0s).
- **Static Analysis Baseline:** 369 issues (0 errors, 1 legacy localization warning, 368 infos matching historical baseline).

### 2.3 Protected Overrides & Local Forks Integrity
All 9 protected overrides in `pubspec.yaml` and all 3 local packages in `packages/` were inspected and confirmed intact:
1. `receive_sharing_intent` (local path: `packages/receive_sharing_intent`)
2. `sqflite: 2.4.5`
3. `sqflite_android: 2.4.5`
4. `audiotagger` (local path: `packages/audiotagger`)
5. `flutter_plugin_android_lifecycle: 2.0.35`
6. `collection: 1.17.1`
7. `flutter_rust_bridge: 1.81.0`
8. `http_parser: 4.0.2`
9. `material_design_icons_flutter` (local path: `packages/material_design_icons_flutter`)

---

## 3. Comprehensive Security Finding Inventory

Each finding has been categorized with a unique identifier, component path, reproduction evidence, severity rating, and impact assessment.

---

### Finding SEC-ROUTE-001: Loose Hostname Validation in Route Handler
- **Component:** `lib/Helpers/route_handler.dart:74-77, 161, 186, 200`
- **Category:** Deep Link & Input Validation
- **Severity:** Medium (Exploitable via crafted deep link / share intent)
- **Status:** Confirmed
- **Evidence:**
  ```dart
  // lib/Helpers/route_handler.dart lines 74-77:
  final bool isYtHost = host.endsWith('youtube.com') ||
      host.endsWith('youtu.be') ||
      urlStr.contains('youtube.com') ||
      urlStr.contains('youtu.be');
  ```
  1. `host.endsWith('youtube.com')` matches any unanchored domain suffix, such as `attacker-youtube.com` or `notyoutube.com`.
  2. `urlStr.contains('youtube.com')` checks substring presence anywhere in the raw URL string (including query parameters, paths, or userinfo), so a URL like `https://attacker.example.com/login?redirect=youtube.com&v=dQw4w9WgXcQ` evaluates as a legitimate YouTube link.
  3. Lines 161, 186, 200 similarly dispatch via `cleanUrl.contains('saavn')` and `cleanUrl.contains('spotify')`.
- **Potential Impact:** Spoofed external content feeds, phishing or misleading UI routes, and unvalidated intent redirection.
- **Proposed Remediation:** Enforce strict domain parsing using `Uri.tryParse()`, extracting `uri.host.toLowerCase()`, and validating against a strict whitelist with leading-dot subdomain anchoring:
  `host == 'youtube.com' || host.endsWith('.youtube.com') || host == 'youtu.be' || host.endsWith('.youtu.be')`.
- **Regression Risk:** Low. Genuine URLs remain fully supported.

---

### Finding SEC-ROUTE-002: Unhandled Index RangeError on Deep Link Offline Audio ID
- **Component:** `lib/Helpers/route_handler.dart:402-415`
- **Category:** Exception Handling & App Stability
- **Severity:** Low / Denial of Service (Crash)
- **Status:** Confirmed
- **Evidence:**
  ```dart
  // lib/Helpers/route_handler.dart line 402:
  final int index = songs.indexWhere((i) => i.id.toString() == id);
  // line 412:
  PlayerInvoke.init(
    songsList: value[1] as List<SongModel>,
    index: value[0] as int, // index is -1 if id not found!
    ...
  );
  ```
  When an incoming intent specifies an unknown or deleted audio ID, `indexWhere` returns `-1`. Passing `-1` directly to `PlayerInvoke.init()` causes an unhandled `RangeError (index): Invalid value: Valid value range is empty: -1`, crashing the application UI.
- **Potential Impact:** Application crash on malformed or deleted content URIs.
- **Proposed Remediation:** Validate `if (index >= 0 && index < songs.length)` before invoking `PlayerInvoke.init()`. If not found, gracefully display a localized snackbar: "Song not found on device".
- **Regression Risk:** Very Low.

---

### Finding SEC-STORE-001: Missing Canonical Path Containment in Song Deletion
- **Component:** `lib/Helpers/song_delete_helper.dart:89, 285`
- **Category:** Android Storage & File Security
- **Severity:** Medium (Potential Arbitrary File Unlinking)
- **Status:** Confirmed
- **Evidence:**
  ```dart
  // lib/Helpers/song_delete_helper.dart line 89:
  final file = File(filePath);
  await file.delete();
  ```
  `filePath` is passed directly from caller arguments (`SongModel.data` or Hive `downloads` map) to `File(filePath).delete()` without canonical boundary validation.
  If a corrupted or malicious database entry contains a path traversal payload (e.g., `../../../../system/file` or paths outside audio directories), the app could attempt to delete files outside the intended media storage folders.
- **Potential Impact:** Unintended file deletion if malicious or malformed path data enters the download/local song repository.
- **Proposed Remediation:** Implement `isSafeAudioPath(String filePath)` in `SongDeleteHelper`:
  - Resolve canonical path via `File(filePath).resolveSymbolicLinksSync()` (or canonical path normalization).
  - Verify path resides within authorized storage boundaries (e.g. standard external storage `/storage/emulated/0`, public `Music` / `Download` directories, or app-specific storage).
  - Verify file has an approved audio extension (`.mp3`, `.m4a`, `.flac`, `.ogg`, `.opus`, `.wav`, etc.).
- **Regression Risk:** Low. Legitimate music files remain fully eligible for deletion.

---

### Finding SEC-STORE-002: Incomplete Playlist & Favorite Reconciliation on Deletion
- **Component:** `lib/Helpers/song_delete_helper.dart:138-164, 288-310`
- **Category:** Persistence & Data Consistency
- **Severity:** Low / Integrity
- **Status:** Confirmed
- **Evidence:**
  When a song is deleted, `song_delete_helper.dart` removes its entry from the `downloads` Hive box. However, it does not purge references from the `Favorite Songs` box or custom playlist boxes in Hive, nor from local SQLite playlists.
  Consequently, deleted songs remain visible as ghost entries in playlists; tapping them later produces playback errors or broken tiles.
- **Potential Impact:** Phantom playlist entries, playback failure cascades, and degraded user experience.
- **Proposed Remediation:** On successful song deletion, call a centralized reconciliation helper that checks and removes the deleted ID from `Favorite Songs` and cached playlist entries.
- **Regression Risk:** Low.

---

### Finding SEC-ARCH-001: Lack of ZIP Bomb & Resource Exhaustion Defense in Backup Restore
- **Component:** `lib/Helpers/backup_restore.dart:96-160, 301-339`
- **Category:** Archive Security & DoS Protection
- **Severity:** Medium
- **Status:** Confirmed
- **Evidence:**
  While Phase D added comprehensive path-traversal protections (`isPathWithinRoot`, `\x00` rejection, parent directory check), `backup_restore.dart` does not limit the **uncompressed size**, **total entry count**, or **compression expansion ratio** of the incoming ZIP file.
  A crafted ZIP archive (ZIP bomb) containing thousands of nested files or a 10 GB uncompressed payload compressed into a few megabytes would pass traversal checks and attempt full decompression on device storage, leading to disk exhaustion or Out-of-Memory (OOM) crashes.
- **Potential Impact:** Denial of service, disk exhaustion, device hang.
- **Proposed Remediation:** During the existing `getZipEntryNames` Central Directory pre-scan, inspect `uncompressedSize` from the central directory header (`cdByteData.getUint32(offset + 24, Endian.little)`). Enforce:
  1. Maximum entry count limit (e.g., max 100 entries; BlackHole backups only contain 10–15 Hive boxes).
  2. Maximum cumulative uncompressed size limit (e.g., max 100 MB).
  3. Maximum compression ratio limit (e.g., max 100:1).
- **Regression Risk:** Zero for legitimate BlackHole backups (which are < 5 MB uncompressed).

---

### Finding SEC-MAN-001: Global Cleartext Traffic Enabled Without Network Security Config
- **Component:** `android/app/src/main/AndroidManifest.xml:19`
- **Category:** Network Security
- **Severity:** Medium
- **Status:** Confirmed
- **Evidence:**
  ```xml
  <application
      android:icon="@mipmap/ic_launcher"
      android:label="BlackHole"
      android:usesCleartextTraffic="true"
      android:requestLegacyExternalStorage="true">
  ```
  Setting `android:usesCleartextTraffic="true"` globally allows cleartext HTTP communication across the entire process on Android 9+ (API 28+).
  While some custom streaming radio stations or legacy HTTP audio streams might require cleartext audio playback, enabling cleartext for all network operations exposes API queries, update checks, and user traffic to local network interception and MITM attacks.
- **Potential Impact:** Network eavesdropping or request tampering on unencrypted endpoints.
- **Proposed Remediation:** In Phase F1/F2, introduce a targeted Android Network Security Config (`res/xml/network_security_config.xml`) that permits cleartext only for media streaming domains/radio endpoints while enforcing HTTPS default for all app API endpoints.
- **Regression Risk:** Low if configured properly.

---

### Finding SEC-MAN-002: Malformed Empty Scheme `<data android:scheme="" />` in Intent Filters
- **Component:** `android/app/src/main/AndroidManifest.xml:148, 168, 297`
- **Category:** Android Manifest Hygiene
- **Severity:** Low / Hygiene
- **Status:** Confirmed
- **Evidence:**
  Lines 148, 168, and 297 declare:
  `<data android:scheme="" />`
  In Android intent resolution, an empty string scheme is invalid and triggers parser warnings in Android tooling or unexpected intent routing behavior.
- **Potential Impact:** Unintended intent filter matching or OS platform warnings.
- **Proposed Remediation:** Remove redundant `<data android:scheme="" />` tags, retaining valid schemes (`file`, `content`, `http`, `https`, `ftp`).
- **Regression Risk:** Zero.

---

### Finding SEC-LINK-001: `AppLinks.open()` Lacks Scheme Whitelist
- **Component:** `lib/Helpers/app_links.dart:75-78`
- **Category:** External Intent Launching
- **Severity:** Low
- **Status:** Confirmed
- **Evidence:**
  ```dart
  // lib/Helpers/app_links.dart line 75:
  final uri = Uri.parse(sanitized);
  final success = await launcher(uri, mode: mode);
  ```
  `AppLinks.open()` parses arbitrary input strings without verifying that `uri.scheme` is one of the intended web protocols (`https`, `http`, `mailto`). If called with `javascript:`, `tel:`, or dangerous custom URI schemes, it forwards them to `launchUrl`.
- **Potential Impact:** Unintended external application or protocol handler invocation.
- **Proposed Remediation:** Add a scheme validation check: `if (!['https', 'http', 'mailto'].contains(uri.scheme.toLowerCase())) return false;`.
- **Regression Risk:** Zero for legitimate external web and email links.

---

### Finding SEC-CICD-001: Unpinned Third-Party GitHub Actions in CI Workflow
- **Component:** `.github/workflows/ui-reference-build.yml:24, 41, 47, 110, 117, 124`
- **Category:** Supply Chain & CI/CD Security
- **Severity:** Low / Supply Chain
- **Status:** Confirmed
- **Evidence:**
  Actions are referenced by floating major tags (e.g. `actions/checkout@v7`, `actions/setup-java@v6`, `subosito/flutter-action@v2`, `actions/upload-artifact@v7`).
  Furthermore, `@v7` and `@v6` tags do not match current official upstream GitHub Action versions (current checkout is v4, upload-artifact is v4).
- **Potential Impact:** Workflow run failures or supply-chain tampering if tags are redirected.
- **Proposed Remediation:** Pin actions to immutable full 40-character commit SHAs with descriptive version comments.
- **Regression Risk:** Zero.

---

### Finding SEC-CICD-002: Incomplete Test Execution in CI Workflow
- **Component:** `.github/workflows/ui-reference-build.yml:90`
- **Category:** CI/CD Test Coverage
- **Severity:** Low / Quality Assurance
- **Status:** Confirmed
- **Evidence:**
  `flutter test test/backend_test.dart test/widget_test.dart`
  The workflow only executes 2 test files, omitting the remaining 300+ automated regression tests authored across Phases D, E, and song management.
- **Potential Impact:** Regressions in core features, accessibility, audio engine, or layout are not caught by CI runner.
- **Proposed Remediation:** Update test step to execute `flutter test` across all unit and regression suites.
- **Regression Risk:** Zero.

---

## 4. Areas Confirmed Clean and Robust

1. **No Embedded Secrets / Credentials:** Thorough repository scanning confirmed zero checked-in keystores, `.jks` files, `key.properties`, private signing credentials, or hardcoded API keys.
2. **Spotify PKCE Implementation:** `lib/APIs/spotify_api.dart` uses standard PKCE with `SPOTIFY_CLIENT_ID` passed via `--dart-define` with no hardcoded secret.
3. **HTTP Call Timeouts:** Active network requests across `lib/` consistently employ `.timeout()` ranging from 8s to 15s.
4. **Download Filename Sanitization:** `lib/Services/download.dart` regex-sanitizes special characters (`[\.\\\*\:\"\?#/;\|]`) to prevent path traversal.
5. **Debounced Sharing & Launcher:** `AppLinks` and `HandleRoute` incorporate robust 1s–3s debounce logic preventing intent replay or loop exploitation.
6. **Canonical Path Resolution:** `backup_restore.dart` utilizes `p.canonicalize`, `p.isWithin`, and symlink resolution.

---

## 5. Audit Summary Matrix

| ID | Component | Severity | Category | Status | Proposed Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `SEC-ROUTE-001` | `lib/Helpers/route_handler.dart` | **Medium** | Deep Link Validation | Confirmed | Enforce strict domain parsing & anchored subdomain matching |
| `SEC-STORE-001` | `lib/Helpers/song_delete_helper.dart` | **Medium** | Storage Safety | Confirmed | Add canonical path boundary & audio extension validation |
| `SEC-ARCH-001` | `lib/Helpers/backup_restore.dart` | **Medium** | Archive Security | Confirmed | Add ZIP bomb size, entry count, and ratio limits in Central Directory scan |
| `SEC-MAN-001` | `android/app/src/main/AndroidManifest.xml` | **Medium** | Network Security | Confirmed | Add Network Security Config restricting cleartext to media domains |
| `SEC-ROUTE-002` | `lib/Helpers/route_handler.dart` | **Low** | Stability / Exception | Confirmed | Guard against `-1` index crash in `OfflinePlayHandler` |
| `SEC-STORE-002` | `lib/Helpers/song_delete_helper.dart` | **Low** | Data Consistency | Confirmed | Clean deleted IDs from `Favorite Songs` and playlists |
| `SEC-MAN-002` | `android/app/src/main/AndroidManifest.xml` | **Low** | Manifest Hygiene | Confirmed | Remove invalid `<data android:scheme="" />` tags |
| `SEC-LINK-001` | `lib/Helpers/app_links.dart` | **Low** | URL Launching | Confirmed | Add scheme whitelist (`https`, `http`, `mailto`) |
| `SEC-CICD-001` | `.github/workflows/ui-reference-build.yml` | **Low** | CI/CD Supply Chain | Confirmed | Pin actions to immutable commit SHAs |
| `SEC-CICD-002` | `.github/workflows/ui-reference-build.yml` | **Low** | CI/CD Quality | Confirmed | Expand CI test invocation to full test suite |

---

## 6. Prerequisite Gate Status

**Status: GATE ACTIVE — STANDING BY FOR OWNER ACCEPTANCE.**
In accordance with Section 0 & 3 of the Phase F Master Prompt, all source code and configurations remain strictly unmodified. Phase F1–F6 implementation will commence only upon explicit owner acceptance of the candidate APK:
`D:\BlackHole-Checkpoints\post-startup-responsive-song-management-final-20261028-184624\app-debug.apk`

