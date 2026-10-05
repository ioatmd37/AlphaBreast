import Foundation

public struct MeasurementItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    /// Straight-line distance in metres, or nil while a point is missing.
    public let meters: Double?
}

public struct ScaleCheck: Equatable, Sendable {
    public static let expectedMeters = 0.100
    public static let toleranceMeters = 0.003

    public let measuredMeters: Double

    public var deviationMeters: Double { measuredMeters - Self.expectedMeters }
    public var isWithinTolerance: Bool { abs(deviationMeters) <= Self.toleranceMeters }
}

/// Distances between landmarks. All are straight lines, not along the skin, and N–IMF is
/// the resting value (the web calculator wants the value under stretch).
public struct Measurements: Equatable, Sendable {
    public let items: [MeasurementItem]
    public let scaleCheck: ScaleCheck?

    public init(_ set: LandmarkSet) {
        func d(_ a: LandmarkKey, _ b: LandmarkKey) -> Double? {
            guard let p = set.landmarks[a], let q = set.landmarks[b] else { return nil }
            return Double(p.distance(to: q))
        }
        items = [
            MeasurementItem(id: "snNR", title: "SN–N ขวา", meters: d(.sn, .nR)),
            MeasurementItem(id: "snNL", title: "SN–N ซ้าย", meters: d(.sn, .nL)),
            MeasurementItem(id: "baseWidthR", title: "Base width ขวา", meters: d(.medR, .latR)),
            MeasurementItem(id: "baseWidthL", title: "Base width ซ้าย", meters: d(.medL, .latL)),
            MeasurementItem(id: "nImfR", title: "N–IMF ขวา (ขณะพัก)", meters: d(.nR, .imfR)),
            MeasurementItem(id: "nImfL", title: "N–IMF ซ้าย (ขณะพัก)", meters: d(.nL, .imfL)),
            MeasurementItem(id: "nN", title: "NAC ถึง NAC", meters: d(.nR, .nL)),
            MeasurementItem(id: "intermammary", title: "Intermammary distance", meters: d(.medR, .medL)),
        ]
        if let a = set.references[.scaleA], let b = set.references[.scaleB] {
            scaleCheck = ScaleCheck(measuredMeters: Double(a.distance(to: b)))
        } else {
            scaleCheck = nil
        }
    }

    public func value(_ id: String) -> Double? {
        items.first { $0.id == id }?.meters
    }
}

public enum Side: String, Sendable {
    case right, left

    var thai: String { self == .right ? "ขวา" : "ซ้าย" }
}

/// Plausibility checks on landmarks in the capture body frame
/// (+X toward the patient's left, +Y up, +Z anterior).
public enum LandmarkWarning: Equatable, Sendable, Identifiable {
    case sidesSwapped
    case sternalNotchBelowNipples
    case imfAboveNipple(Side)
    case medialLateralSwapped(Side)
    case scaleOutOfTolerance(deviationMeters: Double)

    public var id: String {
        switch self {
        case .sidesSwapped: return "sidesSwapped"
        case .sternalNotchBelowNipples: return "snBelowN"
        case .imfAboveNipple(let s): return "imfAboveN-\(s.rawValue)"
        case .medialLateralSwapped(let s): return "medLat-\(s.rawValue)"
        case .scaleOutOfTolerance: return "scale"
        }
    }

    public var message: String {
        switch self {
        case .sidesSwapped:
            return "NAC ขวาอยู่ทางซ้ายของผู้ป่วย อาจจุดสลับข้าง (ขวา–ซ้ายหมายถึงของผู้ป่วย)"
        case .sternalNotchBelowNipples:
            return "Sternal notch อยู่ต่ำกว่า NAC ตรวจตำแหน่ง sn"
        case .imfAboveNipple(let s):
            return "IMF \(s.thai) อยู่สูงกว่า NAC \(s.thai)"
        case .medialLateralSwapped(let s):
            return "ขอบในและขอบนอกเต้า\(s.thai) อาจสลับกัน"
        case .scaleOutOfTolerance(let deviation):
            let mm = deviation * 1000
            return String(format: "ระยะ scale marker ต่างจาก 10.0 cm %+.1f mm (เกิน 3 mm) ตรวจมาตราส่วน", mm)
        }
    }

    public static func check(_ set: LandmarkSet) -> [LandmarkWarning] {
        var warnings: [LandmarkWarning] = []
        let l = set.landmarks
        if let nR = l[.nR], let nL = l[.nL] {
            if nR.x > nL.x { warnings.append(.sidesSwapped) }
            if let sn = l[.sn], sn.y < max(nR.y, nL.y) { warnings.append(.sternalNotchBelowNipples) }
        }
        if let n = l[.nR], let imf = l[.imfR], imf.y > n.y { warnings.append(.imfAboveNipple(.right)) }
        if let n = l[.nL], let imf = l[.imfL], imf.y > n.y { warnings.append(.imfAboveNipple(.left)) }
        if let med = l[.medR], let lat = l[.latR], lat.x > med.x { warnings.append(.medialLateralSwapped(.right)) }
        if let med = l[.medL], let lat = l[.latL], lat.x < med.x { warnings.append(.medialLateralSwapped(.left)) }
        if let scale = Measurements(set).scaleCheck, !scale.isWithinTolerance {
            warnings.append(.scaleOutOfTolerance(deviationMeters: scale.deviationMeters))
        }
        return warnings
    }
}
