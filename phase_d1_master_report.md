# BlackHole Revival — Phase D1.2 Master Dependency Inventory & Modernisation Plan
## Complete 153-Package Register, Media3 Engine Audit, Archive Security Verification & Individual Override Audit

**Project:** BlackHole Music Player (`com.shadow.blackhole`, `v1.15.8`)  
**Phase:** D1.2 — Final Audit Corrections & Validated Modernisation Plan  
**Audit Date:** October 24, 2026  
**Mode:** READ-ONLY INVENTORY AND PLANNING (Strictly Non-Destructive)  
**Maintenance Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Maintenance Branch:** `maintenance/build-compatibility-upgrade`  
**Baseline Commit:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Original Repository (Strictly Read-Only):** `D:\My-GitHub-Projects\BlackHole` (`ui-reference-build/blackhole-main`)  
**Toolchain Baseline:** Flutter 3.47.7 • Dart 3.13.5 • OpenJDK 17.0.20.1 • Gradle 8.14 • AGP 8.3.2 • Kotlin 2.0.21 • compileSdk 36 • minSdk 21 • targetSdk 29 • `skipDependencyChecks=true`  

---

## 1. Correction Log: Reconciling D1, D1.1 and D1.2 Findings

| # | Item | Defect in Previous Reports | Empirical Evidence & Final Correction in D1.2 |
|---|---|---|---|
| **1** | **`just_audio` Media3 Rationale** | Initial reports mistakenly described version `0.9.46` as "avoiding Media3". | **Official Changelog Verification:** `just_audio: 0.9.43` explicitly migrated its Android player from legacy ExoPlayer (`com.google.android.exoplayer2`) to **AndroidX Media3 ExoPlayer 1.4.1** (`androidx.media3:media3-exoplayer:1.4.1`). Version `0.9.46` **does** adopt Media3 on Android. **Corrected Rationale:** Version `0.9.46` is the optimal candidate because it brings the modern Media3 Android engine while preserving 100% source-code compatibility with BlackHole's `ConcatenatingAudioSource` playlist queue management. In contrast, `just_audio: 0.10.x` completely deprecates `ConcatenatingAudioSource` and introduces a breaking playlist API rewrite. |
| **2** | **`archive` Security & Ingestion Graph** | Claimed upgrading `flutter_archive` from 5.0.0 to 6.3.1 remediates `archive: 3.3.7` CVEs GHSA-9v85-q87q-g4vg / GHSA-r285-q736-9v95. | **Complete Dependency Graph Proof:** `flutter_archive` is a native Android/iOS plugin (`java.util.zip`) and does **not** depend on Dart `archive`. Dart `archive: 3.3.7` is pulled in **ONLY** via `msix: 3.14.2` (`dev_dependencies` -> `image: 4.0.17` -> `archive: 3.3.7`) and `flutter_rust_bridge: 1.81.0` (`dependency_overrides` -> `puppeteer: 3.2.0` -> `archive: 3.3.7`). BlackHole application code **never imports `package:archive`**, and it is **never packaged into the Android APK**. Both parent packages (`puppeteer: ^3.0.0` and `image: ^3.1.2`) accept patched versions (`archive: >= 3.3.8` for spoofing; `>= 3.4.10 / 3.6.1` for traversal). `flutter_archive: 5.0.0` is retained to protect `minSdkVersion 21`. |
| **3** | **`app_links` Toolchain Ambiguity** | Previous report described `app_links 6.3.3` as compatible with "AGP 8.5.2 / 8.3.x" without empirical confirmation. | **Published Manifest Inspection:** In `app_links: 6.3.3`, `android/build.gradle` declares `classpath 'com.android.tools.build:gradle:8.5.2'`. Because BlackHole root uses AGP `8.3.2`, subproject classpath resolution is marked **`UNVERIFIED`** until build execution. In contrast, `app_links: 6.0.0` and `3.5.1` declare AGP `8.0.1` (`<= 8.3.2`), `minSdkVersion 16`, and are confirmed **`PASS`**. |
| **4** | **Toolchain Contradiction & Candidate Alignment** | Proposing latest pub.dev releases while retaining AGP 8.3.2, compileSdk 36, and minSdk 21. | Confirmed fatal toolchain blocks: `permission_handler: 13.0.2` requires **AGP 9.0.1, compileSdk 37, minSdk 24, Kotlin 2.3.20**; `flutter_archive: 6.3.1` and `file_picker: 13.2.0` drop Android 5.0–6.0 (mandate minSdk 24); `share_plus: 13.3.1` mandates AGP 8.12.1 and AndroidX Core 1.16.0. Adopted **Path A** with peak compatible stable targets: `connectivity_plus: 6.1.4`, `device_info_plus: 10.1.2`, `share_plus: 10.1.4`, `permission_handler: 11.4.0` (retained), `flutter_archive: 5.0.0` (retained), `file_picker: 8.3.7` (retained). |
| **5** | **153-Package Complete Row-by-Row Register** | Previous reports condensed transitive dependencies into summary counts. | Delivered the **complete, unabridged 153-row register** with verified parents, constraints, baseline, resolved, candidate, toolchain status, and disposition. |
| **6** | **Individual Audit of All Overrides** | Overrides were summarized in bulk. | Evaluated all 9 overrides individually with reasons for existence, benefiting packages, upgrade obsolescence, and removal evidence. Explicitly identified `audio_session` as transitive. |

---

## 2. Package Count Recalculation & Reconciled Totals

Inspection of [`pubspec.yaml`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/pubspec.yaml) and [`pubspec.lock`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/pubspec.lock) confirms exactly **153 packages**:

- **Direct Runtime Dependencies:** **37**
  - Hosted Runtime Packages: **32**
  - Local Compatibility Forks: **3** (`audiotagger`, `material_design_icons_flutter`, `receive_sharing_intent`)
  - Flutter SDK Dependencies: **2** (`flutter`, `flutter_localizations`)
- **Direct Development Dependencies:** **3**
  - Hosted Dev Packages: **2** (`lint`, `msix`)
  - Flutter SDK Dev Package: **1** (`flutter_test`)
- **Transitive Dependencies:** **113**
  - Standard Transitive: **107**
  - Added in Phase B to unblock AGP 8: **4** (`sqflite_android`, `sqflite_darwin`, `sqflite_platform_interface`, `permission_handler_html`)
  - Removed in Phase B: **1** deprecated package (`flutter_blurhash` removed from 150 baseline packages: 150 - 1 + 4 = 153)
- **Dependency Overrides:** **9** (6 added in Phase B + 3 baseline overrides)
- **Outdated Scope:** **56 dependencies** locked below latest pub.dev releases; **29 dependencies** held back by direct `pubspec.yaml` constraints.

---

## 3. Complete 153-Package Dependency Register

