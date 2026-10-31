# BlackHole Phase E0: Baseline Performance Measurement Plan
**Date:** October 26, 2026  
**Status:** Performance Measurement Specification  
**Author:** Senior Flutter Engineer / Performance Architect  
**Project:** BlackHole Music Player (`com.shadow.blackhole`)  
**Workspace:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Target Branch:** `maintenance/build-compatibility-upgrade`  

---

## 1. Principles of Performance Measurement

To ensure engineering rigor, Phase E adheres to the core principle: **Measure First, Change Second**.

1. **No Speculative Claims:** Performance improvements must be demonstrated with concrete timing data, frame metrics, or memory logs.
2. **Comparable Environments:** Measurements must never compare Debug builds against Release builds. Before-and-after evaluations must use identical build variants on the same hardware.
3. **Statistical Repeatability:** Latency figures must be derived from at least five (5) consistent runs, reporting the **median and range** (min–max), not a single outlier.
4. **Separation of Concerns:** External network variance and third-party API latency must be isolated from application-controlled processing time.
5. **Zero Permanent Production Noise:** Instrumentation added for profiling must be non-invasive and must not leave noisy logging or performance overhead in the final application.

---

## 2. Benchmark Categories & Event Definitions

| Category | Start Event (Trigger) | End Event (Settlement) | Target Budget (Physical Device) | Measurement Tool |
|---|---|---|---|---|
| **Cold Startup** | Application process launch (`am start-activity -W` or process creation) | Home screen fully interactive (`HomePage` mounted, first frame painted, scroll responsive) | ≤ 3.5s (down from ~8s) | `adb shell am start-activity -W`, Flutter `Timeline` |
| **Warm Startup** | Application brought to foreground from stopped/background state | Home screen interactive and settled | ≤ 1.0s | `adb shell am start-activity -W`, Activity lifecycle timestamps |
| **Tab Navigation** | Tap bottom bar item (e.g. Home → YouTube) | Destination tab rendered and responsive to gestures | ≤ 150ms / 0 dropped frames | Flutter DevTools Frame Timing, `Timeline` |
| **Screen Push Navigation** | Tap route destination (e.g. Home → Search or Now Playing) | Route transition completed, view interactive | ≤ 300ms / smooth transition | Flutter `WidgetsBindingObserver` / DevTools |
| **YouTube Search (Input)** | Keystroke entered in search field | Search field text updated and cursor responsive | ≤ 16.7ms (immediate, 0 frame drops) | UI Event timing |
| **YouTube Search (First Result)** | Query submitted or debounced | First useful result item painted on screen | ≤ 800ms (cached: ≤ 100ms) | Stop-watch instrumentation / Network logcat |
| **Local Playback Latency** | Tap a local track in downloaded/local music list | First audible audio rendered by ExoPlayer | ≤ 300ms | Audio handler timing logs (`play` to `playing`) |
| **Online Catalogue Playback** | Tap a JioSaavn / catalogue track | First audible audio rendered by ExoPlayer | ≤ 1.2s (dependent on CDN) | Audio handler timing logs |
| **YouTube Playback Latency** | Tap a YouTube search result or playlist item | First audible audio rendered by ExoPlayer | ≤ 2.0s (dependent on stream resolution) | Audio handler timing logs |
| **List Scrolling Smoothness** | Touch-down scroll gesture on 100+ item list | Touch-up scroll idle settlement | 99% frames under 16.6ms (60 Hz) / 11.1ms (90 Hz) | Flutter DevTools Performance Overlay / FrameTiming |
| **Memory Retention** | Baseline after 5-minute active browsing & playback | Steady-state heap memory after GC | ≤ 180 MB heap / no unbounded growth | `adb shell dumpsys meminfo com.shadow.blackhole` |

---

## 3. Detailed Measurement Protocols

### 3.1 Startup Latency Measurement Protocol
#### Physical Device (Owner Execution):
1. Ensure the device is connected via USB with USB debugging enabled.
2. Force-stop the application to guarantee a true cold launch:
   ```powershell
   adb shell am force-stop com.shadow.blackhole
   ```
3. Execute the standard Android Activity Manager benchmark:
   ```powershell
   adb shell am start-activity -W -n com.shadow.blackhole/com.shadow.blackhole.MainActivity
   ```
