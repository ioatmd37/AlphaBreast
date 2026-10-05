import XCTest
@testable import ScanCore

final class LandmarkTests: XCTestCase {
    func testKeysMatchWebAlpha() {
        XCTAssertEqual(LandmarkKey.allCases.map(\.rawValue), ["sn", "nR", "nL", "imfR", "imfL", "medR", "latR", "medL", "latL"])
        XCTAssertEqual(ReferenceKey.allCases.map(\.rawValue), ["xiphoid", "acromionR", "acromionL", "scaleA", "scaleB"])
    }

    func testMarkerRequirements() {
        XCTAssertEqual(LandmarkKey.allCases.filter { !$0.needsMarker }, [.nR, .nL])
    }

    func testPlacementOrderAndCompletion() {
        var set = LandmarkSet()
        XCTAssertEqual(set.nextUnplaced(), .landmark(.sn))
        for key in LandmarkKey.allCases {
            XCTAssertFalse(set.isComplete)
            set[.landmark(key)] = .zero
        }
        XCTAssertTrue(set.isComplete)
        XCTAssertEqual(set.nextUnplaced(), .reference(.xiphoid))
        set[.landmark(.imfL)] = nil
        XCTAssertEqual(set.missingRequired, [.imfL])
        XCTAssertEqual(set.nextUnplaced(), .landmark(.imfL))
    }

    func testMeasurementsFromSpecExample() {
        let m = Measurements(specLandmarks)
        XCTAssertEqual(m.value("snNR")!, 0.21823, accuracy: 1e-4)
        XCTAssertEqual(m.value("snNL")!, 0.21823, accuracy: 1e-4)
        XCTAssertEqual(m.value("baseWidthR")!, 0.12042, accuracy: 1e-4)
        XCTAssertEqual(m.value("nImfR")!, 0.065, accuracy: 1e-4)
        XCTAssertEqual(m.value("nN")!, 0.16, accuracy: 1e-4)
        XCTAssertEqual(m.value("intermammary")!, 0.04, accuracy: 1e-4)
        XCTAssertEqual(m.scaleCheck?.measuredMeters ?? 0, 0.1, accuracy: 1e-5)
        XCTAssertEqual(m.scaleCheck?.isWithinTolerance, true)
    }

    func testMeasurementMissingPoint() {
        var set = specLandmarks
        set.landmarks[.latL] = nil
        set.references[.scaleB] = nil
        let m = Measurements(set)
        XCTAssertNil(m.value("baseWidthL"))
        XCTAssertNotNil(m.value("baseWidthR"))
        XCTAssertNil(m.scaleCheck)
    }

    func testSpecExampleHasNoWarnings() {
        XCTAssertEqual(LandmarkWarning.check(specLandmarks), [])
    }

    func testWarningsCatchSwapsAndScale() {
        var set = specLandmarks
        let nR = set.landmarks[.nR], nL = set.landmarks[.nL]
        set.landmarks[.nR] = nL
        set.landmarks[.nL] = nR
        let medL = set.landmarks[.medL], latL = set.landmarks[.latL]
        set.landmarks[.medL] = latL
        set.landmarks[.latL] = medL
        set.landmarks[.imfR] = Vec3(-0.08, 0.05, 0.06)
        set.references[.scaleB] = Vec3(0.054, -0.180, 0.050)
        let warnings = LandmarkWarning.check(set)
        XCTAssertTrue(warnings.contains(.sidesSwapped))
        XCTAssertTrue(warnings.contains(.medialLateralSwapped(.left)))
        XCTAssertTrue(warnings.contains(.imfAboveNipple(.right)))
        XCTAssertTrue(warnings.contains { if case .scaleOutOfTolerance = $0 { return true } else { return false } })
        XCTAssertFalse(warnings.contains(.sternalNotchBelowNipples))
    }

    func testScaleToleranceBoundary() {
        XCTAssertTrue(ScaleCheck(measuredMeters: 0.1029).isWithinTolerance)
        XCTAssertFalse(ScaleCheck(measuredMeters: 0.0965).isWithinTolerance)
    }
}
