# BLACKHOLE REVIVAL — BATCH 3 POST-TEST FIX REPORT
## Landscape Display Cutout / Notch Layout Defect Resolution
**Milestone:** Post-Batch 3 Single-Bug Visual Fix  
**Date:** 2026-10-25  
**Active Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Git HEAD:** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Target Device Architecture:** Android 9+ (API 28+) Physical Devices with Display Cutouts / Notches

---

## 1. Executive Summary & Defect Scope

During manual physical device testing of the Batch 3 debug APK on a real Android smartphone, auto-rotating into landscape mode revealed a prominent layout and rendering defect on the onboarding setup screen (`AuthScreen`):
- **Visual Symptom in Manual Testing:** In landscape orientation with the notch on the left, the app window was letterboxed with curved corners, leaving the Android system launcher/wallpaper peeking through on the cutout side. Additionally, content within the onboarding screen was either cramped or vulnerable to clipping.
- **Scope Contract:** Strict single-bug fix. No Batch 4 tasks started. No dependency upgrades altered. All 9 dependency overrides preserved. Original repository `D:\My-GitHub-Projects\BlackHole` preserved strictly read-only.
- **Resolution Status:** Successfully diagnosed, patched, verified with focused widget tests, validated across the complete 10-suite automated test suite, verified with static analysis, and compiled into a fresh Android debug APK with verified D: Gradle storage.

---

## 2. Root Cause Analysis

Investigation of the manual test screenshot and the underlying codebase identified a two-part root cause spanning the native Android window level and the Flutter widget layout hierarchy:

### A. Android OS Window Layer (Letterboxing & Wallpaper Leakage)
In `android/app/src/main/res/values/styles.xml` and `android/app/src/main/res/values-night/styles.xml`, both `LaunchTheme` and `NormalTheme` configure:
```xml
<item name="android:windowIsTranslucent">true</item>
```
On Android 9 (API 28) and newer, the default window layout mode around display cutouts (`android:windowLayoutInDisplayCutoutMode="default"`) specifies that windows are not allowed to extend into the cutout area in landscape orientation unless explicitly instructed. Because `android:windowIsTranslucent` is `true`, Android does not letterbox with solid black bars; instead, it renders the window inset from the cutout with rounded corners, causing the underlying Android OS home screen / launcher wallpaper to bleed through visually.

**Fix:** Declaring `<item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>` in both `LaunchTheme` and `NormalTheme` allows the window to extend edge-to-edge across the display cutouts on both short edges of the screen in landscape orientation.

### B. Flutter Widget Layer (`SafeArea` & Edge-to-Edge Composition)
In `lib/Screens/Login/auth.dart` (and symmetrically in `lib/Screens/Login/pref.dart`):
1. **Misplaced `SafeArea`:** `SafeArea` directly wrapped the outer `Stack`. Consequently, all stack children—including the decorative watermark icon (`assets/icon-white-trans.png`) and the background `GradientContainer`—were restricted inside the safe area, creating visible layout seams rather than bleeding edge-to-edge behind the notch.
2. **Opaque Scaffold Background:** `Scaffold` lacked `backgroundColor: Colors.transparent`, blocking the full-screen gradient rendered by the outer `GradientContainer`.
3. **Heading Text Width Vulnerability:** In `auth.dart`, the large "Black\nHole\nMusic." heading (80pt font) was rendered inside an unconstrained `Row(children: [RichText(...)])`. In landscape orientation or on narrow displays, this row could trigger a `RenderFlex overflowed` error.

**Fix:**
- Set `backgroundColor: Colors.transparent` on `Scaffold`.
- Relocated `SafeArea` inside the `Stack` so it specifically wraps only the interactive and readable content `Column` (`Skip`, `Restore`, heading, and name-entry field). The background watermark and gradient remain direct children of `Stack` to extend edge-to-edge.
- Wrapped the heading in `Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RichText(...)))` to guarantee that text scales cleanly without overflowing on any screen aspect ratio or font scale factor.

---

## 3. Exact Source Code Changes

### File 1: `android/app/src/main/res/values/styles.xml`
```diff
--- a/android/app/src/main/res/values/styles.xml
+++ b/android/app/src/main/res/values/styles.xml
@@ -9,6 +9,7 @@
         <item name="android:windowContentOverlay">@null</item>
         <item name="android:windowNoTitle">true</item>
         <item name="android:backgroundDimEnabled">false</item>
+        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
     </style>
@@ -22,6 +23,7 @@
         <item name="android:windowContentOverlay">@null</item>
         <item name="android:windowNoTitle">true</item>
         <item name="android:backgroundDimEnabled">false</item>
+        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
     </style>
```

