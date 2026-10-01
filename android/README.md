# Aura Android pilot

Native Java app for Android 12+ (API 31), targeting API 35. This is a locally compiled development baseline, not a tested production release. See `docs/evidence/VERIFICATION.md` for the latest emulator results. No physical-device radio or actual-wallet proof is claimed.

## Build

Install JDK 17+ and Android SDK platform/build-tools 35. Set `JAVA_HOME` and `ANDROID_HOME`, then from the Aura root:

```sh
npm run android:build
npm run android:test
```

For this Mac, an isolated Apple Silicon toolchain is already under `.toolchains/`. `python3 scripts/setup-android-tools.py` can install it on another Apple Silicon Mac; it downloads verified archives and accepts Android SDK licenses. Standard Android Studio installations can use `android/gradlew` directly with their local SDK configuration. The Gradle 8.11.1 wrapper includes distribution checksum verification.

Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`; handoff copy: `artifacts/Aura-android-debug.apk`. Install on a connected consenting test device with `adb install -r artifacts/Aura-android-debug.apk`. Release signing and store distribution are not configured.

## Connect a phone

1. Run the Aura server on a trusted LAN with `HOST=0.0.0.0 AURA_ORIGIN=http://YOUR-MAC-LAN-IP:4317 npm start`.
2. Use that same origin in the app and wallet-enabled browser. Physical phones cannot reach the Mac through their own localhost. Android emulator host alias is `10.0.2.2`; configure the server origin to match when using it in the emulator browser.
3. Generate a pairing code in Android. Verify your wallet in the companion and approve the code under **Connect your phone**. Return to Aura.
4. Save a profile, choose Open or Heads down, join an event, and explicitly start discovery. Grant Nearby Devices permission when requested. Keep the app open.
5. Backgrounding stops advertising/scanning and requests token revocation. Restart discovery explicitly after returning. If offline, presence expires within 90 seconds.

Wallet keys remain in the external wallet. Session tokens are encrypted with an Android Keystore AES-GCM key. Backup and device transfer exclude app data. Debug allows local HTTP. Release API origins require HTTPS; the only transport cleartext exception is device loopback for MWA’s encrypted local protocol.

## Floating nearby profiles

Discover opens with floating cards for authorized peers observed in your event. Search and intent filters work in both Floating and List modes. Tap a card for profile actions. The card arrangement is for browsing and does not show geographic positions. Discovery pause, stale observations and denied resolution remove cards. See [nearby behavior](../docs/NEARBY.md).

## Implemented baseline

Pairing; profile/status/intents; authenticated avatar and intro uploads; event joining; foreground BLE peripheral and central roles; fresh-token profile resolution; name/role/project and intent search; saved connections and private notes; blocking/reporting; devnet payment intents, external wallet review and receipt links. Account export/deletion and block management open the companion. Native Mobile Wallet Adapter sign-in and signing-only devnet payments are implemented; installed-wallet compatibility, Android UWB and ARCore still require validation/implementation.

Presence create/renew/delete calls are serialized; callbacks from superseded discovery runs are ignored. Token freshness uses a 15-second local observation window. BLE RSSI never creates a direction or AR position.

## Required device acceptance

| Case | Acceptance evidence still needed |
|---|---|
| Pairing and session | Wallet approval, restart restores session; logout and expired session clear access |
| Permissions / Bluetooth | Deny, grant, revoke, toggle radio; no crash or hidden broadcasting |
| Lifecycle | Background, rotation, rapid start/stop, network delay; old response cannot re-enable discovery |
| Discovery | Android↔Android and iOS↔Android in both directions; rotate tokens, hide/block, lose proximity |
| Media / connections | Upload, read, play, save note, block, report; inaccessible media stays inaccessible |
| Payments | Full recipient/amount review in actual wallet; devnet receipt and uncertain-confirmation recovery |
| Device matrix | At least one current Samsung and Pixel; include an Android device without UWB |

Shared UUIDs establish protocol intent, not demonstrated interoperability. The iOS Nearby Interaction archive format is Apple-specific and is not used as an Android UWB protocol.

## Native wallet flow and boundaries

Select **Connect Android wallet** to launch an installed MWA wallet and sign the server's exact challenge. Server verification, not an authorization result alone, creates the session. A payment displays full addresses and exact SOL amount; Android checks the prepared transaction, requires the already verified wallet, checks the returned message is unchanged, and saves signed bytes encrypted before submission. **Activity → Recover signed payment** checks/retries the existing signature without requesting another signature. Failed or expired unresolved transactions may require manual review; do not create a replacement blindly.

The official client dependency is pinned to **2.0.8** for compile SDK 35 compatibility; 2.2.0 requires SDK 37. Signing-only `signTransactions` is optional/deprecated in the adapter but preserves Aura's validation-before-submission design. Wallets lacking it must use the browser fallback; universal wallet support is not claimed. A production HTTPS identity must be controlled by the applicant and configured for the wallet's identity verification, including Android Digital Asset Links where required. This has not been deployed.

### Emulator runtime tests

Build app and instrumentation APKs with `bash scripts/build-android.sh :app:assembleDebug :app:assembleDebugAndroidTest`. Use the dedicated AVD `Aura_Pilot_API35` on port 5580, then `npm run android:test:device`. The runner refuses unrelated AVDs and physical devices, creates an in-memory backend on port 4322, generates a test account, disables live RPC, and exercises Keystore scoping/clear, missing-wallet fallback, profile editing/restoration, and floating-card filtering/navigation/blocking/expiry/pause using injected BLE observations resolved through the real API. Injecting a generated session is a test fixture; it is not actual-wallet sign-in evidence. No emulator BLE/UWB result should be presented as physical radio proof.

### Official references

- [Solana Mobile wallet quickstart](https://docs.solanamobile.com/get-started/kotlin/quickstart)
- [MWA protocol and optional signing methods](https://github.com/solana-mobile/mobile-wallet-adapter/blob/main/spec/spec.md)
- [Official adapter source](https://github.com/solana-mobile/mobile-wallet-adapter/tree/main/android/clientlib)
