# Phase E3 — YouTube Search & Data Layer Responsiveness Audit

## 1. Executive Summary
Phase E3 targets the user-reported latency and sluggishness during YouTube search and suggestions.

The investigation uncovered three primary factors degrading the search experience:
1. **Unmanaged Keystroke Flooding & Inflexible Debounce**:
   - In `lib/CustomWidgets/search_bar.dart`, every keystroke triggered an unmanaged `Future.delayed(Duration(milliseconds: 600))`.
   - Because `Future.delayed` cannot be cancelled, fast typing (e.g. 10 keystrokes) spawned 10 concurrently ticking async delays.
   - The 600ms threshold felt noticeably sluggish to users waiting for suggestions.
2. **Race Conditions & Stale Overwrite Vulnerability**:
   - Out-of-order network responses lacked any monotonic request identity.
   - If an earlier keystroke's network request took 600ms to resolve while a later keystroke's network request took 200ms, the earlier (stale) result arrived last and overwrote the fresher suggestions.
   - A similar race existed in `_YouTubeSearchPageState`, where asynchronous responses from fast consecutive queries could overwrite the active query's results.
3. **Absence of Query-Level In-Memory Caching**:
   - Backspacing, re-typing, or pressing back from video details triggered redundant external HTTP calls for identical queries and suggestions.
   - Repeated parsing of large YouTube Music section JSON trees introduced avoidable frame drops.

---

## 2. Bottlenecks Verified & Architectural Solutions

### 2.1 Cancellable Debounce Timer
- **Implementation**: Replaced `Future.delayed(600ms)` with a lifecycle-managed `Timer(250ms)`.
- **Impact**: Each keystroke cancels the preceding timer. Requests are only initiated once the user pauses typing for 250ms, drastically cutting unnecessary intermediate network traffic while feeling over twice as responsive. The timer is safely cancelled in `dispose()`.

### 2.2 Monotonic Request Token Guarding
- **Implementation**:
  - In `SearchBar`: Added `int _searchRequestId = 0`. Each debounce trigger increments the request ID. Results are only applied to `suggestionsList.value` if `currentRequestId == _searchRequestId && tempQuery == val`.
  - In `_YouTubeSearchPageState`: Added `int _searchToken = 0`. Results from `YtMusicService.search` or `YouTubeServices.fetchSearchResults` are only accepted if `currentToken == _searchToken`.
- **Impact**: Completely eliminates out-of-order response overwrites.

### 2.3 Bounded In-Memory Caches
- **Implementation**:
  - `YouTubeServices.getSearchSuggestions`: Introduced `_suggestionCache` (max 30 items, 5-minute TTL). Repeated keystrokes/backspaces return cached suggestions in 0 ms.
  - `YtMusicService.search`: Introduced `_searchResultCache` (max 20 items, 10-minute TTL). Keyed on normalized query, filter, scope, and spelling parameters.
- **Safety**: Only search metadata and candidate items are cached in memory; short-lived stream URLs are never stored here.

---

## 3. Preserved Safeguards
- All YouTube URL validation and hostname restrictions (`googlevideo.com`) remain intact.
- Query history persistence in Hive continues working as designed.
- Zero network requests are made on empty or cleared queries.
