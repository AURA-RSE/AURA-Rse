# Real-device validation checklist

Status: pending physical execution. Automated test fixtures and emulator checks are separate evidence.

## Hardware gates

| Check | Requirement | Present constraint |
|---|---|---|
| iOS app, discovery and web-companion signing | Signed install on an iPhone running iOS 17+ | iPhone 15 Pro identified for testing; installed build and OS not yet verified |
| Android app and BLE | Android 12+ (API 31), BLE scanning and advertising | Galaxy A30 reported as Android 15; confirm model/API level on connection and test BLE advertising |
| Native Android wallet | Installable Aura app plus a wallet supporting the required MWA signing methods on devnet | No wallet currently installed; install a test wallet before the native-wallet run |
| iOS spatial positioning | Two compatible physical iPhones; runtime Nearby Interaction and camera-assistance capability checks | A second compatible iPhone is still required |

Samsung's [A30 SM-A305G update record](https://doc.samsungmobile.com/SM-A305G/006095190514/eng.html) lists Android 11. An A30 on Android 11 cannot install the current API-31-minimum APK. Check Settings → About phone → Software information; do not assume all regional variants or installed systems are identical. An Android 11 compatibility change needs the legacy BLE permission/location flow, API guards, dependency checks and device validation; lowering the manifest minimum alone is insufficient.

Apple requires runtime [Nearby Interaction capability checks](https://developer.apple.com/documentation/nearbyinteraction/initiating-and-maintaining-a-session). Owning a UWB-capable iPhone does not validate Aura's positioning behavior. Android spatial positioning is not implemented in this build.

For a first wallet trial, [Solana Mobile lists Solflare as MWA-compatible](https://wallets.solanamobile.com/). Install from its official linked store page, create a separate test wallet, and select Devnet using [Solflare’s network settings](https://help.solflare.com/en/articles/6328814-differences-between-mainnet-devnet-and-testnet-and-how-to-switch-between-on-solflare). Keep recovery phrases private. Aura's required signing methods must still be tested against the installed version; listing MWA support does not prove this app's flow.

To connect Android for installation, enable Developer options by tapping Build number seven times in Settings → About phone → Software information, then enable USB debugging. Connect by USB and approve this Mac's debugging prompt. Confirm the model and API level with `adb shell getprop ro.product.model` and `adb shell getprop ro.build.version.sdk` before installing the APK. Record the actual output privately. For iPhone, connect and trust the Mac, enable Developer Mode if requested, and select the phone and a signing team in Xcode.

## Record each run

Copy `device-runs.csv` into a private evidence directory. Record the exact commit, build checksum, date, OS, device model, wallet/version, scenario, attempts, successes, timing and failures. Leave unexecuted checks marked pending. Keep participant identities, consent records, full device identifiers and incident reports out of public evidence.

Use distinct test wallets and devnet only. Connect phones and the development Mac to a trusted LAN; configure the same explicit server origin on all clients. Device localhost does not address the Mac. Follow the root README for server startup, `android/README.md` for APK setup, and Xcode signing for `ios/Aura.xcodeproj`.

## Execution order

1. **Install and authenticate.** Record build/OS; sign a real wallet challenge, pair devices, edit a profile, restart each app and confirm session recovery. Capture permission denial and recovery. Record iOS web-companion signing separately from Android MWA.
2. **Discover in both directions.** Join the same event, start Open discovery on both devices. Verify each displayed wallet against the other device. Perform ten stop/start trials per direction; retain failure counts and timeouts, not just successful timings. Repeat with different events, Stealth, a block, Bluetooth toggles and foreground/background transitions. No unauthorized profile should resolve.
3. **Save and revoke.** Save a connection and private note; verify note isolation. Test media access from an unrelated account. Check expiry, hiding, blocking and deletion against the documented access model.
4. **Native Android wallet.** On a compatible Android build, exercise MWA approval, cancellation and account mismatch using the installed wallet. Review recipient and amount, sign a small devnet transfer, and record the confirmed signature/slot and a devnet explorer link. Exercise interrupted submission by checking the original signature; never request a replacement signature while the outcome is uncertain. A generated-key RPC script is not evidence of external-wallet compatibility.
5. **Positioning with two iPhones.** Check support at runtime, require explicit peer consent and test one peer at a time. Record tape-measured distances at 1/2/3 metres, displayed distance, marker placement, direction/orientation, body occlusion, pocket/bag behavior, walking out of range and reacquisition. Count missing/incorrect markers and confirm stale transforms clear; never infer multi-person capability from this test.
6. **Record one continuous demonstration.** Show build and device models, real wallet authentication, both discovery directions, save/private note, hiding/blocking and a confirmed devnet payment. Record iPhone-to-iPhone positioning separately if a second iPhone is available. Label unavailable features and failures explicitly; protect secrets and participant data.
7. **Arrange a host, then a small pilot.** Obtain actual host consent and define an incident contact, participant consent, device mix and exit criteria. Use `PILOT.md` for a 15–30-person study only after the two-device checks. No host partnership or participant results are currently claimed.

A critical privacy failure, wrong recipient/amount, duplicate payment, or misleading stale position stops that scenario until diagnosed. Report measured reliability without inventing target achievements. Discovery latency, battery cost and crowd accuracy remain unknown until runs are completed.