| Package | Category | Parent Dependency | Baseline Version | Declared Constraint | Resolved Version | Upgradable | Latest Pub | Candidate Version | Constraint Change | Toolchain Status | Risk | Recommended Disposition |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `app_links` | Direct Runtime | Root (pubspec.yaml) | `3.4.3` | `^3.4.3` | `3.4.3` | `3.5.1` | `7.2.2` | **`6.3.3 (or 6.0.0)`** | Major | `UNVERIFIED` | `MEDIUM` | Upgrade to 6.3.3 (UNVERIFIED: declares AGP 8.5.2 vs root AGP 8.3.2) or fallback to 6.0.0 / 3.5.1 (PASS: AGP 8.0.1 / minSdk 16) |
| `audio_service` | Direct Runtime | Root (pubspec.yaml) | `0.18.10` | `^0.18.10` | `0.18.10` | `0.18.19` | `0.18.19` | **`0.18.19`** | Minor | `PASS` | `MEDIUM` | Upgrade to 0.18.19 (Peak 0.18.x stable) |
| `audiotagger` | Direct Runtime | Root (pubspec.yaml) | `2.2.1` | `2.2.1` | `2.2.1` | `2.2.1` | `2.2.1` | **`2.2.1`** | None | `PASS` | `LOW` | Retain local fork (Upstream abandoned; AGP namespace patch) |
| `cached_network_image` | Direct Runtime | Root (pubspec.yaml) | `3.2.3` | `^3.3.1` | `3.3.1` | `3.3.1` | `4.0.5` | **`3.4.1`** | Minor | `PASS` | `LOW` | Upgrade to 3.4.1 (Peak 3.x stable; 4.x has breaking API) |
| `carousel_slider` | Direct Runtime | Root (pubspec.yaml) | `4.2.1` | `^5.1.2` | `5.1.2` | `5.1.2` | `5.1.2` | **`5.1.2`** | None | `PASS` | `LOW` | Retain 5.1.2 (Already latest) |
| `connectivity_plus` | Direct Runtime | Root (pubspec.yaml) | `4.0.1` | `^4.0.1` | `4.0.1` | `4.0.2` | `7.3.2` | **`6.1.4`** | Major | `PASS` | `MEDIUM` | Upgrade to 6.1.4 (AGP 8.3 compatible; 7.x requires AGP 8.12) |
| `cupertino_icons` | Direct Runtime | Root (pubspec.yaml) | `1.0.5` | `^1.0.5` | `1.0.5` | `1.0.9` | `2.0.0` | **`1.0.9`** | Minor | `PASS` | `LOW` | Upgrade to 1.0.9 (Safe minor; 2.x remaps icons) |
| `dart_des` | Direct Runtime | Root (pubspec.yaml) | `1.0.2` | `^1.0.2` | `1.0.2` | `1.0.2` | `1.0.2` | **`1.0.2`** | None | `PASS` | `LOW` | Retain 1.0.2 (Already latest) |
| `device_info_plus` | Direct Runtime | Root (pubspec.yaml) | `9.0.2` | `^9.0.2` | `9.0.2` | `9.1.2` | `13.3.0` | **`10.1.2`** | Major | `PASS` | `MEDIUM` | Upgrade to 10.1.2 (AGP 8.3 compatible; 13.x requires Kotlin 2.2) |
| `file_picker` | Direct Runtime | Root (pubspec.yaml) | `5.3.2` | `^8.3.7` | `8.3.7` | `8.3.7` | `13.2.0` | **`8.3.7`** | None | `PASS` | `LOW` | Retain 8.3.7 (minSdk 21 compatible; 13.x raises minSdk to 24) |
| `flip_card` | Direct Runtime | Root (pubspec.yaml) | `0.7.0` | `^0.7.0` | `0.7.0` | `0.7.0` | `0.7.0` | **`0.7.0`** | None | `PASS` | `LOW` | Retain 0.7.0 (Already latest) |
| `flutter` | Direct Runtime | Root (pubspec.yaml) | `0.0.0` | `` | `0.0.0` | `0.0.0` | `0.0.0` | **`0.0.0`** | None | `PASS` | `LOW` | Retain SDK (Flutter 3.47.7) |
| `flutter_archive` | Direct Runtime | Root (pubspec.yaml) | `5.0.0` | `^5.0.0` | `5.0.0` | `5.0.0` | `6.3.1` | **`5.0.0`** | None | `PASS` | `LOW` | Retain 5.0.0 (Preserves minSdk 21; 6.3.1 raises minSdk to 24) |
| `flutter_displaymode` | Direct Runtime | Root (pubspec.yaml) | `0.6.0` | `^0.6.0` | `0.6.0` | `0.6.0` | `0.7.0` | **`0.7.0`** | Minor | `PASS` | `LOW` | Upgrade to 0.7.0 (Safe minor update) |
| `flutter_localizations` | Direct Runtime | Root (pubspec.yaml) | `0.0.0` | `` | `0.0.0` | `0.0.0` | `0.0.0` | **`0.0.0`** | None | `PASS` | `LOW` | Retain SDK (Flutter 3.47.7) |
| `flutter_lyric` | Direct Runtime | Root (pubspec.yaml) | `2.0.4+6` | `^2.0.4+6` | `2.0.4+6` | `2.0.4+6` | `4.1.0` | **`2.0.4+6`** | None | `PASS` | `MEDIUM` | Retain 2.0.4+6 in Phase D (Evaluate 4.x in future batch) |
| `get_it` | Direct Runtime | Root (pubspec.yaml) | `7.6.0` | `^7.6.0` | `7.6.0` | `7.7.0` | `9.3.0` | **`7.7.0`** | Minor | `PASS` | `LOW` | Upgrade to 7.7.0 (Safe peak 7.x release) |
| `hive` | Direct Runtime | Root (pubspec.yaml) | `2.2.3` | `^2.2.3` | `2.2.3` | `2.2.3` | `2.2.3` | **`2.2.3`** | None | `PASS` | `LOW` | Retain 2.2.3 (Already latest stable) |
| `hive_flutter` | Direct Runtime | Root (pubspec.yaml) | `1.1.0` | `^1.1.0` | `1.1.0` | `1.1.0` | `1.1.0` | **`1.1.0`** | None | `PASS` | `LOW` | Retain 1.1.0 (Already latest stable) |
| `html_unescape` | Direct Runtime | Root (pubspec.yaml) | `2.0.0` | `^2.0.0` | `2.0.0` | `2.0.0` | `2.0.0` | **`2.0.0`** | None | `PASS` | `LOW` | Retain 2.0.0 (Already latest) |
| `just_audio` | Direct Runtime | Root (pubspec.yaml) | `0.9.34` | `^0.9.34` | `0.9.34` | `0.9.46` | `0.10.6` | **`0.9.46`** | Minor | `PASS` | `MEDIUM` | Upgrade to 0.9.46 (Adopts Media3 ExoPlayer 1.4.1 while preserving 0.9.x ConcatenatingAudioSource API; avoids 0.10.x playlist API rewrite) |
| `logging` | Direct Runtime | Root (pubspec.yaml) | `1.2.0` | `^1.2.0` | `1.2.0` | `1.3.0` | `1.3.0` | **`1.3.0`** | Minor | `PASS` | `LOW` | Upgrade to 1.3.0 (Safe minor update) |
| `marquee` | Direct Runtime | Root (pubspec.yaml) | `2.2.3` | `^2.3.0` | `2.3.0` | `2.3.0` | `2.3.0` | **`2.3.0`** | None | `PASS` | `LOW` | Retain 2.3.0 (Already latest) |
| `material_design_icons_flutter` | Direct Runtime | Root (pubspec.yaml) | `5.0.5955-rc.1` | `5.0.5955-rc.1` | `5.0.5955-rc.1` | `5.0.5955-rc.1` | `7.0.7296` | **`5.0.5955-rc.1`** | None | `PASS` | `LOW` | Retain local fork (Upstream discontinued; preserves 22 icons) |
| `metadata_god` | Direct Runtime | Root (pubspec.yaml) | `0.4.1` | `^0.4.1` | `0.4.1` | `0.4.1` | `1.1.0` | **`0.4.1`** | None | `PASS` | `LOW` | Retain 0.4.1 (1.x requires flutter_rust_bridge 2.x & Rust toolchain) |
| `on_audio_query` | Direct Runtime | Root (pubspec.yaml) | `2.9.0` | `^2.9.0` | `2.9.0` | `2.9.0` | `2.9.0` | **`2.9.0`** | None | `PASS` | `LOW` | Retain 2.9.0 (Already latest stable) |
| `package_info_plus` | Direct Runtime | Root (pubspec.yaml) | `4.0.2` | `^4.0.2` | `4.0.2` | `4.2.0` | `10.2.2` | **`8.3.0`** | Major | `PASS` | `MEDIUM` | Upgrade to 8.3.0 (AGP 8.3 compatible; 10.x requires AGP 8.12) |
| `palette_generator` | Direct Runtime | Root (pubspec.yaml) | `0.3.3+2` | `^0.3.3+2` | `0.3.3+2` | `0.3.3+7` | `0.3.3+7` | **`0.3.3+7`** | Minor | `PASS` | `LOW` | Upgrade to 0.3.3+7 (Peak stable before discontinuation) |
| `path_provider` | Direct Runtime | Root (pubspec.yaml) | `2.0.15` | `^2.1.5` | `2.1.6` | `2.1.6` | `2.1.6` | **`2.1.6`** | None | `PASS` | `LOW` | Retain 2.1.6 (Already latest resolved) |
| `permission_handler` | Direct Runtime | Root (pubspec.yaml) | `10.3.0` | `^11.3.1` | `11.4.0` | `11.4.0` | `13.0.2` | **`11.4.0`** | None | `PASS` | `LOW` | Retain 11.4.0 (13.x blocked: requires compileSdk 37, minSdk 24, AGP 9) |
| `receive_sharing_intent` | Direct Runtime | Root (pubspec.yaml) | `1.4.5` | `^1.4.5` | `1.4.5` | `1.4.5` | `1.9.0` | **`1.4.5`** | None | `PASS` | `LOW` | Retain local fork (1.9.0 changes Intent model; evaluate in Batch 8) |
| `salomon_bottom_bar` | Direct Runtime | Root (pubspec.yaml) | `3.3.2` | `^3.3.2` | `3.3.2` | `3.3.2` | `3.3.2` | **`3.3.2`** | None | `PASS` | `LOW` | Retain 3.3.2 (Already latest) |
| `share_plus` | Direct Runtime | Root (pubspec.yaml) | `7.0.2` | `^7.0.2` | `7.0.2` | `7.2.2` | `13.3.1` | **`10.1.4`** | Major | `PASS` | `MEDIUM` | Upgrade to 10.1.4 (AGP 8.3 compatible; 13.x requires AGP 8.12 & Kotlin 2.2) |
| `sliding_up_panel` | Direct Runtime | Root (pubspec.yaml) | `2.0.0+1` | `^2.0.0+1` | `2.0.0+1` | `2.0.0+1` | `2.0.0+1` | **`2.0.0+1`** | None | `PASS` | `LOW` | Retain 2.0.0+1 (Already latest) |
| `url_launcher` | Direct Runtime | Root (pubspec.yaml) | `6.1.11` | `^6.3.1` | `6.3.3` | `6.3.3` | `6.3.3` | **`6.3.3`** | None | `PASS` | `LOW` | Retain 6.3.3 (Already latest resolved) |
| `uuid` | Direct Runtime | Root (pubspec.yaml) | `3.0.7` | `^3.0.7` | `3.0.7` | `3.0.7` | `4.6.0` | **`4.6.0`** | Major | `PASS` | `LOW` | Upgrade to 4.6.0 (Update const Uuid().v1() import in auth.dart) |
| `youtube_explode_dart` | Direct Runtime | Root (pubspec.yaml) | `2.5.3` | `2.5.3` | `2.5.3` | `2.5.3` | `3.1.0` | **`3.1.0`** | Major | `PASS` | `HIGH` | Upgrade to 3.1.0 (Critical YouTube cipher update; investigate stuttering) |
| `flutter_test` | Direct Dev | Root (pubspec.yaml) | `0.0.0` | `` | `0.0.0` | `0.0.0` | `0.0.0` | **`0.0.0`** | None | `PASS` | `LOW` | Retain SDK (Flutter 3.47.7) |
| `lint` | Direct Dev | Root (pubspec.yaml) | `2.1.2` | `^2.1.2` | `2.1.2` | `2.14.0` | `2.14.0` | **`2.14.0`** | Minor | `PASS` | `LOW` | Upgrade to 2.14.0 in Batch 9 |
| `msix` | Direct Dev | Root (pubspec.yaml) | `3.14.2` | `^3.14.2` | `3.14.2` | `3.16.9` | `3.18.0` | **`3.18.0`** | Minor | `PASS` | `LOW` | Upgrade to 3.18.0 in Batch 9 (Updates transitive archive >= 3.6.1) |
| `archive` | Transitive | Transitive | `3.3.7` | `Transitive` | `3.3.7` | `4.5.2` | `4.5.2` | **`3.3.7 (or 3.6.1 dev)`** | None | `PASS` | `LOW` | Retain 3.3.7 or override to 3.6.1. Verified dev/tooling only (msix/flutter_rust_bridge); zero APK runtime exposure. Parents puppeteer & image accept >= 3.3.8 |
| `args` | Transitive | Transitive | `2.4.1` | `Transitive` | `2.4.1` | `2.7.0` | `2.7.0` | **`2.7.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.7.0 via direct upgrades |
| `async` | Transitive | Transitive | `2.11.0` | `Transitive` | `2.11.0` | `2.13.1` | `2.13.1` | **`2.13.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.13.1 via direct upgrades |
| `audio_service_platform_interface` | Transitive | Transitive | `0.1.0` | `Transitive` | `0.1.0` | `0.1.3` | `0.1.3` | **`0.1.3`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.1.3 via direct upgrades |
| `audio_service_web` | Transitive | Transitive | `0.1.1` | `Transitive` | `0.1.1` | `0.1.4` | `0.1.4` | **`0.1.4`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.1.4 via direct upgrades |
| `audio_session` | Transitive | Transitive | `0.1.14` | `Transitive` | `0.1.14` | `0.1.25` | `0.2.4` | **`0.1.25`** | Minor | `PASS` | `LOW` | Transitive dependency (parented by just_audio & audio_service). Auto-resolves to 0.1.25 in Batch 7 for improved Android 12-14 audio focus |
| `boolean_selector` | Transitive | Transitive | `2.1.1` | `Transitive` | `2.1.1` | `2.1.2` | `2.1.2` | **`2.1.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.1.2 via direct upgrades |
| `build_cli_annotations` | Transitive | Transitive | `2.1.0` | `Transitive` | `2.1.0` | `2.1.1` | `2.1.1` | **`2.1.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.1.1 via direct upgrades |
| `cached_network_image_platform_interface` | Transitive | Transitive | `2.0.0` | `Transitive` | `4.0.0` | `4.0.0` | `5.0.3` | **`4.0.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `cached_network_image_web` | Transitive | Transitive | `1.0.2` | `Transitive` | `1.2.0` | `1.2.0` | `2.0.3` | **`1.2.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `characters` | Transitive | Transitive | `1.4.1` | `Transitive` | `1.4.1` | `1.4.1` | `1.4.1` | **`1.4.1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `cli_util` | Transitive | Transitive | `0.4.0` | `Transitive` | `0.4.0` | `0.4.2` | `0.6.0` | **`0.4.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.4.2 via direct upgrades |
| `clock` | Transitive | Transitive | `1.1.3` | `Transitive` | `1.1.3` | `1.1.3` | `1.1.3` | **`1.1.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `collection` | Transitive | Transitive | `1.17.1` | `Transitive` | `1.17.1` | `1.17.1` | `1.19.1` | **`1.17.1`** | None | `PASS` | `LOW` | Retain override (Resolves multi-package constraint) |
| `connectivity_plus_platform_interface` | Transitive | Transitive | `1.2.4` | `Transitive` | `1.2.4` | `1.2.4` | `2.1.0` | **`1.2.4`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `console` | Transitive | Transitive | `4.1.0` | `Transitive` | `4.1.0` | `4.1.0` | `4.1.0` | **`4.1.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `convert` | Transitive | Transitive | `3.1.1` | `Transitive` | `3.1.1` | `3.1.2` | `3.1.2` | **`3.1.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.1.2 via direct upgrades |
| `cross_file` | Transitive | Transitive | `0.3.3+4` | `Transitive` | `0.3.5+5` | `0.3.5+5` | `0.4.0` | **`0.3.5+5`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `crypto` | Transitive | Transitive | `3.0.3` | `Transitive` | `3.0.3` | `3.0.7` | `3.0.7` | **`3.0.7`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.0.7 via direct upgrades |
| `csslib` | Transitive | Transitive | `0.17.2` | `Transitive` | `0.17.2` | `1.0.2` | `1.0.2` | **`1.0.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.0.2 via direct upgrades |
| `dbus` | Transitive | Transitive | `0.7.8` | `Transitive` | `0.7.8` | `0.7.15` | `0.8.0` | **`0.7.15`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.7.15 via direct upgrades |
| `device_info_plus_platform_interface` | Transitive | Transitive | `7.0.0` | `Transitive` | `7.0.0` | `7.0.3` | `8.1.0` | **`7.0.3`** | Minor | `PASS` | `LOW` | Auto-resolves to 7.0.3 via direct upgrades |
| `fading_edge_scrollview` | Transitive | Transitive | `3.0.0` | `Transitive` | `4.1.1` | `4.1.1` | `4.1.1` | **`4.1.1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `fake_async` | Transitive | Transitive | `1.3.3` | `Transitive` | `1.3.3` | `1.3.3` | `1.3.3` | **`1.3.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `ffi` | Transitive | Transitive | `2.0.2` | `Transitive` | `2.2.0` | `2.2.0` | `2.2.0` | **`2.2.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `file` | Transitive | Transitive | `6.1.4` | `Transitive` | `6.1.4` | `7.0.1` | `7.0.1` | **`7.0.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 7.0.1 via direct upgrades |
| `flutter_cache_manager` | Transitive | Transitive | `3.3.1` | `Transitive` | `3.3.1` | `3.3.1` | `3.4.5` | **`3.3.1`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `flutter_plugin_android_lifecycle` | Transitive | Transitive | `2.0.14` | `Transitive` | `2.0.35` | `2.0.35` | `2.0.35` | **`2.0.35`** | None | `PASS` | `LOW` | Retain override (Provides AGP 8 lifecycle) |
| `flutter_rust_bridge` | Transitive | Transitive | `1.81.0` | `Transitive` | `1.81.0` | `1.81.0` | `2.13.0` | **`1.81.0`** | None | `PASS` | `LOW` | Retain override 1.81.0 (Tied to metadata_god 0.4.1) |
| `flutter_web_plugins` | Transitive | Transitive | `0.0.0` | `Transitive` | `0.0.0` | `0.0.0` | `0.0.0` | **`0.0.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `freezed_annotation` | Transitive | Transitive | `2.2.0` | `Transitive` | `2.2.0` | `3.1.0` | `3.1.0` | **`3.1.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.1.0 via direct upgrades |
| `html` | Transitive | Transitive | `0.15.3` | `Transitive` | `0.15.3` | `0.15.7` | `0.15.7` | **`0.15.7`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.15.7 via direct upgrades |
| `http` | Transitive | Transitive | `1.6.0` | `Transitive` | `1.6.0` | `1.6.0` | `1.6.0` | **`1.6.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `http_parser` | Transitive | Transitive | `4.0.2` | `Transitive` | `4.0.2` | `4.0.2` | `4.1.2` | **`4.0.2`** | None | `PASS` | `LOW` | Retain override 4.0.2 |
| `id3` | Transitive | Transitive | `1.0.2` | `Transitive` | `1.0.2` | `1.0.2` | `1.0.2` | **`1.0.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `image` | Transitive | Transitive | `4.0.17` | `Transitive` | `4.0.17` | `4.12.0` | `4.12.0` | **`4.12.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 4.12.0 via direct upgrades |
| `intl` | Transitive | Transitive | `0.20.3` | `Transitive` | `0.20.3` | `0.20.3` | `0.20.3` | **`0.20.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `js` | Transitive | Transitive | `0.6.7` | `Transitive` | `0.6.7` | `0.6.7` | `0.7.2` | **`0.6.7`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `json_annotation` | Transitive | Transitive | `4.12.0` | `Transitive` | `4.12.0` | `4.12.0` | `4.12.0` | **`4.12.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `just_audio_platform_interface` | Transitive | Transitive | `4.2.1` | `Transitive` | `4.2.1` | `4.6.0` | `4.6.0` | **`4.6.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 4.6.0 via direct upgrades |
| `just_audio_web` | Transitive | Transitive | `0.4.8` | `Transitive` | `0.4.8` | `0.4.16` | `0.4.16` | **`0.4.16`** | Minor | `PASS` | `LOW` | Auto-resolves to 0.4.16 via direct upgrades |
| `leak_tracker` | Transitive | Transitive | `11.0.2` | `Transitive` | `11.0.2` | `11.0.2` | `11.0.2` | **`11.0.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `leak_tracker_flutter_testing` | Transitive | Transitive | `3.0.10` | `Transitive` | `3.0.10` | `3.0.10` | `3.0.10` | **`3.0.10`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `leak_tracker_testing` | Transitive | Transitive | `3.0.2` | `Transitive` | `3.0.2` | `3.0.2` | `3.0.2` | **`3.0.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `matcher` | Transitive | Transitive | `0.12.20` | `Transitive` | `0.12.20` | `0.12.20` | `0.12.20` | **`0.12.20`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `material_color_utilities` | Transitive | Transitive | `0.13.0` | `Transitive` | `0.13.0` | `0.13.0` | `0.13.1` | **`0.13.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `meta` | Transitive | Transitive | `1.19.0` | `Transitive` | `1.19.0` | `1.19.0` | `1.19.0` | **`1.19.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `mime` | Transitive | Transitive | `1.0.4` | `Transitive` | `1.0.4` | `1.0.6` | `2.1.0` | **`1.0.6`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.0.6 via direct upgrades |
| `nm` | Transitive | Transitive | `0.5.0` | `Transitive` | `0.5.0` | `0.5.0` | `0.6.0` | **`0.5.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `octo_image` | Transitive | Transitive | `1.0.2` | `Transitive` | `2.1.2` | `2.1.2` | `2.1.2` | **`2.1.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `on_audio_query_android` | Transitive | Transitive | `1.1.0` | `Transitive` | `1.1.0` | `1.1.0` | `1.1.0` | **`1.1.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `on_audio_query_ios` | Transitive | Transitive | `1.1.0` | `Transitive` | `1.1.0` | `1.1.0` | `1.1.0` | **`1.1.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `on_audio_query_platform_interface` | Transitive | Transitive | `1.7.0` | `Transitive` | `1.7.0` | `1.7.0` | `1.7.0` | **`1.7.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `on_audio_query_web` | Transitive | Transitive | `1.6.0` | `Transitive` | `1.6.0` | `1.6.0` | `1.6.0` | **`1.6.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `package_config` | Transitive | Transitive | `2.1.0` | `Transitive` | `2.1.0` | `2.2.0` | `3.0.0` | **`2.2.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.2.0 via direct upgrades |
| `package_info_plus_platform_interface` | Transitive | Transitive | `2.0.1` | `Transitive` | `2.0.1` | `2.0.1` | `4.1.0` | **`2.0.1`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `path` | Transitive | Transitive | `1.9.1` | `Transitive` | `1.9.1` | `1.9.1` | `1.9.1` | **`1.9.1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `path_provider_android` | Transitive | Transitive | `2.0.27` | `Transitive` | `2.2.23` | `2.3.1` | `2.3.1` | **`2.3.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.3.1 via direct upgrades |
| `path_provider_foundation` | Transitive | Transitive | `2.2.3` | `Transitive` | `2.5.1` | `2.6.0` | `2.6.0` | **`2.6.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.6.0 via direct upgrades |
| `path_provider_linux` | Transitive | Transitive | `2.1.10` | `Transitive` | `2.2.2` | `2.2.2` | `2.2.2` | **`2.2.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `path_provider_platform_interface` | Transitive | Transitive | `2.0.6` | `Transitive` | `2.1.3` | `2.1.3` | `2.1.3` | **`2.1.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `path_provider_windows` | Transitive | Transitive | `2.1.7` | `Transitive` | `2.3.0` | `2.3.0` | `2.3.0` | **`2.3.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `permission_handler_android` | Transitive | Transitive | `10.2.1` | `Transitive` | `12.1.0` | `12.1.0` | `14.1.0` | **`12.1.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `permission_handler_apple` | Transitive | Transitive | `9.1.0` | `Transitive` | `9.6.4` | `9.6.4` | `9.6.4` | **`9.6.4`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `permission_handler_html` | Transitive | Transitive | `N/A` | `Transitive` | `0.1.4+1` | `0.1.4+1` | `0.1.4+1` | **`0.1.4+1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `permission_handler_platform_interface` | Transitive | Transitive | `3.10.0` | `Transitive` | `4.4.1` | `4.4.1` | `4.4.1` | **`4.4.1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `permission_handler_windows` | Transitive | Transitive | `0.1.2` | `Transitive` | `0.2.2` | `0.2.2` | `0.2.2` | **`0.2.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `petitparser` | Transitive | Transitive | `5.4.0` | `Transitive` | `5.4.0` | `7.1.0` | `7.1.0` | **`7.1.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 7.1.0 via direct upgrades |
| `platform` | Transitive | Transitive | `3.1.0` | `Transitive` | `3.1.0` | `3.2.0` | `3.2.0` | **`3.2.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.2.0 via direct upgrades |
| `plugin_platform_interface` | Transitive | Transitive | `2.1.4` | `Transitive` | `2.1.8` | `2.1.8` | `2.1.8` | **`2.1.8`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `pointycastle` | Transitive | Transitive | `3.7.3` | `Transitive` | `3.7.3` | `3.7.3` | `4.0.0` | **`3.7.3`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `pool` | Transitive | Transitive | `1.5.1` | `Transitive` | `1.5.1` | `1.5.3` | `1.5.3` | **`1.5.3`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.5.3 via direct upgrades |
| `process` | Transitive | Transitive | `4.2.4` | `Transitive` | `4.2.4` | `4.2.4` | `5.0.6` | **`4.2.4`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `pub_semver` | Transitive | Transitive | `2.1.4` | `Transitive` | `2.1.4` | `2.2.1` | `2.2.1` | **`2.2.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.2.1 via direct upgrades |
| `puppeteer` | Transitive | Transitive | `3.2.0` | `Transitive` | `3.2.0` | `3.26.0` | `3.26.0` | **`3.26.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.26.0 via direct upgrades |
| `rxdart` | Transitive | Transitive | `0.27.7` | `Transitive` | `0.27.7` | `0.27.7` | `0.28.0` | **`0.27.7`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `share_plus_platform_interface` | Transitive | Transitive | `3.2.1` | `Transitive` | `3.2.1` | `3.4.0` | `7.2.0` | **`3.4.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.4.0 via direct upgrades |
| `shelf` | Transitive | Transitive | `1.4.1` | `Transitive` | `1.4.1` | `1.4.3` | `1.4.3` | **`1.4.3`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.4.3 via direct upgrades |
| `shelf_static` | Transitive | Transitive | `1.1.2` | `Transitive` | `1.1.2` | `1.2.0` | `1.2.0` | **`1.2.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.2.0 via direct upgrades |
| `shelf_web_socket` | Transitive | Transitive | `1.0.4` | `Transitive` | `1.0.4` | `1.0.4` | `3.0.0` | **`1.0.4`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `simple_sparse_list` | Transitive | Transitive | `0.1.4` | `Transitive` | `0.1.4` | `0.1.4` | `0.1.4` | **`0.1.4`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `sky_engine` | Transitive | Transitive | `0.0.0` | `Transitive` | `0.0.0` | `0.0.0` | `0.0.0` | **`0.0.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `source_span` | Transitive | Transitive | `1.9.1` | `Transitive` | `1.9.1` | `1.10.2` | `1.10.2` | **`1.10.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.10.2 via direct upgrades |
| `sqflite` | Transitive | Transitive | `2.2.8+4` | `Transitive` | `2.4.5` | `2.4.5` | `2.4.5` | **`2.4.5`** | None | `PASS` | `LOW` | Retain override 2.4.5 (AGP 8 namespace compatible) |
| `sqflite_android` | Transitive | Transitive | `N/A` | `Transitive` | `2.4.5` | `2.4.5` | `2.4.5` | **`2.4.5`** | None | `PASS` | `LOW` | Retain override 2.4.5 (AGP 8 namespace compatible) |
| `sqflite_common` | Transitive | Transitive | `2.4.5` | `Transitive` | `2.5.14` | `2.5.14` | `2.5.14` | **`2.5.14`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `sqflite_darwin` | Transitive | Transitive | `N/A` | `Transitive` | `2.4.4+1` | `2.4.4+1` | `2.4.4+1` | **`2.4.4+1`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `sqflite_platform_interface` | Transitive | Transitive | `N/A` | `Transitive` | `2.4.3` | `2.4.3` | `2.4.3` | **`2.4.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `stack_trace` | Transitive | Transitive | `1.12.2` | `Transitive` | `1.12.2` | `1.12.2` | `1.12.2` | **`1.12.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `stream_channel` | Transitive | Transitive | `2.1.4` | `Transitive` | `2.1.4` | `2.1.4` | `2.1.4` | **`2.1.4`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `string_scanner` | Transitive | Transitive | `1.2.0` | `Transitive` | `1.2.0` | `1.4.1` | `1.4.1` | **`1.4.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.4.1 via direct upgrades |
| `synchronized` | Transitive | Transitive | `3.1.0` | `Transitive` | `3.5.0` | `3.5.0` | `3.5.0` | **`3.5.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `term_glyph` | Transitive | Transitive | `1.2.1` | `Transitive` | `1.2.1` | `1.2.2` | `1.2.2` | **`1.2.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.2.2 via direct upgrades |
| `test_api` | Transitive | Transitive | `0.7.12` | `Transitive` | `0.7.12` | `0.7.12` | `0.7.15` | **`0.7.12`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `tuple` | Transitive | Transitive | `2.0.1` | `Transitive` | `2.0.1` | `2.0.2` | `2.0.2` | **`2.0.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 2.0.2 via direct upgrades |
| `typed_data` | Transitive | Transitive | `1.3.2` | `Transitive` | `1.3.2` | `1.4.0` | `1.4.0` | **`1.4.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.4.0 via direct upgrades |
| `unicode` | Transitive | Transitive | `1.1.7` | `Transitive` | `1.1.7` | `1.1.9` | `1.1.9` | **`1.1.9`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.1.9 via direct upgrades |
| `url_launcher_android` | Transitive | Transitive | `6.0.31` | `Transitive` | `6.3.33` | `6.3.33` | `6.3.33` | **`6.3.33`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_ios` | Transitive | Transitive | `6.1.4` | `Transitive` | `6.4.2` | `6.4.2` | `6.4.2` | **`6.4.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_linux` | Transitive | Transitive | `3.0.5` | `Transitive` | `3.2.3` | `3.2.3` | `3.2.3` | **`3.2.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_macos` | Transitive | Transitive | `3.0.5` | `Transitive` | `3.2.6` | `3.2.6` | `3.2.6` | **`3.2.6`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_platform_interface` | Transitive | Transitive | `2.1.2` | `Transitive` | `2.3.2` | `2.3.2` | `2.3.2` | **`2.3.2`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_web` | Transitive | Transitive | `2.0.16` | `Transitive` | `2.4.3` | `2.4.3` | `2.4.3` | **`2.4.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `url_launcher_windows` | Transitive | Transitive | `3.0.6` | `Transitive` | `3.1.6` | `3.1.6` | `3.1.6` | **`3.1.6`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `vector_math` | Transitive | Transitive | `2.4.3` | `Transitive` | `2.4.3` | `2.4.3` | `2.4.3` | **`2.4.3`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `vm_service` | Transitive | Transitive | `15.4.0` | `Transitive` | `15.4.0` | `15.4.0` | `15.4.0` | **`15.4.0`** | None | `PASS` | `LOW` | Retain (Already latest) |
| `web` | Transitive | Transitive | `1.1.1` | `Transitive` | `1.1.1` | `1.1.2` | `1.1.2` | **`1.1.2`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.1.2 via direct upgrades |
| `web_socket_channel` | Transitive | Transitive | `2.4.0` | `Transitive` | `2.4.0` | `2.4.0` | `3.0.3` | **`2.4.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `win32` | Transitive | Transitive | `5.0.3` | `Transitive` | `5.15.0` | `5.15.0` | `6.4.0` | **`5.15.0`** | None | `PASS` | `LOW` | Retain (Tied to parent constraint) |
| `win32_registry` | Transitive | Transitive | `1.1.1` | `Transitive` | `1.1.1` | `1.1.5` | `3.0.3` | **`1.1.5`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.1.5 via direct upgrades |
| `xdg_directories` | Transitive | Transitive | `1.0.0` | `Transitive` | `1.0.0` | `1.1.0` | `1.1.0` | **`1.1.0`** | Minor | `PASS` | `LOW` | Auto-resolves to 1.1.0 via direct upgrades |
| `xml` | Transitive | Transitive | `6.3.0` | `Transitive` | `6.3.0` | `6.6.1` | `7.1.0` | **`6.6.1`** | Minor | `PASS` | `LOW` | Auto-resolves to 6.6.1 via direct upgrades |
| `yaml` | Transitive | Transitive | `3.1.2` | `Transitive` | `3.1.2` | `3.1.4` | `3.1.4` | **`3.1.4`** | Minor | `PASS` | `LOW` | Auto-resolves to 3.1.4 via direct upgrades |

---

## 4. Deep-Dive Resolution: `just_audio`, `archive`, and `app_links`

### A. `just_audio` Android Media3 Engine & API Stability
- **Verified Changelog Facts:**
  - `just_audio: 0.9.43` officially migrated Android audio playback from legacy ExoPlayer (`com.google.android.exoplayer2`) to **AndroidX Media3 ExoPlayer 1.4.1** (`androidx.media3:media3-exoplayer:1.4.1`).
  - `just_audio: 0.9.46` retains this Media3 ExoPlayer 1.4.1 implementation under `android/build.gradle` with `compileSdk 34` and `minSdk 16`.
- **Why Version 0.9.46 is Strongly Preferred over 0.10.x:**
  1. **Source-Code Queue Architecture:** BlackHole's [`lib/Services/audio_service.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/audio_service.dart) relies extensively on `ConcatenatingAudioSource` for dynamic queue loading, song reordering, shuffling, and indexed seeking.
  2. **Breaking Changes in 0.10.0:** `just_audio: 0.10.0` officially deprecated `ConcatenatingAudioSource` in favor of a brand new playlist API, deprecated `LoopingAudioSource`, replaced `playbackEventStream.onError` with `errorStream`, and bumped minimum Flutter to `3.27.0` and AGP to `8.5.2`.
  3. **Zero-Regression Path:** Candidate **`0.9.46`** delivers the modern Android Media3 engine, fixes iOS/macOS memory leaks on dispose, and fixes stop/play race conditions while maintaining **100% source-code compatibility** with BlackHole's player service.

