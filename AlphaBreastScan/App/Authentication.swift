import CryptoKit
import Foundation
import LocalAuthentication

enum DeviceAuthenticator {
    enum Failure: LocalizedError {
        case noDevicePasscode
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noDevicePasscode:
                return "เครื่องนี้ยังไม่ได้ตั้งรหัส ต้องตั้งรหัสเครื่องก่อนใช้งาน เพราะความปลอดภัยของข้อมูลขึ้นกับการล็อกเครื่อง"
            case .failed(let message):
                return message
            }
        }
    }

    /// Face ID / Touch ID with fallback to the device passcode.
    static func authenticate() async -> Result<Void, Failure> {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .failure(.noDevicePasscode)
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "ปลดล็อกเพื่อเข้าถึงข้อมูลสแกน"
            )
            return ok ? .success(()) : .failure(.failed("ปลดล็อกไม่สำเร็จ"))
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
}

/// Optional soft lock shared with the web alpha page. Only a SHA-256 hash is built into
/// the app, through the `AB_ALPHA_CODE_SHA256` build setting; the code itself is never in
/// the repo. Leave the setting empty to rely on TestFlight's tester list instead.
enum AlphaCode {
    static let expectedHash: String? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ABAlphaCodeSHA256") as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isHex = value.count == 64 && value.allSatisfy { $0.isHexDigit }
        return isHex ? value : nil
    }()

    static var isRequired: Bool { expectedHash != nil }

    static func verify(_ code: String) -> Bool {
        guard let expectedHash else { return true }
        let digest = SHA256.hash(data: Data(code.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex == expectedHash
    }
}
