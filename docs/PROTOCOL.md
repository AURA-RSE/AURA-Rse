# Aura pilot protocol v0.1

All authenticated requests use `Authorization: Bearer <session>`. JSON request/response bodies use camelCase except database-backed payment/ranging records, whose stored field names are documented below. Errors return `{ "error": "message" }`. 401 means reauthenticate; 404 intentionally hides inaccessible resources.

## API map

| Route | Purpose |
|---|---|
| GET `/api/health` | Version, schema, devnet status |
| POST `/api/auth/challenge` `{wallet}` | Obtain exact message and challenge id |
| POST `/api/auth/verify` `{id,signature}` | Base64 Ed25519 signature; consumes nonce; returns token/profile |
| POST `/api/auth/logout` | Revoke current session and presence |
| POST `/api/device/start` | Anonymous expiring approval code + secret |
| POST `/api/device/approve` `{code}` | Authenticated wallet authorizes this device |
| POST `/api/device/poll` `{deviceSecret}` | Consume approval once; receive session |
| GET / PUT `/api/me` | Read/update own profile |
| GET / POST `/api/events` | Joined events / create owned event `{name}` |
| POST `/api/events/join` `{code}` | Join an event |
| POST `/api/events/leave` `{event}` | Leave; revoke presence |
| POST `/api/presence` `{event}` | Issue/rotate 90s token |
| DELETE `/api/presence` | Revoke presence, grants, ranging |
| POST `/api/discovery/resolve` `{token}` | Same-event profile resolution; temporary read grant |
| POST `/api/profiles/read` `{wallet}` | Read an already-authorized profile |
| GET / PUT / DELETE `/api/connections` | Own saved profiles; write `{wallet,note}`; delete `{wallet}` |
| GET / POST / DELETE `/api/blocks` | Read blocks; block/unblock `{wallet}` |
| POST `/api/reports` `{wallet,reason}` | Store a report for operator review; returns `expires` (epoch ms), fixed at creation + 90 days |
| POST `/api/ranging` `{wallet,discoveryToken}` | Request one peer; base64 archived NI token |
| GET `/api/ranging` | Own live requests: sender_token, recipient_token, peer, expires |
| POST `/api/ranging/accept` `{id,discoveryToken}` | Recipient accepts |
| DELETE `/api/ranging` `{id}` | Participant cancels |
| POST `/api/payments` `{wallet,amount}` | Create intent; amount is a decimal string |
| GET `/api/payments` | Own payment history incl. submitted_signature and confirmed signature |
| POST `/api/payments/submit` `{id,transaction}` | Base64 signed transfer; validate and durably submit |
| POST `/api/payments/confirm` `{id,signature?}` | Check devnet receipt; defaults to submitted signature |
| POST `/api/media` `{kind,base64}` | Replace avatar or video; maximum 2 MB / 20 MB |
| GET `/api/media/:id` | Protected raw bytes, correct media MIME |
| DELETE `/api/media` `{kind}` | Delete own avatar/video |
| GET `/api/account/export` | Owner data + base64 uploaded media |
| DELETE `/api/account` `{confirm:"DELETE"}` | Delete account-owned records; unlink reporter identity; retain unexpired safety reports and other senders’ payment histories |
| POST `/rpc` | Authenticated read-only devnet RPC subset for browser transaction construction |

Profile fields: `name`, `role`, `project`, `bio`, `link`, `video`, `intents`, `status`. Status values: `open`, `heads-down`, `stealth`. Server owns `wallet`, `updated`, `avatarMediaId`, `videoMediaId`. Neither links nor project names are externally verified.

Account exports include only the caller's unexpired reports, with `target`, `reason`, `created` and `expires`. Deleting a reporter clears the report's owner link; signing up again does not reclaim those reports. No API exposes reports to their targets. See [retention and deletion semantics](REPORT-RETENTION.md).

## Radio wire format

- BLE service UUID: `A7840001-F5C5-4C53-AA82-BF9A2A3F77E4`.
- Read-only GATT characteristic: `A7840002-F5C5-4C53-AA82-BF9A2A3F77E4`.
- Value: UTF-8 base64url token issued by `/api/presence` (16 random bytes / 22 characters).
- Broadcast only the service UUID. No wallet/name in advertisement or local device name.
- Peer connects, reads characteristic with correct ATT offsets, disconnects, resolves via authenticated API.
- Repeat reads with bounded concurrency and cooldown; tokens rotate. Do not cache a token as a permanent device identity.
- Never use RSSI as a precise direction or position.

Both iOS and Android now implement this BLE contract; physical cross-platform compatibility is not established until tested. The NI relay token format is Apple-specific. Android/UWB interoperability needs a versioned, platform-aware handshake rather than feeding NI archives into Android APIs.

## Native Android wallet payments

`POST /api/payments/prepare` accepts `{id}` for the authenticated sender. It rejects submitted/confirmed or expired intents and unavailable recipients, fetches a confirmed blockhash, then repeats the checks after network I/O. It returns the original intent, `cluster: devnet`, `transaction` (base64 unsigned legacy transaction) and `lastValidBlockHeight`. Caller-supplied amounts/recipients cannot change the intent.

Android decodes and validates the transfer against the review, requests MWA signing-only approval, compares signed message bytes, persists the signature/transaction encrypted locally, and uses the existing submit/confirm endpoints. Recovery may retry identical signed bytes; it never requests a second signature. The server still verifies cryptographic signatures before submission. A failed or expired unresolved payment may require manual review; there is no automatic replacement payment.
