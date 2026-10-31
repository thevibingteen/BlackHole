# BlackHole — Phase F: Threat Model & Remediation Plan

**Author:** Senior Application Security Engineer & DevSecOps Lead  
**Date:** 2026-10-28  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Document Status:** Pre-Implementation Architectural Blueprint (Phase F0 Baseline)  

---

## 1. Threat Modeling Overview & Trust Boundaries

BlackHole is an open-source, client-side Android and desktop audio streaming/offline player. It interacts with several distinct trust boundaries:

```
[ UNTRUSTED INTERNET ]
   │ (HTTP/HTTPS: YouTube InnerTube, JioSaavn CDN, Spotify Web API)
   ▼
[ INTER-PROCESS COMMUNICATION (IPC) ]
   │ (Android Intents: Deep Links, Send/SendMultiple, View)
   ▼
[ APP PROCESS SANDBOX: com.shadow.blackhole ]
   │ (Dart VM, Flutter Engine, AudioService, Hive & SQLite DBs)
   ▼
[ ANDROID SHARED STORAGE ]
   │ (/storage/emulated/0/Music, Scoped MediaStore, App External Cache)
   ▼
[ HARDWARE & AUDIO ENGINE ]
   (MediaSession, AudioTrack, System Notifications)
```

### Trust Boundary Analysis
1. **Trust Boundary 1 (Incoming Intents & Links):** Any installed application on the device or web browser can send an `Intent` (`ACTION_VIEW`, `ACTION_SEND`) to `AudioServiceActivity`. Inputs from this boundary are completely untrusted and must undergo rigorous parsing, scheme validation, and domain anchoring.
2. **Trust Boundary 2 (Shared Storage Filesystem):** Files residing in `/storage/emulated/0/Music/` or external SD cards can be modified, deleted, or introduced by other applications. File unlinking must be constrained to safe canonical directories and audio formats.
3. **Trust Boundary 3 (External Data Archives):** User backup archives (`.zip`) provided via file pickers are untrusted and can contain directory traversal sequences or decompression bombs.
4. **Trust Boundary 4 (Remote API Responses):** Payloads from JioSaavn, YouTube, and Spotify APIs must be parsed defensively with type assertions and bounds checking to prevent index exceptions.

---

## 2. STRIDE Threat Categorization for BlackHole

| STRIDE Threat | Potential Vector in BlackHole | Evaluated Vulnerability | Planned Remediation |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Deceptive domain passed via intent (e.g. `fake-youtube.com`) | `SEC-ROUTE-001` (Unanchored host matching) | Strict regex & domain whitelist with anchored subdomain validation |
| **Tampering** | Path traversal in deletion path (`../../`) | `SEC-STORE-001` (Direct `file.delete()` without containment check) | Canonical path validation enforcing allowed music storage directories |
| **Repudiation** | Failed file deletion reporting success | `SEC-STORE-001` (Unhandled failure cases) | Distinct `DeleteOutcome` reporting failure to UI |
| **Information Disclosure** | Cleartext traffic interception on local networks | `SEC-MAN-001` (Global `usesCleartextTraffic`) | Targeted `network_security_config.xml` restricting cleartext to media CDNs |
| **Denial of Service** | ZIP bomb in backup restoration / unhandled `-1` index | `SEC-ARCH-001`, `SEC-ROUTE-002` | Uncompressed size/entry caps; range checks before audio playback |
| **Elevation of Privilege** | Unpinned GitHub Action hijacking CI runner | `SEC-CICD-001` | Pin actions to immutable 40-character commit SHAs |

---

## 3. Workstream Remediation Plans (Phases F1–F5)

### Phase F1: Android Permissions, File Handling & Media Safety
- **F1.1 Song Deletion Boundary Guard (`SEC-STORE-001`):**
  - Implement `_isSafeAudioPath(String path)` in `lib/Helpers/song_delete_helper.dart`.
  - Validate that the target file path:
    1. Resolves canonically to an allowed user storage area (e.g., standard external storage or app external documents).
    2. Has a genuine audio extension (`.mp3`, `.m4a`, `.flac`, `.ogg`, `.opus`, `.wav`).
    3. Cannot escape intended directories via `..` or null-byte poisoning.
- **F1.2 Playlist & Favorites Reconciliation (`SEC-STORE-002`):**
  - Add a post-deletion sweep removing deleted song IDs from `Favorite Songs` and cached custom playlists.
- **F1.3 Backup ZIP Bomb & Resource Exhaustion Defense (`SEC-ARCH-001`):**
  - In `lib/Helpers/backup_restore.dart`'s `getZipEntryNames`:
    - Enforce a maximum entry count limit: `entries.length <= 100`.
    - Enforce a maximum cumulative uncompressed byte limit: `<= 100 MB`.
    - Enforce a maximum compression ratio: `<= 100:1`.
- **F1.4 Manifest Intent Filter Cleanup (`SEC-MAN-002`):**
  - Remove empty `<data android:scheme="" />` tags from `android/app/src/main/AndroidManifest.xml`.

