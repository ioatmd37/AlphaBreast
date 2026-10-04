import Foundation

private let exportHeader = [
    "AlphaBreast Scan export (\(ScanDocument.schema))",
    "units: m; +X patient's left, +Y up, +Z anterior",
]

/// Wavefront OBJ with per-vertex normals, one object, no materials.
public enum OBJWriter {
    public static func data(for mesh: TriangleMesh) -> Data {
        let normals = mesh.vertexNormals()
        var out = ""
        out.reserveCapacity(mesh.vertices.count * 70 + mesh.triangles.count * 30)
        for line in exportHeader { out += "# \(line)\n" }
        out += "o torso\n"
        for v in mesh.vertices {
            out += "v \(coordinate(v.x)) \(coordinate(v.y)) \(coordinate(v.z))\n"
        }
        for n in normals {
            out += "vn \(direction(n.x)) \(direction(n.y)) \(direction(n.z))\n"
        }
        for t in mesh.triangles {
            let a = t.x + 1, b = t.y + 1, c = t.z + 1
            out += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
        }
        return Data(out.utf8)
    }

    static func coordinate(_ v: Float) -> String { String(format: "%.5f", Double(v)) }
    static func direction(_ v: Float) -> String { String(format: "%.4f", Double(v)) }
}

/// ASCII PLY: positions and triangle faces.
public enum PLYWriter {
    public static func data(for mesh: TriangleMesh) -> Data {
        var out = ""
        out.reserveCapacity(mesh.vertices.count * 40 + mesh.triangles.count * 25)
        out += "ply\nformat ascii 1.0\n"
        for line in exportHeader { out += "comment \(line)\n" }
        out += "element vertex \(mesh.vertices.count)\n"
        out += "property float x\nproperty float y\nproperty float z\n"
        out += "element face \(mesh.triangles.count)\n"
        out += "property list uchar uint vertex_indices\n"
        out += "end_header\n"
        for v in mesh.vertices {
            out += "\(OBJWriter.coordinate(v.x)) \(OBJWriter.coordinate(v.y)) \(OBJWriter.coordinate(v.z))\n"
        }
        for t in mesh.triangles {
            out += "3 \(t.x) \(t.y) \(t.z)\n"
        }
        return Data(out.utf8)
    }
}