4. Record the returned metrics:
   - `ThisTime`: Time to launch the MainActivity.
   - `TotalTime`: Time from process launch to the window receiving focus.
   - `WaitTime`: Total time including activity manager transitions.
5. In addition, measure the time until the home screen feed renders the first cached item (measured via lightweight timestamp logged in `HomePage.initState` to first frame callback).
6. Repeat five (5) times. Record Median, Min, and Max.

### 3.2 Click-to-Audio Latency Measurement Protocol
To measure tap-to-audio latency with millisecond precision without subjective stopwatches:
1. Instrument the critical path with temporary lightweight timing anchors:
   - **T0 (User Tap):** In `PlayerInvoke.init()` or song tile `onTap`:
     ```dart
     final int t0 = DateTime.now().millisecondsSinceEpoch;
     ```
   - **T1 (Queue Prepared):** In `updateNplay()` when calling `audioHandler.play()`:
     ```dart
     final int t1 = DateTime.now().millisecondsSinceEpoch;
     ```
   - **T2 (Engine Started):** In `AudioPlayerHandlerImpl` when `playbackEventStream` receives `ProcessingState.ready` with `playing == true`:
     ```dart
     final int t2 = DateTime.now().millisecondsSinceEpoch;
     ```
2. Log: `Tap-to-Audio Total: ${t2 - t0}ms (Prep: ${t1 - t0}ms, Engine Buffering: ${t2 - t1}ms)`.
3. Perform separate trials for:
   - Case A: Local downloaded track (offline).
   - Case B: Online JioSaavn track (cached vs uncached).
   - Case C: YouTube search result (first play vs replay).
4. Run five (5) trials per category under consistent network conditions.

### 3.3 YouTube Search Latency Protocol
1. Keystroke Responsiveness:
   - Verify that the keyboard input and text editing controller trigger without main-isolate jank.
2. Search Execution Timing:
   - **T_submit:** When `onSubmitted` is triggered.
   - **T_network_done:** When `YtMusicService().search()` or `YouTubeServices().fetchSearchResults()` returns the parsed JSON list.
   - **T_rendered:** When `setState()` completes and the first item is rendered.
3. Compare:
   - Cold query (never searched before).
   - Cached/repeated query (same session).

### 3.4 Frame Smoothness & Scrolling Profile
1. Enable Flutter Frame Timing capturing during test runs or via DevTools:
   ```dart
   WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
     for (final timing in timings) {
       final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
       final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
       final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
       if (totalMs > 16.6) {
         // Long frame detected
       }
     }
   });
   ```
2. Scroll through:
   - Home tab (with 10+ horizontal lists and promo cards).
   - Top Charts tab (100 items).
   - YouTube Search results (50 items).
3. Record percentage of frames exceeding the budget:
   - 60 Hz budget: > 16.6ms.
   - 90 Hz budget: > 11.1ms.
   - 120 Hz budget: > 8.3ms.

---

## 4. Workstation & Host Validation Protocol

While ultimate user-feel testing belongs to the physical device owner, the following automated benchmarks are run on the workstation before and after any change:

1. **Automated Regression Suite:**
   ```powershell
   flutter test --reporter expanded
   ```
   *Requirement:* 271 / 271 tests passing (0 failures).
2. **Static Analysis & Lint Debt Verification:**
   ```powershell
   flutter analyze lib test
   ```
   *Requirement:* Exactly matches the 364 pre-existing debt baseline (0 new errors or warnings).
3. **Syntactic Cleanliness:**
   ```powershell
   git diff --check
   ```
   *Requirement:* Clean exit code 0.
4. **Startup Flow Unit / Harness Benchmarks:**
   Run `test/startup_optimization_test.dart` and `test/batch_7_audio_engine_test.dart` to verify that initialization sequencing and stream emissions remain contract-compliant.

---

## 5. Physical Device Requirements for Owner Acceptance

When candidate implementation batches are released to the owner:
- **Build Mode:** Profile or Release mode APK (or consistent Debug APK matching the Phase D baseline).
- **Environment State:** Recorded WiFi vs Mobile data, battery level > 20%, thermal throttling absent.
- **Reporting Format:** The owner provides observed startup seconds and user-experience feedback against the 8 primary issue descriptions.
