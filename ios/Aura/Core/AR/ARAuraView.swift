import SwiftUI
import ARKit
import RealityKit

/// Only fresh Nearby Interaction measurements place identity content in the scene.
struct ARAuraView: UIViewRepresentable {
    @ObservedObject var positioning: UWBSessionManager
    var name: String
    var select: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator(positioning:positioning) }
    func makeUIView(context:Context) -> ARView {
        let view = ARView(frame:.zero,cameraMode:.ar,automaticallyConfigureSession:false)
        view.session = positioning.arSession
        if ARWorldTrackingConfiguration.isSupported { view.session.run(ARWorldTrackingConfiguration()) }
        context.coordinator.view=view
        view.addGestureRecognizer(UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:))))
        context.coordinator.start()
        return view
    }
    func updateUIView(_ view:ARView,context:Context) { context.coordinator.name=name;context.coordinator.select=select }
    static func dismantleUIView(_ view:ARView,coordinator:Coordinator) { coordinator.stop();view.session.pause();view.scene.anchors.removeAll() }
    final class Coordinator:NSObject {
        weak var view:ARView?
        let positioning:UWBSessionManager
        var name=""
        var select:()->Void = {}
        private var displayLink:CADisplayLink?
        private var anchor:AnchorEntity?
        private var card:Entity?
        private var displayedName=""
        init(positioning:UWBSessionManager){self.positioning=positioning}
        func start(){let link=CADisplayLink(target:self,selector:#selector(updateFrame));link.add(to:.main,forMode:.common);displayLink=link}
        func stop(){displayLink?.invalidate();displayLink=nil;anchor?.removeFromParent();anchor=nil;card=nil}
        @objc func tap(_ gesture:UITapGestureRecognizer){guard let view,positioning.worldTransform != nil,anchor?.isEnabled == true,view.entity(at:gesture.location(in:view)) != nil else{return};select()}
        @objc func updateFrame(){
            guard let view,let transform=positioning.worldTransform,let frame=view.session.currentFrame,case .normal=frame.camera.trackingState else{anchor?.isEnabled=false;return}
            let point=SIMD3<Float>(transform.columns.3.x,transform.columns.3.y,transform.columns.3.z)
            let camera=simd_inverse(frame.camera.transform)*SIMD4<Float>(point,1)
            guard camera.z<0,let projected=view.project(point),view.bounds.contains(projected) else{anchor?.isEnabled=false;return}
            if card==nil || displayedName != name {
                anchor?.removeFromParent();let next=AnchorEntity(world:.zero);let content=ProfileCardEntity.make(name:name);content.generateCollisionShapes(recursive:true);next.addChild(content);view.scene.addAnchor(next);anchor=next;card=content;displayedName=name
            }
            anchor?.isEnabled=true
            card?.look(at:SIMD3<Float>(frame.camera.transform.columns.3.x,frame.camera.transform.columns.3.y,frame.camera.transform.columns.3.z),from:point,relativeTo:nil)
        }
    }
}
