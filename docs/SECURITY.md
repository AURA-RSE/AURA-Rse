# Security and privacy review notes

This implementation has automated regression checks but has not received an independent audit.

## Implemented protections

- Ed25519 wallet proof over server nonce, origin, wallet, and expiry; replay prevented by challenge consumption.
- Random high-entropy bearer sessions stored hashed server-side. iOS uses device-only, unlocked Keychain access; browser holds auth only in memory.
- Bounded JSON and uploads, field validation, prepared SQL, default Stealth, same-event token resolution.
- Expiring presence/read/ranging tokens; bilateral blocks; explicit recipient acceptance for positioning.
- No public attendee-directory API or public media bucket. Private notes are owner-scoped.
- Profile text rendered with native text components / textContent, no raw HTML injection.
- Origin checks, restrictive CSP, no-referrer, nosniff, no auth cookies.
- Devnet-only RPC target and pilot amount cap. Exact integer lamports.
- Signed transfer checked against the intent before submission. Signature stored before RPC I/O. Confirmation checked independently.
- Media signature/type/size checks and protected retrieval; account deletion cascades.

## Remaining risks / deployment gates

- BLE token replay/relay can misrepresent proximity. Wallet ownership is not human identity verification. Names/projects/social links are self-asserted.
- Device position is not a face/body identity proof. Dense crowds, pockets, obstacles, orientation and cross-platform UWB are unvalidated.
- A trusted backend sees profiles, notes, media, wallet bindings and presence resolution; this is not decentralized or end-to-end encrypted identity.
- Profile recipients can retain or screenshot data. Stealth revokes discovery, not previously received information; saved connections retain profile access unless blocked.
- Debug LAN HTTP is not confidential. Production requires HTTPS and external hardening.
- SQLite backup access, retention, restore verification, server-side encryption choices, operational monitoring and distributed rate limiting are not completed.
- Upload checks recognize container signatures, not safe decoding, exact duration, codecs, transcoding or malicious payload scanning. Video duration is checked in the web client only. Public upload deployment requires a hardened media pipeline and resource quotas.
- Reports are persisted; there is no staffed moderation service in this local build. Establish an operator process before a pilot.
- Event codes can be shared; stronger invites/organizer roles, deletion/closure and anti-abuse quotas remain work.
- Session theft enables account actions until expiry/revocation. Sensitive account deletion currently uses active-session authorization and explicit confirmation, not a fresh wallet signature.
- SOL-only devnet; native mobile wallet return flows and SPL support are pending. A definitive failed submission currently requires operator/user review before a new intent; no automatic retry/re-sign path.
- Some transaction metadata remains inherently public on-chain even after Aura account deletion.

Before public deployment: independent security/privacy review; request/body/concurrency quotas; strict HTTPS; backup/restore drill; dependency review; live wallet testing; physical radio/AR validation; abuse response; documented retention and participant consent.
