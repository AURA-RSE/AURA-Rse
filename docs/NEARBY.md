# Builders around you

Aura's iPhone and Android Discover screens offer a floating profile view for opt-in participants discovered in the same event. Tap a card to open the existing profile actions: project links, connection notes, reporting/blocking and devnet payment review. iPhone positioning remains a separate consented, single-peer flow.

## Interaction

- Start discovery only after joining an event and choosing a visible status.
- Browse cards containing an authorized avatar or initial, name, role, project, interest and availability.
- Search by name, role or project; filter by Building, Hiring, Fundraising, Looking for a team, Offering feedback or Open to connect.
- Switch between Floating and List. Card order is stable by name and wallet, rather than jumping as Bluetooth observations arrive.
- Heads down remains visible with its availability label. Stealth stops discovery.
- Pause clears discovered profiles. Expired observations and failed/blocked resolution remove cards using the existing discovery lifecycle.

## What the layout means

Cards are arranged for browsing. Their positions, spacing and floating animation do not represent distance, compass direction, GPS coordinates or a person's location on a map. Aura does not convert Bluetooth signal strength into physical coordinates, and this view adds no location-history collection or global profile directory.

The source of every card is the existing authenticated BLE-token resolution endpoint. A saved connection alone does not populate this view. Both participants must opt in and share an event; a relay of a valid token remains a known limitation of Bluetooth proximity proof. Physical iPhone/Android discovery is still awaiting real-device validation.

## Accessibility and validation

The iPhone view respects Reduce Motion and uses one column at accessibility text sizes. Android floating motion follows system animator settings and uses one column for large font scaling. Both offer a conventional list and accessible profile actions.

Emulator profiles are generated test fixtures and must be labelled as such. The instrumented Android check exercises real API resolution from injected test observations, filtering, layout switching, profile opening, blocking, expiry and pausing. It does not establish real radio behavior. iPhone compilation likewise does not establish physical positioning or discovery reliability.
