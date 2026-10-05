import XCTest
@testable import ScanCore

final class GeometryTests: XCTestCase {
    func testFrameFromForwardIsRightHandedAndOrthonormal() throws {
        let frame = try XCTUnwrap(RigidFrame.make(origin: Vec3(1, 2, 3), up: Vec3(0, 2, 0), zToward: Vec3(1, 0.5, 1)))
        XCTAssertEqual(frame.xAxis.length, 1, accuracy: 1e-5)
        XCTAssertEqual(frame.yAxis.length, 1, accuracy: 1e-5)
        XCTAssertEqual(frame.zAxis.length, 1, accuracy: 1e-5)
        XCTAssertEqual(frame.xAxis.dot(frame.yAxis), 0, accuracy: 1e-5)
        XCTAssertEqual(frame.yAxis.dot(frame.zAxis), 0, accuracy: 1e-5)
        XCTAssertTrue(isClose(frame.xAxis.cross(frame.yAxis), frame.zAxis))
        XCTAssertTrue(isClose(frame.yAxis, Vec3(0, 1, 0)))
    }

    func testFrameRoundTrip() throws {
        let frame = try XCTUnwrap(RigidFrame.make(origin: Vec3(0.3, -1, 2), up: Vec3(0, 1, 0), xToward: Vec3(1, 0, -1)))
        let p = Vec3(0.12, -0.4, 0.9)
        XCTAssertTrue(isClose(frame.toParent(frame.toLocal(p)), p))
        XCTAssertTrue(isClose(frame.xAxis.cross(frame.yAxis), frame.zAxis))
    }

    func testFrameRejectsDegenerateDirection() {
        XCTAssertNil(RigidFrame.make(origin: .zero, up: Vec3(0, 1, 0), zToward: Vec3(0, -3, 0)))
        XCTAssertNil(RigidFrame.make(origin: .zero, up: Vec3(0, 1, 0), xToward: Vec3(0, 1, 0)))
    }

    func testCaptureFrameMakesPatientLeftPositiveX() throws {
        // Scanner stands at +Z (in front). The patient's left is the scanner's right: world +X.
        let frame = try XCTUnwrap(RigidFrame.make(origin: .zero, up: Vec3(0, 1, 0), zToward: Vec3(0, 0, 1)))
        XCTAssertTrue(isClose(frame.xAxis, Vec3(1, 0, 0)))
    }

    func testBodyAlignmentPutsNipplesOnXAxis() throws {
        // Spec landmarks rotated 30° about Y and shifted, as if captured off-axis.
        let angle: Float = .pi / 6
        let rotate = { (p: Vec3) -> Vec3 in
            Vec3(p.x * cos(angle) + p.z * sin(angle), p.y, -p.x * sin(angle) + p.z * cos(angle)) + Vec3(0.5, 1.2, -0.3)
        }
        let captured = specLandmarks.transformed(by: rotate)
        let (_, aligned) = BodyAlignment.align(mesh: TriangleMesh(), landmarks: captured)
        let nR = try XCTUnwrap(aligned.landmarks[.nR])
        let nL = try XCTUnwrap(aligned.landmarks[.nL])
        XCTAssertEqual(nR.x, -0.08, accuracy: 1e-4)
        XCTAssertEqual(nL.x, 0.08, accuracy: 1e-4)
        XCTAssertEqual(nR.y, 0, accuracy: 1e-4)
        // Origin depth at the medial borders (z = 0.05 in the spec frame).
        XCTAssertEqual(nR.z, 0.035, accuracy: 1e-4)
        let sn = try XCTUnwrap(aligned.landmarks[.sn])
        XCTAssertEqual(sn.y, 0.2, accuracy: 1e-4)
        XCTAssertEqual(sn.z, 0, accuracy: 1e-4)
        // Distances survive the rigid transform.
        XCTAssertEqual(Measurements(aligned).value("snNR")!, Measurements(specLandmarks).value("snNR")!, accuracy: 1e-5)
    }

    func testBodyAlignmentWithoutNipplesIsNoOp() {
        let set = LandmarkSet(landmarks: [.sn: Vec3(1, 2, 3)])
        let mesh = grid(n: 2, size: 1)
        let result = BodyAlignment.align(mesh: mesh, landmarks: set)
        XCTAssertEqual(result.mesh, mesh)
        XCTAssertEqual(result.landmarks, set)
    }
}
