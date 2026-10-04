import XCTest
@testable import ScanCore

final class SweepTrackerTests: XCTestCase {
    func testAzimuthSignsFollowPatientSides() throws {
        let frame = try XCTUnwrap(RigidFrame.make(origin: .zero, up: Vec3(0, 1, 0), zToward: Vec3(0, 0, 1)))
        let tracker = SweepTracker(frame: frame)
        XCTAssertEqual(tracker.azimuthDegrees(of: Vec3(0, 0, 0.5)), 0, accuracy: 1e-6)
        XCTAssertEqual(tracker.azimuthDegrees(of: Vec3(0.5, 0, 0)), 90, accuracy: 1e-6) // patient's left
        XCTAssertEqual(tracker.azimuthDegrees(of: Vec3(-0.5, 0, 0)), -90, accuracy: 1e-6) // patient's right
    }

    func testFullSweepCoversEveryBin() throws {
        let frame = try XCTUnwrap(RigidFrame.make(origin: Vec3(0, 1.3, 0), up: Vec3(0, 1, 0), zToward: Vec3(0, 0, 1)))
        var tracker = SweepTracker(frame: frame)
        XCTAssertEqual(tracker.coverage, 0)
        for step in 0...180 {
            let a = (Double(step) - 90) * Double.pi / 180
            let p = Vec3(Float(sin(a)) * 0.5, 1.4, Float(cos(a)) * 0.5)
            tracker.record(cameraPosition: p)
        }
        XCTAssertEqual(tracker.coverage, 1)
    }

    func testOutOfRangePositionsAreIgnored() throws {
        let frame = try XCTUnwrap(RigidFrame.make(origin: .zero, up: Vec3(0, 1, 0), zToward: Vec3(0, 0, 1)))
        var tracker = SweepTracker(frame: frame)
        XCTAssertNil(tracker.record(cameraPosition: Vec3(0, 0, 3)))   // too far
        XCTAssertNil(tracker.record(cameraPosition: Vec3(0, 0, -0.5))) // behind the patient
        XCTAssertEqual(tracker.record(cameraPosition: Vec3(0, 0, 0.5)), 9)
        XCTAssertEqual(SweepTracker.bin(forAzimuth: -90), 0)
        XCTAssertEqual(SweepTracker.bin(forAzimuth: 90), 17)
    }
}
