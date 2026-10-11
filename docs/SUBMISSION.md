# Aura: reviewer brief

Aura turns Solana event attendance into opt-in, wallet-linked connections. The prototype combines native iPhone and Android apps, nearby discovery, searchable event profiles, saved connections with private notes, and a reviewed devnet payment path.

## Inspect the experience

| Experience | Current scope | Evidence |
|---|---|---|
| Wallet-linked identity | Signed challenges; Android MWA; iPhone wallet-companion pairing | [Physical Android sign-in](evidence/physical-wallet-signin.json), API and browser checks |
| Nearby people | Foreground Bluetooth discovery across iPhone and Android | [Manual single-pair observation](evidence/physical-discovery.json); repeatability remains to be measured |
| Event search | Separate, explicit opt-in directory, gated by shared event membership | API privacy tests and Android UI fixtures |
| Connections | Durable saved profiles and owner-private notes | API persistence and Android save/reopen checks |
| Room camera | Measured-only markers with per-peer consent on compatible iPhones | Signed build, relay tests and synthetic projection assertions; physical positioning not yet validated |
| Payments | Devnet SOL, external signing, content validation, durable submission signature and receipt checking | Automated fixture checks; actual wallet-approved devnet receipt remains outstanding |

Android camera preview does not measure participant positions. An Android attendee can appear in nearby search without appearing as a positioned iPhone camera marker. Profile names and project details are self-authored; wallet verification does not verify a person's real-world identity.

## Reproduce

Follow [README](../README.md) for installation and local server setup. Use distinct test wallets and the same server origin on both phones. Join `AURA-LAB`, select Open, and explicitly start discovery. Local pilots require a running Mac and shared Wi-Fi. This submission does not claim a deployed public HTTPS service.

Run `npm run check`, `npm run test:browser`, `npm run test:spatial`, `npm run android:test`, and the native build commands in README. Android UI tests use the isolated Aura emulator and generated fixture accounts. Exact checks and dates are in [VERIFICATION](evidence/VERIFICATION.md).

## Three-minute demonstration script

1. Show the device models, app build numbers and shared event. Use two distinct participant wallets. Do not display recovery phrases or pairing secrets.
2. Sign in, open the profile, choose Open and start discovery. Show the actual nearby profile on each phone.
3. Save a connection and note. Pause discovery, open saved connections, restart the app and verify the saved record remains.
4. Show explicit directory opt-in separately from nearby discovery. Clear search filters before comparing results.
5. Demonstrate Stealth/blocking and record the observed result. Do not infer visibility from server presence alone.
6. For a separate camera recording, use two compatible iPhones, request and accept positioning, then move/turn and show the measured marker. Omit a claimed successful camera demonstration until this works on physical hardware.
7. For a separate payment recording, use only devnet SOL, review the recipient and amount in the wallet, and verify the confirmed transaction in Explorer. A faucet failure or mock receipt is not this result.

## Funded expansion

Device qualification and wallet completion lead into a secure dual-platform beta, measured event deployments, and reusable SDK/protocol releases. Broader wallet support, Android spatial feasibility, media hardening, deployment operations, independent review and adoption measurements remain release deliverables. See [capabilities](CAPABILITIES.md), [architecture](ARCHITECTURE.md), [camera scope](ROOM-CAMERA.md) and [pilot protocol](PILOT.md).

Repository: https://github.com/AURA-RSE/AURA-Rse
