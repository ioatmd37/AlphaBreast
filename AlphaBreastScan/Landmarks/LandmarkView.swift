import SwiftUI
import UIKit
import ScanCore

struct LandmarkView: View {
    @Environment(AppModel.self) private var model
    /// A point picked from the strip to re-place; otherwise the next unplaced one is active.
    @State private var selected: PointKey?

    private var activeKey: PointKey? {
        selected ?? model.landmarks.nextUnplaced()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                prompt
                ZStack(alignment: .bottomTrailing) {
                    if let mesh = model.torsoMesh {
                        MeshSceneView(mesh: mesh, meshID: model.torsoMeshID, markers: markers) { position in
                            guard let key = activeKey else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            model.place(key, at: position)
                            selected = nil
                        }
                    } else {
                        ContentUnavailableView("ไม่มีโมเดล", systemImage: "cube.transparent")
                    }
                    Text("แตะเพื่อวางจุด · ลากเพื่อหมุน · บีบเพื่อซูม")
                        .font(.caption2)
                        .padding(6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(8)
                }
                PointStrip(landmarks: model.landmarks, active: activeKey) { key in
                    selected = key
                }
                bottomBar
            }
            .navigationTitle("จุด landmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.stage = .review
                    } label: {
                        Label("ตรวจผล", systemImage: "chevron.backward")
                    }
                }
            }
        }
    }

    private var prompt: some View {
        HStack(spacing: 12) {
            if let key = activeKey {
                Circle()
                    .fill(PointStyle.color(for: key))
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text("แตะที่: \(key.title) (\(key.rawValue))").font(.headline)
                    Text(key.detail + (key.isRequired ? "" : " · ไม่บังคับ"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !key.isRequired && selected == nil {
                    Button("ข้าม") { model.stage = .results }
                        .disabled(!model.landmarks.isComplete)
                }
            } else {
                Label("วางครบทุกจุดแล้ว", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private var markers: [MeshMarker] {
        PointKey.placementOrder.compactMap { key in
            guard let position = model.landmarks[key] else { return nil }
            return MeshMarker(
                id: key.rawValue,
                position: position,
                color: key == activeKey ? .systemOrange : UIColor(PointStyle.color(for: key)),
                isActive: key == activeKey
            )
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                model.undo()
            } label: {
                Label("ย้อนกลับ", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            if let key = activeKey, model.landmarks[key] != nil {
                Button(role: .destructive) {
                    model.clear(key)
                } label: {
                    Label("ลบจุดนี้", systemImage: "trash")
                }
            }

            Spacer()

            Button {
                model.stage = .results
            } label: {
                Label("ค่าวัด", systemImage: "ruler")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.landmarks.isComplete)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

private struct PointStrip: View {
    let landmarks: LandmarkSet
    let active: PointKey?
    let onSelect: (PointKey) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PointKey.placementOrder) { key in
                        chip(for: key).id(key)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: active) { _, key in
                if let key {
                    withAnimation { proxy.scrollTo(key, anchor: .center) }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func chip(for key: PointKey) -> some View {
        let placed = landmarks[key] != nil
        let isActive = key == active
        return Button {
            onSelect(key)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: placed ? "checkmark.circle.fill" : (key.isRequired ? "circle" : "circle.dashed"))
                Text(key.rawValue)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? Color.white : (placed ? PointStyle.color(for: key) : Color.secondary))
            .background(isActive ? Color.orange : Color(.systemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(key.title)\(placed ? " วางแล้ว" : "")")
    }
}
