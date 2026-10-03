import Foundation
import simd

/// Pure projection rules shared by the renderer and executable regression tests.
enum SpatialProjection {
    static func isFresh(measuredAt:TimeInterval,now:TimeInterval) -> Bool {
        measuredAt.isFinite && now.isFinite && now >= measuredAt && now-measuredAt <= 1.5
    }
    static func isFinite(_ matrix:simd_float4x4) -> Bool {
        (0..<4).allSatisfy { column in (0..<4).allSatisfy { row in matrix[column][row].isFinite } }
    }
    static func point(transform:simd_float4x4,view:simd_float4x4,projection:simd_float4x4,viewport:SIMD2<Float>,measuredAt:TimeInterval,now:TimeInterval,tracking:Bool) -> SIMD2<Float>? {
        guard tracking,isFresh(measuredAt:measuredAt,now:now),isFinite(transform),isFinite(view),isFinite(projection),viewport.x.isFinite,viewport.y.isFinite,viewport.x>0,viewport.y>0 else { return nil }
        let camera=view*transform.columns.3
        guard camera.z < 0 else { return nil }
        let clip=projection*camera
        guard clip.w>0,clip.x.isFinite,clip.y.isFinite,clip.z.isFinite,clip.w.isFinite else { return nil }
        let normalized=SIMD3<Float>(clip.x,clip.y,clip.z)/clip.w
        guard abs(normalized.x)<=1,abs(normalized.y)<=1,abs(normalized.z)<=1 else { return nil }
        return SIMD2<Float>((normalized.x+1)*0.5*viewport.x,(1-normalized.y)*0.5*viewport.y)
    }
}
