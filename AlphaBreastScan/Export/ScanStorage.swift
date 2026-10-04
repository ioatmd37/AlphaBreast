import Foundation
import ScanCore

/// The only place the app writes scan data. Files get `complete` data protection, are
/// excluded from backup, and are removed after sharing or once older than 24 hours.
final class ScanStorage {
    let root: URL
    private let fileManager = FileManager.default

    init() {
        let base = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        root = base.appendingPathComponent("Scans", isDirectory: true)
        prepareRoot()
    }

    private func prepareRoot() {
        try? fileManager.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        excludeFromBackup(root)
    }

    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    func write(_ data: Data, fileName: String) throws -> URL {
        prepareRoot()
        let url = root.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        excludeFromBackup(url)
        return url
    }

    func remove(_ urls: [URL]) {
        for url in urls {
            try? fileManager.removeItem(at: url)
        }
    }

    func removeAll() {
        remove(contents(of: root))
        remove(contents(of: fileManager.temporaryDirectory))
    }

    /// Deletes anything older than `RetentionPolicy.maximumAge`, e.g. left behind by a crash.
    func purgeExpired(now: Date = Date()) {
        for directory in [root, fileManager.temporaryDirectory] {
            for url in contents(of: directory) {
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                if RetentionPolicy.isExpired(createdAt: created, now: now) {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
    }

    private func contents(of directory: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }
}
