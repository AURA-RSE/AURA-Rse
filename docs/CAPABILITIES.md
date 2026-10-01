# Aura capabilities

This matrix tracks the implementation and validation of Aura’s mobile apps and shared services. “Implemented” means source exists and the listed software checks pass. Hardware validation, deployment, audit, and adoption are tracked separately.

| Capability | Current implementation | Evidence / remaining acceptance gate |
|---|---|---|
| Wallet-linked identity | Ed25519 challenge signature, one-time nonce, origin-bound message, expiring hashed sessions | API tests; external wallet/device testing still required |
| Persistent profiles | SQLite schema with bounded fields and HTTPS links | Restart persistence and local backup/restore tests; production recovery exercise pending |
| Profile editing and intents | iOS + Android + web editors; intent search in discovered mobile peers | App compiles; browser edit test; real mobile UI exercise pending |
| Avatar storage | Authenticated PNG/JPEG upload, owner-scoped database BLOB, protected reads and deletion | API privacy/replace/delete checks; browser upload test |
| Intro video | MP4 upload (20 MB), web/Android clients check <=30 seconds; protected storage; iOS/Android playback views | No server-side duration/transcode pipeline; complete media validation remains pending |
| BLE discovery | Foreground iOS CoreBluetooth + Android GATT/scanner/advertiser; shared token UUIDs, bounded pending connections and timeouts | Compiled; two-physical-device test required |
| Ephemeral identity | Server random token, hashed lookup, 90-second expiry; rotates while foreground | API rotation/expiry tests; radio identifier tracking not eliminated |
| Open / Heads Down / Stealth | Persisted status; local stop; server revokes presence, grants, and ranging | API tests; existing downloaded data cannot be recalled; saved connections retain access unless blocked |
| Event-scoped access | Codes, memberships, event creation, no global directory endpoint | API membership isolation tests; organizer moderation/invite quotas pending |
| iOS UWB positioning | Created-before-exchange NISession, authenticated relay, explicit acceptance, one active peer, expiry | Compiled only; physical distance/direction, occlusion and orientation tests required |
| iOS AR identity | ARKit/NI shared session, measured world transform, stale clearing, projection/tracking gate | No BLE-derived invented position; physical registration accuracy unverified |
| Multi-person room overlays | Not yet implemented | Current UWB pilot is one accepted peer at a time; multi-session feasibility study required |
| Nearby fallback | List/search of resolved BLE peers independent of UWB | Compiled; non-UWB device testing required |
| SOL payments | Devnet-only, exact decimal conversion, review, web Wallet Standard / Android MWA signing, validated signed submission, durable signature, RPC receipt verification | API + browser tests use mock RPC; real wallet/devnet round trip still required |
| SPL payments | Not implemented | Token allowlist, decimals, associated token accounts, native wallet support, and receipt verification required |
| Native wallet UX | Android MWA sign-in and signing-only devnet transaction flow; iOS uses the wallet-enabled web companion. Keychain/Keystore protect sessions | Android compiles; actual compatible-wallet testing, HTTPS identity verification and iOS native wallet UX remain |
| Android | Native Java app: pairing, encrypted session, profiles/media, events, BLE, search/intents, connections/notes, block/report native wallet proof/payment review and encrypted signed-payment recovery | Debug APK builds; 14 discovery-rule + 416 transaction-integrity assertions pass. See latest verification record for emulator results. Actual-wallet/BLE/UWB/ARCore validation remains |
| Cross-platform discovery | Shared GATT UUIDs and token protocol implemented in both clients | Must demonstrate iOS↔Android in both directions |
| Cross-platform UWB | Research gate only | Never infer interoperability from both phones advertising UWB |
| Saved connections | Durable owner-scoped records, private notes, web removal | Privacy tests; iOS/Android reads/writes implemented |
| Blocking and reporting | Bilateral access denial, ranging revocation, reports retained for 90 days independently of target deletion | API expiry/deletion/isolation tests and v1/v2 migration checks; no automated abuse detection or staffed moderation |
| Account export/deletion | JSON export incl. own uploaded media; account-owned data deletion; bounded safety-report exception | Tests cover reporter unlinking and other senders’ retained payment history; chain data remains public; backup erasure lifecycle pending |
| Solana names / credentials / NFT context | Not implemented | Verified provenance + consent + display design needed; no self-entered credential portrayed as verified |
| SDK | Reusable transport client, tests, example, protocol documentation | Local package only; Swift/Kotlin packaging and independent integration trials pending |
| Event analytics | No production telemetry system | Pilot observation template available; consented aggregate instrumentation still required |
| Source availability / licensing | Source available at AURA-RSE/AURA-Rse | Public source availability does not itself grant an open-source license; license/ownership review and SDK release remain pending |
| Independent audit | Not performed | Independent security and privacy review pending |
| Production hosting | Not deployed | HTTPS, secrets/config, backups, monitoring, rate limits, restore tests, abuse handling required |

## Validation priorities

1. Reproduce the iPhone and Android builds, API/browser tests, and a real wallet devnet payment.
2. Capture a truthful two-device video: opt in, discover, save, hide, approve positioning, lose tracking gracefully.
3. Run a 15–30-person pilot with device/OS matrix, failure counts, timing, battery observations, and user feedback.
4. Measure spatial accuracy on supported hardware and establish the limits of multi-person positioning.
5. Arrange a consenting pilot host and evaluate an external SDK integration attempt.

Build and automated-test results establish software behavior under the recorded conditions. Physical-device measurements are required to establish crowded-room reliability and iPhone↔Android interoperability.
