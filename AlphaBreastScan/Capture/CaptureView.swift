import RealityKit
import SwiftUI
import ScanCore

struct CaptureView: View {
    @Environment(AppModel.self) private var model
    // Created once on appear: a @State default value would be rebuilt with every view init,
    // and each one owns an ARView and an ARSession.
    @State private var controller: CaptureController?

    var body: some View {
        Group {
            if !CaptureController.isSupported {
                ContentUnavailableView {
                    Label("เครื่องนี้ไม่มี LiDAR", systemImage: "sensor")
                } description: {
                    Text("ต้องใช้ iPhone Pro หรือ iPad Pro ที่มี LiDAR ที่กล้องหลัง")
                } actions: {
                    Button("กลับ") { model.stage = .guide }
                }
            } else if let controller {
                CaptureSessionView(controller: controller)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            guard CaptureController.isSupported else { return }
            let controller = self.controller ?? CaptureController()
            self.controller = controller
            controller.start()
        }
        .onDisappear { controller?.stop() }
    }
}

private struct CaptureSessionView: View {
    @Environment(AppModel.self) private var model
    let controller: CaptureController
    @State private var isConfirmingEarlyFinish = false

    var body: some View {
        ZStack {
            ARViewContainer(arView: controller.arView)
                .ignoresSafeArea()
            Reticle()
            VStack {
                instructions
                Spacer()
                controls
            }
            .padding()
        }
        .alert(
            "สแกนไม่สำเร็จ",
            isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })
        ) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .confirmationDialog(
            "ยังสแกนไม่ครอบคลุม (\(Int(controller.coverage * 100))%) ต้องการจบการสแกนหรือไม่",
            isPresented: $isConfirmingEarlyFinish,
            titleVisibility: .visible
        ) {
            Button("จบการสแกน") { finish() }
            Button("สแกนต่อ", role: .cancel) {}
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(instructionText)
                .font(.callout.weight(.medium))
            HStack(spacing: 12) {
                if let distance = controller.distance {
                    let good = SweepTracker.recommendedDistance.contains(distance)
                    Label("\(Int((distance * 100).rounded())) cm", systemImage: "ruler")
                        .foregroundStyle(good ? Color.green : Color.orange)
                }
                if let message = controller.trackingMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var instructionText: String {
        switch controller.phase {
        case .aiming:
            return "ยืนตรงหน้าผู้ป่วย ห่าง 40–60 cm เล็งกากบาทที่กลางกระดูกอกระดับหัวนม แล้วกดเริ่ม"
        case .scanning:
            return "เดินไปด้านขวาของผู้ป่วย แล้วโค้งผ่านด้านหน้าไปด้านซ้าย กวาดขึ้นลงเล็กน้อย ให้แถบด้านล่างเต็ม"
        case .finishing:
            return "กำลังรวม mesh…"
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if controller.phase != .aiming {
                CoverageBar(bins: controller.bins, current: controller.currentBin)
                Text("\(CaptureView.clock(controller.elapsed)) · เป้าหมาย 30–60 วินาที")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("ยกเลิก") { model.stage = .guide }
                    .buttonStyle(.bordered)
                    .disabled(controller.phase == .finishing)
                switch controller.phase {
                case .aiming:
                    Button {
                        controller.beginScan()
                    } label: {
                        Label("เริ่มสแกน", systemImage: "record.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                case .scanning:
                    Button {
                        if controller.coverage < 0.7 {
                            isConfirmingEarlyFinish = true
                        } else {
                            finish()
                        }
                    } label: {
                        Label("จบการสแกน", systemImage: "stop.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                case .finishing:
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func finish() {
        Task {
            if let result = await controller.finishScan() {
                model.finishCapture(result)
            }
        }
    }
}

extension CaptureView {
    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

private struct Reticle: View {
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.9), lineWidth: 2).frame(width: 36, height: 36)
            Rectangle().fill(.white).frame(width: 2, height: 14)
            Rectangle().fill(.white).frame(width: 14, height: 2)
        }
        .shadow(radius: 2)
        .allowsHitTesting(false)
    }
}

/// The 180° arc in front of the patient, drawn as the scanner sees it: patient's right on
/// the left.
struct CoverageBar: View {
    let bins: [Bool]
    let current: Int?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(bins.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(bins[i] ? Color.green : Color.white.opacity(0.25))
                        .overlay {
                            if current == i {
                                RoundedRectangle(cornerRadius: 2).stroke(.white, lineWidth: 2)
                            }
                        }
                        .frame(height: 18)
                }
            }
            HStack {
                Text("ด้านขวาผู้ป่วย")
                Spacer()
                Text("ด้านหน้า")
                Spacer()
                Text("ด้านซ้ายผู้ป่วย")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement()
        .accessibilityLabel("ครอบคลุม \(bins.filter { $0 }.count) จาก \(bins.count) ช่วง")
    }
}
