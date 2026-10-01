# Safety-report retention and account deletion

The local pilot keeps safety reports for 90 days from creation to allow incident review even if the reported account is deleted. This default requires operational/privacy review before any participant pilot; it does not establish a legal retention requirement.

## Stored evidence and access

A report contains a random ID, target wallet, reporter wallet link, reason (up to 1,000 characters), creation time and expiry. No profile snapshot, location trace, media attachment or session token is copied into the report. Participants should include only information needed to describe the incident.

The reporter can export their own unexpired reports. The target and unrelated participants cannot read them through the API. Only an authorized operator with local database access can review the full report store; there is no moderation dashboard, automated decision system or promised response time.

| Event | Result |
|---|---|
| Target deletes account | Report and original target wallet survive until expiry |
| Reporter deletes account | Owner link becomes null; reason and target remain until expiry |
| Reporter registers the same wallet again | Old reports are not relinked or exported to the new account |
| Original 90-day deadline arrives | Export excludes the report immediately; startup/30-second sweep removes the row |
| Legacy database upgraded | Deadline remains original creation time + 90 days |
| Sender deletes account | Sender-owned payment records are removed |
| Recipient deletes account | Other senders retain their payment records, including the recipient wallet |

## Before a participant pilot

1. Assign an incident operator and give participants a contact and response expectation. No staffing is implied by this repository.
2. Disclose the 90-day report exception and deletion limits before consent. Explain that a report's free text may still identify its author after their account link is removed.
3. Restrict database and backup access to authorized operators. Do not copy incident content into public issues, source control, recordings or test evidence.
4. Define backup expiry and a deletion-reconciliation procedure. Do not restore an old backup into a participant-facing service until deleted accounts and reporter links have been reconciled.
5. Verify expiry with generated test records, without changing the clock of a live participant database. The automated tests cover the exact deadline and startup cleanup.
6. Arrange escalation and review procedures for reported incidents. Reports are allegations, not verified findings. Retention does not itself prevent abuse or ban a re-registering wallet.

The application removes active rows, not forensic remnants in SQLite pages/WAL or independent backups. There is no implemented retention extension or legal-hold feature. Do not claim complete erasure or production-ready abuse operations.
