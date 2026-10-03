# Aura room camera

The intended experience is to open a live camera, look around an event, and open opted-in participant profiles from the camera view. Discovery, wallet verification, and spatial placement are separate capabilities.

## Implemented in this build

- Android: CameraX rear-camera preview with explicit runtime permission, lifecycle-bound capture, a responsive nearby-profile tray, and links to saved connections. Opening a profile uses the same authenticated flow as Discover. Pausing discovery clears nearby cards. Closing the camera or leaving the app releases or suspends camera capture.
- iPhone: a full-screen ARKit camera with explicit permission, nearby-profile tray, profile sheets, discovery controls, and positioning status. One accepted Nearby Interaction peer can have a tappable profile marker at its measured device position. The marker updates with the camera frame and hides when positioning or camera tracking is unavailable.
- Images stay on the device. This feature contains no image uploads, face matching, video recording, or microphone capture.

## What profile placement means

Nearby trays show event-scoped profiles resolved from Bluetooth tokens. Their order is for browsing and does not represent bearing, distance, a person in the camera frame, or device coordinates. They remain labeled as unpositioned.

The iPhone measured marker uses Nearby Interaction and the shared AR session. It marks the other device, not a biometric identification of the person holding it. The participant must accept positioning first. Physical camera-registration accuracy is still unverified.

Android camera preview does not implement UWB/ARCore positioning. This iPhone/Android pair can test a live preview and authorized nearby profiles, but cannot validate the existing Apple-to-Apple positioning path. Room-wide, multi-person anchored overlays remain unimplemented; a camera background alone is not that capability.

## Physical checks

1. Update each app, preserve the existing wallet session, and join the same event with distinct test wallets.
2. Open room camera. Check camera permission acceptance, denial, portrait/landscape layout, and return from background. The camera indicator must stop when leaving the camera or backgrounding the app.
3. Start discovery on both devices. Check that fresh authorized profiles appear in the camera tray, open their details, save a note, and retrieve it without discovery.
4. Pause discovery or enter Stealth and verify cards clear. A physical Stealth regression remains pending after the Android profile-draft fix.
5. With a second compatible iPhone, request and accept positioning, then verify measured-marker alignment, movement, out-of-view hiding, occlusion, expiry, and tap behavior against the physical scene. Record failures and missing measurements.
6. Do not label tray browsing as positional AR or the emulator camera as a physical device result.

## Camera limitation reported during manual use — 2026-10-03

The user reported that camera search behaved like the existing search over a camera feed. This is a valid limitation report, not a successful spatial test. The Android tray is still a nearby list, and the iPhone camera cannot place profiles without a fresh accepted Nearby Interaction measurement. Both interfaces now make the absence of positional capability explicit. Do not describe these changes as a fix for multi-person camera discovery.

The separate **People at this event** directory preserves browsing without opening the camera or starting BLE discovery. It lists explicitly opted-in visible members, supports name/role/project and intent filtering, and does not imply physical proximity. The existing nearby Floating/List search remains available.

The next physical positioning test requires two compatible Apple devices. The existing `NINearbyPeerConfiguration` path is Apple-to-Apple; it does not position an Android peer. See [Apple's peer configuration](https://developer.apple.com/documentation/nearbyinteraction/ninearbypeerconfiguration). Cross-platform room coverage needs an additional measured positioning design and validation. A camera preview, BLE signal strength, arbitrary card coordinates, and face matching are not substitutes for that work.
