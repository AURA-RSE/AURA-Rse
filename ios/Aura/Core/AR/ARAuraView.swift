import SwiftUI
import ARKit
import RealityKit

/// Screen cards are projected from measured world coordinates on every camera frame.
struct ARAuraView: UIViewRepresentable {
    @ObservedObject var positioning:UWBSessionManager
    var profiles:[AuraProfile]
    var select:(String)->Void
    func makeCoordinator() -> Coordinator { Coordinator(positioning:positioning) }
    func makeUIView(context:Context) -> ARView {
        let view=ARView(frame:.zero,cameraMode:.ar,automaticallyConfigureSession:false)
        view.session=positioning.arSession;positioning.startCamera()
        context.coordinator.view=view;context.coordinator.start();return view
    }
    func updateUIView(_ view:ARView,context:Context) { context.coordinator.profiles=Dictionary(uniqueKeysWithValues:profiles.map{($0.wallet,$0)});context.coordinator.select=select }
    static func dismantleUIView(_ view:ARView,coordinator:Coordinator) { coordinator.stop();coordinator.positioning.stop() }
    final class Coordinator:NSObject {
        weak var view:ARView?
        let positioning:UWBSessionManager
        var profiles:[String:AuraProfile]=[:]
        var select:(String)->Void = {_ in}
        private var displayLink:CADisplayLink?
        private var cards:[String:UIButton]=[:]
        init(positioning:UWBSessionManager){self.positioning=positioning}
        func start(){let link=CADisplayLink(target:self,selector:#selector(updateFrame));link.add(to:.main,forMode:.common);displayLink=link}
        func stop(){displayLink?.invalidate();displayLink=nil;for card in cards.values {card.removeFromSuperview()};cards=[:]}
        @objc private func tap(_ sender:UIButton){guard let peer=sender.accessibilityIdentifier,!sender.isHidden,profiles[peer] != nil,let measurement=positioning.measurements[peer],SpatialProjection.isFresh(measuredAt:measurement.measuredAt,now:ProcessInfo.processInfo.systemUptime) else {return};select(peer)}
        @objc func updateFrame(){
            guard let view else{return}
            for peer in Array(cards.keys) where profiles[peer]==nil || positioning.measurements[peer]==nil { cards.removeValue(forKey:peer)?.removeFromSuperview() }
            guard let frame=view.session.currentFrame,case .normal=frame.camera.trackingState,let orientation=view.window?.windowScene?.interfaceOrientation,orientation != .unknown else { for card in cards.values {card.isHidden=true};return }
            let projection=frame.camera.projectionMatrix(for:orientation,viewportSize:view.bounds.size,zNear:0.01,zFar:100)
            let cameraView=frame.camera.viewMatrix(for:orientation)
            for (peer,measurement) in positioning.measurements {
                guard let profile=profiles[peer] else {continue}
                guard let point=SpatialProjection.point(transform:measurement.transform,view:cameraView,projection:projection,viewport:SIMD2<Float>(Float(view.bounds.width),Float(view.bounds.height)),measuredAt:measurement.measuredAt,now:ProcessInfo.processInfo.systemUptime,tracking:true) else {cards[peer]?.isHidden=true;continue}
                let card:UIButton
                if let existing=cards[peer] {card=existing} else {
                    card=UIButton(type:.system);card.accessibilityIdentifier=peer;card.addTarget(self,action:#selector(tap(_:)),for:.touchUpInside)
                    card.backgroundColor=UIColor(white:0.035,alpha:0.9);card.layer.cornerRadius=18;card.layer.borderWidth=1;card.layer.borderColor=UIColor(red:0.82,green:1,blue:0.45,alpha:0.8).cgColor
                    card.titleLabel?.numberOfLines=3;card.titleLabel?.textAlignment = .center;card.titleLabel?.font = .systemFont(ofSize:14,weight:.semibold);card.setTitleColor(.white,for:.normal)
                    view.addSubview(card);cards[peer]=card
                }
                let distance=measurement.distance.map { String(format:"%.1f m · measured device",$0) } ?? "Measured device"
                card.setTitle("\(profile.name)\n\(profile.role)\n\(distance)",for:.normal)
                card.accessibilityLabel="\(profile.name), \(profile.role), \(distance). Open profile."
                // Bottom centre remains at the measured projected point. Never clamp a card
                // onto the edge, as doing so would imply an unmeasured location.
                card.frame=CGRect(x:CGFloat(point.x)-90,y:CGFloat(point.y)-84,width:180,height:84)
                card.isHidden = !view.bounds.contains(card.frame)
            }
        }
    }
}