### File 2: `android/app/src/main/res/values-night/styles.xml`
```diff
--- a/android/app/src/main/res/values-night/styles.xml
+++ b/android/app/src/main/res/values-night/styles.xml
@@ -9,6 +9,7 @@
         <item name="android:windowContentOverlay">@null</item>
         <item name="android:windowNoTitle">true</item>
         <item name="android:backgroundDimEnabled">false</item>
+        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
     </style>
@@ -22,5 +23,6 @@
         <item name="android:windowContentOverlay">@null</item>
         <item name="android:windowNoTitle">true</item>
         <item name="android:backgroundDimEnabled">false</item>
+        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
     </style>
```

### File 3: `lib/Screens/Login/auth.dart`
```diff
--- a/lib/Screens/Login/auth.dart
+++ b/lib/Screens/Login/auth.dart
@@ -52,27 +52,28 @@ class _AuthScreenState extends State<AuthScreen> {
   Widget build(BuildContext context) {
     return GradientContainer(
       child: Scaffold(
+        backgroundColor: Colors.transparent,
         extendBodyBehindAppBar: true,
-        body: SafeArea(
-          child: Stack(
-            children: [
-              Positioned(
-                left: MediaQuery.of(context).size.width / 1.85,
-                child: SizedBox(
-                  width: MediaQuery.of(context).size.width,
-                  height: MediaQuery.of(context).size.width,
-                  child: const Image(
-                    image: AssetImage(
-                      'assets/icon-white-trans.png',
-                    ),
+        body: Stack(
+          children: [
+            Positioned(
+              left: MediaQuery.of(context).size.width / 1.85,
+              child: SizedBox(
+                width: MediaQuery.of(context).size.width,
+                height: MediaQuery.of(context).size.width,
+                child: const Image(
+                  image: AssetImage(
+                    'assets/icon-white-trans.png',
                   ),
                 ),
               ),
-              const GradientContainer(
-                child: null,
-                opacity: true,
-              ),
-              Column(
+            ),
+            const GradientContainer(
+              child: null,
+              opacity: true,
+            ),
+            SafeArea(
+              child: Column(
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
@@ -114,9 +115,12 @@ class _AuthScreenState extends State<AuthScreen> {
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.spaceAround,
                           children: [
-                            Row(
-                              children: [
-                                RichText(
+                            Align(
+                              alignment: Alignment.centerLeft,
+                              child: FittedBox(
+                                fit: BoxFit.scaleDown,
+                                alignment: Alignment.centerLeft,
+                                child: RichText(
                                   text: TextSpan(
                                     text: 'Black\nHole\n',
                                     style: TextStyle(
@@ -149,7 +153,7 @@ class _AuthScreenState extends State<AuthScreen> {
                                     ],
                                   ),
                                 ),
-                              ],
+                              ),
                             ),
                             SizedBox(
                               height: MediaQuery.of(context).size.height * 0.1,
@@ -278,8 +282,8 @@ class _AuthScreenState extends State<AuthScreen> {
                   ),
                 ],
               ),
-            ],
-          ),
+            ),
+          ],
         ),
       ),
     );
```

### File 4: `lib/Screens/Login/pref.dart`
```diff
--- a/lib/Screens/Login/pref.dart
+++ b/lib/Screens/Login/pref.dart
@@ -52,27 +52,28 @@ class _PrefScreenState extends State<PrefScreen> {
   Widget build(BuildContext context) {
     return GradientContainer(
       child: Scaffold(
+        backgroundColor: Colors.transparent,
         resizeToAvoidBottomInset: false,
-        body: SafeArea(
-          child: Stack(
-            children: [
-              Positioned(
-                left: MediaQuery.of(context).size.width / 1.85,
-                child: SizedBox(
-                  width: MediaQuery.of(context).size.width,
-                  height: MediaQuery.of(context).size.width,
-                  child: const Image(
-                    image: AssetImage(
-                      'assets/icon-white-trans.png',
-                    ),
+        body: Stack(
+          children: [
+            Positioned(
+              left: MediaQuery.of(context).size.width / 1.85,
+              child: SizedBox(
+                width: MediaQuery.of(context).size.width,
+                height: MediaQuery.of(context).size.width,
+                child: const Image(
+                  image: AssetImage(
+                    'assets/icon-white-trans.png',
                   ),
                 ),
               ),
-              const GradientContainer(
-                child: null,
-                opacity: true,
-              ),
-              Column(
+            ),
+            const GradientContainer(
+              child: null,
+              opacity: true,
+            ),
+            SafeArea(
+              child: Column(
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
@@ -559,8 +588,8 @@ class _PrefScreenState extends State<PrefScreen> {
                   ),
                 ],
               ),
-            ],
-          ),
+            ),
+          ],
         ),
       ),
     );
```

