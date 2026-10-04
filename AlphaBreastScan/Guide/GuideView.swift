import SwiftUI
import ScanCore

enum ChecklistItem: String, CaseIterable, Identifiable {
    case posture, hairJewelry, markers, lighting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .posture: return "ท่ายืนถูกต้อง"
        case .hairJewelry: return "รวบผม ถอดเครื่องประดับแล้ว"
        case .markers: return "แปะ marker ครบ 7 จุด"
        case .lighting: return "แสงสว่างสม่ำเสมอ"
        }
    }

    var detail: String {
        switch self {
        case .posture: return "ยืนตรง มือเท้าสะเอว กางศอกเล็กน้อยให้เห็นรักแร้"
        case .hairJewelry: return "ไม่มีสร้อยหรือผมบังคอและหน้าอก"
        case .markers: return "marker นูน ผิวด้าน 8–10 mm (เช่น ECG electrode) ที่ sn, IMF, ขอบในและขอบนอกเต้าทั้งสองข้าง"
        case .lighting: return "ไม่มีแสงแดดส่องตรง แสงแดดรบกวน LiDAR"
        }
    }
}

struct GuideView: View {
    @Environment(AppModel.self) private var model
    @State private var checked: Set<ChecklistItem> = []
    @State private var isConfirmingConsent = false

    private var canStart: Bool {
        model.consentAt != nil && checked.count == ChecklistItem.allCases.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TorsoDiagram()
                        .frame(height: 340)
                        .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8))
                    DiagramLegend()
                } header: {
                    Text("ตำแหน่ง marker")
                } footer: {
                    Text("ขวา–ซ้ายหมายถึงของผู้ป่วย ในภาพมองจากด้านหน้า ข้างขวาของผู้ป่วยจึงอยู่ทางซ้ายของภาพ")
                }

                Section("รายการตรวจก่อนสแกน") {
                    ForEach(ChecklistItem.allCases) { item in
                        Toggle(isOn: binding(for: item)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("วิธีสแกน") {
                    ProtocolRow(icon: "lungs", text: "ให้ผู้ป่วยกลั้นหายใจช่วงหายใจออกสุดขณะสแกน")
                    ProtocolRow(icon: "scope", text: "ยืนตรงหน้าผู้ป่วย เล็งกากบาทที่กลางกระดูกอกระดับหัวนม แล้วกดเริ่ม")
                    ProtocolRow(icon: "arrow.left.and.right", text: "ถือเครื่องห่าง 40–60 cm ระดับหน้าอก เดินไปด้านขวาของผู้ป่วย แล้วโค้งราว 180° ผ่านด้านหน้าไปด้านซ้าย")
                    ProtocolRow(icon: "arrow.up.and.down", text: "กวาดขึ้นลงเล็กน้อยให้เห็นใต้ราวนมและเหนือไหปลาร้า")
                    ProtocolRow(icon: "timer", text: "ใช้เวลา 30–60 วินาที")
                }

                Section {
                    Text("ก่อนสแกนทุกครั้ง แจ้งผู้ป่วยว่าแอปจะเก็บภาพ 3 มิติของลำตัวส่วนหน้า ข้อมูลประมวลผลในเครื่องนี้เท่านั้น ไม่ส่งผ่านเครือข่าย ไม่บันทึกลงคลังรูปภาพ และถูกลบหลังส่งออกหรือเมื่อเกิน 24 ชั่วโมง ไฟล์ที่ส่งออกไม่มีชื่อหรือข้อมูลระบุตัวผู้ป่วย")
                        .font(.callout)
                    if let consentAt = model.consentAt {
                        Label("ผู้ป่วยยินยอมเมื่อ \(consentAt.formatted(date: .omitted, time: .standard))", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("บันทึกความยินยอมของผู้ป่วย") { isConfirmingConsent = true }
                    }
                } header: {
                    Text("ความยินยอมของผู้ป่วย")
                } footer: {
                    Text("บันทึกเฉพาะเวลาที่ยินยอม ไม่บันทึกตัวตน")
                }

                Section {
                    Button {
                        model.stage = .capture
                    } label: {
                        Label("เริ่มสแกน", systemImage: "camera.metering.matrix")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canStart)
                } footer: {
                    if !canStart {
                        Text("ทำรายการตรวจให้ครบและบันทึกความยินยอมก่อนเริ่มสแกน")
                    }
                }
            }
            .navigationTitle("เตรียมผู้ป่วย")
            .confirmationDialog("ผู้ป่วยรับทราบและยินยอมให้สแกนแล้วใช่หรือไม่", isPresented: $isConfirmingConsent, titleVisibility: .visible) {
                Button("ยินยอมแล้ว") { model.recordConsent() }
                Button("ยกเลิก", role: .cancel) {}
            }
        }
    }

    private func binding(for item: ChecklistItem) -> Binding<Bool> {
        Binding(
            get: { checked.contains(item) },
            set: { isOn in
                if isOn { checked.insert(item) } else { checked.remove(item) }
            }
        )
    }
}

private struct ProtocolRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon).foregroundStyle(.tint)
        }
    }
}
