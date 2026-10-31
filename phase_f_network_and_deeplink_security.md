# BlackHole — Phase F: Network & Deep-Link Security Report

**Engineering Role:** Application Security Engineer & Network Security Specialist  
**Date:** 2026-10-30  
**Target:** BlackHole Music Player (`com.shadow.blackhole`)  
**Worktree:** `D:\My-GitHub-Projects\BlackHole-maintenance`  
**Branch:** `maintenance/build-compatibility-upgrade`  
**Base Commit (HEAD):** `c983cdb1b9ca86504640d68c80d5c6b5d0640f75`  
**Candidate Checkpoint Directory:** `D:\BlackHole-Checkpoints\post-phase-f-security-final-20261030-003224`  
**Candidate APK SHA-256:** `D81C0A7FC89ED2EB5F54C7DF3CD6E10F24A87CB2D8ED5B15975FE514A4AC6E50`  

---

## 1. Executive Summary

Phase F2 audited external input boundaries, URI parsing, deep links, scheme dispatchers, and network traffic policies.

Prior to remediation, deep-link handling in `route_handler.dart` relied on loose substring checks (e.g. `cleanUrl.contains('youtube')`, `cleanUrl.contains('saavn')`, `cleanUrl.contains('spotify')`), allowing deceptive hostnames (e.g. `attacker-youtube.com`, `notyoutube.com`) or URLs with redirect query parameters to trigger internal handlers. Furthermore, external URI launching in `app_links.dart` lacked protocol restrictions, and `OfflinePlayHandler` mishandled missing song indices (`-1`).

All URI entrypoints and handlers have been hardened with strict parsing, anchored domain whitelists, scheme whitelisting, and bounds checking.

---

## 2. Deep-Link & Hostname Hardening (`SEC-ROUTE-001`)

### Exact Hostname Validation
In [lib/Helpers/route_handler.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/route_handler.dart), unanchored string search was replaced with RFC-compliant URI parsing and strict hostname validators:

1. **YouTube Domain Validator (`HandleRoute.isYouTubeHost`):**
   - Must match `youtube.com`, `*.youtube.com` (e.g. `www.youtube.com`, `m.youtube.com`, `music.youtube.com`), `youtu.be`, or `*.youtu.be`.
   - Rejects: `attacker-youtube.com`, `notyoutube.com`, `youtube.com.attacker.example`, `attacker.example/?redirect=youtube.com`.
2. **JioSaavn Domain Validator (`HandleRoute.isJioSaavnHost`):**
   - Must match `jiosaavn.com`, `*.jiosaavn.com` (e.g. `www.jiosaavn.com`), `saavn.com`, or `*.saavn.com`.
   - Rejects: `attacker-jiosaavn.com`, `fake-saavn.com`, `jiosaavn.com.attacker.example`.
3. **Spotify Domain Validator (`HandleRoute.isSpotifyHost`):**
   - Must match `spotify.com` or `*.spotify.com` (e.g. `open.spotify.com`).
   - Rejects: `attacker-spotify.com`, `spotify.com.attacker.example`.

### Scheme & Parameter Validation
In `HandleRoute.parseYouTubeUrl()`:
- Enforces scheme must be `http` or `https`.
- Rejects non-HTTP schemes and parses parameters (`v`, `list`, `/shorts/`, `/embed/`) with proper bounds checking.

---

## 3. Offline Song Index Protection (`SEC-ROUTE-002`)

In `OfflinePlayHandler`:
- When an offline song ID is shared or opened, `songs.indexWhere()` evaluates the song's location in local storage.
- If `index < 0` (the song is missing or stale), the handler immediately halts without calling `PlayerInvoke.init()`.
- A user-facing SnackBar (`Song not found on device storage`) is presented, and the navigation route is safely popped.
- This prevents the application from throwing `RangeError` or fabricating playback of song index `0`.

---

## 4. External URI Scheme Whitelisting (`SEC-LINK-001`)

In [lib/Helpers/app_links.dart](file:///d:/My-GitHub-Projects/BlackHole-maintenance/lib/Helpers/app_links.dart):
- `AppLinks.isSchemeAllowed(urlString)` restricts external launches to authorized protocols:
  - `https:` (secure web destinations)
  - `http:` (web links and streams)
  - `mailto:` (support email)
- Dangerous, custom, or exploitable schemes are strictly rejected:
  - `javascript:`
  - `file:`
  - `content:`
  - `data:`
  - `intent:`
  - `market:`
- If an unsupported scheme is detected, the operation aborts with a user notification and does not invoke the platform launcher.

---

## 5. Cleartext Networking Policy (`SEC-MAN-001`)

### Analysis of `android:usesCleartextTraffic="true"`
- All primary backend APIs (JioSaavn API, Spotify Web API, YouTube InnerTube API, GitHub update check, lyrics scrapers) strictly enforce `https://` at the Dart application layer.
- BlackHole supports user-configured internet radio stations via the Radio Browser directory. Many independent, community, and international shoutcast/icecast radio servers only broadcast over unencrypted HTTP (e.g. `http://stream.example.com:8000/live`).
- Setting a global `usesCleartextTraffic="false"` would immediately break radio playback for hundreds of legitimate HTTP stations across the world.
- Because radio endpoints are user-discoverable and dynamic, they cannot be pre-enumerated in a static `network_security_config.xml`.
- **Architectural Decision:** Retain `android:usesCleartextTraffic="true"` strictly to support legitimate internet radio streaming, while keeping all API and data endpoints enforced to TLS/HTTPS with full certificate verification.