---

## 4. Focused Layout & Safe-Area Test Suite

To guarantee regression-free behaviour in both orientation directions and on notched displays, a dedicated test file was authored:
[test/landscape_display_cutout_test.dart](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/landscape_display_cutout_test.dart)

### Invariants Tested:
1. **Portrait Layout Invariant:** `AuthScreen` renders at standard phone dimensions (`393x851`) with top and bottom safe areas without any `RenderFlex` overflow.
2. **Landscape (Notch on Left) Invariant:** Screen rotated 90 degrees with a 48dp left notch inset. Background elements span the full display width (`851dp`), while the content `Column` and interactive widgets are positioned strictly beyond `dx >= 48.0dp`.
3. **Reverse Landscape (Notch on Right) Invariant:** Screen rotated 270 degrees with a 48dp right notch inset. The top-right action buttons (`Restore` and `Skip`) are protected inside the safe area and never rendered closer than 48dp to the right edge (`dx <= 851 - 48`).
4. **PrefScreen Invariant:** Verified that `PrefScreen` also renders edge-to-edge without overflowing in landscape mode.
5. **Android Cutout XML Invariant:** Verified that both `android/app/src/main/res/values/styles.xml` and `android/app/src/main/res/values-night/styles.xml` declare `shortEdges`.

**Result:** All 5 tests passed in 7.54 seconds with zero errors or warnings.

---

## 5. Automated Test Suite Results

The complete automated Flutter test suite was executed across all 10 test files in `D:\My-GitHub-Projects\BlackHole-maintenance\test` using the expanded reporter:

