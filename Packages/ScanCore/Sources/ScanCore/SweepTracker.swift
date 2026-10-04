import Foundation

/// Tracks which part of the 180° arc in front of the patient the scanner has covered.
public struct SweepTracker: Equatable, Sendable {
    public static let binCount = 18
    public static let binWidthDegrees = 180.0 / Double(binCount)
    public static let usableDistance: ClosedRange<Float> = 0.25...1.2
    /// The protocol asks for 40–60 cm.
    public static let recommendedDistance: ClosedRange<Float> = 0.40...0.60

    /// Capture body frame: origin on the chest, +Z toward where the scanner stood at start.
    public let frame: RigidFrame
    public private(set) var bins: [Bool]

    public init(frame: RigidFrame) {
        self.frame = frame
        bins = Array(repeating: false, count: Self.binCount)
    }

    /// 0° in front of the patient, −90° at the patient's right side, +90° at their left.
    public func azimuthDegrees(of cameraPosition: Vec3) -> Double {
        let p = frame.toLocal(cameraPosition)
        return atan2(Double(p.x), Double(p.z)) * 180 / Double.pi
    }

    public func distance(of cameraPosition: Vec3) -> Float {
        frame.toLocal(cameraPosition).length
    }

    public static func bin(forAzimuth degrees: Double) -> Int? {
        guard degrees >= -90, degrees <= 90 else { return nil }
        return min(binCount - 1, Int((degrees + 90) / binWidthDegrees))
    }

    /// Marks the bin the camera is in. Returns it, or nil when out of range.
    @discardableResult
    public mutating func record(cameraPosition: Vec3) -> Int? {
        guard Self.usableDistance.contains(distance(of: cameraPosition)),
              let bin = Self.bin(forAzimuth: azimuthDegrees(of: cameraPosition))
        else { return nil }
        bins[bin] = true
        return bin
    }

    public var coverage: Double {
        Double(bins.filter { $0 }.count) / Double(Self.binCount)
    }
}
