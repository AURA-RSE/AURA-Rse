# Aura capabilities

This matrix tracks the implementation and validation of Aura’s mobile apps and shared services. “Implemented” means source exists and the listed software checks pass. Hardware validation, deployment, audit, and adoption are tracked separately.

| Capability | Current implementation | Evidence / remaining acceptance gate |
|---|---|---|
| Wallet-linked identity | Ed25519 challenge signature, one-time nonce, origin-bound message, expiring hashed sessions | API tests and recorded physical Samsung/Solflare sign-in; broader wallet coverage remains |
| Persistent profiles | SQLite schema with bounded fields and HTTPS links | Restart persistence and local backup/restore tests; production recovery exercise pending |
| Profile editing and intents | iOS + Android + web editors; intent search in discovered mobile peers | Browser and emulator checks; manual physical profile/event interactions recorded during pilot troubleshooting; repeatable device matrix remains |
| Avatar storage | Authenticated PNG/JPEG upload, owner-scoped database BLOB, protected reads and deletion | API privacy/replace/delete checks; browser upload test |
| Intro video | MP4 upload (20 MB), web/Android clients check <=30 seconds; protected storage; iOS/Android playback views | No server-side duration/transcode pipeline; complete media validation remains pending |
| BLE discovery | Foreground iOS CoreBluetooth + Android GATT/scanner/advertiser; shared token UUIDs, bounded pending connections and timeouts | Manual iPhone 15 Pro ↔ Samsung SM-A055F discovery observed; see physical-discovery.json. Latency, repeatability and crowded-room reliability unmeasured |
| Ephemeral identity | Server random token, hashed lookup, 90-second expiry; rotates while foreground | API rotation/expiry tests; radio identifier tracking not eliminated |
| Open / Heads Down / Stealth | Persisted status; local stop; server revokes presence, grants, and ranging | API tests; existing downloaded data cannot be recalled; saved connections retain access unless blocked |
| Event-scoped access | Codes, memberships, event creation, explicit opt-in member directory scoped to shared events | API membership, directory opt-out, Stealth, block and media authorization tests; organizer moderation/invite quotas pending |
| iOS UWB positioning | Created-before-exchange NISession, authenticated relay, explicit acceptance per peer, up to three concurrent requests, capability checks, expiry | Signed build and relay tests; concurrent hardware feasibility, physical distance/direction, occlusion and orientation tests required |
| iOS AR identity | ARKit/NI shared session, measured world transform, stale clearing, projection/tracking gate | No BLE-derived invented position; physical registration accuracy unverified |
| Room camera | Android CameraX preview with nearby tray; iPhone ARKit camera with measured-only tappable markers and a separate positioning consent panel | Camera preview and position are separate. Android emulator checks and iOS signed build; real camera / marker validation pending. See [room camera](ROOM-CAMERA.md). |
| Multi-participant camera prototype | iPhone per-peer NI sessions and camera projection for up to three accepted devices; offscreen/stale/tracking-loss hiding | Software implemented and projection tests pass. Concurrent physical positioning remains unverified; Android and event-wide coverage are not implemented. |
| Floating nearby profiles | Native iOS and Android cards, protected avatars, name/role/project search, intent filters and list alternative; populated by authorized BLE resolution | Browsing layout, not measured coordinates; Android UI fixtures and physical-device evidence are tracked separately |
| Nearby fallback | List/search of resolved BLE peers independent of UWB | Manual nearby profile discovery observed with the Samsung; repeatable non-UWB device matrix remains |
| SOL payments | Devnet-only, exact decimal conversion, review, web Wallet Standard / Android MWA signing, validated signed submission, durable signature, RPC receipt verification | API + browser tests use mock RPC; real wallet/devnet round trip still required |
| SPL payments | Not implemented | Token allowlist, decimals, associated token accounts, native wallet support, and receipt verification required |
| Native wallet UX | Android MWA sign-in and signing-only devnet transaction flow; iOS uses the wallet-enabled web companion. Keychain/Keystore protect sessions | Physical Samsung/Solflare sign-in recorded; broader wallet testing, HTTPS identity verification and direct iOS wallet UX remain |
| Android | Native Java app: pairing, encrypted session, profiles/media, events, BLE, search/intents, connections/notes, block/report native wallet proof/payment review and encrypted signed-payment recovery | Debug APK builds; 14 discovery-rule + 416 transaction-integrity assertions pass. See latest verification record for emulator results. Physical sign-in and single-pair BLE observations recorded; broader compatibility and Android spatial implementation remain |
| Cross-platform discovery | Shared GATT UUIDs and token protocol implemented in both clients | Manual observation in both directions recorded; automated repeatability, timings and crowded-room results remain |
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
2. Capture a real-device video of opt-in, cross-platform discovery, saving and hiding; record positioning separately with two compatible iPhones.
3. Run a 15–30-person pilot with device/OS matrix, failure counts, timing, battery observations, and user feedback.
4. Measure spatial accuracy on supported hardware and establish the limits of multi-person positioning.
5. Arrange a consenting pilot host and evaluate an external SDK integration attempt.

Build and automated-test results establish software behavior under the recorded conditions. Single-pair manual discovery observations are evidence of an initial physical result, not a broad compatibility guarantee. Further measurements are required to establish repeatability and crowded-room reliability.