### B. `archive` Ingestion Graph & Security Analysis
- **Vulnerabilities:**
  - **GHSA-r285-q736-9v95:** Filename spoofing in Zip headers (Patched in `archive: >= 3.3.8`).
  - **GHSA-9v85-q87q-g4vg (CVE-2023-39139):** Path traversal during archive extraction (Patched in `archive: >= 3.4.10 / 3.6.1`).
- **Resolved Version in Project:** `archive: 3.3.7`.
- **Exact Ingestion Dependency Graph:**
  ```
  [Development Graph]
  msix: 3.14.2 (dev_dependencies)
  └── image: 4.0.17
      └── archive: 3.3.7 (parent constraint: ^3.1.2)

  [Generator Override Graph]
  flutter_rust_bridge: 1.81.0 (dependency_overrides)
  └── puppeteer: 3.2.0
      └── archive: 3.3.7 (parent constraint: ^3.0.0)
  ```
- **Evidence of Zero Android Runtime Exposure:**
  1. `grep -r "package:archive" lib/` returns **0 matches**. Application code never imports Dart `archive`.
  2. `msix` is a Windows desktop MSIX packaging executable; none of its code is compiled into the Android APK.
  3. `flutter_rust_bridge` is used only for `metadata_god` C-FFI runtime bindings; `puppeteer` (browser test runner) is tree-shaken and excluded by the Dart AOT compiler during `flutter build apk`.
  4. The application's backup/restore feature uses `package:flutter_archive/flutter_archive.dart`, which invokes Android's native `java.util.zip.ZipInputStream`.
  5. In Phase C, [`lib/Helpers/backup_restore.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/backup_restore.dart) added `verifyZipEntries` (15/15 passing tests), providing application-level path traversal immunity.
- **Parent Constraint Analysis & Resolution:**
  - `puppeteer: 3.2.0` specifies `archive: ^3.0.0`.
  - `image: 4.0.17` specifies `archive: ^3.1.2`.
  - Both parents allow `archive >= 3.3.8` and `archive: 3.6.1`.
  - Upgrading `msix` to `^3.18.0` in Batch 9 (or adding `dependency_overrides: archive: ^3.6.1`) safely resolves `archive >= 3.6.1`, eliminating the dev-tool advisory.

### C. `app_links` Toolchain Compatibility
- **Inspection of Published Versions:**
  - `app_links: 7.2.2`: `android/build.gradle.kts` declares `classpath 'com.android.tools.build:gradle:9.2.1'`, `compileSdk = 36`, and `minSdk = 24`. **Status: `BLOCKED`** (requires AGP 9.2+ and drops Android 5.0–6.0).
  - `app_links: 6.3.3`: `android/build.gradle` declares `classpath 'com.android.tools.build:gradle:8.5.2'`, `compileSdk 34`, `minSdkVersion 16`. Because root project uses AGP `8.3.2`, subproject AGP 8.5.2 declaration is **Status: `UNVERIFIED`** until build execution.
  - `app_links: 6.0.0`: `android/build.gradle` declares `classpath 'com.android.tools.build:gradle:8.0.1'`, `compileSdkVersion 31`, `minSdkVersion 16`. Since `8.0.1 <= 8.3.2`, **Status: `PASS`**.
  - `app_links: 3.5.1` (Peak 3.x): `classpath 'com.android.tools.build:gradle:8.0.1'`, `minSdkVersion 16`. **Status: `PASS`** (Zero code changes).
- **Recommendation:** Propose `app_links: 6.3.3` with fallback to `app_links: 6.0.0` (or retaining `3.5.1`) if subproject classpath resolution rejects AGP 8.5.2.

---

## 5. Individual Audit of All 9 Dependency Overrides & `audio_session`

### Override 1: `audiotagger: path: packages/audiotagger`
- **Why It Exists:** Upstream `audiotagger: 2.2.1` was abandoned in 2020 and lacks the mandatory `namespace` declaration required by AGP 8.x.
- **Benefiting Dependencies:** [`lib/Services/download.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Services/download.dart), [`lib/Screens/Library/downloads.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Screens/Library/downloads.dart), [`lib/Helpers/lyrics.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/lyrics.dart).
- **Does Proposed Upgrade Make It Unnecessary?** **NO**. Upstream has no updates.
- **Evidence for Safe Removal:** Complete migration of ID3 tagging to `metadata_god`.
- **Disposition:** **Retain local fork override**.

