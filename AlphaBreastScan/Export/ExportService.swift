import Foundation
import ScanCore

enum ModelFormat: String, CaseIterable, Identifiable {
    case obj, ply

    var id: String { rawValue }
    var title: String { "." + rawValue }
}

struct ExportInput: Sendable {
    let mesh: TriangleMesh
    let landmarks: LandmarkSet
    let capturedAt: Date
    let consentAt: Date?
    let format: ModelFormat
    let device: String
}

enum ExportService {
    struct Files: Sendable {
        let modelName: String
        let modelData: Data
        let landmarkName: String
        let landmarkData: Data
    }

    /// Aligns to the export frame and encodes both files. Pure; safe off the main actor.
    static func encode(_ input: ExportInput) -> Files {
        let aligned = BodyAlignment.align(mesh: input.mesh, landmarks: input.landmarks)
        let base = ExportNaming.baseName(for: input.capturedAt)
        let modelData: Data
        switch input.format {
        case .obj: modelData = OBJWriter.data(for: aligned.mesh)
        case .ply: modelData = PLYWriter.data(for: aligned.mesh)
        }
        let document = ScanDocument(
            capturedAt: input.capturedAt,
            device: input.device,
            consentAt: input.consentAt,
            landmarks: aligned.landmarks
        )
        return Files(
            modelName: "\(base).\(input.format.rawValue)",
            modelData: modelData,
            landmarkName: "\(base).json",
            landmarkData: document.jsonData()
        )
    }

    static func write(_ files: Files, to storage: ScanStorage) throws -> [URL] {
        let model = try storage.write(files.modelData, fileName: files.modelName)
        do {
            let landmarks = try storage.write(files.landmarkData, fileName: files.landmarkName)
            return [model, landmarks]
        } catch {
            storage.remove([model])
            throw error
        }
    }
}
