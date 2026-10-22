![Repo Banner](https://user-images.githubusercontent.com/87353286/144381080-faf8e557-7909-43a1-a8e2-208936e5a8f8.png)

# BlackHole

An open-source Flutter music player for online and offline music discovery and playback.

[![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-1f425f.svg)](https://flutter.dev/)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)
[![UI Reference Build](https://github.com/thevibingteen/BlackHole/actions/workflows/ui-reference-build.yml/badge.svg?branch=ui-reference-build%2Fblackhole-main)](https://github.com/thevibingteen/BlackHole/actions/workflows/ui-reference-build.yml)
[![GitHub stars](https://img.shields.io/github/stars/thevibingteen/BlackHole.svg?style=social&label=Star)](https://github.com/thevibingteen/BlackHole)
[![GitHub forks](https://img.shields.io/github/forks/thevibingteen/BlackHole.svg?style=social&label=Forks)](https://github.com/thevibingteen/BlackHole/network/members)

⭐ If you enjoy using BlackHole or find this project helpful, please consider starring the repository!

---

## Project Overview & Identity

**BlackHole** is a modern, feature-packed music player application built with Flutter. It combines online streaming discovery with seamless local offline music playback, custom playlist organization, synchronized lyrics, and flexible audio customization.

This repository ([thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole)) is a **community-maintained fork and ongoing revival** of BlackHole, maintained by [@thevibingteen](https://github.com/thevibingteen). It builds upon the foundational architecture originally created by [Ankit Sangwan](https://github.com/Sangwan5688) and open-source contributors, providing stabilization, bug fixes, updated community links, reproducible continuous integration, and ongoing maintenance.

* **Upstream Attribution**: This repository is a derivative work and not the original upstream project. The current maintainer does not claim authorship of inherited upstream code or ownership of third-party assets. Upstream copyright notices and licenses are fully preserved in compliance with the [GNU General Public License v3.0](LICENSE).
* **Educational & Research Purpose**: This project is maintained primarily for learning, research, Flutter architecture exploration, and community maintenance.

---

## Distribution & Build Availability

* **No Commercial Distribution**: This project is maintained as a community and educational software project. The current maintainer does not operate an official paid commercial distribution channel, sell application licenses, or monetize user access.
* **No Official App Store Presence**: The application is not officially published or distributed on Google Play, the Apple App Store, F-Droid, or commercial third-party app stores.
* **Source & Testing Artifacts**: Source code is available in this repository. Automated continuous integration (CI) development and testing APK artifacts (Split-ABI: `arm64-v8a`, `armeabi-v7a`, `x86_64`) are generated via [GitHub Actions](https://github.com/thevibingteen/BlackHole/actions).
* **Community Channels**: Project announcements, preview testing information, and community discussions are shared via Telegram:
  * [BlackHole Revived Telegram Channel](https://t.me/blackholerevived) — Announcements and community build information.
  * [BlackHole Telegram Group](https://t.me/+_9wHWiHi1MdmMGM1) — Discussion, feedback, and peer support.

---

## Verified Features

* **High-Quality Online Streaming**: Audio streaming up to 320 kbps AAC/MP4 where provided by supported endpoints (JioSaavn catalog).
* **YouTube Music & Video Stream Audio**: Search YouTube videos and playlists, extracting audio tracks directly for lightweight playback without video overhead.
* **Synchronized & Plain Lyrics**: Real-time synchronized lyrics display powered by [LRCLIB](https://lrclib.net), with fallbacks to JioSaavn and Musixmatch text lyrics.
* **Comprehensive Search & Catalog Discovery**: Search songs, albums, artists, and playlists across supported online catalogs and YouTube.
* **Language-Specific Feed**: Localized Home discovery and promoted playlists across 15+ catalog languages (Hindi, English, Punjabi, Tamil, Telugu, and more).
* **Trending Hits & Charts**: Explore trending tracks and curated local and global charts (JioSaavn chart data).
* **Artist & Genre Radios**: Continuous, automated radio stations generated from selected artists or genres.
* **Multi-Source Playlist Import**: Import public playlists from Spotify (via client-side PKCE OAuth), YouTube, JioSaavn, and Deezer.
* **Offline Music & Local Downloads**: Download audio tracks with embedded ID3 metadata tags and album art, and index/play local audio files on device storage without internet access.
* **In-App ID3 Tag Editing**: View and modify audio metadata and tags directly on local files.
* **Queue Management & Listening History**: Reorder upcoming tracks, view recently played songs, and manage playback queues.
* **Custom Theming & Visuals**: Rich dark mode, customizable color gradients, dynamic accent colors, and responsive portrait/landscape layouts.
* **Audio Equalization & Sleep Timer**: Fine-tune listening preferences with built-in equalization and schedule automatic shutoff timers.
* **Local Backup & Restore**: Backup and restore user settings, favorites, and playlists locally using Hive storage.
* **Zero Subscriptions & Zero Ads**: 100% open-source with no advertising frameworks, subscription fees, or paid tiers.

---

## Screenshots

<p align="center">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" width="30%" alt="Search and Discover">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" width="30%" alt="Now Playing Screen">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" width="30%" alt="Synchronized Lyrics">
</p>
<p align="center">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/4.png" width="30%" alt="Queue Management">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/5.png" width="30%" alt="Settings and Themes">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/6.png" width="30%" alt="Top Charts">
</p>

---

## Building from Source

### Prerequisites

1. **Flutter SDK**: `>=3.0.0` (The automated GitHub Actions build pipeline is tested and verified on Flutter `3.10.6` stable). See the [official Flutter setup guide](https://flutter.dev/docs/get-started/install).
2. **Java Development Kit (JDK)**: JDK 11 (e.g., Eclipse Temurin 11).
3. **Android SDK**: Android SDK platform tools with API Level 33+.

### Step-by-Step Instructions

1. **Clone the repository**:
   ```bash
   git clone https://github.com/thevibingteen/BlackHole.git
   cd BlackHole
   ```

2. **Verify you are on the default branch**:
   ```bash
   git checkout main
   ```

3. **Install project dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the automated test suite**:
   ```bash
   flutter test test/backend_test.dart test/widget_test.dart
   ```

5. **Launch the application on a connected device or emulator**:
   ```bash
   flutter run
   ```

---

## Project Policies & Governance

Please consult our governance, compliance, and community documentation:

* [Software License (GPL-3.0)](LICENSE) — Full text of the GNU General Public License v3.0.
* [Legal & Educational-Use Disclaimer](DISCLAIMER.md) — Clarification of purpose, non-affiliation, media rights, and warranty limits.
* [Terms of Use](TERMS_OF_USE.md) — Guidelines for responsible usage, testing, and interaction.
* [Privacy Policy](PRIVACY_POLICY.md) — Disclosures regarding on-device data storage, device permissions, and third-party endpoints.
* [Security Policy](SECURITY.md) — Responsible vulnerability reporting guidelines and contacts.
* [Contributing Guidelines](CONTRIBUTING.md) — Development workflow, code standards, and pull request procedures.
* [Code of Conduct](CODE_OF_CONDUCT.md) — Community pledge and enforcement standards based on Contributor Covenant 2.0.

---

## Third-Party Services Disclaimer

BlackHole interfaces with publicly accessible third-party APIs and streaming endpoints (such as JioSaavn, YouTube, YouTube Music, Spotify, Deezer, and LRCLIB).

* These services are independent entities with their own terms of service, rate limits, and policies.
* The availability, performance, and formatting of third-party features depend on external service continuity and cannot be guaranteed.
* BlackHole is **not** endorsed by, sponsored by, or officially affiliated with any of these third-party platforms.

---

## Sponsorship & Donations

If you find this project valuable and wish to support ongoing maintenance and testing:

* **Buy Me a Coffee**: [buymeacoffee.com/thevibingteen](https://buymeacoffee.com/thevibingteen)
* **PayPal**: [Donate via PayPal](https://www.paypal.com/ncp/payment/859SMGK59Z48L)

---

## Acknowledgements

* **Original Upstream Author**: Sincere credit and thanks to [Ankit Sangwan](https://github.com/Sangwan5688) for creating the original BlackHole music player.
* **Contributors**: Gratitude to all open-source developers who have contributed patches, translations, and issue reports.
* **Ecosystem**: Special thanks to the Flutter team, Dart community, and authors of the open-source packages that power this application.
