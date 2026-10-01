import RealityKit
import UIKit

enum ProfileCardEntity {
    static func make(name:String) -> Entity {
        let entity = Entity()
        let plate = ModelEntity(mesh:.generatePlane(width:0.36,depth:0.15),materials:[UnlitMaterial(color:UIColor(red:0.08,green:0.12,blue:0.10,alpha:1))])
        plate.orientation = simd_quatf(angle:.pi / 2,axis:[1,0,0]);entity.addChild(plate)
        let mesh = MeshResource.generateText(String(name.prefix(24)),extrusionDepth:0.001,font:.systemFont(ofSize:0.025,weight:.semibold),containerFrame:.zero,alignment:.center,lineBreakMode:.byTruncatingTail)
        let label = ModelEntity(mesh:mesh,materials:[UnlitMaterial(color:UIColor(red:0.81,green:1,blue:0.45,alpha:1))])
        label.position = [-0.15,-0.005,0.003];entity.addChild(label)
        return entity
    }
}
