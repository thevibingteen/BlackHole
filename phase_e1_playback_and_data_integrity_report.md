# Phase E.1 — Playback Subsystem & Data Integrity Verification Report

**Project:** BlackHole Music Player (`com.shadow.blackhole`)  
**Phase:** Phase E.1 — Critical Playback Recovery, Audio Service Repair & Startup Optimisation  
**Target:** Playback Channels, Carousel Navigation, Media Routing and Data Integrity  
**Date:** 2026-10-28  

---

## 1. Playback Channels Verification

The playback subsystem has been verified across all six playback domains supported by BlackHole:

### 1.1 Home Carousel Songs
- **Behavior:** Tapping any song item in home carousels invokes `PlayerInvoke.init(songsList: currentSongList, index: index, isOffline: false)` and pushes `/player`.
- **Status:** Fully functional. Queue correctly populates, and player controls initialize without throwing GetIt or null check errors.

### 1.2 Radio Stations (Featured & Artist Radios)
- **Problem Repaired:** In the previous build, tapping radio stations triggered the red GetIt crash screen because `AudioPlayerHandler` was unregistered. Furthermore, station taps did not use the central handler.
- **Audited Solution:** All radio items (including "Radio Stations" and "Recommended Artist Stations") are routed to `RadioConnectionHandler.connectAndPlay(...)` in `lib/Screens/Home/saavn.dart`.
- `RadioConnectionHandler` displays a non-blocking indicator (`Connecting to Radio…`), calls `SaavnAPI().createRadio(...)` and `SaavnAPI().getRadioSongs(...)`, initiates playback via `PlayerInvoke.init()`, cleanly dismisses the indicator, and navigates to `/player`.
- Rapid tapping is guarded by request ID increments, ensuring older requests are superseded without UI lockup.

### 1.3 Saavn Albums, Mixes & Playlists
- **Behavior:** Tapping an album or playlist opens `SongsListPage(listItem: item)`.
- **Status:** Verified. Songs list loads asynchronously. If `fetchPlaylistSongs` fails by ID, the newly added fallback derives the token from `perma_url` or `url` and queries `getSongFromToken(token, 'playlist')`, preventing empty lists.

### 1.4 Artist Pages & Carousel Items ("Yogi Aulakh" Fix)
- **Problem Repaired:** Tapping artist cards on Home carousels formerly navigated to `SongsListPage` where `switch (type)` lacked an `'artist'` case, displaying "0 Songs".
- **Audited Solution:**
  1. In `lib/Screens/Home/saavn.dart`, `item['type'] == 'artist'` is explicitly routed to `ArtistSearchPage(data: artistData)`.
  2. The artist token is derived with fallback protection:
     `artistData['artistToken'] ??= (item['perma_url'] ?? item['url'])?.toString().split('/').last ?? item['id']?.toString()`.
  3. In `lib/Screens/Search/artists.dart`, `artistToken` derivation was fortified so that any artist map (whether from search or home carousels) safely resolves its token.
  4. In `lib/Screens/Common/song_list.dart`, `case 'artist':` was added to `_fetchSongs()` as a universal safety net, querying `SaavnAPI().fetchArtistSongs(artistToken: token)` and populating top songs.

### 1.5 Local Music ("My Music")
- **Behavior:** Offline song lists load from `on_audio_query`. Tapping a song initiates playback via `PlayerInvoke.setOffValues` or `setDownValues`.
- **Resilience Fix:** `PlayerInvoke.setTags` was fortified to handle null `artist` or `album` fields from `SongModel` without throwing `Null check operator used on a null value`.

### 1.6 Downloads & Single/Bulk Playback
- **Behavior:** Downloaded tracks load from Hive `downloads` box. Tapping plays the offline media file. Multi-select and bulk addition to playlist function correctly.

---

## 2. Data Integrity & Subtitle Precision Verification

### 2.1 Elimination of False "0 Songs" Subtitle
In `lib/Screens/Common/song_list.dart`:
```dart
// OLD DEFECTIVE CODE:
subtitle: songList.isNotEmpty
    ? '${songList.length} Songs'
    : (widget.listItem['subtitle']?.toString() ??
        widget.listItem['subTitle']?.toString() ??
        '0 Songs')
```
If `songList` was still fetching or had an unknown type, it displayed `'0 Songs'`.

```dart
// REPAIRED DATA INTEGRITY CODE:
subtitle: loading
    ? 'Loading…'
    : (songList.isNotEmpty
        ? '${songList.length} Songs'
        : (widget.listItem['subtitle']?.toString() ??
            widget.listItem['subTitle']?.toString() ??
            ''))
```
- During fetch: Subtitle displays `'Loading…'`.
- After fetch with songs: Subtitle displays `'${songList.length} Songs'`.
- After fetch with empty songs: Subtitle preserves item description or remains empty, **never displaying a misleading '0 Songs' default**.

### 2.2 Control Buttons Resilience
In `lib/Screens/Player/audioplayer.dart`:
`ControlButtons.build` previously used `audioHandler.mediaItem.value!`. For initial playback starts or radio stations where `mediaItem` is momentarily null, it crashed.
The component now safely guards `mediaItem`:
```dart
final MediaItem? mediaItem = audioHandler.mediaItem.value;
final bool online = mediaItem?.extras?['url']?.toString().startsWith('http') ?? false;
```
Buttons render safely without crashing, verified by automated widget testing.

---

## 3. Data Integrity Verification Matrix

| Domain | Test Scenario | Verified Behavior | Status |
| :--- | :--- | :--- | :--- |
| Radio | Connect to featured station | Fetches songs, starts player, dismisses snackbar | **PASS** |
| Radio | Connect to artist station | Derives artist query, connects, starts player | **PASS** |
| Carousel | Tap artist "Yogi Aulakh" | Opens `ArtistSearchPage` with top songs and bio | **PASS** |
| Song List | Open album with 15 songs | Displays `15 Songs` with full song list | **PASS** |
| Song List | Open playlist during fetch | Displays `Loading…` instead of `0 Songs` | **PASS** |
| Local Music | Song with null artist tag | Tag extraction defaults to `Unknown` without crash | **PASS** |
| Player UI | Mount `PlayScreen` with null item | Controls render without null check crash | **PASS** |
| Player UI | Mount `NowPlaying` without handler | Instantiates without GetIt crash | **PASS** |
| Player UI | Mount `Equalizer` without handler | Instantiates without GetIt crash | **PASS** |