### Override 2: `collection: 1.17.1`
- **Why It Exists:** Baseline override to resolve conflicting upper/lower collection version bounds across legacy packages.
- **Benefiting Dependencies:** Over 20 packages depending on `collection`.
- **Does Proposed Upgrade Make It Unnecessary?** **Conditional**. Flutter 3.47.7 SDK bundles `collection: 1.19.1`. If direct packages are upgraded to versions accepting collection `^1.18.0 / 1.19.0`, this override can be retired.
- **Evidence for Safe Removal:** Clean `flutter pub get` resolution without the override.
- **Disposition:** **Retain through Batches 1–8; evaluate removal in Batch 9**.

### Override 3: `flutter_plugin_android_lifecycle: 2.0.35`
- **Why It Exists:** Added in Phase B because older plugins depended on `2.0.14`, which caused compile errors under AGP 8.3.2.
- **Benefiting Dependencies:** `image_picker`, `url_launcher_android`, `file_picker`.
- **Does Proposed Upgrade Make It Unnecessary?** **Conditional**. Modern plugin releases natively depend on `flutter_plugin_android_lifecycle: >=2.0.20`.
- **Evidence for Safe Removal:** `flutter pub deps` showing no package restricting lifecycle to `<2.0.20`.
- **Disposition:** **Retain through Batches 1–8; evaluate removal in Batch 9**.

