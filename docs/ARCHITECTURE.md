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
| Profile | SQLite JSON | Owner, current authorized discoverer, saved connection; blocks override | Until deleted |
| Uploaded avatar/video | SQLite BLOB | Same profile authorization | Replaced by owner or deleted with account |
| Event/member records | SQLite | Authenticated memberships and owner operations | Until account/event lifecycle removes them |
| Presence token | Phone memory; hash in SQLite | Same-event authenticated resolver with observed token | 90 seconds; rotation/revocation |
| Temporary read grant | SQLite | Specific viewer→profile | Two minutes; revoked on target hide/block |
| Positioning handshake | SQLite | Sender and recipient only | Two minutes; stop/hide/block removes it |
| Connection/private note | SQLite | Note author only | Until author removes it or relevant account deletion |
| Reports | SQLite | Reporter in personal export, local operator with DB access | Until deletion; production retention policy pending |
| Payment intent and signature | SQLite | Sender | Until account deletion; unsigned abandoned intents swept after expiry + 24h |
| Confirmed transaction | Solana devnet | Public chain data | Not erasable by Aura |

The database is not application-encrypted: file permissions and host disk encryption are the current local protection. Do not describe private notes as end-to-end encrypted. HTTPS is required for release deployment. Debug HTTP is limited to trusted local tests with devnet accounts.

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
