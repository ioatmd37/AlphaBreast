import ARKit
import Foundation
import RealityKit
import ScanCore

/// Scan output in the capture body frame: origin on the front of the chest where the
/// reticle was aimed, +Y up (gravity), +Z toward where the scanner stood, +X patient's left.
struct CaptureResult {
    let mesh: TriangleMesh
    let capturedAt: Date
    let duration: TimeInterval
}

/// Approach A in the spec: ARKit scene reconstruction, merging every `ARMeshAnchor`.
@MainActor
@Observable
final class CaptureController: NSObject {
    enum Phase {
        case aiming, scanning, finishing
    }

    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    @ObservationIgnored let arView: ARView

    private(set) var phase: Phase = .aiming
    private(set) var trackingMessage: String?
    /// Aiming: depth at the reticle. Scanning: distance to the capture origin.
    private(set) var distance: Float?
    private(set) var elapsed: TimeInterval = 0
    private(set) var bins = [Bool](repeating: false, count: SweepTracker.binCount)
    private(set) var currentBin: Int?
    var errorMessage: String?

    var coverage: Double {
        Double(bins.filter { $0 }.count) / Double(bins.count)
    }

    @ObservationIgnored private var tracker: SweepTracker?
    @ObservationIgnored private var scanStart: Date?
    @ObservationIgnored private var lastUpdate: TimeInterval = 0

    override init() {
        arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        super.init()
        arView.session.delegate = self
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.renderOptions.insert(.disableMotionBlur)
    }

    func start() {
        guard Self.isSupported else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.worldAlignment = .gravity
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        phase = .aiming
        tracker = nil
        scanStart = nil
        bins = Array(repeating: false, count: SweepTracker.binCount)
        currentBin = nil
        elapsed = 0
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        arView.session.pause()
    }

    /// Fixes the capture frame from the current camera pose and the depth at the reticle.
    func beginScan() {
        guard let frame = arView.session.currentFrame else {
            errorMessage = "กล้องยังไม่พร้อม ลองอีกครั้ง"
            return
        }
        let camera = frame.camera.transform
        let position = Vec3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        let forward = -Vec3(camera.columns.2.x, camera.columns.2.y, camera.columns.2.z)
        let depth = DepthSampler.centerDepth(of: frame) ?? 0.5
        let center = position + forward * depth
        guard let bodyFrame = RigidFrame.make(origin: center, up: Vec3(0, 1, 0), zToward: position - center) else {
            errorMessage = "ถือเครื่องให้ตั้งตรง หันเข้าหาหน้าอกผู้ป่วย"
            return
        }
        tracker = SweepTracker(frame: bodyFrame)
        scanStart = Date()
        phase = .scanning
    }

    /// Collects the reconstructed mesh, stops the session and moves it into the body frame.
    func finishScan() async -> CaptureResult? {
        guard let tracker, let scanStart, let frame = arView.session.currentFrame else { return nil }
        phase = .finishing
        let chunks = frame.anchors.compactMap { ($0 as? ARMeshAnchor)?.worldMesh() }
        arView.session.pause()
        let bodyFrame = tracker.frame
        let mesh = await Task.detached(priority: .userInitiated) {
            TriangleMesh.merged(chunks)
                .transformed(by: bodyFrame.toLocal)
                .cropped(to: .captureLimit)
                .welded(tolerance: 0.001)
        }.value
        guard !mesh.isEmpty else {
            errorMessage = "ไม่ได้ผิวจากการสแกน ลองสแกนใหม่"
            start()
            return nil
        }
        return CaptureResult(mesh: mesh, capturedAt: scanStart, duration: Date().timeIntervalSince(scanStart))
    }

    private func handle(_ frame: ARFrame) {
        guard frame.timestamp - lastUpdate > 0.1 else { return }
        lastUpdate = frame.timestamp
        let camera = frame.camera.transform
        let position = Vec3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        switch phase {
        case .aiming:
            distance = DepthSampler.centerDepth(of: frame)
        case .scanning:
            guard var tracker, let scanStart else { return }
            currentBin = tracker.record(cameraPosition: position)
            self.tracker = tracker
            if bins != tracker.bins { bins = tracker.bins }
            distance = tracker.distance(of: position)
            elapsed = Date().timeIntervalSince(scanStart)
        case .finishing:
            break
        }
    }

    private static func message(for state: ARCamera.TrackingState) -> String? {
        switch state {
        case .normal:
            return nil
        case .notAvailable:
            return "ระบบติดตามตำแหน่งไม่พร้อม"
        case .limited(let reason):
            switch reason {
            case .initializing: return "กำลังเริ่มระบบ ขยับเครื่องช้า ๆ"
            case .excessiveMotion: return "ขยับเร็วเกินไป เดินให้ช้าลง"
            case .insufficientFeatures: return "ภาพมีรายละเอียดน้อย เพิ่มแสงหรือหันให้เห็นฉากมากขึ้น"
            case .relocalizing: return "กำลังหาตำแหน่งใหม่"
            @unknown default: return "การติดตามตำแหน่งจำกัด"
            }
        }
    }
}

extension CaptureController: ARSessionDelegate {
    // The session delivers on the main queue (no delegateQueue set).
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        MainActor.assumeIsolated {
            self.handle(frame)
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        MainActor.assumeIsolated {
            self.trackingMessage = Self.message(for: state)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            self.errorMessage = message
        }
    }
}
