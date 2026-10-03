import Foundation
import NearbyInteraction
import ARKit
import Combine

struct SpatialMeasurement {
    let transform: simd_float4x4
    let distance: Float?
    let measuredAt: TimeInterval
}

/// Bounded per-peer sessions. Only hardware measurements may create camera markers.
final class UWBSessionManager: NSObject, ObservableObject, NISessionDelegate, ARSessionDelegate {
    static let peerLimit = 3 // Product cap, not a guarantee about every device's hardware limit.
    @Published private(set) var measurements: [String:SpatialMeasurement] = [:]
    @Published private(set) var messages: [String:String] = [:]
    @Published private(set) var cameraMessage = "Move the phone slowly to establish camera tracking."
    let arSession = ARSession()
    var onFailure: ((String,String) -> Void)?
    var supportsDistance: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }
    var supportsCamera: Bool { NISession.deviceCapabilities.supportsCameraAssistance && ARWorldTrackingConfiguration.isSupported }
    var peerIDs: Set<String> { Set(sessions.keys) }
    private var sessions: [String:NISession] = [:]
    private var freshness: Timer?
    private var cameraRunning = false

    override init() { super.init();arSession.delegate=self;arSession.delegateQueue = .main }
    func startCamera() {
        guard !cameraRunning,ARWorldTrackingConfiguration.isSupported else { return }
        measurements=[:]
        let configuration=ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isCollaborationEnabled = false
        configuration.userFaceTrackingEnabled = false
        configuration.initialWorldMap = nil
        arSession.run(configuration,options:[.resetTracking,.removeExistingAnchors]);cameraRunning=true
    }
    func pauseCamera() { arSession.pause();cameraRunning=false;measurements=[:] }
    func prepare(peer:String) throws -> String {
        guard supportsDistance else { throw APIError.message("Precise positioning is unavailable on this phone.") }
        guard sessions[peer] == nil else { throw APIError.message("Positioning with this participant is already active.") }
        guard sessions.count < Self.peerLimit else { throw APIError.message("Stop one positioning session before adding another.") }
        let session=NISession();session.delegate=self;session.delegateQueue = .main
        guard let token=session.discoveryToken else { session.invalidate();throw APIError.message("Nearby Interaction token unavailable.") }
        let data:Data
        do { data=try NSKeyedArchiver.archivedData(withRootObject:token,requiringSecureCoding:true) }
        catch { session.invalidate();throw error }
        sessions[peer]=session;messages[peer]="Waiting for positioning approval."
        return data.base64EncodedString()
    }
    func run(peer:String,peerToken:String) throws {
        guard let session=sessions[peer],let data=Data(base64Encoded:peerToken),let token=try NSKeyedUnarchiver.unarchivedObject(ofClass:NIDiscoveryToken.self,from:data) else { throw APIError.message("Positioning handshake is unavailable. Request it again.") }
        let configuration=NINearbyPeerConfiguration(peerToken:token)
        if supportsCamera { startCamera();configuration.isCameraAssistanceEnabled=true;session.setARSession(arSession) }
        session.run(configuration);messages[peer]="Point the backs of both phones toward each other to acquire a measurement."
        if freshness == nil {
            freshness=Timer.scheduledTimer(withTimeInterval:0.2,repeats:true) { [weak self] _ in
                guard let self else { return }
                let now=ProcessInfo.processInfo.systemUptime
                for (peer,measurement) in self.measurements where !SpatialProjection.isFresh(measuredAt:measurement.measuredAt,now:now) {
                    self.measurements.removeValue(forKey:peer);self.messages[peer]="Measurement lost. Point toward this participant again."
                }
            }
        }
    }
    func stop(peer:String) {
        let session=sessions.removeValue(forKey:peer);session?.delegate=nil;session?.invalidate()
        measurements.removeValue(forKey:peer);messages.removeValue(forKey:peer)
        if sessions.isEmpty { freshness?.invalidate();freshness=nil }
    }
    func stop() { for peer in Array(sessions.keys) { stop(peer:peer) };pauseCamera() }
    private func peer(for session:NISession) -> String? { sessions.first(where:{$0.value === session})?.key }
    private func fail(_ session:NISession,_ message:String) {
        guard let peer=peer(for:session) else { return };stop(peer:peer);onFailure?(peer,message)
    }
    func session(_ session:NISession,didUpdate objects:[NINearbyObject]) {
        guard let peer=peer(for:session),let object=objects.first else { return }
        guard let configuration=session.configuration as? NINearbyPeerConfiguration,object.discoveryToken==configuration.peerDiscoveryToken,
              supportsCamera,let transform=session.worldTransform(for:object),SpatialProjection.isFinite(transform) else {
            measurements.removeValue(forKey:peer);messages[peer]="Distance or direction unavailable. No profile is placed.";return
        }
        measurements[peer]=SpatialMeasurement(transform:transform,distance:object.distance,measuredAt:ProcessInfo.processInfo.systemUptime)
        messages[peer]="Device position measured."
    }
    func session(_ session:NISession,didRemove objects:[NINearbyObject],reason:NINearbyObject.RemovalReason) { fail(session,"Positioning ended or the peer left range. Request it again.") }
    func sessionWasSuspended(_ session:NISession) { fail(session,"Positioning was interrupted. Request it again when both phones are ready.") }
    func sessionSuspensionEnded(_ session:NISession) { fail(session,"Positioning needs a new session after interruption.") }
    func session(_ session:NISession,didInvalidateWith error:Error) { fail(session,error.localizedDescription) }
    func sessionShouldAttemptRelocalization(_ session:ARSession) -> Bool { false }
    func session(_ session:ARSession,cameraDidChangeTrackingState camera:ARCamera) {
        switch camera.trackingState {
        case .normal: cameraMessage="Camera tracking ready."
        case .notAvailable: measurements=[:];cameraMessage="Camera tracking unavailable."
        case .limited: measurements=[:];cameraMessage="Move slowly; camera tracking is still settling."
        }
    }
    func sessionWasInterrupted(_ session:ARSession) {
        let peers=Array(sessions.keys);stop();cameraMessage="Camera interrupted. Close and reopen it to resume."
        for peer in peers { onFailure?(peer,"Camera positioning was interrupted. Request a new session.") }
    }
    func session(_ session:ARSession,didFailWithError error:Error) {
        let peers=Array(sessions.keys);stop();cameraMessage="Camera tracking stopped. Close and reopen the camera."
        for peer in peers { onFailure?(peer,error.localizedDescription) }
    }
}
