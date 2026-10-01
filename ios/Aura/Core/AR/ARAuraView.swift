import SwiftUI
import ARKit
import RealityKit

struct ARAuraView: UIViewRepresentable {
    @ObservedObject var positioning: UWBSessionManager
    var name: String
    func makeUIView(context:Context) -> ARView {
        let view = ARView(frame:.zero,cameraMode:.ar,automaticallyConfigureSession:false)
        view.session = positioning.arSession
        if ARWorldTrackingConfiguration.isSupported { view.session.run(ARWorldTrackingConfiguration()) }
        return view
    }
    func updateUIView(_ view:ARView,context:Context) {
        view.scene.anchors.removeAll()
        guard let transform = positioning.worldTransform,
              let frame = view.session.currentFrame,
              case .normal = frame.camera.trackingState else { return }
        let point = SIMD3<Float>(transform.columns.3.x,transform.columns.3.y,transform.columns.3.z)
        let camera = simd_inverse(frame.camera.transform) * SIMD4<Float>(point,1)
        guard camera.z < 0,let projected = view.project(point),view.bounds.contains(projected) else { return }
        let anchor = AnchorEntity(world:point)
        let card = ProfileCardEntity.make(name:name)
        anchor.addChild(card)
        card.look(at:SIMD3<Float>(frame.camera.transform.columns.3.x,frame.camera.transform.columns.3.y,frame.camera.transform.columns.3.z),from:point,relativeTo:nil)
        view.scene.addAnchor(anchor)
    }
    static func dismantleUIView(_ uiView:ARView,coordinator:()) { uiView.session.pause();uiView.scene.anchors.removeAll() }
}
