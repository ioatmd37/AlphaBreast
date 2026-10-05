import SceneKit
import SwiftUI
import UIKit
import ScanCore

struct MeshMarker {
    let id: String
    let position: Vec3
    let color: UIColor
    let isActive: Bool
}

/// Orbitable view of a mesh, with optional markers and tap-to-pick on the surface.
struct MeshSceneView: UIViewRepresentable {
    let mesh: TriangleMesh
    /// Changes whenever `mesh` does; rebuilding SceneKit geometry is too slow to do per update.
    let meshID: UUID
    var markers: [MeshMarker] = []
    var onTap: ((Vec3) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.backgroundColor = .secondarySystemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        if coordinator.meshID != meshID {
            coordinator.meshID = meshID
            coordinator.setMesh(mesh)
        }
        coordinator.setMarkers(markers)
    }

    final class Coordinator: NSObject {
        weak var view: SCNView?
        var meshID: UUID?
        var onTap: ((Vec3) -> Void)?
        private var meshNode: SCNNode?
        private var cameraNode: SCNNode?
        private let markerRoot = SCNNode()

        func setMesh(_ mesh: TriangleMesh) {
            guard let view, let scene = view.scene else { return }
            meshNode?.removeFromParentNode()
            let node = SCNNode(geometry: MeshGeometry.make(mesh))
            scene.rootNode.addChildNode(node)
            meshNode = node
            if markerRoot.parent == nil {
                scene.rootNode.addChildNode(markerRoot)
            }
            frameCamera(on: mesh, in: view)
        }

        /// Looks at the mesh from the front (+Z), far enough to see all of it.
        private func frameCamera(on mesh: TriangleMesh, in view: SCNView) {
            guard let bounds = mesh.bounds else { return }
            let center = (bounds.min + bounds.max) / 2
            let size = (bounds.max - bounds.min).length
            let camera = SCNCamera()
            camera.zNear = 0.01
            camera.zFar = 20
            camera.fieldOfView = 40
            let node = SCNNode()
            node.camera = camera
            node.position = SCNVector3(x: center.x, y: center.y, z: center.z + max(size * 1.3, 0.4))
            node.look(at: SCNVector3(x: center.x, y: center.y, z: center.z))
            cameraNode?.removeFromParentNode()
            view.scene?.rootNode.addChildNode(node)
            cameraNode = node
            view.pointOfView = node
            view.defaultCameraController.target = SCNVector3(x: center.x, y: center.y, z: center.z)
        }

        func setMarkers(_ markers: [MeshMarker]) {
            markerRoot.childNodes.forEach { $0.removeFromParentNode() }
            for marker in markers {
                let sphere = SCNSphere(radius: marker.isActive ? 0.006 : 0.0045)
                let material = SCNMaterial()
                material.diffuse.contents = marker.color
                material.lightingModel = .constant
                // Keep markers visible even where they sink into the surface.
                material.readsFromDepthBuffer = false
                sphere.materials = [material]
                let node = SCNNode(geometry: sphere)
                node.renderingOrder = 10
                node.position = SCNVector3(x: marker.position.x, y: marker.position.y, z: marker.position.z)
                markerRoot.addChildNode(node)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view, let meshNode, let onTap else { return }
            let location = gesture.location(in: view)
            let hits = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: true,
            ])
            guard let hit = hits.first(where: { $0.node === meshNode }) else { return }
            let p = hit.worldCoordinates
            onTap(Vec3(Float(p.x), Float(p.y), Float(p.z)))
        }
    }
}

enum MeshGeometry {
    static func make(_ mesh: TriangleMesh) -> SCNGeometry {
        let positions = mesh.vertices.map { SCNVector3(x: $0.x, y: $0.y, z: $0.z) }
        let normals = mesh.vertexNormals().map { SCNVector3(x: $0.x, y: $0.y, z: $0.z) }
        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.triangles.count * 3)
        for t in mesh.triangles {
            indices.append(t.x)
            indices.append(t.y)
            indices.append(t.z)
        }
        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.85, green: 0.76, blue: 0.70, alpha: 1)
        material.lightingModel = .blinn
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}
