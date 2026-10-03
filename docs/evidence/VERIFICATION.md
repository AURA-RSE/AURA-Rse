# Verification record

## 2026-10-03 — separate event search and iPhone branding

- Added an explicit opt-in event directory on iPhone and Android. Existing nearby Floating/List search and camera remain separate. Web and native profile editors expose the same visibility control; old profiles remain unlisted by default.
- All 32 backend tests pass. New checks cover membership isolation, default privacy, invalid consent values, opt-out, Stealth, event leaving, bilateral blocks, media access revocation, and durable saved connections.
- All five Android emulator instrumentation tests pass. The new test opens and filters event search without starting BLE or camera, then verifies that withdrawing consent removes the result. Existing camera-preview, nearby filtering, save-note and profile-draft regressions also pass. These use synthetic identities and do not prove physical camera positioning.
- Android build/lint passed (0 errors, 26 warnings); web companion browser checks passed with fixture wallets/RPC. Unsigned and signed iOS builds passed. App icon PNGs and Assets.car are present in the iOS product. The signed update has not been installed on the currently disconnected physical iPhone.
- Replaced the empty iOS app-icon asset with an opaque 1024px version of Aura's existing ring mark. Added the same mark to onboarding, Discover and room-camera branding.
- The user's camera feedback is an unresolved spatial capability gap: Android has no measured placement, and the Apple path supports only one accepted compatible peer and still needs physical validation. New copy identifies an unpositioned nearby list explicitly. No multi-person camera success is claimed.

## 2026-10-02 — live room camera

- Added local-only room-camera preview on Android and iPhone, authorized nearby-profile trays, profile opening, discovery controls, and permission handling. No recording, microphone capture, face matching, or image upload was added.
- Android build and lint pass with no errors. Lint includes dependency upgrade notices, the existing debug HTTP configuration, and untranslated UI strings. Four emulator instrumentation tests cover a streaming CameraX preview, profile opening from the camera tray, and clearing cards on pause, alongside the prior save/profile checks. `android-room-camera-fixtures.png` is an emulated camera scene with synthetic profile fixtures.
- The signed iPhone camera build succeeded and was installed on the connected test phone. The measured-marker renderer updates per display frame, reuses its entity, hides invalid/out-of-view measurements, and supports taps. Camera and physical marker behavior still require user validation.
- Nearby trays do not represent physical positions. Multi-person spatial overlays remain unimplemented. See `../ROOM-CAMERA.md` for the implementation boundary and device checks.

## 2026-10-02 — profile drafts and saved connections

- Android list refreshes no longer rebuild the My Aura form and discard unsaved text or Presence selections. Discover now links directly to saved connections in People. Reopening a saved profile from Discover retains its private note and saved state.
- All 30 backend tests passed, including saved-note access after discovery access expires and the participant switches to Stealth.
- All four Android instrumentation tests passed. The regression checks refresh the profile form while editing Presence, save and verify Stealth through the API, and confirm a saved note remains visible after discovery stops and the activity is recreated. Reopening the discovered profile preserves the saved note.
- Android build and lint passed. The physical-device Stealth observation remains unresolved pending a retest; these automated checks do not establish that physical outcome.

## 2026-10-02 — Android saved-connection feedback

- Saving a connection now shows progress, success and errors inside the open profile panel. A failed save retains the note; an in-flight save disables duplicate submissions.
- Four isolated Android emulator instrumentation tests passed, including persisting a note through the real fixture API and retaining an edited note after a rejected update. The test fixture was corrected to avoid blocking the same participant twice.
- Android debug build and lint passed (no errors; five existing warnings). Physical installation of this feedback update remains separate from these checks.

## 2026-10-02 — physical Android sign-in and event-join feedback

- **Physical Samsung SM-A055F, Android 15:** the user approved Aura's native Solflare sign-in and reached the profile screen. The isolated backend verified a created profile and active authenticated session. App/wallet versions and the tested APK checksum are recorded in `physical-wallet-signin.json`. This is manual device evidence, not an independently witnessed audit or a payment receipt.
- Subsequent backend inspection confirmed a saved profile and event membership. Repeated USB connection interruptions affected local server access; a shared Wi-Fi connection is being prepared. No physical peer discovery, spatial measurement or confirmed payment is established by this run.
- Fixed Android event joining: successful joining selects the event and opens Discover with confirmation; errors remain beside the event code; unsaved profile changes require saving before navigation; changing events clears previous discovery.
- **Four Android emulator instrumentation tests passed**, including blank/invalid event code handling, unsaved-edit preservation, joining through the real isolated API, selected-event feedback, and profile persistence. Native app build passed; lint retains five existing warnings and no errors. Emulator evidence remains separate from the physical sign-in result.

## 2026-10-01 — floating nearby profiles

- Added native iPhone and Android floating cards for profiles resolved through the existing opt-in, same-event BLE flow. Cards include protected avatars or initials, project/role, interest and availability; search, intent filters and list mode share the same authorized peers. Layout does not represent physical coordinates.
- **Unsigned iPhone build passed. Android debug APK build passed.** Android lint: **0 errors, 5 existing warnings** (four dependency updates and debug HTTP).
- **All four Android emulator instrumentation tests passed.** The new test uses generated API accounts and injected BLE observations, then exercises filtering, view switching, card-to-profile navigation, server-side blocking, expiry and pause clearing. The other tests cover encrypted session storage, missing-wallet fallback and profile edits/recreation. See `android-device-tests.txt`.
- **30 API/core/store tests passed** again, preserving event isolation, presence revocation, blocking, report retention and payment checks.
- `android-nearby-test-fixtures.png` is a labelled emulator screenshot of synthetic profiles. It is visual/UI evidence, not live participants or physical Bluetooth proof.
- iPhone runtime interaction, physical iPhone↔Android discovery, actual wallet signing and two-iPhone spatial positioning remain pending. No GPS collection, face matching, public directory or multi-person AR positioning was added.

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
