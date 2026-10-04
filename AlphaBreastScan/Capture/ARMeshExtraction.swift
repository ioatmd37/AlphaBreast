import ARKit
import Metal
import ScanCore

extension ARMeshAnchor {
    /// The anchor's geometry as a mesh in world coordinates.
    func worldMesh() -> TriangleMesh {
        let geometry = self.geometry
        let transform = self.transform

        let source = geometry.vertices
        let vertexBase = UnsafeRawPointer(source.buffer.contents())
        var vertices: [Vec3] = []
        vertices.reserveCapacity(source.count)
        for i in 0..<source.count {
            let offset = source.offset + source.stride * i
            let x = vertexBase.load(fromByteOffset: offset, as: Float.self)
            let y = vertexBase.load(fromByteOffset: offset + 4, as: Float.self)
            let z = vertexBase.load(fromByteOffset: offset + 8, as: Float.self)
            let world = transform * SIMD4<Float>(x, y, z, 1)
            vertices.append(Vec3(world.x, world.y, world.z))
        }

        let faces = geometry.faces
        let faceBase = UnsafeRawPointer(faces.buffer.contents())
        let perFace = faces.indexCountPerPrimitive
        let bytes = faces.bytesPerIndex
        func index(_ i: Int) -> UInt32 {
            if bytes == 2 {
                return UInt32(faceBase.load(fromByteOffset: i * 2, as: UInt16.self))
            }
            return faceBase.load(fromByteOffset: i * 4, as: UInt32.self)
        }
        var triangles: [SIMD3<UInt32>] = []
        if perFace == 3 {
            triangles.reserveCapacity(faces.count)
            for f in 0..<faces.count {
                triangles.append(SIMD3(index(f * 3), index(f * 3 + 1), index(f * 3 + 2)))
            }
        }
        return TriangleMesh(vertices: vertices, triangles: triangles)
    }
}

enum DepthSampler {
    /// Median LiDAR depth (metres) of a 5×5 patch at the image centre.
    static func centerDepth(of frame: ARFrame) -> Float? {
        guard let map = frame.sceneDepth?.depthMap,
              CVPixelBufferGetPixelFormatType(map) == kCVPixelFormatType_DepthFloat32
        else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let rowBytes = CVPixelBufferGetBytesPerRow(map)
        guard width >= 5, height >= 5 else { return nil }
        var samples: [Float] = []
        for y in (height / 2 - 2)...(height / 2 + 2) {
            for x in (width / 2 - 2)...(width / 2 + 2) {
                let value = UnsafeRawPointer(base).load(fromByteOffset: y * rowBytes + x * 4, as: Float32.self)
                if value.isFinite, value > 0.05 { samples.append(value) }
            }
        }
        guard !samples.isEmpty else { return nil }
        samples.sort()
        return samples[samples.count / 2]
    }
}
