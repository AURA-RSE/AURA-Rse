# Real-device pilot and evidence plan

Start with the [device validation checklist](DEVICE-VALIDATION.md) and assign an operator using the [report-retention procedure](REPORT-RETENTION.md). Record failures as failures; the checklist does not establish device compatibility.

## Two-device smoke test

Use different test wallets and the same event. Record device models, OS versions, app build, server revision/source checksum, network, and physical layout. Do not use actual personal funds.

1. Verify wallet ownership in the web companion and pair both phones. Restart each app; confirm the Keychain session and server profile return.
2. Keep Stealth enabled. Neither device should resolve the other's presence.
3. Choose Open and start discovery on both. Measure first-discovery latency. Confirm names/wallets manually.
4. Rotate a token; confirm old token rejection and continued discovery. Toggle Bluetooth off/on; scanning should only resume if explicitly started.
5. Save a profile and private note. Restart server and client. Verify persistence and note isolation.
6. Upload a real avatar and <=30s MP4; verify playback and that a third account without discovery cannot read them.
7. Request positioning. Verify recipient must accept; third account cannot read handshake. Confirm compatible hardware reports actual distance and position.
8. Move, rotate, occlude, walk out of range, cross paths. Record incorrect/missing placement and recovery. No positional measurement means no spatial card.
9. Hide, block, background, or revoke pairing. Measure disappearance. Offline server presence may remain resolvable until 90-second expiry; cached downloaded data cannot be recalled.
10. Create a devnet SOL payment, review full recipient, sign in an actual supported wallet, and independently open the devnet explorer receipt. Confirm no test fixture is involved.
11. Disconnect networking immediately after signing/submission. Check the stored signature; do not create a second payment until its outcome is established.
12. Export and delete a test account. Verify its profile/media/sessions disappear. Verify existing safety reports survive until their original 90-day deadline and reporter deletion clears the owner link. Check the other sender's payment history still retains the deleted recipient wallet. Explain these exceptions, public chain records and backup limits before participant consent.

## Small-room pilot

Recruit 15–30 consenting participants. Include at least one phone without precise positioning support. Use an operator to record aggregate observations rather than logging movement histories.

Record in `pilot-observations.csv`:

```
run_id,build,platform,device_model,os_version,scenario,participant_count,attempts,successes,wrong_identity_count,median_discovery_seconds,p95_discovery_seconds,position_available_fraction,notes
```

Keep an incident log, failure videos with permission, battery baseline/end readings, permission failures, wallet compatibility results, and participant feedback. Ask whether someone made a useful new connection; do not infer value solely from screen opens.

## Validation record

- Two-minute unedited real-device interaction video.
- Installable build instructions and exact compatibility matrix.
- Test outputs, known limitations, storage/architecture decision, threat model.
- Real devnet transaction receipt(s), labeled test transactions.
- Pilot observation report, including failures and missing position data.
- Pilot-host consent and participant consent records stored privately.
- SDK integration example evaluated by an external builder.

Automated screenshots using synthetic test wallets are labeled as fixtures and must never be passed off as live users or adoption.
