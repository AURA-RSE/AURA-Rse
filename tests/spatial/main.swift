import Foundation
import simd

var assertions=0
func check(_ value:Bool,_ message:String) { assertions += 1;if !value { fatalError(message) } }
let identity=matrix_identity_float4x4
let projection=simd_float4x4(SIMD4<Float>(1,0,0,0),SIMD4<Float>(0,1,0,0),SIMD4<Float>(0,0,-1,-1),SIMD4<Float>(0,0,-0.2,0))
func transform(_ x:Float=0,_ y:Float=0,_ z:Float = -2) -> simd_float4x4 {var result=identity;result.columns.3=SIMD4<Float>(x,y,z,1);return result}
func point(_ target:simd_float4x4=transform(),_ view:simd_float4x4=matrix_identity_float4x4,_ time:Double=10,_ tracking:Bool=true,_ viewport:SIMD2<Float>=SIMD2<Float>(200,400)) -> SIMD2<Float>? {SpatialProjection.point(transform:target,view:view,projection:projection,viewport:viewport,measuredAt:10,now:time,tracking:tracking)}
check(point()==SIMD2<Float>(100,200),"Forward device projects to the camera centre")
check(point(transform(1))==SIMD2<Float>(150,200),"A distinct peer has its own measured screen position")
check(point(transform(0,1))==SIMD2<Float>(100,100),"World up maps to screen up")
var shifted=identity;shifted.columns.3.x = -1
check(point(transform(),shifted)==SIMD2<Float>(50,200),"Moving the camera moves the projected card, not a fixed overlay")
let turned=simd_float4x4(simd_quatf(angle: .pi,axis:SIMD3<Float>(0,1,0)))
check(point(transform(),turned)==nil,"Turning away removes the peer from view")
check(point(transform(0,0,2))==nil,"Never show devices behind the camera")
check(point(transform(5))==nil,"Offscreen devices are hidden, not clamped to an edge")
check(point(transform(),identity,11.5) != nil,"Measurement allowed at freshness boundary")
check(point(transform(),identity,11.5001)==nil,"Old measurements cannot leave stale floating identities")
check(point(transform(),identity,9.9)==nil,"Future timestamps are rejected")
check(point(transform(),identity,10,false)==nil,"Tracking loss hides profiles immediately")
check(point(transform(),identity,10,true,SIMD2<Float>(0,400))==nil,"Zero viewport cannot produce a marker")
check(point(transform(.nan))==nil,"Non-finite measured coordinates are rejected")
check(point(transform(),identity,.nan)==nil,"Non-finite clock rejected")
var invalidProjection=projection;invalidProjection.columns.0.x = .infinity
check(SpatialProjection.point(transform:transform(),view:identity,projection:invalidProjection,viewport:SIMD2<Float>(200,400),measuredAt:10,now:10,tracking:true)==nil,"Invalid camera projection rejected")
print("PASS: \(assertions) measured-position projection assertions. Synthetic geometry; not physical UWB/AR evidence.")
