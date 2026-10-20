# Contributing to BlackHole

Thank you for your interest in contributing to BlackHole! This repository ([thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole)) is a community-maintained version of the BlackHole open-source Flutter music player.

We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

---

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating in this project. All contributors and participants are expected to adhere to its standards to maintain a welcoming, respectful, and harassment-free community.

---

## Getting Started

### 1. Check Existing Issues
- Before opening a new issue or writing code, check the [issue tracker](https://github.com/thevibingteen/BlackHole/issues) to see if a similar bug or feature request has already been reported.
- If an open issue exists and someone is already actively working on it, please leave a comment to coordinate efforts before starting work.

### 2. Reporting Bugs & Feature Requests
- **Bugs**: If you find a new bug, please open an issue using the [Bug Report template](https://github.com/thevibingteen/BlackHole/issues/new/choose). Provide clear steps to reproduce the behavior, device details (OS version, device model), app version, and relevant logs if available.
- **Feature Requests**: Suggest ideas or improvements using the [Feature Request template](https://github.com/thevibingteen/BlackHole/issues/new/choose). Clearly describe the problem, the proposed solution, and any alternatives considered.

---

## Development Environment & Toolchain

To ensure consistency with the repository's continuous integration (CI) pipeline, use the following supported environment:

- **Flutter SDK**: `>=3.0.0` (CI pipeline uses Flutter `3.10.6` stable)
- **Dart SDK**: Compatible with `environment: sdk: ">=2.18.0 <4.0.0"` in [`pubspec.yaml`](pubspec.yaml)
- **Java Development Kit (JDK)**: Java 11 (Temurin Hotspot JDK 11 is used in CI)
- **Android SDK**: API level 33+ platform tools

---

## Development Workflow

### 1. Fork and Clone
Fork the repository on GitHub, then clone your fork locally:

```bash
git clone https://github.com/<your-username>/BlackHole.git
cd BlackHole
```

### 2. Working Branch
The primary development branch for this build series is:
`ui-reference-build/blackhole-main`

Create your topic branch based on `ui-reference-build/blackhole-main`:

```bash
git checkout -b fix/your-bug-description ui-reference-build/blackhole-main
```

### 3. Install Dependencies
Fetch the project packages:

```bash
flutter pub get
```

### 4. Running the App
Run on a connected Android device, emulator, or desktop target:

```bash
flutter run
```

### 5. Running Tests & Code Quality Checks
Before submitting your changes, run the test suite and verify code formatting:

```bash
# Format code
dart format --output=none --set-exit-if-changed .

# Run test suites
flutter test test/backend_test.dart test/widget_test.dart
```

---

## Pull Request Guidelines

1. **Focused Scope**: Keep changes focused on the problem being solved. Avoid unrelated refactors, cosmetic re-formatting of untouched files, or dependency churn.
2. **Preserve User Changes**: When working in a shared workspace or branch, be mindful of existing changes and do not discard user work.
3. **Target Branch**: Submit pull requests against the `ui-reference-build/blackhole-main` branch of [thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole).
4. **Self-Review Checklist**:
   - [ ] Code compiles and passes `flutter test`.
   - [ ] Dart code adheres to `dart format`.
   - [ ] Documentation and comments are updated if behavior changed.
   - [ ] No secrets, keys, or unintended build artifacts are committed.
   - [ ] License and copyright headers on inherited files remain preserved.

---

## References

- [Project README](README.md)
- [GNU General Public License v3.0](LICENSE)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [GitHub Issues](https://github.com/thevibingteen/BlackHole/issues)
