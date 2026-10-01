# Local handoff

Aura lives in this standalone project directory, outside any other project’s Git workspace. Start with `README.md`. The revised project is `ios/Aura.xcodeproj`; the original supplied iOS project remains unchanged.

The web companion runs at `http://localhost:4317` when `npm start` is active. It is a real backend-connected profile/wallet companion, not a substitute for physical BLE discovery. It intentionally starts without sample people. Test fixtures exist only in the test suite.

## What to review

1. `docs/CAPABILITIES.md`: implemented features and remaining validation.
2. `docs/ARCHITECTURE.md`: storage, identities, media, sessions, payments, and the no-custom-contract decision.
3. `docs/evidence/VERIFICATION.md`: completed checks and their limits.
4. `docs/PILOT.md`: physical-device checks and the measured small-room pilot.

## Next evidence priorities

- Sign/build for two actual iPhones; run wallet pairing, BLE discovery and consented UWB positioning.
- Fund a generated devnet test wallet and complete a real payment with a supported external wallet. The automated faucet attempt failed before funding.
- Validate media decoding/playback and exact positioning on supported physical devices.
- Install `artifacts/Aura-android-debug.apk` on a consenting test device. Verify pairing, lifecycle, media and discovery, then iOS↔Android BLE in both directions. The app builds; radio interoperability is not yet proven.
- Field-test the implemented native Android wallet flow on a compatible installed wallet, including cancellation, wrong-account selection, and signed-payment recovery. Gate Android UWB/AR work on measured hardware results.
- Obtain a pilot host and run the measured participant study.

The source repository is [AURA-RSE/AURA-Rse](https://github.com/AURA-RSE/AURA-Rse). No production deployment has been performed. No real user wallet or mainnet funds were used. The original prototype's simulated login/signature and placeholder API are not used in the revised app.