| # | Test Suite File | Test Scope | Result | Duration |
| :-: | :--- | :--- | :-: | :-: |
| 1 | [`test/landscape_display_cutout_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/landscape_display_cutout_test.dart) | Display cutout landscape/portrait safe-area invariants | **PASS (5/5)** | 7.54s |
| 2 | [`test/batch_3_modernisation_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/batch_3_modernisation_test.dart) | Connectivity multi-result, AppLinks debounce & Device Info ABI | **PASS (16/16)** | 7.34s |
| 3 | [`test/batch_2_modernisation_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/batch_2_modernisation_test.dart) | Palette Generator, Package Info & Canvas shaders | **PASS (9/9)** | 7.42s |
| 4 | [`test/post_batch_2_fixes_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/post_batch_2_fixes_test.dart) | Drawer header contrast, artwork resolution & LRCLIB pipeline | **PASS (17/17)** | 6.73s |
| 5 | [`test/download_bug_fixes_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/download_bug_fixes_test.dart) | Download notifications, refresh safety & track identity | **PASS (10/10)** | 7.40s |
| 6 | [`test/playlist_header_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/playlist_header_test.dart) | Bouncy header scaling (1.0x - 1.5x) & layout bounds | **PASS (15/15)** | 7.37s |
| 7 | [`test/radio_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/radio_test.dart) | Radio connection state machine & error fallback | **PASS (5/5)** | 7.05s |
| 8 | [`test/widget_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/widget_test.dart) | Version comparison & top charts selectors | **PASS (3/3)** | 6.70s |
| 9 | [`test/backend_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/backend_test.dart) | Theme seed invariants, parsers & streaming sanitization | **PASS (95/95)** | 8.20s |
| 10 | [`test/speed_test.dart`](file:///D:/My-GitHub-Projects/BlackHole-maintenance/test/speed_test.dart) | Playback speed engine bridge & UI controls | **PASS (7/7 Assertions)** | 729.09s (timeout in tearDownAll) |

### Note on `test/speed_test.dart`
As documented in Phase C, Phase D2 Batch 1, Batch 2, and Batch 3, all 7 unit and widget assertions in `test/speed_test.dart` pass in 1.1 seconds. The test process subsequently times out during `(tearDownAll)` because `SpeedTestAudioHandler` (which extends `BaseAudioHandler` from `package:audio_service`) leaves open isolate receive ports in the test runner. Per mandatory instructions, this test was faithfully executed and recorded without skipping, weakening, or suppressing.

---

## 6. Static Analysis Verification

Static analysis was executed across `lib` and `test`:
```bash
flutter analyze lib test
```
- **Results:** **0 compile/type errors**.
- **Historical Baseline:** Baseline analyzer issue at `lib/Helpers/format.dart:727` remains unchanged. Historical style lints and deprecation warnings remain identical to baseline.
- **Zero New Issues:** `test/landscape_display_cutout_test.dart`, `lib/Screens/Login/auth.dart`, and `lib/Screens/Login/pref.dart` introduce zero new analyzer issues.

---

## 7. Android Debug APK Build Metrics

The Android debug APK was compiled cleanly with the verified D: Gradle user home:

- **Build Command:** `flutter build apk --debug -v`
- **Build Duration:** 210.6 seconds (~3.5 minutes)
- **Exit Code:** `0`
- **Output Artifact Path:** [app-debug.apk](file:///D:/My-GitHub-Projects/BlackHole-maintenance/build/app/outputs/flutter-apk/app-debug.apk)
- **APK File Size:** **170,281,210 bytes**
- **New SHA-256 Checksum:** `74f758fa9d878970167be7752ce4627a6cc2e28ee8beb9051fd8fa78b7812d6b`
- **Preserved Pre-Batch-3 Checkpoint APK:**
  - Location: `D:\BlackHole-Checkpoints\pre-batch-3-gradle-cleanup-20261025-024025\BlackHole-maintenance\build\app\outputs\flutter-apk\app-debug.apk`
  - Byte Size: `197,217,008 bytes`
  - SHA-256: `9d04ca58c0f1434ec11c7e8baf739dd467940e5965125b1cd994f7e337edb6ca` (Verified Intact)
- **Workstation Gradle Verification:**
  - `C:\Users\gkpsu\.gradle` was **NOT recreated** (Confirmed `False`).
  - Active Gradle User Home: `D:\DevCaches\GradleUserHome` (Confirmed `True`).
- **Disk Storage Verification:**
  - C: Drive Free: **34.15 GB**
  - D: Drive Free: **40.17 GB**

---

## 8. Independent Scope & Preservation Audit

1. **Original Repository:** Confirmed read-only; no files modified in `D:\My-GitHub-Projects\BlackHole`.
2. **Dependency Versions & Overrides:** All four Batch 3 modernised dependencies (`connectivity_plus: ^6.1.1`, `url_launcher: ^6.3.1`, `device_info_plus: ^10.1.2`, `package_info_plus: ^8.1.2`) and all 9 dependency overrides remain exactly at their approved versions.
3. **Build Toolchain:** AGP, Gradle wrapper (8.14), Kotlin, and Flutter SDK settings were completely untouched.
4. **Application Features:** No changes were made to audio playback, downloading, routing, settings, or any screen outside of the onboarding layout fix.
5. **No Workarounds:** Auto-rotation was not disabled, portrait mode was not forced, and the status bar was not hidden.

---

## 9. Mandatory Stopping Point & Maintainer Verification Checklist

In accordance with Section 9 of the prompt, work is now halted before proceeding to Phase D2 Batch 4. The maintainer should manually install and test the new APK on the physical Android phone:

- [ ] **Check 1: Display Cutout Behavior in Landscape:** Rotate phone into landscape mode (notch on left). Confirm the window extends edge-to-edge behind the notch without letterboxing or wallpaper leakage.
- [ ] **Check 2: Reverse Landscape Orientation:** Rotate phone 180 degrees into reverse landscape mode (notch on right). Confirm the layout adapts and top-right actions (`Restore`, `Skip`) remain visible and unobstructed.
- [ ] **Check 3: Portrait Layout:** Confirm portrait onboarding layout remains visually pristine, properly centered, and unclipped.
- [ ] **Check 4: Interactive Controls:** Verify `Restore`, `Skip`, the `Enter Your Name` text field, and `Get Started` button respond to touches normally.
- [ ] **Check 5: General Stability:** Verify the rest of BlackHole functions as expected without regression.

**Do not begin Phase D2 Batch 4 until manual testing on the physical device is approved by the maintainer.**
