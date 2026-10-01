# Aura proximity SDK (local v0.1)

Transport-independent JavaScript API client. No framework, radio, custody, or generated identities. Import `AuraClient` from `index.mjs` in this local workspace. The package is private and has not been published or licensed for public release yet.

```js
import { AuraClient } from './index.mjs';
const aura = new AuraClient({ baseURL: 'https://your-aura-server.example' });
await aura.signIn(wallet.address, message => wallet.signMessage(message));
await aura.join(eventCode);
// Obtain token from your platform's real BLE characteristic read:
const { profile } = await aura.resolve(observedToken);
await aura.saveConnection(profile.wallet, 'Discuss the demo next week');
```

`signMessage` must return raw Ed25519 signature bytes over the exact message. Adapt external wallet responses explicitly. The token is secret: never broadcast it over BLE; only the server-issued short-lived presence token belongs in the GATT characteristic.

See `docs/PROTOCOL.md` for the API and BLE contract, and `docs/CAPABILITIES.md` for remaining Swift/Kotlin packaging and real-device evidence requirements.
