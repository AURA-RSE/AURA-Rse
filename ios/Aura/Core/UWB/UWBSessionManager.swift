import Foundation
import NearbyInteraction
import ARKit
import Combine

/// One explicitly accepted peer at a time. Hardware validation remains required.
final class UWBSessionManager: NSObject, ObservableObject, NISessionDelegate {
    @Published private(set) var distance: Float?
    @Published private(set) var worldTransform: simd_float4x4?
    @Published private(set) var message = "Select a nearby participant to request positioning."
    @Published private(set) var peerID: String?
    let arSession = ARSession()
    var supportsDistance: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }
    var supportsCamera: Bool { NISession.deviceCapabilities.supportsCameraAssistance && ARWorldTrackingConfiguration.isSupported }
    private var session: NISession?
    private var freshness: Timer?
    private var measuredAt = Date.distantPast
    func prepare(peer: String) throws -> String {
        guard supportsDistance else { throw APIError.message("Precise positioning is not supported on this device. Nearby discovery remains available.") }
        stop(); peerID = peer
        let s = NISession(); s.delegate = self; s.delegateQueue = .main; session = s
        guard let token = s.discoveryToken else { stop(); throw APIError.message("Nearby Interaction token unavailable.") }
        message = "Waiting for the other participant to accept."
        return try NSKeyedArchiver.archivedData(withRootObject:token,requiringSecureCoding:true).base64EncodedString()
    }
    func run(peerToken: String) throws {
        guard let session,let data = Data(base64Encoded:peerToken),let token = try NSKeyedUnarchiver.unarchivedObject(ofClass:NIDiscoveryToken.self,from:data) else { throw APIError.message("Invalid positioning handshake.") }
        let configuration = NINearbyPeerConfiguration(peerToken:token)
        if supportsCamera { arSession.run(ARWorldTrackingConfiguration()); configuration.isCameraAssistanceEnabled = true; session.setARSession(arSession) }
        session.run(configuration); message = "Point the backs of both phones toward each other. Keep a clear line of sight."
        freshness?.invalidate()
        freshness = Timer.scheduledTimer(withTimeInterval:0.3,repeats:true) { [weak self] _ in
            guard let self else { return }
            if Date().timeIntervalSince(self.measuredAt) > 1.5 { self.worldTransform = nil; self.distance = nil }
        }
    }
    func stop() { freshness?.invalidate();freshness = nil;let old = session;session = nil;old?.invalidate();arSession.pause();peerID = nil;distance = nil;worldTransform = nil;message = "Positioning stopped." }
    func session(_ session:NISession,didUpdate nearbyObjects:[NINearbyObject]) {
        guard self.session === session,let object = nearbyObjects.first else { return }
        measuredAt = Date();distance = object.distance
        worldTransform = supportsCamera ? session.worldTransform(for:object) : nil
        message = worldTransform == nil ? "Position unavailable. Use the nearby list; no card is attached to a person." : "Measured device position. Confirm the person before transacting."
    }
    func session(_ session:NISession,didRemove nearbyObjects:[NINearbyObject],reason:NINearbyObject.RemovalReason) { worldTransform = nil;distance = nil;message = "Peer out of range. Request positioning again." }
    func sessionWasSuspended(_ session:NISession) { worldTransform = nil;distance = nil;message = "Positioning suspended." }
    func sessionSuspensionEnded(_ session:NISession) { stop() }
    func session(_ session:NISession,didInvalidateWith error:Error) { guard self.session === session else { return };stop();message = error.localizedDescription }
}
