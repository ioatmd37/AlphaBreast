import Foundation

/// An orthonormal, right-handed coordinate frame expressed in its parent's coordinates.
public struct RigidFrame: Equatable, Sendable {
    public var origin: Vec3
    public var xAxis: Vec3
    public var yAxis: Vec3
    public var zAxis: Vec3

    public init(origin: Vec3, xAxis: Vec3, yAxis: Vec3, zAxis: Vec3) {
        self.origin = origin
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.zAxis = zAxis
    }

    public static let identity = RigidFrame(
        origin: .zero,
        xAxis: Vec3(1, 0, 0),
        yAxis: Vec3(0, 1, 0),
        zAxis: Vec3(0, 0, 1)
    )

    /// Y along `up`, Z along the part of `zToward` perpendicular to `up`, X = Y × Z.
    public static func make(origin: Vec3, up: Vec3, zToward: Vec3) -> RigidFrame? {
        let y = up.normalized
        let zRaw = zToward - y * zToward.dot(y)
        guard y.length > 0.5, zRaw.length > 1e-6 else { return nil }
        let z = zRaw.normalized
        return RigidFrame(origin: origin, xAxis: y.cross(z), yAxis: y, zAxis: z)
    }

    /// Y along `up`, X along the part of `xToward` perpendicular to `up`, Z = X × Y.
    public static func make(origin: Vec3, up: Vec3, xToward: Vec3) -> RigidFrame? {
        let y = up.normalized
        let xRaw = xToward - y * xToward.dot(y)
        guard y.length > 0.5, xRaw.length > 1e-6 else { return nil }
        let x = xRaw.normalized
        return RigidFrame(origin: origin, xAxis: x, yAxis: y, zAxis: x.cross(y))
    }

    /// Parent coordinates → this frame.
    public func toLocal(_ point: Vec3) -> Vec3 {
        let d = point - origin
        return Vec3(d.dot(xAxis), d.dot(yAxis), d.dot(zAxis))
    }

    /// This frame → parent coordinates.
    public func toParent(_ point: Vec3) -> Vec3 {
        origin + xAxis * point.x + yAxis * point.y + zAxis * point.z
    }
}
