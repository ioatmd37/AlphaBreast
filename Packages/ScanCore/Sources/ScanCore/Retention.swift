import Foundation

public enum RetentionPolicy {
    /// Files older than this are deleted on launch and when the app returns to the foreground.
    public static let maximumAge: TimeInterval = 24 * 60 * 60

    public static func isExpired(createdAt: Date, now: Date, maximumAge: TimeInterval = maximumAge) -> Bool {
        now.timeIntervalSince(createdAt) > maximumAge
    }
}

public enum ExportNaming {
    /// `scan-20261004-1530`. Gregorian calendar even on devices set to the Buddhist calendar.
    public static func baseName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "scan-" + formatter.string(from: date)
    }
}
