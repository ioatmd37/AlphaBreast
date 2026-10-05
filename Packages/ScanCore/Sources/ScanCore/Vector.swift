import Foundation

/// A point or direction in metres. Same memory layout as ARKit's `simd_float3`.
public typealias Vec3 = SIMD3<Float>

extension SIMD3 where Scalar == Float {
    public func dot(_ other: SIMD3<Float>) -> Float {
        (self * other).sum()
    }

    public func cross(_ other: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    public var length: Float {
        self.dot(self).squareRoot()
    }

    public var normalized: SIMD3<Float> {
        let l = length
        return l > 0 ? self / l : self
    }

    public func distance(to other: SIMD3<Float>) -> Float {
        (self - other).length
    }

    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}
