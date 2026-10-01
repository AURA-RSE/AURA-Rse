# Verification record

## 2026-10-01 — bounded safety-report retention and deletion semantics

- **30 API/core/store tests passed.** New checks cover target deletion, reporter unlinking, re-registration isolation, export isolation, exact 90-day expiry, startup cleanup, schema v1/v2 migration, future-schema rejection and retained recipient wallets in other senders' payment history. See `api-tests.txt`.
- Schema v3 preserves safety reports until their original expiry even after target deletion. Reporter deletion clears the account link. Active rows expire at creation + 90 days, with startup and 30-second cleanup; exports enforce expiry independently of the sweep. SQLite/WAL remnants and backup erasure remain outside this guarantee.
- Web build and isolated Chrome integration **passed**; generated wallets and mocked RPC remain test fixtures. Updated privacy notices and workspace screenshot included. See `browser-tests.txt`.
- Unsigned generic iPhone build **passed** after the reporting notice update. Existing derived-data paths emitted stale-file warnings; no physical install, signing or radio validation was performed.
- Android debug APK build **passed**. Lint remains **0 errors, 5 warnings** (four dependency upgrades and debug-only cleartext transport). See `android-build.txt` and `android-lint.txt`.
- The existing Android emulator/transaction-integrity results below are earlier runs, not new device evidence from this change.
- Physical BLE, actual MWA signing/devnet receipt and two-iPhone positioning remain pending. No Android device was connected at the USB check; the Apple device query returned a CoreDevice provider error, so iPhone connection status was not established.
- Added a real-device checklist, blank measurement CSV and operator retention procedure. These are plans and procedures, not completed field results.

## 2026-10-01 — Aura v0.3 native Android wallet groundwork

- **24 API/core tests passed.** Native payment preparation fixes the sender, recipient, amount and reference; tests check expiry/block changes during RPC, invalid upstream data, signed submission and recovery.
- **416 transaction-integrity assertions passed** against an unfunded generated web3.js fixture, plus **14 discovery-rule assertions**. These are local checks, not device runs or live users.
- **3 Android emulator instrumentation tests passed** on the dedicated Android 15 / API 35 ARM64 AVD: missing-wallet fallback, Android Keystore encrypted session scoping/clear, and profile edits + activity recreation using an isolated real API backend with generated test credentials. Live RPC was disabled. See `android-device-tests.txt` and `android-emulator-onboarding.png`.
- Android debug app and instrumentation APKs **build successfully**. Debug APK signature verifies. Lint: **0 errors, 5 advisories** (four dependency upgrades and debug-only cleartext transport). Official MWA 2.0.8 is pinned for SDK 35; version 2.2.0 requires SDK 37. Signing-only MWA is optional/deprecated; installed-wallet support and a future migration need explicit testing.
- Native code now includes MWA sign-in, reviewed payment signing, independent transaction-content checks, and Keystore-encrypted signed-byte recovery before submission. **No actual installed-wallet or live devnet success is claimed by emulator tests.**
- Original Downloads source/project: **all 18 hashes unchanged**. The revised Aura app is maintained separately from the original supplied project.
- Still pending: physical BLE/iOS↔Android evidence, measured UWB/AR accuracy, actual wallet/receipt proof, media hardening, external security review, host/participant evidence and public SDK release.

The text logs under this directory contain the latest run for each check. Earlier entries below describe their historical state; current counts and warnings are above.

## 2026-09-30 — standalone Aura and Android baseline

- Aura was moved into its own standalone project directory.
- API/core suite: **21 passed, 0 failed**. Added a regression proving cleanup preserves unresolved submitted signatures while deleting abandoned unsigned intents. See `api-tests.txt`.
- Android debug APK: **BUILD SUCCESSFUL**, Android Gradle Plugin 8.9.2, Gradle 8.11.1, Java 21 host toolchain / Java 17 source, SDK 35; minimum Android 12.
- Android lint: **no issues found**. Token/freshness/GATT-boundary checks: **14 assertions passed**. See `android-build.txt`, `android-lint.txt`, and `android-rules.txt`.
- Native Android source includes pairing, encrypted sessions, profiles/media, events, foreground BLE, intent filtering, saved connections/notes, block/report, payment intent creation and companion handoff. Presence writes are serialized across stop/restart; no Android UWB/AR or native MWA integration is claimed.
- Browser integration: **passed again** after updating the companion for both mobile platforms. See `browser-tests.txt`. Screenshots regenerated with isolated test wallets and mocked RPC.
- Original Downloads Aura project: all **18 source/project hashes unchanged**.
- **Not verified:** Android emulator/device execution, iOS↔Android radio interoperability, physical UWB/AR accuracy, actual external-wallet round trip, live devnet payment, or event pilot results. No production release occurred.

## 2026-09-28 — initial iOS and shared backend checks

- API/core regression suite: **20 passed, 0 failed**. Includes wallet proof/replay, expiries, access isolation, Stealth, blocks, private notes, pairing, consented ranging relay, amount/receipt validation, signed submission recovery, media authorization, restart persistence, and a SQLite backup restoration.
- Browser integration: **passed** in isolated Google Chrome. Desktop and 390px mobile layout checked; wallet challenge, profile update, event join, saved connection, reviewed signed transaction, receipt verification, avatar upload, and absence of JavaScript page errors checked.
- Browser wallets and RPC were **explicit test fixtures**. Test participants and the successful browser transaction are not live adoption or mainnet/devnet execution evidence.
- iPhone build: **BUILD SUCCEEDED**, iOS 17 minimum deployment target, iOS 26.4 SDK, unsigned generic device build.
- Simulator build: **BUILD SUCCEEDED**, separate `com.Waliu.Aura.LocalPilot` identifier. Runtime smoke test could not complete: the simulator remained on its iOS boot screen, so pending install/launch attempts were stopped. Build success does not establish BLE/UWB/camera performance.
- Live devnet smoke attempt: **not completed**. Faucet returned an internal error before funding the generated test wallet. No live transfer was submitted by this attempt. See `devnet-smoke.json`.
- Original project preservation: all 18 inventoried source/project file hashes match the supplied Downloads project. Its existing uncommitted state was preserved.
- No public release or deployment was performed during these checks.

Screenshots `web-workspace-test-fixtures.png` show generated test users. `web-desktop.png` and `web-mobile.png` show the empty landing experience. Real-device radio validation, external wallet compatibility, crowded-room positioning, Android device validation, and external SDK trials remain required.
