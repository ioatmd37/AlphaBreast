import Foundation

/// The nine required landmarks, in placement order. The raw values match the web alpha page
/// (`src/components/ScanAlpha.tsx`); do not rename one without changing both sides.
/// Right and left are the patient's.
public enum LandmarkKey: String, CaseIterable, Codable, Sendable {
    case sn, nR, nL, imfR, imfL, medR, latR, medL, latL

    public var title: String {
        switch self {
        case .sn: return "Sternal notch"
        case .nR: return "NAC ขวา"
        case .nL: return "NAC ซ้าย"
        case .imfR: return "IMF ขวา"
        case .imfL: return "IMF ซ้าย"
        case .medR: return "ขอบในเต้าขวา"
        case .latR: return "ขอบนอกเต้าขวา"
        case .medL: return "ขอบในเต้าซ้าย"
        case .latL: return "ขอบนอกเต้าซ้าย"
        }
    }

    public var detail: String {
        switch self {
        case .sn: return "รอยบุ๋มเหนือกระดูกอก"
        case .nR, .nL: return "กึ่งกลางหัวนม"
        case .imfR, .imfL: return "จุดต่ำสุดของรอยพับใต้ NAC"
        case .medR, .medL: return "ขอบในของเต้า ที่ระดับ NAC"
        case .latR, .latL: return "ขอบนอกของเต้า ที่ระดับ NAC"
        }
    }

    public var needsMarker: Bool {
        switch self {
        case .nR, .nL: return false
        default: return true
        }
    }
}

/// Optional reference points.
public enum ReferenceKey: String, CaseIterable, Codable, Sendable {
    case xiphoid, acromionR, acromionL, scaleA, scaleB

    public var title: String {
        switch self {
        case .xiphoid: return "Xiphoid"
        case .acromionR: return "Acromion ขวา"
        case .acromionL: return "Acromion ซ้าย"
        case .scaleA: return "Scale A"
        case .scaleB: return "Scale B"
        }
    }

    public var detail: String {
        switch self {
        case .xiphoid: return "ปลายล่างกระดูกอก"
        case .acromionR, .acromionL: return "ปุ่มหัวไหล่"
        case .scaleA, .scaleB: return "marker คู่ห่างกัน 10.0 cm บนหน้าท้อง"
        }
    }
}

/// Either kind of point, in the order the app asks for them.
public enum PointKey: Hashable, Sendable, Identifiable {
    case landmark(LandmarkKey)
    case reference(ReferenceKey)

    public static let placementOrder: [PointKey] =
        LandmarkKey.allCases.map(PointKey.landmark) + ReferenceKey.allCases.map(PointKey.reference)

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .landmark(let k): return k.rawValue
        case .reference(let k): return k.rawValue
        }
    }

    public var title: String {
        switch self {
        case .landmark(let k): return k.title
        case .reference(let k): return k.title
        }
    }

    public var detail: String {
        switch self {
        case .landmark(let k): return k.detail
        case .reference(let k): return k.detail
        }
    }

    public var isRequired: Bool {
        if case .landmark = self { return true }
        return false
    }

    public var needsMarker: Bool {
        switch self {
        case .landmark(let k): return k.needsMarker
        case .reference: return true
        }
    }
}

public struct LandmarkSet: Equatable, Sendable {
    public var landmarks: [LandmarkKey: Vec3]
    public var references: [ReferenceKey: Vec3]

    public init(landmarks: [LandmarkKey: Vec3] = [:], references: [ReferenceKey: Vec3] = [:]) {
        self.landmarks = landmarks
        self.references = references
    }

    public subscript(point: PointKey) -> Vec3? {
        get {
            switch point {
            case .landmark(let k): return landmarks[k]
            case .reference(let k): return references[k]
            }
        }
        set {
            switch point {
            case .landmark(let k): landmarks[k] = newValue
            case .reference(let k): references[k] = newValue
            }
        }
    }

    public var missingRequired: [LandmarkKey] {
        LandmarkKey.allCases.filter { landmarks[$0] == nil }
    }

    public var isComplete: Bool { missingRequired.isEmpty }

    /// The first point in placement order that has no position yet.
    public func nextUnplaced() -> PointKey? {
        PointKey.placementOrder.first { self[$0] == nil }
    }

    public func transformed(by transform: (Vec3) -> Vec3) -> LandmarkSet {
        LandmarkSet(
            landmarks: landmarks.mapValues(transform),
            references: references.mapValues(transform)
        )
    }
}
