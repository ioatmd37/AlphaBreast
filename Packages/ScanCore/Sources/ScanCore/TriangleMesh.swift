import Foundation

/// Indexed triangle mesh in metres.
public struct TriangleMesh: Equatable, Sendable {
    public var vertices: [Vec3]
    public var triangles: [SIMD3<UInt32>]

    public init(vertices: [Vec3] = [], triangles: [SIMD3<UInt32>] = []) {
        self.vertices = vertices
        self.triangles = triangles
    }

    public var triangleCount: Int { triangles.count }
    public var isEmpty: Bool { triangles.isEmpty }

    public var bounds: (min: Vec3, max: Vec3)? {
        guard var lo = vertices.first else { return nil }
        var hi = lo
        for v in vertices {
            lo = pointwiseMin(lo, v)
            hi = pointwiseMax(hi, v)
        }
        return (lo, hi)
    }

    public var surfaceArea: Float {
        var total: Float = 0
        for t in triangles {
            let a = vertices[Int(t.x)], b = vertices[Int(t.y)], c = vertices[Int(t.z)]
            total += (b - a).cross(c - a).length * 0.5
        }
        return total
    }

    /// Area-weighted vertex normals.
    public func vertexNormals() -> [Vec3] {
        var normals = [Vec3](repeating: .zero, count: vertices.count)
        for t in triangles {
            let a = vertices[Int(t.x)], b = vertices[Int(t.y)], c = vertices[Int(t.z)]
            let n = (b - a).cross(c - a)
            normals[Int(t.x)] += n
            normals[Int(t.y)] += n
            normals[Int(t.z)] += n
        }
        return normals.map { $0.normalized }
    }

    public func transformed(by transform: (Vec3) -> Vec3) -> TriangleMesh {
        TriangleMesh(vertices: vertices.map(transform), triangles: triangles)
    }

    public static func merged(_ meshes: [TriangleMesh]) -> TriangleMesh {
        var result = TriangleMesh()
        result.vertices.reserveCapacity(meshes.reduce(0) { $0 + $1.vertices.count })
        result.triangles.reserveCapacity(meshes.reduce(0) { $0 + $1.triangles.count })
        for mesh in meshes {
            let offset = UInt32(result.vertices.count)
            result.vertices.append(contentsOf: mesh.vertices)
            result.triangles.append(contentsOf: mesh.triangles.map { $0 &+ offset })
        }
        return result
    }
}
