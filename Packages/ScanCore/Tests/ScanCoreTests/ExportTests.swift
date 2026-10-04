import XCTest
@testable import ScanCore

final class ExportTests: XCTestCase {
    let bangkok = TimeZone(secondsFromGMT: 7 * 3600)!
    // 2026-10-04 15:30:00 +07:00
    let captured = Date(timeIntervalSince1970: 1_791_102_600)

    func testTimestampAndBaseName() {
        XCTAssertEqual(ScanDocument.timestamp(captured, timeZone: bangkok), "2026-10-04T15:30:00+07:00")
        XCTAssertEqual(ExportNaming.baseName(for: captured, timeZone: bangkok), "scan-20261004-1530")
    }

    func testJSONMatchesSpecShape() throws {
        let doc = ScanDocument(capturedAt: captured, timeZone: bangkok, device: "iPhone 16 Pro", landmarks: specLandmarks)
        let text = String(decoding: doc.jsonData(), as: UTF8.self)
        XCTAssertTrue(text.contains("\"schema\": \"alphabreast-scan/1\""))
        XCTAssertTrue(text.contains("\"capturedAt\": \"2026-10-04T15:30:00+07:00\""))
        XCTAssertTrue(text.contains("\"units\": \"m\""))
        XCTAssertTrue(text.contains("\"method\": \"arkit-scene-reconstruction\""))
        XCTAssertTrue(text.contains("\"nR\":   [-0.0800, 0.0000, 0.0850]"))
        XCTAssertFalse(text.contains("consentAt"))
        XCTAssertFalse(text.contains("acromion"))
        let snRange = try XCTUnwrap(text.range(of: "\"sn\""))
        let latLRange = try XCTUnwrap(text.range(of: "\"latL\""))
        XCTAssertLessThan(snRange.lowerBound, latLRange.lowerBound)

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: doc.jsonData()) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schema", "capturedAt", "units", "device", "method", "landmarks", "references"])
        let landmarks = try XCTUnwrap(object["landmarks"] as? [String: Any])
        XCTAssertEqual(Set(landmarks.keys), Set(LandmarkKey.allCases.map(\.rawValue)))
    }

    func testJSONRoundTrip() throws {
        let consent = captured.addingTimeInterval(-300)
        let doc = ScanDocument(capturedAt: captured, timeZone: bangkok, device: "iPad \"Pro\"\n", consentAt: consent, landmarks: specLandmarks)
        let decoded = try ScanDocument.decode(doc.jsonData())
        XCTAssertEqual(decoded.capturedAt, captured)
        XCTAssertEqual(decoded.consentAt, consent)
        XCTAssertEqual(decoded.device, "iPad \"Pro\"\n")
        XCTAssertEqual(decoded.timeZone.secondsFromGMT(), 7 * 3600)
        for key in LandmarkKey.allCases {
            XCTAssertTrue(isClose(decoded.landmarks.landmarks[key]!, specLandmarks.landmarks[key]!, accuracy: 1e-4), key.rawValue)
        }
        XCTAssertEqual(decoded.landmarks.references.count, 3)
    }

    func testDecodeRejectsOtherSchema() {
        let data = Data(#"{"schema":"other/2","capturedAt":"2026-10-04T15:30:00Z","units":"m","device":"x","method":"y","landmarks":{}}"#.utf8)
        XCTAssertThrowsError(try ScanDocument.decode(data)) { error in
            XCTAssertEqual(error as? ScanDocument.DecodingError, .wrongSchema("other/2"))
        }
    }

    func testOBJWriter() {
        let mesh = grid(n: 2, size: 1)
        let text = String(decoding: OBJWriter.data(for: mesh), as: UTF8.self)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.filter { $0.hasPrefix("v ") }.count, 9)
        XCTAssertEqual(lines.filter { $0.hasPrefix("vn ") }.count, 9)
        XCTAssertEqual(lines.filter { $0.hasPrefix("f ") }.count, 8)
        XCTAssertTrue(lines.contains("v -0.50000 -0.50000 0.00000"))
        XCTAssertTrue(lines.contains("f 1//1 2//2 5//5"))
    }

    func testPLYWriter() {
        let mesh = grid(n: 2, size: 1)
        let text = String(decoding: PLYWriter.data(for: mesh), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("ply\nformat ascii 1.0\n"))
        XCTAssertTrue(text.contains("element vertex 9\n"))
        XCTAssertTrue(text.contains("element face 8\n"))
        let body = text.components(separatedBy: "end_header\n")[1].split(separator: "\n")
        XCTAssertEqual(body.count, 17)
        XCTAssertEqual(body[9], "3 0 1 4")
    }

    func testRetention() {
        let now = Date()
        XCTAssertFalse(RetentionPolicy.isExpired(createdAt: now.addingTimeInterval(-23 * 3600), now: now))
        XCTAssertTrue(RetentionPolicy.isExpired(createdAt: now.addingTimeInterval(-25 * 3600), now: now))
    }
}
