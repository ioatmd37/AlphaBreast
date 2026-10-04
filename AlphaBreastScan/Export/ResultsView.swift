import SwiftUI
import ScanCore

struct ResultsView: View {
    @Environment(AppModel.self) private var model
    @State private var format: ModelFormat = .obj
    @State private var shareURLs: SharedFiles?
    @State private var isExporting = false
    @State private var exportStatus: String?
    @State private var errorMessage: String?
    @State private var isConfirmingReset = false

    var body: some View {
        let measurements = Measurements(model.landmarks)
        let warnings = LandmarkWarning.check(model.landmarks)
        NavigationStack {
            Form {
                if !warnings.isEmpty {
                    Section("ข้อควรตรวจ") {
                        ForEach(warnings) { warning in
                            Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    ForEach(measurements.items) { item in
                        LabeledContent(item.title, value: Self.centimetres(item.meters))
                    }
                } header: {
                    Text("ค่าวัด")
                } footer: {
                    Text("ระยะเป็นเส้นตรงระหว่างจุด ไม่ใช่ระยะตามผิว · N–IMF เป็นค่าขณะพัก เครื่องคำนวณในเว็บใช้ค่าขณะดึงตึง จึงยังต้องวัดด้วยมือ · ใช้เพื่อการทดสอบ ไม่ใช่เพื่อการตัดสินใจทางคลินิก")
                }

                if let scale = measurements.scaleCheck {
                    Section("ตรวจมาตราส่วน") {
                        LabeledContent("scaleA–scaleB", value: Self.centimetres(scale.measuredMeters))
                        Label(
                            scale.isWithinTolerance ? "ต่างจาก 10.0 cm ไม่เกิน 3 mm" : "ต่างจาก 10.0 cm เกิน 3 mm",
                            systemImage: scale.isWithinTolerance ? "checkmark.circle.fill" : "xmark.octagon.fill"
                        )
                        .foregroundStyle(scale.isWithinTolerance ? Color.green : Color.red)
                    }
                }

                Section {
                    Picker("รูปแบบโมเดล", selection: $format) {
                        ForEach(ModelFormat.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button {
                        Task { await export() }
                    } label: {
                        HStack {
                            Label("ส่งออกโมเดล + landmark", systemImage: "square.and.arrow.up")
                            if isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting || model.torsoMesh == nil || !model.landmarks.isComplete)
                    if let exportStatus {
                        Label(exportStatus, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("ส่งออก")
                } footer: {
                    Text("ส่งผ่าน AirDrop หรือบันทึกลง Files แล้วเปิดในหน้า Scan ของ augsizer ไฟล์ในแอปจะถูกลบทันทีหลังปิดหน้าส่งออก ไฟล์ไม่มีชื่อหรือข้อมูลระบุตัวผู้ป่วย")
                }

                Section {
                    Button("ผู้ป่วยรายใหม่ (ล้างข้อมูลทั้งหมด)", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
            }
            .navigationTitle("ค่าวัดและส่งออก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.stage = .landmarks
                    } label: {
                        Label("landmark", systemImage: "chevron.backward")
                    }
                }
            }
            .sheet(item: $shareURLs, onDismiss: deleteShared) { files in
                ShareSheet(urls: files.urls) { completed in
                    exportStatus = completed ? "ส่งออกแล้ว และลบไฟล์ออกจากแอปแล้ว" : nil
                    shareURLs = nil
                }
                .presentationDetents([.medium, .large])
            }
            .alert(
                "ส่งออกไม่สำเร็จ",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("ตกลง", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "ล้างข้อมูลสแกน landmark และความยินยอมของผู้ป่วยรายนี้?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("ล้างข้อมูล", role: .destructive) { model.startNewPatient() }
            }
        }
    }

    private func export() async {
        guard let mesh = model.torsoMesh, let capture = model.capture else { return }
        isExporting = true
        defer { isExporting = false }
        let input = ExportInput(
            mesh: mesh,
            landmarks: model.landmarks,
            capturedAt: capture.capturedAt,
            consentAt: model.consentAt,
            format: format,
            device: DeviceInfo.marketingName
        )
        let files = await Task.detached(priority: .userInitiated) { ExportService.encode(input) }.value
        do {
            shareURLs = SharedFiles(urls: try ExportService.write(files, to: model.storage))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteShared() {
        model.storage.removeAll()
    }

    static func centimetres(_ meters: Double?) -> String {
        guard let meters else { return "—" }
        return String(format: "%.1f cm", meters * 100)
    }
}

private struct SharedFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}
