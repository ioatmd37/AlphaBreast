import Foundation

/// The export frame: +X toward the patient's left (nR → nL), +Y up, +Z out of the chest.
/// Origin sits at the NAC midpoint, pushed back to the depth of the medial breast borders
/// when those are placed, so it lies near the middle of the torso front.
public enum BodyAlignment {
    public static func frame(for set: LandmarkSet, up: Vec3 = Vec3(0, 1, 0)) -> RigidFrame? {
        guard let nR = set.landmarks[.nR], let nL = set.landmarks[.nL],
              var frame = RigidFrame.make(origin: (nR + nL) / 2, up: up, xToward: nL - nR)
        else { return nil }
        if let medR = set.landmarks[.medR], let medL = set.landmarks[.medL] {
            let depth = frame.toLocal((medR + medL) / 2).z
            frame.origin += frame.zAxis * depth
        }
        return frame
    }

    /// Re-expresses mesh and landmarks in the export frame. Returns them unchanged when the
    /// NACs are not placed yet.
    public static func align(mesh: TriangleMesh, landmarks: LandmarkSet) -> (mesh: TriangleMesh, landmarks: LandmarkSet) {
        guard let frame = frame(for: landmarks) else { return (mesh, landmarks) }
        return (mesh.transformed(by: frame.toLocal), landmarks.transformed(by: frame.toLocal))
    }
}
