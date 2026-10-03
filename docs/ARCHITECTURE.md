# Architecture and storage decisions

## Components

```
iPhone CoreBluetooth / Android BLE → short-lived presence token → authenticated Aura API
                                                 ↓
Wallet-enabled browser ↔ signature challenges → SQLite profiles/events/media
       ↓                                         ↓
review + sign transfer → validate + persist signature → Solana devnet RPC

Consenting iPhone peers ↔ authenticated token relay ↔ Nearby Interaction
                                                    ↓
                                         measured ARKit world transform
```

The API is intentionally small and runs on one Node process for a development pilot. SQLite WAL is the durable source of truth. A production multi-instance deployment needs managed persistence or a coordinated single-writer design and distributed rate limiting.

## Data ownership and lifetime

| Data | Location | Access | Lifetime |
|---|---|---|---|
| Signing keys | User's external wallet | Wallet only | Wallet-controlled; never collected by Aura |
| API bearer session | iOS Keychain / Android Keystore-encrypted preferences / browser memory; hash in server DB | Account owner | Seven days; individual logout or account deletion |
| Wallet challenge | SQLite | Public initiation; signature required | Five minutes, single-use |
| Profile | SQLite JSON | Owner, current authorized discoverer, saved connection, or shared-event member while directory opt-in is on and status is visible; blocks override | Until deleted |
| Uploaded avatar/video | SQLite BLOB | Same profile authorization | Replaced by owner or deleted with account |
| Event/member records | SQLite | Authenticated memberships and owner operations | Until account/event lifecycle removes them |
| Presence token | Phone memory; hash in SQLite | Same-event authenticated resolver with observed token | 90 seconds; rotation/revocation |
| Temporary read grant | SQLite | Specific viewer→profile | Two minutes; revoked on target hide/block |
| Positioning handshake | SQLite | Sender and recipient only | Two minutes; stop/hide/block removes it |
| Connection/private note | SQLite | Note author only | Until author removes it or relevant account deletion |
| Reports | SQLite | Reporter in personal export before expiry; authorized local operator with DB access | 90 days from creation, independent of target deletion; reporter link cleared on reporter deletion |
| Payment intent and signature | SQLite | Sender | Until sender account deletion; recipient wallet remains after recipient deletion; unsigned abandoned intents swept after expiry + 24h |
| Confirmed transaction | Solana devnet | Public chain data | Not erasable by Aura |

The database is not application-encrypted: file permissions and host disk encryption are the current local protection. Do not describe private notes as end-to-end encrypted. HTTPS is required for release deployment. Debug HTTP is limited to trusted local tests with devnet accounts.

## Account deletion and safety-report retention

Deletion removes the account's profile, uploaded media, sessions, challenges, memberships, owned events, connections/notes, blocks, ranging state and sender-owned payment records. Connections targeting the account are removed too. It does not erase every occurrence of the wallet: other senders' payment records can retain it, and chain transactions remain public.

Safety reports are a bounded exception. Schema v3 stores the target wallet, report reason (maximum 1,000 characters), creation time and expiry independently of the target's profile. Deleting the target does not delete these reports. Deleting the reporter sets the reporter account link to null; it does not erase information they included in the reason. Re-registering that wallet does not restore ownership of old reports. Reports are never exposed to their targets or other participants through the API.

The pilot retention window is 90 days from the original creation time. The v1/v2 migration preserves that deadline rather than restarting it. Expired reports are excluded from exports immediately, removed from active database rows at startup and on the 30-second cleanup sweep, and not extended by account deletion. This is an operational pilot default, subject to privacy and security review before deployment; it is not a claim of legal compliance or an automatic moderation service.

Deleting rows is not secure erasure of SQLite pages, WAL files or backups. The backup lifecycle remains an operator responsibility. Restoring a database runs expiry cleanup before serving requests, but an older backup can still restore deleted accounts or reporter links: reconcile deletions before reopening access. Establish backup expiry, deletion reconciliation and operator access controls before a participant pilot. See [operator procedure](REPORT-RETENTION.md).

## Why there is no custom contract

