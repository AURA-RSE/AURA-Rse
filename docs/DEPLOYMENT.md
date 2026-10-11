# Aura pilot server deployment

Status: deployment recipe prepared; no cloud service or public URL provisioned. Docker is not installed on the preparation Mac, so the container build has not been executed here. The native Node server and browser/API tests are verified separately. This is a pilot deployment recipe, not a production-readiness claim.

## Local review without a hosting account

Use the README setup (`npm ci`, `npm run build`, `npm start`) for desktop review. Physical phones need the Mac's LAN address and the same Wi-Fi. The Mac must stay awake and the Aura process must remain running. A new Wi-Fi network may change the server address; use the same new origin on each phone and in the wallet browser. Sessions are scoped to their original server address, so a change may require pairing again.

## Container recipe for a hosting operator

The root Dockerfile bundles the API and web companion, runs as the unprivileged node user and includes a health check. Its build context is allowlisted to exclude local profiles, wallet/session data, signing material and mobile toolchains.

```sh
docker build -t aura-pilot .
docker volume create aura-pilot-data
docker run --name aura-pilot --restart unless-stopped \
  -p 127.0.0.1:4317:4317 \
  -e AURA_ORIGIN=https://YOUR-PILOT-HOST \
  -v aura-pilot-data:/app/data aura-pilot
```

Replace YOUR-PILOT-HOST with an actual host before starting. Set up HTTPS at the hosting platform or reverse proxy and route it to the private application port. On platforms requiring a public container listener, expose the internal port through the platform's HTTPS service instead of publishing raw HTTP. The browser and both apps must use exactly the AURA_ORIGIN value. Release mobile builds require HTTPS.

Use one application instance and a persistent writable local filesystem for `/app/data` (node UID 1000). The app uses SQLite WAL; ephemeral disks and multiple replicas sharing a network filesystem are not an accepted deployment here. Keep the same database across rebuilds. Do not copy the developer's pilot database to a public service by default; start empty and onboard consenting users.

Before inviting anyone: verify `/api/health`, wallet sign-in, pairing, event join and durable profile/connection reads after a restart. Take a consistent SQLite snapshot with `scripts/backup.mjs`, copy it to protected off-host storage and test restoration. Define the backup schedule, retention, incident contact and report-review owner. Do not log bearer tokens, pairing secrets or wallet signatures. Rate limits currently use the socket peer for unauthenticated clients; a shared proxy can group clients into one budget. Pilot load and trusted-proxy handling must be qualified before opening registration widely.

Use devnet only. No RPC keys or wallet private keys are needed by this build. Review the [threat model](SECURITY.md), [retention procedure](REPORT-RETENTION.md) and [capabilities](CAPABILITIES.md) before a wider rollout.

Implementation references: [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/), [official Node image guidance](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md), [Node 24 SQLite](https://nodejs.org/download/release/latest-v24.x/docs/api/sqlite.html).
