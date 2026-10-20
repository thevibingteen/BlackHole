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

## Project Overview

**BlackHole** is a modern, high-performance, feature-packed music player application built with Flutter. It combines online streaming discovery with seamless local offline music playback, custom playlist organization, synchronized lyrics, and flexible audio customization.

This repository ([thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole)) is a community-maintained modification of BlackHole. It builds upon the foundational architecture created by original author Ankit Sangwan and open-source contributors, providing stabilization, bug fixes, updated community links, and continuous build maintenance. This repository is not the original upstream project, nor does the current maintainer claim authorship of every inherited line of code.

---

## Get Updates and Community Builds

Follow the community channels for announcements, discussions, and build information:

* Follow the [BlackHole Revived Telegram Channel](https://t.me/blackholerevived) for project updates and any community-shared build information.
* Join the [BlackHole Telegram Group](https://t.me/+_9wHWiHi1MdmMGM1) for discussion, feedback, and community support.

> **Note**: This community build series is not distributed on Google Play, the Apple App Store, F-Droid, or third-party repositories. For testing and development, you can build directly from source using the instructions below or check the Telegram community channels for shared builds.

---

## Features

* **High-Quality Streaming**: High-quality audio streaming where available (up to 320 kbps AAC from supported providers).
* **Comprehensive Search**: Search across songs, albums, artists, and playlists from supported online catalogs and YouTube.
* **Language-Specific Discovery**: Language-aware promoted playlists and localized Home discovery across 15+ catalog languages where available.
* **Trending & Top Hits**: Explore trending songs and curated local and global charts (JioSaavn chart data).
* **Artist & Genre Radios**: Infinite, continuous radio playback stations based on selected artists or genres.
* **Favorites & Custom Playlists**: Organize your library with favorite tracks and custom user-created playlists.
* **Multi-Source Playlist Import**: Import playlists from supported providers, including Spotify, YouTube, JioSaavn, and Deezer.
* **JSON Playlist Import & Export**: Export your playlists to standard JSON files for backup or share them across devices.
* **Synchronized & Static Lyrics**: Built-in lyrics display support with time-synced highlighting when available.
* **Queue Management & Listening History**: Reorder upcoming tracks, view recently played songs, and manage playback queues effortlessly.
* **Custom Theming & Visuals**: Rich dark mode, customizable color gradients, dynamic accent colors, and responsive support for both portrait and landscape orientations.
* **Offline Playback & Local Downloads**: Download audio tracks with embedded ID3 metadata tags (where supported by source) and play local audio files seamlessly without an internet connection.
* **In-App Tag Editing**: View and modify audio metadata and ID3 tags directly inside the app.
* **YouTube Discovery & Audio Playback**: Search YouTube playlists and videos, streaming audio tracks without video overhead.
* **Song Recommendations**: Dynamic track suggestions and autoplay recommendations based on currently playing music.
* **Built-in Equalizer**: Built-in audio equalization to fine-tune your listening experience.
* **Sleep Timer**: Schedule automatic playback shutoff for bedtime listening.
* **Local Backup & Restore**: Backup and restore user settings, favorites, and playlists locally using Hive storage.
* **Integrated Update Check**: Check for newly published repository releases directly from the Settings screen.
* **No Subscriptions, No Ads**: Fully open-source with no subscription fees or in-app advertising.

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

1. **Flutter SDK**: Ensure you have Flutter `>=3.0.0` installed (the CI build pipeline uses Flutter `3.10.6` stable). See the [official Flutter documentation](https://flutter.dev/docs/get-started/install) for installation details.
2. **Java Development Kit (JDK)**: JDK 11 (e.g. Eclipse Temurin 11).
3. **Android SDK**: Android SDK platform tools with API Level 33+.

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/thevibingteen/BlackHole.git
   cd BlackHole
   ```

2. Switch to the active development branch:
   ```bash
   git checkout ui-reference-build/blackhole-main
   ```

3. Install project dependencies:
   ```bash
   flutter pub get
   ```

4. Run the automated test suite:
   ```bash
   flutter test test/backend_test.dart test/widget_test.dart
   ```

5. Launch the application:
   ```bash
   flutter run
   ```

---

## Contributing

Contributions are welcome! Whether reporting a bug, proposing a new feature, or submitting code improvements, please read our [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md) before getting started.

* Submit pull requests against the `ui-reference-build/blackhole-main` branch.
* Ensure code adheres to `dart format` and all tests pass with `flutter test`.

---

## Issues & Support

* If you encounter a bug or have a suggestion, please check the [Issue Tracker](https://github.com/thevibingteen/BlackHole/issues) to see if it has already been addressed, or open a new issue.
* **Email Support**: [thevibingteen@gmail.com](mailto:thevibingteen@gmail.com)
* **Instagram**: [thevibingteen](https://www.instagram.com/thevibingteen)

---

## Community & Beta Support

Stay connected and test preview updates with the community:

* **Telegram Group**: [Join the BlackHole Telegram Group](https://t.me/+_9wHWiHi1MdmMGM1)
* **Telegram Channel**: [Follow the BlackHole Revived Telegram Channel](https://t.me/blackholerevived)

---

## Sponsorship & Donations

If you appreciate the work being done on this project and want to support ongoing maintenance:

* **Buy Me a Coffee**: [Support the project on Buy Me a Coffee](https://buymeacoffee.com/thevibingteen)
* **PayPal**: [Donate or sponsor the project using PayPal](https://www.paypal.com/ncp/payment/859SMGK59Z48L)

---

## License & Acknowledgements

* **License**: This project is licensed under the [GNU General Public License v3.0](LICENSE).
* **Original Author**: Special thanks and credit to [Ankit Sangwan](https://github.com/Sangwan5688) and the original upstream contributors for authoring the initial BlackHole codebase.
* **Open-Source Community**: Thank you to the Flutter team, Dart community, and authors of the third-party libraries that make this application possible.

---

## Privacy, Safety & Educational-Use Disclaimer

BlackHole is an open-source educational and community development project created for personal learning, experimentation, and research.

* **Content Ownership**: BlackHole does not host, store, index, or own any audio tracks, music files, artwork, or stream content. All media accessible through the application belongs to its respective copyright owners and providers.
* **User Responsibility**: Users of this software are solely responsible for ensuring that their playback, downloading, and usage comply with applicable laws and the terms of service of third-party media sources.
* **No Infringement Endorsement**: This project does not endorse, encourage, or facilitate copyright infringement.
* **License Preservation**: This educational disclaimer does not limit, waive, or contradict any terms or rights under the GNU General Public License v3.0 (GPL v3). The complete GPL v3 license remains in full effect.

---

## Third-Party Services & API Disclaimer

BlackHole interfaces with publicly accessible third-party APIs and content services (such as JioSaavn, YouTube, Spotify, and Deezer) to provide search, metadata, and streaming capabilities.

* These third-party services are independent entities with their own terms of service, rate limits, and policies.
* The availability, performance, and functionality of third-party features depend on external service continuity and cannot be guaranteed.
* BlackHole is not affiliated with, endorsed by, or sponsored by any of these third-party services.