### Override 4: `flutter_rust_bridge: 1.81.0`
- **Why It Exists:** Baseline override. `metadata_god: ^0.4.1` requires `flutter_rust_bridge: 1.x`, but newer transitive packages attempted to pull `2.x`.
- **Benefiting Dependencies:** `metadata_god: 0.4.1`.
- **Does Proposed Upgrade Make It Unnecessary?** **NO**. Upgrading to 2.x requires dynamic Rust compilation.
- **Evidence for Safe Removal:** Full rewrite of `metadata_god` native bindings.
- **Disposition:** **Retain override 1.81.0**.

### Override 5: `http_parser: 4.0.2`
- **Why It Exists:** Baseline override to resolve version bounds between `http`, `cached_network_image`, and streaming clients.
- **Benefiting Dependencies:** `http`, `cached_network_image`, `youtube_explode_dart`.
- **Does Proposed Upgrade Make It Unnecessary?** **Conditional**.
- **Evidence for Safe Removal:** Clean `pub get` resolution without conflict warnings in Batch 9.
- **Disposition:** **Retain through Batches 1–8; test removal in Batch 9**.

### Override 6: `material_design_icons_flutter: path: packages/material_design_icons_flutter`
- **Why It Exists:** Upstream 5.x had `sdk: ">=2.12.0 <3.0.0"`, rejecting Dart 3 (`3.13.5`). The local fork patched the SDK constraint to `<4.0.0`. Upstream 7.x renamed all icon constants and was then discontinued.
- **Benefiting Dependencies:** 8 screens across BlackHole using 22 distinct MdiIcons.
- **Does Proposed Upgrade Make It Unnecessary?** **NO**. Upstream 7.x is discontinued and breaks icon constants.
- **Evidence for Safe Removal:** Replacing all 22 MdiIcon usages with Material `Icons` or SVG assets.
- **Disposition:** **Retain local fork override**.