The pilot does not require escrow, token issuance, a payment vault, or a consensus-maintained identity registry. Its SOL transfers invoke the System Program. Adding a custom program merely to store profiles would add deployment/audit cost and conflict with deletion and presence privacy. A future registry/attestation feature requires a separate decision record defining the actual public data, authority model, account layout, rent, migration, and revocation semantics. It is not silently assumed to exist.

## Payments

1. Authenticated sender creates an intent for an authorized profile; amount is parsed as integer lamports, with a 1 devnet SOL pilot cap.
2. Server fixes sender, recipient, amount, fresh reference, and expiry.
3. Browser builds a transfer locally; Android requests `/api/payments/prepare`. Both paths use exactly one transfer plus a read-only reference account. Android independently decodes the unsigned bytes and checks the reviewed sender, recipient, amount, permissions and reference.
4. External wallet signs through Wallet Standard or Android MWA. The client verifies the returned message has not changed. Android saves signed bytes and signature in Keystore-encrypted storage before submission, allowing identical-byte recovery after a lost response.
5. Server verifies signatures, fee payer, instruction, amount, recipient, and reference; records the signature before network submission.
6. Devnet submission can succeed, fail, or return an uncertain network outcome. A submitted signature is never discarded or replaced by another signature for the same intent.
7. Confirmation reads the actual transaction at confirmed commitment, checks execution succeeded, signer, recipient, amount, and reference. Only then does UI show confirmed.

Mock RPC tests validate these checks, not blockchain availability. A real devnet smoke test is still a submission gate. Do not automatically re-sign an uncertain payment.

## Presence and spatial truth

The BLE characteristic contains only a random short-lived token; no public wallet-derived HMAC secret. Tokens are not proof of physical co-location: another participant can relay a token within its lifetime. UWB peers must explicitly accept, and world placement is permitted only for measured coordinates. The app tracks a device, not a face or an independently authenticated human body.

Foreground is the supported mode. Backgrounding pauses radio discovery and requests revocation; if offline, the server token expires naturally. Bluetooth platform identifiers and a visible person remain potential tracking signals; “no surveillance of any kind” would be an unsupported claim.

## Recovery

Schema migrations run at startup and refuse an unknown future version. Data defaults to `data/aura.sqlite`; `AURA_DB` overrides it. SQLite backup must include a consistent WAL-aware snapshot, not a naive copy while writes run. `scripts/backup.mjs` provides a SQLite `VACUUM INTO` snapshot. Backups contain private data and must receive retention/access controls before deployment.

## Event directory

`POST /api/events/people` requires membership in the requested event and returns only other members with `eventDirectory: true` and a non-Stealth status. Existing profiles default to unlisted. Each native client and the web profile editor exposes the opt-in and explains that it applies to events the person joins. The directory works without Bluetooth presence; it is not evidence that a member is physically in the room.

Profile/media/payment authorization rechecks shared membership, visibility and blocking at request time. Directory reads do not mint lingering access grants. Opt-out, Stealth or leaving the shared event withdraws directory-based access immediately; independent saved-connection access remains intentional. Old clients that omit the new setting preserve the existing explicit choice. Lists refresh every five seconds while open, clear on errors/background, and recheck authorization before opening a profile. Previously disclosed information cannot be retroactively erased from another user's memory.

The pilot returns the event's opted-in member list in one response. Pagination, large-event load testing and organizer membership controls remain production work.

## Bounded camera positioning

The iPhone advertises `apple-ni-v2` on each presence lease when its NI runtime supports precise distance measurement. Authorized BLE resolution returns this capability hint. The relay requires two currently present, unblocked participants in the same event with that protocol. It allows up to three handshakes per wallet, rejects duplicate pairs and unrelated approvals, and rechecks presence when accepting. Each handshake expires after two minutes; ordinary token renewal preserves it, while a fresh discovery start clears obsolete sessions.

The iPhone manages NI sessions by wallet and request ID rather than one global peer. Camera cards use measured world coordinates and the current AR camera matrices, with a monotonic 1.5-second freshness limit. Projection hides markers behind the camera, outside its viewport, on invalid coordinates, and while tracking is unavailable. Camera session teardown invalidates local ranging. Network revision guards prevent old polls from overwriting newer consent actions. No position is derived from BLE signal strength or a face image. Physical registration and concurrent NI feasibility still require device trials; three is a software limit, not a proven radio capacity.
