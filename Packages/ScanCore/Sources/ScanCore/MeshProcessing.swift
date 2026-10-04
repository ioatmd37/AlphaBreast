import Foundation

/// Axis-aligned box in the body frame (+X patient's left, +Y up, +Z anterior).
public struct CropBox: Equatable, Sendable {
    public var minX: Float
    public var maxX: Float
    public var minY: Float
    public var maxY: Float
    public var minZ: Float
    public var maxZ: Float

    public init(minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.minZ = minZ
        self.maxZ = maxZ
    }

    /// Torso from the base of the neck to the waist, relative to a capture origin on the
    /// front of the chest at nipple level.
    public static let torsoDefault = CropBox(minX: -0.25, maxX: 0.25, minY: -0.40, maxY: 0.30, minZ: -0.30, maxZ: 0.20)

    /// Generous limit applied right after capture to drop the rest of the room.
    public static let captureLimit = CropBox(minX: -1.0, maxX: 1.0, minY: -1.0, maxY: 1.0, minZ: -1.0, maxZ: 1.0)

    public func contains(_ p: Vec3) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY && p.z >= minZ && p.z <= maxZ
    }
}

private struct GridKey: Hashable {
    let x: Int32
    let y: Int32
    let z: Int32

    init(_ p: Vec3, cell: Float) {
        x = Int32(clamping: Int((p.x / cell).rounded(.down)))
        y = Int32(clamping: Int((p.y / cell).rounded(.down)))
        z = Int32(clamping: Int((p.z / cell).rounded(.down)))
    }
}

extension TriangleMesh {
    /// Removes vertices no triangle uses.
    public func compacted() -> TriangleMesh {
        var remap = [UInt32](repeating: .max, count: vertices.count)
        var newVertices: [Vec3] = []
        newVertices.reserveCapacity(vertices.count)
        func remapped(_ i: UInt32) -> UInt32 {
            if remap[Int(i)] == .max {
                remap[Int(i)] = UInt32(newVertices.count)
                newVertices.append(vertices[Int(i)])
            }
            return remap[Int(i)]
        }
        let newTriangles = triangles.map { SIMD3(remapped($0.x), remapped($0.y), remapped($0.z)) }
        return TriangleMesh(vertices: newVertices, triangles: newTriangles)
    }

    /// Merges vertices that fall in the same `tolerance`-sized grid cell, and drops invalid,
    /// out-of-range and degenerate triangles. ARKit mesh anchors overlap at their seams.
    public func welded(tolerance: Float = 0.001) -> TriangleMesh {
        var cellIndex: [GridKey: UInt32] = [:]
        cellIndex.reserveCapacity(vertices.count)
        var newVertices: [Vec3] = []
        var remap = [UInt32](repeating: .max, count: vertices.count)
        for (i, v) in vertices.enumerated() where v.isFinite {
            let key = GridKey(v, cell: tolerance)
            if let existing = cellIndex[key] {
                remap[i] = existing
            } else {
                let index = UInt32(newVertices.count)
                cellIndex[key] = index
                newVertices.append(v)
                remap[i] = index
            }
        }
        let count = vertices.count
        var newTriangles: [SIMD3<UInt32>] = []
        newTriangles.reserveCapacity(triangles.count)
        for t in triangles {
            guard Int(t.x) < count, Int(t.y) < count, Int(t.z) < count else { continue }
            let a = remap[Int(t.x)], b = remap[Int(t.y)], c = remap[Int(t.z)]
            guard a != .max, b != .max, c != .max, a != b, b != c, a != c else { continue }
            newTriangles.append(SIMD3(a, b, c))
        }
        return TriangleMesh(vertices: newVertices, triangles: newTriangles).compacted()
    }

    /// Keeps triangles whose centroid lies inside `box`.
    public func cropped(to box: CropBox) -> TriangleMesh {
        let kept = triangles.filter { t in
            let centroid = (vertices[Int(t.x)] + vertices[Int(t.y)] + vertices[Int(t.z)]) / 3
            return box.contains(centroid)
        }
        return TriangleMesh(vertices: vertices, triangles: kept).compacted()
    }

