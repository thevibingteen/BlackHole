# BlackHole — Song Multi-Select Implementation Report

**Author:** Senior Flutter Engineer & QA Lead  
**Date:** 2026-10-28  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  

---

## 1. Executive Summary

Physical testing on the owner's device showed that in "My Music" (`lib/Screens/LocalMusic/downed_songs.dart`) and "Downloads" (`lib/Screens/Library/downloads.dart`), long-pressing a song item did not trigger multi-selection mode, and the item popup menu provided only "Add to Playlist" without options to enter selection or perform deletion.

We implemented an intuitive, accessible multi-selection system across both local and downloaded song lists, featuring long-press entry, checkboxes, real-time selection counts, "Select All" / "Clear Selection", bulk "Add to Playlist", and bulk "Delete".

---

## 2. Requirements & Workflow Design

The multi-select implementation satisfies all authorized requirements:
1. **Entry Modes:**
   - **Long Press:** Long-pressing any song tile activates selection mode and selects the tapped song.
   - **Menu Item:** Choosing "Select" from the 3-dot popup menu enters selection mode for that song.
2. **Visual Indicators:**
   - Leading `Checkbox` widget appears beside every song item during selection mode.
   - Selected items display a distinct theme-aware highlight background.
   - The default trailing popup menu is temporarily hidden during selection mode to prevent conflicting touch targets.
3. **Contextual Action Toolbar:**
   - Positioned prominently at the top of the tab.
   - Displays real-time selected count: `"${_selectedAudioIds.length} Selected"`.
   - "Close" button (X) cancels selection mode and clears all selections.
   - "Select All" / "Clear" toggle selects or deselects all visible songs.
   - "Add to Playlist" icon button invokes bulk playlist addition.
   - "Delete" icon button initiates safe bulk song deletion with confirmation.
4. **Tap Behavior:**
   - Tapping any song while in selection mode toggles its selection without triggering audio playback.
   - Once all selections are cleared, the UI returns to normal mode.

---

## 3. Implementation Details

### 3.1 Local Music SongsTab (`lib/Screens/LocalMusic/downed_songs.dart`)
- Added state variables:
  ```dart
  final Set<int> _selectedAudioIds = {};
  bool get _isSelectionMode => _selectedAudioIds.isNotEmpty;
  ```
- Added contextual toolbar widget `_buildSelectionToolbar()` with action buttons and accessibility tooltips.
- Updated `ListTile`:
  - `leading`: When `_isSelectionMode`, displays `Checkbox(value: isSelected, onChanged: ...)`; otherwise displays album artwork thumbnail.
  - `onTap`: If `_isSelectionMode`, toggles ID in `_selectedAudioIds`; otherwise triggers `PlayerInvoke.init(...)`.
  - `onLongPress`: Toggles ID in `_selectedAudioIds` and triggers `setState()`.
  - `trailing`: Displays 3-dot popup menu with "Select", "Add to Playlist", and "Delete" in normal mode; hidden in selection mode.

### 3.2 Downloads Tab (`lib/Screens/Library/downloads.dart`)
- Added matching state variables and contextual toolbar `_buildSelectionToolbar()`.
- Wired multi-select support for downloaded Hive songs, matching the look, feel, and interaction model of `downed_songs.dart`.

### 3.3 Bulk Playlist Addition (`lib/CustomWidgets/add_playlist.dart`)
- Added helper functions:
  - `addMultipleToOffPlaylist(BuildContext context, List<int> audioIds)`: Adds multiple offline audio IDs to local SQLite/MediaStore playlists.
  - `addMultipleToPlaylist(BuildContext context, List<MediaItem> items)`: Adds multiple `MediaItem` records to custom Hive playlists.

---

## 4. Verification & Automated Test Results

Automated unit and widget tests were implemented in `test/song_multi_select_test.dart`:
1. `Normal mode shows song list without checkboxes and with popup menu`: Passed.
2. `Long press enters selection mode, displays toolbar and checkbox`: Passed.
3. `Select All selects all songs and updates toolbar count`: Passed.

**Automated Test Suite Status:** 3 / 3 passed (0 failures).

