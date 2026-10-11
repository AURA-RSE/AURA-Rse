# Local handoff

Aura lives in this standalone project directory, outside any other project’s Git workspace. Start with `docs/SUBMISSION.md` and `README.md`. Deployment instructions are in `docs/DEPLOYMENT.md`. The revised project is `ios/Aura.xcodeproj`; the original supplied iOS project remains unchanged.

The web companion runs at `http://localhost:4317` when `npm start` is active. It is a real backend-connected profile/wallet companion, not a substitute for physical BLE discovery. It intentionally starts without sample people. Test fixtures exist only in the test suite.

## What to review

1. `docs/CAPABILITIES.md`: implemented features and remaining validation.
2. `docs/ARCHITECTURE.md`: storage, identities, media, sessions, payments, and the no-custom-contract decision.
3. `docs/evidence/VERIFICATION.md`: completed checks and their limits.
4. `docs/DEVICE-VALIDATION.md`: hardware prerequisites, recording steps and pending device checks.
5. `docs/PILOT.md`: physical-device checks and the measured small-room pilot.
6. `docs/REPORT-RETENTION.md`: safety-report lifetime, deletion exceptions and operator responsibilities.

## Next evidence priorities

- Submission build 3 is signed. Install it on two compatible iPhones to validate measured positioning; build 2 was previously installed on the available iPhone.
- Complete an Aura payment with a supported external wallet using devnet test SOL. The automated faucet attempt failed before funding.
- Validate media decoding/playback and exact positioning on supported physical devices.
- Install `artifacts/Aura-android-debug.apk` on a consenting test device. Verify pairing, lifecycle, media and discovery, then iOS↔Android BLE in both directions. An initial manual single-pair result is recorded; repeated runs and timing measurements remain.
- Field-test the implemented native Android wallet flow on a compatible installed wallet, including cancellation, wrong-account selection, and signed-payment recovery. Gate Android UWB/AR work on measured hardware results.
- Obtain a pilot host and run the measured participant study.

The source repository is [AURA-RSE/AURA-Rse](https://github.com/AURA-RSE/AURA-Rse). No production deployment has been performed. Physical sign-in used the user-operated Solflare wallet. Aura stores no wallet private keys. No mainnet transfer is claimed. The original prototype's simulated login/signature and placeholder API are not used in the revised app.
