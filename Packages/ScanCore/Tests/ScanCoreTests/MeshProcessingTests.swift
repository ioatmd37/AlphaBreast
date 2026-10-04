import XCTest
@testable import ScanCore

final class MeshProcessingTests: XCTestCase {
    func testMergeOffsetsIndices() {
        let a = grid(n: 1, size: 1)
        let merged = TriangleMesh.merged([a, a])
        XCTAssertEqual(merged.vertices.count, 8)
        XCTAssertEqual(merged.triangles.count, 4)
        XCTAssertEqual(merged.triangles[2], a.triangles[0] &+ 4)
    }

    func testWeldJoinsDuplicatesAndDropsDegenerates() {
        let a = grid(n: 4, size: 1)
        var merged = TriangleMesh.merged([a, a])
        merged.vertices.append(Vec3(.nan, 0, 0))
        let nanIndex = UInt32(merged.vertices.count - 1)
        merged.triangles.append(SIMD3(0, 1, nanIndex))
        merged.triangles.append(SIMD3(0, 0, 1))
        merged.triangles.append(SIMD3(0, 1, 999))
        let welded = merged.welded(tolerance: 0.001)
        XCTAssertEqual(welded.vertices.count, 25)
        XCTAssertEqual(welded.triangles.count, 64)
    }

    func testCompactedRemovesUnusedVertices() {
        let mesh = TriangleMesh(vertices: [.zero, Vec3(1, 0, 0), Vec3(5, 5, 5), Vec3(0, 1, 0)], triangles: [SIMD3(0, 1, 3)])
        let compact = mesh.compacted()
        XCTAssertEqual(compact.vertices, [.zero, Vec3(1, 0, 0), Vec3(0, 1, 0)])
        XCTAssertEqual(compact.triangles, [SIMD3(0, 1, 2)])
    }

    func testCropKeepsCentroidsInsideBox() {
        let mesh = grid(n: 10, size: 1)
        let box = CropBox(minX: -0.25, maxX: 0.25, minY: -0.5, maxY: 0.5, minZ: -1, maxZ: 1)
        let cropped = mesh.cropped(to: box)
        XCTAssertEqual(cropped.triangleCount, 100)
        XCTAssertTrue(cropped.vertices.allSatisfy { abs($0.x) <= 0.3 + 1e-5 })
    }

    func testLargestComponentDropsSmallFragments() {
        let body = grid(n: 10, size: 0.5)
        let fragment = grid(n: 2, size: 0.05, center: Vec3(0.9, 0, 0))
        let cleaned = TriangleMesh.merged([body, fragment]).keepingLargestComponents()
        XCTAssertEqual(cleaned.triangleCount, body.triangleCount)
        XCTAssertEqual(cleaned.vertices.count, body.vertices.count)
    }

    func testLargestComponentKeepsSimilarSizedPieces() {
        let left = grid(n: 10, size: 0.2, center: Vec3(-0.2, 0, 0))
        let right = grid(n: 9, size: 0.2, center: Vec3(0.2, 0, 0))
        let cleaned = TriangleMesh.merged([left, right]).keepingLargestComponents()
        XCTAssertEqual(cleaned.triangleCount, left.triangleCount + right.triangleCount)
    }

    func testDecimationMeetsBudgetAndKeepsExtent() throws {
        let mesh = grid(n: 100, size: 0.4)
        XCTAssertEqual(mesh.triangleCount, 20_000)
        let small = mesh.decimated(maxTriangles: 2_000)
        XCTAssertLessThanOrEqual(small.triangleCount, 2_000)
        XCTAssertGreaterThan(small.triangleCount, 500)
        let b = try XCTUnwrap(small.bounds)
        XCTAssertEqual(b.max.x - b.min.x, 0.4, accuracy: 0.03)
        XCTAssertEqual(small.surfaceArea, 0.16, accuracy: 0.02)
    }

    func testDecimationLeavesSmallMeshAlone() {
        let mesh = grid(n: 5, size: 1)
        XCTAssertEqual(mesh.decimated(maxTriangles: 100), mesh)
    }

    func testPipelineCropsCleansAndDecimates() {
        let torso = grid(n: 60, size: 0.5)
        let wall = grid(n: 60, size: 2, center: Vec3(0, 0, -0.8))
        let result = MeshPipeline.torso(from: .merged([torso, wall]), crop: .torsoDefault, maxTriangles: 3_000)
        XCTAssertLessThanOrEqual(result.triangleCount, 3_000)
        XCTAssertGreaterThan(result.triangleCount, 0)
        XCTAssertTrue(result.vertices.allSatisfy { abs($0.z) < 0.01 })
    }

    func testVertexNormalsPointAlongPlaneNormal() {
        let normals = grid(n: 3, size: 1).vertexNormals()
        XCTAssertTrue(normals.allSatisfy { isClose($0, Vec3(0, 0, 1)) })
    }
}
