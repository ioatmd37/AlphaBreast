import Foundation
import SwiftUI
import ScanCore

/// State for one patient at a time. Scan data lives in memory only; files are written just
/// long enough to hand them to the share sheet.
@MainActor
@Observable
final class AppModel {
    enum Stage {
        case guide, capture, review, landmarks, results
    }

    var stage: Stage = .guide
    private(set) var isUnlocked = false
    private(set) var alphaCodeAccepted = !AlphaCode.isRequired

    private(set) var consentAt: Date?
    private(set) var capture: CaptureResult?
    var cropBox: CropBox = .torsoDefault
    private(set) var torsoMesh: TriangleMesh?
    private(set) var torsoMeshID = UUID()
    private(set) var landmarks = LandmarkSet()
    private var landmarkHistory: [LandmarkSet] = []

    let storage = ScanStorage()

    init() {
        storage.purgeExpired()
    }

    // MARK: Lock

    func unlockSucceeded() {
        isUnlocked = true
        storage.purgeExpired()
    }

    func acceptAlphaCode() {
        alphaCodeAccepted = true
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            isUnlocked = false
        case .active:
            storage.purgeExpired()
        default:
            break
        }
    }

    // MARK: Flow

    func recordConsent() {
        consentAt = Date()
    }

    func finishCapture(_ result: CaptureResult) {
        capture = result
        cropBox = .torsoDefault
        torsoMesh = nil
        landmarks = LandmarkSet()
        landmarkHistory = []
        stage = .review
    }

    func rescan() {
        capture = nil
        torsoMesh = nil
        landmarks = LandmarkSet()
        landmarkHistory = []
        stage = .capture
    }

    func setTorsoMesh(_ mesh: TriangleMesh) {
        torsoMesh = mesh
        torsoMeshID = UUID()
    }

    /// Clears everything about the current patient, including any files left on disk.
    func startNewPatient() {
        consentAt = nil
        capture = nil
        cropBox = .torsoDefault
        torsoMesh = nil
        landmarks = LandmarkSet()
        landmarkHistory = []
        storage.removeAll()
        stage = .guide
    }

    // MARK: Landmarks

    func place(_ point: PointKey, at position: Vec3) {
        landmarkHistory.append(landmarks)
        landmarks[point] = position
    }

    func clear(_ point: PointKey) {
        guard landmarks[point] != nil else { return }
        landmarkHistory.append(landmarks)
        landmarks[point] = nil
    }

    var canUndo: Bool { !landmarkHistory.isEmpty }

    func undo() {
        if let previous = landmarkHistory.popLast() {
            landmarks = previous
        }
    }
}