    /// Keeps connected pieces with at least `minimumFraction` of the largest piece's
    /// triangles. Removes stray background fragments left after cropping.
    public func keepingLargestComponents(minimumFraction: Double = 0.2) -> TriangleMesh {
        guard !triangles.isEmpty else { return self }
        var parent = Array(0..<vertices.count)
        func find(_ x: Int) -> Int {
            var r = x
            while parent[r] != r {
                parent[r] = parent[parent[r]]
                r = parent[r]
            }
            return r
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }
        for t in triangles {
            union(Int(t.x), Int(t.y))
            union(Int(t.y), Int(t.z))
        }
        var counts: [Int: Int] = [:]
        var roots: [Int] = []
        roots.reserveCapacity(triangles.count)
        for t in triangles {
            let r = find(Int(t.x))
            roots.append(r)
            counts[r, default: 0] += 1
        }
        let largest = counts.values.max() ?? 0
        let threshold = max(1, Int((Double(largest) * minimumFraction).rounded(.up)))
        var kept: [SIMD3<UInt32>] = []
        for (t, r) in zip(triangles, roots) where counts[r, default: 0] >= threshold {
            kept.append(t)
        }
        return TriangleMesh(vertices: vertices, triangles: kept).compacted()
    }

    /// Vertex-clustering decimation: grows the grid cell until the mesh fits `maxTriangles`.
    public func decimated(maxTriangles: Int) -> TriangleMesh {
        guard maxTriangles > 0, triangleCount > maxTriangles else { return self }
        // A surface of area A on a grid of cell s yields roughly 2A/s² triangles.
        var cell = max((2 * surfaceArea / Float(maxTriangles)).squareRoot(), 1e-4)
        var result = clustered(cellSize: cell)
        var attempts = 0
        while result.triangleCount > maxTriangles, attempts < 40 {
            cell *= 1.2
            result = clustered(cellSize: cell)
            attempts += 1
        }
        return result
    }

    func clustered(cellSize: Float) -> TriangleMesh {
        var cellIndex: [GridKey: Int] = [:]
        var sums: [Vec3] = []
        var counts: [Float] = []
        var remap = [UInt32](repeating: 0, count: vertices.count)
        for (i, v) in vertices.enumerated() {
            let key = GridKey(v, cell: cellSize)
            if let index = cellIndex[key] {
                sums[index] += v
                counts[index] += 1
                remap[i] = UInt32(index)
            } else {
                cellIndex[key] = sums.count
                remap[i] = UInt32(sums.count)
                sums.append(v)
                counts.append(1)
            }
        }
        let newVertices = zip(sums, counts).map { $0 / $1 }
        var seen = Set<SIMD3<UInt32>>()
        var newTriangles: [SIMD3<UInt32>] = []
        for t in triangles {
            let a = remap[Int(t.x)], b = remap[Int(t.y)], c = remap[Int(t.z)]
            guard a != b, b != c, a != c else { continue }
            // Rotate so the smallest index comes first; keeps winding, catches duplicates.
            let key: SIMD3<UInt32>
            if a < b && a < c {
                key = SIMD3(a, b, c)
            } else if b < c {
                key = SIMD3(b, c, a)
            } else {
                key = SIMD3(c, a, b)
            }
            if seen.insert(key).inserted {
                newTriangles.append(key)
            }
        }
        return TriangleMesh(vertices: newVertices, triangles: newTriangles).compacted()
    }
}

public enum MeshPipeline {
    /// Target size from the spec: no more than 100,000 triangles.
    public static let maxTriangles = 100_000

    /// Body-frame capture mesh → cropped, cleaned and decimated torso.
    public static func torso(from mesh: TriangleMesh, crop: CropBox, maxTriangles: Int = maxTriangles) -> TriangleMesh {
        mesh.cropped(to: crop)
            .keepingLargestComponents()
            .decimated(maxTriangles: maxTriangles)
    }
}
