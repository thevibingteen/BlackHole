# Contributing to BlackHole

Thank you for your interest in contributing to BlackHole! This repository ([thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole)) is a community-maintained fork and ongoing revival of the BlackHole open-source Flutter music player.

We welcome bug reports, feature suggestions, documentation enhancements, and pull requests from the community.

---

## Code of Conduct & Policies

Before contributing, please review our community and governance documents:

* [Code of Conduct](CODE_OF_CONDUCT.md) — Standards of respectful, inclusive community interaction.
* [Software License (GPL-3.0)](LICENSE) — The governing copyleft software license.
* [Legal & Educational-Use Disclaimer](DISCLAIMER.md) — Information on non-affiliation, third-party services, and media rights.
* [Terms of Use](TERMS_OF_USE.md) — Project expectations and guidelines.
* [Privacy Policy](PRIVACY_POLICY.md) — Data handling, local storage, and third-party endpoints.
* [Security Policy](SECURITY.md) — Vulnerability reporting and responsible disclosure.

All contributors and participants are expected to adhere to these standards.

---

## Getting Started

### 1. Check Existing Issues
* Before opening a new issue or writing code, check the [Issue Tracker](https://github.com/thevibingteen/BlackHole/issues) to see if a similar bug or feature request has already been reported.
* If an open issue exists and someone is already actively working on it, please leave a comment to coordinate efforts before starting work.

### 2. Reporting Bugs & Feature Requests
* **Bug Reports**: Open an issue using the [Bug Report template](https://github.com/thevibingteen/BlackHole/issues/new?template=bug_report.md). Provide clear steps to reproduce the issue, device details (Android version, device model), app version/commit, and relevant logs if available.
* **Feature Requests**: Suggest ideas or improvements using the [Feature Request template](https://github.com/thevibingteen/BlackHole/issues/new?template=feature_request.md). Clearly describe the problem, the proposed solution, and any alternatives considered.

---

## Development Environment & Toolchain

To ensure consistency with the repository's continuous integration (CI) pipeline and avoid unexpected regressions, use the verified toolchain:

* **Flutter SDK**: `>=3.0.0` (The automated GitHub Actions CI build pipeline is verified on Flutter `3.10.6` stable).
* **Dart SDK**: Compatible with `environment: sdk: ">=2.18.0 <4.0.0"` in [`pubspec.yaml`](pubspec.yaml).
* **Java Development Kit (JDK)**: JDK 11 (Eclipse Temurin 11 is used in CI).
* **Android SDK**: API level 33+ platform tools and build tools.
* **Target Platforms**: Android (ARM64, ARMv7, x86_64).

---

## Development Workflow

### 1. Fork and Clone
Fork the repository on GitHub, then clone your fork locally:

```bash
git clone https://github.com/<your-username>/BlackHole.git
cd BlackHole
```

### 2. Working Branch
The default branch and primary integration target for this repository is:
**`main`**

Create your topic branch based on `main`:

```bash
git checkout -b fix/your-bug-description main
```

*(Note: Automated split-ABI release APK builds in GitHub Actions are triggered on branches matching `ui-reference-build/*` via [`.github/workflows/ui-reference-build.yml`](.github/workflows/ui-reference-build.yml)).*

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
Before submitting your changes, run the automated test suite and verify code formatting:

```bash
# Verify code formatting adheres to Dart standards
dart format --output=none --set-exit-if-changed .

# Run the test suite (unit and widget tests)
flutter test test/backend_test.dart test/widget_test.dart
```

---

## Pull Request Guidelines

1. **Focused Scope**: Keep changes focused on the problem being solved. Avoid unrelated refactors, cosmetic re-formatting of untouched files, or unneeded dependency changes.
2. **Target Branch**: Submit pull requests targeting the **`main`** branch of [thevibingteen/BlackHole](https://github.com/thevibingteen/BlackHole).
3. **Preserve Upstream Attribution & Licenses**: Retain all existing copyright notices, author attributions, and license headers in existing files in accordance with the [GNU General Public License v3.0](LICENSE).
4. **No Secrets or Binary Artifacts**: Never commit API secrets, private credentials, keystore files, or generated binary build artifacts (`.apk`, `.aab`, ephemeral build caches).
5. **Self-Review Checklist**:
   - [ ] Code compiles without errors on Flutter `3.10.6` / JDK 11.
   - [ ] Tests pass via `flutter test test/backend_test.dart test/widget_test.dart`.
   - [ ] Dart code adheres to `dart format`.
   - [ ] Documentation and comments are updated if behavior or configuration changed.
   - [ ] Upstream author credits and GPL-3.0 headers remain intact.
