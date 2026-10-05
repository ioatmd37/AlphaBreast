import SwiftUI

struct UnlockView: View {
    @Environment(AppModel.self) private var model
    @State private var errorMessage: String?
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("AlphaBreast Scan").font(.largeTitle.bold())
                Text("รุ่นทดสอบ alpha · ข้อมูลอยู่ในเครื่องนี้เท่านั้น")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Task { await authenticate() }
            } label: {
                Label("ปลดล็อกด้วย Face ID / รหัสเครื่อง", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
        }
        .padding()
        .task { await authenticate() }
    }

    private func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        switch await DeviceAuthenticator.authenticate() {
        case .success:
            errorMessage = nil
            model.unlockSucceeded()
        case .failure(let failure):
            errorMessage = failure.localizedDescription
        }
    }
}

struct AlphaCodeView: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var isWrong = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill").font(.system(size: 48)).foregroundStyle(.tint)
            Text("รหัสทดสอบ alpha").font(.title2.bold())
            Text("ใช้รหัสเดียวกับหน้าเว็บ alpha").foregroundStyle(.secondary)
            SecureField("รหัส", text: $code)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit(submit)
            if isWrong {
                Text("รหัสไม่ถูกต้อง").foregroundStyle(.red)
            }
            Button("ยืนยัน", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(code.isEmpty)
            Spacer()
        }
        .padding()
    }

    private func submit() {
        if AlphaCode.verify(code) {
            model.acceptAlphaCode()
        } else {
            isWrong = true
            code = ""
        }
    }
}
