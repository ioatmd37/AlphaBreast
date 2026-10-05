import Foundation
@testable import ScanCore

/// Landmarks from the spec's example file (section 8.2).
let specLandmarks = LandmarkSet(
    landmarks: [
        .sn: Vec3(0.000, 0.200, 0.050),
        .nR: Vec3(-0.080, 0.000, 0.085),
        .nL: Vec3(0.080, 0.000, 0.085),
        .imfR: Vec3(-0.080, -0.060, 0.060),
        .imfL: Vec3(0.080, -0.060, 0.060),
        .medR: Vec3(-0.020, 0.000, 0.050),
        .latR: Vec3(-0.140, 0.000, 0.040),
        .medL: Vec3(0.020, 0.000, 0.050),
        .latL: Vec3(0.140, 0.000, 0.040),
    ],
    references: [
        .xiphoid: Vec3(0.000, -0.050, 0.052),
        .scaleA: Vec3(-0.050, -0.180, 0.050),
        .scaleB: Vec3(0.050, -0.180, 0.050),
    ]
)

/// A flat n×n grid of quads in the XY plane, `size` metres across, centred on `center`.
func grid(n: Int, size: Float, center: Vec3 = .zero) -> TriangleMesh {
    var mesh = TriangleMesh()
    let step = size / Float(n)
    for j in 0...n {
        for i in 0...n {
            mesh.vertices.append(center + Vec3(Float(i) * step - size / 2, Float(j) * step - size / 2, 0))
        }
    }
    let row = UInt32(n + 1)
    for j in 0..<UInt32(n) {
        for i in 0..<UInt32(n) {
            let a = j * row + i, b = a + 1, c = a + row, d = c + 1
            mesh.triangles.append(SIMD3(a, b, d))
            mesh.triangles.append(SIMD3(a, d, c))
        }
    }
    return mesh
}

func isClose(_ a: Vec3, _ b: Vec3, accuracy: Float = 1e-5) -> Bool {
    (a - b).length <= accuracy
}
