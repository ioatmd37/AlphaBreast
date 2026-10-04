import SwiftUI
import ScanCore

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var isProcessing = false
    @State private var isConfirmingRescan = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    if let mesh = model.torsoMesh, !mesh.isEmpty {
                        MeshSceneView(mesh: mesh, meshID: model.torsoMeshID)
                    } else {
                        Color(.secondarySystemBackground)
                        if !isProcessing {
                            Text("ไม่พบผิวในกรอบ ปรับกรอบหรือสแกนใหม่")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if isProcessing {
                        ProgressView("กำลังประมวลผล mesh…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxHeight: .infinity)

                Form {
                    Section {
                        if let mesh = model.torsoMesh {
                            MeshStats(mesh: mesh)
                        }
                        if let capture = model.capture {
                            LabeledContent("เวลาสแกน", value: CaptureView.clock(capture.duration))
                        }
                    } header: {
                        Text("ผลสแกน")
                    } footer: {
                        Text("หมุนดูโมเดล ถ้ามีรูหรือผิวขาดบริเวณเต้า ใต้ราวนม หรือเหนือไหปลาร้า ให้สแกนใหม่")
                    }
                    CropControls()
                    Section {
                        Button {
                            model.stage = .landmarks
                        } label: {
                            Label("ต่อไป: จุด landmark", systemImage: "mappin.and.ellipse")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(model.torsoMesh?.isEmpty ?? true || isProcessing)
                        Button("สแกนใหม่", role: .destructive) { isConfirmingRescan = true }
                    }
                }
                .frame(height: 360)
            }
            .navigationTitle("ตรวจผล")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: model.cropBox) { await process() }
            .confirmationDialog("ทิ้งผลสแกนนี้และสแกนใหม่?", isPresented: $isConfirmingRescan, titleVisibility: .visible) {
                Button("สแกนใหม่", role: .destructive) { model.rescan() }
            }
        }
    }

    /// Re-runs crop → clean → decimate whenever the crop box settles.
    private func process() async {
        guard let capture = model.capture else { return }
        isProcessing = true
        if model.torsoMesh != nil {
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard !Task.isCancelled else { return }
        let crop = model.cropBox
        let source = capture.mesh
        let torso = await Task.detached(priority: .userInitiated) {
            MeshPipeline.torso(from: source, crop: crop)
        }.value
        guard !Task.isCancelled else { return }
        model.setTorsoMesh(torso)
        isProcessing = false
    }
}

private struct MeshStats: View {
    let mesh: TriangleMesh

    var body: some View {
        LabeledContent("จำนวนสามเหลี่ยม", value: mesh.triangleCount.formatted())
        if let b = mesh.bounds {
            let size = (b.max - b.min) * 100
            LabeledContent("ขนาด (กว้าง × สูง × ลึก)", value: String(format: "%.0f × %.0f × %.0f cm", size.x, size.y, size.z))
        }
    }
}

private struct CropControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            slider("ครึ่งความกว้าง", value: halfWidth, range: 0.12...0.50)
            slider("ขอบบน (เหนือจุดเล็ง)", value: binding(\.maxY), range: 0.10...0.50)
            slider("ขอบล่าง (ใต้จุดเล็ง)", value: negated(\.minY), range: 0.15...0.70)
            slider("ความลึกด้านหลัง", value: negated(\.minZ), range: 0.10...0.60)
            Button("คืนค่าเริ่มต้น") { model.cropBox = .torsoDefault }
                .disabled(model.cropBox == .torsoDefault)
        } header: {
            Text("ตัดขอบเขตลำตัว")
        } footer: {
            Text("ให้เหลือตั้งแต่โคนคอถึงเอว ตัดพื้นหลังและแขนส่วนล่างออก")
        }
    }

    private func slider(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded())) cm")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.01)
        }
    }

    private var halfWidth: Binding<Float> {
        Binding(
            get: { model.cropBox.maxX },
            set: { model.cropBox.minX = -$0; model.cropBox.maxX = $0 }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<CropBox, Float>) -> Binding<Float> {
        Binding(get: { model.cropBox[keyPath: keyPath] }, set: { model.cropBox[keyPath: keyPath] = $0 })
    }

    private func negated(_ keyPath: WritableKeyPath<CropBox, Float>) -> Binding<Float> {
        Binding(get: { -model.cropBox[keyPath: keyPath] }, set: { model.cropBox[keyPath: keyPath] = -$0 })
    }
}