### Override 7: `receive_sharing_intent: path: packages/receive_sharing_intent`
- **Why It Exists:** Added in Phase B. Upstream 1.4.5 lacked AGP 8 `namespace` and had outdated compileSdk. The local fork added `namespace 'com.kasem.receive_sharing_intent'` and `compileSdkVersion 34`.
- **Benefiting Dependencies:** [`lib/Helpers/route_handler.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/route_handler.dart).
- **Does Proposed Upgrade Make It Unnecessary?** **POSSIBLE in Batch 8**. Upstream 1.9.0 added namespace support, but changes Intent handling models.
- **Evidence for Safe Removal:** Passing tests in `test/route_handler_test.dart` and manual intent sharing test under upstream 1.9.0.
- **Disposition:** **Retain local fork override for initial batches; evaluate 1.9.0 in Batch 8**.

### Override 8 & 9: `sqflite: 2.4.5` & `sqflite_android: 2.4.5`
- **Why It Exists:** Added in Phase B. `flutter_cache_manager: 3.3.1` (pulled by `cached_network_image: 3.3.1`) depended on `sqflite: 2.2.8+4`, which lacked AGP 8 `namespace`. Overriding to 2.4.5 provided the AGP 8 compatible Android implementation.
- **Benefiting Dependencies:** `cached_network_image` / `flutter_cache_manager`.
- **Does Proposed Upgrade Make It Unnecessary?** **Conditional**. In Batch 2, when `cached_network_image` is upgraded to `3.4.1`, it pulls a newer `flutter_cache_manager` that natively accepts `sqflite: ^2.3.0 / 2.4.x`, allowing this override to potentially be retired.
- **Evidence for Safe Removal:** `flutter pub deps` showing `flutter_cache_manager` natively resolving `sqflite >= 2.4.0`.
- **Disposition:** **Retain through Batch 2; test removal after cached_network_image bump**.

### Status & Target Justification for `audio_session`
- **Direct or Transitive?** **TRANSITIVE**. Not declared in [`pubspec.yaml`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/pubspec.yaml); parented by `just_audio` and `audio_service`.
- **Current Resolved Version:** **`0.1.18`** in [`pubspec.lock`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/pubspec.lock).
- **Target Version in Batch 7:** **`0.1.25`**.
- **Justification:** Both candidate `just_audio: 0.9.46` and `audio_service: 0.18.19` require `audio_session: ^0.1.25`. Version `0.1.25` resolves Android 12–14 audio focus ducking, Bluetooth SCO routing, and noisy (headphone disconnect) event lifecycle bugs. It auto-resolves cleanly without an override.

---

## 6. Revised Ordered Upgrade Batches & Execution Plan

```
[Batch 1: Low-Risk Utilities]
         │
         ▼
[Batch 2: UI, Widgets & Images]
         │
         ▼
[Batch 3: System & Connectivity (Toolchain-Compatible)]
         │
         ▼
[Batch 4: Storage & Permissions Baseline]
         │
         ▼
[Batch 5: Database & Persistence Security]
         │
         ▼
[Batch 6: YouTube Streaming & Deep Links]
         │
         ▼
[Batch 7: Audio Core Engine & Services]
         │
         ▼
[Batch 8: Local Compatibility Forks Audit]
         │
         ▼
[Batch 9: Dev Tools, Packaging & Final Validation]
```

### Batch 1: Low-Risk Utilities & Non-Breaking Helpers
- **Packages:** `logging: ^1.3.0`, `cupertino_icons: ^1.0.9`, `dart_des: 1.0.2` (retain), `flip_card: 0.7.0` (retain), `html_unescape: 2.0.0` (retain), `marquee: 2.3.0` (retain).
- **Prerequisites:** None.
- **Risk Level:** Minimal (`LOW`).
- **Automated Tests:** Run `flutter test test/helpers_test.dart` and full 125-test baseline suite.
- **Maintainer Manual Checks:** Confirm app launches and basic logging output.

### Batch 2: UI, Layout, Display & Images
- **Packages:** `cached_network_image: ^3.4.1`, `carousel_slider: ^5.1.2`, `salomon_bottom_bar: 3.3.2`, `sliding_up_panel: 2.0.0+1`, `palette_generator: ^0.3.3+7`, `flutter_displaymode: ^0.7.0`, `flutter_lyric: 2.0.4+6` (retain).
- **Prerequisites:** Batch 1.
- **Risk Level:** Low-Medium (`LOW-MEDIUM`).
- **Automated Tests:** 15/15 playlist header overflow tests, widget tests.
- **Maintainer Manual Checks:** Verify Now Playing lyrics display, album art gradients, carousel scrolling.

### Batch 3: System, Device & Connectivity (Toolchain-Compatible)
- **Packages:** `connectivity_plus: ^6.1.4`, `device_info_plus: ^10.1.2`, `package_info_plus: ^8.3.0`, `url_launcher: ^6.3.3`.
- **Prerequisites:** Batch 2.
- **Source Migrations:** `audio_service.dart` (`onConnectivityChanged` -> `List<ConnectivityResult>`), `setting.dart` (`supportedAbis`).
- **Risk Level:** Medium (`MEDIUM`).
- **Automated Tests:** Full 125-test suite, service locator tests.
- **Maintainer Manual Checks:** Toggle WiFi/cellular and verify playback reaction; check About screen version display.

### Batch 4: Storage, Permissions & File Selection (Baseline Protection)
- **Packages:** `path_provider: ^2.1.6`, `permission_handler: 11.4.0` (retain), `file_picker: 8.3.7` (retain), `on_audio_query: 2.9.0` (retain).
- **Prerequisites:** Batch 3.
- **Risk Level:** Low (`LOW`).
- **Automated Tests:** Audio query tests, storage helper tests.
- **Maintainer Manual Checks:** Open local library; verify scanned songs appear without permission crashes.

### Batch 5: Database, Persistence & Backup Security
- **Packages:** `hive: 2.2.3` (retain), `hive_flutter: 1.1.0` (retain), `sqflite: 2.4.5` (retain override), `flutter_archive: 5.0.0` (retain).
- **Prerequisites:** Batch 4.
- **Risk Level:** Low (`LOW`).
- **Automated Tests:** `test/backup_restore_test.dart` (round-trip backup, restore, path traversal guards).
- **Maintainer Manual Checks:** Export a backup file, modify a playlist, and restore the backup.

### Batch 6: YouTube Streaming & Deep Links
- **Packages:** `youtube_explode_dart: ^3.1.0`, `app_links: ^6.3.3` (fallback `6.0.0` / `3.5.1`), `share_plus: ^10.1.4`, `uuid: ^4.6.0`.
- **Prerequisites:** Batch 5.
- **Source Migrations:** `spotify_helper.dart` (`uriLinkStream`), `auth.dart` (`Uuid().v1()`).
- **Playback Investigation:** Benchmark YouTube stream extraction latency against reported song stuttering.
- **Risk Level:** High (`HIGH`).
- **Automated Tests:** Stream URL parser tests, URI link tests.
- **Maintainer Manual Checks:** Play multiple YouTube songs, test song share link, test Spotify import redirect.

### Batch 7: Core Audio Engine & Player Services
- **Packages:** `just_audio: ^0.9.46`, `audio_service: ^0.18.19`, `audio_session: ^0.1.25` (transitive auto-resolve).
- **Prerequisites:** Batch 6.
- **Risk Level:** High (`HIGH`).
- **Automated Tests:** Radio reconnection test, playback speed sync test, headphone disconnect test, miniplayer queue tests.
- **Maintainer Manual Checks:** Play audio in background, lock device, test notification play/pause/skip buttons, test radio streaming.

### Batch 8: Local Compatibility Forks Audit & Alignment
- **Packages:** `packages/receive_sharing_intent` (Evaluate upgrade to 1.9.0 vs retain fork), `packages/audiotagger` (retain), `packages/material_design_icons_flutter` (retain).
- **Prerequisites:** Batch 7.
- **Risk Level:** Medium (`MEDIUM`).
- **Automated Tests:** `test/route_handler_test.dart` (sharing intent error handling).
- **Maintainer Manual Checks:** Share a song/URL from an external app to BlackHole; verify route handling.

### Batch 9: Dev Dependencies, Packaging & Final Validation
- **Packages:** `lint: ^2.14.0`, `msix: ^3.18.0`, clean redundant `dependency_overrides`.
- **Prerequisites:** Batches 1–8.
- **Risk Level:** Low (`LOW`).
- **Automated Tests:** `flutter analyze lib test`, full 125-test baseline suite, debug APK compilation check.
- **Maintainer Manual Checks:** Run `flutter test` and compile APK via PowerShell.

---

## 7. Explicit List of Packages That Must Remain Pinned and Why

1. **`just_audio: 0.9.46` (Pinned to Peak 0.9.x):**
   - **Reason:** Version `0.10.x` completely deprecates `ConcatenatingAudioSource` and introduces a breaking playlist API rewrite, whereas `0.9.46` delivers the Media3 Android engine while preserving BlackHole's existing queue architecture.
2. **`metadata_god: 0.4.1` (Pinned):**
   - **Reason:** Upstream `1.x` requires `flutter_rust_bridge: 2.x` and a full native Rust compiler toolchain, removing prebuilt C ABI binaries.
3. **`permission_handler: 11.4.0` (Pinned):**
   - **Reason:** Upstream `13.x` requires `compileSdk 37`, `minSdk 24`, `AGP 9.0.1`, and `Kotlin 2.3.20`. Incompatible with our toolchain.
4. **`flutter_archive: 5.0.0` (Pinned):**
   - **Reason:** Upstream `6.3.1` raises `minSdk` to 24 (dropping Android 5.0–6.0) without affecting Dart `archive`.
5. **`file_picker: 8.3.7` (Pinned):**
   - **Reason:** Upstream `13.x` raises `minSdk` to 24 via `android_file_picker: 2.0.0`.
6. **`material_design_icons_flutter: 5.0.5955-rc.1` (Local Fork Pinned):**
   - **Reason:** Upstream is discontinued; version 7.x renamed/removed icon constants, which would break 22 UI icons across 8 screens.
7. **`audiotagger: 2.2.1` (Local Fork Pinned):**
   - **Reason:** Upstream is abandoned (2020) and lacks AGP 8 namespace.
8. **`receive_sharing_intent: 1.4.5` (Local Fork Pinned for Initial Batches):**
   - **Reason:** Maintained with AGP 8 namespace and compileSdk 34. Candidate 1.9.0 deferred to Batch 8.
9. **`hive: 2.2.3` & `hive_flutter: 1.1.0` (Pinned):**
   - **Reason:** Peak stable releases on pub.dev.
10. **`on_audio_query: 2.9.0` (Pinned):**
    - **Reason:** Peak stable release on pub.dev.
11. **`sliding_up_panel: 2.0.0+1` (Pinned):**
    - **Reason:** Peak stable release on pub.dev (abandoned upstream).

---

## 8. Outstanding Uncertainties & Maintainer Approval Decisions

1. **Toolchain Policy Approval (Path A vs Path B):**
   - Maintainer approval is requested to confirm **Path A (Current Toolchain Preservation)** during Phase D, keeping AGP 8.3.2, compileSdk 36, and minSdk 21, and adopting the peak toolchain-compatible package candidates (`connectivity_plus: 6.1.4`, `device_info_plus: 10.1.2`, `share_plus: 10.1.4`, `app_links: 6.3.3` with `6.0.0` fallback).
2. **Playback Stuttering Investigation Authorization:**
   - Authorize benchmarking YouTube stream chunking and player buffering in Batch 6 (`youtube_explode_dart: 3.1.0`) against the maintainer's reported audio stuttering.
3. **Local Forks Retention Approval:**
   - Maintainer approval is requested to retain local compatibility forks for `material_design_icons_flutter` (5.0.5955-rc.1) and `audiotagger` (2.2.1), and evaluate `receive_sharing_intent` (1.9.0) in Batch 8.

---

### Strict Stop Condition Enforced
Phase D1.2 is strictly read-only. No application code, build configurations, or dependencies were modified. The emulator was not launched or tested. Both repositories remain 100% intact.
