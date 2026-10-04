import Foundation

/// The landmark file (`.json`) that goes with the exported model. Coordinates share the
/// model's frame and are in metres. Never put patient-identifying data in here.
public struct ScanDocument: Equatable, Sendable {
    public static let schema = "alphabreast-scan/1"
    public static let arkitMethod = "arkit-scene-reconstruction"

    public var capturedAt: Date
    public var timeZone: TimeZone
    public var device: String
    public var method: String
    /// When the patient gave consent. A time only, never who.
    public var consentAt: Date?
    public var landmarks: LandmarkSet

    public init(
        capturedAt: Date,
        timeZone: TimeZone = .current,
        device: String,
        method: String = ScanDocument.arkitMethod,
        consentAt: Date? = nil,
        landmarks: LandmarkSet
    ) {
        self.capturedAt = capturedAt
        self.timeZone = timeZone
        self.device = device
        self.method = method
        self.consentAt = consentAt
        self.landmarks = landmarks
    }

    /// Pretty-printed JSON with keys in spec order and coordinates rounded to 0.1 mm.
    public func jsonData() -> Data {
        var lines: [String] = []
        lines.append("{")
        var fields: [String] = [
            "  \"schema\": \(Self.quoted(Self.schema))",
            "  \"capturedAt\": \(Self.quoted(Self.timestamp(capturedAt, timeZone: timeZone)))",
            "  \"units\": \"m\"",
            "  \"device\": \(Self.quoted(device))",
            "  \"method\": \(Self.quoted(method))",
        ]
        if let consentAt {
            fields.append("  \"consentAt\": \(Self.quoted(Self.timestamp(consentAt, timeZone: timeZone)))")
        }
        let landmarkPairs = LandmarkKey.allCases.compactMap { key in
            landmarks.landmarks[key].map { (key.rawValue, $0) }
        }
        fields.append("  \"landmarks\": " + Self.pointObject(landmarkPairs))
        let referencePairs = ReferenceKey.allCases.compactMap { key in
            landmarks.references[key].map { (key.rawValue, $0) }
        }
        if !referencePairs.isEmpty {
            fields.append("  \"references\": " + Self.pointObject(referencePairs))
        }
        lines.append(fields.joined(separator: ",\n"))
        lines.append("}")
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    public enum DecodingError: Error, Equatable {
        case wrongSchema(String)
        case badTimestamp(String)
        case badPoint(String)
    }

    public static func decode(_ data: Data) throws -> ScanDocument {
        struct Raw: Decodable {
            var schema: String
            var capturedAt: String
            var device: String
            var method: String
            var consentAt: String?
            var landmarks: [String: [Double]]
            var references: [String: [Double]]?
        }
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        guard raw.schema == schema else { throw DecodingError.wrongSchema(raw.schema) }
        guard let captured = parseTimestamp(raw.capturedAt) else { throw DecodingError.badTimestamp(raw.capturedAt) }
        var consent: Date?
        if let c = raw.consentAt {
            guard let parsed = parseTimestamp(c) else { throw DecodingError.badTimestamp(c) }
            consent = parsed
        }
        func point(_ name: String, _ values: [Double]) throws -> Vec3 {
            guard values.count == 3 else { throw DecodingError.badPoint(name) }
            return Vec3(Float(values[0]), Float(values[1]), Float(values[2]))
        }
        var set = LandmarkSet()
        for (name, values) in raw.landmarks {
            if let key = LandmarkKey(rawValue: name) { set.landmarks[key] = try point(name, values) }
        }
        for (name, values) in raw.references ?? [:] {
            if let key = ReferenceKey(rawValue: name) { set.references[key] = try point(name, values) }
        }
        return ScanDocument(
            capturedAt: captured,
            timeZone: timeZone(of: raw.capturedAt) ?? .current,
            device: raw.device,
            method: raw.method,
            consentAt: consent,
            landmarks: set
        )
    }

    // MARK: - Formatting

    /// `2026-10-04T15:30:00+07:00`
    public static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    static func parseTimestamp(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    static func timeZone(of string: String) -> TimeZone? {
        if string.hasSuffix("Z") { return TimeZone(secondsFromGMT: 0) }
        let suffix = string.suffix(6)
        guard suffix.count == 6, let sign = suffix.first, sign == "+" || sign == "-" else { return nil }
        let parts = suffix.dropFirst().split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return TimeZone(secondsFromGMT: (sign == "-" ? -1 : 1) * (h * 3600 + m * 60))
    }

    static func number(_ value: Float) -> String {
        let rounded = (Double(value) * 10_000).rounded() / 10_000
        return String(format: "%.4f", rounded == 0 ? 0 : rounded)
    }

    static func pointObject(_ pairs: [(String, Vec3)]) -> String {
        guard !pairs.isEmpty else { return "{}" }
        let width = pairs.map { $0.0.count }.max() ?? 0
        let body = pairs.map { name, p in
            let key = quoted(name) + ":" + String(repeating: " ", count: width - name.count + 1)
            return "    " + key + "[\(number(p.x)), \(number(p.y)), \(number(p.z))]"
        }
        return "{\n" + body.joined(separator: ",\n") + "\n  }"
    }

    static func quoted(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}