### Phase F2: Network, URLs, Deep Links & Sharing Security
- **F2.1 Strict Domain Anchoring in Route Handler (`SEC-ROUTE-001`):**
  - Refactor `HandleRoute.parseYouTubeUrl` and `handleRoute` in `lib/Helpers/route_handler.dart`.
  - Replace raw `contains('youtube')` with strict `Uri.tryParse()` checking:
    ```dart
    final host = uri.host.toLowerCase();
    final isValidYt = host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be' ||
        host.endsWith('.youtu.be');
    ```
  - Apply similar strict hostname anchoring for `jiosaavn.com` and `spotify.com`.
- **F2.2 Offline Play Index Range Guard (`SEC-ROUTE-002`):**
  - In `OfflinePlayHandler`: check `if (index >= 0 && index < songs.length)` before invoking `PlayerInvoke.init()`. Display a graceful snackbar if the song is not found.
- **F2.3 External App Launch Scheme Whitelist (`SEC-LINK-001`):**
  - In `lib/Helpers/app_links.dart`: restrict `AppLinks.open()` to `https`, `http`, and `mailto` schemes.
- **F2.4 Network Security Config (`SEC-MAN-001`):**
  - Author `android/app/src/main/res/xml/network_security_config.xml`.
  - Configure default base-config with `cleartextTrafficPermitted="false"`, providing domain-config overrides with `cleartextTrafficPermitted="true"` only for user-configured custom streaming domains.

### Phase F3: Persistence, Privacy & Recovery
- **F3.1 Transactional Integrity & Box Open Safety:**
  - Audit all 11 Hive boxes for concurrent access guards and corrupt box recovery routines.
  - Preserve existing non-destructive fallback behavior (never wipe entire databases upon partial read failure).
- **F3.2 Privacy & Sensitive Data Scrubbing:**
  - Confirm logging statements in production code strip sensitive user tokens, authorization codes, and file paths.

### Phase F4: Dependency & Secret Hygiene
- **F4.1 Preserve All 9 Protected Overrides:**
  - Strictly maintain `receive_sharing_intent`, `sqflite: 2.4.5`, `sqflite_android: 2.4.5`, `audiotagger`, `flutter_plugin_android_lifecycle: 2.0.35`, `collection: 1.17.1`, `flutter_rust_bridge: 1.81.0`, `http_parser: 4.0.2`, `material_design_icons_flutter`.
  - Zero mass-upgrades without explicit owner approval.
- **F4.2 No Secret Hardcoding:**
  - Ensure all API identifiers (such as `SPOTIFY_CLIENT_ID`) remain configurable via `--dart-define` and environment variables.

### Phase F5: CI/CD & Build Supply Chain Hardening
- **F5.1 Pin Third-Party Actions (`SEC-CICD-001`):**
  - Update `.github/workflows/ui-reference-build.yml` to pin all GitHub Actions to exact 40-character commit SHAs.
- **F5.2 Expand CI Test Verification (`SEC-CICD-002`):**
  - Update workflow test execution step from testing only 2 files to running `flutter test` across the full test suite.

---

## 4. Phase F6 Verification Gates & Test Plan

Upon receiving owner authorization to begin implementation:
1. **Focused Security Unit Tests:**
   - Author `test/security_hardening_test.dart` verifying:
     - `SEC-ROUTE-001`: Rejection of malicious domains (`fake-youtube.com`, `attacker.com?v=xyz`).
     - `SEC-ROUTE-002`: Handling of unknown/deleted offline song IDs without crash.
     - `SEC-STORE-001`: Rejection of deletion requests outside music storage or with non-audio extensions.
     - `SEC-ARCH-001`: Rejection of oversized archives and excessive entry counts.
     - `SEC-LINK-001`: Rejection of unsafe URI schemes in `AppLinks.open`.
2. **Full Automated Test Suite Execution:**
   - Run `flutter test --reporter expanded`.
   - Gate Requirement: 100% pass rate (315+ tests, 0 failures).
3. **Static Analysis Baseline:**
   - Run `flutter analyze lib test`.
   - Gate Requirement: 0 errors, 0 new warnings introduced.
4. **Git Diff & Whitespace Verification:**
   - Run `git diff --check`.
   - Gate Requirement: 0 whitespace/formatting errors.
5. **Candidate Checkpoint Build:**
   - Run `$env:GRADLE_USER_HOME = "D:\DevCaches\GradleUserHome"; flutter build apk --debug`.
   - Copy to `D:\BlackHole-Checkpoints\post-phase-f-security-final-YYYYMMDD-HHMMSS\app-debug.apk`.
   - Compute and verify SHA-256 and byte size.

---

## 5. Prerequisite Gate Stop

**GATE STATUS: ACTIVE.**  
In accordance with instructions:
- The Phase F0 Read-Only Baseline Audit is complete.
- Audit reports `phase_f_security_baseline_audit.md` and `phase_f_threat_model_and_remediation_plan.md` are persisted.
- **No source files, configuration, or dependencies have been altered.**
- Implementation of Phases F1–F6 is strictly held until the owner explicitly confirms physical-device acceptance of the candidate APK:
  `D:\BlackHole-Checkpoints\post-startup-responsive-song-management-final-20261028-184624\app-debug.apk`

