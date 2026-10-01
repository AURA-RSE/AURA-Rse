# Aura — the room becomes the interface

Aura brings opt-in discovery and wallet-linked identity to Solana gatherings. Native iOS and Android apps connect nearby participants through a shared backend, web wallet companion, and JavaScript SDK.

**Status:** development pilot with compiled iOS and Android apps and automated API, browser, and Android checks. Physical cross-platform discovery, spatial accuracy, and live wallet compatibility still require validation. See [capabilities](docs/CAPABILITIES.md) for implementation status and remaining work.

Source repository: [AURA-RSE/AURA-Rse](https://github.com/AURA-RSE/AURA-Rse). Aura is maintained as a standalone project. The original supplied iOS project is preserved separately; the revised Xcode project is `ios/Aura.xcodeproj`. Local databases, credentials, toolchains, build caches and generated handoff bundles are excluded from Git.

## Builders around you

Discover opt-in participants as floating profile cards on iPhone and Android. Filter by intent, open a profile, save a connection or switch to a list. Cards show people resolved through nearby Bluetooth discovery in your event; the layout is not a geographic map. See [nearby profiles](docs/NEARBY.md).

## Run locally

Requirements: Node 22.13+ (tested on Node 25.9), npm, Xcode for iOS builds.

```sh
git clone https://github.com/AURA-RSE/AURA-Rse.git
cd AURA-Rse
npm ci
npm run build
npm start
```

Open http://localhost:4317. The UI starts empty: it contains no invented attendees or activity. Use a Solana Wallet Standard wallet supporting devnet, message signing, and transaction signing. A signed message authenticates ownership; Aura never receives wallet private keys.

1. Connect a wallet, save a profile, and join `AURA-LAB` or create your own event code.
2. Open `ios/Aura.xcodeproj` in Xcode. Select a device and configure signing for your team.
3. Start device pairing in the app. Approve its code in the authenticated web companion.
4. Select the event and a visible profile status, then explicitly start discovery.
5. A second participant does the same with a different wallet. Both apps remain in the foreground.
6. Save a discovered profile. Request positioning only with a consenting participant and supported devices.
7. A payment creates an intent. The wallet-enabled web companion reviews/signs it. The server submits the exact signed transfer and independently verifies the devnet receipt.

For a **physical iPhone or Android phone**, localhost points to the phone itself. On a trusted development LAN:

```sh
HOST=0.0.0.0 AURA_ORIGIN=http://YOUR-MAC-LAN-IP:4317 npm start
```

Use that exact origin in both the browser and phone. Debug builds permit local HTTP; **release builds require HTTPS**. Use devnet-only test accounts on a private LAN; do not expose this development server directly to the public internet. HTTPS deployment and production hardening are tracked prerequisites, not completed work. Android now offers native Solana Mobile Wallet Adapter sign-in and payment signing, with the web companion as fallback. iOS signing currently uses the web companion. Actual native-wallet compatibility remains a device acceptance gate.

## Verification

```sh
npm test                  # API/security/persistence/amount/position gating tests
npm run build             # web SDK bundle
npm run test:browser      # isolated Chrome integration test; generated wallets + mock RPC
npm run ios:build         # unsigned generic iPhone build
npm run android:build     # Android APK + lint (JDK/SDK required)
npm run android:test      # discovery rules + transaction integrity checks
npm run android:test:device # isolated Aura emulator + API fixtures; see android/README.md
```

Browser tests use an installed Google Chrome and port 4321. They never use personal browser data or submit real transactions. Code compilation and mocked RPC tests do not establish radio behavior or live wallet compatibility.

## Contents

- `android/` — native Java app, foreground BLE, Android Keystore session protection, profiles, events, connections and wallet-companion payments. See [Android setup](android/README.md).
- `ios/` — revised SwiftUI app, CoreBluetooth discovery, Nearby Interaction handshake, measured AR overlay, secure Keychain session storage.
- `server/` — authenticated API, durable SQLite storage, privacy enforcement, media storage, devnet payment submission and verification.
- `web/` — wallet verification, profile/media editor, event management, device approval, private connections, payment review, export/deletion.
- `packages/sdk/` — reusable JavaScript client and measurement-gating helper, with an integration example.
- `tests/` — automated regression and browser tests.
- `docs/` — architecture/storage decisions, protocol, threat model, pilot procedure, capabilities, and verification records.

## Storage and the smart-contract decision

Profiles, uploaded media, notes, sessions, events, and payment records persist in `data/aura.sqlite`. Presence and positioning tokens expire and are swept. Notes are owner-scoped. Media reads require access to the owner's profile. Database files are not committed or included in the source handoff.

**Aura has no custom Solana program in this version.** SOL transfers use the existing System Program. Storing public profiles, location history, or private notes on-chain would make deletion/privacy requirements harder and is not needed for these transfers. This is an explicit architecture choice, not omitted contract storage. See [storage design](docs/ARCHITECTURE.md).
