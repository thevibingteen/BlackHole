# Privacy Policy

**Project**: BlackHole (Community-Maintained Fork)  
**Repository**: [thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole)  
**Maintainer**: [@thevibingteen](https://github.com/thevibingteen)  
**Effective Date**: October 23, 2026

---

## 1. Introduction

This Privacy Policy describes how the BlackHole open-source Flutter music player application ("BlackHole") handles data, requests device permissions, and interacts with third-party network services.

BlackHole is designed with a **privacy-first architecture**. It does not require user registration or an application-specific user account, does not embed advertising frameworks, and does not transmit usage telemetry or analytics to the repository maintainer.

---

## 2. Information Handled by the Maintainer

* **No Maintainer Data Collection**: The repository maintainer does not operate a remote user-tracking server, authentication server, telemetry backend, or user database.
* **No Account Creation**: You do not need to create an account, provide an email address, or provide personal identity details to use the BlackHole application.
* **No Tracking or Advertising SDKs**: The application contains no Google Analytics, Firebase Analytics, Facebook SDK, Crashlytics, AdMob, or third-party behavioral profiling trackers.

---

## 3. Data Stored Locally on Your Device

BlackHole stores application state and user preferences locally on your device using Hive database storage within the application's sandboxed private directory:

| Category | Storage Mechanism | Description | User Control |
| :--- | :--- | :--- | :--- |
| **Settings & Preferences** | Local Hive Box (`settings`) | UI theme mode, accent colors, preferred music discovery languages, audio quality selection, download path. | Configurable via Settings screen. |
| **Favorites & Playlists** | Local Hive Box (`favoriteSongs`, custom playlists) | Songs added to favorites and user-created custom playlists. | Editable/deletable directly in app; exportable to local JSON. |
| **Search History** | Local Hive Box (`searchHistory`, `ytSearch`) | Recent search queries entered by the user. | Clearable in Settings (`Clear Search History`). |
| **Playback History & Queue** | Local Hive Box (`recent`, `queue`) | Recently played tracks and active queue state. | Clearable in Settings (`Clear Recently Played`). |
| **Spotify OAuth Tokens** | Local Hive Box (`settings`) | Optional Spotify PKCE access and refresh tokens when a user explicitly logs in to import Spotify playlists. | Removed when the user disconnects or clears app data. |
| **Downloaded Media & Artwork** | Local Device Storage | Audio tracks (`.mp3`, `.m4a`) downloaded by the user, with embedded ID3 metadata tags, and cached album art images. | Manageable directly in file manager or within the app. |

All locally stored Hive data remains on your device and can be backed up or restored via the in-app Backup/Restore feature (saved to user-selected files) or wiped completely by clearing the app data in Android system settings.

---

## 4. Device Permissions Requested

BlackHole requests only permissions necessary for local audio playback, file management, and streaming:

| Permission | Android API Levels | Purpose in Application |
| :--- | :--- | :--- |
| `android.permission.INTERNET` | All | Fetching search results, streaming audio, downloading artwork and lyrics from external services, and checking for app updates on GitHub. |
| `android.permission.READ_EXTERNAL_STORAGE` | Up to API 32 | Scanning, indexing, and playing audio files stored on the device's shared storage. |
| `android.permission.WRITE_EXTERNAL_STORAGE` | Up to API 29 / legacy | Saving downloaded audio tracks and exporting backup/playlist files. |
| `android.permission.MANAGE_EXTERNAL_STORAGE` | API 30+ (Optional) | Broad storage management for reading/writing local audio tracks and backup files across custom directories on Android 11+. |
| `android.permission.FOREGROUND_SERVICE` | All | Maintaining uninterrupted background audio playback and displaying media playback controls in the system notification shade. |
| `android.permission.WAKE_LOCK` | All | Preventing device sleep from terminating active audio streaming while the screen is off. |

---

## 5. Third-Party Network Services & Endpoint Interactions

To provide online streaming, track discovery, playlist importing, lyrics, and update notifications, BlackHole communicates directly with third-party endpoints from your device.

When your device communicates with these external services, standard HTTP request metadata (including your device's IP address and user-agent string) is inherently received by the external server. The data practices of these external providers are governed by their respective privacy policies:

1. **JioSaavn** (`jiosaavn.com`):
   - **Purpose**: Search queries, catalog browsing, top charts, song metadata, and audio stream URL resolution.
   - **Data Sent**: Search terms, requested song/album/playlist IDs, preferred language selections.
   - **Provider Policy**: Governed by JioSaavn's Terms of Service and Privacy Policy.

2. **YouTube & YouTube Music** (`youtube.com`, `music.youtube.com`, `google.com`):
   - **Purpose**: Searching YouTube videos/music, audio stream URL extraction via `youtube_explode_dart`, and search query auto-completion via `suggestqueries.google.com`.
   - **Data Sent**: Search terms, video identifiers.
   - **Provider Policy**: Governed by Google/YouTube Privacy Policy and Terms of Service.

3. **Spotify** (`accounts.spotify.com`, `api.spotify.com`):
   - **Purpose**: Optional user playlist importing and Top Charts discovery.
   - **Data Sent**: If you choose to connect your Spotify account, Spotify's authorization flow (PKCE OAuth) runs directly between your device and Spotify. BlackHole requests read-only scopes (`user-read-private`, `playlist-read-private`, `playlist-read-collaborative`). Access tokens are stored locally on your device and are never sent to the maintainer.
   - **Provider Policy**: Governed by Spotify Privacy Policy.

4. **LRCLIB** (`lrclib.net`):
   - **Purpose**: Retrieving synchronized (`.lrc`) and plain text lyrics.
   - **Data Sent**: Track title, artist name, and album name for lyrics matching.
   - **Provider Policy**: Governed by LRCLIB's terms.

5. **Deezer** (`api.deezer.com`):
   - **Purpose**: Resolving public Deezer playlist links for playlist importing.
   - **Data Sent**: Public playlist ID requested by user.
   - **Provider Policy**: Governed by Deezer Privacy Policy.

6. **GitHub** (`api.github.com`):
   - **Purpose**: Checking for new releases of this repository via `Settings -> Check for Update`.
   - **Data Sent**: Standard GitHub API query for latest release tag in `thevibingteen/BlackHole`.
   - **Provider Policy**: Governed by GitHub Privacy Statement.

---

## 6. Diagnostic Logging & Crash Reports

* **Local Logs**: The app captures technical diagnostic events locally in memory and temporary session files using the standard Dart `logging` package to assist in troubleshooting playback or network errors.
* **No Automatic Telemetry Upload**: Log files are **never** automatically sent or uploaded to any server.
* **Manual Log Sharing**: A user may choose to export or share session logs voluntarily using the in-app feature (`Settings -> Others -> share logs`). When clicked, the logs are passed to Android's system share sheet for the user to send through their chosen messaging or email client.

---

## 7. Children's Privacy

BlackHole does not knowingly collect, store, or solicit personal information from children or any other users.

---

## 8. Updates to this Policy

As the application evolves or third-party service integrations change, this Privacy Policy may be updated. Revisions will be committed to this repository with an updated effective date.

---

## 9. Contact & Inquiries

If you have questions, feedback, or concerns regarding privacy in BlackHole, please contact the maintainer:

* **Maintainer**: [@thevibingteen](https://github.com/thevibingteen)
* **Email**: [thevibingteen@gmail.com](mailto:thevibingteen@gmail.com)
* **Issue Tracker**: [GitHub Issues](https://github.com/thevibingteen/BlackHole/issues)
