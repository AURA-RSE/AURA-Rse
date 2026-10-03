# Aura room camera

Room Camera is intended to let participants turn around an event and open profiles at measured device locations. Identity authorization, camera preview, and positional measurement are separate capabilities.

## Current implementation

**iPhone:** the camera canvas now contains only measured profile markers. It no longer presents a nearby-card tray as camera search. Each marker is projected from a fresh Nearby Interaction world transform through the current camera view and projection matrices. Turning away hides it. Lost tracking, expired measurements, leaving the event, stopping a session, and disappearing peers remove markers. A marker identifies a consenting participant's device; it does not recognize the person holding it.

A separate **Position people** panel shows compatible nearby participants, sends positioning requests, and lets recipients accept or stop them. The app and relay cap sessions at three participants per device. That is an application cap, not a hardware concurrency guarantee. Each participant has a separate NI session, discovery token, approval, timeout, measurement and stop action. Late network replies cannot resurrect a stopped local session. The camera is configured according to Apple's shared-session requirements and does not attempt relocalization after an interruption.

**Android:** CameraX preview and the explicitly unpositioned nearby tray remain available. Android does not advertise the Apple positioning protocol and cannot be selected for this iPhone positioning path. No Android UWB/ARCore positioning is claimed.

Both platforms retain the original searchable nearby Floating/List view and the separate opt-in event directory. The directory does not imply physical proximity. No images are uploaded, recorded, or matched against faces by these features.

## First physical positioning test

1. Update the server and both compatible iPhones. Join the same event using distinct verified Aura profiles; choose a visible status and start discovery.
2. On the viewing phone, open **Room Camera → Position people** and request a compatible participant.
3. On the other phone, review and accept the request. Camera permission is requested before camera-assisted positioning starts. An incompatible or old client is shown as unavailable for positioning.
4. Return to Camera. Point the backs of the phones toward each other to acquire the initial measurement. An empty camera is expected until NI provides a valid world transform.
5. With one phone held still, rotate the viewing phone. The marker should follow the measured device location, leave the view when the device does, and reopen the correct profile when tapped. Record alignment error, distance, lighting, acquisition delay and lost measurements.
6. Move the target phone and repeat. Then test two and three accepted peers. Hardware session-limit errors must stop the affected session visibly rather than invent a marker. Measure whether simultaneous camera-assisted sessions are actually supported on the tested devices.
7. Test cancellation, denial, Stealth, blocking, backgrounding, lost network, lost Bluetooth, expired sessions and camera interruptions. Repeat after rotating the viewing phone and after restarting the app.

The current iPhone–Samsung test pair cannot validate Apple-to-Apple ranging. A second compatible iPhone is needed for the first physical result, and additional phones for concurrency. The software checks below are not substitutes for that evidence.

## Software verification

- `npm test`: authenticated relay, bilateral consent, capability rejection, three-request bounds, independent cancellation, expired presence, fresh-session reset, and v3-to-v4 presence migration.
- `npm run test:spatial`: 15 assertions against the renderer's actual projection helper, including camera translation/rotation, multiple positions, offscreen and behind-camera devices, invalid coordinates, tracking loss and measurement freshness. Geometry is synthetic.
- iOS signed build: verifies framework integration compiles and produces a signed artifact, not physical UWB accuracy.
- Android emulator and web fixture checks: verify existing non-spatial flows remain compatible with the upgraded server.

No full-room coverage, physical accuracy threshold, simultaneous NI capacity, or cross-platform spatial success has been demonstrated yet.

## Server upgrade

Schema v4 adds `presence.ranging_protocol`, defaulting existing phones to no positioning capability. Stop the old Aura server and back up its SQLite database before restarting the new code; do not run an old and new server against this database together. Migration preserves existing token rows. New iPhone discovery advertises `apple-ni-v2`; normal renewals preserve handshakes, while an explicit fresh start clears obsolete handshakes. Capabilities are client-declared compatibility hints, not hardware attestation.

## Apple API references

- [NISession: one session per nearby object](https://developer.apple.com/documentation/nearbyinteraction/nisession)
- [Sharing an ARSession and its required configuration](https://developer.apple.com/documentation/nearbyinteraction/nisession/setarsession(_:))
- [Apple peer positioning configuration](https://developer.apple.com/documentation/nearbyinteraction/ninearbypeerconfiguration)
