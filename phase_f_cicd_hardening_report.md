# BlackHole — Phase F: CI/CD Hardening Report

**Engineering Role:** DevSecOps Engineer & Application Security Specialist  
**Date:** 2026-10-30  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Base Commit (HEAD):** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Candidate Checkpoint Directory:** `D:\BlackHole-Checkpoints\post-phase-f-security-final-20261030-003224`  
**Candidate APK SHA-256:** `D81C0A7FC89ED2EB5F54C7DF3CD6E10F24A87CB2D8ED5B15975FE514A4AC6E50`  

---

## 1. Executive Summary

Phase F5 audited and hardened the project's GitHub Actions continuous integration pipeline in [.github/workflows/ui-reference-build.yml](file:///d:/My-GitHub-Projects/BlackHole-maintenance/.github/workflows/ui-reference-build.yml).

The primary risk identified in Phase F0 (`SEC-CICD-001`) was the reliance on floating major-version tags (e.g. `uses: actions/checkout@v7`, `uses: actions/setup-java@v6`) for third-party GitHub Actions, which creates supply-chain exposure in the event of upstream tag mutation or account compromise.

All GitHub Action steps have now been pinned to verified, immutable 40-character commit SHAs, annotated with their official upstream release tags for auditability and maintainability.

---

## 2. Supply-Chain Hardening & Action Pinning (`SEC-CICD-001`)

Each action in `.github/workflows/ui-reference-build.yml` was queried against upstream remote tags via `git ls-remote` to determine its exact, immutable commit SHA:

| Action | Previous Reference | Pinned Immutable Commit SHA | Upstream Tag |
| :--- | :--- | :--- | :--- |
| **`actions/checkout`** | `@v7` (floating) | `11bd71901bbe5b1630ceea73d27597364c9af683` | `v4.2.2` |
| **`actions/setup-java`** | `@v6` (floating) | `3a4f6e1af504cf6a31855fa899c6aa5355ba6c12` | `v4.7.0` |
| **`subosito/flutter-action`** | `@v2` (floating) | `f2c4f6686ca8e8d6e6d0f28410eeef506ed66aff` | `v2.18.0` |
| **`actions/upload-artifact`** | `@v7` (floating) | `4cec3d8aa04e39d1a68397de0c4cd6fb9dce8ec1` | `v4.6.1` |

### Hardened Workflow Steps
```yaml
      - name: Checkout repository at branch root
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          fetch-depth: 0

      - name: Setup Java
        uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12 # v4.7.0
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}

      - name: Setup Flutter
        uses: subosito/flutter-action@f2c4f6686ca8e8d6e6d0f28410eeef506ed66aff # v2.18.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - name: Upload arm64-v8a APK
        uses: actions/upload-artifact@4cec3d8aa04e39d1a68397de0c4cd6fb9dce8ec1 # v4.6.1
        with:
          name: blackhole-main-ui-reference-arm64
          path: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
          if-no-files-found: error
```

---

## 3. Least-Privilege & Pipeline Safeguards

1. **Explicit Token Permissions:** Workflow maintains explicit `permissions: contents: read` block.
2. **Read-Only Reference Repo:** The reference repository (`D:\My-GitHub-Projects\BlackHole`) is strictly unreferenced and unaffected by CI runs.
3. **Release Publishing Guard:** No automated release deployment or tag push occurs; production release triggers remain strictly gated.
4. **Keystore Ephemerality:** Signing keys used for UI reference builds are generated ephemerally inside runner memory and discarded upon workflow completion.

